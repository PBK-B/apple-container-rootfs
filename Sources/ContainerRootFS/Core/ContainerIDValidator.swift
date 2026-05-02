import Foundation

enum ContainerIDValidator {
    static let reservedIDs: Set<String> = [RuntimePaths.runtimeDirectoryName]

    static func validate(_ containerID: String) throws {
        guard !reservedIDs.contains(containerID) else {
            throw ContainerIDValidationError.reservedID(containerID)
        }
    }
}

enum ContainerIDValidationError: LocalizedError {
    case reservedID(String)

    var errorDescription: String? {
        switch self {
        case .reservedID(let containerID):
            return "Container identifier '\(containerID)' is reserved for internal runtime data and cannot be used with --container-id."
        }
    }
}
