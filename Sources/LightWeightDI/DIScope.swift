import Foundation

/// Business / feature container. Use with `@Autowired(AbcDI.self)` when dependencies
/// are registered on a dedicated `DependencyResolver` instance.
///
/// Registration-only enums must **not** conform — only scope enums like `AbcDI`.
public protocol DIResolverScope {
    static var shared: DependencyResolver { get }
}