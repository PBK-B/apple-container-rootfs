import ArgumentParser
import Foundation

extension ContainerRootFSCommand {
    @available(macOS 26.0, *)
    struct NetworkCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "network",
            abstract: "Manage named networks",
            subcommands: [Create.self, List.self, Inspect.self, Remove.self]
        )
    }
}

@available(macOS 26.0, *)
extension ContainerRootFSCommand.NetworkCommand {
    struct Create: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "create", abstract: "Create a named network")

        @Argument var name: String
        @Option(name: .long, help: "Runtime root")
        var root: String = FileManager.default.currentDirectoryPath + "/containers/runtime"

        func run() throws {
            _ = try NamedNetwork.ensure(name: name, root: URL(fileURLWithPath: root))
            print(name)
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "ls", abstract: "List named networks")

        @Option(name: .long, help: "Runtime root")
        var root: String = FileManager.default.currentDirectoryPath + "/containers/runtime"

        func run() throws {
            let networksRoot = URL(fileURLWithPath: root).appendingPathComponent("networks", isDirectory: true)
            guard FileManager.default.fileExists(atPath: networksRoot.path) else { return }
            let files = try FileManager.default.contentsOfDirectory(at: networksRoot, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "json" {
                print(file.deletingPathExtension().lastPathComponent)
            }
        }
    }

    struct Inspect: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "inspect", abstract: "Inspect a named network")

        @Argument var name: String
        @Option(name: .long, help: "Runtime root")
        var root: String = FileManager.default.currentDirectoryPath + "/containers/runtime"

        func run() throws {
            let network = try NamedNetwork.ensure(name: name, root: URL(fileURLWithPath: root))
            let data = try Data(contentsOf: network.manifestPath)
            print(String(decoding: data, as: UTF8.self))
        }
    }

    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "rm", abstract: "Remove a named network")

        @Argument var name: String
        @Option(name: .long, help: "Runtime root")
        var root: String = FileManager.default.currentDirectoryPath + "/containers/runtime"

        func run() throws {
            let path = URL(fileURLWithPath: root)
                .appendingPathComponent("networks", isDirectory: true)
                .appendingPathComponent("\(name).json", isDirectory: false)
            if FileManager.default.fileExists(atPath: path.path) {
                try FileManager.default.removeItem(at: path)
            }
        }
    }
}
