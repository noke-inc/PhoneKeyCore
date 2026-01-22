Pod::Spec.new do |s|
  s.name             = 'PhoneKeyCore'
  s.version          = '1.0.7'
  s.summary          = 'Ed25519 key generation, storage, and signing for iOS.'
  s.description      = <<-DESC
PhoneKeyCore is an internal iOS SDK for Ed25519 signing and key management.
  DESC

  # Private, internal Git repo
  s.homepage         = 'git@github.com:noke-inc/Specs.git'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Noke Inc.' => 'support@noke.com' }
  
  s.platforms = {
    :ios => '12.0',
    :watchos => '6.2'
  }

  # <— KEY PART —
  # The ZIP file lives inside the Specs repo itself.
  # CocoaPods clones the repo using SSH, finds the ZIP locally,
  # and extracts it without ever using curl/HTTPS.
  s.source           = {
    :git => 'git@github.com:noke-inc/Specs.git',
    :tag => s.version.to_s
  }

  s.ios.deployment_target = '12.0'
  s.swift_versions = ['5.9', '5.10']

  # This MUST match the name inside your ZIP
  s.vendored_frameworks = 'PhoneKeyCore.xcframework'

  # Because you are distributing a binary SDK
  #s.static_framework = true
end
