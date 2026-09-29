import Foundation

/// Builds a `multipart/form-data` request body.
struct MultipartForm: Sendable {
    let boundary = "OrbTorrent-\(UUID().uuidString)"
    private var body = Data()

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    mutating func add(_ name: String, _ value: String) {
        appendLine("--\(boundary)")
        appendLine("Content-Disposition: form-data; name=\"\(name)\"")
        appendLine("")
        appendLine(value)
    }

    mutating func addFile(_ name: String, filename: String, contentType: String, data: Data) {
        let safeName = filename.replacingOccurrences(of: "\"", with: "'")
        appendLine("--\(boundary)")
        appendLine("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(safeName)\"")
        appendLine("Content-Type: \(contentType)")
        appendLine("")
        body.append(data)
        appendLine("")
    }

    func finalized() -> Data {
        var result = body
        result.append(Data("--\(boundary)--\r\n".utf8))
        return result
    }

    private mutating func appendLine(_ line: String) {
        body.append(Data((line + "\r\n").utf8))
    }
}
