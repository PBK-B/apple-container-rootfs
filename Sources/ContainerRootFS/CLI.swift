import ArgumentParser
import Foundation

struct ContainerRootFSCommand: AsyncParsableCommand {
    private static var rootSubcommands: [any ParsableCommand.Type] {
        var commands: [any ParsableCommand.Type] = [
            Plan.self,
            Inspect.self,
            Remove.self,
            Bootstrap.self,
            Run.self,
        ]

        if #available(macOS 26.0, *) {
            commands.insert(NetworkCommand.self, at: 4)
        }

        return commands
    }

    static let configuration = CommandConfiguration(
        commandName: "rootfs",
        abstract: "Manage host-backed Linux root filesystems",
        subcommands: rootSubcommands,
        defaultSubcommand: Bootstrap.self,
        aliases: ["container-rootfs"]
    )
}

@available(macOS 10.15, *)
@main
struct RootFSMain {
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let normalizedArguments = Self.normalizedArguments(arguments)

        await ContainerRootFSCommand.main(normalizedArguments)
    }

    private static func normalizedArguments(_ arguments: [String]) -> [String] {
        guard let first = arguments.first else {
            return arguments
        }

        let executableName = URL(fileURLWithPath: CommandLine.arguments.first ?? "").lastPathComponent
        let aliases = Set([ContainerRootFSCommand.configuration.commandName, executableName, "container-rootfs", "rootfs"])
        guard aliases.contains(first) else {
            return arguments
        }

        return Array(arguments.dropFirst())
    }
}
