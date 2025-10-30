@echo off
setlocal enabledelayedexpansion

echo ================================================
echo Building Native Libraries with 16KB Alignment
echo ================================================

REM Detect Android SDK
if defined ANDROID_SDK_ROOT (
    set "ANDROID_SDK=%ANDROID_SDK_ROOT%"
) else if defined ANDROID_HOME (
    set "ANDROID_SDK=%ANDROID_HOME%"
) else (
    set "ANDROID_SDK=%LOCALAPPDATA%\Android\Sdk"
)

if not exist "%ANDROID_SDK%" (
    echo ERROR: Android SDK not found at: %ANDROID_SDK%
    echo Please set ANDROID_SDK_ROOT or ANDROID_HOME environment variable
    exit /b 1
)

echo Using SDK: %ANDROID_SDK%

REM Detect NDK
set "NDK_VERSION=27.3.13750724"
if defined ANDROID_NDK_HOME (
    set "NDK_DIR=%ANDROID_NDK_HOME%"
) else (
    set "NDK_DIR=%ANDROID_SDK%\ndk\%NDK_VERSION%"
)

if not exist "%NDK_DIR%" (
    echo ERROR: NDK not found at: %NDK_DIR%
    echo Installing NDK %NDK_VERSION%...
    call "%ANDROID_SDK%\cmdline-tools\latest\bin\sdkmanager.bat" "ndk;%NDK_VERSION%"
    if errorlevel 1 (
        echo ERROR: Failed to install NDK
        exit /b 1
    )
)

echo Using NDK: %NDK_DIR%

REM Check for CMake
where cmake >nul 2>&1
if errorlevel 1 (
    echo ERROR: CMake not found. Please install CMake 3.22.1 or higher
    exit /b 1
)

REM Check for Ninja
where ninja >nul 2>&1
if errorlevel 1 (
    echo ERROR: Ninja not found. Please install Ninja build system
    echo You can install it via: choco install ninja
    exit /b 1
)

REM Set paths
set "ROOT_DIR=%CD%"
set "BUILD_DIR=%ROOT_DIR%\build"
set "JNI_LIBS_DIR=%ROOT_DIR%\src\main\jniLibs"

REM Clean previous build
echo Cleaning previous build...
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
if exist "%JNI_LIBS_DIR%" rmdir /s /q "%JNI_LIBS_DIR%"
mkdir "%JNI_LIBS_DIR%"

REM ABIs to build
set "ABIS=arm64-v8a armeabi-v7a x86_64"

set "BUILD_SUCCESS=1"

REM Build each ABI
for %%A in (%ABIS%) do (
    echo.
    echo ======================================
    echo Building for ABI: %%A
    echo ======================================

    set "ABI_BUILD=%BUILD_DIR%\%%A"
    mkdir "!ABI_BUILD!"
    cd "!ABI_BUILD!"

    REM Configure with CMake
    cmake ..\..\  ^
        -DCMAKE_TOOLCHAIN_FILE="%NDK_DIR%\build\cmake\android.toolchain.cmake" ^
        -DANDROID_ABI=%%A ^
        -DANDROID_PLATFORM=android-21 ^
        -DCMAKE_BUILD_TYPE=Release ^
        -DANDROID_STL=c++_shared ^
        -G Ninja

    if errorlevel 1 (
        echo ERROR: CMake configuration failed for %%A
        set "BUILD_SUCCESS=0"
        cd "%ROOT_DIR%"
        goto :continue
    )

    REM Build
    ninja
    if errorlevel 1 (
        echo ERROR: Build failed for %%A
        set "BUILD_SUCCESS=0"
        cd "%ROOT_DIR%"
        goto :continue
    )

    REM Copy built .so to jniLibs
    if exist "libbbhelper.so" (
        mkdir "%JNI_LIBS_DIR%\%%A"
        copy /Y "libbbhelper.so" "%JNI_LIBS_DIR%\%%A\"
        echo Successfully built and copied libbbhelper.so for %%A
    ) else (
        echo ERROR: libbbhelper.so not found for %%A
        set "BUILD_SUCCESS=0"
    )

    cd "%ROOT_DIR%"
    :continue
)

echo.
if "%BUILD_SUCCESS%"=="1" (
    echo ================================================
    echo All builds completed successfully!
    echo ================================================
    echo.
    echo Built libraries:
    for %%A in (%ABIS%) do (
        if exist "%JNI_LIBS_DIR%\%%A\libbbhelper.so" (
            echo   ✓ %%A
        )
    )
    echo.
    echo To verify 16KB alignment, run: verify_alignment.bat
    exit /b 0
) else (
    echo.
    echo ERROR: Some builds failed. Check the output above for details.
    exit /b 1
)
