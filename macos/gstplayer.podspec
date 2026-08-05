#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint gstplayer.podspec` to validate before publishing.
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
  s.source_files     = 'gstplayer/Sources/gstplayer/**/*.{swift,c,m,h}'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.15'
  s.swift_version = '5.0'

  # --- GStreamer (macOS) -----------------------------------------------------
  # Official universal GStreamer.framework is auto-downloaded to the user cache
  # during pod install (ensure_gstreamer_macos.sh) and embedded into the .app
  # via vendored_frameworks + CocoaPods [CP] Embed Pods Frameworks.
  #
  # Set GSTPLAYER_ALLOW_HOMEBREW_GSTREAMER=1 for local Homebrew-only dev (not MAS).
  gst_ver = ENV.fetch('GST_VER', '1.28.5')
  cache_root = File.expand_path("~/Library/Caches/gstplayer/gstreamer/#{gst_ver}")
  use_homebrew = ENV['GSTPLAYER_ALLOW_HOMEBREW_GSTREAMER'] == '1'

  gst_sys_pkgs = %w[
    GLIB_2_0 GOBJECT_2_0 GIO_2_0
    GSTREAMER_1_0 GSTREAMER_BASE_1_0 GSTREAMER_APP_1_0 GSTREAMER_VIDEO_1_0
  ]

  if use_homebrew
    brew_prefix = `command -v brew >/dev/null 2>&1 && brew --prefix 2>/dev/null`.strip
    brew_prefix = '/opt/homebrew' if brew_prefix.empty?
    gst_pkg_config_path = ENV['GSTREAMER_PKG_CONFIG_PATH']
    gst_pkg_config_path = "#{brew_prefix}/lib/pkgconfig" if gst_pkg_config_path.nil? || gst_pkg_config_path.empty?
    gst_modules = 'gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0 gstreamer-base-1.0 gio-2.0 gobject-2.0 glib-2.0'
    gst_libs = `PKG_CONFIG_PATH="#{gst_pkg_config_path}" pkg-config --libs #{gst_modules} 2>/dev/null`.strip
    if gst_libs.empty?
      raise "Homebrew GStreamer not found (PKG_CONFIG_PATH=#{gst_pkg_config_path}). Install via brew or unset GSTPLAYER_ALLOW_HOMEBREW_GSTREAMER"
    end
    rust_build_script = 'export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"; ' \
      "export PKG_CONFIG_PATH=\"#{gst_pkg_config_path}:$PKG_CONFIG_PATH\"; " \
      'sh "$PODS_TARGET_SRCROOT/../native/scripts/build_pod.sh"'
    other_ldflags = '-force_load ${PODS_CONFIGURATION_BUILD_DIR}/gstplayer/libgstplayer.a ' + gst_libs
    framework_search_paths = nil
    Pod::UI.puts '[gstplayer] Using Homebrew GStreamer (debug only; not suitable for Mac App Store)'
  else
    ensure_script = File.join(__dir__, 'scripts', 'ensure_gstreamer_macos.sh')
    unless system({ 'GST_VER' => gst_ver }, 'sh', ensure_script)
      raise 'GStreamer ensure failed; check network connectivity or set GSTPLAYER_GSTREAMER_ROOT / GSTREAMER_FRAMEWORK_SRC'
    end

    framework_path = "#{cache_root}/GStreamer.framework"
    if File.file?("#{framework_path}/Headers/gst/gst.h")
      framework_root = cache_root
    elsif File.file?('/Library/Frameworks/GStreamer.framework/Headers/gst/gst.h')
      framework_root = '/Library/Frameworks'
      framework_path = '/Library/Frameworks/GStreamer.framework'
    else
      raise <<~MSG
        GStreamer.framework not found after ensure step.
        Expected cache at #{cache_root} or system install at /Library/Frameworks.
        Set GSTPLAYER_ALLOW_HOMEBREW_GSTREAMER=1 for Homebrew-only local dev.
      MSG
    end
    gst_headers = "#{framework_path}/Headers"

    Pod::UI.puts "[gstplayer] Using GStreamer.framework at #{framework_path}"

    link_script = File.join(__dir__, 'scripts', 'prepare_vendored_gstreamer.sh')
    unless system({ 'GST_VER' => gst_ver }, 'sh', link_script, '--link-vendored')
      raise 'GStreamer vendored link failed; see log above'
    end
    s.vendored_frameworks = 'Vendored/GStreamer.framework'

    gst_env = gst_sys_pkgs.map { |p|
      "export SYSTEM_DEPS_#{p}_NO_PKG_CONFIG=1; " \
      "export SYSTEM_DEPS_#{p}_SEARCH_FRAMEWORK=\"#{framework_root}\"; " \
      "export SYSTEM_DEPS_#{p}_LIB_FRAMEWORK=GStreamer; " \
      "export SYSTEM_DEPS_#{p}_INCLUDE=\"#{gst_headers}\"; "
    }.join
    rust_build_script = 'export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"; ' \
      'export GST_VER="' + gst_ver + '"; ' \
      'sh "$PODS_TARGET_SRCROOT/../native/scripts/build_pod.sh"'
    other_ldflags = '-force_load ${PODS_CONFIGURATION_BUILD_DIR}/gstplayer/libgstplayer.a ' \
      '-framework GStreamer -liconv -lresolv -lz -lbz2 ' \
      '-framework CoreFoundation -framework CoreMedia -framework CoreVideo ' \
      '-framework CoreAudio -framework AVFoundation -framework AVFAudio ' \
      '-framework AudioToolbox -framework VideoToolbox -framework Foundation -framework Security'
    framework_search_paths = framework_root
  end

  force_load = '-force_load ${PODS_CONFIGURATION_BUILD_DIR}/gstplayer/libgstplayer.a'

  s.script_phases = [
    {
      :name => 'Build C player library',
      :script => rust_build_script,
      :execution_position => :before_compile,
      :input_files => [
        '${PODS_TARGET_SRCROOT}/../native/include/gstp_player.h',
        '${PODS_TARGET_SRCROOT}/../native/src/pipeline.c',
        '${PODS_TARGET_SRCROOT}/../native/src/thumbnail.c',
        '${PODS_TARGET_SRCROOT}/../native/src/bus.c',
        '${PODS_TARGET_SRCROOT}/../native/src/gstp_player.c',
        '${PODS_TARGET_SRCROOT}/../native/src/gstp_ffi_keep.c',
      ],
      :output_files => ['${PODS_CONFIGURATION_BUILD_DIR}/gstplayer/libgstplayer.a'],
    },
  ]

  pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => other_ldflags,
  }
  if use_homebrew
    pod_target_xcconfig['EXCLUDED_ARCHS[sdk=macosx*]'] = 'x86_64'
  end
  if framework_search_paths
    pod_target_xcconfig['FRAMEWORK_SEARCH_PATHS'] = framework_search_paths
  end
  s.pod_target_xcconfig = pod_target_xcconfig

  # Runner link + keep global symbols for Dart DynamicLibrary.process() / dlsym.
  user_xcconfig = {
    'OTHER_LDFLAGS' => force_load,
    'STRIP_STYLE' => 'non-global',
  }
  if use_homebrew
    user_xcconfig['GSTPLAYER_ALLOW_HOMEBREW_GSTREAMER'] = '1'
  end
  s.user_target_xcconfig = user_xcconfig
end
