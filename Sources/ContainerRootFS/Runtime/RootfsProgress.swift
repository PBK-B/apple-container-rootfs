import ContainerizationExtras
import Foundation

final class RootfsProgress: @unchecked Sendable {
    private let label: String
    private let lock = NSLock()

    private var description: String = ""
    private var itemsName: String = "items"
    private var totalItems: Int?
    private var items: Int = 0
    private var totalSize: Int64?
    private var size: Int64 = 0

    init(label: String) {
        self.label = label
    }

    var handler: ProgressHandler {
        { [lock] events in
            lock.withLock {
                for event in events {
                    switch event.event {
                    case "add-items":
                        if let value = event.value as? Int {
                            self.items += value
                        }
                    case "add-total-items":
                        if let value = event.value as? Int {
                            self.totalItems = (self.totalItems ?? 0) + value
                        }
                    case "add-size":
                        if let value = event.value as? Int64 {
                            self.size += value
                        }
                    case "add-total-size":
                        if let value = event.value as? Int64 {
                            self.totalSize = (self.totalSize ?? 0) + value
                        }
                    default:
                        break
                    }
                }

                self.render()
            }
        }
    }

    func setDescription(_ value: String) {
        lock.withLock {
            description = value
            render()
        }
    }

    func setItemsName(_ value: String) {
        lock.withLock {
            itemsName = value
            render()
        }
    }

    func finish() {
        lock.withLock {
            writeLine("")
        }
    }

    private func render() {
        let parts: [String] = [
            label,
            description,
            progressText(),
        ].filter { !$0.isEmpty }

        writeLine(parts.joined(separator: " | "))
    }

    private func progressText() -> String {
        var fragments: [String] = []
        if let totalItems, totalItems > 0 {
            fragments.append("\(items)/\(totalItems) \(itemsName)")
        } else if items > 0 {
            fragments.append("\(items) \(itemsName)")
        }
        if let totalSize, totalSize > 0 {
            fragments.append("\(formatted(size))/\(formatted(totalSize))")
        } else if size > 0 {
            fragments.append(formatted(size))
        }
        return fragments.joined(separator: " ")
    }

    private func formatted(_ value: Int64) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let gb = mb * 1024.0
        let amount = Double(value)
        if amount >= gb { return String(format: "%.1fGB", amount / gb) }
        if amount >= mb { return String(format: "%.1fMB", amount / mb) }
        if amount >= kb { return String(format: "%.1fKB", amount / kb) }
        return "\(value)B"
    }

    private func writeLine(_ text: String) {
        let output = "\r\u{001B}[2K\(text)"
        if let data = output.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
