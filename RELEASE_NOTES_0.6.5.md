# LightWeightDI 0.6.5

## Summary

Bugfix for `.graph` scope isolation. Graph-scoped instances are now keyed by **owner identity**, so screens stacked on a navigation hierarchy no longer share UseCase / Repository instances while previous screens stay alive.

## What's fixed

In 0.6.0, `.graph` caches used the type name only. If two screens both held strong references (typical `NavigationStack` push without pop), they reused the same graph-scoped objects.

**0.6.5** assigns each class owner a graph identity and keys the cache as `TypeName#graphID`.

| Scenario | 0.6.0 | 0.6.5 |
|----------|-------|-------|
| Same screen, diamond dependency (Presenter → UseCase → Repo and Presenter → Repo) | Shared (correct) | Shared (correct) |
| Two screens alive at once, same registered types | Shared (bug) | Isolated per screen |
| Top-level consecutive `resolve` calls (no shared owner session) | Could reuse via type-only weak cache | Separate sessions / instances |

## Who should upgrade

Anyone using `.graph` with multiple concurrent screens, presenters, or holders — especially `NavigationStack` / similar retention of previous destinations.

## Install

**SPM**

```swift
.package(url: "https://github.com/daanibe12/LightWeightDI.git", from: "0.6.5")
```

**CocoaPods**

```ruby
pod 'LightWeightDI', '0.6.5'
```
