cmake_minimum_required(VERSION 3.22.1)

project(bbhelper)

# --- Always build with position-independent code ---
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# --- Detect ABI and set 16 KB page alignment ---
if(CMAKE_ANDROID_ARCH_ABI MATCHES "armeabi-v7a|arm64-v8a|x86_64")
    message(STATUS ">> Enforcing 16KB page alignment for ${CMAKE_ANDROID_ARCH_ABI}")

    # Set page size for linker
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,max-page-size=0x4000")

    # Also set the CMake property (belt and suspenders approach)
    set(CMAKE_SHARED_LIBRARY_PAGE_SIZE 0x4000)
else()
    message(STATUS ">> Using default page alignment for ${CMAKE_ANDROID_ARCH_ABI}")
endif()

# --- Add native source ---
add_library(bbhelper SHARED c++/directBufferAndroid.cpp)
target_compile_options(bbhelper PRIVATE -DBUILD_FOR_ANDROID)

# --- Log build configuration ---
message(STATUS "================================")
message(STATUS "Build Configuration:")
message(STATUS "  ABI: ${CMAKE_ANDROID_ARCH_ABI}")
message(STATUS "  Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Page Size: ${CMAKE_SHARED_LIBRARY_PAGE_SIZE}")
message(STATUS "================================")
