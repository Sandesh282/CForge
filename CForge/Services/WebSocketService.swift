import Foundation

// MARK: - Connection State

enum WebSocketConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)

    var isLive: Bool { self == .connected }

    var displayLabel: String {
        switch self {
        case .connected:          return "Live"
        case .connecting:         return "Connecting..."
        case .reconnecting:       return "Reconnecting..."
        case .disconnected:       return "Offline"
        }
    }
}

// MARK: - Domain Events

/// All possible events the WebSocket layer can emit to the rest of the app.
/// New event types are added here first — the rest of the app remains unaware
/// of the raw wire format.
///
/// Conforms to `Sendable` so it can safely cross actor boundaries inside
/// `AsyncStream` continuations.
enum WebSocketEvent: Sendable {
    case submissionVerdict(submission: Submission)
    case ratingUpdate(handle: String, newRating: Int)
    case connectionStateChanged(WebSocketConnectionState)
    case error(Error)
}

// MARK: - Wire Envelope

/// Raw JSON envelope that arrives over the wire. The `event` field is a
/// discriminator; `payload` is re-decoded based on that discriminator.
struct WebSocketEnvelope: Decodable {
    let event: String
    let payload: PayloadContainer?

    struct PayloadContainer: Decodable {
        // Submission verdict fields
        let submission: Submission?
        // Rating update fields
        let handle: String?
        let newRating: Int?
    }
}

// MARK: - Protocol

/// Pure Swift-Concurrency WebSocket contract.
///
/// Callers receive events through `eventStream` — an `AsyncStream` that they
/// can iterate with `for await event in service.eventStream { … }` from any
/// async context.  No Combine dependency is required by consumers.
protocol WebSocketServiceProtocol: AnyObject, Sendable {
    /// An `AsyncStream` of typed domain events. Multiple callers can each
    /// obtain their own stream via repeated property access; each call yields
    /// an independent stream backed by its own continuation.
    var eventStream: AsyncStream<WebSocketEvent> { get }

    /// Current connection state as an `AsyncStream`.  Yields the current
    /// value immediately upon subscription (cold observable equivalent).
    var connectionStateStream: AsyncStream<WebSocketConnectionState> { get }

    /// Synchronous snapshot of the current connection state — useful for
    /// initial binding before the async loop runs.
    var currentState: WebSocketConnectionState { get }

    func connect(to url: URL)
    func disconnect()
    func send(_ message: String) async throws
}
