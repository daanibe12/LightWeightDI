# LightWeightDI

![macOS](https://img.shields.io/badge/macOS-13+-green)
![iOS](https://img.shields.io/badge/iOS-14+-red)
![tvOS](https://img.shields.io/badge/tvOS-16+-blue)
![CocoaPods](https://img.shields.io/badge/CocoaPods-0.6.0-blue)
[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

A small, self-contained dependency injection library for Swift on Apple platforms. No third-party runtime dependencies.

## Features

- **`DependencyResolver`** — register and resolve dependencies by type
- **`@Autowired`** — property-wrapper injection with lazy resolution on first access
- **Three scopes** — `.weak` (default), `.application`, and `.graph`
- **Nested resolution** — factories receive the resolver so dependencies chain through the same container
- **Thread-safe** — internal `NSRecursiveLock` around container state
- **Graph scope** — deduplicates instances within a resolve chain and releases them when no strong references remain (unlike a permanent singleton cache)

## Requirements

| Platform | Version |
|----------|---------|
| iOS      | 14.0+   |
| macOS    | 13.0+   |
| tvOS     | 16.0+   |
| Swift    | 5.9+    |

## Installation

### Swift Package Manager

**Xcode:** File → Add Package Dependencies → enter the repository URL.

**Package.swift:**

```swift
dependencies: [
    .package(url: "https://github.com/daanibe12/LightWeightDI.git", from: "0.6.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["LightWeightDI"]
    )
]
```

### CocoaPods

```ruby
use_frameworks!

target 'YourApp' do
  pod 'LightWeightDI', '0.6.0'
end
```

## Quick start

Register types at app launch (e.g. in `AppDelegate` or `@main` `App` initializer), then use `@Autowired` on each type.

```swift
import LightWeightDI

// 1. Register (Composition Root) — .graph for screen-scoped trees, .application for app singletons
DependencyResolver.shared.regist(UserRepositoryProtocol.self, scope: .application) { _ in
    UserRepository()
}
DependencyResolver.shared.regist(ProfileViewModel.self, scope: .graph) { _ in ProfileViewModel() }

// 2. Types — dependencies via @Autowired, not init parameters
final class ProfileViewModel: AnyObject {
    @Autowired var repository: UserRepositoryProtocol
}

final class ProfileViewController: AnyObject {
    @Autowired var viewModel: ProfileViewModel
}

// 3. Use — resolved on first property access
let viewController = ProfileViewController()
let vm = viewController.viewModel  // ProfileViewModel resolved here
let repo = vm.repository          // UserRepository resolved here
```

## Registration

Two `regist` overloads are supported (0.6.0+):

```swift
// Legacy (still compiles — same as pre-0.6.0)
func regist<Service>(
    _ type: Service.Type,
    scope: ScopeType = .weak,
    factory: @escaping () -> Service
)

// Use when resolving nested dependencies inside the factory
func regist<Service>(
    _ type: Service.Type,
    scope: ScopeType = .weak,
    factory: @escaping (DependencyResolver) -> Service
)
```

**Legacy style** (no breaking change from older versions):

```swift
DependencyResolver.shared.regist(GreeterProtocol.self, scope: .application) {
    Greeter(name: "Hello")
}
```

**Nested resolve in factory** — pass the resolver parameter:

```swift
resolver.regist(AuthService.self, scope: .application) { r in
    AuthService(client: r.resolve(NetworkClient.self))
}
```

`{ _ in Foo() }` works with both overloads; `{ Foo() }` uses the legacy `() -> Service` overload.

### When to use `(DependencyResolver) -> Service`

Use the resolver parameter when the factory calls `r.resolve`. A `() -> Service` factory cannot reach the **current** container without hard-coding `DependencyResolver.shared`, which breaks isolated test containers and graph-scope sharing on a non-`shared` resolver.

## Scopes

| Scope | Behavior | Typical use |
|-------|----------|-------------|
| **`.weak`** (default) | New instance on every `resolve` | Stateless helpers, per-call values; explicit opt-in when omitted |
| **`.application`** | Single instance for the lifetime of the resolver (until `initialize()`) | App-wide singletons (API client, settings) |
| **`.graph`** | One instance per type while the object graph is being built; reused across `@Autowired` / nested `resolve`; weakly cached afterward and recreated when all strong references are gone | View models, presenters, screen-scoped services |

### `.weak` (default)

```swift
resolver.regist(TransientService.self) { _ in TransientService() }
// same as scope: .weak

let x = resolver.resolve(TransientService.self)
let y = resolver.resolve(TransientService.self)
// x !== y, factory runs every time
```

> **Naming note:** `.weak` here means *transient* (no instance cache in the container). It is not ARC `weak`. The container only stores the factory closure.

For nested `@Autowired` graphs and shared screen-scoped instances, register with **`.graph`** explicitly.

### `.application`

```swift
resolver.regist(Database.self, scope: .application) { _ in Database() }

let db1 = resolver.resolve(Database.self)
let db2 = resolver.resolve(Database.self)
// db1 === db2, factory runs once
```

### `.graph`

Graph scope deduplicates instances in two ways:

1. **During a single `resolve` call** — `activeGraphCache` is used while the factory runs (including nested `r.resolve` calls).
2. **Across `@Autowired` property access** — each first access starts a short graph session, then `weakGraphCache` reuses instances while something in the live object graph still holds them strongly.

#### Primary pattern: `@Autowired` + graph registration

Register each type with a simple factory. Wire the tree with **`@Autowired` on each type** — not with `r.resolve` inside factories.

**Object graph (what you are building):**

```
ProfilePresenter
├── useCase: ProfileUseCase          ← @Autowired on Presenter
│   └── repository: UserRepository   ← @Autowired on UseCase
└── repository: UserRepository       ← @Autowired on Presenter (second path to the same leaf)
```

**1. Registration** — factories only create the type itself:

```swift
DependencyResolver.shared.regist(UserRepository.self, scope: .graph) { _ in UserRepository() }
DependencyResolver.shared.regist(ProfileUseCase.self, scope: .graph) { _ in ProfileUseCase() }
DependencyResolver.shared.regist(ProfilePresenter.self, scope: .graph) { _ in ProfilePresenter() }
```

**2. Types** — each dependency is an `@Autowired` property on the parent:

```swift
final class UserRepository: AnyObject { /* ... */ }

final class ProfileUseCase: AnyObject {
    @Autowired var repository: UserRepository   // child → leaf
}

final class ProfilePresenter: AnyObject {
    @Autowired var useCase: ProfileUseCase      // parent → child (UseCase is injected here)
    @Autowired var repository: UserRepository   // parent → leaf (shortcut to the same type)
}
```

Nothing is injected in `init`. `ProfilePresenter` does not receive `ProfileUseCase` as a parameter — it gets `useCase` when you **read** `presenter.useCase`.

**3. Usage** — the graph is resolved lazily when properties are accessed:

```swift
var presenter = ProfilePresenter()
// At this point: no DI yet. useCase and repository are not resolved.

// Path A (indirect): Presenter → UseCase → Repository
let viaUseCase = presenter.useCase.repository

// Path B (direct): Presenter → Repository
let direct = presenter.repository

// Same UserRepository instance; its factory ran only once.
// viaUseCase === direct
```

**What happens step by step for `presenter.useCase.repository`:**

| Step | You read | `@Autowired` resolves |
|------|----------|------------------------|
| 1 | `presenter.useCase` | `ProfileUseCase` (created once, cached on `presenter`) |
| 2 | `.repository` on that use case | `UserRepository` (created once, cached on `useCase`) |

**What happens for `presenter.repository`:**

| Step | You read | Result |
|------|----------|--------|
| 3 | `presenter.repository` | Same `UserRepository` as step 2 (graph scope + still held by `useCase`) |

So `ProfileUseCase` enters the graph **only** because `ProfilePresenter` declares `@Autowired var useCase: ProfileUseCase` and you accessed `presenter.useCase`.

Nested graphs (diamond paths, siblings, deeper trees) work the same way: register with `.graph`, declare `@Autowired` on each parent, then read properties. No `r.resolve` inside factories is required.

When nothing strongly references a graph-scoped instance anymore, the next resolve can create a fresh one.

<details>
<summary>Optional: <code>init</code> injection without <code>@Autowired</code></summary>

If a type takes dependencies only through `init` and has no `@Autowired` properties, wire them in the factory with `r.resolve`. Sharing applies **within that single** `resolve(Root.self)` call:

```swift
resolver.regist(Branch.self, scope: .graph) { _ in Branch() }
resolver.regist(Root.self, scope: .graph) { r in
    Root(
        left: r.resolve(Branch.self),
        right: r.resolve(Branch.self)
    )
}
```

This is not needed when dependencies are declared with `@Autowired`.
</details>

## `@Autowired`

```swift
final class MyViewModel {
    @Autowired var repository: UserRepositoryProtocol
}
```

- Resolves from **`DependencyResolver.shared`** on **first** access to `wrappedValue`
- Caches the result on the owning instance (same property, same instance)
- Wraps each first-time resolve in a **graph session** (`startGraphSession` / `endGraphSession`)
- Together with **`.graph` registration**, this is how parent/child relationships are formed: reading `parent.child.grandchild` resolves each registered type and shares graph-scoped instances across the tree (via `activeGraphCache` during a session and `weakGraphCache` while strong references exist)

```swift
DependencyResolver.shared.regist(HeavyService.self, scope: .graph) { _ in HeavyService() }

final class MyHolder {
    @Autowired var service: HeavyService
}

var holder = MyHolder()
// HeavyService factory not called yet

let service = holder.service  // resolved and cached on this holder
let again = holder.service    // same instance (property cache)

// Another holder while the first still lives → same graph-scoped HeavyService
var other = MyHolder()
let shared = other.service
// service === shared when the first holder’s service is still strongly reachable
```

### Recommended usage

| Layer | Suggestion |
|-------|------------|
| View / ViewController / SwiftUI view | `@Autowired` is fine |
| ViewModel / UseCase / Repository | Prefer initializer injection for easier unit tests |
| App entry | Register everything on `DependencyResolver.shared` |

`@Autowired` implies a shared resolution root (like most property-wrapper DI). For testable core logic, pass dependencies through `init` and keep the container at the composition root.

## Manual resolve

You can resolve without the property wrapper:

```swift
let repo = DependencyResolver.shared.resolve(UserRepositoryProtocol.self)
```

Use this for one-off construction or when you need a new instance every time with `.weak` scope.

## Clearing the container

```swift
DependencyResolver.shared.initialize()
```

Removes all registrations and caches. Useful for test teardown or resetting preview/demo state.

## Testing

Create a **separate** resolver for tests so production registrations are untouched:

```swift
let testResolver = DependencyResolver()
testResolver.regist(UserRepositoryProtocol.self, scope: .application) { _ in
    MockUserRepository()
}

let sut = ProfileViewModel(repository: testResolver.resolve(UserRepositoryProtocol.self))
```

For code that uses `@Autowired` (bound to `shared`), reset in `setUp` / `tearDown`:

```swift
func setUp() {
    DependencyResolver.shared.initialize()
    DependencyResolver.shared.regist(UserRepositoryProtocol.self, scope: .application) { _ in
        MockUserRepository()
    }
}

func tearDown() {
    DependencyResolver.shared.initialize()
}
```

The package includes a Swift Testing suite under `Tests/LightWeightDITests`. Run:

```bash
swift test
```

## API reference

| API | Description |
|-----|-------------|
| `DependencyResolver.shared` | Default app-wide container |
| `DependencyResolver()` | Isolated container (tests, modules) |
| `regist(_:scope:factory:)` | Register a type with a factory |
| `resolve(_:)` | Resolve a registered type |
| `initialize()` | Clear registrations and all caches |
| `@Autowired` | Lazy property injection from `shared` |

## Comparison with heavier DI frameworks

LightWeightDI intentionally stays minimal:

- No storyboard integration
- No auto-wiring / reflection
- No child containers or assembly types
- Small API surface: register, resolve, three scopes, one property wrapper

If you need feature-rich container hierarchies, consider [Swinject](https://github.com/Swinject/Swinject) or [Factory](https://github.com/hmlongco/Factory). LightWeightDI targets projects that want a few hundred lines of DI without pulling in a larger framework.

## License

MIT — see [LICENSE](LICENSE).
