source 'git@github.com:noke-inc/Specs.git'
source 'https://cdn.cocoapods.org/'

platform :ios, '12.0'

target 'PhoneKeySample' do
  use_frameworks! :linkage => :static
  pod 'PhoneKeyCore', '1.0.0'
  pod 'Sodium'
end

target 'PhoneKeyCoreTests' do
  # DO NOT include Sodium for tests
  # It is not compatible with static linking + arm64 exclusion
  use_frameworks! :linkage => :static
  
  pod 'PhoneKeyCore', '1.0.0'
end
