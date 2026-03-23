Pod::Spec.new do |s|
  s.name             = 'PhoneKeyCore'
  s.version          = '1.0.1'
  s.summary          = 'Ed25519 and ECDSA P-256 key generation, storage, and signing for iOS and watchOS.'
  s.description      = <<-DESC
PhoneKeyCore is an iOS/watchOS SDK for cryptographic key management and signing.
It provides Ed25519 and ECDSA P-256 signing capabilities, ACL handling, command signing,
and secure keychain storage for mobile authentication systems.
  DESC

  s.homepage         = 'https://github.com/noke-inc/PhoneKeyCore'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Noke Inc.' => 'support@noke.com' }
  
  s.source           = {
    :git => 'https://github.com/noke-inc/PhoneKeyCore.git',
    :tag => s.version.to_s
  }

  s.ios.deployment_target = '12.0'
  s.watchos.deployment_target = '6.2'
  
  s.swift_versions = ['5.0', '5.1', '5.2', '5.3', '5.4', '5.5', '5.6', '5.7', '5.8', '5.9', '5.10']

  # Source files
  s.source_files = 'PhoneKeyCore/**/*.{swift,h,m}'
  s.public_header_files = 'PhoneKeyCore/**/*.h'
  
  # Resources
  s.resource_bundles = {
    'PhoneKeyCore' => ['PhoneKeyCore/**/*.docc']
  }

  # Module configuration
  s.module_name = 'PhoneKeyCore'
  s.requires_arc = true
  
  # Framework configuration
  s.frameworks = 'Foundation', 'Security'
  
  # Pod target xcconfig
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_VERSION' => '5.0'
  }
end
