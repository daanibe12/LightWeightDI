#if canImport(SwiftUI)
import SwiftUI

/// SwiftUI injection for `ObservableObject` view models.
///
/// `@Autowired` cannot be used on a `View`: a struct's property wrapper needs a
/// `mutating` getter, which `body` cannot call. This wrapper keeps the instance
/// in `@StateObject` instead, so the view owns it, resolves it once per view
/// identity, and subscribes to `objectWillChange` so `@Published` updates redraw
/// the body.
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
/// Register the view model with `.weak` scope: resolution happens once per view
/// identity, so a transient registration is enough. Use `.graph` for the
/// dependencies that view model shares within its own tree.
///
/// > Note: `StateObject`'s autoclosure is evaluated by SwiftUI during rendering,
/// > not when the wrapper is constructed. Code that only reads `wrappedValue`
/// > outside a view (unit tests, plain functions) therefore bypasses the
/// > memoization that a rendered view gets.
@propertyWrapper
public struct AutowiredObject<ObjectType: ObservableObject>: DynamicProperty {
    @StateObject private var dependency: ObjectType

    /// Resolves from `DependencyResolver.shared`.
    public init() {
        _dependency = StateObject(
            wrappedValue: DependencyResolver.shared.resolve(ObjectType.self)
        )
    }

    /// Explicit instance (tests, previews, manual wiring).
    public init(wrappedValue: ObjectType) {
        _dependency = StateObject(wrappedValue: wrappedValue)
    }

    public var wrappedValue: ObjectType {
        dependency
    }

    /// `$viewModel.title`
    public var projectedValue: ObservedObject<ObjectType>.Wrapper {
        $dependency
    }
}
#endif
