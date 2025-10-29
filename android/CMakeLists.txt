cmake_minimum_required(VERSION 3.4.1)

# Force 16KB page alignment for ARM 32/64-bit
if(CMAKE_ANDROID_ARCH_ABI MATCHES "armeabi-v7a|arm64-v8a")
    set(CMAKE_SHARED_LIBRARY_PAGE_SIZE 0x4000)
endif()

add_library(bbhelper SHARED c++/directBufferAndroid.cpp)

target_compile_options(bbhelper PRIVATE -DBUILD_FOR_ANDROID)
