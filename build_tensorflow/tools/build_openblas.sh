#!/bin/bash

# tool based of https://github.com/tensorflow/tensorflow/blob/master/tensorflow/tools/ci_build/pi/build_raspberry_pi.sh

CONFIG_PATH="$(realpath $1)"
TARGET=${TARGET:-ARMV6}

[ -f "$CONFIG_PATH" ] && {
  source "$CONFIG_PATH"
} || {
  echo -ne "Use: $0 <config>"
  exit 1
}

[ -z "$OPENBLAS_PATH" ] && {
    echo "invalid openblas installation path. Please insert variable OPENBLAS_PATH=<openblas_installed_dir> in your config file."
    exit 1
}

OPENBLAS_SRC_PATH="/tmp/openblas_src/"
DIR="$(realpath $(dirname $0))"
BUILD_TF_BIN="$DIR/../build_tensorflow.sh"
[ ! -f "$BUILD_TF_BIN" ] && {
    echo "not found $BUILD_TF_BIN script."
    exit 1
}

rm -rf ${OPENBLAS_SRC_PATH}

LINES=$($BUILD_TF_BIN "$CONFIG_PATH" prepare 2>&1 | tail -n3)
WORKDIR="$(echo "$LINES" | head -n1 | cut -d$'\t' -f2)"
BAZEL_BIN="$(echo "$LINES" | head -n2 | tail -n1 | cut -d$'\t' -f2)"
CROSSTOOL_DIR="$(echo "$LINES" | head -n3 | tail -n1 | cut -d$'\t' -f2)"
CROSSTOOL_CC=$CROSSTOOL_DIR/bin/$CROSSTOOL_NAME-gcc

git clone https://github.com/xianyi/OpenBLAS ${OPENBLAS_SRC_PATH}
cd ${OPENBLAS_SRC_PATH}
# The commit after this introduced Fortran compile issues. In theory they should
# be solvable using NOFORTRAN=1 on the make command, but my initial tries didn't
# work, so pinning to the last know good version.
git checkout 5a6a2bed9aff0ba8a18651d5514d029c8cae336a
# If this path is changed, you'll also need to update
# cxx_builtin_include_directory in third_party/toolchains/cpus/arm/CROSSTOOL.tpl
make CC=${CROSSTOOL_CC} FC=${CROSSTOOL_CC} HOSTCC=gcc TARGET=$TARGET
make PREFIX=${OPENBLAS_PATH} install
