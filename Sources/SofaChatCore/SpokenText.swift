import Foundation

/// Cleans text before it is read aloud. The model is asked for plain
/// sentences, but if markdown slips through, the voice shouldn't read out
/// asterisks, pound signs or web addresses.
public enum SpokenText {
    public static func clean(_ text: String) -> String {
        var lines: [String] = []
        for rawLine in text.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            line = dropListMarker(line)
            while line.hasPrefix("#") {
                line.removeFirst()
            }
            line = line.trimmingCharacters(in: .whitespaces)
            if !line.isEmpty {
                lines.append(line)
            }
        }
        var result = lines.joined(separator: " ")
        result = replaceLinks(result)
        for mark in ["**", "__", "`", "*"] {
            result = result.replacingOccurrences(of: mark, with: "")
        }
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "- item", "* item", "+ item" and "1. item" become "item".
    static func dropListMarker(_ line: String) -> String {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        let digits = line.prefix(while: { $0.isNumber })
        if !digits.isEmpty {
            let rest = line.dropFirst(digits.count)
            if rest.hasPrefix(". ") || rest.hasPrefix(") ") {
                return String(rest.dropFirst(2))
            }
        }
        return line
    }

    /// "[the guide](https://example.com)" becomes "the guide".
    static func replaceLinks(_ text: String) -> String {
        var output = ""
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "[",
               let closeBracket = text[index...].firstIndex(of: "]"),
               text.index(after: closeBracket) < text.endIndex,
               text[text.index(after: closeBracket)] == "(",
               let closeParen = text[closeBracket...].firstIndex(of: ")")
            {
                output += text[text.index(after: index)..<closeBracket]
                index = text.index(after: closeParen)
            } else {
                output.append(text[index])
                index = text.index(after: index)
            }
        }
        return output
    }
}
