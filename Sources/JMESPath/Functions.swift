/// Used to validate arguments of a function before it is run
public struct FunctionSignature {
    /// Function argument used in function signature to verify arguments
    public indirect enum ArgumentType: CustomStringConvertible {
        case any
        case null
        case string
        case number
        case boolean
        case object
        case array
        case expRef
        case typedArray(ArgumentType)
        case union([ArgumentType])

        /// type of variable
        public var description: String {
            switch self {
            case .any: return "any"
            case .null: return "null"
            case .string: return "string"
            case .boolean: return "boolean"
            case .number: return "number"
            case .array: return "array"
            case .object: return "object"
            case .expRef: return "expression"
            case .typedArray(let type):
                return "array[\(type.description)]"
            case .union(let types):
                return "one of \(types.map { $0.description }.joined(separator: ", "))"
            }
        }
    }

    let inputs: [ArgumentType]
    let varArg: ArgumentType?

    /// Initialize function signature
    /// - Parameters:
    ///   - inputs: Function parameters
    ///   - varArg: Additiona variadic parameter
    public init(inputs: ArgumentType..., varArg: ArgumentType? = nil) {
        self.inputs = inputs
        self.varArg = varArg
    }

    /// Validate list of arguments, match signature
    /// - Parameter args: Array of arguments
    /// - Throws: JMESPathError.runtime
    func validateArgs(_ args: [JMESVariable]) throws {
        guard args.count == self.inputs.count || (args.count > self.inputs.count && self.varArg != nil)
        else {
            throw JMESPathError.runtime("Invalid number of arguments, expected \(self.inputs.count), got \(args.count)")
        }

        for i in 0..<self.inputs.count {
            guard args[i].isType(self.inputs[i]) else {
                throw JMESPathError.runtime("Invalid argument, expected \(self.inputs[i]), got \(args[i].getType())")
            }
        }
        if args.count > self.inputs.count, let varArg = self.varArg {
            for i in self.inputs.count..<args.count {
                guard args[i].isType(varArg) else {
                    throw JMESPathError.runtime("Invalid variadic argument, expected \(varArg), got \(args[i].getType())")
                }
            }
        }
    }
}

extension JMESVariable {
    /// Is variable of a certain argument type
    func isType(_ type: FunctionSignature.ArgumentType) -> Bool {
        switch (self, type) {
        case (_, .any),
            (.string, .string),
            (.null, .null),
            (.number, .number),
            (.boolean, .boolean),
            (.array, .array),
            (.object, .object),
            (.expRef, .expRef):
            return true

        case (.array(let array), .typedArray(let elementType)):
            let childElementsAreType = (array.first { !JMESVariable(from: $0).isType(elementType) } == nil)
            return childElementsAreType

        case (_, .union(let types)):
            let isType = types.first { self.isType($0) } != nil
            return isType

        default:
            return false
        }
    }
}

/// Protocol for JMESPath function expression
///
/// To write your own functions, implement a type conforming to
/// `JMESFunction` and then register it with the `JMESRuntime` you run your
/// search with. For example
/// ```
/// struct IdentityFunction: JMESFunction {
///     /// function takes one argument of any type
///     static var signature: FunctionSignature { .init(inputs: .any) }
///     /// evaluate just returns same object back
///     static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
///         return args[0]
///     }
/// }
/// let runtime = JMESRuntime()
/// runtime.registerFunction("identity", function: IdentityFunction.self)
/// // compile expression and run search
/// let expression = try Expression.compile(myExpression)
/// let result = try expression.search(json: myJson, runtime: runtime)
/// ```
protocol JMESFunction: Sendable {
    /// function signature
    static var signature: FunctionSignature { get }
    /// Evaluate function
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) throws -> JMESVariable
}

/// Protocl for JMESPath function that takes a single number
protocol NumberFunction: JMESFunction {
    static func evaluate(_ number: JMESNumber) -> JMESVariable
}

extension NumberFunction {
    static var signature: FunctionSignature { .init(inputs: .number) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch args[0] {
        case .number(let number):
            return self.evaluate(number)
        default:
            preconditionFailure()
        }
    }
}

/// Protocl for JMESPath function that takes a single array
protocol ArrayFunction: JMESFunction {
    static func evaluate(_ array: JMESArray) -> JMESVariable
}

