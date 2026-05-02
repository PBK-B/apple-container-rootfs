import ArgumentParser
import Foundation

extension ContainerRootFSCommand {
    struct Plan: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "plan",
            abstract: "Show the workspace layout"
        )

        @Option(name: .long, help: "Container identifier")
        var containerID: String

        @Option(name: .long, help: "Workspace directory")
        var root: String = FileManager.default.currentDirectoryPath + "/containers"

        @Option(name: .long, help: "Workspace mode: rw or ro-layer")
        var mode: RootfsMode = .rw

        func run() throws {
            let workspace = RootfsWorkspace(root: URL(fileURLWithPath: root), logger: .init(label: "container-rootfs.plan"))
            let layout = workspace.layout(for: containerID, mode: mode)
            print(layout.description)
        }
    }
}
