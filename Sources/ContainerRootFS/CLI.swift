import ArgumentParser

@available(macOS 10.15, *)
@main
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
        commandName: "container-rootfs",
        abstract: "Manage host-backed Linux root filesystems",
        subcommands: rootSubcommands,
        defaultSubcommand: Bootstrap.self
    )
}
