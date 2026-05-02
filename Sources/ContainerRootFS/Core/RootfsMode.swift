import ArgumentParser

enum RootfsMode: String, ExpressibleByArgument, Codable {
    case rw
    case roLayer = "ro-layer"
}
