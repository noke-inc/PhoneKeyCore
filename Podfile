# Uncomment the next line to define a global platform for your project
platform :ios, '12.0'

target 'PhoneKeySample' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks! :linkage => :static

  # Pods for PhoneKeySample
  pod 'Sodium'
end

target 'PhoneKeyCoreTests' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks! :linkage => :static

  # Pods for PhoneKeySample
  pod 'Sodium'
end


post_install do |installer|
  installer.pods_project.build_configurations.each do |config|
    # Force simulator builds to x86_64 (exclude arm64)
    config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
  end

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Same exclusion per-target (belt-and-suspenders)
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
    end
  end
end

