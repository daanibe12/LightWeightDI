//
//  AppContainer.swift
//  Machiawase
//
//  Created by ebina on 2026/04/12.
//

import Foundation

public enum ScopeType {
    case weak
    case application
    case graph
}

internal struct WeakBox {
    weak var value: AnyObject?
}

/// `.graph` cache key: the service type plus the owning tree's identity.
struct GraphKey: Hashable {
    let type: ObjectIdentifier
    let graphID: UUID
}

private struct DIRegistration {
    let scope: ScopeType
    let factory: (DependencyResolver) -> Any
}

/// Graph session for a single resolve chain, passed down the call stack.
///
/// This used to live on the resolver as a shared `graphIDStack`, so a session
/// opened on one thread could be observed by another. Passing it instead of
/// storing it keeps concurrent resolves on separate trees.
private struct GraphSession {
    let graphID: UUID
    /// Explicit sessions keep their strong cache until `endGraphSession()`.
    let retainsActiveCache: Bool
}

/// Thread-local handle to the tree a resolve belongs to.
///
/// `@Autowired` installs the owner's ID here for the duration of the resolve
/// and restores the previous value, so nested `@Autowired` / `r.resolve` calls
/// stay on the same tree without touching resolver state.
enum GraphContext {
    private static let key = "LightWeightDI.graphID"

    static var current: UUID? {
        get { Thread.current.threadDictionary[key] as? UUID }
        set {
            if let newValue {
                Thread.current.threadDictionary[key] = newValue
            } else {
                Thread.current.threadDictionary.removeObject(forKey: key)
            }
        }
    }

    /// Bind this thread to `graphID`, run `body`, then restore the previous ID.
    static func withGraph<T>(_ graphID: UUID, _ body: () -> T) -> T {
        let outer = current
        current = graphID
        defer { current = outer }
        return body()
    }
}

public final class DependencyResolver {
    public static let shared = DependencyResolver()
    internal let lock = NSRecursiveLock()
    private var registrations = [ObjectIdentifier: DIRegistration]()

    private var containerCache = [ObjectIdentifier: Any]()
    internal var weakGraphCache = [GraphKey: WeakBox]()
    internal var activeGraphCache = [GraphKey: Any]()

    /// Explicit sessions opened by `startGraphSession(id:)`, innermost last.
    private var activeSessions: [UUID] = []

    public init() {}

    /// Graph ID for an owner; used by `@Autowired` to share one tree.
    public static func graphIdentity(for object: AnyObject) -> UUID {
        DIGraphIdentity.getOrCreate(object)
    }

    public func initialize() {
        lock.lock(); defer { lock.unlock() }
        registrations.removeAll()
        containerCache.removeAll()
        weakGraphCache.removeAll()
        activeGraphCache.removeAll()
        activeSessions.removeAll()
    }

    public func register<Service>(_ type: Service.Type, scope: ScopeType = .weak, factory: @escaping () -> Service) {
        register(type, scope: scope) { _ in factory() }
    }

    public func register<Service>(_ type: Service.Type, scope: ScopeType = .weak, factory: @escaping (DependencyResolver) -> Service) {
        lock.lock(); defer { lock.unlock() }
        // Key on the type itself. Its name string drops the module, so two
        // `Repository` types in different modules would collide.
        registrations[ObjectIdentifier(type)] = DIRegistration(scope: scope, factory: factory)
    }

    /// Start a graph session with a fresh ID.
    public func startGraphSession() {
        startGraphSession(id: UUID())
    }

    public func startGraphSession(id: UUID) {
        lock.lock(); defer { lock.unlock() }
        activeSessions.append(id)
    }

    public func endGraphSession() {
        lock.lock(); defer { lock.unlock() }
        // An extra call is ignored instead of corrupting session state.
        guard let closed = activeSessions.popLast() else { return }
        if activeSessions.isEmpty {
            activeGraphCache.removeAll()
        } else {
            removeActiveEntries(for: closed)
        }
    }

    public func resolve<Service>(_ type: Service.Type) -> Service {
        let session = openSession()
        defer { closeSession(session) }

        // Keep the tree visible to factories on this thread so a nested
        // `r.resolve` inside a factory rejoins the same session.
        return GraphContext.withGraph(session.graphID) {
            performResolve(type, session: session)
        }
    }

