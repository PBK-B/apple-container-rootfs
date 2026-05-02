import ArgumentParser
import ContainerizationOCI
import Foundation
import Logging

extension ContainerRootFSCommand {
    struct Bootstrap: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "bootstrap",
            abstract: "Pull an OCI image and create a host-backed workspace"
        )

        @Option(name: .long, help: "OCI image reference")
        var image: String

        @Option(name: .long, help: "Container identifier")
        var containerID: String

        @Option(name: .long, help: "Workspace directory")
        var root: String = FileManager.default.currentDirectoryPath + "/containers"

        @Option(name: .long, help: "Workspace mode: rw or ro-layer")
        var mode: RootfsMode = .rw

        @Option(name: .long, help: "OCI platform, e.g. linux/arm64")
        var platform: String = "linux/arm64"

        func run() async throws {
            let workspace = RootfsWorkspace(root: URL(fileURLWithPath: root), logger: Logger(label: "rootfs.bootstrap"))
            let layout = workspace.layout(for: containerID, mode: mode)

            try workspace.prepare(layout: layout)
            let builder = try RootfsBuilder(storeRoot: workspace.root.appendingPathComponent("image-store", isDirectory: true), logger: Logger(label: "rootfs.bootstrap"))
            try await builder.build(imageReference: image, platform: try Platform(from: platform), layout: layout)
            try workspace.writeManifest(layout: layout, imageReference: image)

            print(layout.description)
        }
    }
}
