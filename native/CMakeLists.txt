cmake_minimum_required(VERSION 3.10)
project(gstplayer_native C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
add_compile_definitions(GSTP_BUILDING)

set(GSTP_SOURCES
  src/runtime.c
  src/bus.c
  src/frame.c
  src/pipeline.c
  src/thumbnail.c
  src/gstp_player.c
  src/gstp_ffi_keep.c
)

if(APPLE)
  list(APPEND GSTP_SOURCES src/apple_env.c)
endif()

add_library(gstplayer SHARED ${GSTP_SOURCES})
target_include_directories(gstplayer
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

if(ANDROID)
  find_library(log-lib log)
  find_library(android-lib android)
  # Expect GSTREAMER_ROOT_ANDROID and ABI-specific umbrella already built.
  if(NOT DEFINED GSTREAMER_ROOT_ANDROID)
    message(FATAL_ERROR "GSTREAMER_ROOT_ANDROID is required for Android builds")
  endif()
  target_compile_definitions(gstplayer PRIVATE __ANDROID__)
  target_include_directories(gstplayer PRIVATE
    ${GSTREAMER_ROOT_ANDROID}/include
    ${GSTREAMER_ROOT_ANDROID}/include/gstreamer-1.0
    ${GSTREAMER_ROOT_ANDROID}/include/glib-2.0
  )
  target_link_libraries(gstplayer PRIVATE
    ${log-lib}
    ${android-lib}
    gstreamer_android
  )
elseif(APPLE AND NOT IOS)
  # Prefer pkg-config (Homebrew) when available; else GStreamer.framework.
  find_package(PkgConfig)
  if(PkgConfig_FOUND)
    pkg_check_modules(GST gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0)
  endif()
  if(GST_FOUND)
    target_include_directories(gstplayer PRIVATE ${GST_INCLUDE_DIRS})
    target_link_directories(gstplayer PRIVATE ${GST_LIBRARY_DIRS})
    target_link_libraries(gstplayer PRIVATE ${GST_LIBRARIES})
  else()
    set(GST_FRAMEWORK_ROOT "$ENV{HOME}/Library/Caches/gstplayer/gstreamer/1.28.6")
    if(DEFINED ENV{GSTREAMER_FRAMEWORK_ROOT})
      set(GST_FRAMEWORK_ROOT "$ENV{GSTREAMER_FRAMEWORK_ROOT}")
    endif()
    target_include_directories(gstplayer PRIVATE
      ${GST_FRAMEWORK_ROOT}/GStreamer.framework/Headers
    )
    target_link_libraries(gstplayer PRIVATE
      "-F${GST_FRAMEWORK_ROOT}"
      "-framework GStreamer"
    )
  endif()
elseif(IOS)
  message(STATUS "iOS: link GStreamer.framework via podspec OTHER_LDFLAGS")
else()
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(GST REQUIRED gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0)
  target_include_directories(gstplayer PRIVATE ${GST_INCLUDE_DIRS})
  target_link_directories(gstplayer PRIVATE ${GST_LIBRARY_DIRS})
  target_link_libraries(gstplayer PRIVATE ${GST_LIBRARIES})
endif()

install(TARGETS gstplayer
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION bin
)
install(FILES include/gstp_player.h DESTINATION include)
