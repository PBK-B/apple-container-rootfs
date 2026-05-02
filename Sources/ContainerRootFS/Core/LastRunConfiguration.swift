import Foundation

struct LastRunConfiguration: Codable {
    let command: [String]
    let tty: Bool
    let kernel: String
    let initfsReference: String
    let network: String?
    let bindMounts: [String]
    let mountSpecs: [String]
    let dns: [String]
    let dnsSearch: [String]
    let dnsOptions: [String]
    let hosts: [String]
    let environment: [String]
    let workingDirectory: String?
    let cpus: Int?
    let memory: String?
    let recordedAt: Date
}
