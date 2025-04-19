//
//  AppContainer.swift
//  Machiawase
//
//  Created by ebina on 2025/04/12.
//

import Swinject
import SwiftUI

public class AppContainer {
  static let appContainer = Container()
  public static func resolve<T>() -> T {
    guard let resolveValue = appContainer.resolve(T.self) else {
      fatalError("can not resolve")
    }
    return resolveValue
  }
  
  public static func register<T>(_ type: T.Type, factory: @escaping (Swinject.Resolver) -> T) {
    appContainer.register(type, factory: factory).inObjectScope(.container)
  }
  
  public static func initialize() {
    appContainer.removeAll()
  }
}




public class WeakContainer {
  static let weakContainer = Container()
  public static func resolve<T>() -> T {
    guard let resolveValue = weakContainer.resolve(T.self) else {
      fatalError("can not resolve")
    }
    return resolveValue
  }
  
  public static func register<T>(_ type: T.Type, factory: @escaping (Swinject.Resolver) -> T) {
    weakContainer.register(type, factory: factory).inObjectScope(.weak)
  }
  
  public static func initialize() {
    weakContainer.removeAll()
  }
}



@propertyWrapper
public struct Autowired<T> {
  private var dependency: T
  
  public init(isApp: Bool = false) {
    if isApp {
      dependency = AppContainer.resolve()
    } else {
      dependency = WeakContainer.resolve()
    }
    
  }
  public var wrappedValue: T {dependency}
}

@propertyWrapper
public struct AutowiredForState<T>: DynamicProperty where T: ObservableObject {
  @StateObject private var dependency: T
  public init(isApp: Bool = false) {
    if isApp {
      self._dependency = StateObject(wrappedValue: AppContainer.resolve())
    } else {
      self._dependency = StateObject(wrappedValue: WeakContainer.resolve())
    }
    
  }
  public var wrappedValue: T {
    get { return dependency }
  }
  public var projectedValue: ObservedObject<T>.Wrapper {
    return self.$dependency
  }
}
