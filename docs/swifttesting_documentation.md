# Swift Testing – A Modern Replacement for XCTest

## Overview
Swift **Testing** is a modern, expressive, and macro-based testing framework introduced by Apple during WWDC 2024 as a next-generation alternative to **XCTest** for Swift code ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Swift%20Testing%20is%20a%20modern%2C,when%20writing%20unit%20tests)). It takes advantage of powerful Swift language features to make tests clearer and more concise, requiring less code and providing more actionable failure feedback ([Adding tests to your Xcode project - Apple Developer](https://developer.apple.com/documentation/Xcode/adding-tests-to-your-xcode-project#:~:text=A%20newer%2C%20modern%20testing%20framework,XCTest)). Swift Testing is intended primarily for unit tests and integration tests that call your code directly ([Adding tests to your Xcode project - Apple Developer](https://developer.apple.com/documentation/Xcode/adding-tests-to-your-xcode-project#:~:text=A%20newer%2C%20modern%20testing%20framework,XCTest)). (UI tests and performance tests continue to use XCTest for those specific purposes, as XCTest still provides UI automation and performance measurement support ([Adding tests to your Xcode project - Apple Developer](https://developer.apple.com/documentation/Xcode/adding-tests-to-your-xcode-project#:~:text=A%20newer%2C%20modern%20testing%20framework,XCTest)).) Swift Testing is included with Xcode 16 and later, and can coexist with existing XCTest tests to facilitate a gradual migration ([Swift Testing - Xcode - Apple Developer](https://developer.apple.com/xcode/swift-testing/#:~:text=Works%20with%20XCTest)).

## Key Features and Architecture
- **Clear & Expressive API with Macros** – Swift Testing introduces a simple API using Swift macros (such as `#expect` and `#require`) for assertions ([Swift Testing - Xcode - Apple Developer](https://developer.apple.com/xcode/swift-testing/#:~:text=Clear%2C%20expressive%20API)). These macros let you write complex expectations in a single statement and automatically capture values in expressions, producing detailed messages when a test fails (e.g., showing actual vs expected values). This unified approach replaces the many `XCTAssert*` functions with a single, flexible syntax ([Using the #expect macro for Swift Testing - SwiftLee](https://www.avanderlee.com/swift-testing/expect-macro/#:~:text=The%20,XCAssertTrue)).  
- **Parameterized & Parallel Tests** – The framework natively supports *parameterized tests*, allowing you to run the same test code over a sequence of input values easily ([GitHub - swiftlang/swift-testing: A modern, expressive testing package for Swift](https://github.com/swiftlang/swift-testing#:~:text=Scalable%20coverage%20and%20execution)). Tests can be defined with an `arguments` list, and will execute for each value. In addition, Swift Testing integrates with Swift concurrency: tests can be marked `async` and will run in parallel by default (making efficient use of multiple cores and speeding up test suites) ([GitHub - swiftlang/swift-testing: A modern, expressive testing package for Swift](https://github.com/swiftlang/swift-testing#:~:text=Scalable%20coverage%20and%20execution)).  
- **Custom Traits for Test Behavior** – You can customize how and when tests run using *traits*. Traits are parameters on the `@Test` or `@Suite` macros that describe runtime conditions or metadata ([Swift Testing - Xcode - Apple Developer](https://developer.apple.com/xcode/swift-testing/#:~:text=You%20can%20customize%20the%20behavior,execution%20time%20limits%20for%20your%C2%A0tests)). For example, you can restrict a test to certain platforms or OS versions, set timeouts, conditionally enable/disable tests, or attach metadata like tags. This enables fine-grained control for continuous integration and conditional execution of tests (e.g., only run a test if a feature flag is enabled) ([Swift Testing - Xcode - Apple Developer](https://developer.apple.com/xcode/swift-testing/#:~:text=You%20can%20customize%20the%20behavior,execution%20time%20limits%20for%20your%C2%A0tests)) ([Swift Testing - Xcode - Apple Developer](https://developer.apple.com/xcode/swift-testing/#:~:text=%40Test%28,expect%28video.comments.contains%28%22So%20picturesque%21%22%29%29)).  
- **Flexible Test Organization** – Swift Testing removes the rigid class-based structure of XCTest. Test functions are ordinary Swift functions (which can be global or within any type) annotated with `@Test` ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Something%20that%20has%20changed%20compared,want%20to%20be%20a%20test)). You no longer need to subclass `XCTestCase` or prefix methods with “test” – any function marked with the macro becomes a test. You can group related tests in structs, classes (including actors or other types) to form test *suites*, and even nest suites for hierarchical organization ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=In%20this%20new%20approach%20to,final%20class)) ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=WifiParserTests)). Descriptive names and tagging provide additional ways to organize and filter tests.  
- **Isolated State per Test** – Each test in Swift Testing is run on a fresh instance of its suite type, which is initialized before the test and torn down after ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=As%20you%20can%20see%20above%2C,variables%20and%20implicitly%20unwrapped%20optionals)). Setup code can be placed in an initializer, and the suite’s `deinit` acts as the equivalent of XCTest’s `tearDown` ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=in%20XCTest,variables%20and%20implicitly%20unwrapped%20optionals)). This means no shared mutable state between tests unless explicitly intended, improving test isolation by default. (You can also write tests as global functions if setup isn’t needed.)  
- **Powerful Diagnostics** – When tests run in Xcode, results are shown with rich inline information. Failure messages are more informative thanks to expression capture (e.g., showing `variableX → actualValue` in the output) and the ability to include custom messages. Xcode 16’s test UI fully supports Swift Testing with features like filtering by tags and re-running individual data-driven test cases ([Swift Testing - Xcode - Apple Developer](https://developer.apple.com/xcode/swift-testing/#:~:text=You%20can%20work%20with%20your,command%20line%20using%20the%20Swift%C2%A0Package%C2%A0Manager)).  
- **Open Source & Cross-Platform** – Swift Testing is developed as an open-source Swift Package and works across all major Swift platforms ([GitHub - swiftlang/swift-testing: A modern, expressive testing package for Swift](https://github.com/swiftlang/swift-testing#:~:text=Cross)). It supports not only iOS, macOS, watchOS, tvOS (and upcoming platforms like visionOS), but also Linux and Windows ([GitHub - swiftlang/swift-testing: A modern, expressive testing package for Swift](https://github.com/swiftlang/swift-testing#:~:text=Cross)). This cross-platform support allows consistent testing for Swift packages on different OSes. The project is discussed and evolved in the Swift Forums, welcoming community input to shape its future ([GitHub - swiftlang/swift-testing: A modern, expressive testing package for Swift](https://github.com/swiftlang/swift-testing#:~:text=Swift%20Testing%20works%20on%20all,future%20of%20testing%20in%20Swift)).  
- **Coexistence with XCTest** – You can use Swift Testing alongside XCTest in the same test suite. Xcode treats tests from both frameworks equally, so you can incrementally migrate your test code ([GitHub - swiftlang/swift-testing: A modern, expressive testing package for Swift](https://github.com/swiftlang/swift-testing#:~:text=Works%20with%20XCTest)). For example, you might write new tests with Swift Testing while keeping legacy tests in XCTest until they’re ported. This side-by-side compatibility ensures you don’t have to rewrite everything at once ([GitHub - swiftlang/swift-testing: A modern, expressive testing package for Swift](https://github.com/swiftlang/swift-testing#:~:text=Works%20with%20XCTest)).

## Setting Up and Using Swift Testing

### Xcode Integration
Using Swift Testing in Xcode 16+ is straightforward. When creating a new project in Xcode, you can choose **Swift Testing** as the testing framework in the project setup options ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Swift%20Testing%20ships%20with%20Xcode,Testing%20as%20your%20testing%20framework)). Xcode will configure a test target that uses Swift Testing instead of XCTest. Similarly, if you add a new test target to an existing project, you’ll have the option to select Swift Testing in the template ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Image)). If your project already contains an XCTest bundle, you don’t need to create a separate bundle for Swift Testing – you can mix Swift Testing tests into the same target without extra configuration ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Image)). Simply start writing tests with the new framework, and Xcode will discover and run them alongside XCTests.

