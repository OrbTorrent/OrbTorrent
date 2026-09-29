import Foundation

/// Component versions reported by `GET /api/v2/app/buildInfo`.
struct BuildInfo: Sendable, Decodable, Equatable {
    let qt: String
    let libtorrent: String
    let boost: String
    let openssl: String

    private enum CodingKeys: String, CodingKey {
        case qt, libtorrent, boost, openssl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        qt = c.value(.qt, default: "")
        libtorrent = c.value(.libtorrent, default: "")
        boost = c.value(.boost, default: "")
        openssl = c.value(.openssl, default: "")
    }
}
