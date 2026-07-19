import SwiftUI

/// SwiftUI counterpart to `@Autowired`: resolves from `DependencyResolver.shared` and owns the
/// instance with `@State` so it survives view updates.
///
/// ```swift
/// struct ProfileView: View {
///     @AutowiredState var viewModel: ProfileViewModel
///
///     var body: some View {
///         Text(viewModel.title)
///     }
/// }
///
/// ProfileView()
/// ```
///
/// Prefer this over `@Autowired` on `View` types: the `@Autowired` macro uses a `mutating`
/// getter (to cache on the struct), which cannot be accessed from `body`.
@propertyWrapper
public struct AutowiredState<Value>: DynamicProperty {
    @State private var value: Value

    /// Resolves `Value` from `DependencyResolver.shared` inside a graph session.
    public init() {
        _value = State(initialValue: AutowiredState.resolveFromShared())
    }

    /// Uses an explicit instance (previews, tests, parent injection).
    public init(wrappedValue: Value) {
        _value = State(initialValue: wrappedValue)
    }

    public var wrappedValue: Value {
        get { value }
        nonmutating set { value = newValue }
    }

    public var projectedValue: Binding<Value> {
        $value
    }

    /// Same resolve path as `init()` — useful for manual `State(initialValue:)` wiring.
    public static func resolveFromShared() -> Value {
        let resolver = DependencyResolver.shared
        resolver.startGraphSession()
        defer { resolver.endGraphSession() }
        return resolver.resolve(Value.self)
    }
}
