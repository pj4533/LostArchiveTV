Using SwiftUI ObservableObject with Protocols and Dependency Injection (iOS 17.4, Swift 5.9)

SwiftUI’s data-driven design works seamlessly with the Combine framework’s ObservableObject protocol and @Published properties. In large iOS/iPadOS apps that emphasize protocols and dependency injection (DI) for testability and modular architecture, it’s important to structure your ObservableObject view models and services properly. This report covers best practices for combining ObservableObject and @Published with protocols and DI, the limitations you might encounter, and common patterns or workarounds (with code examples) to address those issues. All information is based on the latest public releases (Swift 5.9+, Xcode 15.3, iOS 17.4).

Introduction: Protocol-Oriented View Models and DI in SwiftUI

In SwiftUI MVVM architecture, view models are often implemented as classes conforming to ObservableObject so that their state changes (via @Published properties) automatically update the UI. Dependency Injection (DI) involves supplying these view models with external dependencies (e.g. network services, data sources) at runtime rather than hard-coding them. Using protocols for those dependencies (and even for the view models themselves) allows for swapping implementations (for testing, previews, or different app configurations) without changing the view’s code ￼ ￼.

For example, you might define a MessageSender protocol for sending network requests, have your view model use that protocol, and inject either a real API client or a mock during tests. This decoupling makes logic more testable and your SwiftUI views simpler ￼:

protocol MessageSender {
    func sendMessage(_ content: String) async throws
}

@MainActor // ensure main-thread updates
class SendMessageViewModel: ObservableObject {
    @Published var message = ""
    @Published private(set) var errorText: String?  // output published value
    
    private let sender: MessageSender  // injected dependency
    
    init(sender: MessageSender) {
        self.sender = sender
    }
    
    func send() {
        guard !message.isEmpty else { return }
        // ... (set loading state)
        Task {
            do {
                try await sender.sendMessage(message)  // use protocol
                message = ""                           // update published state
            } catch {
                errorText = error.localizedDescription // update published state
            }
            // ... (reset loading state)
        }
    }
}

In the above example, SendMessageViewModel is injected with a MessageSender dependency. It conforms to ObservableObject and uses @Published to notify the SwiftUI view of changes in message and errorText ￼ ￼. The @MainActor attribute is used to ensure all published changes occur on the main thread, which is a best practice for SwiftUI.

Best Practices for ObservableObject, @Published, and Protocols

1. Define Protocols for Contracts, Not Stored Properties: Protocols should outline the interface (methods and computed properties) that your view model or service provides, but they cannot directly contain stored properties or property wrappers like @Published. For example, define a protocol that extends ObservableObject and includes plain properties and methods. Any @Published variables will be implemented in the concrete class, not in the protocol definition ￼ ￼:

protocol CounterViewModelProtocol: ObservableObject {
    var count: Int { get set }
    func didTapIncrement()
    func didTapDecrement()
}
final class CounterViewModelImpl: CounterViewModelProtocol {
    @Published var count: Int = 0    // stored property, publishes changes
    func didTapIncrement() { count += 1 }
    func didTapDecrement() { count -= 1 }
}

In this snippet, the protocol defines the requirements (count and the tap methods) but the @Published storage is in the concrete class. SwiftUI views can use CounterViewModelProtocol as an abstraction while still responding to count updates via Combine ￼ ￼.

2. Make Your Protocol Class-Bound (if needed) and Conform to ObservableObject: By extending your view model protocol to ObservableObject, you ensure any conforming class can be observed by SwiftUI’s @StateObject or @ObservedObject. This does constrain conformers to be classes (since ObservableObject is a class-constrained protocol), but that’s appropriate for view models. It also means the protocol inherits Combine’s default objectWillChange publisher (via an associated type). Note: Because ObservableObject has an associated type (ObjectWillChangePublisher), you usually cannot use the protocol as an existential type directly in a property wrapper. Instead, use generics or type erasure (explained below) to store an ObservableObject protocol in a view ￼ ￼.

3. Use @StateObject or @ObservedObject Correctly with DI: There are two common patterns for injecting an observable view model into a SwiftUI View:
	•	Initializer Injection with @StateObject: If the view owns the view model’s lifecycle, use @StateObject. You can pass a factory closure to StateObject in the initializer to inject a protocol-based object without multiple initializations. For example, using a generic view:

