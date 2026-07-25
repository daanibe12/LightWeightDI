/// Lazy injection from `DependencyResolver.shared`. For SwiftUI `View`, use `@AutowiredState`.
@attached(peer, names: prefixed(__di_))
@attached(accessor)
public macro Autowired() = #externalMacro(module: "LightWeightDIMacrosPlugin", type: "AutowiredMacro")
