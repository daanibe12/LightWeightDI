import Observation

/// Observation-compatible macro for types that use `@Autowired`.
///
/// Marks `@Autowired` properties with `@ObservationIgnored` so they compose with
/// the `@Autowired` accessor macro. Prefer this over Observation's `@Observable`
/// when the type also uses `@Autowired`.
@attached(
    member,
    names: named(_$observationRegistrar), named(access), named(withMutation), arbitrary
)
@attached(memberAttribute)
@attached(extension, conformances: Observation.Observable)
public macro DIObservable() = #externalMacro(module: "LightWeightDIMacrosPlugin", type: "DIObservableMacro")