extension ArrayFunction {
    static var signature: FunctionSignature { .init(inputs: .array) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch args[0] {
        case .array(let array):
            return self.evaluate(array)
        default:
            preconditionFailure()
        }
    }
}

// MARK: Functions

/// `number abs(number $value)`
/// Returns the absolute value of the provided argument. The signature indicates that a number is returned, and that the
/// input argument must resolve to a number, otherwise a invalid-type error is triggered.
struct AbsFunction: NumberFunction {
    static func evaluate(_ number: JMESNumber) -> JMESVariable {
        .number(number.abs())
    }
}

/// `number avg(array[number] $elements)`
/// Returns the average of the elements in the provided array. An empty array will produce a return value of null.
struct AvgFunction: ArrayFunction {
    static var signature: FunctionSignature { .init(inputs: .typedArray(.number)) }
    static func evaluate(_ array: JMESArray) -> JMESVariable {
        guard array.count > 0 else { return .null }
        let total = array.reduce(JMESNumber(0)) {
            if case .number(let number) = JMESVariable(from: $1) {
                return $0 + number
            } else {
                preconditionFailure()
            }
        }
        return .number(total / JMESNumber(Double(array.count)))
    }
}

/// `number ceil(number $value)`
/// Returns the next highest integer value by rounding up if necessary.
struct CeilFunction: NumberFunction {
    static func evaluate(_ number: JMESNumber) -> JMESVariable {
        .number(number.ceil())
    }
}

/// `boolean contains(array|string $subject, any $search)`
/// Returns true if the given $subject contains the provided $search string.
struct ContainsFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .union([.array, .string]), .any) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch (args[0], args[1]) {
        case (.array(let array), _):
            let result = array.first { args[1] == JMESVariable(from: $0) } != nil
            return .boolean(result)

        case (.string(let string), .string(let string2)):
            let result = string.contains(string2)
            return .boolean(result)

        case (.string, _):
            return .null

        default:
            preconditionFailure()
        }
    }
}

/// `boolean ends_with(string $subject, string $prefix)`
/// Returns true if the $subject ends with the $prefix, otherwise this function returns false.
struct EndsWithFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .string, .string) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch (args[0], args[1]) {
        case (.string(let string), .string(let string2)):
            return .boolean(string.hasSuffix(string2))
        default:
            preconditionFailure()
        }
    }
}

/// `number floor(number $value)`
/// Returns the next lowest integer value by rounding down if necessary.
struct FloorFunction: NumberFunction {
    static func evaluate(_ number: JMESNumber) -> JMESVariable {
        .number(number.floor())
    }
}

/// `string join(string $glue, array[string] $stringsarray)`
/// Returns all of the elements from the provided $stringsarray array joined together using the
/// $glue argument as a separator between each.
struct JoinFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .string, .typedArray(.string)) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch (args[0], args[1]) {
        case (.string(let separator), .array(let array)):
            let strings: [String] = array.map {
                if case .string(let s) = JMESVariable(from: $0) {
                    return s
                } else {
                    preconditionFailure()
                }
            }
            return .string(strings.joined(separator: separator))
        default:
            preconditionFailure()
        }
    }
}

/// `array keys(object $obj)`
/// Returns an array containing the keys of the provided object. Note that because JSON hashes are
/// inheritently unordered, the keys associated with the provided object obj are inheritently unordered.
/// Implementations are not required to return keys in any specific order.
struct KeysFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .object) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch args[0] {
        case .object(let object):
            return .array(object.keys.map { $0 })
        default:
            preconditionFailure()
        }
    }
}

/// `number length(string|array|object $subject)`
/// Returns the length of the given argument using the following types rules:
///     1. string: returns the number of code points in the string
///     2. array: returns the number of elements in the array
///     3. object: returns the number of key-value pairs in the object
struct LengthFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .union([.array, .object, .string])) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch args[0] {
        case .array(let array):
            return .number(.init(array.count))
        case .object(let object):
            return .number(.init(object.count))
        case .string(let string):
            return .number(.init(string.count))
        default:
            preconditionFailure()
        }
    }
}

