import XCTest
@testable import ContainerRootFS

@available(macOS 26.0, *)
final class NamedNetworkTests: XCTestCase {
    func testEnsureCreatesManifest() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let network = try NamedNetwork.ensure(name: "demo", root: root)
        XCTAssertEqual(network.manifest.name, "demo")
        XCTAssertTrue(FileManager.default.fileExists(atPath: network.manifestPath.path))
    }
}
