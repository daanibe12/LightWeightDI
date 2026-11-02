import Testing
@testable import LightWeightDI
import Foundation

// Namespaces stand in for separate modules. Both declare a type named `Repository`.
enum FeatureA {
    final class Repository: AnyObject { let tag = "A" }
}

enum FeatureB {
    final class Repository: AnyObject { let tag = "B" }
}

/// Registration keys used to be `String(describing:)`, which drops the module
/// and the enclosing type. Two `Repository` types therefore collided, the second
/// registration overwrote the first, and the forced cast trapped.
struct TypeKeyCollisionTests {

    @Test func sameTypeNameInDifferentModulesDoesNotCollide() {
        let resolver = DependencyResolver()
        resolver.register(FeatureA.Repository.self, scope: .application) { _ in FeatureA.Repository() }
        resolver.register(FeatureB.Repository.self, scope: .application) { _ in FeatureB.Repository() }

        #expect(resolver.resolve(FeatureA.Repository.self).tag == "A")
        #expect(resolver.resolve(FeatureB.Repository.self).tag == "B")
    }

    @Test func sameTypeNameDoesNotCollideInGraphScope() {
        let resolver = DependencyResolver()
        resolver.register(FeatureA.Repository.self, scope: .graph) { _ in FeatureA.Repository() }
        resolver.register(FeatureB.Repository.self, scope: .graph) { _ in FeatureB.Repository() }

        #expect(resolver.resolve(FeatureA.Repository.self).tag == "A")
        #expect(resolver.resolve(FeatureB.Repository.self).tag == "B")
    }

    @Test func sameTypeNameDoesNotCollideInWeakScope() {
        let resolver = DependencyResolver()
        resolver.register(FeatureA.Repository.self, scope: .weak) { _ in FeatureA.Repository() }
        resolver.register(FeatureB.Repository.self, scope: .weak) { _ in FeatureB.Repository() }

        #expect(resolver.resolve(FeatureA.Repository.self).tag == "A")
        #expect(resolver.resolve(FeatureB.Repository.self).tag == "B")
    }
}
