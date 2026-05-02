import Foundation

struct RootfsLayout: CustomStringConvertible {
    let root: URL
    let containerID: String
    let mode: RootfsMode
    let lower: URL
    let upper: URL
    let work: URL
    let merged: URL
    let writableLayer: URL

    var containerRoot: URL { root.appendingPathComponent(containerID, isDirectory: true) }

    var runtimeRoot: URL {
        switch mode {
        case .rw:
            lower
        case .roLayer:
            writableLayer
        }
    }

    var description: String {
        [
            "container=\(containerID)",
            "mode=\(mode.rawValue)",
            "root=\(root.path)",
            "lower=\(lower.path)",
            "upper=\(upper.path)",
            "work=\(work.path)",
            "merged=\(merged.path)",
            "writable=\(writableLayer.path)",
            "runtime=\(runtimeRoot.path)",
        ].joined(separator: "\n")
    }
}
