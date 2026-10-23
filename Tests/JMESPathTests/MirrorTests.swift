import XCTest

@testable import JMESPath

final class MirrorTests: XCTestCase {
    func testInterpreter<Value: Equatable>(_ expression: String, data: Any, result: Value) {
        do {
            let expression = try JMESExpression.compile(expression)
            let searchResult = try XCTUnwrap(expression.search(object: data))
            guard let value = searchResult as? Value else {
                XCTFail("Expected \(Value.self), instead we got \(type(of: searchResult))")
                return
            }
            XCTAssertEqual(value, result)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testString() {
        struct TestString {
            let s: String
        }
        let test = TestString(s: "hello")
        self.testInterpreter("s", data: test, result: "hello")
    }

    func testOptional() {
        struct TestString {
            let s: String?
        }
        let test = TestString(s: "hello")
        self.testInterpreter("s", data: test, result: "hello")
    }

    func testNumbers() {
        struct TestNumbers {
            let i: Int
            let d: Double
            let f: Float
            let b: Bool
        }
        let test = TestNumbers(i: 34, d: 1.4, f: 2.5, b: true)
        self.testInterpreter("i", data: test, result: 34)
        self.testInterpreter("d", data: test, result: 1.4)
        self.testInterpreter("f", data: test, result: 2.5)
        self.testInterpreter("b", data: test, result: true)
    }

    func testArray() {
        struct TestArray {
            let a: [Int]
        }
        let test = TestArray(a: [1, 2, 3, 4, 5])
        self.testInterpreter("a", data: test, result: test.a)
        self.testInterpreter("a[2]", data: test, result: 3)
        self.testInterpreter("a[-2]", data: test, result: 4)
        self.testInterpreter("a[1]", data: test, result: 2)
    }

    func testObjects() {
        struct TestObject {
            struct TestSubObject {
                let a: String
            }

            let sub: TestSubObject
        }
        let test = TestObject(sub: .init(a: "hello"))
        self.testInterpreter("sub.a", data: test, result: "hello")
    }

    func testEnum() {
        enum TestEnum: String {
            case test1
            case test2
        }
        struct TestObject {
            let e: TestEnum
        }
        let test = TestObject(e: .test2)
        self.testInterpreter("e", data: test, result: "test2")
    }

    func testCustomReflectableArray() {
        struct TestObject: CustomReflectable {
            let a: [Int]
            var customMirror: Mirror { Mirror(reflecting: self.a) }
        }
        let test = TestObject(a: [1, 2, 3, 4])
        self.testInterpreter("[2]", data: test, result: 3)
    }

    func testCustomReflectableDictionary() {
        struct TestObject: CustomReflectable {
            let d: [String: String]
            var customMirror: Mirror { Mirror(reflecting: self.d) }
        }
        let test = TestObject(d: ["test": "one", "test2": "two", "test3": "three"])
        self.testInterpreter("test2", data: test, result: "two")
    }

    func testPropertyWrapper() {
        @propertyWrapper struct Wrap<T>: JMESPropertyWrapper {
            var value: T
            var customMirror: Mirror { Mirror(reflecting: self.value) }

            init(wrappedValue: T) {
                self.value = wrappedValue
            }
            var wrappedValue: T {
                get { value }
                set { value = newValue }
            }
            var anyValue: Any { value }
        }
        struct TestObject {
            @Wrap var test: String
        }
        let test = TestObject(test: "testText")
        self.testInterpreter("test", data: test, result: "testText")
    }
}
