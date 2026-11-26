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
# Pin and verify the official SQLite amalgamation before compiling it.
sqlite_archive="deps/sqlite-amalgamation-3530400.zip"
if [ ! -f "$sqlite_archive" ]; then
  curl --fail --location --retry 3 -o "$sqlite_archive.tmp" https://sqlite.org/2026/sqlite-amalgamation-3530400.zip
  mv "$sqlite_archive.tmp" "$sqlite_archive"
fi
python3 - "$sqlite_archive" <<'PY'
import hashlib, sys
with open(sys.argv[1], "rb") as f:
    assert hashlib.sha3_256(f.read()).hexdigest() == "628a44cfe82c66aed1ccbbe85a562d2e33ebe64b3288981ed76285612227934e", "SQLite archive checksum mismatch"
PY
unzip -oq "$sqlite_archive" -d deps
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