    private func performResolve<Service>(_ type: Service.Type, session: GraphSession) -> Service {
        lock.lock(); defer { lock.unlock() }
        let typeKey = ObjectIdentifier(type)

        guard let registration = registrations[typeKey] else {
            fatalError("🚨 LightWeightDI: \(type) が未登録です。")
        }

        if registration.scope == .application {
            if let cached = containerCache[typeKey] as? Service { return cached }
            let instance = registration.factory(self) as! Service
            containerCache[typeKey] = instance
            return instance
        }
        if registration.scope == .weak {
            let instance = registration.factory(self) as! Service
            if let object = Self.classObject(instance) {
                DIGraphIdentity.set(session.graphID, on: object)
            }
            return instance
        }

        let key = Self.graphCacheKey(typeKey: typeKey, graphID: session.graphID)

        if let strongInstance = activeGraphCache[key] as? Service {
            return strongInstance
        }
        if let box = weakGraphCache[key], let cachedInstance = box.value as? Service {
            return cachedInstance
        }

        let instance = registration.factory(self) as! Service
        activeGraphCache[key] = instance
        if let object = Self.classObject(instance) {
            weakGraphCache[key] = WeakBox(value: object)
            DIGraphIdentity.set(session.graphID, on: object)
        }

        return instance
    }

    // MARK: - Session lifecycle

    /// Precedence: explicit `startGraphSession(id:)` > ambient `@Autowired` owner > fresh tree.
    private func openSession() -> GraphSession {
        lock.lock(); defer { lock.unlock() }
        if let explicit = activeSessions.last {
            return GraphSession(graphID: explicit, retainsActiveCache: true)
        }
        if let ambient = GraphContext.current {
            return GraphSession(graphID: ambient, retainsActiveCache: false)
        }
        return GraphSession(graphID: UUID(), retainsActiveCache: false)
    }

    private func closeSession(_ session: GraphSession) {
        guard !session.retainsActiveCache else { return }
        lock.lock(); defer { lock.unlock() }
        // Objects stay reachable through `weakGraphCache` while owners hold them,
        // so the strong copies can be dropped once the resolve returns.
        removeActiveEntries(for: session.graphID)
    }

    private func removeActiveEntries(for graphID: UUID) {
        guard !activeGraphCache.isEmpty else { return }
        activeGraphCache = activeGraphCache.filter { $0.key.graphID != graphID }
    }

    private static func graphCacheKey(typeKey: ObjectIdentifier, graphID: UUID) -> GraphKey {
        GraphKey(type: typeKey, graphID: graphID)
    }

    private static func classObject<T>(_ value: T) -> AnyObject? {
        guard Swift.type(of: value) is AnyClass else { return nil }
        return value as AnyObject
    }
}

@propertyWrapper
public struct Autowired<Service> {
    fileprivate var cachedValue: Service?

    /// Fallback for value-type owners (no `_enclosingInstance`).
    public var wrappedValue: Service {
        mutating get {
            if let cached = cachedValue { return cached }

            let resolved = DependencyResolver.shared.resolve(Service.self)
            cachedValue = resolved
            return resolved
        }
        set {
            cachedValue = newValue
        }
    }

    /// Class owners share one graph ID so nested `@Autowired` trees stay isolated per root.
    public static subscript<EnclosingSelf: AnyObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Service>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Autowired<Service>>
    ) -> Service {
        get {
            if let cached = object[keyPath: storageKeyPath].cachedValue {
                return cached
            }

            let graphID = DependencyResolver.graphIdentity(for: object)

            // Bind only this thread to the owner's tree, then restore. No resolver
            // state is mutated, so parallel screens cannot observe each other.
            let resolved = GraphContext.withGraph(graphID) {
                DependencyResolver.shared.resolve(Service.self)
            }

            var storage = object[keyPath: storageKeyPath]
            storage.cachedValue = resolved
            object[keyPath: storageKeyPath] = storage
            return resolved
        }
        set {
            var storage = object[keyPath: storageKeyPath]
            storage.cachedValue = newValue
            object[keyPath: storageKeyPath] = storage
        }
    }

    public init() {}
}
