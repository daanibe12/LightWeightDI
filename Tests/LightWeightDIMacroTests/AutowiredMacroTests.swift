import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

#if canImport(LightWeightDIMacrosPlugin)
import LightWeightDIMacrosPlugin

@Suite
struct AutowiredMacroExpansionTests {

    @Test
    func nonObservableExpandsLazyResolveWithShared() {
        assertMacroExpansion(
            """
            final class Holder {
                @Autowired var repository: GreeterRepository
            }
            """,
            expandedSource: """
            final class Holder {
                @Autowired var repository: GreeterRepository

                private var __di_repository: GreeterRepository?

                var repository: GreeterRepository {
                    get {
                        if let cached = __di_repository { return cached }
                        let resolver = DependencyResolver.shared
                        resolver.startGraphSession()
                        defer { resolver.endGraphSession() }
                        let resolved = resolver.resolve(GreeterRepository.self)
                        __di_repository = resolved
                        return resolved
                    }
                }
            }
            """,
            macros: ["Autowired": AutowiredMacro.self]
        )
    }

    @Test
    func diObservableExpandsWithObservationIgnored() {
        assertMacroExpansion(
            """
            @DIObservable
            final class ViewModel {
                @Autowired var repository: GreeterRepository
            }
            """,
            expandedSource: """
            @DIObservable
            final class ViewModel {
                @Autowired var repository: GreeterRepository

                @ObservationIgnored private var __di_repository: GreeterRepository?

                var repository: GreeterRepository {
                    get {
                        if let cached = __di_repository { return cached }
                        let resolver = DependencyResolver.shared
                        resolver.startGraphSession()
                        defer { resolver.endGraphSession() }
                        let resolved = resolver.resolve(GreeterRepository.self)
                        __di_repository = resolved
                        return resolved
                    }
                }
            }
            """,
            macros: ["Autowired": AutowiredMacro.self]
        )
    }
}
#endif
