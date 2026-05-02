import Containerization
import ContainerizationExtras
import Foundation

@available(macOS 26.0, *)
struct NamedNetwork {
    let manifest: NetworkManifest
    let resourceRoot: URL

    var manifestPath: URL {
        resourceRoot.appendingPathComponent("\(manifest.name).json", isDirectory: false)
    }

    static func ensure(name: String, root: URL) throws -> NamedNetwork {
        let networksRoot = root.appendingPathComponent("networks", isDirectory: true)
        try FileManager.default.createDirectory(at: networksRoot, withIntermediateDirectories: true)

        let path = networksRoot.appendingPathComponent("\(name).json", isDirectory: false)
        if FileManager.default.fileExists(atPath: path.path) {
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let manifest = try decoder.decode(NetworkManifest.self, from: data)
            return NamedNetwork(manifest: manifest, resourceRoot: networksRoot)
        }

        let manifest = NetworkManifest(name: name, mode: "nat", createdAt: Date())
        let encoder = JSONEncoder.pretty()
        let data = try encoder.encode(manifest)
        try data.write(to: path, options: .atomic)
        return NamedNetwork(manifest: manifest, resourceRoot: networksRoot)
    }

    func makeNetwork() throws -> any Network {
        switch manifest.mode {
        case "nat":
            return try VmnetNetwork()
        default:
            throw NamedNetworkError.unsupportedMode(manifest.mode)
        }
    }
}

enum NamedNetworkError: LocalizedError {
    case unsupportedMode(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedMode(let mode):
            return "Unsupported network mode: \(mode)"
        }
    }
}
