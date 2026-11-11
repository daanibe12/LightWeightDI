# LightWeightDI 0.6.7

## Summary

Adds `@AutowiredObject` for SwiftUI, and fixes two defects in the container: type-name collisions across modules, and graph sessions leaking between concurrent resolves. CocoaPods support is removed; the package is distributed through Swift Package Manager only.

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

## What's fixed

### Type-name collisions

Registrations and caches were keyed by `String(describing: type)`. That string drops the module and the enclosing type, so two types named `Repository` in different modules produced the same key. The second registration overwrote the first and the forced cast trapped:

```
Could not cast value of type 'ModuleB.Repository' to 'ModuleA.Repository'
```

Keys are now `ObjectIdentifier(type)`. Graph caches use a `GraphKey` struct (type + tree ID) instead of a `"typeName#graphID"` string.

### Graph sessions leaking across concurrent resolves

The graph session lived on the resolver as a shared `graphIDStack`. A session opened on one thread could be observed by another, so resolving from a background task joined the wrong tree and shared an instance with an unrelated screen. Measured against the previous build:

| | 0.6.5 | 0.6.7 |
|---|---|---|
| Instances bound to the wrong tree (200 concurrent resolves) | 97 | 0 |
| Diamond sharing inside one tree (100 concurrent runs) | 19 | 100 |

Sessions are now passed down the call stack, and `@Autowired` binds its owner's tree through a thread-local context instead of mutating resolver state.

### Unbalanced `endGraphSession()`

Calling it without a matching `startGraphSession()` corrupted the session count and later trapped on `graphIDStack.last!`. Extra calls are now ignored.

## Upgrade notes

Source compatible. No public API was removed or renamed.

Behaviour changes in two cases:

1. **Concurrent `.graph` resolution now isolates properly.** The old sharing was unintentional. Code that happened to rely on state being shared between screens will see separate instances.
2. **`startGraphSession(id:)` and `@Autowired` now agree.** Previously `@Autowired` ignored an explicit session and assigned its own ID. It now uses the open session. Projects that open a session in test `setUp` will see it take effect for the first time.

`@Autowired` still resolves from `DependencyResolver.shared`, and `initialize()` still does not clear values already cached on an instance.

### Breaking change: CocoaPods

`LightWeightDI.podspec` has been removed. CocoaPods users must migrate to Swift Package Manager or remain on 0.6.5.

## Platform support

| Platform | Version |
|----------|---------|
| iOS | 14.0+ |
| macOS | 13.0+ |
| tvOS | 16.0+ |
| Swift | 5.9+ |

`@AutowiredObject` is available wherever SwiftUI is. `@Observable` support (used with `@State` + `resolve`) requires iOS 17+ / macOS 14+ / tvOS 17+.

## Install

Swift Package Manager only.

```swift
.package(url: "https://github.com/daanibe12/LightWeightDI.git", from: "0.6.7")
```

CocoaPods support was removed in 0.6.7. The `LightWeightDI.podspec` is no longer published. Projects using CocoaPods should either migrate to Swift Package Manager or stay on 0.6.5.
