Pod::Spec.new do |s|
  s.name             = 'ABTastyQAssistant'
  s.version          = '0.3.0'
  s.summary          = 'In-app QA overlay for inspecting ABTasty feature flags and campaigns at runtime.'


  s.description      = <<-DESC
ABTastyQAssistant is an in-app QA toolkit for iOS applications integrated with ABTasty.
It provides a lightweight overlay panel that lets QA teams and developers inspect feature flags,
campaigns, and targeting conditions at runtime — without needing to rebuild or access backend tools.
Built on top of the Flagship SDK, it streamlines the testing and validation workflow directly on device.
                     DESC

  s.homepage         = 'https://github.com/flagship-io/abtasty-qa-assistant-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Adel' => 'adel@abtasty.com' }
  s.source           = { :git => 'https://github.com/flagship-io/abtasty-qa-assistant-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_version = '5.0'

  s.source_files = 'ABTastyQAssistant/{Controllers,Models,Services,Tools,Views}/**/*.{swift,h,m,mm}', 'ABTastyQAssistant/*.{swift,h,m,mm}'

  s.resource_bundles = {
    'ABTastyQAssistant' => [
      'ABTastyQAssistant/Assets/**/*',
      'ABTastyQAssistant/Assets/Fonts/*.ttf',
      'ABTastyQAssistant/Controllers/**/*.storyboard',
      'ABTastyQAssistant/Views/**/*.xib'
    ]
  }

  s.frameworks = 'UIKit'
  s.dependency 'FlagShip', '~> 5.0.0-beta'
end
