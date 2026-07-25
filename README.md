# LightWeightDI

![macOS](https://img.shields.io/badge/macOS-13+-green)
![iOS](https://img.shields.io/badge/iOS-14+-red)
![tvOS](https://img.shields.io/badge/tvOS-16+-blue)
[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

A small, self-contained dependency injection library for Swift on Apple platforms. No third-party runtime dependencies.

## Features

- **`DependencyResolver`** — register and resolve dependencies by type
- **`@Autowired`** — macro-based lazy injection on first property access
- **`@AutowiredState`** — SwiftUI `DynamicProperty` that resolves once and owns the instance with `@State`
- **`@DIObservable`** — Observation-compatible macro that marks `@Autowired` members as `@ObservationIgnored`
- **Three scopes** — `.weak` (default), `.application`, and `.graph`
- **Nested resolution** — factories receive the resolver so dependencies chain through the same container
- **Thread-safe** — internal `NSRecursiveLock` around container state
- **Graph scope** — deduplicates instances within one object tree (UseCase / Repository diamonds), isolated per owning root so navigation stacks do not collide

## Requirements

| Platform | Version |
|----------|---------|
| iOS      | 14.0+   |
| macOS    | 13.0+   |
| tvOS     | 16.0+   |
| Swift    | 5.9+    |

`@DIObservable` uses the Observation framework (iOS 17+ / macOS 14+ / tvOS 17+).

## Installation

**Xcode:** File → Add Package Dependencies → enter the repository URL.

`@Autowired` and `@DIObservable` are implemented as Swift macros. The first time you add this package, Xcode will ask you to **Trust & Enable** the macro plugin. That is expected — macros run at compile time, so Xcode requires an explicit allow. Without trusting them, the macros will not expand and builds that use `@Autowired` / `@DIObservable` will fail.

Core APIs (`DependencyResolver`, `register` / `resolve`, `@AutowiredState`) work without enabling macros.

**Package.swift:**

```swift
dependencies: [
    .package(url: "https://github.com/daanibe12/LightWeightDI.git", from: "0.7.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["LightWeightDI"]
    )
]
```

Installation is **Swift Package Manager only**. CocoaPods support was removed in 0.7.0.

## Quick start

Register types at app launch (e.g. in `AppDelegate` or `@main` `App` initializer).

- **ViewModel** → `.weak` (default): one instance per screen / owner
- **UseCase / Repository** (shared inside one VM tree) → `.graph`
- **App singletons** → `.application`

```swift
import LightWeightDI

// 1. Register (Composition Root)
DependencyResolver.shared.register(UserRepositoryProtocol.self, scope: .application) { _ in
    UserRepository()
}
DependencyResolver.shared.register(ProfileUseCase.self, scope: .graph) { _ in
    ProfileUseCase()
}
DependencyResolver.shared.register(ProfileViewModel.self) { _ in  // .weak
    ProfileViewModel()
}

// 2. Types
final class ProfileUseCase {
    @Autowired var repository: UserRepositoryProtocol
}

final class ProfileViewModel {
    @Autowired var useCase: ProfileUseCase
}

final class ProfileViewController {
    @Autowired var viewModel: ProfileViewModel
}

// 3. Use — resolved on first property access
let viewController = ProfileViewController()
let vm = viewController.viewModel  // new ProfileViewModel (.weak)
let repo = vm.useCase.repository   // UserRepository from the tree
```

### SwiftUI

Do **not** put `@Autowired` on a `View` (struct getters are `mutating` and cannot be read from `body`). Use `@AutowiredState` instead:

```swift
struct ProfileView: View {
    @AutowiredState var viewModel: ProfileViewModel

    var body: some View {
        Text(viewModel.title)
    }
}

ProfileView()  // resolves ProfileViewModel once and keeps it in @State
```

When the ViewModel also uses Observation + `@Autowired`, prefer `@DIObservable` over Observation’s `@Observable`:

```swift
@DIObservable
final class ProfileViewModel {
    @Autowired var useCase: ProfileUseCase
    var title = ""
}
```

## Registration

Two `register` overloads are supported:

```swift
func register<Service>(
    _ type: Service.Type,
    scope: ScopeType = .weak,
    factory: @escaping () -> Service
)

func register<Service>(
    _ type: Service.Type,
    scope: ScopeType = .weak,
    factory: @escaping (DependencyResolver) -> Service
)
```

**Legacy style** (`() -> Service`):

```swift
DependencyResolver.shared.register(GreeterProtocol.self, scope: .application) {
    Greeter(name: "Hello")
}
```

**Nested resolve in factory** — pass the resolver parameter:

```swift
resolver.register(AuthService.self, scope: .application) { r in
    AuthService(client: r.resolve(NetworkClient.self))
}
```

`{ _ in Foo() }` works with both overloads; `{ Foo() }` uses the legacy `() -> Service` overload.

### When to use `(DependencyResolver) -> Service`

Use the resolver parameter when the factory calls `r.resolve`. A `() -> Service` factory cannot reach the **current** container without hard-coding `DependencyResolver.shared`, which breaks isolated test containers and graph-scope sharing on a non-`shared` resolver.

## Scopes

| Scope | Behavior | Typical use |
|-------|----------|-------------|
| **`.weak`** (default) | New instance on every `resolve` | **ViewModels**, presenters owned by a screen, transient helpers |
| **`.application`** | Single instance for the lifetime of the resolver (until `initialize()`) | App-wide singletons (API client, settings) |
| **`.graph`** | One instance per type **within one object tree** (a graph session keyed by the owning instance); weakly reused for further `@Autowired` on that same tree while references remain | **UseCase / Repository** shared inside one VM tree — e.g. diamond dependencies |

### Why ViewModels should be `.weak`

A ViewModel is normally **one per screen**. Prefer `.weak` so each resolve creates a new root. Independently, `.graph` is already **isolated per owning tree** (each screen / holder gets its own graph identity), so two `ProfileView`s on a `NavigationStack` do not share UseCase / Repository instances either.

```text
Stack: Profile(user-1) → VM① → Repo①
       Profile(user-2) → VM② → Repo②   // separate trees
```

### `.weak` (default)

```swift
resolver.register(ProfileViewModel.self) { _ in ProfileViewModel() }
// same as scope: .weak

let x = resolver.resolve(ProfileViewModel.self)
let y = resolver.resolve(ProfileViewModel.self)
// x !== y, factory runs every time
```

> **Naming note:** `.weak` here means *transient* (no instance cache in the container). It is not ARC `weak`. The container only stores the factory closure.

### `.application`

```swift
resolver.register(Database.self, scope: .application) { _ in Database() }

let db1 = resolver.resolve(Database.self)
let db2 = resolver.resolve(Database.self)
// db1 === db2, factory runs once
```

### `.graph`

Graph scope deduplicates instances **inside one object tree**:

1. **During a single `resolve` / graph session** — nested `r.resolve` calls share via `activeGraphCache`.
2. **Across `@Autowired` on the same owner (and objects created in that tree)** — each owner has a graph identity; further resolves reuse that tree’s `weakGraphCache` entries while strong references remain.

Different owners (two screens, two holders) get **different** graph identities, so they do not share `.graph` instances even while both are alive. This matches Swinject-style “one graph per root,” not a process-wide soft singleton.

#### Primary pattern: `@Autowired` + graph under the ViewModel

Register shared tree nodes with `.graph`. Keep the screen-owned root (ViewModel / Presenter held by the view) as `.weak`.

**Object graph:**

```
ProfileViewModel              ← .weak (owned by the screen)
├── useCase: ProfileUseCase   ← .graph + @Autowired
│   └── repository: UserRepository   ← .graph
└── repository: UserRepository       ← same instance (diamond)
```

**1. Registration:**

```swift
DependencyResolver.shared.register(UserRepository.self, scope: .graph) { _ in UserRepository() }
DependencyResolver.shared.register(ProfileUseCase.self, scope: .graph) { _ in ProfileUseCase() }
DependencyResolver.shared.register(ProfileViewModel.self) { _ in ProfileViewModel() }  // .weak
```

**2. Types** — each dependency is an `@Autowired` property on the parent:

```swift
final class UserRepository { /* ... */ }

final class ProfileUseCase {
    @Autowired var repository: UserRepository
}

final class ProfileViewModel {
    @Autowired var useCase: ProfileUseCase
    @Autowired var repository: UserRepository
}
```

**3. Usage** — the graph under the VM is resolved lazily when properties are accessed:

```swift
var viewModel = ProfileViewModel()
// At this point: no DI yet.

let viaUseCase = viewModel.useCase.repository
let direct = viewModel.repository
// viaUseCase === direct ; UserRepository factory ran only once
```

Nested graphs (diamond paths, siblings, deeper trees) work the same way below the ViewModel: register with `.graph`, declare `@Autowired` on each parent, then read properties.

When nothing strongly references a graph-scoped instance anymore, the next resolve can create a fresh one.

<details>
<summary>Optional: <code>init</code> injection without <code>@Autowired</code></summary>

If a type takes dependencies only through `init` and has no `@Autowired` properties, wire them in the factory with `r.resolve`. Sharing applies **within that single** `resolve(Root.self)` call:

```swift
resolver.register(Branch.self, scope: .graph) { _ in Branch() }
resolver.register(Root.self, scope: .graph) { r in
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

- Resolves from **`DependencyResolver.shared`** on **first** access
- Caches the result on the owning instance
- Wraps each first-time resolve in a **graph session** (`startGraphSession` / `endGraphSession`)
- Together with **`.graph` registration** on UseCase / Repository, reading `parent.child.grandchild` shares instances across the tree

```swift
DependencyResolver.shared.register(HeavyService.self, scope: .graph) { _ in HeavyService() }

final class MyHolder {
    @Autowired var service: HeavyService
}

var holder = MyHolder()
let service = holder.service  // resolved and cached on this holder
let again = holder.service    // same instance (property cache)
```

### Recommended usage

| Layer | Suggestion |
|-------|------------|
| SwiftUI `View` | `@AutowiredState` (not `@Autowired`) |
| UIKit `UIViewController` | `@Autowired` for the ViewModel is fine |
| ViewModel | Prefer `.weak`; `@Autowired` or init injection for deps |
| UseCase / Repository | `.graph` when shared inside one VM tree; init injection for unit tests |
| App entry | Register everything on `DependencyResolver.shared` |

## `@AutowiredState`

SwiftUI counterpart to `@Autowired`: resolves from `shared` inside a graph session and stores the value in `@State`.

```swift
struct ProfileView: View {
    @AutowiredState var viewModel: ProfileViewModel

    var body: some View {
        Text(viewModel.title)
    }
}
```

Use `AutowiredState(wrappedValue:)` only when you need an explicit instance (advanced / manual wiring). Everyday screens just declare the property and call `ProfileView()`.

## `@DIObservable`

Use instead of Observation’s `@Observable` when the same class also has `@Autowired` properties. `@Autowired` members become `@ObservationIgnored`; other stored properties are tracked.

## Manual resolve

```swift
let repo = DependencyResolver.shared.resolve(UserRepositoryProtocol.self)
```

Use for one-off construction or when you need a new instance every time with `.weak` scope.

## Clearing the container

```swift
DependencyResolver.shared.initialize()
```

Removes all registrations and caches. Useful for test teardown or resetting preview/demo state.

## Testing

Create a **separate** resolver for tests so production registrations are untouched:

```swift
let testResolver = DependencyResolver()
testResolver.register(UserRepositoryProtocol.self, scope: .application) { _ in
    MockUserRepository()
}

let sut = ProfileViewModel(repository: testResolver.resolve(UserRepositoryProtocol.self))
```

For code that uses `@Autowired` / `@AutowiredState` (bound to `shared`), reset in `setUp` / `tearDown`:

```swift
func setUp() {
    DependencyResolver.shared.initialize()
    DependencyResolver.shared.register(UserRepositoryProtocol.self, scope: .application) { _ in
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
| `register(_:scope:factory:)` | Register a type with a factory |
| `resolve(_:)` | Resolve a registered type |
| `initialize()` | Clear registrations and all caches |
| `@Autowired` | Lazy property injection from `shared` (macro) |
| `@AutowiredState` | SwiftUI state-owned injection from `shared` |
| `@DIObservable` | Observation macro compatible with `@Autowired` |

## Comparison with heavier DI frameworks

LightWeightDI intentionally stays minimal:

- No storyboard integration
- No auto-wiring / reflection
- No child containers, assembly types, or key-path factories
- Small API surface: register, resolve, three scopes, macros for injection

If you need feature-rich container hierarchies, consider [Swinject](https://github.com/Swinject/Swinject) or [Factory](https://github.com/hmlongco/Factory). LightWeightDI targets projects that want a few hundred lines of DI without pulling in a larger framework.

## Releases

### 0.7.0

- `@Autowired` and `@DIObservable` are now **Swift macros** (Xcode may ask to **Trust & Enable** the macro plugin on first add)
- Added `@AutowiredState` for SwiftUI (`DynamicProperty` + `@State`)
- Graph scope is isolated per owning root, so separate screens / navigation entries do not share `.graph` instances
- Core `DependencyResolver` APIs remain usable without enabling macros
- **Dropped CocoaPods support** — use Swift Package Manager only

### 0.6.0

- `DependencyResolver` with `register` / `resolve` / `initialize`
- `@Autowired` property-wrapper injection (lazy, first access)
- Three scopes: `.weak` (default), `.application`, `.graph`
- Nested resolution via `(DependencyResolver) -> Service` factories
- Thread-safe container state
- CocoaPods distribution (`LightWeightDI.podspec`)

## License

MIT — see [LICENSE](LICENSE).