/// `array[any] map(expression->any->any expr, array[any] elements)`
/// Apply the expr to every element in the elements array and return the array of results. An elements
/// of length N will produce a return array of length N.
///
/// Unlike a projection, `([*].bar)`, map will include the result of applying the expr for every
/// element in the elements array, even if the result if null.
struct MapFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .expRef, .array) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) throws -> JMESVariable {
        switch (args[0], args[1]) {
        case (.expRef(let ast), .array(let array)):
            let results = try array.map { try runtime.interpret(JMESVariable(from: $0), ast: ast).collapse() ?? JMESNull() }
            return .array(results)
        default:
            preconditionFailure()
        }
    }
}

/// `number max(array[number]|array[string] $collection)`
/// Returns the highest found number in the provided array argument.
/// An empty array will produce a return value of null.
struct MaxFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .union([.typedArray(.string), .typedArray(.number)])) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch args[0] {
        case .array(let array):
            guard let first = array.first else { return .null }
            switch JMESVariable(from: first) {
            case .string(var max):
                for element in array.dropFirst() {
                    if case .string(let string) = JMESVariable(from: element) {
                        if string > max {
                            max = string
                        }
                    }
                }
                return .string(max)

            case .number(var max):
                for element in array.dropFirst() {
                    if case .number(let number) = JMESVariable(from: element) {
                        if number > max {
                            max = number
                        }
                    }
                }
                return .number(max)

            default:
                preconditionFailure()
            }

        default:
            preconditionFailure()
        }
    }
}

/// `max_by(array elements, expression->number|expression->string expr)`
/// Return the maximum element in an array using the expression expr as the comparison key.
/// The entire maximum element is returned.
struct MaxByFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .array, .expRef) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) throws -> JMESVariable {
        switch (args[0], args[1]) {
        case (.array(let array), .expRef(let ast)):
            guard let first = array.first else { return .null }
            let firstValue = try runtime.interpret(JMESVariable(from: first), ast: ast)
            var maxElement: Any = first
            switch firstValue {
            case .string(var maxValue):
                for element in array.dropFirst() {
                    let value = try runtime.interpret(JMESVariable(from: element), ast: ast)
                    if case .string(let string) = value {
                        if string > maxValue {
                            maxValue = string
                            maxElement = element
                        }
                    } else {
                        throw JMESPathError.runtime("Invalid argment, expected array values to be strings, instead got \(value.getType())")
                    }
                }
                return JMESVariable(from: maxElement)

            case .number(var maxValue):
                for element in array.dropFirst() {
                    let value = try runtime.interpret(JMESVariable(from: element), ast: ast)
                    if case .number(let number) = value {
                        if number > maxValue {
                            maxValue = number
                            maxElement = element
                        }
                    } else {
                        throw JMESPathError.runtime("Invalid argment, expected array values to be numbers, instead got \(value.getType())")
                    }
                }
                return JMESVariable(from: maxElement)

            default:
                throw JMESPathError.runtime("Invalid argment, expected array values to be strings or numbers, instead got \(firstValue.getType())")
            }
        default:
            preconditionFailure()
        }
    }
}

/// `number min(array[number]|array[string] $collection)`
/// Returns the lowest found number in the provided $collection argument.
struct MinFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .union([.typedArray(.string), .typedArray(.number)])) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch args[0] {
        case .array(let array):
            guard let first = array.first else { return .null }
            switch JMESVariable(from: first) {
            case .string(var min):
                for element in array {
                    if case .string(let string) = JMESVariable(from: element) {
                        if string < min {
                            min = string
                        }
                    }
                }
                return .string(min)

            case .number(var min):
                for element in array {
                    if case .number(let number) = JMESVariable(from: element) {
                        if number < min {
                            min = number
                        }
                    }
                }
                return .number(min)

            default:
                preconditionFailure()
            }

        default:
            preconditionFailure()
        }
    }
}