### Swift Package Manager (SPM) Usage
Swift Testing is included in the Swift toolchain (as of Swift 6), so you can use it out-of-the-box with SPM when you opt into Swift 6. To enable it in a Swift Package: set your package’s tools-version to 6.0. If you don’t add Swift Testing as an explicit package dependency, you’ll need to tell the Swift test runner to use the new framework. For example, run tests with an extra flag:  

```bash
swift test --enable-experimental-swift-testing
```  

This `--enable-experimental-swift-testing` flag is required for SwiftPM to run Swift Testing tests if the package doesn’t declare a direct dependency on it ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=If%20you%20don%E2%80%99t%20list%20Swift,written%20with%20the%20new%20library)). Alternatively, you can add **Swift Testing** as a package dependency in your `Package.swift` (the package is open-source on GitHub). Adding it explicitly makes the tests run without special flags, which is useful if you are working outside Xcode or on other platforms ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Before%20Xcode%2016%20or%20on,other%20platforms)). (Note: Using Swift Testing requires a Swift 6 compiler; there were workarounds for Swift 5.10, but those are temporary ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Image)).)

### Importing the Framework
To use Swift Testing in your test files, import the **Testing** module at the top of each test file:  

```swift
import Testing
```  

This module import gives you access to the `@Test` and `@Suite` macros, `#expect`/`#require`, and other Swift Testing APIs ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Let%E2%80%99s%20now%20see%20how%20you,module)). Unlike XCTest, you do **not** import XCTest nor subclass `XCTestCase` when using Swift Testing.

## Defining Tests
In Swift Testing, every test is simply a function annotated with the `@Test` attribute (macro). You are free to name test functions in a descriptive way without the rigid `test...` prefix requirement ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Something%20that%20has%20changed%20compared,want%20to%20be%20a%20test)). For example, you could write:  

```swift
@Test 
func whenParsingValidData_thenOutputsExpectedResult() {
    // test code...
}
```  

Because the function is marked with `@Test`, Xcode knows it’s a test to run, regardless of its name ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Something%20that%20has%20changed%20compared,want%20to%20be%20a%20test)). Test functions can be `async` and/or `throws` if needed – this allows you to await asynchronous code and propagate errors out of the test, respectively ([Adding tests to your Xcode project | Apple Developer Documentation](https://docs.developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project#:~:text=Documentation%20docs,them%20to%20a%20global%20actor)). Swift Testing will handle a thrown error as a test failure, and await asynchronous code just like normal Swift, without the need for XCTest expectations or fulfillment. You can also mark test functions with a global actor if they need to run on a specific thread (for example, `@MainActor`) ([Adding tests to your Xcode project | Apple Developer Documentation](https://docs.developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project#:~:text=Documentation%20docs,them%20to%20a%20global%20actor)).

Tests can be defined at global scope (as free functions) or as methods inside a type (such as a struct, class, or actor). You have flexibility in how you organize them ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=In%20this%20new%20approach%20to,final%20class)). For instance, you might group related tests inside a `struct` named after the functionality under test, or you can keep tests as standalone functions if that makes sense.

### Test Suites
Any type that contains test functions can act as a *test suite*. You can optionally use the `@Suite` macro on a type to designate it as a suite, which provides a couple of conveniences:
- If a type is marked with `@Suite`, **all** its methods are treated as test functions automatically, so you don’t need to put `@Test` on each one ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=These%20types%20are%20called%20Suites,in%20one%20of%20two%20ways)). (Use this when every method in the type is meant to be a test.)
- If you don’t mark the type with `@Suite`, then you should put `@Test` on each test function individually (this is also perfectly fine) ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=,macro%20to%20each%20test)).

