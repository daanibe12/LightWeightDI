# LightWeightDI 0.6.9

## Summary

Removes **`DIRoots`** and KeyPath-based `@Autowired(\.app)` / `@Autowired(\.abc)` from 0.6.8.

Scoped injection stays available via **`DIResolverScope`** and **`@Autowired(HomeDI.self)`** only. Unqualified `@Autowired` is unchanged.

## Breaking (from 0.6.8 only)

If you adopted 0.6.8 KeyPath injection:

- Remove `DIRoots`, `extension DIRoots`, and `@Autowired(\.…)` on `DIRoots`
- Use `@Autowired(YourDI.self)` instead

If you only use `DependencyResolver.shared` and unlabeled `@Autowired`, **no code changes**.

## What remains

- `DIResolverScope`
- `@Autowired()` → `DependencyResolver.shared`
- `@Autowired(Scope.self)` → `Scope.shared`
- `init(resolver:)` for tests
- `@AutowiredObject` → `shared` only

## Behavior (0.6.9)

- **`DependencyResolver.initialize()`** waits until in-flight **`resolve`** calls finish before clearing registrations and caches. This reduces crashes when another thread calls `initialize()` while a factory or nested `resolve` is still running on the same container.
- Does **not** replace host-app test discipline: parallel XCTest classes that all call `initialize()` on **`DependencyResolver.shared`** can still race after clears complete. Prefer `DependencyResolver()` / `DIResolverScope`, avoid tearDown `restore` on `shared`, or isolate heavy DI tests in the test plan.

## Installation

```swift
.package(url: "https://github.com/daanibe12/LightWeightDI.git", from: "0.6.9")
```