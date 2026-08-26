#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'gstplayer'
  s.version          = '1.0.0'
  s.summary          = 'Polished all-in-one Flutter video player (GStreamer).'
  s.description      = <<-DESC
A polished, all-in-one Flutter video player with beautiful built-in controls and
broad format support for local and network video, powered by GStreamer
(native C core + Dart FFI) and Flutter Texture rendering.
                       DESC
  s.homepage         = 'https://github.com/wanwenfeng4798/GstPlayer'
  s.license          = { :file => '../LICENSE' }
  s.module_name      = 'gstplayer'

  s.source           = { :path => '.' }
  s.source_files = 'gstplayer/Sources/gstplayer/**/*.{swift,h,m,c}'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'

  gst_ver = ENV.fetch('GST_VER', '1.28.6')
  cache_ios = File.expand_path("~/Library/Caches/gstplayer/gstreamer/#{gst_ver}/ios/iPhone.sdk")

  gst_root = ENV['GSTREAMER_ROOT_IOS']
  if gst_root.nil? || gst_root.empty?
    ensure_script = File.join(__dir__, 'scripts', 'ensure_gstreamer_ios.sh')
    unless system({ 'GST_VER' => gst_ver }, 'sh', ensure_script)
      raise 'GStreamer iOS ensure failed; check network or set GSTREAMER_ROOT_IOS'
    end
    gst_root = cache_ios
  end

  unless File.file?("#{gst_root}/GStreamer.framework/Headers/gst/gst.h")
    raise <<~MSG
      GStreamer iOS SDK not found at #{gst_root}.
      Expected GStreamer.framework/Headers/gst/gst.h
      Set GSTREAMER_ROOT_IOS or allow ensure_gstreamer_ios.sh to download the cache.
    MSG
  end

  Pod::UI.puts "[gstplayer] Using GStreamer iOS SDK at #{gst_root}"

  gst_framework_parent = gst_root
  gst_headers = "#{gst_root}/GStreamer.framework/Headers"

  s.script_phase = {
    :name => 'Build C player library',
    :script => 'export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"; export GSTP_IOS=1; export GSTREAMER_FRAMEWORK_ROOT="' + gst_root + '"; export PLATFORM_NAME="${PLATFORM_NAME}"; sh "$PODS_TARGET_SRCROOT/../native/scripts/build_pod.sh"',
    :execution_position => :before_compile,
    :input_files => [
      '${PODS_TARGET_SRCROOT}/../native/include/gstp_player.h',
      '${PODS_TARGET_SRCROOT}/../native/src/pipeline.c',
      '${PODS_TARGET_SRCROOT}/../native/src/thumbnail.c',
      '${PODS_TARGET_SRCROOT}/../native/src/bus.c',
      '${PODS_TARGET_SRCROOT}/../native/src/gstp_player.c',
      '${PODS_TARGET_SRCROOT}/../native/src/gstp_ffi_keep.c',
    ],
    :output_files => ["${PODS_CONFIGURATION_BUILD_DIR}/gstplayer/libgstplayer.a"],
  }

  force_load = '-force_load ${PODS_CONFIGURATION_BUILD_DIR}/gstplayer/libgstplayer.a'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'ENABLE_BITCODE' => 'NO',
    'HEADER_SEARCH_PATHS' => '"' + gst_headers + '"',
    'FRAMEWORK_SEARCH_PATHS' => '"' + gst_framework_parent + '"',
    'OTHER_LDFLAGS' => force_load + ' -framework GStreamer -liconv -lresolv -lz -lbz2 -framework UIKit -framework QuartzCore -framework CoreGraphics -framework IOSurface -framework Metal -framework CoreFoundation -framework CoreMedia -framework CoreVideo -framework CoreAudio -framework AVFoundation -framework AVFAudio -framework AssetsLibrary -framework AudioToolbox -framework VideoToolbox -framework OpenGLES -framework Foundation -framework Security',
  }
  # Runner link + keep global symbols for Dart DynamicLibrary.process() / dlsym.
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => force_load,
    'STRIP_STYLE' => 'non-global',
  }
  s.vendored_frameworks = []
end
