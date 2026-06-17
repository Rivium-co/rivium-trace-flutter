Pod::Spec.new do |s|
  s.name             = 'rivium_trace_flutter_sdk'
  s.version          = '2.0.0'
  s.summary          = 'RiviumTrace Flutter plugin with real native crash capture'
  s.description      = <<-DESC
RiviumTrace error tracking and APM SDK for Flutter. iOS native crashes
are captured via PLCrashReporter (vendored MIT). The plugin bridges
Dart to the native iOS RiviumTrace SDK using a MethodChannel.

Currently vendors the iOS SDK sources directly under Vendor/. When the
standalone RiviumTrace pod is published, this podspec will be changed
to depend on it instead and the Vendor/ directory removed.
  DESC

  s.homepage         = 'https://rivium.co/cloud/rivium-trace'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'RiviumTrace' => 'support@rivium.co' }
  s.source           = { :path => '.' }

  s.platform               = :ios, '12.0'
  s.ios.deployment_target  = '12.0'
  s.swift_version          = '5.5'
  s.static_framework       = true

  # Bridge + vendored RiviumTrace iOS SDK sources.
  s.source_files = [
    'Classes/**/*',
    'Vendor/RiviumTrace/**/*.swift'
  ]
  s.public_header_files = 'Classes/**/*.h'

  s.dependency 'Flutter'

  # Vendored PLCrashReporter (MIT). Async-signal-safe native crash capture.
  # See THIRD_PARTY_NOTICES.txt at the package root.
  s.vendored_frameworks = 'Vendor/CrashReporter.xcframework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
