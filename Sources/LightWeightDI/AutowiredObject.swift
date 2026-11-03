#if canImport(SwiftUI)
import SwiftUI

/// Reference box so a `struct` can cache a resolved instance without a
/// `mutating` getter. The graph ID stays with the box, so every resolve made
/// through one wrapper shares a single `.graph` tree.
private final class DIBox<Value> {
    var value: Value?
    let graphID = UUID()
}

/// SwiftUI injection for `ObservableObject` view models.
///
/// `@Autowired` cannot be used on a `View`: a struct's property wrapper needs a
/// `mutating` getter, which `body` cannot call. This wrapper keeps the instance
/// in `@State` so the view owns it for its lifetime and changes publish through
/// `ObservableObject`.
///
/// ```swift
/// struct ProfileView: View {
///     @AutowiredObject var viewModel: ProfileViewModel
///
///     var body: some View {
///         Text(viewModel.title)
///     }
/// }
/// ```
///
/// Use `.weak` scope so each view gets its own root, and `.graph` for the
/// dependencies it shares within that tree.
@propertyWrapper
public struct AutowiredObject<ObjectType: ObservableObject>: DynamicProperty {
    @State private var box = DIBox<ObjectType>()

    /// Resolves from `DependencyResolver.shared` on first access.
    public init() {}

    /// Explicit instance (tests, previews, manual wiring).
    public init(wrappedValue: ObjectType) {
        let box = DIBox<ObjectType>()
        box.value = wrappedValue
        _box = State(initialValue: box)
    }

    public var wrappedValue: ObjectType {
        if let cached = box.value { return cached }
        let resolved = DependencyResolver.shared.resolve(ObjectType.self)
        box.value = resolved
        return resolved
    }

    /// `$viewModel.title`
    public var projectedValue: ObservedObject<ObjectType>.Wrapper {
        ObservedObject(wrappedValue: wrappedValue).projectedValue
    }
}
#endif
