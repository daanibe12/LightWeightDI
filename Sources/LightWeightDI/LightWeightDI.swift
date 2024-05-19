// The Swift Programming Language
// https://docs.swift.org/swift-book
import SwiftUI
import Swinject


public class DependencyResolver {
    public static let shared = DependencyResolver()
    private var container: Container = Container()
    public func initialize() {
        container = Container()
    }
    public func resolve<T>() -> T {
        guard let resolveValue = container.resolve(T.self) else {
            fatalError("can not resolve")
        }
        return resolveValue
    }
    
    public func regist<T>(_ type: T.Type, scope: Swinject.ObjectScope = .weak, factory: @escaping (Swinject.Resolver) -> T) {
        container.register(type, factory: factory).inObjectScope(scope)
    }
}

@propertyWrapper
public struct Autowired<T> {
    private var dependency: T

    public init() {
        dependency = DependencyResolver.shared.resolve()
    }
    public var wrappedValue: T {dependency}
}

@propertyWrapper 
public struct AutowiredStateObj<T>: DynamicProperty where T: ObservableObject {
    @StateObject private var dependency: T
    public init() {
        self._dependency = StateObject(wrappedValue: DependencyResolver.shared.resolve())
    }
    public var wrappedValue: T {
        get { return dependency }
    }
    public var projectedValue: ObservedObject<T>.Wrapper {
        return self.$dependency
    }
}