/// min_by(array elements, expression->number|expression->string expr)
/// Return the minimum element in an array using the expression expr as the comparison key.
/// The entire maximum element is returned.
struct MinByFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .array, .expRef) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) throws -> JMESVariable {
        switch (args[0], args[1]) {
        case (.array(let array), .expRef(let ast)):
            guard let first = array.first else { return .null }
            let firstValue = try runtime.interpret(JMESVariable(from: first), ast: ast)
            var minElement: Any = first
            switch firstValue {
            case .string(var minValue):
                for element in array.dropFirst() {
                    let value = try runtime.interpret(JMESVariable(from: element), ast: ast)
                    if case .string(let string) = value {
                        if string < minValue {
                            minValue = string
                            minElement = element
                        }
                    } else {
                        throw JMESPathError.runtime("Invalid argment, expected array values to be strings, instead got \(value.getType())")
                    }
                }
                return JMESVariable(from: minElement)

            case .number(var minValue):
                for element in array.dropFirst() {
                    let value = try runtime.interpret(JMESVariable(from: element), ast: ast)
                    if case .number(let number) = value {
                        if number < minValue {
                            minValue = number
                            minElement = element
                        }
                    } else {
                        throw JMESPathError.runtime("Invalid argment, expected array values to be number, instead got \(value.getType())")
                    }
                }
                return JMESVariable(from: minElement)

            default:
                throw JMESPathError.runtime("Invalid argment, expected array values to be strings or numbers, instead got \(firstValue.getType())")
            }
        default:
            preconditionFailure()
        }
    }
}

/// `object merge([object *argument, [, object $...]])`
/// Accepts 0 or more objects as arguments, and returns a single object with subsequent objects
/// merged. Each subsequent object’s key/value pairs are added to the preceding object. This
/// function is used to combine multiple objects into one. You can think of this as the first object
/// being the base object, and each subsequent argument being overrides that are applied to
/// the base object.
struct MergeFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .object, varArg: .object) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch args[0] {
        case .object(var object):
            for arg in args.dropFirst() {
                if case .object(let object2) = arg {
                    object = object.merging(object2) { $1 }
                } else {
                    preconditionFailure()
                }
            }
            return .object(object)
        default:
            preconditionFailure()
        }
    }
}

/// `any not_null([any $argument [, any $...]])`
/// Returns the first argument that does not resolve to null. This function accepts one or more
/// arguments, and will evaluate them in order until a non null argument is encounted. If all
/// arguments values resolve to null, then a value of null is returned.
struct NotNullFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .any, varArg: .any) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        for arg in args {
            guard case .null = arg else {
                return arg
            }
        }
        return .null
    }
}

/// `array reverse(string|array $argument)`
/// Reverses the order of the $argument.
struct ReverseFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .union([.array, .string])) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch args[0] {
        case .string(let string):
            return .string(String(string.reversed()))
        case .array(let array):
            return .array(array.reversed())
        default:
            preconditionFailure()
        }
    }
}

/// `array sort(array[number]|array[string] $list)`
/// This function accepts an array $list argument and returns the sorted elements of the $list
/// as an array.
///
/// The array must be a list of strings or numbers. Sorting strings is based on code points.
/// Locale is not taken into account.
struct SortFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .union([.typedArray(.number), .typedArray(.string)])) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch args[0] {
        case .array(let array):
            let jmesArray = array.map { JMESVariable(from: $0) }
            let sorted = jmesArray.sorted { $0.compare(.lessThan, value: $1) == true }
            // can use compact map here as we are guaranteed they won't be `nil` given the
            // function signature requires numbers or strings
            return .array(sorted.compactMap { $0.collapse() })
        default:
            preconditionFailure()
        }
    }
}

/// `sort_by(array elements, expression->number|expression->string expr)`
/// Sort an array using an expression expr as the sort key. For each element in the array of
/// elements, the expr expression is applied and the resulting value is used as the key used
/// when sorting the elements.
///
/// If the result of evaluating the expr against the current array element results in type other
/// than a number or a string, a type error will occur.
struct SortByFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .array, .expRef) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) throws -> JMESVariable {
        struct ValueAndSortKey {
            let value: Any
            let sortValue: JMESVariable
        }
        switch (args[0], args[1]) {
        case (.array(let array), .expRef(let ast)):
            guard let first = array.first else { return .array(array) }
            let firstSortValue = try runtime.interpret(JMESVariable(from: first), ast: ast)
            switch firstSortValue {
            case .string, .number:
                break
            default:
                throw JMESPathError.runtime("Invalid argument for sorting, expected number or string, instead got \(firstSortValue.getType())")
            }

            let restOfTheValues = try array.dropFirst().map { element -> ValueAndSortKey in
                let sortValue = try runtime.interpret(JMESVariable(from: element), ast: ast)
                guard sortValue.isSameType(as: firstSortValue) else {
                    throw JMESPathError.runtime(
                        "Sort arguments all have to be the same type, expected \(firstSortValue.getType()), instead got \(sortValue.getType())"
                    )
                }
                return .init(value: element, sortValue: sortValue)
            }
            let values = [ValueAndSortKey(value: first, sortValue: firstSortValue)] + restOfTheValues
            let sorted = values.sorted(by: { $0.sortValue.compare(.lessThan, value: $1.sortValue) == true })
            return .array(sorted.map { $0.value })
        default:
            preconditionFailure()
        }
    }
}

