import ContainerizationOS
import Foundation

enum MemoryParser {
    static func parse(_ value: String) throws -> UInt64 {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let suffixes: [(String, (Int) -> UInt64)] = [
            ("k", { $0.kib() }),
            ("kb", { $0.kib() }),
            ("m", { $0.mib() }),
            ("mb", { $0.mib() }),
            ("g", { $0.gib() }),
            ("gb", { $0.gib() }),
            ("t", { $0.tib() }),
            ("tb", { $0.tib() }),
        ]

        for (suffix, convert) in suffixes {
            if trimmed.hasSuffix(suffix) {
                let numberPart = String(trimmed.dropLast(suffix.count))
                guard let number = Int(numberPart) else {
                    throw MemoryParserError.invalidValue(value)
                }
                return convert(number)
            }
        }

        guard let bytes = UInt64(trimmed) else {
            throw MemoryParserError.invalidValue(value)
        }
        return bytes
    }
}

enum MemoryParserError: LocalizedError {
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .invalidValue(let value):
            return "Invalid memory value: \(value). Examples: 512m, 1g, 1073741824"
        }
    }
}
