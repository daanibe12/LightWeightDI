# Add 0.6.8 scoped injection (additive only)

## Summary

LightWeightDI **0.6.8** adds optional **scoped dependency injection**. This release is **additive only**: unqualified `@Autowired` still resolves from `DependencyResolver.shared` (0.5 / 0.6.x compatible).

## What's new

### `DIResolverScope`

Protocol for feature/business containers with `static var shared: DependencyResolver`. Use `@Autowired(AbcDI.self)` to inject from that resolver's table.

### `DIRoots`

Neutral KeyPath root with built-in `app` (defaults to `DependencyResolver.shared`) and `DIRoots.current` for wiring. Apps add slots via `extension DIRoots { var abc: DependencyResolver { … } }` without package-specific business names.

### `@Autowired` (extended)

| Initializer | Resolves from |
| --- | --- |
| `init()` | `DependencyResolver.shared` (unchanged) |
| `init(_: Scope.Type)` where `Scope: DIResolverScope` | `Scope.shared` |
| `init(_: KeyPath<DIRoots, DependencyResolver>)` | `DIRoots.current[keyPath:]` (e.g. `\.app`, app-defined `\.abc`) |
| `init(resolver:)` | Explicit resolver (tests / manual wiring) |

Class owners still bind `.graph` to the owner tree; scoped wrappers resolve through the **stored resolver**.

### Docs

- `README.md` — 0.6.8 release section, SPM `from: "0.6.8"`, Business containers example (`abc`)
- `RELEASE_NOTES_0.6.8.md`

### `@AutowiredObject`

No behavior change — still `DependencyResolver.shared` only (documented).

## Out of scope (by design)

- No stored business slots in the package
- No required `extension Autowired` in apps
- No `DependencyValues`, nested KeyPaths, or cross-resolver graph
- No breaking changes

## Tests

New **`ScopedContainer068Tests`** (6 tests): unqualified → shared, `Scope.self`, `\.app`, two resolvers, `extension DIRoots` + `\.abc`, scope vs KeyPath on same table.

**`swift test`:** 81 tests, all passed.

## Migration

| Audience | Action |
| --- | --- |
| Existing users | Pin 0.6.8; no code change if using only `shared` + unqualified `@Autowired` |
| Scoped DI | Add `AbcDI`, `extension DIRoots`, register and inject on the **same resolver** per type |

`ScopeType` = lifetime within one table; `DIResolverScope` = which table.

## Files

- `Sources/LightWeightDI/DIScope.swift` (new)
- `Sources/LightWeightDI/DIRoots.swift` (new)
- `Sources/LightWeightDI/LightWeightDI.swift`
- `Sources/LightWeightDI/AutowiredObject.swift` (note)
- `Tests/LightWeightDITests/LightWeightDITests.swift`
- `README.md`, `RELEASE_NOTES_0.6.8.md`

## Test plan

- [x] `swift test` (81/81)
- [ ] Tag `0.6.8` after merge (release)