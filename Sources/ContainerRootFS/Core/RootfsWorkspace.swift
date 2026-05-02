import ContainerizationEXT4
import Foundation
import Logging
import SystemPackage

enum RootfsWorkspaceError: LocalizedError {
    case containerNotFound(id: String, root: String)
    case manifestNotFound(id: String, path: String)
    case lowerRootfsNotFound(id: String, path: String)
    case writableLayerNotFound(id: String, path: String)

    var errorDescription: String? {
        switch self {
        case .containerNotFound(let id, let root):
            return "Container workspace '\(id)' was not found under \(root). Run 'container-rootfs bootstrap --container-id \(id) ...' first."
        case .manifestNotFound(let id, let path):
            return "Rootfs manifest for '\(id)' was not found at \(path). Recreate the workspace with 'container-rootfs bootstrap'."
        case .lowerRootfsNotFound(let id, let path):
            return "Lower rootfs for '\(id)' was not found at \(path). Recreate the workspace with 'container-rootfs bootstrap'."
        case .writableLayerNotFound(let id, let path):
            return "Writable layer for '\(id)' was not found at \(path). Recreate it with '--refresh-writable-layer' or rerun bootstrap."
        }
    }
}

struct RootfsWorkspace {
    let root: URL
    let logger: Logger

    func layout(for containerID: String, mode: RootfsMode) -> RootfsLayout {
        RootfsLayout(
            root: root,
            containerID: containerID,
            mode: mode,
            lower: root.appendingPathComponent(containerID, isDirectory: true).appendingPathComponent("lower", isDirectory: true),
            upper: root.appendingPathComponent(containerID, isDirectory: true).appendingPathComponent("upper", isDirectory: true),
            work: root.appendingPathComponent(containerID, isDirectory: true).appendingPathComponent("work", isDirectory: true),
            merged: root.appendingPathComponent(containerID, isDirectory: true).appendingPathComponent("merged", isDirectory: true),
            writableLayer: root.appendingPathComponent(containerID, isDirectory: true).appendingPathComponent("writable.ext4", isDirectory: false)
        )
    }

    func prepare(layout: RootfsLayout) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: layout.containerRoot, withIntermediateDirectories: true)

        switch layout.mode {
        case .rw:
            try fm.createDirectory(at: layout.lower, withIntermediateDirectories: true)
        case .roLayer:
            try fm.createDirectory(at: layout.lower, withIntermediateDirectories: true)
            try createWritableLayer(at: layout.writableLayer)
        }
    }

    func writeManifest(layout: RootfsLayout, imageReference: String) throws {
        let manifest = RootfsManifest(
            containerID: layout.containerID,
            imageReference: imageReference,
            mode: layout.mode,
            root: layout.root.path,
            lower: layout.lower.path,
            upper: layout.upper.path,
            work: layout.work.path,
            merged: layout.merged.path,
            writableLayer: layout.writableLayer.path,
            runtime: layout.runtimeRoot.path,
            createdAt: Date()
        )

        let manifestURL = layout.containerRoot.appendingPathComponent("rootfs-manifest.json", isDirectory: false)
        let data = try JSONEncoder.pretty().encode(manifest)
        try data.write(to: manifestURL, options: [.atomic])
    }

    func prepareRuntimeRoot(layout: RootfsLayout, refresh: Bool = false) throws -> URL {
        guard FileManager.default.fileExists(atPath: layout.lower.path) else {
            throw RootfsWorkspaceError.lowerRootfsNotFound(id: layout.containerID, path: layout.lower.path)
        }

        switch layout.mode {
        case .rw:
            return layout.lower
        case .roLayer:
            if refresh && FileManager.default.fileExists(atPath: layout.writableLayer.path) {
                try FileManager.default.removeItem(at: layout.writableLayer)
            }
            try createWritableLayer(at: layout.writableLayer)
            guard FileManager.default.fileExists(atPath: layout.writableLayer.path) else {
                throw RootfsWorkspaceError.writableLayerNotFound(id: layout.containerID, path: layout.writableLayer.path)
            }
            return layout.lower
        }
    }

    func remove(containerID: String) throws {
        let containerRoot = root.appendingPathComponent(containerID, isDirectory: true)
        guard FileManager.default.fileExists(atPath: containerRoot.path) else { return }
        try FileManager.default.removeItem(at: containerRoot)
    }

    func manifest(containerID: String) throws -> RootfsManifest {
        let containerRoot = root.appendingPathComponent(containerID, isDirectory: true)
        guard FileManager.default.fileExists(atPath: containerRoot.path) else {
            throw RootfsWorkspaceError.containerNotFound(id: containerID, root: root.path)
        }

        let manifestURL = root
            .appendingPathComponent(containerID, isDirectory: true)
            .appendingPathComponent("rootfs-manifest.json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw RootfsWorkspaceError.manifestNotFound(id: containerID, path: manifestURL.path)
        }
        let data = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RootfsManifest.self, from: data)
    }

    private func createWritableLayer(at path: URL, size: UInt64 = 1.gib()) throws {
        let filePath = FilePath(path.path)
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
        let fs = try EXT4.Formatter(filePath, minDiskSize: size)
        try fs.close()
    }
}