struct CounterView<VM: CounterViewModelProtocol>: View {
    @StateObject private var viewModel: VM
    init(viewModel: @autoclosure @escaping () -> VM) {
        _viewModel = StateObject(wrappedValue: viewModel())  // inject via autoclosure
    }
    // body uses viewModel.count ...
}

Here the view is generic over any CounterViewModelProtocol implementation. The @autoclosure @escaping trick delays creating the view model until SwiftUI sets up the StateObject, avoiding duplicate init calls ￼. This technique allows injecting different implementations (real or mock) into the view while letting SwiftUI manage the instance’s state.

	•	External Injection with @ObservedObject: If the view model is created outside the view (e.g. by a parent or DI container), pass it in and mark it with @ObservedObject. In this case, the view does not own the lifecycle. For example:

struct SendMessageView: View {
    @ObservedObject var viewModel: SendMessageViewModel  // conforms to MessageSenderProtocol & ObservableObject
    /* init(viewModel: MessageSenderProtocol & ObservableObject) {...} */
    var body: some View { /* use viewModel */ }
}

The property’s type must conform to ObservableObject (here the concrete class does). If you want to accept a protocol type, ensure the protocol extends ObservableObject (e.g. MessageSenderProtocol: ObservableObject) and use a generic or erased type. The Michigan Labs example demonstrates making the view generic over a ViewModel protocol for this reason ￼ ￼. Using @ObservedObject means the object is already instantiated (perhaps injected via a SwiftUI EnvironmentObject or passed down manually) and SwiftUI will subscribe to its publisher.

4. Inject Dependencies via Initializers or Environment: Adhere to DI principles by supplying any required services to your view model, rather than instantiating them internally. Common approaches:
	•	Initializer Injection: As shown above, pass protocol-typed dependencies into the view model’s initializer. In our SendMessageViewModel example, we inject a MessageSender when constructing the view model ￼. This makes the view model agnostic to which concrete service it’s using, enabling easy swapping for tests (e.g. injecting a MessageSenderMock) ￼.
	•	Environment Injection: Leverage SwiftUI’s environment to provide global or shared objects. You can define custom EnvironmentKey values for services. For instance, you might add an EnvironmentValues key for an APIClientProtocol. Then inside any view, use @Environment(\.apiClient) var api: APIClientProtocol to get the injected implementation. This avoids threading dependencies through multiple initializers. Antoine van der Lee recommends using the environment for linking dependencies from Swift Packages to your SwiftUI views, thereby decoupling modules ￼ ￼. Keep in mind that reading a value via @Environment does not automatically trigger view updates on changes unless the object itself is observable. If you need the view to update when a dependency changes, consider using @EnvironmentObject (which requires a concrete ObservableObject type). Environment objects are useful for global app state or singletons, but cannot be protocols directly (they rely on a concrete type for lookup). A workaround is to inject a type-erased wrapper or use environment keys as described.

5. Mark ViewModels with @MainActor (or ensure Main Thread Updates): SwiftUI expects UI-related changes to happen on the main thread. Publishing changes from background threads is not allowed – you’ll get runtime warnings (“Publishing changes from background threads is not allowed; make sure to publish values from the main thread”) if you violate this ￼ ￼. To avoid issues:
	•	Annotate your ObservableObject classes with @MainActor to automatically marshal their method executions and property access to the main thread ￼.
	•	If not using @MainActor, explicitly dispatch background results to the main queue before assigning to @Published properties. For example: DispatchQueue.main.async { self.status = .loaded }.

This ensures that any @Published property changes trigger SwiftUI updates on the main run loop ￼. (Combine’s @Published does not inherently switch threads for you – if a background task updates a published property, the update occurs on that background thread by default ￼ ￼.)

6. Use Protocols to Enable Testing and Previews: One big advantage of protocol-based design is the ability to provide mock or stub implementations in tests and SwiftUI previews. You can create a fake conforming class that supplies deterministic data. For example, Michigan Labs demonstrated a PreviewComplexViewModel that implements the same ComplexViewModel protocol but returns static state for SwiftUI previews ￼ ￼. Your SwiftUI PreviewProvider can instantiate the view with this mock view model to easily visualize different states:

