/// Lexer object
///
/// Parses raw text to create an array of tokens
internal class Lexer {
    var index: String.Index
    let text: String

    init(text: String) {
        self.text = text
        self.index = text.startIndex
    }

    func tokenize() throws -> [Token] {
        var tokens: [Token] = []

        while !self.reachedEnd() {
            let c = self.current()

            switch c {
            case "a"..."z", "A"..."Z", "_":
                tokens.append(.identifier(self.readIdentifier()))
                continue
            case "\"":
                try tokens.append(.quotedIdentifier(self.readQuotedIdentifier()))
            case "'":
                try tokens.append(.literal(self.readRawString()))
            case "0"..."9":
                try tokens.append(.number(self.readNumber()))
                continue
            case "-":
                try tokens.append(.number(self.readNegativeNumber()))
                continue
            case "`":
                try tokens.append(.literal(self.readLiteral()))
            case ".":
                tokens.append(.dot)
            case "*":
                tokens.append(.star)
            case "|":
                tokens.append(self.alternative(expected: "|", match: .or, else: .pipe))
            case "@":
                tokens.append(.at)
            case "[":
                tokens.append(self.readLeftBracket())
            case "]":
                tokens.append(.rightBracket)
            case ",":
                tokens.append(.comma)
            case ":":
                tokens.append(.colon)
            case "{":
                tokens.append(.leftBrace)
            case "}":
                tokens.append(.rightBrace)
            case "&":
                tokens.append(self.alternative(expected: "&", match: .and, else: .ampersand))
            case "(":
                tokens.append(.leftParenthesis)
            case ")":
                tokens.append(.rightParenthesis)
            case "=":
                tokens.append(.equals)
                self.next()
                guard self.index != self.text.endIndex, self.text[self.index] == "=" else {
                    throw JMESPathError.compileTime("'=' is not valid, did you mean '=='")
                }
            case ">":
                tokens.append(self.alternative(expected: "=", match: .greaterThanOrEqual, else: .greaterThan))
            case "<":
                // check next char
                tokens.append(self.alternative(expected: "=", match: .lessThanOrEqual, else: .lessThan))
            case "!":
                // check next char
                tokens.append(self.alternative(expected: "=", match: .notEqual, else: .not))
            case " ", "\n", "\t", "\r":
                break
            default:
                throw JMESPathError.compileTime("Unable to parse character '\(c)'")
            }

            self.next()
        }
        tokens.append(.eof)
        return tokens
    }

    private func readIdentifier() -> String {
        let identifierStart = self.index
        exitLoop: while !self.reachedEnd() {
            switch self.current() {
            case "a"..."z", "A"..."Z", "_", "0"..."9":
                break
            default:
                break exitLoop
            }
            self.next()
        }
        return String(self.text[identifierStart..<self.index])
    }

    private func readLeftBracket() -> Token {
        switch self.peek() {
        case "]":
            self.next()
            return .flatten
        case "?":
            self.next()
            return .filter
        default:
            return .leftBracket
        }
    }

    private func readNumber() throws -> Int {
        let identifierStart = self.index
        exitLoop: while !self.reachedEnd() {
            switch self.current() {
            case "0"..."9":
                break
            default:
                break exitLoop
            }
            self.next()
        }
        let intString = self.text[identifierStart..<self.index]
        guard let int = Int(intString) else {
            throw JMESPathError.compileTime("Failed to parse number 'intString'")
        }
        return int
    }

    private func readNegativeNumber() throws -> Int {
        let identifierStart = self.index
        self.next()
        exitLoop: while !self.reachedEnd() {
            switch self.current() {
            case "0"..."9":
                break
            default:
                break exitLoop
            }
            self.next()
        }
        let intString = self.text[identifierStart..<self.index]
        guard let int = Int(intString) else {
            throw JMESPathError.compileTime("Failed to parse number 'intString'")
        }
        return int
    }

    private func readQuotedIdentifier() throws -> String {
        let string = try readInside()
        let variable = try JMESVariable.parse(json: "\"\(string)\"")
        guard case .string(let string2) = variable else { preconditionFailure() }
        return string2
    }

    private func readRawString() throws -> JMESVariable {
        let string = try self.readInside()
        return .string(string.replacingOccurrences(of: "\\'", with: "'"))
    }

    private func readLiteral() throws -> JMESVariable {
        let string = try readInside()
        do {
            let unescaped = string.replacingOccurrences(of: "\\`", with: "`")
            return try JMESVariable.parse(json: unescaped)
        } catch {
            throw JMESPathError.compileTime("Unable to parse literal JSON")
        }
    }

    private func readInside() throws -> String {
        let wrapper = self.current()
        self.next()
        let start = self.index
        exitLoop: while !self.reachedEnd() {
            let c = self.current()
            switch c {
            case wrapper:
                let buffer = self.text[start..<self.index]
                return String(buffer)
            case "\\":
                self.next()
                guard !self.reachedEnd() else { throw JMESPathError.compileTime("Unclosed \(wrapper) delimiter") }
            default:
                break
            }
            self.next()
        }
        throw JMESPathError.compileTime("Unclosed \(wrapper) delimiter")
    }

    private func alternative(expected: Character, match: Token, else: Token) -> Token {
        if self.peek() == expected {
            self.next()
            return match
        }
        return `else`
    }

    private func peek() -> Character? {
        let nextIndex = self.text.index(after: self.index)
        guard nextIndex != self.text.endIndex else { return nil }
        return self.text[nextIndex]
    }

    private func current() -> Character {
        self.text[self.index]
    }

    private func next() {
        self.index = self.text.index(after: self.index)
    }

    private func reachedEnd() -> Bool {
        self.index == self.text.endIndex
    }
}
