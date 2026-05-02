import Foundation

enum RuntimePaths {
    static let runtimeDirectoryName = ".runtime"
    static let imageStoreDirectoryName = "images"
    static let networksDirectoryName = "networks"
    static let containersDirectoryName = "containers"

    static func runtimeRoot(in workspaceRoot: URL) -> URL {
        workspaceRoot.appendingPathComponent(runtimeDirectoryName, isDirectory: true)
    }

    static func imageStoreRoot(in workspaceRoot: URL) -> URL {
        runtimeRoot(in: workspaceRoot).appendingPathComponent(imageStoreDirectoryName, isDirectory: true)
    }

    static func networksRoot(in workspaceRoot: URL) -> URL {
        runtimeRoot(in: workspaceRoot).appendingPathComponent(networksDirectoryName, isDirectory: true)
    }

    static func managerContainersRoot(in workspaceRoot: URL) -> URL {
        runtimeRoot(in: workspaceRoot).appendingPathComponent(containersDirectoryName, isDirectory: true)
    }

    static func defaultRuntimeRootPath(from currentDirectoryPath: String) -> String {
        runtimeRoot(in: URL(fileURLWithPath: currentDirectoryPath).appendingPathComponent("containers", isDirectory: true)).path
    }
}
