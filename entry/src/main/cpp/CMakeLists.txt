# the minimum version of CMake.
cmake_minimum_required(VERSION 3.5.0)
project(Termony)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

include_directories(${NATIVERENDER_ROOT_PATH}
                              ${NATIVERENDER_ROOT_PATH}/include)

find_library(
    EGL-lib
    EGL
)

find_library(
    GLES-lib
    GLESv3
)

add_subdirectory(freetype)
add_subdirectory(utf8proc)

add_library(entry SHARED log.cpp napi_init.cpp terminal.cpp)
target_compile_features(entry PRIVATE cxx_std_17)
target_link_libraries(entry PUBLIC ${EGL-lib} ${GLES-lib} libace_napi.z.so libnative_window.so libhilog_ndk.z.so freetype utf8proc)
