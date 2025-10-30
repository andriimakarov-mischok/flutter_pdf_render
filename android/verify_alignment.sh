#!/usr/bin/env bash
set -e

echo "================================================"
echo "🔍 Verifying 16KB Page Alignment"
echo "================================================"

# Check for readelf
if ! command -v readelf &> /dev/null; then
    echo "❌ readelf not found. Please install binutils"
    exit 1
fi

JNI_LIBS_DIR="src/main/jniLibs"
ARM_ABIS=("arm64-v8a" "armeabi-v7a")
ALL_PASS=true

echo ""

for ABI in "${ARM_ABIS[@]}"; do
    SO_FILE="$JNI_LIBS_DIR/$ABI/libbbhelper.so"

    if [ ! -f "$SO_FILE" ]; then
        echo "⚠️  $ABI: libbbhelper.so not found"
        ALL_PASS=false
        continue
    fi

    echo "Checking $ABI..."
    echo "----------------------------------------"

    # Get alignment values from LOAD segments
    ALIGNMENTS=$(readelf -l "$SO_FILE" | grep -A 1 "LOAD" | grep "Align" | awk '{print $NF}')

    FAIL_COUNT=0
    PASS_COUNT=0

    for ALIGN in $ALIGNMENTS; do
        # Convert hex to decimal
        ALIGN_DEC=$((ALIGN))
        REQUIRED=$((0x4000))  # 16KB = 16384 bytes

        if [ "$ALIGN_DEC" -ge "$REQUIRED" ]; then
            echo "  ✅ Alignment: $ALIGN ($ALIGN_DEC bytes) >= 16KB"
            ((PASS_COUNT++))
        else
            echo "  ❌ Alignment: $ALIGN ($ALIGN_DEC bytes) < 16KB"
            ((FAIL_COUNT++))
            ALL_PASS=false
        fi
    done

    if [ "$FAIL_COUNT" -eq 0 ]; then
        echo "  ✓ $ABI PASSED (all $PASS_COUNT segments aligned correctly)"
    else
        echo "  ✗ $ABI FAILED ($FAIL_COUNT segments not aligned correctly)"
    fi

    echo ""
done

# Also check x86_64 (should work with default alignment)
X86_64_FILE="$JNI_LIBS_DIR/x86_64/libbbhelper.so"
if [ -f "$X86_64_FILE" ]; then
    echo "Checking x86_64 (informational only)..."
    echo "----------------------------------------"
    readelf -l "$X86_64_FILE" | grep -A 1 "LOAD" | grep "Align" | awk '{print "  " $0}'
    echo ""
fi

echo "================================================"
if [ "$ALL_PASS" = true ]; then
    echo "✅ ALL ARM LIBRARIES PASS 16KB ALIGNMENT CHECK"
    echo "================================================"
    echo ""
    echo "🎉 Your libraries meet Google Play's requirements!"
    exit 0
else
    echo "❌ ALIGNMENT CHECK FAILED"
    echo "================================================"
    echo ""
    echo "⚠️  Some libraries do not meet the 16KB requirement."
    echo "    Please check your CMake configuration."
    exit 1
fi