In practice, some developers prefer to always use `@Test` on functions for clarity, especially given current Xcode versions may not list the tests if `@Suite` is used without individual annotations ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=,let%20Apple%20know%20about%20this)). Either way, the presence of `@Test` or `@Suite` will make the tests discoverable.

Each test suite type is instantiated fresh for each test it runs. This means you can define **stored properties** in your suite to represent the state needed for tests, and initialize them in an initializer. This replaces the role of `setUp()` in XCTest. For example, if every test needs a new `Database` instance, you can create one in the suite’s init:

#### Example:
```swift
@Suite struct DatabaseTests {
    let db: Database  // system under test
    init() {
        db = Database()  // setup before each test
    }

    @Test func testInsert() throws {
        let record = Record(id: 1, data: "Hello")
        try db.insert(record)
        #expect(db.contains(record))
    }

    @Test func testDelete() throws {
        // ... use db, which is a fresh instance per test
        // no interference between tests
    }
}  // deinit of suite runs after each test, analogous to tearDown
```

In this example, `DatabaseTests` is a suite that contains two test functions. The `init()` serves to set up `db` before each test, and Swift Testing will call `deinit` after each test (which you could implement if needed to cleanup resources) ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=in%20XCTest,variables%20and%20implicitly%20unwrapped%20optionals)). This approach avoids shared mutable state and eliminates the need for implicitly unwrapped optionals for properties that are set up in `setUp()` ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=As%20you%20can%20see%20above%2C,variables%20and%20implicitly%20unwrapped%20optionals)) – since each test gets a brand new instance of the suite, you can initialize properties directly.

*(Note: You can also use a class or actor with `@Suite` if needed. If you use a class, you could also implement `deinit` to run teardown code. Using value types like struct/actor is often convenient for isolation.)*

## Writing Assertions with `#expect` and `#require`
Swift Testing dramatically simplifies assertions. Instead of having a family of `XCTAssert` functions (equal, not equal, true, false, nil, throws, etc.), there are two primary macros: **`#expect`** and **`#require`**.

The **`#expect`** macro is the workhorse for validating test conditions. You call it with a boolean expression that should be true for the test to pass. For example:  

```swift
#expect(user.age >= 18)
```  