/// `boolean starts_with(string $subject, string $prefix)`
/// Returns true if the $subject starts with the $prefix, otherwise this function returns false.
struct StartsWithFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .string, .string) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch (args[0], args[1]) {
        case (.string(let string), .string(let string2)):
            return .boolean(string.hasPrefix(string2))
        default:
            preconditionFailure()
        }
    }
}

/// `number sum(array[number] $collection)`
/// Returns the sum of the provided array argument.
/// An empty array will produce a return value of 0.
struct SumFunction: ArrayFunction {
    static var signature: FunctionSignature { .init(inputs: .typedArray(.number)) }
    static func evaluate(_ array: JMESArray) -> JMESVariable {
        guard let first = array.first.map({ JMESVariable(from: $0) }) else { return .number(.init(0)) }
        switch first {
        case .number(let number):
            let total = array.dropFirst().reduce(number) {
                if case .number(let number) = JMESVariable(from: $1) {
                    return $0 + number
                } else {
                    preconditionFailure()
                }
            }
            return .number(total)

        default:
            preconditionFailure()
        }
    }
}

/// `array to_array(any $arg)`
/// - array - Returns the passed in value.
/// - number/string/object/boolean - Returns a one element array containing the passed in argument.
struct ToArrayFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .any) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch args[0] {
        case .array:
            return args[0]
        default:
            return .array([args[0].collapse() ?? JMESNull()])
        }
    }
}

/// `number to_number(any $arg)`
/// - string - Returns the parsed number. Any string that conforms to the json-number
///     production is supported. Note that the floating number support will be implementation
///     specific, but implementations should support at least IEEE 754-2008 binary64
///     (double precision) numbers, as this is generally available and widely used.
/// - number - Returns the passed in value.
/// - Everything else - null
struct ToNumberFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .any) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) throws -> JMESVariable {
        switch args[0] {
        case .number(let number):
            return .number(number)
        case .string(let string):
            do {
                return try JMESVariable.parse(json: string)
            } catch {
                return .null
            }
        default:
            return .null
        }
    }
}

/// `string to_string(any $arg)`
/// - string - Returns the passed in value.
/// - number/array/object/boolean - The JSON encoded value of the object. The JSON encoder
///     should emit the encoded JSON value without adding any additional new lines.
struct ToStringFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .any) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) throws -> JMESVariable {
        switch args[0] {
        case .string(let string):
            return .string(string)
        default:
            return args[0].json().map { .string($0) } ?? .null
        }
    }
}

/// `string type(array|object|string|number|boolean|null $subject)`
/// Returns the JavaScript type of the given $subject argument as a string value.
/// The return value MUST be one of the following: number, string, boolean, array, object, null
struct TypeFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .any) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) throws -> JMESVariable {
        .string(args[0].getType())
    }
}

/// `array values(object $obj)`
/// Returns the values of the provided object. Note that because JSON hashes are inheritently
/// unordered, the values associated with the provided object obj are inheritently unordered.
/// Implementations are not required to return values in any specific order.
struct ValuesFunction: JMESFunction {
    static var signature: FunctionSignature { .init(inputs: .object) }
    static func evaluate(args: [JMESVariable], runtime: JMESRuntime) -> JMESVariable {
        switch args[0] {
        case .object(let object):
            return .array(object.values.map { $0 })
        default:
            preconditionFailure()
        }
    }
}
