import ContainerizationOCI
import Foundation

enum KernelResolver {
    static let environmentVariable = "CONTAINER_ROOTFS_KERNEL"

    static func resolve(explicitPath: String?) throws -> String {
        if let explicitPath, !explicitPath.isEmpty {
            try validateExists(explicitPath)
            return explicitPath
        }

        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath
        let appRoot = (try? ContainerSystemPropertyResolver.getAppRoot()) ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("com.apple.container")

        let propertyPath = try? ContainerSystemPropertyResolver.get("kernel.binaryPath")
        let propertyCandidates = propertyPath.map { resolvePropertyPath($0, appRoot: appRoot) } ?? []
        let envPath = ProcessInfo.processInfo.environment[environmentVariable].map { [$0] } ?? []

        let candidates = (
            envPath
            + propertyCandidates
            + [
                URL(fileURLWithPath: cwd).appendingPathComponent("vmlinux").path,
                URL(fileURLWithPath: cwd).appendingPathComponent("bin/vmlinux").path,
                "/opt/kata/share/kata-containers/vmlinux.container",
                "/opt/kata/share/kata-containers/vmlinux-6.18.15-186",
            ]
        ).unique()

        for candidate in candidates where fm.fileExists(atPath: candidate) {
            return candidate
        }

        throw KernelResolutionError.notFound(candidates: candidates)
    }

    private static func validateExists(_ path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw KernelResolutionError.missingExplicitPath(path: path)
        }
    }

    private static func resolvePropertyPath(_ value: String, appRoot: URL?) -> [String] {
        if value.hasPrefix("/") {
            return [value]
        }

        var results: [String] = []
        if let appRoot {
            let name = URL(fileURLWithPath: value).lastPathComponent
            let arch = ContainerizationOCI.Platform.current.architecture
            results.append(appRoot.appendingPathComponent("kernels").appendingPathComponent("default.kernel-\(arch)").path)
            results.append(appRoot.appendingPathComponent("kernels").appendingPathComponent(name).path)
            results.append(appRoot.appendingPathComponent("kernels").appendingPathComponent(value).path)
        }
        results.append(URL(fileURLWithPath: "/").appendingPathComponent(value).path)
        results.append(value)
        return results
    }
}

enum KernelResolutionError: LocalizedError {
    case missingExplicitPath(path: String)
    case notFound(candidates: [String])
    case promptInputUnavailable
    case installationDeclined
    case installationFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .missingExplicitPath(let path):
            return "Kernel not found at path: \(path)"
        case .notFound(let candidates):
            let joined = candidates.joined(separator: ", ")
            return "No kernel found. Provide --kernel, set CONTAINER_ROOTFS_KERNEL, configure container system property 'kernel.binaryPath', or place a kernel at one of: \(joined)"
        case .promptInputUnavailable:
            return "Unable to read user input while asking to install the recommended kernel."
        case .installationDeclined:
            return "Kernel installation was declined by the user."
        case .installationFailed(let message):
            return "Failed to install the recommended kernel: \(message)"
        }
    }
}

private extension Array where Element == String {
    func unique() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