If the condition is false, the test will record a failure. The real power of `#expect` is that it can take any Swift expression using standard operators, and it will capture the values of sub-expressions. This means failure messages are much more informative. For instance, if the above expectation fails, the message might say something like *“Expectation failed: (user.age → 16) >= 18”*, clearly showing that `user.age` was 16 at runtime. This is a big improvement over some XCTest messages that only say which assert failed without context. Swift Testing uses **one unified assertion macro** for practically all checks, making test code easier to write and read ([Using the #expect macro for Swift Testing - SwiftLee](https://www.avanderlee.com/swift-testing/expect-macro/#:~:text=The%20,XCAssertTrue)).

By default, an `#expect` failure **does not stop the test** – the test will continue running subsequent lines, similar to how XCTest assertions work by default (where the test continues after a failure, unless `continueAfterFailure` is set to false) ([Choose Between #expect and #require in Swift Tests](https://fatbobman.com/en/snippet/swift-testing-differences-between-expect-and-require/#:~:text=)) ([Choose Between #expect and #require in Swift Tests](https://fatbobman.com/en/snippet/swift-testing-differences-between-expect-and-require/#:~:text=%40Test%20func%20example,%2F%2F%20Still%20executes)). This allows one test to report multiple failures in one run, which can be useful for diagnosing multiple issues at once.

### The `#require` Macro
Swift Testing also provides `#require`, a macro for cases where you **want to stop the test immediately** if a condition isn’t met. Think of `#require` as an assertion that acts as a *precondition*. If a `#require` fails, it will abort the test’s execution at that point. In fact, `#require` is implemented to throw an error on failure, so you must call it with `try` (even when checking a simple condition) ([Choose Between #expect and #require in Swift Tests](https://fatbobman.com/en/snippet/swift-testing-differences-between-expect-and-require/#:~:text=1)) ([Choose Between #expect and #require in Swift Tests](https://fatbobman.com/en/snippet/swift-testing-differences-between-expect-and-require/#:~:text=%40Test%20func%20person%28%29%20throws%20,needed)). This is how it halts the test – the thrown error escapes the test function (which can be `throws`), and the test is marked as failed without running further code.

Use `#require` for critical conditions that the rest of the test cannot proceed without ([Choose Between #expect and #require in Swift Tests](https://fatbobman.com/en/snippet/swift-testing-differences-between-expect-and-require/#:~:text=%3E%20TL%3BDR%3A%20Use%20%60,execution%20to%20continue%20after%20failure)) ([Choose Between #expect and #require in Swift Tests](https://fatbobman.com/en/snippet/swift-testing-differences-between-expect-and-require/#:~:text=%2A%20%60%23expect%60%3A%20Use%20for%20non,failure%20terminates%20the%20test%20case)). A common example would be unwrapping an optional or ensuring a function did not throw an unexpected error. In XCTest you might do something like: 

```swift
let value = try XCTUnwrap(optionalValue)  
XCTAssertEqual(value.property, 42)
``` 

With Swift Testing, `#require` combines those steps:  

```swift
let value = try #require(optionalValue)  
#expect(value.property == 42)
```  

Here, `try #require(optionalValue)` will fail the test and stop if `optionalValue` is `nil`, but if not, it unwraps it and assigns to `value` ([Choose Between #expect and #require in Swift Tests](https://fatbobman.com/en/snippet/swift-testing-differences-between-expect-and-require/#:~:text=2)) ([Choose Between #expect and #require in Swift Tests](https://fatbobman.com/en/snippet/swift-testing-differences-between-expect-and-require/#:~:text=%40Test%20func%20notOptional%28%29%20throws%20,expect%28unwrappedPerson.name%20%3D%3D%20%22Fat)). This is analogous to `XCTUnwrap` (and indeed `#require` is often used to unwrap optionals or catch early errors) ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=There%20is%20an%20extra%20change,pass%20in%20if%20it%20can)). Another example: if calling a throwing function is essential to proceed, you can require it succeeds: `let result = try #require( try someThrowingFunc() )`. This will catch any thrown error from `someThrowingFunc` and fail the test immediately with that error if it throws.

In summary, use **`#expect`** for most assertions – it keeps the test running even if one check fails – and use **`#require`** for non-negotiable conditions that should short-circuit the test on failure ([Choose Between #expect and #require in Swift Tests](https://fatbobman.com/en/snippet/swift-testing-differences-between-expect-and-require/#:~:text=Summary)). Both macros can include an optional message string as a second parameter, just like traditional assertions, to provide additional context in failure reports.

#### Example:
```swift
@Test func exampleUsage() throws {
    let person: Person? = Person(name: "Alice", age: 30)
    // Critical precondition: person must not be nil
    let validPerson = try #require(person, "Person should exist")  // unwraps Person
    
    #expect(validPerson.age >= 18)          // will continue even if fails
    #expect(validPerson.name == "Alice")   // another check
}
```

In this example, if `person` was `nil`, the test would stop at the `#require` line with a failure (and not execute the subsequent expectations). If `person` is non-nil, the test proceeds to check the age and name. Even if the age expectation fails, the name check still runs (so you’d get potentially two failures reported if both conditions were wrong).

### Checking Errors (Exception Handling)
Testing error throwing in Swift Testing is very straightforward and eliminates boilerplate. To assert that a piece of code throws an error (and specifically, an expected error), you use the `#expect(throws:)` variant of the macro. Instead of a boolean expression, you provide the expected error type or value and a closure containing the code that should throw. For example, suppose `ValidationError.valueTooSmall` is an error your function might throw:

```swift
@Test func errorIsThrownForInvalidInput() throws {
    let input = -1
    #expect(throws: ValidationError.valueTooSmall, "Values less than 0 should throw an error") {
        try checkInput(input)
    }
}
``` 

In the above test, the `#expect` will pass if `checkInput(input)` throws the `ValidationError.valueTooSmall` error, and it will fail if no error is thrown or a different error is thrown ([Asserting state with #expect in Swift Testing – Donny Wals](https://www.donnywals.com/asserting-state-with-expect-in-swift-testing/#:~:text=%40Test%20func%20errorIsThrownForIncorrectInput,)) ([Asserting state with #expect in Swift Testing – Donny Wals](https://www.donnywals.com/asserting-state-with-expect-in-swift-testing/#:~:text=The%20first%20argument%20that%20we,to%20check%20thrown%20errors%20for)). The failure message in case of a mismatch will even tell you which error was thrown versus which was expected, which is helpful for debugging ([Asserting state with #expect in Swift Testing – Donny Wals](https://www.donnywals.com/asserting-state-with-expect-in-swift-testing/#:~:text=Now%20let%27s%20say%20that%20I,a%20little%20bit%20like%20this)). You can also use an error **type** instead of a specific error case if you just want to ensure an error of a certain kind is thrown (for instance, `throws: SomeErrorType.self`).

To assert that code **does not throw** any error, Swift Testing uses the concept of expecting the `Never` type as the “error” – since `Never` can never be thrown, this means you expect no throw to happen. For example:

```swift
@Test func noErrorIsThrownForValidInput() throws {
    let input = 5
    #expect(throws: Never.self, "Valid input should not throw") {
        try checkInput(input)
    }
}
``` 

This will fail if `checkInput(input)` throws anything (because throwing any error would violate the expectation that no error is thrown) ([Asserting state with #expect in Swift Testing – Donny Wals](https://www.donnywals.com/asserting-state-with-expect-in-swift-testing/#:~:text=,)). Essentially, `throws: Never.self` is Swift Testing’s way of expressing the “no throw expected” condition (akin to XCTest’s `XCTAssertNoThrow`). 

The `#expect(throws:)` macro is quite flexible. In the closure, you put the code that you expect to throw or not throw. You don’t need to catch the error yourself – the macro handles that. If you need to inspect the error further, one approach is to perform the operation beforehand and capture the error, but commonly just specifying the error type or specific error case is enough to verify correct behavior. These features replace `XCTAssertThrowsError` and `XCTAssertNoThrow` from XCTest in a more inline and readable way ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=2.%20The%20%60,WifiParser.Error.noMatches)).

### Other Assertions and Issues
Most other XCTest assertions map to a combination of `#expect` or `#require` with appropriate expressions. For example:
- `XCTAssertEqual(a, b)` becomes `#expect(a == b)`
- `XCTAssertNotEqual(x, y)` becomes `#expect(x != y)`
- `XCTAssertTrue(cond)` becomes `#expect(cond)`
- `XCTAssertNil(opt)` becomes `#expect(opt == nil)`
- `XCTAssertFalse(cond)` becomes `#expect(cond == false)` (or `#expect(!cond)`)
- `XCTFail("message")` can be done by `#expect(false, "message")` to unconditionally fail at that point.

If you need to mark a test as failed without an expression (the equivalent of calling `XCTFail()`), you can use the approach above or potentially use the `Issue` API. Swift Testing includes an `Issue` type to record test issues manually. For instance, `Issue.record("message")` could be used to log a failure (this is analogous to how one might use `XCTFail`). In general, though, using `#expect(false)` or a similar check is straightforward for triggering a failure.

For handling **expected failures** (tests that are currently broken but you don’t want them to cause the suite to fail), Swift Testing provides a better mechanism than simply disabling the test. You can wrap the failing expectations in a `withKnownIssue` block:

```swift
@Test func exampleKnownBug() {
    withKnownIssue("Tracking issue XYZ-123") {
        #expect(someFunction() == 42)  // this is known to fail currently
    }
}
``` 

When you run the tests, anything inside `withKnownIssue` that fails will be reported separately as an “expected failure”, and won’t mark the test as failed ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=There%20is%20another%20alternative%20to,skip%20failures%20in%20unit%20tests)) ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=The%20great%20thing%20about%20,block)). The test output will note that this test has a known issue. However – importantly – if the code *starts passing* (the issue is fixed unexpectedly), Swift Testing will flag the test to let you know that the known issue is no longer failing ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=The%20great%20thing%20about%20,block)). In other words, it fails the test to alert you that your expected failure is now passing, so you should remove the `withKnownIssue` wrapper. This is similar to XCTest’s `XCTExpectFailure`, but with the convenient behavior of alerting you when the expectation of failure is no longer valid.

## Test Traits and Customization
Swift Testing introduces **traits** to give more control over test execution and organization. Traits are passed as parameters to the `@Test` and `@Suite` macros to modify the test’s behavior or metadata ([Swift Testing - Xcode - Apple Developer](https://developer.apple.com/xcode/swift-testing/#:~:text=You%20can%20customize%20the%20behavior,execution%20time%20limits%20for%20your%C2%A0tests)). Here are some key traits and how to use them:

- **Custom Name** – By default, a test’s name in results is generated from the function name (or suite name from the type). You can override this by providing a string as the first parameter to `@Test` or `@Suite`. For example: `@Test("Successfully parsing a string with all fields")` will show that descriptive name in Xcode’s test navigator instead of the function name ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Custom%20names)) ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=You%20can%20override%20the%20way,string%20to%20their%20respective%20macros)). This can make test reports more readable at a glance. Similarly, `@Suite("Parse a wifi string") struct WifiParserTests { ... }` names the whole suite ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Custom%20names)).

- **Tags** – Tags are a powerful way to categorize tests. They are a kind of trait that you define and then apply to tests or suites ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=One%20exciting%20feature%20that%20Swift,tests%20and%20run%20them%20selectively)) ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=import%20Testing)). You might define tags like `.parsing` or `.network` to mark certain groups of tests. First, you declare the tag (usually via an extension on the provided `Tag` type):
  ```swift
  extension Tag {
      @Tag static var parsing: Self
      @Tag static var network: Self
  }
  ```  
  This creates two tag identifiers. You can then apply them: e.g., `@Test(.tags(.parsing)) func testParsingValidInput() { ... }` ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=import%20Testing)) ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=WifiParserTests)). You can assign multiple tags to a test by listing them: `@Test(.tags(.parsing, .network))` if it falls into both categories. Tags can also be applied at the suite level: `@Suite(.tags(.parsing)) struct ParserTests { ... }` to tag all tests in that suite ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=)). Tags from a suite are inherited by the tests within, and you can also nest suites and have inner suites add more tags ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=WifiParserTests)). In Xcode’s Test navigator, you’ll be able to filter or select tests by tag, making it easy to run all “parsing” tests, for example, with one click ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Now%2C%20when%20examining%20the%20test,to%20filter%20tests%20by%20tags)).

