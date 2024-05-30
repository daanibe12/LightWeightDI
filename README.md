
# LightWeightDI
![MacOS](https://img.shields.io/badge/MacOS-13+-green)
![ios](https://img.shields.io/badge/ios-16+-red)
![tvOS](https://img.shields.io/badge/tvOS-16+-yellow)
![Cocoapods](https://img.shields.io/badge/Cocoapods-0.1.7-blue)
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

## About LightWeight DI
- LightWeightDI provides DI functionality for iOS and MacOS app development.
- This library internally references Swinject.
- How to install
### How to install by Cocoapods (podfile)
```
use_frameworks!
target 'cocoapodssample' do
pod 'LightWeightDI'
end


```

### How to install by Swift Package Manager(Xcode menu)
<img width="1056" alt="スクリーンショット 2024-05-24 3 55 26" src="https://github.com/daanibe12/LightWeightDI/assets/170229202/f97c02da-bfe6-44e0-9be2-8c6ddd7e1ac4">



- Usage:
- How to regist implementation object into containar
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

- How to DependencyInject
  
`@Autowired var repository: ARepository`

`@Autowired var appObj: AppScopeProtocol`


- example iOS apps project using clean architecture MVVM

[SampleLightWeightDI5.zip](https://github.com/daanibe12/LightWeightDI/files/15502655/SampleLightWeightDI5.zip)
