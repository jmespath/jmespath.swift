#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension JMESVariable {
    static func parse(json: String) throws -> Self {
        try json.withBufferView { view in
            var scanner = JSONScanner(bytes: view, options: .init())
            let map = try scanner.scan()
            guard let value = map.loadValue(at: 0) else { throw JMESPathError.runtime("Empty JSON file") }
            return try JMESVariable(from: parse(value, map: map))
        }
    }

    ///  Parse JSON into object
    /// - Parameter json: json string
    /// - Returns: object
    static func parse(json: some ContiguousBytes) throws -> Self {
        try json.withBufferView { view in
            var scanner = JSONScanner(bytes: view, options: .init())
            let map = try scanner.scan()
            guard let value = map.loadValue(at: 0) else { throw JMESPathError.runtime("Empty JSON file") }
            return try JMESVariable(from: parse(value, map: map))
        }
    }

    static func parse(_ jsonValue: JSONMap.Value, map: JSONMap) throws -> Any {
        switch jsonValue {
        case .string(let region, let isSimple):
            return try map.withBuffer(for: region) { stringBuffer, fullSource in
                if isSimple {
                    guard let result = String._tryFromUTF8(stringBuffer) else {
                        throw JSONError.cannotConvertInputStringDataToUTF8(
                            location: .sourceLocation(at: stringBuffer.startIndex, fullSource: fullSource)
                        )
                    }
                    return result
                }
                return try JSONScanner.stringValue(from: stringBuffer, fullSource: fullSource)
            }

        case .bool(let value):
            return value

        case .null:
            return JMESNull()

        case .number(let region, let hasExponent):
            return try map.withBuffer(for: region) { numberBuffer, fullSource in
                if hasExponent {
                    let digitsStartPtr = try JSONScanner.prevalidateJSONNumber(from: numberBuffer, hasExponent: hasExponent, fullSource: fullSource)

                    if let floatingPoint = Double(prevalidatedBuffer: numberBuffer) {
                        // Check for overflow (which results in an infinite result), or rounding to zero.
                        // While strtod does set ERANGE in the either case, we don't rely on it because setting errno to 0 first and then check the result is surprisingly expensive. For values "rounded" to infinity, we reject those out of hand. For values "rounded" down to zero, we perform check for any non-zero digits in the input, which turns out to be much faster.
                        if floatingPoint.isFinite {
                            // Should also check for underflow here
                            return floatingPoint
                        } else {
                            throw JSONError.numberIsNotRepresentableInSwift(parsed: String(decoding: numberBuffer, as: UTF8.self))
                        }
                    }
                    throw JSONScanner.validateNumber(from: numberBuffer.suffix(from: digitsStartPtr), fullSource: fullSource)

                } else {
                    let digitBeginning = try JSONScanner.prevalidateJSONNumber(from: numberBuffer, hasExponent: hasExponent, fullSource: fullSource)
                    // This is the fast pass. Number directly convertible to Integer.
                    if let integer = Int(prevalidatedBuffer: numberBuffer) {
                        return integer
                    }
                    if let double = Double(prevalidatedBuffer: numberBuffer) {
                        return double
                    }
                    throw JSONScanner.validateNumber(from: numberBuffer.suffix(from: digitBeginning), fullSource: fullSource)
                }
            }

        case .array(let region):
            var entries = [Any]()
            var iterator = map.makeArrayIterator(from: region.startOffset)
            while let value = iterator.next() {
                try entries.append(Self.parse(value, map: map))
            }
            return entries

        case .object(let region):
            var entries = [String: Any]()
            var iterator = map.makeObjectIterator(from: region.startOffset)
            while let value = iterator.next() {
                guard case .string(let region, let isSimple) = value.key else {
                    throw JMESPathError.runtime("Non string dictionary keys are not supported.")
                }
                let key = try map.withBuffer(for: region) { stringBuffer, fullSource in
                    if isSimple {
                        guard let result = String._tryFromUTF8(stringBuffer) else {
                            throw JSONError.cannotConvertInputStringDataToUTF8(
                                location: .sourceLocation(at: stringBuffer.startIndex, fullSource: fullSource)
                            )
                        }
                        return result
                    }
                    return try JSONScanner.stringValue(from: stringBuffer, fullSource: fullSource)
                }
                entries[key] = try Self.parse(value.value, map: map)
            }
            return entries
        }
    }

    /// JSON output from variable
    public func json() -> String? {
        guard let value = JSONEncoderValue(from: self) else { return nil }
        var writer = JSONWriter(options: [])
        do {
            try writer.serializeJSON(value)
            let value = String(decoding: writer.bytes, as: UTF8.self)
            return value
        } catch {
            return nil
        }
    }
}

extension JSONEncoderValue {
    init?(from variable: JMESVariable) {
        switch variable {
        case .string(let string):
            self = .string(string)
        case .number(let number):
            self = .number(number.description)
        case .boolean(let bool):
            self = .bool(bool)
        case .array(let array):
            self = .array(array.compactMap { JSONEncoderValue(from: JMESVariable(from: $0)) })
        case .object(let object):
            self = .object(object.compactMapValues { JSONEncoderValue(from: JMESVariable(from: $0)) })
        case .other:
            return nil
        case .null:
            self = .null
        default:
            return nil
        }

    }
}
