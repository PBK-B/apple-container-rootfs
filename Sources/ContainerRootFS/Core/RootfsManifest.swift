import Foundation

struct RootfsManifest: Codable {
    let containerID: String
    let imageReference: String
    let mode: RootfsMode
    let root: String
    let lower: String
    let upper: String
    let work: String
    let merged: String
    let writableLayer: String
    let runtime: String
    let createdAt: Date
}
