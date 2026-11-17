import Foundation

/// KeyPath injection root for `@Autowired(\.app)` and app-defined slots.
///
/// Add business resolvers in your app with `extension DIRoots { var abc: DependencyResolver { … } }`.
public struct DIRoots {
    public var app: DependencyResolver

    public init(app: DependencyResolver = .shared) {
        self.app = app
    }

    public static var current = DIRoots(app: .shared)
}