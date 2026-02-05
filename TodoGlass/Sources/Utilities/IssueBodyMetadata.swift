import Foundation

enum IssueBodyMetadata {
    private static let duePrefix = "due:"

    private static let storageFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static func parse(body: String?) -> (cleanBody: String, dueDate: Date?) {
        guard let body, !body.trimmed.isEmpty else { return ("", nil) }
        let lines = body.components(separatedBy: .newlines)
        var dueDate: Date?
        var remaining: [String] = []

        for line in lines {
            let trimmed = line.trimmed
            if trimmed.lowercased().hasPrefix(duePrefix) {
                let raw = String(trimmed.dropFirst(duePrefix.count)).trimmed
                if let date = storageFormatter.date(from: raw) {
                    dueDate = date
                }
                continue
            }
            remaining.append(line)
        }

        let cleaned = remaining.joined(separator: "\n").trimmed
        return (cleaned, dueDate)
    }

    static func apply(dueDate: Date?, to body: String) -> String {
        let cleaned = parse(body: body).cleanBody
        guard let dueDate else { return cleaned }
        let dueLine = "Due: \(storageFormatter.string(from: dueDate))"
        if cleaned.isEmpty {
            return dueLine
        }
        return "\(dueLine)\n\n\(cleaned)"
    }

    static func displayString(for dueDate: Date) -> String {
        return displayFormatter.string(from: dueDate)
    }
}
