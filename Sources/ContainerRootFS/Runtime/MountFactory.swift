import Containerization
import Foundation

enum MountFactory {
    static func makeMounts(bindMounts: [String], mountSpecs: [String]) throws -> [Containerization.Mount] {
        var mounts: [Containerization.Mount] = []
        mounts.append(contentsOf: try bindMounts.map(parseBind))
        mounts.append(contentsOf: try mountSpecs.map(parseMountSpec))
        return mounts
    }

    private static func parseBind(_ raw: String) throws -> Containerization.Mount {
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2 || parts.count == 3 else {
            throw MountFactoryError.invalidBind(raw)
        }

        let source = parts[0]
        let destination = parts[1]
        let readonly = parts.count == 3 && parts[2] == "ro"
        let options = readonly ? ["ro"] : []
        return .share(source: source, destination: destination, options: options)
    }

    private static func parseMountSpec(_ raw: String) throws -> Containerization.Mount {
        let pairs = raw.split(separator: ",").map(String.init)
        var type: String?
        var source: String?
        var target: String?
        var readonly = false

        for pair in pairs {
            if pair == "readonly" || pair == "ro" {
                readonly = true
                continue
            }

            let pieces = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard pieces.count == 2 else {
                throw MountFactoryError.invalidMount(raw)
            }

            switch pieces[0] {
            case "type":
                type = pieces[1]
            case "source", "src":
                source = pieces[1]
            case "target", "destination", "dst":
                target = pieces[1]
            default:
                continue
            }
        }

        guard type == "bind", let source, let target else {
            throw MountFactoryError.invalidMount(raw)
        }

        let options = readonly ? ["ro"] : []
        return .share(source: source, destination: target, options: options)
    }
}

enum MountFactoryError: LocalizedError {
    case invalidBind(String)
    case invalidMount(String)

    var errorDescription: String? {
        switch self {
        case .invalidBind(let value):
            return "Invalid bind mount: \(value). Expected /host/path:/container/path[:ro]"
        case .invalidMount(let value):
            return "Invalid mount specification: \(value). Expected type=bind,source=...,target=...[,readonly]"
        }
    }
}
