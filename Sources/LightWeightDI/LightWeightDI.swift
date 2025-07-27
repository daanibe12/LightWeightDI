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

public class AppContainer {
    public static let shard = AppContainer()
    
    // Transient スコープ用のファクトリを保持
    private var weakFactories: [String: () -> Any] = [:]
    // Singleton スコープ用のインスタンスを保持
    private var applicationInstances: [String: Any] = [:]
    
    private init() {}
    
    public func register<Service>(_ service: Service.Type, scope:
                           ScopeType, factory: @escaping () -> Service) {
        let key = String(describing: service)
        switch scope {
        case .weak:
            weakFactories[key] = factory
        case .application:
            // シングルトンの場合、初回登録時にインスタンスを生成して保持
            applicationInstances[key] = factory()
        }
    }
    public func resolve<Service>(_ service: Service.Type) -> Service {
        let key = String(describing: service)
        
        // まずシングルトンとして登録されているか確認
        if let instance = applicationInstances[key] as? Service {
            print("DIContainer: Resolved \(key) (Singleton Instance)")
            return instance
        }
        
        // 次にトランジェントとしてファクトリが登録されているか確認
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
        self.dependency = AppContainer.shard.resolve(Service.self)
    }
    public var wrappedValue: Service {dependency}
}

