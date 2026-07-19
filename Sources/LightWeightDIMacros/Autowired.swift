/// Lazy dependency injection from `DependencyResolver.shared` on first property access.
///
/// On SwiftUI `View` types, use `@AutowiredState` instead: this macro caches with a
/// `mutating` getter, which cannot be read from `body`.
@attached(peer, names: prefixed(__di_))
@attached(accessor)
public macro Autowired() = #externalMacro(module: "LightWeightDIMacrosPlugin", type: "AutowiredMacro")
