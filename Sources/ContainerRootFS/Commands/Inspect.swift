import ArgumentParser
import Foundation

extension ContainerRootFSCommand {
    struct Inspect: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "inspect",
            abstract: "Print workspace metadata"
        )

        @Option(name: .long, help: "Container identifier")
        var containerID: String

        @Option(name: .long, help: "Workspace directory")
        var root: String = FileManager.default.currentDirectoryPath + "/containers"

        func run() throws {
            let workspace = RootfsWorkspace(root: URL(fileURLWithPath: root), logger: .init(label: "rootfs.inspect"))
            let manifest = try workspace.manifest(containerID: containerID)
            let output = InspectOutput(workspace: manifest, lastRun: try workspace.lastRun(containerID: containerID))
            let data = try JSONEncoder.pretty().encode(output)
            print(String(decoding: data, as: UTF8.self))
        }
    }
}
