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
/// `@unchecked Sendable`: All mutable state is accessed under `lock` (continuation dictionaries)
/// or exclusively from the URLSession delegate queue (webSocketTask, activeURL, reconnectAttempts).
/// `_currentState` is always read and written under `lock` to prevent data races across
/// concurrent callers (ViewModels, connect/disconnect, ping callbacks, delegate queue).
final class LiveWebSocketService: NSObject, WebSocketServiceProtocol, @unchecked Sendable {

    // MARK: - Continuation Dictionaries

    /// All active event stream continuations.
    private var eventContinuations: [UUID: AsyncStream<WebSocketEvent>.Continuation] = [:]

    /// All active connection-state stream continuations.
    private var stateContinuations: [UUID: AsyncStream<WebSocketConnectionState>.Continuation] = [:]

    /// Guards ALL shared mutable state: continuation dictionaries and `_currentState`.
    private let lock = NSLock()

    /// Current connection state. MUST only be read or written under `lock`.
    private var _currentState: WebSocketConnectionState = .disconnected

    // MARK: - WebSocketServiceProtocol

    /// Each call returns an independent `AsyncStream` so multiple observers
    /// (e.g. different Repositories) can each iterate their own sequence.
    var eventStream: AsyncStream<WebSocketEvent> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock { eventContinuations[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.eventContinuations.removeValue(forKey: id) }
            }
        }
    }

    /// Yields the current state immediately (cold-observable semantics matching
    /// `CurrentValueSubject`), then all subsequent state changes.
    ///
    /// The state snapshot and the continuation registration are performed atomically
    /// under `lock`, preventing a race where a transition fires between the two.
    var connectionStateStream: AsyncStream<WebSocketConnectionState> {
        AsyncStream { continuation in
            let id = UUID()
            // Atomic: register continuation AND read current state in the same lock region
            // so no state transition can slip between the two operations.
            let current: WebSocketConnectionState = lock.withLock {
                stateContinuations[id] = continuation
                return _currentState
            }
            continuation.yield(current)         // emit OUTSIDE lock — no deadlock risk
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.stateContinuations.removeValue(forKey: id) }
            }
        }
    }

    /// Synchronous snapshot — for initial ViewModel binding before the async loop starts.
    var currentState: WebSocketConnectionState {
        lock.withLock { _currentState }
    }

    // MARK: - Internal State (delegate-queue serialised)

    private var webSocketTask: URLSessionWebSocketTask?
    private var activeURL: URL?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Connection Lifecycle

    func connect(to url: URL) {
        guard currentState == .disconnected else {
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

    /// Delivers an event to every active continuation. Emission is done OUTSIDE
    /// the lock to avoid any potential deadlock with the termination handler.
    private func emit(_ event: WebSocketEvent) {
        let continuations = lock.withLock { Array(eventContinuations.values) }
        continuations.forEach { $0.yield(event) }
    }

    /// Updates the state snapshot (under lock) and delivers the new state to all
    /// active continuations (outside the lock).
    private func updateState(_ state: WebSocketConnectionState) {
        let continuations: [AsyncStream<WebSocketConnectionState>.Continuation] = lock.withLock {
            _currentState = state
            return Array(stateContinuations.values)
        }
        continuations.forEach { $0.yield(state) }
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
