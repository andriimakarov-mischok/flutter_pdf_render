cmake_minimum_required(VERSION 3.22.1)

project(bbhelper)

# --- Detect ABI and set 16 KB page alignment ---
if(CMAKE_ANDROID_ARCH_ABI MATCHES "armeabi-v7a|arm64-v8a|x86_64")
    message(STATUS ">> Enforcing 16KB page alignment for ${CMAKE_ANDROID_ARCH_ABI}")
    set(CMAKE_SHARED_LIBRARY_PAGE_SIZE 0x4000)
else()
    message(STATUS ">> Using default page alignment for ${CMAKE_ANDROID_ARCH_ABI}")
endif()

# --- Always build with position-independent code ---
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# --- Debug: write ABI info to a file (optional, remove later) ---
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/abi_info.txt"
        "ABI=${CMAKE_ANDROID_ARCH_ABI}\nPAGE_SIZE=${CMAKE_SHARED_LIBRARY_PAGE_SIZE}\n")

# --- Add native source ---
add_library(bbhelper SHARED c++/directBufferAndroid.cpp)
target_compile_options(bbhelper PRIVATE -DBUILD_FOR_ANDROID)

# Force 16KB page alignment for ARM 32/64-bit
if(CMAKE_ANDROID_ARCH_ABI MATCHES "armeabi-v7a|arm64-v8a")
    set(CMAKE_SHARED_LIBRARY_PAGE_SIZE 0x4000)
endif()
