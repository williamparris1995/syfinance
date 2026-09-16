cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# F24 自动更新:WinSparkle 以 exe「ProductVersion 字符串」为当前版本,与 appcast
# 版本(X.Y.Z,+N 构建号不进版本串,见 tool/gen_appcast.py)做 Sparkle 语义比较;
# FLUTTER_VERSION 原文含「+N」,其「+」会被比较器判为预发布串(1.0.4+5 < 1.0.4),
# 已装最新版仍恒提示可更新(死循环)。版本字符串一律用 X.Y.Z(仅 Runner.rc 的
# FileVersion/ProductVersion 用此宏),+N 只保留在数值 FILEVERSION 第 4 段。
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_XYZ=\"${FLUTTER_VERSION_MAJOR}.${FLUTTER_VERSION_MINOR}.${FLUTTER_VERSION_PATCH}\"")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# F24 自动更新:Runner.rc 内嵌 DSAPub(dsa_pub.pem);RC 编译规则不追踪其依赖,
# 换钥后增量构建会静默沿用旧公钥(review MEDIUM)——显式声明依赖强制重编。
set_property(SOURCE "Runner.rc" PROPERTY OBJECT_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/dsa_pub.pem")
