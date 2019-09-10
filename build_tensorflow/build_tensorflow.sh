#!/bin/bash

# build_tensorflow -*- shell-script -*-
#
# The MIT License (MIT)
#
# Copyright (c) 2017 Leonardo Lontra
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

[ -f "$1" ] && {
  source "$1"
} || {
  echo -ne "Use: $0 <config>\n\tFor prepare environment only, uses: $0 <config> prepare\n"
  exit 1
}

DIR="$(realpath $(dirname $0))"
source "${DIR}/patch.sh"

# builtin variables
RED='\033[0;31m'
BLUE='\033[1;36m'
NC='\033[0m'
TF_PYTHON_VERSION=${TF_PYTHON_VERSION:-"3"}
TF_VERSION=${TF_VERSION:-"v1.14.0"}
TF_BUILD_OUTPUT=${TF_BUILD_OUTPUT:-"/tmp/tensorflow_pkg"}
BAZEL_VERSION=${BAZEL_VERSION:-"0.24.1"}
CROSSTOOL_WHEEL_ARCH=${CROSSTOOL_WHEEL_ARCH:-"any"}
TF_GIT_URL=${TF_GIT_URL:-"https://github.com/tensorflow/tensorflow"}
WORKDIR=${WORKDIR:-"$DIR"}
BAZEL_BIN="$(command -v bazel)"

function log_failure_msg() {
	echo -ne "[${RED}ERROR${NC}] $@\n"
}

function log_app_msg() {
	echo -ne "[${BLUE}INFO${NC}] $@\n"
}

function create_workdir()
{
  WORKDIR=${WORKDIR}/sources/
  if [ ! -d $WORKDIR ]; then
    mkdir -p ${WORKDIR} || {
      log_failure_msg "error when creates workdir $WORKDIR"
      exit 1
    }
  fi
  return 0
}

function build_bazel()
{
  mkdir -p ${WORKDIR}/bin/

  # force compiling bazel if version is different or not found
  if [ -z "$BAZEL_BIN" ] || [ "$($BAZEL_BIN version | grep -i 'label' | awk '{ print $3 }' | tr -d '-')" != "${BAZEL_VERSION}" ]; then
      BAZEL_BIN="${WORKDIR}/bin/bazel-${BAZEL_VERSION}"
  fi

  PATH="${WORKDIR}/bin/:${PATH}"

  if [ -f "$BAZEL_BIN" ]; then
    log_app_msg "bazel already installed."
    # make sure using correct bazel version
    rm -f ${WORKDIR}/bin/bazel &>/dev/null
    ln -sf "${WORKDIR}/bin/bazel-${BAZEL_VERSION}" "${WORKDIR}/bin/bazel" &>/dev/null
    return 0
  fi

  cd $WORKDIR

  if [ ! -f bazel-${BAZEL_VERSION}-dist.zip ]; then
    wget --no-check-certificate https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-dist.zip
  fi

  if [ ! -d bazel-${BAZEL_VERSION} ]; then
    mkdir bazel-${BAZEL_VERSION}
    unzip bazel-${BAZEL_VERSION}-dist.zip -d bazel-${BAZEL_VERSION}/
    rm -f bazel-${BAZEL_VERSION}-dist.zip
    cd bazel-${BAZEL_VERSION}/
    if [ "$BAZEL_PATCH" == "yes" ]; then
      bazel_patch || {
        log_failure_msg "error when apply patch"
        exit 1
      }
    fi
  else
    cd bazel-${BAZEL_VERSION}/
  fi

  ./compile.sh
  if [ ! -f ./output/bazel ]; then
    log_failure_msg "error when compile bazel"
    exit 1
  fi

  chmod +x output/bazel
  mv output/bazel "${WORKDIR}/bin/bazel-${BAZEL_VERSION}"
  ln -sf "${WORKDIR}/bin/bazel-${BAZEL_VERSION}" "${WORKDIR}/bin/bazel" &>/dev/null

  return 0
}

function toolchain()
{
  [ "$CROSSTOOL_COMPILER" != "yes" ] && return 0

  CROSSTOOL_DIR="${WORKDIR}/toolchain/${CROSSTOOL_DIR}/"

  [ ! -d "${CROSSTOOL_DIR}/${CROSSTOOL_NAME}/bin/" ] && {
    mkdir -p ${WORKDIR}/toolchain/
    wget --no-check-certificate $CROSSTOOL_URL -O toolchain.tar.xz || {
      log_failure_msg "error when download crosstool"
      exit 1
    }
    tar xf toolchain.tar.xz -C ${WORKDIR}/toolchain/ || {
      log_failure_msg "error when extract crosstool"
      exit 1
    }
    rm toolchain.tar.xz &>/dev/null
  }

}