// Protocol for view model (extends ObservableObject)
protocol ComplexViewModel: ObservableObject {
    var state: LoadingState { get }
    func load()
}
// Real implementation uses network:
final class NetworkBackedComplexViewModel: ComplexViewModel { ... }
// Preview implementation returns sample data:
final class PreviewComplexViewModel: ComplexViewModel {
    let state: LoadingState
    init(state: LoadingState) { self.state = state }
    func load() { /* no-op or immediate mock data */ }
}
// In Preview:
struct ComplexView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ComplexView(viewModel: PreviewComplexViewModel(state: .loading))
            ComplexView(viewModel: PreviewComplexViewModel(state: .loaded([])))
        }
    }
}

By hiding the view model behind a protocol, the view (ComplexView) doesn’t need to know whether it’s getting a real or preview implementation. It just cares that it has a state to display ￼ ￼. This makes it easy to test and preview UI in various scenarios without setting up actual data sources.

Similarly, for unit tests you might inject a mock service into your view model. In John Sundell’s example, a MessageSenderMock is injected so the asynchronous send logic can be tested deterministically. He even shows extending XCTestCase with helpers to wait for @Published property changes ￼ ￼, highlighting how the Combine publishers can be used to verify that an observable object’s state changed as expected in response to events.

Known Limitations of ObservableObject & @Published with Protocols/DI

While the above practices enable powerful architecture, be aware of some limitations:
	•	Cannot Define @Published in a Protocol Directly: Swift protocols can’t include stored properties or property wrappers. In the Stack Overflow question “How to define a protocol as a type for an @ObservedObject property?”, the accepted answer explains that you cannot put @Published var in a protocol or protocol extension ￼. The workaround is to declare a normal property in the protocol and then use @Published in the concrete class. (You can provide default implementations via protocol extensions for methods or computed properties, but stored data must live in a class.) In short, the protocol defines the contract (e.g. var title: String { get set }), and the conforming class provides the @Published var title to fulfill that contract ￼ ￼.
	•	Protocols with Associated Types Require Generics or Erasure: When a protocol extends ObservableObject, it inherits Combine’s associated type requirement (associatedtype ObjectWillChangePublisher), which means the protocol is technically a “PAT” (protocol with associated type). You cannot use such a protocol as an “opaque” any ObservableObject type without either (a) making the containing type generic, or (b) erasing the type. This is why many examples use a generic on the view (<VM: MyViewModelProtocol>) instead of something like @ObservedObject var viewModel: MyViewModelProtocol – the latter won’t compile unless you add any, and even with any ObservableObject you’d lose static type info for the publisher. The Michigan Labs article notes that because their ComplexViewModel protocol extends ObservableObject (with an associated type for the publisher), the ComplexView had to be generic over the protocol type ￼ ￼. Workaround: use a generic constraint in views (as shown above) or create a type-erased wrapper if you truly need to store heterogeneous ObservableObjects in one container.
	•	SwiftUI Property Wrapper Initialization Semantics: If you use @StateObject with protocol types, be careful to initialize it properly. SwiftUI requires that a @StateObject is initialized exactly once for the view (usually during the first render). The generic initializer with @autoclosure shown earlier is a pattern to ensure this. If you instead tried to do _viewModel = StateObject(wrappedValue: MyViewModel()) without a closure, you might inadvertently recreate the object on each re-init of the view. Likewise, if you use @ObservedObject, ensure the object is created outside and consistently passed in; if the reference changes, the view will treat it as a new object and reload state. Inconsistencies in initialization can lead to duplicate objects or lost state (e.g., reloading a view may recreate a view model if not handled correctly ￼).
	•	EnvironmentObject Type Restrictions: @EnvironmentObject is a convenient way to inject an observable object into many views without threading it through initializers, but it relies on type lookup. You cannot declare an @EnvironmentObject var foo: SomeProtocol unless that protocol is the exact type of an object you put into the environment. Typically, you provide a concrete object (e.g. UserSettings: ObservableObject) via .environmentObject(UserSettings()) in your App, and consumer views use the same concrete type. If your architecture demands protocol abstractions, you might skip EnvironmentObject in favor of a custom environment value (as discussed) or manage a container of type-erased objects. This is a limitation in flexibility – environment objects work best for shared, concrete state.
	•	Increased Complexity and Boilerplate: Introducing protocols for every view model can add indirection and code overhead. As one commentary notes, for simple screens a protocol + concrete class might be overkill ￼. You end up writing a protocol, an impl class, perhaps a preview class, etc., which is great for decoupling but means more code to maintain. Small apps might not need this level of abstraction, whereas larger apps benefit from it. It’s important to balance pragmatism and architecture – don’t introduce protocols/DI “just because.” Use them when you have multiple implementations (e.g., real vs test) or to invert dependencies for unit testing ￼ ￼.
	•	ObservableObject Publisher Behavior: By default, ObservableObject (via @Published) coalesces rapid changes and emits the objectWillChange prior to changes. One should be mindful that setting multiple @Published properties within a short time frame may result in a single combined UI refresh, not one per property (which is usually fine or even desirable). But if you rely on the order of events, know that @Published will send updates synchronously on the publishing thread by default. Also, SwiftUI’s view updating might skip intermediate states if multiple changes occur in one runloop tick. Usually this isn’t a “limitation” so much as an implementation detail, but it’s worth noting when debugging UI updates. If needed, you can manually call objectWillChange.send() in a custom scenario to control update timing.

