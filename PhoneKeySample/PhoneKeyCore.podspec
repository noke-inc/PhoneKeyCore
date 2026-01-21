Pod::Spec.new do |s|
  s.name             = 'PhoneKeyCore'
  s.version          = '1.0.0'
  s.summary          = 'Ed25519 key generation, storage, and signing for iOS.'
  s.description      = <<-DESC
PhoneKeyCore is a lightweight framework that manages Ed25519 keypairs using
CryptoKit (iOS 13+) with support for legacy crypto providers for older devices.
  DESC

  s.homepage         = 'https://github.com/noke-inc/PhoneKeySigningPOC'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Noke Inc.' => 'support@noke.com' }

  # This will be replaced automatically by the release script
  s.source = {
    :http => 'https://github.com/noke-inc/PhoneKeySigningPOC/releases/download/1.0.0/PhoneKeyCore.xcframework.zip'
  }

  s.ios.deployment_target = '12.0'
  s.swift_versions = ['5.7', '5.8', '5.9', '5.10']

  # Binary SDK
  s.vendored_frameworks = 'PhoneKeyCore.xcframework'
  s.static_framework = true
end
