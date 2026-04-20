import Foundation

enum CSVParserError: Error, LocalizedError {
    case unreadableText
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .unreadableText:
            return "The selected file could not be decoded as text."
        case .emptyFile:
            return "The selected CSV file is empty."
        }
    }
}

enum CSVParser {
    static func parse(url: URL) throws -> DataTable {
        let data = try Data(contentsOf: url)
        let string =
            String(data: data, encoding: .utf8) ??
            String(data: data, encoding: .utf16LittleEndian) ??
            String(data: data, encoding: .utf16BigEndian) ??
            String(data: data, encoding: .unicode)

        guard let string else {
            throw CSVParserError.unreadableText
        }

        return try parse(text: string)
    }

    static func parse(text: String) throws -> DataTable {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CSVParserError.emptyFile
        }

        let delimiter = detectDelimiter(in: trimmed)
        let rows = tokenize(trimmed, delimiter: delimiter)
            .filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }

        guard let headerRow = rows.first else {
            throw CSVParserError.emptyFile
        }

        let headers = headerRow.enumerated().map { index, value in
            let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return candidate.isEmpty ? "Column\(index + 1)" : candidate
        }

        let bodyRows = rows.dropFirst().map { row -> [String: String] in
            var mapped: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                mapped[header] = index < row.count ? row[index] : ""
            }
            return mapped
        }

        return DataTable(headers: headers, rows: bodyRows)
    }

    private static func detectDelimiter(in text: String) -> Character {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let candidates: [Character] = [",", "\t", ";", "|"]
        return candidates.max { lhs, rhs in
            firstLine.filter { $0 == lhs }.count < firstLine.filter { $0 == rhs }.count
        } ?? ","
    }

    private static func tokenize(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var iterator = text.makeIterator()

        while let character = iterator.next() {
            if inQuotes {
                if character == "\"" {
                    if let peek = iterator.next() {
                        if peek == "\"" {
                            currentField.append("\"")
                        } else {
                            inQuotes = false
                            handleCharacter(
                                peek,
                                delimiter: delimiter,
                                currentField: &currentField,
                                currentRow: &currentRow,
                                rows: &rows
                            )
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(character)
                }
            } else if character == "\"" {
                inQuotes = true
            } else {
                handleCharacter(
                    character,
                    delimiter: delimiter,
                    currentField: &currentField,
                    currentRow: &currentRow,
                    rows: &rows
                )
            }
        }

        currentRow.append(currentField)
        rows.append(currentRow)
        return rows
    }

    private static func handleCharacter(
        _ character: Character,
        delimiter: Character,
        currentField: inout String,
        currentRow: inout [String],
        rows: inout [[String]]
    ) {
        if character == delimiter {
            currentRow.append(currentField)
            currentField = ""
            return
        }

        if character == "\n" {
            currentRow.append(currentField)
            rows.append(currentRow)
            currentField = ""
            currentRow = []
            return
        }

        if character == "\r" {
            return
        }

        currentField.append(character)
    }
}