- **Enabled/Disabled** – You might sometimes want to disable a test without deleting it (perhaps it’s flaky or waiting on a fix). Swift Testing provides an `.disabled` trait for this purpose. For instance: `@Test(.disabled("Flaky, needs investigation")) func testFeatureX() { ... }` will mark that test as disabled ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=)). Disabled tests appear greyed out in Xcode’s interface and are skipped during test runs ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=)). The string you provide (reason) is shown to indicate why it’s disabled. Similarly, you can disable an entire suite with `@Suite(.disabled("…"))`, which will skip all tests in it. There’s also an `.enabled(if: condition)` trait to only run a test when a certain condition is true ([Swift Testing - Xcode - Apple Developer](https://developer.apple.com/xcode/swift-testing/#:~:text=You%20can%20customize%20the%20behavior,execution%20time%20limits%20for%20your%C2%A0tests)). For example, `@Test(.enabled(if: AppFeatures.isPremiumEnabled))` would only run that test if the static condition is true (this could check an environment variable, OS version, device type, etc.). This is useful for platform-specific tests or feature-flagged code paths.

- **Bug Reference** – The `.bug` trait allows attaching a link or identifier for a bug tracking system to a test ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=You%20can%20even%20pair%20the,tracking%20software%20issue)). For instance: `@Test(.bug("ISSUE-1234")) func testKnownBugScenario() { ... }`. This doesn’t change execution, but it records the association so that reports can include the reference. It’s often combined with `.disabled` for known bugs, e.g., marking a test as disabled and linking the bug ID ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=You%20can%20even%20pair%20the,tracking%20software%20issue)) ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=)).

- **Time Limits** – You can specify a time limit for a test using a trait like `.timeLimit(seconds:)` (the exact API may be `.timeout()` or similar in the final implementation). This will mark the test as failed if it exceeds the given runtime, which is helpful for ensuring no test hangs indefinitely or runs too long on CI.

*(Additional traits may include ones to specify required device (like `.only(on: .macOS)` or exclude certain platforms), but the above are the primary ones highlighted in documentation.)* ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Traits%20are%20a%20way%20to,how%20and%20when%20they%20run))

