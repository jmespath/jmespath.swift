/// JMESPath runtime
///
/// Holds list of functions available to JMESPath expression
public class JMESRuntime {
    /// Initialize `JMESRuntime`
    public init() {
        self.functions = Self.builtInFunctions
    }

    /// Register new function with runtime
    /// - Parameters:
    ///   - name: Function name
    ///   - function: Function object
    func registerFunction(_ name: String, function: JMESFunction.Type) {
        self.functions[name] = function
    }

    func getFunction(_ name: String) -> JMESFunction.Type? {
        self.functions[name]
    }

    private var functions: [String: JMESFunction.Type]
    private static let builtInFunctions: [String: JMESFunction.Type] = [
        "abs": AbsFunction.self,
        "avg": AvgFunction.self,
        "ceil": CeilFunction.self,
        "contains": ContainsFunction.self,
        "ends_with": EndsWithFunction.self,
        "floor": FloorFunction.self,
        "join": JoinFunction.self,
        "keys": KeysFunction.self,
        "length": LengthFunction.self,
        "map": MapFunction.self,
        "max": MaxFunction.self,
        "max_by": MaxByFunction.self,
        "min": MinFunction.self,
        "min_by": MinByFunction.self,
        "merge": MergeFunction.self,
        "not_null": NotNullFunction.self,
        "reverse": ReverseFunction.self,
        "sort": SortFunction.self,
        "sort_by": SortByFunction.self,
        "starts_with": StartsWithFunction.self,
        "sum": SumFunction.self,
        "to_array": ToArrayFunction.self,
        "to_number": ToNumberFunction.self,
        "to_string": ToStringFunction.self,
        "type": TypeFunction.self,
        "values": ValuesFunction.self,
    ]
}
