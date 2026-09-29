import Foundation

enum APIError: LocalizedError, Sendable {
    /// The engine isn't accepting connections (starting, stopped or crashed).
    case unreachable
    /// The engine rejected OrbTorrent's credentials.
    case unauthorized
    case http(status: Int, body: String)
    case invalidResponse
    case decoding(String)
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .unreachable:
            "The download engine isn't running."
        case .unauthorized:
            "OrbTorrent couldn't sign in to its download engine."
        case .http(let status, let body):
            body.isEmpty ? "The engine returned an error (\(status))." : body
        case .invalidResponse:
            "The engine sent an unexpected response."
        case .decoding(let detail):
            "The engine sent data OrbTorrent couldn't read: \(detail)"
        case .rejected(let reason):
            reason
        }
    }
}

extension Error {
    /// Whether this is work being called off, such as a request whose screen
    /// closed, rather than something going wrong. It's never worth an alert.
    var isCancellation: Bool {
        self is CancellationError || (self as? URLError)?.code == .cancelled
    }
}
