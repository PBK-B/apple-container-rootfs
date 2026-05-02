import ContainerizationArchive
import ContainerizationOCI
import Foundation

enum KernelInstaller {
    private static let fallbackKernelURL = "https://github.com/kata-containers/kata-containers/releases/download/3.28.0/kata-static-3.28.0-arm64.tar.zst"
    private static let fallbackKernelBinaryPath = "opt/kata/share/kata-containers/vmlinux-6.18.15-186"

    static func promptAndInstallRecommendedKernel() throws {
        let kernelURL = try ContainerSystemPropertyResolver.get("kernel.url") ?? Self.fallbackKernelURL
        if isatty(STDIN_FILENO) == 1 {
            print("No default kernel configured.")
            print("Install the recommended default kernel from [\(kernelURL)]? [Y/n]: ", terminator: "")

            guard let answer = readLine(strippingNewline: true) else {
                throw KernelResolutionError.promptInputUnavailable
            }

            guard answer.isEmpty || answer.lowercased() == "y" else {
                throw KernelResolutionError.installationDeclined
            }
        } else {
            print("No default kernel configured; installing the recommended kernel automatically...")
        }

        try installRecommendedKernel()
    }

    static func installRecommendedKernel() throws {
        let kernelURL = try ContainerSystemPropertyResolver.get("kernel.url") ?? Self.fallbackKernelURL
        let kernelBinaryPath = try ContainerSystemPropertyResolver.get("kernel.binaryPath") ?? Self.fallbackKernelBinaryPath
        let appRoot = try resolvedAppRoot()
        let kernelsRoot = appRoot.appendingPathComponent("kernels", isDirectory: true)
        try FileManager.default.createDirectory(at: kernelsRoot, withIntermediateDirectories: true)

        print("Downloading recommended kernel archive...")

        let archiveURL = try downloadedArchive(from: kernelURL)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        print("Installing kernel from archive member \(kernelBinaryPath)...")
        let archiveReader = try ArchiveReader(file: archiveURL)
        let (_, data) = try archiveReader.extractFile(path: kernelBinaryPath)

        let kernelName = URL(fileURLWithPath: kernelBinaryPath).lastPathComponent
        let installedKernelURL = kernelsRoot.appendingPathComponent(kernelName)
        try data.write(to: installedKernelURL, options: .atomic)

        let platform = ContainerizationOCI.Platform.current
        let defaultKernelURL = kernelsRoot.appendingPathComponent("default.kernel-\(platform.architecture)")
        try? FileManager.default.removeItem(at: defaultKernelURL)
        try FileManager.default.createSymbolicLink(at: defaultKernelURL, withDestinationURL: installedKernelURL)

        print("Installed recommended kernel at \(installedKernelURL.path)")
    }

    private static func resolvedAppRoot() throws -> URL {
        if let appRoot = try ContainerSystemPropertyResolver.getAppRoot() {
            return appRoot
        }
        return ContainerSystemPropertyResolver.defaultAppRoot()
    }

    private static func downloadedArchive(from source: String) throws -> URL {
        let url: URL
        if let parsed = URL(string: source), let scheme = parsed.scheme, !scheme.isEmpty {
            url = parsed
        } else {
            url = URL(fileURLWithPath: source, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardizedFileURL
        }

        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        if url.isFileURL {
            let data = try Data(contentsOf: url)
            try data.write(to: destination, options: .atomic)
            return destination
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["curl", "-fL", url.absoluteString, "-o", destination.path]

        let stderr = Pipe()
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw KernelResolutionError.installationFailed(message: "failed to launch curl: \(error.localizedDescription)")
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw KernelResolutionError.installationFailed(message: errorText.isEmpty ? "failed to download kernel archive from \(url)" : errorText)
        }

        return destination
    }
}