Using traits can greatly help in managing large test suites:
- **Tags** let you run targeted subsets (e.g., run “fast” tests vs “slow” tests, or run all tests for a specific feature module).
- **Conditional enabling** helps in multi-platform projects to skip tests on unsupported configurations.
- **Disabling with context** ensures temporarily skipped tests aren’t forgotten (especially if paired with a bug link or using `withKnownIssue` inside the test as described earlier).

## Parameterized Tests
A notable feature of Swift Testing is built-in **parameterized testing** (also called data-driven tests). This allows you to write one test that runs multiple times with different input values. To create a parameterized test, define your test function with one or more parameters, and supply an array of argument values to the `@Test` macro via the `arguments:` parameter.

For example, suppose you want to test a function `addOne(_:)` with several inputs:  

```swift
@Test(arguments: [0, 1, -1, 42])   // will run 4 times
func testAddOne(input: Int) {
    let output = addOne(input)
    #expect(output == input + 1)
}
```  

This single test will execute once for each value in the array `arguments` (0, 1, -1, 42), and within the test the parameter `input` will take on each of those values in turn. So effectively, four sub-tests run, each with a different `input`. In Xcode’s test navigator, this might appear as the test name with an annotation or expansion for each argument, and each can pass or fail independently.

Parameterized tests help avoid writing very similar test code repeatedly. Instead of four separate functions or a loop inside a test (which would stop at the first failure), the framework treats each input as a separate test run. If one case fails, you’ll see exactly which input caused it. Xcode even allows you to re-run a specific failed case easily, which aids debugging ([Swift Testing - Xcode - Apple Developer](https://developer.apple.com/xcode/swift-testing/#:~:text=You%20can%20work%20with%20your,command%20line%20using%20the%20Swift%C2%A0Package%C2%A0Manager)).

You can have multiple parameters as well. For instance, `@Test(arguments: [(2,3), (0,0), (-1,1)]) func testAdd(x: Int, y: Int) { ... }` would run the test for each tuple of values. Under the hood, the framework likely uses Swift’s macro system to generate multiple test invocations.

In Swift Testing, parameterized tests integrate with other features too. You can tag parameterized tests, give them custom names, etc. For example, from the earlier example in the error tests: 

```swift
@Test(.tags(.errorReporting), arguments: [
    "",  // empty string
    "WIFI:T:WPA;P:pass;H:YES;;",            // missing SSID
    "WIFI:S:network;T:WPA;H:YES;;",         // missing password
    "WIFI:T:WPA;H:YES;;"                    // missing both
]) 
func whenParseIsCalledWithInvalidString_thenNoMatchesErrorIsThrown(input: String) throws {
    #expect(throws: WifiParser.Error.noMatches) { try sut.parse(wifi: input) }
    #expect(errorMonitoring.capturedErrors.compactMap { $0 as? WifiParser.Error } == [.noMatches])
}
```  

In this test ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=%2F%2F%201%20%40Test%28.tags%28.errorReporting%29%2C%20arguments%3A%20,%2F%2F%202)) ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=,property%20of)), the `arguments` array contains multiple invalid Wi-Fi strings to test, and the test ensures that each of them throws the `.noMatches` error and records it appropriately. The test is also tagged as `.errorReporting` in addition to the suite’s `.parsing` tag, demonstrating combined traits. The framework will run this test four times (for each input string), and if, say, the third case fails, the report will identify which input string was being tested. You can then re-run just that case from Xcode to debug. Parameterized tests can significantly reduce duplicated test code while increasing coverage of edge cases.

## Best Practices
Here are some best practices and tips for using Swift Testing effectively in your projects:

- **Use Descriptive Test Names**: Since you aren’t forced to start names with `test`, you can be very clear about what each test does. Consider using the function name to describe the scenario and expectation (as shown in many examples), and/or use the string name in the `@Test` attribute for a friendlier description ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Custom%20names)). Descriptive names make it easier to understand test failures quickly.

- **Organize Tests with Suites**: Take advantage of grouping tests in suites (`struct`/`class` with `@Suite`). For example, you might have `UserServiceTests` containing all tests related to `UserService` logic, and within it, maybe nested suites like `AuthenticationTests`, `ProfileUpdateTests`, etc. This hierarchy can mirror your app’s structure and makes large test suites easier to navigate ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=WifiParserTests)) ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=%40Suite%28.tags%28.errorReporting%29%29%20struct%20ErrorReportingTests%20,)). It’s also fine to keep some tests as global functions if they don’t logically fit in a type – Swift Testing is flexible.

- **Leverage Tags for Filtering**: Define tags for important groupings of tests (e.g., feature areas, test characteristics like “slow”, “networking”, or team ownership). Tagging tests lets you run a subset easily. For instance, you might tag long-running tests with `.slow` and then exclude them on a quick test run, or tag critical tests and run only those in certain pipelines ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=One%20exciting%20feature%20that%20Swift,tests%20and%20run%20them%20selectively)) ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=import%20Testing)). Use Xcode’s UI or command-line options (once available) to include/exclude tags as needed.

- **Prefer `#expect` for Multiple Assertions**: It’s common to have several related assertions in one test (to validate various outcomes). Using `#expect` for all of them will allow the test to report all failures in one go, which is helpful for diagnosing issues. Only use `#require` for the truly critical preconditions or when continuing after a failure would produce meaningless results or cascade errors ([Choose Between #expect and #require in Swift Tests](https://fatbobman.com/en/snippet/swift-testing-differences-between-expect-and-require/#:~:text=Summary)). For example, ensure a parsed result isn’t `nil` with `#require` before checking its properties with `#expect`.

- **Initialization and Teardown**: Use the suite’s initializer to set up any state needed for tests, and let the implicit teardown (deinit) handle cleanup ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=As%20you%20can%20see%20above%2C,variables%20and%20implicitly%20unwrapped%20optionals)). This keeps setup code next to the tests themselves, making it clearer. If using a class for a suite and you need to reset some static state or external resource, implement `deinit` or consider using `withKnownIssue` or traits like `.enabled` to conditionally skip in problematic environments instead of leaving state dirty.

