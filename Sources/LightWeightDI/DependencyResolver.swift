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
    internal var weakGraphCache = [String: WeakBox]()
    internal var activeGraphCache = [String: Any]()
    fileprivate var activeSessionCount = 0

    public init() {}

    public func initialize() {
        lock.lock(); defer { lock.unlock() }
        registrations.removeAll()
        containerCache.removeAll()
        weakGraphCache.removeAll()
        activeGraphCache.removeAll()
        activeSessionCount = 0
    }

    public func register<Service>(_ type: Service.Type, scope: ScopeType = .weak, factory: @escaping () -> Service) {
        register(type, scope: scope) { _ in factory() }
    }

    public func register<Service>(_ type: Service.Type, scope: ScopeType = .weak, factory: @escaping (DependencyResolver) -> Service) {
        lock.lock(); defer { lock.unlock() }
        registrations[String(describing: type)] = DIRegistration(scope: scope, factory: factory)
    }

    public func startGraphSession() {
        lock.lock(); defer { lock.unlock() }
        activeSessionCount += 1
    }

    public func endGraphSession() {
        lock.lock(); defer { lock.unlock() }
        activeSessionCount -= 1
        if activeSessionCount == 0 {
            activeGraphCache.removeAll()
        }
    }

    public func resolve<Service>(_ type: Service.Type) -> Service {
        lock.lock(); defer { lock.unlock() }
        let key = String(describing: type)

        guard let registration = registrations[key] else {
            fatalError("🚨 LightWeightDI: \(type) が未登録です。")
        }

        if registration.scope == .application {
            if let cached = containerCache[key] as? Service { return cached }
            let instance = registration.factory(self) as! Service
            containerCache[key] = instance
            return instance
        }
        if registration.scope == .weak { return registration.factory(self) as! Service }
        if let strongInstance = activeGraphCache[key] as? Service {
            return strongInstance
        }
        if let box = weakGraphCache[key], let cachedInstance = box.value as? Service {
            return cachedInstance
        }

        let instance = registration.factory(self) as! Service
        activeGraphCache[key] = instance
        weakGraphCache[key] = WeakBox(value: instance as AnyObject)

        return instance
    }
}
