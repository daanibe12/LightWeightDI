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

## Installation

```swift
.package(url: "https://github.com/daanibe12/LightWeightDI.git", from: "0.6.9")
```