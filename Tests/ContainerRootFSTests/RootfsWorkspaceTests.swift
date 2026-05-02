import XCTest
@testable import ContainerRootFS

final class RootfsWorkspaceTests: XCTestCase {
    func testManifestRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let workspace = RootfsWorkspace(root: root, logger: .init(label: "test"))
        let layout = workspace.layout(for: "abc123", mode: .rw)
        try workspace.prepare(layout: layout)
        try workspace.writeManifest(layout: layout, imageReference: "docker.io/library/alpine:latest")

        let manifest = try workspace.manifest(containerID: "abc123")
        XCTAssertEqual(manifest.containerID, "abc123")
        XCTAssertEqual(manifest.imageReference, "docker.io/library/alpine:latest")
        XCTAssertEqual(manifest.mode, .rw)
        XCTAssertEqual(manifest.runtime, layout.lower.path)
    }

    func testRoLayerCreatesWritableLayer() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let workspace = RootfsWorkspace(root: root, logger: .init(label: "test"))
        let layout = workspace.layout(for: "abc123", mode: .roLayer)
        try workspace.prepare(layout: layout)

        XCTAssertTrue(FileManager.default.fileExists(atPath: layout.lower.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: layout.writableLayer.path))
    }

    func testManifestFailsWhenWorkspaceIsMissing() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let workspace = RootfsWorkspace(root: root, logger: .init(label: "test"))

        XCTAssertThrowsError(try workspace.manifest(containerID: "missing")) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Container workspace 'missing' was not found under \(root.path). Run 'container-rootfs bootstrap --container-id missing ...' first."
            )
        }
    }

    func testManifestFailsWhenManifestFileIsMissing() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let workspace = RootfsWorkspace(root: root, logger: .init(label: "test"))
        let layout = workspace.layout(for: "abc123", mode: .rw)
        try FileManager.default.createDirectory(at: layout.containerRoot, withIntermediateDirectories: true)

        XCTAssertThrowsError(try workspace.manifest(containerID: "abc123")) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Rootfs manifest for 'abc123' was not found at \(layout.containerRoot.appendingPathComponent("rootfs-manifest.json").path). Recreate the workspace with 'container-rootfs bootstrap'."
            )
        }
    }
}
