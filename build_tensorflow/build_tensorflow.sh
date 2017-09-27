#!/bin/bash

# build_tensorflow -*- shell-script -*-
#
#Copyright (c) 2017 Leonardo Lontra
#All rights reserved.
#
#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions
#are met:
#1. Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#2. Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
#3. Neither the name of the author nor the names of other contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
#THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
#IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE
#LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
#BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
#OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
#EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[ -f "$1" ] && {
  source "$1"
} || {
  echo "Use: $0 <config>"
  exit 1
}

DIR="$(realpath $(dirname $0))"
source "${DIR}/patch.sh"

# builtin variables
RED='\033[0;31m'
BLUE='\033[1;36m'
NC='\033[0m'
TF_PYTHON_VERSION=${TF_PYTHON_VERSION:-"3.5"}
TF_VERSION=${TF_VERSION:-"v1.3.0"}
BAZEL_VERSION=${BAZEL_VERSION:-"0.5.2"}
WORKDIR=${WORKDIR:-"$DIR"}

function log_failure_msg() {
	echo -ne "[${RED}ERROR${NC}] $@\n"
}

function log_app_msg() {
	echo -ne "[${BLUE}INFO${NC}] $@\n"
}

function create_tempdir()
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
  if [ ! -z "$(whereis bazel | awk '{ print $2 }')" ]; then
    log_app_msg "bazel already installed."
    return 0
  fi

  # Build bazel
  cd $WORKDIR

  if [ ! -f bazel-${BAZEL_VERSION}-dist.zip ]; then
    wget --no-check-certificate https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-dist.zip
  fi

  if [ ! -d bazel-${BAZEL_VERSION} ]; then
    mkdir bazel-${BAZEL_VERSION}
    unzip bazel-${BAZEL_VERSION}-dist.zip -d bazel-${BAZEL_VERSION}/
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

  ./compile.sh || {
    log_failure_msg "error when compile bazel"
    exit 1
  }
  cp -a output/bazel /usr/local/bin/
  chmod +x /usr/local/bin/bazel
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
    git clone --recurse-submodules https://github.com/tensorflow/tensorflow || return 1
    cd tensorflow/
  else
    cd tensorflow/
    bazel clean &>/dev/null
    git checkout master
    git branch -D __temp__
  fi

  [ "${TF_VERSION}" != "master" ] && git checkout tags/${TF_VERSION}

  # creates a temp branch for apply some patches and reuse cloned folder
  git checkout -b __temp__

  if [ "$TF_PATCH" == "yes" ]; then
     tf_patch || {
       log_failure_msg "error when apply patch"
       exit 1
     }
  fi

  if [ ! -z "$CROSSTOOL_DIR" ] && [ ! -z "$CROSSTOOL_NAME" ]; then
    tf_toolchain_patch "$CROSSTOOL_NAME" "$CROSSTOOL_DIR" || {
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
  bazel clean
  export PYTHON_BIN_PATH=$(whereis python${TF_PYTHON_VERSION} | awk '{ print $2 }')
  export ${TF_BUILD_VARS}
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

  bazel build ${BAZEL_LOCAL_RESOURCES} -c opt ${BAZEL_COPT_FLAGS} --verbose_failures ${BAZEL_EXTRA_FLAGS} || return 1

  # Build a wheel, if needs
  [[ "${BAZEL_EXTRA_FLAGS}" == *"build_pip_package"* ]] && {
    unset BDIST_OPTS
    # if crosscompile was activated, builds universal wheel
    if [ ! -z "$CROSSTOOL_DIR" ] && [ ! -z "$CROSSTOOL_NAME" ]; then
      export BDIST_OPTS="--universal"
    fi

    local output="/tmp/tensorflow_pkg"

    # build a wheel.
    bazel-bin/tensorflow/tools/pip_package/build_pip_package $output || return 1

    if [ ! -z "$BDIST_OPTS" ]; then
      local f="${output}/$(ls $output | grep -i '.whl' | tail -n1)"
      local new_f="$(echo $f | sed -rn 's/tensorflow-([^-]+)-([^-]+)-.*/tensorflow-\1-\2-none-any.whl/p')"
      mv $f $new_f
      log_app_msg "wheel was renamed of $f for $new_f"
    fi

  }

  log_app_msg "Done."
}

function main()
{
    create_tempdir
    build_bazel
    toolchain
    download_tensorflow
    configure_tensorflow
    build_tensorflow
}

main
