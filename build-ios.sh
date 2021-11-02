#!/bin/bash

set -e

export SCRIPT_DIR=$(dirname $(realpath $0))

export BOOST_VERSION=1.76.0
export THREADS="-j$(sysctl -n hw.ncpu)"

export BUILD_DIR="$PWD/build"
export BUILD_BOOST_DIR="$BUILD_DIR/boost"
export BUILD_THIRDPARTY_DIR="$BUILD_DIR/thirdparty"
export BUILD_LIBRIME_DIR="$BUILD_DIR/librime"
export BUILD_XCFW_PATH="$BUILD_DIR/Rime.xcframework"

export OUTPUT_DIR="$PWD/output"
export OUTPUT_BOOST_DIR="$PWD/output/boost"
export OUTPUT_THIRDPARTY_DIR="$PWD/output/thirdparty"
export OUTPUT_LIBRIME_DIR="$PWD/output/librime"

export LIB_NAME=Rime
export OUTPUT_XCFW_PATH="$PWD/output/$LIB_NAME.xcframework"

if [ -z "$1" ] || [ ! -d "$1" ]; then
    echo "Please specify path to librime."
    exit -1
fi
export RIME_ROOT=$(realpath $1)

export CMAKE_IOS_TOOLCHAIN_ROOT="$SCRIPT_DIR/ios-cmake"
if [ ! -d "$CMAKE_IOS_TOOLCHAIN_ROOT" ]; then
    echo "Please install CMake toolchain for iOS."
    exit -1
fi

build_boost() {
    if [ -f $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/macos/release/build/x86_64/libboost.a ] &&
       [ -f $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/macos-silicon/release/build/arm64/libboost.a ] &&
       [ -f $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/ios/release/build/iphoneos/arm64/libboost.a ] &&
       [ -f $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/ios/release/build/iphonesimulator/arm64/libboost.a ] &&
       [ -f $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/ios/release/build/iphonesimulator/x86_64/libboost.a ]; then
       echo "Boost is already built. Skipping."
       return
    fi

    echo "Building Boost..."
    export BOOST_LIBS="filesystem regex system"

    rm -rf $BUILD_BOOST_DIR || true
    mkdir -p $BUILD_BOOST_DIR
    
    pushd $BUILD_BOOST_DIR
    $SCRIPT_DIR/boost.sh --boost-libs "$BOOST_LIBS" -macos --macos-archs "x86_64" -macossilicon -ios --ios-archs "arm64" --no-framework
    popd
}

install_boost() {
    mkdir -p $OUTPUT_BOOST_DIR/macosx_x86_64
    ln -s $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/macos/release/prefix/include $OUTPUT_BOOST_DIR/macosx_x86_64/include || true
    ln -s $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/macos/release/build/x86_64 $OUTPUT_BOOST_DIR/macosx_x86_64/lib || true

    mkdir -p $OUTPUT_BOOST_DIR/macosx_arm64
    ln -s $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/macos-silicon/release/prefix/include $OUTPUT_BOOST_DIR/macosx_arm64/include || true
    ln -s $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/macos-silicon/release/build/arm64 $OUTPUT_BOOST_DIR/macosx_arm64/lib || true

    mkdir -p $OUTPUT_BOOST_DIR/iphoneos_arm64
    ln -s $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/ios/release/prefix/include $OUTPUT_BOOST_DIR/iphoneos_arm64/include || true
    ln -s $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/ios/release/build/iphoneos/arm64 $OUTPUT_BOOST_DIR/iphoneos_arm64/lib || true

    mkdir -p $OUTPUT_BOOST_DIR/iphonesimulator_x86_64
    ln -s $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/ios/release/prefix/include $OUTPUT_BOOST_DIR/iphonesimulator_x86_64/include || true
    ln -s $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/ios/release/build/iphonesimulator/x86_64 $OUTPUT_BOOST_DIR/iphonesimulator_x86_64/lib || true

    mkdir -p $OUTPUT_BOOST_DIR/iphonesimulator_arm64
    ln -s $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/ios/release/prefix/include $OUTPUT_BOOST_DIR/iphonesimulator_arm64/include || true
    ln -s $BUILD_BOOST_DIR/build/boost/$BOOST_VERSION/ios/release/build/iphonesimulator/arm64 $OUTPUT_BOOST_DIR/iphonesimulator_arm64/lib || true
}

