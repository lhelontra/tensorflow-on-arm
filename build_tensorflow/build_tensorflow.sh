#!/bin/bash

source "build_tensorflow.conf"
TF_PYTHON_VERSION=${TF_PYTHON_VERSION:-"3.5"}
TF_VERSION=${TF_VERSION:-"v1.3.0-rc0"}
BAZEL_VERSION=${BAZEL_VERSION:-"0.5.2"}
WORKDIR=${WORKDIR:-$(pwd)}
BAZEL_COPT_FLAGS=""

function setCompilerFlag()
{
    if [ "$TF_BOARDMODEL_TARGET" == "rpi2" ]; then
        BAZEL_COPT_FLAGS="--copt=-funsafe-math-optimizations --copt=-mcpu=cortex-a7 --copt=-mfpu=neon-vfpv4 --copt=-ftree-vectorize --copt=-mfloat-abi=hard"

    elif [ "$TF_BOARDMODEL_TARGET" == "rpi3" ]; then
        BAZEL_COPT_FLAGS="--copt=-funsafe-math-optimizations --copt=-march=armv8-a+crc --copt=-mtune=cortex-a53 --copt=-mfpu=neon-fp-armv8 --copt=-mfloat-abi=hard"

    elif [ "$TF_BOARDMODEL_TARGET" == "beagle_black" ]; then
        BAZEL_COPT_FLAGS="--copt=-funsafe-math-optimizations --copt=-march=armv7-a --copt=-mtune=cortex-a8 --copt=-mfpu=neon --copt=-mfloat-abi=hard"

    elif [ "$TF_BOARDMODEL_TARGET" == "cubietruck_v5" ]; then
        BAZEL_COPT_FLAGS="--copt=-funsafe-math-optimizations --copt=-march=armv7-a --copt=-mtune=cortex-a7 --copt=-mfpu=neon-vfpv4 --copt=-mfloat-abi=hard"

    elif [ "$TF_BOARDMODEL_TARGET" == "banana_pipro" ]; then
        BAZEL_COPT_FLAGS="--copt=-funsafe-math-optimizations --copt=-march=armv7-a --copt=-mtune=cortex-a7 --copt=-mfpu=neon-vfpv4 --copt=-mfloat-abi=hard"

    elif [ "$TF_BOARDMODEL_TARGET" == "odroid_c1" ]; then
        BAZEL_COPT_FLAGS="--copt=-funsafe-math-optimizations --copt=-mcpu=cortex-a5 --copt=-mfpu=neon-vfpv4 --copt=-ftree-vectorize --copt=-mfloat-abi=hard"

    elif [ "$TF_BOARDMODEL_TARGET" == "odroid_c2" ]; then
        BAZEL_COPT_FLAGS="--copt=-funsafe-math-optimizations --copt=-march=armv8-a+crc --copt=-mtune=cortex-a53"
    fi
}

