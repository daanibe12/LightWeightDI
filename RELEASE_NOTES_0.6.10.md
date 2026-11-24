# LightWeightDI 0.6.10

## Summary

Ships **`feature/add_conduct_load`**: safer **`DependencyResolver.initialize()`** when resolves are in flight on the same container.

No API changes from **0.6.9**. Pin **0.6.10** instead of tracking the branch.

## Behavior

- **`initialize()`** calls **`waitUntilNoInflightResolves()`** before clearing registrations and caches.
- **`resolve`** paths are wrapped in **`trackInflightResolve`** so concurrent `initialize()` is less likely to tear down state mid-factory or mid-nested-`resolve`.

This does **not** remove the need for sound parallel test harnesses: many XCTest classes still sharing **`DependencyResolver.shared`** and all calling **`initialize()`** can race after clears finish. Prefer isolated **`DependencyResolver()`** / **`DIResolverScope`**, register once per process where possible, and avoid tearDown restore on **`shared`** (see README **Testing**).

## Installation

```swift
.package(url: "https://github.com/daanibe12/LightWeightDI.git", from: "0.6.10")
```

## Migrating from `feature/add_conduct_load` branch pin

In Xcode or **Package.swift**, replace:

```swift
// branch = feature/add_conduct_load
```

with:

```swift
.package(url: "https://github.com/daanibe12/LightWeightDI.git", from: "0.6.10")
```

Then **Reset Package Caches** / resolve packages so CI and local builds use the tag revision.