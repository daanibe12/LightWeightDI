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

private struct DIRegistration {
    let scope: ScopeType
    let factory: (DependencyResolver) -> Any
}

public final class DependencyResolver {
    public static let shared = DependencyResolver()
    internal let lock = NSRecursiveLock()
    private var registrations = [String: DIRegistration]()

    private var containerCache = [String: Any]()
    /// `.graph` cache key: `typeName#graphID`.
    internal var weakGraphCache = [String: WeakBox]()
    internal var activeGraphCache = [String: Any]()
    fileprivate var activeSessionCount = 0
    fileprivate var graphIDStack = [UUID]()

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
        activeSessionCount = 0
        graphIDStack.removeAll()
    }

    public func register<Service>(_ type: Service.Type, scope: ScopeType = .weak, factory: @escaping () -> Service) {
        register(type, scope: scope) { _ in factory() }
    }

    public func register<Service>(_ type: Service.Type, scope: ScopeType = .weak, factory: @escaping (DependencyResolver) -> Service) {
        lock.lock(); defer { lock.unlock() }
        registrations[String(describing: type)] = DIRegistration(scope: scope, factory: factory)
    }

    /// Start a graph session with a fresh ID.
    public func startGraphSession() {
        startGraphSession(id: UUID())
    }

    public func startGraphSession(id: UUID) {
        lock.lock(); defer { lock.unlock() }
        activeSessionCount += 1
        graphIDStack.append(id)
    }

    public func endGraphSession() {
        lock.lock(); defer { lock.unlock() }
        activeSessionCount -= 1
        if !graphIDStack.isEmpty {
            graphIDStack.removeLast()
        }
        if activeSessionCount == 0 {
            activeGraphCache.removeAll()
            graphIDStack.removeAll()
        }
    }

    public func resolve<Service>(_ type: Service.Type) -> Service {
        lock.lock(); defer { lock.unlock() }
        let typeKey = String(describing: type)

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
            if let graphID = graphIDStack.last, let object = Self.classObject(instance) {
                DIGraphIdentity.set(graphID, on: object)
            }
            return instance
        }

        let startedSession = activeSessionCount == 0
        if startedSession {
            activeSessionCount = 1
            graphIDStack.append(UUID())
        }
        defer {
            if startedSession {
                activeSessionCount = 0
                graphIDStack.removeAll()
                activeGraphCache.removeAll()
            }
        }

        let graphID = graphIDStack.last!
        let key = Self.graphCacheKey(typeKey: typeKey, graphID: graphID)

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
            DIGraphIdentity.set(graphID, on: object)
        }

        return instance
    }

    private static func graphCacheKey(typeKey: String, graphID: UUID) -> String {
        "\(typeKey)#\(graphID.uuidString)"
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

            let resolver = DependencyResolver.shared
            resolver.startGraphSession()
            defer { resolver.endGraphSession() }
            let resolved = resolver.resolve(Service.self)
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

            let resolver = DependencyResolver.shared
            let graphID = DependencyResolver.graphIdentity(for: object)
            resolver.startGraphSession(id: graphID)
            defer { resolver.endGraphSession() }
            let resolved = resolver.resolve(Service.self)

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