function bazel_patch()
{
patch -p1 << EOF
From ea6a30f5f4331feabd2a4f9d5ce8ed4eacc80ec0 Mon Sep 17 00:00:00 2001
From: Leonardo Lontra <lhe.lontra@gmail.com>
Date: Wed, 19 Jul 2017 03:12:17 +0000
Subject: [PATCH] fix build aarch64

fix aarch64 autocpuConverter
---
 scripts/bootstrap/buildenv.sh                                        | 2 +-
 .../google/devtools/build/lib/analysis/config/AutoCpuConverter.java  | 2 ++
 src/main/java/com/google/devtools/build/lib/util/CPU.java            | 3 ++-
 .../devtools/build/lib/rules/cpp/CrosstoolConfigurationHelper.java   | 2 ++
 third_party/BUILD                                                    | 5 +++++
 tools/cpp/cc_configure.bzl                                           | 4 +++-
 6 files changed, 15 insertions(+), 3 deletions(-)

diff --git a/scripts/bootstrap/buildenv.sh b/scripts/bootstrap/buildenv.sh
index 88d7e4fc4..e6c94021a 100755
--- a/scripts/bootstrap/buildenv.sh
+++ b/scripts/bootstrap/buildenv.sh
@@ -53,7 +53,7 @@ PLATFORM=\$(uname -s | tr 'A-Z' 'a-z')

 MACHINE_TYPE="\$(uname -m)"
 MACHINE_IS_64BIT='no'
-if [ "\${MACHINE_TYPE}" = 'amd64' -o "\${MACHINE_TYPE}" = 'x86_64' -o "\${MACHINE_TYPE}" = 's390x' ]; then
+if [ "\${MACHINE_TYPE}" = 'amd64' -o "\${MACHINE_TYPE}" = 'x86_64' -o "\${MACHINE_TYPE}" = 's390x' -o "\${MACHINE_TYPE}" = 'aarch64' ]; then
   MACHINE_IS_64BIT='yes'
 fi

diff --git a/src/main/java/com/google/devtools/build/lib/analysis/config/AutoCpuConverter.java b/src/main/java/com/google/devtools/build/lib/analysis/config/AutoCpuConverter.java
index d63ffdd63..d14934a87 100644
--- a/src/main/java/com/google/devtools/build/lib/analysis/config/AutoCpuConverter.java
+++ b/src/main/java/com/google/devtools/build/lib/analysis/config/AutoCpuConverter.java
@@ -57,6 +57,8 @@ public class AutoCpuConverter implements Converter<String> {
               return "arm";
             case S390X:
               return "s390x";
+   	    case AARCH64:
+              return "aarch64";
             default:
               return "unknown";
           }
diff --git a/src/main/java/com/google/devtools/build/lib/util/CPU.java b/src/main/java/com/google/devtools/build/lib/util/CPU.java
index e210eb5c4..a3f7308ad 100644
--- a/src/main/java/com/google/devtools/build/lib/util/CPU.java
+++ b/src/main/java/com/google/devtools/build/lib/util/CPU.java
@@ -24,7 +24,8 @@ public enum CPU {
   X86_32("x86_32", ImmutableSet.of("i386", "i486", "i586", "i686", "i786", "x86")),
   X86_64("x86_64", ImmutableSet.of("amd64", "x86_64", "x64")),
   PPC("ppc", ImmutableSet.of("ppc", "ppc64", "ppc64le")),
-  ARM("arm", ImmutableSet.of("aarch64", "arm", "armv7l")),
+  ARM("arm", ImmutableSet.of("arm", "armv7l")),
+  AARCH64("aarch64", ImmutableSet.of("aarch64")),
   S390X("s390x", ImmutableSet.of("s390x", "s390")),
   UNKNOWN("unknown", ImmutableSet.<String>of());

diff --git a/src/test/java/com/google/devtools/build/lib/rules/cpp/CrosstoolConfigurationHelper.java b/src/test/java/com/google/devtools/build/lib/rules/cpp/CrosstoolConfigurationHelper.java
index ada901e6e..be49c70d8 100644
--- a/src/test/java/com/google/devtools/build/lib/rules/cpp/CrosstoolConfigurationHelper.java
+++ b/src/test/java/com/google/devtools/build/lib/rules/cpp/CrosstoolConfigurationHelper.java
@@ -71,6 +71,8 @@ public class CrosstoolConfigurationHelper {
           return "arm";
         case S390X:
           return "s390x";
+        case AARCH64:
+          return "aarch64";
         default:
           return "unknown";
       }
diff --git a/third_party/BUILD b/third_party/BUILD
index 589e659ab..7d77a774f 100644
--- a/third_party/BUILD
+++ b/third_party/BUILD
@@ -617,6 +617,11 @@ config_setting(
 )

 config_setting(
+    name = "aarch64",
+    values = {"host_cpu": "aarch64"},
+)
+
+config_setting(
     name = "freebsd",
     values = {"host_cpu": "freebsd"},
 )
diff --git a/tools/cpp/cc_configure.bzl b/tools/cpp/cc_configure.bzl
index e23f01403..9cd7dcf0a 100644
--- a/tools/cpp/cc_configure.bzl
+++ b/tools/cpp/cc_configure.bzl
@@ -164,8 +164,10 @@ def _get_cpu_value(repository_ctx):
   result = repository_ctx.execute(["uname", "-m"])
   if result.stdout.strip() in ["power", "ppc64le", "ppc", "ppc64"]:
     return "ppc"
-  if result.stdout.strip() in ["arm", "armv7l", "aarch64"]:
+  if result.stdout.strip() in ["arm", "armv7l"]:
     return "arm"
+  if result.stdout.strip() in ["aarch64"]:
+    return "aarch64"
   return "k8" if result.stdout.strip() in ["amd64", "x86_64", "x64"] else "piii"


--
2.11.0

EOF
}

function tf_patch()
{
patch -p1 << EOF
From 2b10c812f147008cbf6fca7fa9ec1a2d9164589b Mon Sep 17 00:00:00 2001
From: Leonardo Lontra <lhe.lontra@gmail.com>
Date: Tue, 25 Jul 2017 01:08:45 +0000
Subject: [PATCH] change eigen version

---
 tensorflow/workspace.bzl | 8 ++++----
 1 file changed, 4 insertions(+), 4 deletions(-)

diff --git a/tensorflow/workspace.bzl b/tensorflow/workspace.bzl
index a5f044060..1c5b5b625 100644
--- a/tensorflow/workspace.bzl
+++ b/tensorflow/workspace.bzl
@@ -147,11 +147,11 @@ def tf_workspace(path_prefix="", tf_repo_name=""):
   native.new_http_archive(
       name = "eigen_archive",
       urls = [
-          "http://mirror.bazel.build/bitbucket.org/eigen/eigen/get/f3a22f35b044.tar.gz",
-          "https://bitbucket.org/eigen/eigen/get/f3a22f35b044.tar.gz",
+          "http://mirror.bazel.build/bitbucket.org/eigen/eigen/get/d781c1de9834.tar.gz",
+          "https://bitbucket.org/eigen/eigen/get/d781c1de9834.tar.gz",
       ],
-      sha256 = "ca7beac153d4059c02c8fc59816c82d54ea47fe58365e8aded4082ded0b820c4",
-      strip_prefix = "eigen-eigen-f3a22f35b044",
+      sha256 = "a34b208da6ec18fa8da963369e166e4a368612c14d956dd2f9d7072904675d9b",
+      strip_prefix = "eigen-eigen-d781c1de9834",
       build_file = str(Label("//third_party:eigen.BUILD")),
   )
 
-- 
2.11.0

EOF
}

function build_bazel()
{
  if [ ! -z "$(whereis bazel | awk '{ print $2 }')" ]; then
    echo "bazel already installed."
    return 0
  fi
  
  # Build bazel
  cd $WORKDIR

  if [ ! -f bazel-${BAZEL_VERSION}-dist.zip ]; then
    wget https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-dist.zip
  fi

  if [ ! -d bazel-${BAZEL_VERSION} ]; then
    mkdir bazel-${BAZEL_VERSION}
    unzip bazel-${BAZEL_VERSION}-dist.zip -d bazel-${BAZEL_VERSION}/
    cd bazel-${BAZEL_VERSION}/
    [ "$BAZEL_APPLY_SUPPORT_AARCH64_PATH" == "yes" ] && bazel_patch
  else
    cd bazel-${BAZEL_VERSION}/
  fi

  ./compile.sh || {
    echo "error when compile bazel"
    return 1
  }
  cp -a output/bazel /usr/local/bin/
  chmod +x /usr/local/bin/bazel
  return 0
}

function create_venv()
{
  WORKDIR=${WORKDIR}/python${TF_PYTHON_VERSION}-work
  if [ ! -d python${TF_PYTHON_VERSION}-work ]; then
    virtualenv -p python${TF_PYTHON_VERSION} --system-site-packages python${TF_PYTHON_VERSION}-work || return 1
  fi
  source ${WORKDIR}/bin/activate
  return 0
}

function download_tensorflow()
{
  cd $WORKDIR
  if [ ! -d tensorflow ]; then
    git clone --recurse-submodules https://github.com/tensorflow/tensorflow || return 1
    cd tensorflow
    git checkout tags/${TF_VERSION}
    [ "$TF_FIX_EIGEN_NEON_SUPPORT" == "yes" ] && tf_patch
  else
    cd tensorflow
  fi
  return 0
}

function configure_tensorflow()
{
  cd ${WORKDIR}/tensorflow
  # configure tensorflow
  export TF_NEED_GCP=0
  export TF_NEED_CUDA=0
  export TF_NEED_HDFS=0
  export TF_NEED_OPENCL=0
  export TF_NEED_VERBS=0
  export TF_NEED_MPI=0
  export TF_NEED_MKL=0
  export TF_NEED_JEMALLOC=1
  export CC_OPT_FLAGS="-march=native"
  export TF_ENABLE_XLA=0
  PYTHON_BIN_PATH=$(pwd)/../bin/python PYTHON_LIB_PATH=$(pwd)/../lib/python${TF_PYTHON_VERSION}/site-packages $TF_FLAGS ./configure || {
      echo "error when configure tensorflow"
      exit 1
  }
  return 0
}

function build_tensorflow()
{
  setCompilerFlag
  cd ${WORKDIR}/tensorflow
  bazel build --local_resources ${BAZEL_AVALIABLE_RAM},${BAZEL_AVALIABLE_CPU},${BAZEL_AVALIABLE_IO} -c opt ${BAZEL_COPT_FLAGS} --verbose_failures tensorflow/tools/pip_package:build_pip_package || return 1
  bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg || return 1
  echo "Done."
}

function main()
{
    create_venv || exit 1
    build_bazel || exit 1
    download_tensorflow || exit 1
    configure_tensorflow || exit 1
    build_tensorflow || exit 1
}

main