Common Workarounds and Patterns

To overcome the above limitations and implement protocol-oriented DI in SwiftUI, consider these patterns:
	•	Generic Wrapper Views: As shown, make your SwiftUI views generic over the view model protocol. This avoids existential type issues and lets the compiler know the concrete type in use. You get the flexibility of abstraction with zero runtime cost. The view can be initialized with any conforming object, and SwiftUI will manage it as expected ￼ ￼. The trade-off is that the generic becomes part of the view’s type, which can slightly complicate the view hierarchy or usage of the view in tools like previews (usually manageable). If you prefer not to expose a generic to the outside, you can also hide it behind type-erased factories or use the protocol type in the initializer only.
	•	Abstract Base Classes: If protocols feel too cumbersome, another approach is to use an abstract base class for your view models. For example, define a class BaseItemViewModel: ObservableObject with some default behavior, and subclass it for concrete variants. This was the approach the Stack Overflow question asker initially attempted (with AbstractItemViewModel and then TestItemViewModel) ￼ ￼. You can still inject dependencies via initializers on the subclass. This isn’t as flexible as protocols (since Swift lacks true abstract classes and single inheritance means you can’t mix multiple “protocols”), but it can reduce boilerplate by sharing code in the base class. Protocol extensions can achieve a similar effect for multiple conforming classes (e.g., providing default method implementations) ￼, but remember they cannot hold state.
	•	Type Erasure for ViewModels: In situations where you cannot use a generic (say, you need to store different view model types in a single array, or you want a field of type “any view model”), you can implement a type-erased wrapper. For instance, an AnyViewModel class could hold an underlying ObservableObject and forward its objectWillChange. However, implementing a full type eraser that forwards @Published properties can be complex. Many developers find it simpler to stick with generics or separate properties, avoiding the need for type-erased ObservableObject. If you do need it, the pattern would be similar to how SwiftUI’s AnyView works, but for observable objects (not commonly seen in the wild due to the aforementioned complexity).
	•	Using @Environment for DI: As discussed, environment values are a powerful DI mechanism in SwiftUI. Define environment keys for your protocol types to make them easily accessible. For example:

