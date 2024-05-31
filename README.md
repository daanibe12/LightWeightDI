
# LightWeightDI
![MacOS](https://img.shields.io/badge/MacOS-13+-green)
![ios](https://img.shields.io/badge/ios-16+-red)
![Cocoapods](https://img.shields.io/badge/Cocoapods-0.2.2-blue)
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

## About LightWeight DI
- LightWeightDI provides DI functionality for iOS and MacOS app development.
- This library internally references Swinject.
- 
## How to install

### How to install by Cocoapods (podfile)
- CocoaPods is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate Alamofire into your Xcode project using CocoaPods, specify it in your Podfile:
```
use_frameworks!
target 'cocoapodssample' do
pod 'LightWeightDI'
end


```

### How to install by Swift Package Manager(Xcode menu)
<img width="1056" alt="スクリーンショット 2024-05-24 3 55 26" src="https://github.com/daanibe12/LightWeightDI/assets/170229202/fd7934fe-4a1d-4f9c-bd4f-fbce51641509">


### How to install by Swift Package Manager(Package.swift)
- The Swift Package Manager is a tool for automating the distribution of Swift code and is integrated into the swift compiler.Once you have your Swift package set up, adding Alamofire as a dependency is as easy as adding it to the dependencies value of your Package.swift or the Package list in Xcode.

```
dependencies: [
    .package(url: "https://github.com/daanibe12/LightWeightDI.git", .upToNextMajor(from: "0.2.2"))
]
```

## Usage:
### How to regist implementation object into containar
```
// regist implementation object into containar (strong)
        DependencyResolver.shared.regist(AppScopeProtocol.self, scope: .container) { r in
            return AppScopeProtocolImpl()
        }

        //injected AppScopeProtocol implementation object
        @Autowired var appObj: AppScopeProtocol

// regist implementation object into containar  (default weak)
        DependencyResolver.shared.regist(ARepository.self) { r in
            return ARepositoryImpl()
        }


```

### Example of Dependent Injection
  
`@Autowired var repository: ARepository`

`@Autowired var appObj: AppScopeProtocol`


## iOS apps project using clean architecture MVVM

[SampleLightWeightDI5.zip](https://github.com/daanibe12/LightWeightDI/files/15502655/SampleLightWeightDI5.zip)
