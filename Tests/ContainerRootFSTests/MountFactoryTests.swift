import XCTest
@testable import ContainerRootFS

final class MountFactoryTests: XCTestCase {
    func testBindMountParsesReadOnly() throws {
        let mounts = try MountFactory.makeMounts(bindMounts: ["/tmp:/data:ro"], mountSpecs: [])
        XCTAssertEqual(mounts.count, 1)
        XCTAssertEqual(mounts[0].source, "/tmp")
        XCTAssertEqual(mounts[0].destination, "/data")
        XCTAssertEqual(mounts[0].options, ["ro"])
    }

    func testMountSpecParsesReadOnly() throws {
        let mounts = try MountFactory.makeMounts(bindMounts: [], mountSpecs: ["type=bind,source=/tmp,target=/data,readonly"])
        XCTAssertEqual(mounts.count, 1)
        XCTAssertEqual(mounts[0].source, "/tmp")
        XCTAssertEqual(mounts[0].destination, "/data")
        XCTAssertEqual(mounts[0].options, ["ro"])
    }
}
