# LightWeightDI 0.6.8

## Summary

**Additive release only.** Unqualified `@Autowired` still resolves from `DependencyResolver.shared` (0.5 / 0.6.x compatible).

Adds optional **scoped resolvers** via `DIResolverScope` and KeyPath slots on `DIRoots`.

## What's new

### `DIResolverScope`

Conforming types expose `static var shared: DependencyResolver`. Use `@Autowired(AbcDI.self)` for injection from that table.

### `DIRoots`

Neutral root for KeyPath injection:

- Built-in `app` → `DependencyResolver` (defaults to `DependencyResolver.shared`)
- Your app adds slots: `extension DIRoots { var abc: DependencyResolver { AbcDI.shared } }`
- Then `@Autowired(\.abc)` compiles **in the module that defines the extension** (no `extension Autowired` needed)

### `@Autowired` initializers

```swift
@Autowired var global: GlobalService              // DependencyResolver.shared

@Autowired(AbcDI.self) var useCase: SomeUseCase    // AbcDI.shared

@Autowired(\.app) var sameAsShared: GlobalService    // DIRoots.current.app (default: shared)

@Autowired(\.abc) var feature: SomeUseCase         // after extension DIRoots { var abc … }
```

`init(resolver:)` is available for tests.

### `ScopeType` vs `DIResolverScope`

- **`ScopeType`** (`.weak` / `.application` / `.graph`) — lifetime inside one registration table
- **`DIResolverScope`** — which `DependencyResolver` instance to use

### `@AutowiredObject`

Unchanged — `DependencyResolver.shared` only.

## Migration

Pin **0.6.8** when ready; no code changes until you add scoped registers and injection.

## Installation

```swift
.package(url: "https://github.com/daanibe12/LightWeightDI.git", from: "0.6.8")
```