#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WinSDK)
import WinSDK
#elseif canImport(Bionic)
import Bionic
#else
#error("Unsupported platform")
#endif

/// Number type that can store integer or floating point
struct JMESNumber: Sendable, Equatable {
    fileprivate enum _Internal {
        case int(Int)
        case double(Double)
    }

    fileprivate var value: _Internal

    init(_ int: some BinaryInteger) {
        self.value = .int(numericCast(int))
    }

    init(_ double: some BinaryFloatingPoint) {
        self.value = .double(Double(double))
    }
}

private func _ceil(_ value: Double) -> Double {
    ceil(value)
}
private func _floor(_ value: Double) -> Double {
    floor(value)
}
extension JMESNumber {
    func collapse() -> Any {
        switch self.value {
        case .int(let int):
            int
        case .double(let double):
            double
        }

    }

    func abs() -> JMESNumber {
        switch self.value {
        case .int(let int):
            .init(Swift.abs(int))
        case .double(let double):
            .init(Swift.abs(double))
        }
    }

    func floor() -> JMESNumber {
        switch self.value {
        case .int:
            self
        case .double(let double):
            .init(_floor(double))
        }
    }

    func ceil() -> JMESNumber {
        switch self.value {
        case .int:
            self
        case .double(let double):
            .init(_ceil(double))
        }
    }

    public static func == (_ lhs: JMESNumber, _ rhs: JMESNumber) -> Bool {
        switch (lhs.value, rhs.value) {
        case (.int(let lhs), .int(let rhs)):
            lhs == rhs
        case (.int(let lhs), .double(let rhs)):
            Double(lhs) == rhs
        case (.double(let lhs), .double(let rhs)):
            lhs == rhs
        case (.double(let lhs), .int(let rhs)):
            lhs == Double(rhs)
        }
    }

    static prefix func - (_ value: JMESNumber) -> JMESNumber {
        switch value.value {
        case .int(let int):
            .init(-int)
        case .double(let double):
            .init(-double)
        }
    }

    static func + (_ lhs: JMESNumber, _ rhs: JMESNumber) -> JMESNumber {
        switch (lhs.value, rhs.value) {
        case (.int(let lhs), .int(let rhs)):
            .init(lhs + rhs)
        case (.int(let lhs), .double(let rhs)):
            .init(Double(lhs) + rhs)
        case (.double(let lhs), .double(let rhs)):
            .init(lhs + rhs)
        case (.double(let lhs), .int(let rhs)):
            .init(lhs + Double(rhs))
        }
    }

    static func - (_ lhs: JMESNumber, _ rhs: JMESNumber) -> JMESNumber {
        switch (lhs.value, rhs.value) {
        case (.int(let lhs), .int(let rhs)):
            .init(lhs - rhs)
        case (.int(let lhs), .double(let rhs)):
            .init(Double(lhs) - rhs)
        case (.double(let lhs), .double(let rhs)):
            .init(lhs - rhs)
        case (.double(let lhs), .int(let rhs)):
            .init(lhs - Double(rhs))
        }
    }

    static func * (_ lhs: JMESNumber, _ rhs: JMESNumber) -> JMESNumber {
        switch (lhs.value, rhs.value) {
        case (.int(let lhs), .int(let rhs)):
            .init(lhs * rhs)
        case (.int(let lhs), .double(let rhs)):
            .init(Double(lhs) * rhs)
        case (.double(let lhs), .double(let rhs)):
            .init(lhs * rhs)
        case (.double(let lhs), .int(let rhs)):
            .init(lhs * Double(rhs))
        }
    }

    static func / (_ lhs: JMESNumber, _ rhs: JMESNumber) -> JMESNumber {
        switch (lhs.value, rhs.value) {
        case (.int(let lhs), .int(let rhs)):
            .init(lhs / rhs)
        case (.int(let lhs), .double(let rhs)):
            .init(Double(lhs) / rhs)
        case (.double(let lhs), .double(let rhs)):
            .init(lhs / rhs)
        case (.double(let lhs), .int(let rhs)):
            .init(lhs / Double(rhs))
        }
    }

    static func > (_ lhs: JMESNumber, _ rhs: JMESNumber) -> Bool {
        switch (lhs.value, rhs.value) {
        case (.int(let lhs), .int(let rhs)):
            lhs > rhs
        case (.int(let lhs), .double(let rhs)):
            Double(lhs) > rhs
        case (.double(let lhs), .double(let rhs)):
            lhs > rhs
        case (.double(let lhs), .int(let rhs)):
            lhs > Double(rhs)
        }
    }

    static func >= (_ lhs: JMESNumber, _ rhs: JMESNumber) -> Bool {
        switch (lhs.value, rhs.value) {
        case (.int(let lhs), .int(let rhs)):
            lhs >= rhs
        case (.int(let lhs), .double(let rhs)):
            Double(lhs) >= rhs
        case (.double(let lhs), .double(let rhs)):
            lhs >= rhs
        case (.double(let lhs), .int(let rhs)):
            lhs >= Double(rhs)
        }
    }

    static func < (_ lhs: JMESNumber, _ rhs: JMESNumber) -> Bool {
        !(lhs >= rhs)
    }

    static func <= (_ lhs: JMESNumber, _ rhs: JMESNumber) -> Bool {
        !(lhs > rhs)
    }
}

extension JMESNumber: CustomStringConvertible {
    public var description: String {
        switch value {
        case .int(let int):
            return int.description
        case .double(let double):
            var string = double.description
            if string.hasSuffix(".0") {
                string.removeLast(2)
            }
            return string
        }
    }
}
