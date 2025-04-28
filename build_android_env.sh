#!/bin/bash

# export ANDROID_NDK_ROOT="${ANDROID_NDK_HOME:-/home/runner/work/ZLMediaKit/ZLMediaKit/android-ndk}"
export ANDROID_NDK_ROOT="${ANDROID_NDK_HOME:-/dataset/datavol/sdk/android_ndk/android-ndk-r21e}"

HOST_TAG=linux-x86_64

MIN_SDK_VERSION=21

TOOLCHAIN=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$HOST_TAG

PATH=$TOOLCHAIN/bin:$PATH

BUILD_DIR=$PWD/build/