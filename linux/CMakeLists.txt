cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "gstplayer")
project(${PROJECT_NAME} LANGUAGES C CXX)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GST REQUIRED
  gstreamer-1.0
  gstreamer-app-1.0
  gstreamer-video-1.0
  gstreamer-pbutils-1.0
)
pkg_check_modules(GTK REQUIRED gtk+-3.0)

set(PLUGIN_NAME "gst_player_plugin")
set(NATIVE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../native")

add_library(${PLUGIN_NAME} SHARED
  "gst_player_plugin.cc"
  "gstplayer_texture.cc"
  "${NATIVE_ROOT}/src/runtime.c"
  "${NATIVE_ROOT}/src/bus.c"
  "${NATIVE_ROOT}/src/discoverer.c"
  "${NATIVE_ROOT}/src/frame.c"
  "${NATIVE_ROOT}/src/pipeline.c"
  "${NATIVE_ROOT}/src/thumbnail.c"
  "${NATIVE_ROOT}/src/http_source.c"
  "${NATIVE_ROOT}/src/http_user_agent.c"
  "${NATIVE_ROOT}/src/gstp_player.c"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET default
  C_VISIBILITY_PRESET default
)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL GSTP_BUILDING)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${NATIVE_ROOT}/include"
  "${NATIVE_ROOT}/src"
  ${GST_INCLUDE_DIRS}
)
target_link_directories(${PLUGIN_NAME} PRIVATE ${GST_LIBRARY_DIRS})
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${PLUGIN_NAME} PRIVATE ${GST_LIBRARIES})

set(gstplayer_bundled_libraries
  $<TARGET_FILE:${PLUGIN_NAME}>
  PARENT_SCOPE
)
