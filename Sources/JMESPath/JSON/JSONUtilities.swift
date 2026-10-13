extension UInt8 {
    internal static var _space: UInt8 { UInt8(ascii: " ") }
    internal static var _return: UInt8 { UInt8(ascii: "\r") }
    internal static var _newline: UInt8 { UInt8(ascii: "\n") }
    internal static var _tab: UInt8 { UInt8(ascii: "\t") }
    internal static var _slash: UInt8 { UInt8(ascii: "/") }

    internal static var _colon: UInt8 { UInt8(ascii: ":") }
    internal static let _semicolon = UInt8(ascii: ";")
    internal static var _comma: UInt8 { UInt8(ascii: ",") }

    internal static var _openbrace: UInt8 { UInt8(ascii: "{") }
    internal static var _closebrace: UInt8 { UInt8(ascii: "}") }

    internal static var _openbracket: UInt8 { UInt8(ascii: "[") }
    internal static var _closebracket: UInt8 { UInt8(ascii: "]") }

    internal static let _openangle = UInt8(ascii: "<")
    internal static let _closeangle = UInt8(ascii: ">")

    internal static var _quote: UInt8 { UInt8(ascii: "\"") }
    internal static var _backslash: UInt8 { UInt8(ascii: "\\") }
    internal static var _forwardslash: UInt8 { UInt8(ascii: "/") }

    internal static var _equal: UInt8 { UInt8(ascii: "=") }
    internal static var _minus: UInt8 { UInt8(ascii: "-") }
    internal static var _plus: UInt8 { UInt8(ascii: "+") }
    internal static var _question: UInt8 { UInt8(ascii: "?") }
    internal static var _exclamation: UInt8 { UInt8(ascii: "!") }
    internal static var _ampersand: UInt8 { UInt8(ascii: "&") }
    internal static var _pipe: UInt8 { UInt8(ascii: "|") }
    internal static var _period: UInt8 { UInt8(ascii: ".") }
    internal static var _e: UInt8 { UInt8(ascii: "e") }
    internal static var _E: UInt8 { UInt8(ascii: "E") }
}

internal var _asciiNumbers: ClosedRange<UInt8> { UInt8(ascii: "0")...UInt8(ascii: "9") }

internal func _parseIntegerDigits<Result: FixedWidthInteger>(
    _ codeUnits: BufferView,
    isNegative: Bool
) -> Result? {
    guard _fastPath(!codeUnits.isEmpty) else { return nil }

    // ASCII constants, named for clarity:
    let _0 = 48 as UInt8

    let numericalUpperBound: UInt8 = _0 &+ 10
    let multiplicand: Result = 10
    var result: Result = 0

    var iter = codeUnits.makeIterator()
    while let digit = iter.next() {
        let digitValue: Result
        if _fastPath(digit >= _0 && digit < numericalUpperBound) {
            digitValue = Result(truncatingIfNeeded: digit &- _0)
        } else {
            return nil
        }
        let overflow1: Bool
        (result, overflow1) = result.multipliedReportingOverflow(by: multiplicand)
        let overflow2: Bool
        (result, overflow2) =
            isNegative
            ? result.subtractingReportingOverflow(digitValue)
            : result.addingReportingOverflow(digitValue)
        guard _fastPath(!overflow1 && !overflow2) else { return nil }
    }
    return result
}

internal func _parseHexIntegerDigits<Result: FixedWidthInteger>(
    _ codeUnits: BufferView,
    isNegative: Bool
) -> Result? {
    guard _fastPath(!codeUnits.isEmpty) else { return nil }

    // ASCII constants, named for clarity:
    let _0 = 48 as UInt8
    let _A = 65 as UInt8
    let _a = 97 as UInt8

    let numericalUpperBound = _0 &+ 10
    let uppercaseUpperBound = _A &+ 6
    let lowercaseUpperBound = _a &+ 6
    let multiplicand: Result = 16

    var result = 0 as Result
    for digit in codeUnits {
        let digitValue: Result
        if _fastPath(digit >= _0 && digit < numericalUpperBound) {
            digitValue = Result(truncatingIfNeeded: digit &- _0)
        } else if _fastPath(digit >= _A && digit < uppercaseUpperBound) {
            digitValue = Result(truncatingIfNeeded: digit &- _A &+ 10)
        } else if _fastPath(digit >= _a && digit < lowercaseUpperBound) {
            digitValue = Result(truncatingIfNeeded: digit &- _a &+ 10)
        } else {
            return nil
        }

        let overflow1: Bool
        (result, overflow1) = result.multipliedReportingOverflow(by: multiplicand)
        let overflow2: Bool
        (result, overflow2) =
            isNegative
            ? result.subtractingReportingOverflow(digitValue)
            : result.addingReportingOverflow(digitValue)
        guard _fastPath(!overflow1 && !overflow2) else { return nil }
    }
    return result
}