- **Handling Flaky or Known Failures**: Rather than simply commenting out or ignoring a failing test, use `withKnownIssue` to mark it as an expected failure if appropriate ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=There%20is%20another%20alternative%20to,skip%20failures%20in%20unit%20tests)). This way the test still runs (so you know if it starts passing) but doesn’t break your suite. If a test is truly not applicable under certain conditions, use `.disabled` with a note ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=)), but try to limit how many tests are disabled at any given time and resolve them as soon as possible. Keep the reasons and any bug links documented via the traits ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=You%20can%20even%20pair%20the,tracking%20software%20issue)).

- **Parallel Execution**: Because Swift Testing runs tests in parallel by default, ensure that your tests are thread-safe and independent. Avoid sharing global mutable state between tests. If you have to modify global state (like user defaults or a singleton), consider isolating tests to a serial executor or using actors to prevent data races. You can also mark a test or suite with a global actor (like `@MainActor`) if it interacts with UI or other Main-thread-only code, which will serialize those tests to run on the main thread.

- **Mixing with XCTest**: During a migration period, you may have both XCTest and Swift Testing tests in your project. Keep in mind:
  - Both will run, but the reporting might show separate groupings (XCTest still might show “0 tests executed” at the very top if you have no tests in XCTest, which is a minor cosmetic issue ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Unfortunately%2C%20even%20though%20tests%20are,presumably%20referring%20to%20XCTest%20suites)) ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Unfortunately%2C%20even%20though%20tests%20are,presumably%20referring%20to%20XCTest%20suites))).
  - For UI tests and certain performance tests, you’ll still use XCTest for now. It’s perfectly acceptable to have UI tests in an XCTest target and unit tests in Swift Testing in the same project.
  - When writing new tests, prefer Swift Testing for its advantages, but don’t feel pressured to rewrite every old test immediately unless it benefits from cleanup.

- **Continuous Integration (CI)**: Ensure your CI is using Xcode 16 or Swift 6 toolchain so that it recognizes Swift Testing tests. If running via SwiftPM on Linux or in a Docker, remember the `--enable-experimental-swift-testing` if you haven’t added the package. Over time, Swift Testing will likely become standard and that flag may not be needed once it’s no longer “experimental”. Also, use tags/traits to segment tests if you want certain jobs to run only a subset (e.g., smoke tests vs full test suite).

- **Stay Updated**: Swift Testing is evolving (being open-source). Keep an eye on the Swift forums or Swift Testing’s documentation for new features or changes. For example, future versions might add more traits or expand UI testing capabilities. Upgrading Xcode/Swift may bring improvements to how tests are discovered or run (addressing any current limitations with @Suite, etc.). Community blogs (like those by Swift developers) are also a great resource – many have begun sharing tips on using Swift Testing effectively as it matures.

## Migrating from XCTest
Migrating existing tests from XCTest to Swift Testing can be done gradually. Here’s a guide for transitioning typical XCTest patterns to Swift Testing:

- **Import and Setup**: In your test files, replace `import XCTest` with `import Testing` ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Let%E2%80%99s%20now%20see%20how%20you,module)). Remove any subclass of `XCTestCase`. You can convert your test class into either a struct or just keep it as a class but without inheriting from `XCTestCase`. (If you keep it as a class, you may mark it `final` for clarity, though it’s not required.)

- **Setup and Teardown**: If you used `override func setUp()` and `tearDown()`, move that logic into an initializer and deinitializer (or just let variables go out of scope) in your suite type. For example, properties that were defined as optionals and initialized in `setUp` can become non-optionals that you initialize in the `init()` ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=let%20sut%3A%20WifiParser%20let%20errorMonitoring%3A,SpyErrorMonitoring)) ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=in%20XCTest,variables%20and%20implicitly%20unwrapped%20optionals)). In Swift Testing, the suite type itself can hold state. In many cases, you can avoid mutable state entirely – use `let` properties set in init. If you had `setUpWithError` or throwing setup, your `init()` can throw if needed (though it’s often simpler to handle errors in tests themselves). For teardown, free resources in `deinit` if necessary (e.g., delete temp files, etc.), but often the end of scope suffices.

- **Test Methods**: Remove the `test` prefix from method names (this is optional, but you might as well rename them to something more descriptive now that you can). More importantly, prefix each test function with `@Test` ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=Something%20that%20has%20changed%20compared,want%20to%20be%20a%20test)). If you converted your class to a struct, also decide whether to add `@Suite`. You can either mark the type with `@Suite` to auto-detect all methods as tests ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=These%20types%20are%20called%20Suites,in%20one%20of%20two%20ways)), or explicitly mark each test with `@Test` (the latter is often clearer during migration). Ensure any test methods that were `private` are now at least internal, or not marked, because they need to be visible for the test runner (if you had them as open or internal in XCTest, just keep them the same; `@Test` will handle discovery).

