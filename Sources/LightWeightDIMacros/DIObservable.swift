import Observation

/// `@Observable` alternative that marks `@Autowired` members as `@ObservationIgnored`.
@attached(
    member,
    names: named(_$observationRegistrar), named(access), named(withMutation), arbitrary
)
@attached(memberAttribute)
@attached(extension, conformances: Observation.Observable)
public macro DIObservable() = #externalMacro(module: "LightWeightDIMacrosPlugin", type: "DIObservableMacro")
