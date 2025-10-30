@echo off
setlocal enabledelayedexpansion

echo ================================================
echo Verifying 16KB Page Alignment
echo ================================================

REM Detect Android NDK for readelf
if defined ANDROID_NDK_HOME (
    set "NDK_DIR=%ANDROID_NDK_HOME%"
) else if defined ANDROID_SDK_ROOT (
    set "NDK_DIR=%ANDROID_SDK_ROOT%\ndk\27.3.13750724"
) else if defined ANDROID_HOME (
    set "NDK_DIR=%ANDROID_HOME%\ndk\27.3.13750724"
) else (
    set "NDK_DIR=%LOCALAPPDATA%\Android\Sdk\ndk\27.3.13750724"
)

REM Find readelf in NDK
set "READELF="
for %%P in (
    "%NDK_DIR%\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-readelf.exe"
    "%NDK_DIR%\toolchains\llvm\prebuilt\windows\bin\llvm-readelf.exe"
) do (
    if exist %%P (
        set "READELF=%%~P"
        goto :found_readelf
    )
)

:found_readelf
if not defined READELF (
    echo ERROR: readelf not found in NDK
    echo Please ensure Android NDK is installed
    exit /b 1
)

echo Using: !READELF!
echo.

set "JNI_LIBS_DIR=src\main\jniLibs"
set "ALL_PASS=1"

REM Check ARM ABIs (these need 16KB alignment)
for %%A in (arm64-v8a armeabi-v7a) do (
    set "SO_FILE=%JNI_LIBS_DIR%\%%A\libbbhelper.so"

    if not exist "!SO_FILE!" (
        echo WARNING: %%A: libbbhelper.so not found
        set "ALL_PASS=0"
    ) else (
        echo Checking %%A...
        echo ----------------------------------------

        REM Run readelf and capture output
        "!READELF!" -l "!SO_FILE!" | findstr /C:"LOAD" /C:"Align" > temp_alignment.txt

        set "ABI_PASS=1"

        REM Parse alignment values (simplified check)
        for /f "tokens=*" %%L in (temp_alignment.txt) do (
            echo   %%L
            echo %%L | findstr /C:"0x4000" >nul
            if errorlevel 1 (
                echo %%L | findstr /C:"0x10000" >nul
                if errorlevel 1 (
                    REM Neither 0x4000 nor 0x10000 found
                    echo %%L | findstr /C:"Align" >nul
                    if not errorlevel 1 (
                        echo   WARNING: Alignment may be less than 16KB
                        set "ABI_PASS=0"
                    )
                )
            )
        )

        del temp_alignment.txt

        if "!ABI_PASS!"=="1" (
            echo   PASSED - Alignment appears correct
        ) else (
            echo   FAILED - Alignment may not meet 16KB requirement
            set "ALL_PASS=0"
        )

        echo.
    )
)

REM Also check x86_64 (informational)
set "X86_64_FILE=%JNI_LIBS_DIR%\x86_64\libbbhelper.so"
if exist "!X86_64_FILE!" (
    echo Checking x86_64 ^(informational only^)...
    echo ----------------------------------------
    "!READELF!" -l "!X86_64_FILE!" | findstr /C:"LOAD" /C:"Align"
    echo.
)

echo ================================================
if "%ALL_PASS%"=="1" (
    echo ALL ARM LIBRARIES APPEAR TO PASS
    echo ================================================
    echo.
    echo Your libraries likely meet Google Play requirements!
    echo For definitive verification, check alignment values manually.
    exit /b 0
) else (
    echo ALIGNMENT CHECK FAILED OR INCOMPLETE
    echo ================================================
    echo.
    echo WARNING: Some libraries may not meet requirements.
    echo Please verify alignment values manually.
    exit /b 1
)
