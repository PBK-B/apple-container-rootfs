import ArgumentParser
import Containerization
import ContainerizationOS
import Foundation

extension ContainerRootFSCommand {
    struct Run: AsyncParsableCommand {
        private static let fallbackInitfsReference = "ghcr.io/apple/containerization/vminit:0.31.0"

        static let configuration = CommandConfiguration(
            commandName: "run",
            abstract: "Run a container from a host-backed workspace"
        )

        @Option(name: .long, help: "Container identifier")
        var containerID: String

        @Option(name: .long, help: "Workspace directory")
        var root: String = FileManager.default.currentDirectoryPath + "/containers"

        @Option(name: .long, help: "Path to Linux kernel image")
        var kernel: String?

        @Option(name: .long, help: "Initfs image reference")
        var initfsReference: String?

        @Flag(name: .long, help: "Recreate the writable layer before start")
        var refreshWritableLayer: Bool = false

        @Flag(name: .long, inversion: .prefixedEnableDisable, help: "Allocate a terminal for interactive commands")
        var tty: Bool?

        @Argument(parsing: .remaining, help: "Command to run inside the container")
        var command: [String] = []

        func run() async throws {
            Self.trace("loading workspace")
            let workspace = RootfsWorkspace(root: URL(fileURLWithPath: root), logger: .init(label: "container-rootfs.run"))
            let manifest = try workspace.manifest(containerID: containerID)
            let layout = workspace.layout(for: manifest.containerID, mode: manifest.mode)
            _ = try workspace.prepareRuntimeRoot(layout: layout, refresh: refreshWritableLayer)

            Self.trace("resolving kernel")
            let resolvedKernel = try resolveKernelOrInstallIfNeeded()
            Self.trace("resolving initfs")
            let resolvedInitfsReference = try Self.resolveInitfsReference(explicit: initfsReference)

            let processArguments = command.isEmpty ? ["/bin/sh"] : command
            let executable = processArguments[0]
            let arguments = Array(processArguments.dropFirst())
            let shouldUseTTY = resolveTTY(executable: executable)

            let terminal = shouldUseTTY ? try? Terminal.current : nil
            if shouldUseTTY, let terminal {
                try terminal.setraw()
            }
            defer { terminal?.tryReset() }

            Self.trace("preparing mounts")
            let rootfs = Containerization.Mount.share(source: layout.lower.path, destination: "/", options: manifest.mode == .roLayer ? ["ro"] : [])
            let writableLayer: Containerization.Mount? = manifest.mode == .roLayer
                ? Containerization.Mount.block(format: "ext4", source: layout.writableLayer.path, destination: "/", options: [])
                : nil

            Self.trace("initializing manager")
            let managerRoot = URL(fileURLWithPath: root).appendingPathComponent("runtime", isDirectory: true)
            let managerContainerRoot = managerRoot
                .appendingPathComponent("containers", isDirectory: true)
                .appendingPathComponent(containerID, isDirectory: true)
            try FileManager.default.createDirectory(at: managerContainerRoot, withIntermediateDirectories: true)

            var manager = try await ContainerManager(
                kernel: Kernel(path: URL(fileURLWithPath: resolvedKernel), platform: .linuxArm),
                initfsReference: resolvedInitfsReference,
                root: managerRoot
            )
            Self.trace("loading image")
            let image = try await manager.imageStore.get(reference: manifest.imageReference, pull: true)

            do {
                Self.trace("creating container")
                let container = try await manager.create(containerID, image: image, rootfs: rootfs, writableLayer: writableLayer, networking: false) { config in
                    config.process.arguments = [executable] + arguments
                    config.process.workingDirectory = "/"
                    if shouldUseTTY, let terminal {
                        config.process.setTerminalIO(terminal: terminal)
                    }
                }
                Self.trace("container created")

                Self.trace("creating VM resources")
                try await container.create()
                Self.trace("starting container")
                try await container.start()
                Self.trace("container started")

                if let terminal, let size = try? terminal.size {
                    try? await container.resize(to: size)
                }

                Self.trace("waiting for container")
                let status = try await container.wait()
                Self.trace("container exited")
                try await container.stop()

                if status.exitCode != 0 {
                    throw ExitCode(status.exitCode)
                }
            } catch {
                Self.trace("run failed: \(String(reflecting: error))")
                throw error
            }
        }

        private static func trace(_ message: String) {
            let text = "[container-rootfs] \(message)\n"
            if let data = text.data(using: .utf8) {
                FileHandle.standardError.write(data)
            }
        }

        private static func resolveInitfsReference(explicit: String?) throws -> String {
            if let explicit, !explicit.isEmpty {
                return explicit
            }

            if let configured = try ContainerSystemPropertyResolver.get("image.init") {
                return configured
            }

            return Self.fallbackInitfsReference
        }

        private func resolveKernelOrInstallIfNeeded() throws -> String {
            do {
                return try KernelResolver.resolve(explicitPath: kernel)
            } catch KernelResolutionError.notFound where kernel == nil {
                try KernelInstaller.promptAndInstallRecommendedKernel()
                return try KernelResolver.resolve(explicitPath: nil)
            }
        }

        private func resolveTTY(executable: String) -> Bool {
            if let tty {
                return tty
            }

            let shellNames = ["sh", "ash", "bash", "zsh"]
            let executableName = URL(fileURLWithPath: executable).lastPathComponent
            return shellNames.contains(executableName)
        }
    }
}
