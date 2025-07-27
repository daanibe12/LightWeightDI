Pod::Spec.new do |spec|
  spec.name          = "LightWeightDI"
  spec.version       = "0.3.1"
  spec.author        = { "ebina" => "ebina123jpjpjp@gmail.com" }
  spec.homepage      = "https://github.com/daanibe12/LightWeightDI"
  spec.license       = { :type => "MIT", :file => "LICENSE" }
  spec.summary       = "LightWeightDI provides DI functionality for iOS and MacOS app development."
  spec.description   = <<-DESC
   LightWeightDI provides DI functionality for iOS and MacOS app development.
  DESC

  spec.swift_version         = '5.0'
  spec.ios.deployment_target     = '16.0'
  spec.osx.deployment_target     = '13.0'
  
  spec.source        = { :git => "https://github.com/daanibe12/LightWeightDI.git", :tag => "#{spec.version}" }
  spec.source_files  = "Sources", "Sources/**/*.swift"
  spec.dependency "Swinject", "2.8.8"
end
