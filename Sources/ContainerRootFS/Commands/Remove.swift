import ArgumentParser
import Foundation

extension ContainerRootFSCommand {
    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "remove",
            abstract: "Remove a workspace"
        )

        @Option(name: .long, help: "Container identifier")
        var containerID: String

        @Option(name: .long, help: "Workspace directory")
        var root: String = FileManager.default.currentDirectoryPath + "/containers"

        func run() throws {
            try ContainerIDValidator.validate(containerID)
            let workspace = RootfsWorkspace(root: URL(fileURLWithPath: root), logger: .init(label: "rootfs.remove"))
            try workspace.remove(containerID: containerID)
        }
    }
}
