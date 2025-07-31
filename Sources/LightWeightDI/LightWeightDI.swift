//
//  AppContainer.swift
//  Machiawase
//
//  Created by ebina on 2025/04/12.
//

import Foundation
public enum ScopeType {
    case weak
    case application
}

public class DependencyResolver {
    public static let shard = DependencyResolver()
    private var weakFactories: [String: () -> Any] = [:]
    private var applicationInstances: [String: Any] = [:]
    
    private init() {}
    
    public func register<Service>(_ service: Service.Type, scope:
                           ScopeType, factory: @escaping () -> Service) {
        let key = String(describing: service)
        switch scope {
        case .weak:
            weakFactories[key] = factory
        case .application:
            applicationInstances[key] = factory()
        }
    }
    public func resolve<Service>(_ service: Service.Type) -> Service {
        let key = String(describing: service)
        if let instance = applicationInstances[key] as? Service {
            print("DIContainer: Resolved \(key) (Singleton Instance)")
            return instance
        }
        if let factory = weakFactories[key] {
            guard let instance = factory() as? Service else {
                fatalError("DIContainer: Could not cast transient")
            }
            print("DIContainer: Resolved \(key) (New Transient Instance)")
            return instance
        }
        
        fatalError("DIContainer: Dependency not found for \(key). Didyou forget to register it?")
    }
}



@propertyWrapper
public struct Autowired<Service> {
    private var dependency: Service
    
    public init() {
        self.dependency = DependencyResolver.shard.resolve(Service.self)
    }
    public var wrappedValue: Service {dependency}
}

