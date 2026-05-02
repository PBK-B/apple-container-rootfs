import Foundation

struct InspectOutput: Codable {
    let workspace: RootfsManifest
    let lastRun: LastRunConfiguration?
}
