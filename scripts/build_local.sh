#!/bin/bash
#
##############################################################################
# Example command to build Caffe2
##############################################################################
#

set -ex

# Needs to be at least 10.9 for c++11 support on macOS. This is needed for
# setuptools, which calls into distutils, whose default for this seems to be
# 10.6
if [ "$(uname)" == 'Darwin' ]; then
  MACOSX_DEPLOYMENT_TARGET=10.9
fi

CAFFE2_ROOT="$( cd "$(dirname "$0")"/.. ; pwd -P)"

CMAKE_ARGS=()

# Use ccache if available (this path is where Homebrew installs ccache symlinks)
if [ "$(uname)" == 'Darwin' ]; then
  CCACHE_WRAPPER_PATH=/usr/local/opt/ccache/libexec
  if [ -d "$CCACHE_WRAPPER_PATH" ]; then
    CMAKE_ARGS+=("-DCMAKE_C_COMPILER=$CCACHE_WRAPPER_PATH/gcc")
    CMAKE_ARGS+=("-DCMAKE_CXX_COMPILER=$CCACHE_WRAPPER_PATH/g++")
  fi
fi

# Use special install script with Anaconda
if [ -n "${USE_ANACONDA}" ]; then
  conda build "$CAFFE2_ROOT/conda"
else
  # Build protobuf compiler from third_party if configured to do so
  if [ -n "${USE_HOST_PROTOC:-}" ]; then
    echo "USE_HOST_PROTOC is set; building protoc before building Caffe2..."
    "$CAFFE2_ROOT/scripts/build_host_protoc.sh"
    CUSTOM_PROTOC_EXECUTABLE="$CAFFE2_ROOT/build_host_protoc/bin/protoc"
    echo "Built protoc $("$CUSTOM_PROTOC_EXECUTABLE" --version)"
    CMAKE_ARGS+=("-DCAFFE2_CUSTOM_PROTOC_EXECUTABLE=$CUSTOM_PROTOC_EXECUTABLE")
  fi

  # We are going to build the target into build.
  BUILD_ROOT=${BUILD_ROOT:-"$CAFFE2_ROOT/build"}
  mkdir -p "$BUILD_ROOT"
  cd "$BUILD_ROOT"
  echo "Building Caffe2 in: $BUILD_ROOT"

  cmake "$CAFFE2_ROOT" \
        "${CMAKE_ARGS[@]}" \
        "$@"

  # Determine the number of CPUs to build with.
  # If the `CAFFE_MAKE_NCPUS` variable is not specified, use them all.
  if [ -n "${CAFFE_MAKE_NCPUS}" ]; then
      CAFFE_MAKE_NCPUS="$CAFFE_MAKE_NCPUS"
  elif [ "$(uname)" == 'Darwin' ]; then
      CAFFE_MAKE_NCPUS="$(sysctl -n hw.ncpu)"
  else
      CAFFE_MAKE_NCPUS="$(nproc)"
  fi

  # Now, actually build the target.
  cmake --build . -- "-j$CAFFE_MAKE_NCPUS"
fi