build_thirdparty() {
    export PLAT=$1
    export ARCH=$2
    export PLAT_ARCH=${PLAT}_${ARCH}

    echo "Building third party libraries for $PLAT_ARCH"

    SDKROOT=$(xcrun --sdk $PLAT --show-sdk-path) \
	MACOSX_DEPLOYMENT_TARGET=10.12 \
	CMAKE_OSX_ARCHITECTURES=$ARCH \
    RIME_ROOT=$RIME_ROOT \
	BUILD_DIR=$BUILD_THIRDPARTY_DIR/$PLAT_ARCH \
	INSTALL_DIR="$OUTPUT_THIRDPARTY_DIR/$PLAT_ARCH" \
    make $THREADS -f ios-thirdparty.mk
}

build_librime() {
    PLAT=$1
    ARCH=$2
    PLAT_ARCH=${PLAT}_${ARCH}

    HOST_ARCH="macosx_$(uname -m)"
    HOST_THIRDPARTY_DIR="$OUTPUT_THIRDPARTY_DIR/$HOST_ARCH"
    if [ "$PLAT_ARCH" = "macosx_$HOST_ARCH" ]; then
        IS_HOST_ARCH=ON
    else
        IS_HOST_ARCH=OFF
    fi

    unset CFLAGS
    unset CXXFLAGS
    unset LDFLAGS

    ENABLE_BITCODE=0
    case "$PLAT_ARCH" in
        "macosx_x86_64")
            PLATFORM=MAC
            DEPLOYMENT_TARGET=10.12
            ;;
        "macosx_arm64")
            PLATFORM=MAC_ARM64
            DEPLOYMENT_TARGET=10.12
            ;;
        "iphonesimulator_x86_64")
            PLATFORM=SIMULATOR64
            DEPLOYMENT_TARGET=13.0
            ;;
        "iphonesimulator_arm64")
            PLATFORM=SIMULATORARM64
            DEPLOYMENT_TARGET=13.0
            ;;
        "iphoneos_arm64")
            PLATFORM=OS64
            DEPLOYMENT_TARGET=13.0
            ENABLE_BITCODE=1
            ;;
        *)
            echo "Unsupported PLAT_ARCH $PLAT_ARCH"
            exit -1
            ;;
    esac

    echo "Building librime for $PLAT_ARCH"

    PLAT_ARCH_BUILD_DIR=$BUILD_LIBRIME_DIR/$PLAT_ARCH

    echo "$OUTPUT_THIRDPARTY_DIR/$PLAT_ARCH/lib"
    if [ ! -d $PLAT_ARCH_BUILD_DIR/rime.xcodeproj ]; then
    SDKROOT=$(xcrun --sdk $PLAT --show-sdk-path) \
    cmake $RIME_ROOT -B$PLAT_ARCH_BUILD_DIR -GXcode \
        -DBUILD_STATIC=ON \
        -DBUILD_TEST=$IS_HOST_ARCH \
        -DBUILD_SAMPLE=$IS_HOST_ARCH \
        -DCMAKE_FRAMEWORK=ON \
        -DCMAKE_FIND_ROOT_PATH="$OUTPUT_THIRDPARTY_DIR/$PLAT_ARCH" \
        -DCMAKE_INSTALL_PREFIX="$OUTPUT_LIBRIME_DIR/$PLAT_ARCH" \
        -DCAPNP_EXECUTABLE="$HOST_THIRDPARTY_DIR/bin/capnp" \
        -DCAPNPC_CXX_EXECUTABLE="$HOST_THIRDPARTY_DIR/bin/capnpc-c++" \
        -DBoost_NO_BOOST_CMAKE=TRUE \
        -DBOOST_ROOT="$OUTPUT_BOOST_DIR/$PLAT_ARCH" \
        -DCMAKE_TOOLCHAIN_FILE=$CMAKE_IOS_TOOLCHAIN_ROOT/ios.toolchain.cmake \
        -DPLATFORM=$PLATFORM \
        -DDEPLOYMENT_TARGET=$DEPLOYMENT_TARGET \
        -DENABLE_BITCODE=$ENABLE_BITCODE \
        -DENABLE_VISIBILITY=1 \
        -DCMAKE_XCODE_ATTRIBUTE_APPLICATION_EXTENSION_API_ONLY=YES \
        -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
        -DCMAKE_XCODE_ATTRIBUTE_LD_DYLIB_INSTALL_NAME="@rpath/Rime.framework/Rime" \
        -T buildsystem=1
    else
        echo "Skip configure for $PLAT_ARCH."
    fi
    
    cmake --build $PLAT_ARCH_BUILD_DIR --config Release --target install $THREADS
}

