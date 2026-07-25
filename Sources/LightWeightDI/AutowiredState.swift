import SwiftUI

/// SwiftUI injection: resolve from `shared` once and keep in `@State`. Use instead of `@Autowired` on `View`.
@propertyWrapper
public struct AutowiredState<Value>: DynamicProperty {
    @State private var value: Value

    /// Resolve from `DependencyResolver.shared`.
    public init() {
        _value = State(initialValue: AutowiredState.resolveFromShared())
    }

    /// Explicit instance (tests / manual wiring).
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

    /// Resolve path used by `init()`.
    public static func resolveFromShared() -> Value {
        let resolver = DependencyResolver.shared
        let graphID = UUID()
        resolver.startGraphSession(id: graphID)
        defer { resolver.endGraphSession() }
        return resolver.resolve(Value.self)
    }
}