private struct APIClientKey: EnvironmentKey {
    static let defaultValue: APIClientProtocol = RealAPIClient()  // default if not set
}
extension EnvironmentValues {
    var apiClient: APIClientProtocol {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

Now you can do MyView().environment(\.apiClient, MockAPIClient()) in tests or previews, and inside MyView use @Environment(\.apiClient) var apiClient to get it. This pattern keeps your views free of hard-coded dependencies and allows swapping implementations at the app level ￼ ￼. Do note that if APIClientProtocol is not an ObservableObject, changes in it won’t automatically refresh SwiftUI. Typically, services are stateless singletons or use callbacks to update view model state, so that’s fine.

	•	Pattern: ViewModel Protocol with Associated State/Events: In more complex apps, you may separate the view state (data to display) from the view model’s internal logic. One advanced pattern is to use a generic view model protocol with associated types for the view’s state and UI events. For example, Chris Hulbert’s “Previewable SwiftUI ViewModels” suggests a protocol ViewModel<ViewEvent, ViewState>: ObservableObject with an associated viewState property (often a struct or enum representing the UI state) and a handle(event:) method for inputs ￼. Concrete view models specify their ViewEvent and ViewState types, and the view is generic over the protocol constrained to those types. This design allows a clean separation: the view binds to viewState (often with @Published in the VM) and sends user actions through handle(event:). A generic PreviewViewModel can implement any ViewModel<Event, State> to feed sample states for UI previews ￼. While this is more involved, it scales well for larger teams by establishing a consistent pattern and enables very rich previews/testing. The downside is a lot of boilerplate in setting up those generics. Use such a pattern only if simpler MVVM isn’t meeting your needs.
	•	Testing Combine Publishers: When using protocols and DI, your business logic becomes easier to test because you can inject mocks and observe published outputs. It’s good practice to write unit tests for your ObservableObject classes. You can either use Combine’s sink in tests or utilize XCTest expectations. For example, Sundell’s extension of XCTestCase.waitUntil(_ propertyPublisher: Published<T>.Publisher, equals:) shows how to wait for a published value to meet a condition ￼ ￼. This kind of utility can be reused across many view model tests – a nice benefit of having your state in @Published properties. Keep in mind to call those from the main thread (or use XCTestExpectation appropriately) since the Combine subscription will deliver on whatever thread the value was published.

Conclusion

Using ObservableObject with @Published in a protocol-driven, dependency-injected architecture is not only possible in SwiftUI but highly encouraged for large apps. The key best practices are to isolate view state in ObservableObject classes, inject dependencies via protocols, and leverage SwiftUI property wrappers (with generics or environment techniques) to connect everything to the UI. This yields code that is modular, testable, and previewable – you can swap in mock implementations or preview data sources without altering your views, thanks to the power of protocols and DI ￼ ￼.

Be mindful of the limitations: you’ll write a bit more boilerplate and have to work around Swift’s constraints (no stored properties in protocols, associated type issues, main-thread updates). However, the community has established patterns to handle these, from using generics in views ￼ to utilizing environment keys and default implementations. By following the patterns described and using the latest SwiftUI improvements, you can create robust iOS/iPadOS apps that separate concerns cleanly.

Finally, note that Apple is continuing to evolve SwiftUI’s data model. In fact, Swift 5.9 introduced the Observation framework with the @Observable macro as a modern alternative to ObservableObject and @Published (aimed to reduce unnecessary view updates) ￼. While this report focused on the established ObservableObject pattern in iOS 17.4, it’s good to be aware of new tools as they become available. For now, the combination of ObservableObject, @Published, protocols, and dependency injection remains a proven approach for building testable and maintainable SwiftUI apps.

Sources:
	•	John Sundell, “Writing testable code when using SwiftUI” (Feb 2022) – discusses moving logic to view models and injecting dependencies for testability ￼ ￼.
	•	Stack Overflow – “How to define a protocol as a type for an @ObservedObject property?” – solution using a generic view model protocol and @ObservedObject in a generic View ￼ ￼.
	•	Alejandro Zalazar, “Using ViewModel with Protocols in SwiftUI” (Feb 2024) – guide on MVVM with generics, including code examples and pros/cons ￼ ￼.
	•	Michigan Labs, “Using View Model Protocols to manage complex SwiftUI views” (Mar 2021) – illustrates protocol-based view models to enable previews of network-driven views ￼ ￼.
	•	SwiftLee (Antoine van der Lee), “Using @Environment in SwiftUI to link Swift Package dependencies” (Apr 2024) – shows how to inject dependencies via SwiftUI’s environment to avoid tight coupling ￼ ￼.
	•	Chris Hulbert, “Previewable SwiftUI ViewModels” (May 2024) – presents a protocol with associated ViewState and ViewEvent for scalable MVVM and easy previews ￼ ￼.
	•	Apple Developer Forums – discussions on @Published and main thread requirements ￼ and on migrating to the new Observation framework.