function download_tensorflow()
{
  cd ${WORKDIR}
  if [ ! -d tensorflow ]; then
    git clone --recurse-submodules ${TF_GIT_URL} || return 1
    cd tensorflow/
  else
    cd tensorflow/
    $BAZEL_BIN clean &>/dev/null

    # clean temp branch
    git reset --hard
    git clean -f -d
    git checkout master
    git branch -D __temp__
    git pull
  fi

  git checkout ${TF_VERSION} || {
    log_failure_msg "error when using tensorflow version ${TF_VERSION}"
    exit 1
  }

  # creates a temp branch for apply some patches and reuse cloned folder
  git checkout -b __temp__

  # sets git local config for apply patch
  git config user.email "temp@example.com"
  git config user.name "temp"

  if [ "$TF_PATCH" == "yes" ]; then
     tf_patch || {
       log_failure_msg "error when apply patch"
       exit 1
     }
  fi

  if [ ! -z "$CROSSTOOL_DIR" ] && [ ! -z "$CROSSTOOL_NAME" ]; then
    tf_toolchain_patch "$CROSSTOOL_NAME" "$CROSSTOOL_DIR" "$CROSSTOOL_EXTRA_INCLUDE" || {
      log_failure_msg "error when apply crosstool patch"
      exit 1
    }
  fi

  git add .
  git commit -m "temp modifications"

  return 0
}

function configure_tensorflow()
{
  # configure tensorflow
  cd ${WORKDIR}/tensorflow
  $BAZEL_BIN clean
  export PYTHON_BIN_PATH=$(command -v python${TF_PYTHON_VERSION})
  export ${TF_BUILD_VARS}

  # if need_cuda is enabled, search sdk
  if [ "$TF_NEED_CUDA" == "1" ]; then
     local nvcc_path=$(command -v nvcc)

     if [ ! -z "$nvcc_path" ]; then
         local cuda_location=$(echo $nvcc_path | sed 's/\/bin\/nvcc//')
         local cuda_version=$(cat "${cuda_location}/version.txt" | awk '{ print $3 }' | cut -d'.' -f-2)
         local cudnn_version=$(readlink $(find "${cuda_location}/" -iname '*libcudnn.so') | cut -d'.' -f3)

         export CUDA_TOOLKIT_PATH="$cuda_location"
         export TF_CUDA_VERSION=$cuda_version
         export TF_CUDNN_VERSION=$cudnn_version
     else
         export TF_NEED_CUDA=0
     fi
  fi

  yes '' | ./configure || {
      log_failure_msg "error when configure tensorflow"
      exit 1
  }
  return 0
}

function build_tensorflow()
{
  cd ${WORKDIR}/tensorflow

  if [ ! -z "$BAZEL_AVALIABLE_RAM" ] && [ ! -z "$BAZEL_AVALIABLE_CPU" ] && [ ! -z "$BAZEL_AVALIABLE_IO" ]; then
    BAZEL_LOCAL_RESOURCES="--local_resources ${BAZEL_AVALIABLE_RAM},${BAZEL_AVALIABLE_CPU},${BAZEL_AVALIABLE_IO}"
  fi

  [[ "${BAZEL_EXTRA_FLAGS}" == *"build_pip_package"* ]] && BAZEL_EXTRA_FLAGS+=" --python_path=python${TF_PYTHON_VERSION}"

  $BAZEL_BIN build ${BAZEL_LOCAL_RESOURCES} -c opt ${BAZEL_COPT_FLAGS} --verbose_failures ${BAZEL_EXTRA_FLAGS} || return 1

  # Build a wheel, if needs
  [[ "${BAZEL_EXTRA_FLAGS}" == *"build_pip_package"* ]] && {
    unset BDIST_OPTS
    # if crosscompile was activated, builds universal wheel
    if [ ! -z "$CROSSTOOL_DIR" ] && [ ! -z "$CROSSTOOL_NAME" ]; then
      export BDIST_OPTS="--universal"
    fi

    mkdir -p ${TF_BUILD_OUTPUT} || {
      log_failure_msg "error when creates output dir $TF_BUILD_OUTPUT"
      exit 1
    }

    # build a wheel.
    bazel-bin/tensorflow/tools/pip_package/build_pip_package $TF_BUILD_OUTPUT || return 1

    if [ ! -z "$BDIST_OPTS" ]; then
      local f="${TF_BUILD_OUTPUT}/$(ls -t $TF_BUILD_OUTPUT | grep -i '.whl' | head -n1)"
      local new_f="$(echo $f | sed -rn "s/tensorflow-([^-]+)-([^-]+)-.*/tensorflow-\1-\2-none-${CROSSTOOL_WHEEL_ARCH}.whl/p")"
      mv $f $new_f
      log_app_msg "wheel was renamed of $f for $new_f"
    fi
  }

  # Copy library files, if needs
  [[ "${BAZEL_EXTRA_FLAGS}" == *"libtensorflow"* ]] && {
    # collect the library files.
    cp bazel-bin/tensorflow/libtensorflow* $TF_BUILD_OUTPUT &>/dev/null
    cp bazel-bin/tensorflow/lite/libtensorflowlite* $TF_BUILD_OUTPUT &>/dev/null
    cp tensorflow/c/c_api.h $TF_BUILD_OUTPUT &>/dev/null
    log_app_msg "Library files moved to $TF_BUILD_OUTPUT"
  }

  log_app_msg "Done."
}


function prepare_env()
{
  # prepare environment for compiling
  create_workdir
  build_bazel
  toolchain
  download_tensorflow
  echo -ne "Workdir:            \t${WORKDIR}\n"
  echo -ne "Bazel binary:       \t${BAZEL_BIN}\n"
  [ ! -z "$CROSSTOOL_DIR" ] && echo -ne "Toolchain directory:\t${CROSSTOOL_DIR}\n"
}


function main()
{
    prepare_env
    configure_tensorflow
    build_tensorflow
}

[ "$2" == "prepare" ] && prepare_env || main
