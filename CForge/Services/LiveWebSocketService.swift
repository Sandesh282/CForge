import Foundation

// MARK: - LiveWebSocketService

/// Concrete WebSocket implementation backed by `URLSessionWebSocketTask`.
///
/// Key design decisions:
/// - Uses a recursive `.receive()` loop (URLSessionWebSocketTask requires re-arming after each message)
/// - Exponential backoff reconnect (2^attempt seconds, capped at 5 attempts)
/// - 30-second ping/pong loop to detect silent connection drops
/// - All socket callbacks are dispatched to a serial background queue to avoid blocking
/// - Events are published through `AsyncStream` continuations — 100% pure Swift Concurrency,
///   zero Combine dependency.
///
/// `@unchecked Sendable`: The mutable state (`webSocketTask`, `activeURL`, etc.) is always
/// accessed from the `URLSession` delegate queue (serial) or from callers who hold the
/// appropriate task reference. We document and enforce this invariant instead of using
/// an actor, because `URLSessionDelegate` conformance requires `NSObject` inheritance
/// which prevents actor adoption.
final class LiveWebSocketService: NSObject, WebSocketServiceProtocol, @unchecked Sendable {

    // MARK: - AsyncStream Continuations

    /// All active event stream continuations. Each call to `eventStream` appends one.
    private var eventContinuations: [UUID: AsyncStream<WebSocketEvent>.Continuation] = [:]

    /// All active connection-state stream continuations.
    private var stateContinuations: [UUID: AsyncStream<WebSocketConnectionState>.Continuation] = [:]

    /// Guards access to the continuation dictionaries from the URLSession delegate queue.
    private let lock = NSLock()

    // MARK: - WebSocketServiceProtocol

    /// Each call returns an independent `AsyncStream` so multiple observers
    /// (e.g., different Repositories) can each iterate their own sequence.
    var eventStream: AsyncStream<WebSocketEvent> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock { eventContinuations[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.eventContinuations.removeValue(forKey: id) }
            }
        }
    }

    /// Yields the current state immediately, then all subsequent state changes.
    var connectionStateStream: AsyncStream<WebSocketConnectionState> {
        let current = _currentState
        return AsyncStream { continuation in
            let id = UUID()
            continuation.yield(current)                          // cold-observable: emit current first
            lock.withLock { stateContinuations[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.stateContinuations.removeValue(forKey: id) }
            }
        }
    }

    /// Synchronous snapshot — for initial ViewModel binding before the async loop starts.
    var currentState: WebSocketConnectionState { _currentState }

    // MARK: - Internal State

    private var webSocketTask: URLSessionWebSocketTask?
    private var activeURL: URL?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var _currentState: WebSocketConnectionState = .disconnected

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Connection Lifecycle

    func connect(to url: URL) {
        guard _currentState == .disconnected else {
            AppLog.debug("WS: Already connected or connecting — ignoring connect(to:)", category: .network)
            return
        }
        activeURL = url
        openConnection(to: url)
    }

    private func openConnection(to url: URL) {
        AppLog.debug("WS: Connecting to \(url)", category: .network)
        updateState(.connecting)
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        beginListening()
        startPingLoop()
    }

    func disconnect() {
        AppLog.debug("WS: Disconnecting", category: .network)
        cancelSupportTasks()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        updateState(.disconnected)
        reconnectAttempts = 0
        activeURL = nil
    }

    func send(_ message: String) async throws {
        guard let task = webSocketTask else {
            throw NetworkError.transportError(
                wrapped: NSError(domain: "WebSocket", code: -1,
                                 userInfo: [NSLocalizedDescriptionKey: "Not connected"])
            )
        }
        try await task.send(.string(message))
    }

    // MARK: - Recursive Listen Loop
    //
    // URLSessionWebSocketTask does NOT auto-repeat receive — you must call
    // .receive() again after each successful message. This recursive pattern
    // is the correct idiomatic approach (not a while loop, which would block).

    private func beginListening() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handle(message: message)
                self.beginListening()           // Re-arm for next message
            case .failure(let error):
                AppLog.error("WS: Receive error — \(error.localizedDescription)", category: .network)
                self.handleConnectionLoss(error: error)
            }
        }
    }

    // MARK: - Message Parsing

    private func handle(message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text):
            guard let d = text.data(using: .utf8) else { return }
            data = d
        case .data(let d):
            data = d
        @unknown default:
            return
        }

        guard let envelope = try? JSONDecoder().decode(WebSocketEnvelope.self, from: data) else {
            AppLog.debug("WS: Could not decode envelope", category: .network)
            return
        }

        dispatch(envelope: envelope)
    }

    private func dispatch(envelope: WebSocketEnvelope) {
        switch envelope.event {
        case "submission_verdict":
            if let submission = envelope.payload?.submission {
                emit(.submissionVerdict(submission: submission))
            }
        case "rating_update":
            if let handle = envelope.payload?.handle, let rating = envelope.payload?.newRating {
                emit(.ratingUpdate(handle: handle, newRating: rating))
            }
        default:
            AppLog.debug("WS: Unknown event type '\(envelope.event)'", category: .network)
        }
    }

    // MARK: - Reconnect with Exponential Backoff

    private func handleConnectionLoss(error: Error) {
        cancelSupportTasks()
        webSocketTask = nil

        guard reconnectAttempts < maxReconnectAttempts, let url = activeURL else {
            AppLog.error("WS: Max reconnect attempts reached or no active URL", category: .network)
            updateState(.disconnected)
            emit(.error(error))
            return
        }

        reconnectAttempts += 1
        let delaySeconds = pow(2.0, Double(reconnectAttempts)) // 2, 4, 8, 16, 32
        AppLog.debug("WS: Reconnecting in \(Int(delaySeconds))s (attempt \(reconnectAttempts))", category: .network)

        updateState(.reconnecting(attempt: reconnectAttempts))

        reconnectTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.openConnection(to: url)
        }
    }

    // MARK: - Ping Loop (keep-alive)

    private func startPingLoop() {
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                guard !Task.isCancelled else { break }
                self?.webSocketTask?.sendPing { error in
                    if let error {
                        AppLog.error("WS: Ping failed — \(error.localizedDescription)", category: .network)
                        self?.handleConnectionLoss(error: error)
                    }
                }
            }
        }
    }

    private func cancelSupportTasks() {
        pingTask?.cancel()
        pingTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    // MARK: - Emission Helpers

    /// Delivers an event to every active continuation.
    private func emit(_ event: WebSocketEvent) {
        lock.withLock {
            eventContinuations.values.forEach { $0.yield(event) }
        }
    }

    /// Updates local state snapshot and delivers the new state to every continuation.
    private func updateState(_ state: WebSocketConnectionState) {
        _currentState = state
        lock.withLock {
            stateContinuations.values.forEach { $0.yield(state) }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension LiveWebSocketService: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        AppLog.debug("WS: Connection opened", category: .network)
        reconnectAttempts = 0
        updateState(.connected)
        emit(.connectionStateChanged(.connected))
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
        AppLog.debug("WS: Connection closed — code: \(closeCode.rawValue), reason: \(reasonStr)", category: .network)
        updateState(.disconnected)
        emit(.connectionStateChanged(.disconnected))
    }
}
