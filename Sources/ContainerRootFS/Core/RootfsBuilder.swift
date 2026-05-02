import Containerization
import ContainerizationArchive
import ContainerizationOCI
import ContainerizationExtras
import Foundation
import Logging

struct RootfsBuilder {
    let imageStore: ImageStore
    let logger: Logger

    init(storeRoot: URL, logger: Logger) throws {
        self.imageStore = try ImageStore(path: storeRoot)
        self.logger = logger
    }

    func build(imageReference: String, platform: Platform, layout: RootfsLayout, progress: ProgressHandler? = nil) async throws {
        let image = try await imageStore.pull(reference: imageReference, platform: platform, progress: progress)
        try FileManager.default.createDirectory(at: layout.lower, withIntermediateDirectories: true)

        let manifest = try await image.manifest(for: platform)
        for layer in manifest.layers {
            let content = try await image.getContent(digest: layer.digest)
            let reader = try ArchiveReader(file: content.path)
            _ = try reader.extractContents(to: layout.lower)
        }
    }
}