- **Assertions**: This is the bulk of changes. Go through each `XCTAssert*` call and replace it with the appropriate `#expect` or `#require`:
  - `XCTAssertEqual(a, b, msg)` → `#expect(a == b, msg)`
  - `XCTAssertNotEqual(a, b)` → `#expect(a != b)`
  - `XCTAssertTrue(cond)` → `#expect(cond)`
  - `XCTAssertFalse(cond)` → `#expect(cond == false)`
  - `XCTAssertNil(x)` → `#expect(x == nil)`
  - `XCTAssertNotNil(x)` → `#expect(x != nil)` or you can do `let val = try #require(x)` to both unwrap and ensure it’s non-nil in one go ([Getting started with Swift Testing](https://www.polpiella.dev/swift-testing#:~:text=There%20is%20an%20extra%20change,pass%20in%20if%20it%20can)).
  - `XCTFail("msg")` → `#expect(false, "msg")` (or use `Issue.record` similarly).
  - `XCTAssertThrowsError(try something()) { error in ... }` → This one needs some restructuring. Use `#expect(throws: ErrorType.self) { try something() }` for the throw, and if you need to verify something about the error, you can follow it with additional expectations. For example, if you previously did `XCTAssertThrowsError(try foo()) { error in XCTAssertEqual(error as? MyError, MyError.someCase) }`, you can now do:
    ```swift
    #expect(throws: MyError.someCase) { try foo() }
    ``` 
    If the test only cared that *an* error is thrown (not specific), you could do `#expect(throws: Error.self) { ... }`, but typically you know what error type to expect. You can also verify side-effects after a throw as separate expectations (e.g., if throwing should trigger some callback, check that after the `#expect(throws:)`).
  - `XCTAssertNoThrow(try something())` → `#expect(throws: Never.self) { try something() }` as described earlier.

  It might help to refer to a mapping chart or documentation while doing this; Apple has provided comparison charts ([Using the #expect macro for Swift Testing - SwiftLee](https://www.avanderlee.com/swift-testing/expect-macro/#:~:text=)) ([Using the #expect macro for Swift Testing - SwiftLee](https://www.avanderlee.com/swift-testing/expect-macro/#:~:text=As%20you%20can%20see%2C%20many,covered%20in%20a%20future%20article)) and community guides list common mappings. After replacing assertions, double-check the logic—because `#expect` doesn’t stop the test, some XCTest patterns where subsequent code assumed the assertion passed might need adjusting. For example, if you did multiple asserts in sequence in XCTest, that code will still work (each `#expect` will just report failure and move on). But if you had an `XCTAssertNotNil(x)` followed by using `x!` in later code, in Swift Testing you should instead do `let xVal = try #require(x)` to ensure you have a non-nil value for use.

- **Test Life-cycle**: Remove any calls to `XCTestCase.setUp()` or `XCTestCase.tearDown()` (since those are no longer used). If you had `XCTestExpectation` and waited on asynchronous tasks, rewrite the test to use `async`/`await`. Swift Testing allows `async` tests naturally, so you can simply call asynchronous functions with `try await` and then do `#expect` on their results, rather than using fulfill/wait. For example, `let result = try await fetchData()` and then `#expect(result.isEmpty == false)`.

- **Run & Iterate**: Run the tests. Swift Testing tests will show up in Xcode’s Test navigator along with any remaining XCTest tests. If something isn’t running, ensure the function is annotated with `@Test` and that it’s part of a test target. Fix any compile errors (likely related to needing `try` with `#require`, or optional type mismatches if you used `#require` to unwrap something). The conversion typically makes tests much more concise. For any failing tests, examine the new failure messages – they should be quite clear on what’s different, often saving you from adding extra `print` debugging.

- **Gradual Migration**: There’s no need to convert everything at once. You can have some tests still subclassing `XCTestCase` with old assertions, and others using Swift Testing in the same suite. Xcode 16+ can execute both ([GitHub - swiftlang/swift-testing: A modern, expressive testing package for Swift](https://github.com/swiftlang/swift-testing#:~:text=Works%20with%20XCTest)). Over time, you might choose to move all unit tests to Swift Testing for consistency and to take advantage of new features. You might leave UI tests in XCTest if Swift Testing doesn’t yet support UI interactions at the level you need. Keep an eye on the development of Swift Testing for future support of UI testing.

## Conclusion
Swift Testing modernizes Swift’s testing infrastructure with a focus on expressiveness, safety, and developer efficiency. By using Swift’s language capabilities (macros, result builders, concurrency), it reduces boilerplate – tests require **less code** and yield more informative output ([Adding tests to your Xcode project - Apple Developer](https://developer.apple.com/documentation/Xcode/adding-tests-to-your-xcode-project#:~:text=A%20newer%2C%20modern%20testing%20framework,XCTest)). Key features like unified assertions with `#expect`, automatic optional unwrapping with `#require`, and parameterized tests can simplify test logic while increasing coverage. Traits and tagging bring flexibility in organizing and running tests, which is especially valuable in large projects or when running tests in CI pipelines. 

Because Swift Testing is open-source and cross-platform, it’s not confined to Xcode – Swift packages can use it across different OS environments, and the Swift community can contribute to its evolution ([GitHub - swiftlang/swift-testing: A modern, expressive testing package for Swift](https://github.com/swiftlang/swift-testing#:~:text=Swift%20Testing%20works%20on%20all,future%20of%20testing%20in%20Swift)) ([GitHub - swiftlang/swift-testing: A modern, expressive testing package for Swift](https://github.com/swiftlang/swift-testing#:~:text=Cross)). Apple has designed it to work alongside XCTest, lowering the barrier to adoption by allowing an incremental migration ([Swift Testing - Xcode - Apple Developer](https://developer.apple.com/xcode/swift-testing/#:~:text=Works%20with%20XCTest)). In practice, teams can start writing new tests in Swift Testing to reap its benefits (such as clearer failure diagnostics and easier maintenance) while keeping legacy tests running until they’re ready to transition.

Overall, Swift Testing is poised to become the future of testing in Swift. It maintains what developers liked about XCTest (like the Xcode integration and structured test runs) but removes a lot of historical baggage (class requirements, inconvenient asserts) and adds powerful new capabilities. As you incorporate Swift Testing into your workflow, you’ll likely find your tests are more *Swifty* – leveraging language features for clarity – and you might even enjoy writing tests more, thanks to the framework’s focus on making tests a “breeze” to write ([Swift Testing - Xcode - Apple Developer](https://developer.apple.com/xcode/swift-testing/#:~:text=Swift%20Testing)).

