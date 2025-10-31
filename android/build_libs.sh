#!/usr/bin/env bash
set -e

echo "================================================"
echo "🔧 Building Native Libraries with 16KB Alignment"
echo "================================================"

# Detect OS
OS=$(uname | tr '[:upper:]' '[:lower:]')
echo "📱 Detected OS: $OS"

# Android SDK detection with better defaults
if [ "$OS" = "darwin" ]; then
    # macOS
    DEFAULT_SDK="$HOME/Library/Android/sdk"
elif [ "$OS" = "linux" ]; then
    # Linux
    DEFAULT_SDK="$HOME/Android/Sdk"
else
    echo "❌ Unsupported OS: $OS"
    exit 1
fi

ANDROID_SDK=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$DEFAULT_SDK}}

# Ensure SDK exists
if [ ! -d "$ANDROID_SDK" ]; then
    echo "⚠️  Android SDK not found at: $ANDROID_SDK"
    echo "📥 Installing Android SDK..."

    mkdir -p "$ANDROID_SDK/cmdline-tools"
    cd /tmp

    if [ "$OS" = "linux" ]; then
        wget -q https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip -O cmdline-tools.zip
    elif [ "$OS" = "darwin" ]; then
        curl -s -o cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-mac-9477386_latest.zip
    fi

    unzip -q cmdline-tools.zip -d "$ANDROID_SDK/cmdline-tools"
    mv "$ANDROID_SDK/cmdline-tools/cmdline-tools" "$ANDROID_SDK/cmdline-tools/latest"
    rm cmdline-tools.zip

    echo "✅ SDK installed successfully"
fi

export ANDROID_SDK_ROOT="$ANDROID_SDK"
export ANDROID_HOME="$ANDROID_SDK"
export PATH="$ANDROID_SDK/cmdline-tools/latest/bin:$ANDROID_SDK/platform-tools:$PATH"

# Ensure NDK exists
NDK_VERSION="27.3.13750724"
NDK_DIR="${ANDROID_NDK_HOME:-$ANDROID_SDK/ndk/$NDK_VERSION}"

if [ ! -d "$NDK_DIR" ]; then
    echo "⚠️  NDK not found at: $NDK_DIR"
    echo "📥 Installing NDK $NDK_VERSION via sdkmanager..."

    yes | sdkmanager --sdk_root="$ANDROID_SDK" "ndk;$NDK_VERSION" || {
        echo "❌ Failed to install NDK"
        exit 1
    }

    echo "✅ NDK installed successfully"
fi

export ANDROID_NDK_HOME="$NDK_DIR"

echo "✅ Using SDK: $ANDROID_SDK"
echo "✅ Using NDK: $NDK_DIR"

# Check for required tools
if ! command -v cmake &> /dev/null; then
    echo "❌ CMake not found. Please install CMake 3.22.1 or higher"
    exit 1
fi

if ! command -v ninja &> /dev/null; then
    echo "⚠️  Ninja not found. Installing..."
    if [ "$OS" = "darwin" ]; then
        brew install ninja 2>/dev/null || {
            echo "❌ Please install Ninja: brew install ninja"
            exit 1
        }
    elif [ "$OS" = "linux" ]; then
        sudo apt-get update && sudo apt-get install -y ninja-build 2>/dev/null || {
            echo "❌ Please install Ninja: sudo apt-get install ninja-build"
            exit 1
        }
    fi
fi

# ABIs to build - aligned with build.gradle
ABIS=("arm64-v8a" "armeabi-v7a" "x86_64")

# Paths
ROOT_DIR=$(pwd)
BUILD_DIR="$ROOT_DIR/build"
JNI_LIBS_DIR="$ROOT_DIR/src/main/jniLibs"

# Clean previous build
echo "🧹 Cleaning previous build..."
rm -rf "$BUILD_DIR" "$JNI_LIBS_DIR"
mkdir -p "$JNI_LIBS_DIR"

# Build each ABI
BUILD_SUCCESS=true
for ABI in "${ABIS[@]}"; do
    echo ""
    echo "======================================"
    echo "🔨 Building for ABI: $ABI"
    echo "======================================"

    ABI_BUILD="$BUILD_DIR/$ABI"
    mkdir -p "$ABI_BUILD"
    cd "$ABI_BUILD"

    # Configure with CMake
    if ! cmake ../../ \
        -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI=$ABI \
        -DANDROID_PLATFORM=android-21 \
        -DCMAKE_BUILD_TYPE=Release \
        -DANDROID_STL=c++_shared \
        -G Ninja; then
        echo "❌ CMake configuration failed for $ABI"
        BUILD_SUCCESS=false
        continue
    fi

    # Build
    if ! ninja; then
        echo "❌ Build failed for $ABI"
        BUILD_SUCCESS=false
        continue
    fi

    # Copy built .so to jniLibs
    if [ -f "libbbhelper.so" ]; then
        mkdir -p "$JNI_LIBS_DIR/$ABI"
        cp libbbhelper.so "$JNI_LIBS_DIR/$ABI/"
        echo "✅ Successfully built and copied libbbhelper.so for $ABI"

        # CRITICAL: Also copy libc++_shared.so from NDK
        STL_LIB="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/$ABI/libc++_shared.so"
        if [ "$OS" = "darwin" ]; then
            STL_LIB="$NDK_DIR/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/$ABI/libc++_shared.so"
        fi

        if [ -f "$STL_LIB" ]; then
            cp "$STL_LIB" "$JNI_LIBS_DIR/$ABI/"
            echo "✅ Copied libc++_shared.so for $ABI"
        else
            echo "⚠️  Warning: libc++_shared.so not found at $STL_LIB"
            echo "   Trying alternative locations..."

            # Try alternative NDK structure
            for HOST in linux-x86_64 darwin-x86_64; do
                ALT_STL="$NDK_DIR/toolchains/llvm/prebuilt/$HOST/sysroot/usr/lib/$ABI/libc++_shared.so"
                if [ -f "$ALT_STL" ]; then
                    cp "$ALT_STL" "$JNI_LIBS_DIR/$ABI/"
                    echo "✅ Found and copied libc++_shared.so from $HOST"
                    break
                fi
            done
        fi
    else
        echo "❌ libbbhelper.so not found for $ABI"
        BUILD_SUCCESS=false
    fi
done

cd "$ROOT_DIR"

if [ "$BUILD_SUCCESS" = true ]; then
    echo ""
    echo "================================================"
    echo "🎉 All builds completed successfully!"
    echo "================================================"
    echo ""
    echo "📦 Built libraries:"
    for ABI in "${ABIS[@]}"; do
        if [ -f "$JNI_LIBS_DIR/$ABI/libbbhelper.so" ]; then
            SIZE=$(ls -lh "$JNI_LIBS_DIR/$ABI/libbbhelper.so" | awk '{print $5}')
            echo "  ✓ $ABI: $SIZE"
        fi
    done
    echo ""
    echo "💡 To verify 16KB alignment, run: ./verify_alignment.sh"
    exit 0
else
    echo ""
    echo "❌ Some builds failed. Check the output above for details."
    exit 1
fi
