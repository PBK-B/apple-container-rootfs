import Foundation

struct RunOptions {
    let containerID: String
    let root: String
    let kernel: String?
    let initfsReference: String?
    let refreshWritableLayer: Bool
    let tty: Bool?
    let command: [String]
    let bindMounts: [String]
    let mountSpecs: [String]
    let network: String?
}
