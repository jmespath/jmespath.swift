//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

internal enum JSONEncoderValue: Equatable {
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    case array([JSONEncoderValue])
    case object([String: JSONEncoderValue])

    case directArray([UInt8], lengths: [Int])
    case nonPrettyDirectArray([UInt8])
}

/// The formatting of the output JSON data.
public struct JSONOutputFormatting: OptionSet, Sendable {
    /// The format's default value.
    public let rawValue: UInt

    /// Creates an OutputFormatting value with the given raw value.
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// Produce human-readable JSON with indented output.
    public static let prettyPrinted = JSONOutputFormatting(rawValue: 1 << 0)

    /// Produce JSON with dictionary keys sorted in lexicographic order.
    public static let sortedKeys = JSONOutputFormatting(rawValue: 1 << 1)

    /// By default slashes get escaped ("/" → "\/", "http://apple.com/" → "http:\/\/apple.com\/")
    /// for security reasons, allowing outputted JSON to be safely embedded within HTML/XML.
    /// In contexts where this escaping is unnecessary, the JSON is known to not be embedded,
    /// or is intended only for display, this option avoids this escaping.
    public static let withoutEscapingSlashes = JSONOutputFormatting(rawValue: 1 << 3)
}
