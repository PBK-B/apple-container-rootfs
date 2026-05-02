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

        @Option(name: .long, help: "Bind mount in the form /host:/container[:ro]")
        var bind: [String] = []

        @Option(name: .long, help: "Mount specification in the form type=bind,source=...,target=...[,readonly]")
        var mount: [String] = []

        @Option(name: .long, help: "Named network to attach to")
        var network: String?

        @Option(name: .long, help: "Environment variable in the form KEY=VALUE")
        var env: [String] = []

        @Option(name: .long, help: "Working directory inside the container")
        var workdir: String?

        @Option(name: .long, help: "Number of virtual CPUs")
        var cpus: Int?

        @Option(name: .long, help: "Memory limit, e.g. 512m or 1g")
        var memory: String?

        @Option(name: .long, help: "DNS nameserver")
        var dns: [String] = []

        @Option(name: .customLong("dns-search"), help: "DNS search domain")
        var dnsSearch: [String] = []

        @Option(name: .customLong("dns-option"), help: "DNS resolver option")
        var dnsOption: [String] = []

        @Option(name: .customLong("add-host"), help: "Static host entry in the form hostname:ip")
        var addHost: [String] = []

        @Flag(name: .long, inversion: .prefixedEnableDisable, help: "Allocate a terminal for interactive commands")
        var tty: Bool?

        @Argument(parsing: .remaining, help: "Command to run inside the container")
        var command: [String] = []

        func run() async throws {
            try ContainerIDValidator.validate(containerID)
            Self.trace("loading workspace")
            let workspaceRoot = URL(fileURLWithPath: root)
            let workspace = RootfsWorkspace(root: workspaceRoot, logger: .init(label: "rootfs.run"))
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
            let extraMounts = try MountFactory.makeMounts(bindMounts: bind, mountSpecs: mount)
            let hosts = try HostsFactory.makeHosts(entries: addHost)
            let dnsConfig = dns.isEmpty && dnsSearch.isEmpty && dnsOption.isEmpty
                ? nil
                : DNS(nameservers: dns.isEmpty ? DNS.defaultNameservers : dns, searchDomains: dnsSearch, options: dnsOption)
            try dnsConfig?.validate()
            let memoryInBytes = try memory.map { try MemoryParser.parse($0) }

            Self.trace("initializing manager")
            let managerRoot = RuntimePaths.runtimeRoot(in: workspaceRoot)
            let managerContainerRoot = RuntimePaths.managerContainersRoot(in: workspaceRoot)
                .appendingPathComponent(containerID, isDirectory: true)
            try FileManager.default.createDirectory(at: managerContainerRoot, withIntermediateDirectories: true)

            let runtimeManager: ContainerManager
            if network == "none" {
                runtimeManager = try await ContainerManager(
                    kernel: Kernel(path: URL(fileURLWithPath: resolvedKernel), platform: .linuxArm),
                    initfsReference: resolvedInitfsReference,
                    root: managerRoot
                )
            } else if #available(macOS 26.0, *), let network {
                let namedNetwork = try NamedNetwork.ensure(name: network, root: managerRoot)
                runtimeManager = try await ContainerManager(
                    kernel: Kernel(path: URL(fileURLWithPath: resolvedKernel), platform: .linuxArm),
                    initfsReference: resolvedInitfsReference,
                    root: managerRoot,
                    network: try namedNetwork.makeNetwork()
                )
            } else {
                runtimeManager = try await ContainerManager(
                    kernel: Kernel(path: URL(fileURLWithPath: resolvedKernel), platform: .linuxArm),
                    initfsReference: resolvedInitfsReference,
                    root: managerRoot
                )
            }
            var manager = runtimeManager
            Self.trace("loading image")
            let image = try await manager.imageStore.get(reference: manifest.imageReference, pull: true)

            do {
                Self.trace("creating container")
                let container = try await manager.create(containerID, image: image, rootfs: rootfs, writableLayer: writableLayer, networking: network != "none") { config in
                    config.process.arguments = [executable] + arguments
                    config.process.workingDirectory = workdir ?? "/"
                    config.process.environmentVariables.append(contentsOf: env)
                    if let cpus {
                        config.cpus = cpus
                    }
                    if let memoryInBytes {
                        config.memoryInBytes = memoryInBytes
                    }
                    config.mounts.append(contentsOf: extraMounts)
                    config.hosts = hosts
                    config.dns = dnsConfig
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

                try workspace.writeLastRun(
                    containerID: containerID,
                    configuration: LastRunConfiguration(
                        command: processArguments,
                        tty: shouldUseTTY,
                        kernel: resolvedKernel,
                        initfsReference: resolvedInitfsReference,
                        network: network,
                        bindMounts: bind,
                        mountSpecs: mount,
                        dns: dns,
                        dnsSearch: dnsSearch,
                        dnsOptions: dnsOption,
                        hosts: addHost,
                        environment: env,
                        workingDirectory: workdir,
                        cpus: cpus,
                        memory: memory,
                        recordedAt: Date()
                    )
                )
            } catch {
                Self.trace("run failed: \(String(reflecting: error))")
                throw error
            }
        }

        private static func trace(_ message: String) {
            let text = "[rootfs] \(message)\n"
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
