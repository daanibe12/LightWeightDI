# LightWeightDI 0.6.7

## Summary

Single release since **0.6.0** (the last published tag). It adds `@AutowiredObject` for SwiftUI, folds in graph isolation fixes that were prepared as 0.6.5 but never tagged, fixes type-key collisions and concurrent graph session leaks, and removes CocoaPods (SPM only).

## What's new

### `@AutowiredObject`

Inject an `ObservableObject` view model into a SwiftUI `View`.

```swift
final class ProfileViewModel: ObservableObject {
    @Published private(set) var users: [User] = []
    @Autowired var useCase: ProfileUseCase
}

struct ProfileView: View {
    @AutowiredObject var viewModel: ProfileViewModel

    var body: some View {
        List(viewModel.users) { Text($0.name) }
    }
}
```

`@Autowired` alone cannot be used on a `View`: a struct's property wrapper needs a `mutating` getter, which `body` cannot call. `@AutowiredObject` holds the instance in `@StateObject`, so the view owns it, resolves it once per view identity, and subscribes to `objectWillChange` so `@Published` changes redraw the body. `$viewModel` produces a `Binding`.

It works with `.weak` scope: because resolution happens once per view identity, a transient registration is enough. Use `.graph` for the dependencies the view model shares within its own tree.

To share one view model with child views, create it at the root and pass it down with `.environmentObject`; this is distribution, not injection.

For `@Observable` view models (iOS 17+), keep `@ObservationIgnored @Autowired` on dependencies and resolve the view model in the view with `init` + `@State` (see README).

## What's fixed (since 0.6.0)

### `.graph` scoped to each owner tree

In **0.6.0**, graph caches used the type name only. Two screens alive at once (for example `NavigationStack` without pop) could share the same UseCase / Repository.

**0.6.7** gives each class owner a stable graph identity and keys graph caches by **type + tree ID** (`GraphKey`). Within one owner, diamond dependencies still deduplicate; across owners, instances stay isolated.

| Scenario | 0.6.0 | 0.6.7 |
|----------|-------|-------|
| Same screen, diamond dependency | Shared (correct) | Shared (correct) |
| Two screens alive at once | Shared (bug) | Isolated per screen |
| Top-level consecutive `resolve` (no shared owner) | Separate | Separate |

### Type-name collisions

Registrations and caches were keyed by `String(describing: type)`. That string drops the module and the enclosing type, so two types named `Repository` in different modules produced the same key. The second registration overwrote the first and the forced cast trapped:

```
Could not cast value of type 'ModuleB.Repository' to 'ModuleA.Repository'
```

Keys are now `ObjectIdentifier(type)`.

### Graph sessions leaking across concurrent resolves

The graph session lived on the resolver as a shared `graphIDStack`. A session opened on one thread could be observed by another, so resolving from a background task joined the wrong tree and shared an instance with an unrelated screen. Measured against **0.6.0**:

| | 0.6.0 | 0.6.7 |
|---|---|---|
| Instances bound to the wrong tree (200 concurrent resolves) | 97 | 0 |
| Diamond sharing inside one tree (100 concurrent runs) | 19 | 100 |

Sessions are now passed down the call stack, and `@Autowired` binds its owner's tree through a thread-local context instead of mutating resolver state.

### Unbalanced `endGraphSession()`

Calling it without a matching `startGraphSession()` corrupted the session count and later trapped on `graphIDStack.last!`. Extra calls are now ignored.

## Who should upgrade

Anyone on **0.6.0** who uses `.graph` with multiple concurrent screens, presenters, or holders (especially navigation stacks), resolves from background tasks, or registers the same type name in more than one module.

## Upgrade notes

Source compatible. No public API was removed or renamed (except dropping the unpublished CocoaPods podspec).

Behaviour changes:

1. **Separate screens no longer share `.graph` instances by accident** (owner-scoped graph + concurrent isolation).
2. **Concurrent `.graph` resolution** no longer borrows another screen's tree unintentionally.
3. **`startGraphSession(id:)` and `@Autowired` now agree.** An open explicit session takes precedence over the owner's graph ID.

`@Autowired` still resolves from `DependencyResolver.shared`, and `initialize()` still does not clear values already cached on an instance.

### Breaking change: CocoaPods

`LightWeightDI.podspec` has been removed. CocoaPods users must migrate to Swift Package Manager or **pin the last CocoaPods release (0.6.0 tag)**.

## Platform support

| Platform | Version |
|----------|---------|
| iOS | 14.0+ |
| macOS | 13.0+ |
| tvOS | 16.0+ |
| Swift | 5.9+ |

`@AutowiredObject` is available wherever SwiftUI is. `@Observable` view models (iOS 17+) use `init` + `@State` in the view; see README.

## Install

Swift Package Manager only.

```swift
.package(url: "https://github.com/daanibe12/LightWeightDI.git", from: "0.6.7")
```