build_xcframework() {
    echo "Building XCFramework..."
    rm -rf "$BUILD_XCFW_PATH" || true

    FW_MACOSX_DIR="$BUILD_XCFW_PATH/macosx/$LIB_NAME.framework"
    FW_IOSSIM_DIR="$BUILD_XCFW_PATH/iphonesimulator/$LIB_NAME.framework"
    FW_IOS_DIR="$BUILD_XCFW_PATH/iphoneos/$LIB_NAME.framework"

    mkdir -p "$FW_MACOSX_DIR"
    mkdir -p "$FW_IOSSIM_DIR"
    mkdir -p "$FW_IOS_DIR"

    FW_MACOSX_LIB="$FW_MACOSX_DIR/$LIB_NAME"
    FW_IOSSIM_LIB="$FW_IOSSIM_DIR/$LIB_NAME"
    FW_IOS_LIB="$FW_IOS_DIR/$LIB_NAME"

    cp -R src/ "$FW_MACOSX_DIR"
    cp -R src/ "$FW_IOSSIM_DIR"
    cp -R src/ "$FW_IOS_DIR"

    lipo -create $OUTPUT_LIBRIME_DIR/macosx_x86_64/lib/rime.framework/rime $OUTPUT_LIBRIME_DIR/macosx_arm64/lib/rime.framework/rime -output $FW_MACOSX_LIB
    lipo -create $OUTPUT_LIBRIME_DIR/iphonesimulator_x86_64/lib/rime.framework/rime $OUTPUT_LIBRIME_DIR/iphonesimulator_arm64/lib/rime.framework/rime -output $FW_IOSSIM_LIB
    lipo -create $OUTPUT_LIBRIME_DIR/iphoneos_arm64/lib/rime.framework/rime -output $FW_IOS_LIB

    install_name_tool -id "@rpath/$LIB_NAME.framework/$LIB_NAME" "$FW_MACOSX_LIB"
    install_name_tool -id "@rpath/$LIB_NAME.framework/$LIB_NAME" "$FW_IOSSIM_LIB"
    install_name_tool -id "@rpath/$LIB_NAME.framework/$LIB_NAME" "$FW_IOS_LIB"

    rm -rf $OUTPUT_XCFW_PATH || true
    xcodebuild -create-xcframework \
        -framework $FW_MACOSX_DIR \
        -framework $FW_IOSSIM_DIR \
        -framework $FW_IOS_DIR \
        -output "$OUTPUT_XCFW_PATH"

    if [ -d "$1" ]; then
        echo "Copying to $1"
        cp -a "$OUTPUT_XCFW_PATH" "$1"
    fi
}

mkdir -p "$OUTPUT_DIR"

if [ "$2" == "all" ]; then
    build_thirdparty "macosx" "x86_64"
    build_thirdparty "macosx" "arm64"

    build_thirdparty "iphonesimulator" "x86_64"
    build_thirdparty "iphonesimulator" "arm64"

    build_thirdparty "iphoneos" "arm64"

    build_boost
    install_boost
fi

build_librime "macosx" "x86_64"
build_librime "macosx" "arm64"

build_librime "iphonesimulator" "x86_64"
build_librime "iphonesimulator" "arm64"
 
build_librime "iphoneos" "arm64"

build_xcframework "${@: -1}"
