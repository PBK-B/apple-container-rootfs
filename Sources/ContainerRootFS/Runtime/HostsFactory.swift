import Containerization
import Foundation

enum HostsFactory {
    static func makeHosts(entries: [String]) throws -> Hosts? {
        guard !entries.isEmpty else {
            return nil
        }

        let mapped = try entries.map(parseEntry)
        return Hosts(entries: mapped, comment: "managed by rootfs")
    }

    private static func parseEntry(_ raw: String) throws -> Hosts.Entry {
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            throw HostsFactoryError.invalidEntry(raw)
        }

        return Hosts.Entry(ipAddress: parts[1], hostnames: [parts[0]])
    }
}

enum HostsFactoryError: LocalizedError {
    case invalidEntry(String)

    var errorDescription: String? {
        switch self {
        case .invalidEntry(let value):
            return "Invalid host entry: \(value). Expected hostname:ip"
        }
    }
}
