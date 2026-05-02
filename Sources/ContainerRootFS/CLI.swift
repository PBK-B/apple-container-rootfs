import ArgumentParser

@available(macOS 10.15, *)
@main
struct ContainerRootFSCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "container-rootfs",
        abstract: "Manage host-backed Linux root filesystems",
        subcommands: [
            Plan.self,
            Inspect.self,
            Remove.self,
            Bootstrap.self,
            Run.self,
        ],
        defaultSubcommand: Bootstrap.self
    )
}
