#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
target="${1:-linux}"
mkdir -p deps
if [ ! -d deps/godot-cpp/.git ]; then
  git clone --depth 1 --branch godot-4.4.1-stable https://github.com/godotengine/godot-cpp.git deps/godot-cpp
fi
if [ ! -d deps/llama.cpp/.git ]; then
  git clone --depth 1 --branch b5046 https://github.com/ggml-org/llama.cpp.git deps/llama.cpp
fi
git -C deps/godot-cpp rev-parse HEAD
git -C deps/llama.cpp rev-parse HEAD
args=(-DCMAKE_BUILD_TYPE=Release)
case "$target" in
  android)
    : "${ANDROID_NDK_HOME:?Set ANDROID_NDK_HOME}"
    args+=("-DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 -DANDROID_STL=c++_static -DGGML_CPU_ARM_ARCH=armv8-a)
    ;;
  linux) ;;
  *) echo "Unknown target: $target" >&2; exit 2 ;;
esac
cmake -S . -B "build-$target" -G Ninja "${args[@]}"
cmake --build "build-$target" --target cubyte_llama --parallel "${BUILD_JOBS:-2}"
mkdir -p "../game/native/$target"
cp "build-$target/out/libcubyte_llama.so" "../game/native/$target/"
cp cubyte_llama.gdextension ../game/native/
mkdir -p ../game/native/licenses
cp deps/godot-cpp/LICENSE.md ../game/native/licenses/godot-cpp.txt
cp deps/llama.cpp/LICENSE ../game/native/licenses/llama.cpp.txt
