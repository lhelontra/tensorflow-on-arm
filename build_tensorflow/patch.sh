#!/bin/bash

PATCH_DIR="$(dirname ${BASH_SOURCE[0]})"

function bazel_patch()
{
  [ ! -d "${PATCH_DIR}/patch/bazel/${BAZEL_VERSION}" ] && return 0
  for f in $(find "${PATCH_DIR}/patch/bazel/${BAZEL_VERSION}" -type f | sort); do
    patch -p1 < "$f" || return 1
  done
  return 0
}

function tf_patch()
{
  [ ! -d "${PATCH_DIR}/patch/tensorflow/${TF_VERSION}" ] && return 0
  for f in $(find "${PATCH_DIR}/patch/tensorflow/${TF_VERSION}" -type f | sort); do
    git apply "$f" || return 1
  done
  return 0
}

function tf_toolchain_patch()
{
  local CROSSTOOL_NAME="$1"
  local CROSSTOOL_DIR="$2"
  local CROSSTOOL_EXTRA_INCLUDE="$3"
  [ -z "$CROSSTOOL_EXTRA_INCLUDE" ] && CROSSTOOL_EXTRA_INCLUDE="/usr/local/include/"
  local CROSSTOOL_VERSION=$($CROSSTOOL_DIR/bin/$CROSSTOOL_NAME-gcc -dumpversion)
  git apply << EOF
diff --git a/third_party/toolchains/cpus/arm/BUILD b/third_party/toolchains/cpus/arm/BUILD
index 5d388e918b..5e44b7e702 100644
--- a/third_party/toolchains/cpus/arm/BUILD
+++ b/third_party/toolchains/cpus/arm/BUILD
@@ -64,5 +64,5 @@ cc_toolchain(
     strip_files = "arm_linux_all_files",
     supports_param_files = 1,
     toolchain_config = ":armeabi_config",
-    toolchain_identifier = "arm-linux-gnueabihf",
+    toolchain_identifier = "$CROSSTOOL_NAME",
 )
diff --git a/arm_compiler.BUILD b/arm_compiler.BUILD
index cffe3fac70..dbde41825c 100644
--- a/arm_compiler.BUILD
+++ b/arm_compiler.BUILD
@@ -3,65 +3,65 @@ package(default_visibility = ["//visibility:public"])
 filegroup(
     name = "gcc",
     srcs = [
-        "bin/arm-rpi-linux-gnueabihf-gcc",
+        "bin/$CROSSTOOL_NAME-gcc",
     ],
 )

 filegroup(
     name = "ar",
     srcs = [
-        "bin/arm-rpi-linux-gnueabihf-ar",
+        "bin/$CROSSTOOL_NAME-ar",
     ],
 )

 filegroup(
     name = "ld",
     srcs = [
-        "bin/arm-rpi-linux-gnueabihf-ld",
+        "bin/$CROSSTOOL_NAME-ld",
     ],
 )

 filegroup(
     name = "nm",
     srcs = [
-        "bin/arm-rpi-linux-gnueabihf-nm",
+        "bin/$CROSSTOOL_NAME-nm",
     ],
 )

 filegroup(
     name = "objcopy",
     srcs = [
-        "bin/arm-rpi-linux-gnueabihf-objcopy",
+        "bin/$CROSSTOOL_NAME-objcopy",
     ],
 )

 filegroup(
     name = "objdump",
     srcs = [
-        "bin/arm-rpi-linux-gnueabihf-objdump",
+        "bin/$CROSSTOOL_NAME-objdump",
     ],
 )

 filegroup(
     name = "strip",
     srcs = [
-        "bin/arm-rpi-linux-gnueabihf-strip",
+        "bin/$CROSSTOOL_NAME-strip",
     ],
 )

 filegroup(
     name = "as",
     srcs = [
-        "bin/arm-rpi-linux-gnueabihf-as",
+        "bin/$CROSSTOOL_NAME-as",
     ],
 )

 filegroup(
     name = "compiler_pieces",
     srcs = glob([
-        "arm-linux-gnueabihf/**",
+        "$CROSSTOOL_NAME/**",
         "libexec/**",
-        "lib/gcc/arm-linux-gnueabihf/**",
+        "lib/gcc/$CROSSTOOL_NAME/**",
         "include/**",
     ]),
 )
diff --git a/third_party/toolchains/cpus/arm/cc_config.bzl.tpl b/third_party/toolchains/cpus/arm/cc_config.bzl.tpl
index bfe91e711b..da292cdcaf 100644
--- a/third_party/toolchains/cpus/arm/cc_config.bzl.tpl
+++ b/third_party/toolchains/cpus/arm/cc_config.bzl.tpl
@@ -17,7 +17,7 @@ load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

 def _impl(ctx):
     if (ctx.attr.cpu == "armeabi"):
-        toolchain_identifier = "arm-linux-gnueabihf"
+        toolchain_identifier = "$CROSSTOOL_NAME"
     elif (ctx.attr.cpu == "local"):
         toolchain_identifier = "local_linux"
     else:
@@ -269,7 +269,6 @@ def _impl(ctx):
                                 "-U_FORTIFY_SOURCE",
                                 "-D_FORTIFY_SOURCE=1",
                                 "-fstack-protector",
-                                "-DRASPBERRY_PI",
                             ],
                         ),
                     ],
@@ -331,13 +330,21 @@ def _impl(ctx):
                             flags = [
                                 "-std=c++11",
                                 "-isystem",
-			 	"%{ARM_COMPILER_PATH}%/lib/gcc/arm-rpi-linux-gnueabihf/6.5.0/include",
+                       "$CROSSTOOL_DIR/$CROSSTOOL_NAME/include/c++/$CROSSTOOL_VERSION/",
                                 "-isystem",
-                                "%{ARM_COMPILER_PATH}%/lib/gcc/arm-rpi-linux-gnueabihf/6.5.0/include-fixed",
+                                "$CROSSTOOL_DIR/$CROSSTOOL_NAME/sysroot/usr/include/",
                                 "-isystem",
-                                "%{ARM_COMPILER_PATH}%/arm-rpi-linux-gnueabihf/sysroot/usr/include/",
+                                "$CROSSTOOL_DIR/$CROSSTOOL_NAME/libc/usr/include/",
                                 "-isystem",
-		                "%{ARM_COMPILER_PATH}%/arm-rpi-linux-gnueabihf/include/c++/6.5.0/",
+		                "$CROSSTOOL_DIR/lib/gcc/$CROSSTOOL_NAME/$CROSSTOOL_VERSION/include",
+		                       "-isystem",
+                        "$CROSSTOOL_DIR/lib/gcc/$CROSSTOOL_NAME/$CROSSTOOL_VERSION/include-fixed",
+                               "-isystem",
+                        "/usr/include",
+                               "-isystem",
+                        "/usr/include/$CROSSTOOL_NAME",
+                               "-isystem",
+                        "$CROSSTOOL_EXTRA_INCLUDE",
                                 "-isystem",
                                 "%{PYTHON_INCLUDE_PATH}%",
                                 "-isystem",
@@ -559,12 +566,14 @@ def _impl(ctx):

     if (ctx.attr.cpu == "armeabi"):
         cxx_builtin_include_directories = [
-                "%{ARM_COMPILER_PATH}%/lib/gcc/arm-rpi-linux-gnueabihf/6.5.0/include",
-                "%{ARM_COMPILER_PATH}%/lib/gcc/arm-rpi-linux-gnueabihf/6.5.0/include-fixed",
-                "%{ARM_COMPILER_PATH}%/arm-rpi-linux-gnueabihf/sysroot/usr/include/",
-		"%{ARM_COMPILER_PATH}%/arm-rpi-linux-gnueabihf/include/c++/6.5.0/",
+                "$CROSSTOOL_DIR/$CROSSTOOL_NAME/include/c++/$CROSSTOOL_VERSION/",
+                "$CROSSTOOL_DIR/$CROSSTOOL_NAME/sysroot/usr/include/",
+                "$CROSSTOOL_DIR/$CROSSTOOL_NAME/libc/usr/include/",
+		"$CROSSTOOL_DIR/lib/gcc/$CROSSTOOL_NAME/$CROSSTOOL_VERSION/include",
+		"$CROSSTOOL_DIR/lib/gcc/$CROSSTOOL_NAME/$CROSSTOOL_VERSION/include-fixed",
                 "/usr/include",
-                "/tmp/openblas_install/include/",
+                "/usr/include/$CROSSTOOL_NAME",
+                "$CROSSTOOL_EXTRA_INCLUDE",
             ]
     elif (ctx.attr.cpu == "local"):
         cxx_builtin_include_directories = ["/usr/lib/gcc/", "/usr/local/include", "/usr/include"]
@@ -579,44 +588,44 @@ def _impl(ctx):
         tool_paths = [
             tool_path(
                 name = "ar",
-                path = "%{ARM_COMPILER_PATH}%/bin/arm-rpi-linux-gnueabihf-ar",
+                path = "$CROSSTOOL_DIR/bin/$CROSSTOOL_NAME-ar",
             ),
             tool_path(name = "compat-ld", path = "/bin/false"),
             tool_path(
                 name = "cpp",
-                path = "%{ARM_COMPILER_PATH}%/bin/arm-rpi-linux-gnueabihf-cpp",
+                path = "$CROSSTOOL_DIR/bin/$CROSSTOOL_NAME-cpp",
             ),
             tool_path(
                 name = "dwp",
-                path = "%{ARM_COMPILER_PATH}%/bin/arm-rpi-linux-gnueabihf-dwp",
+                path = "$CROSSTOOL_DIR/bin/$CROSSTOOL_NAME-dwp",
             ),
             tool_path(
                 name = "gcc",
-                path = "%{ARM_COMPILER_PATH}%/bin/arm-rpi-linux-gnueabihf-gcc",
+                path = "$CROSSTOOL_DIR/bin/$CROSSTOOL_NAME-gcc",
             ),
             tool_path(
                 name = "gcov",
-                path = "%{ARM_COMPILER_PATH}%/bin/arm-rpi-linux-gnueabihf-gcov",
+                path = "$CROSSTOOL_DIR/bin/$CROSSTOOL_NAME-gcov",
             ),
             tool_path(
                 name = "ld",
-                path = "%{ARM_COMPILER_PATH}%/bin/arm-rpi-linux-gnueabihf-ld",
+                path = "$CROSSTOOL_DIR/bin/$CROSSTOOL_NAME-ld",
             ),
             tool_path(
                 name = "nm",
-                path = "%{ARM_COMPILER_PATH}%/bin/arm-rpi-linux-gnueabihf-nm",
+                path = "$CROSSTOOL_DIR/bin/$CROSSTOOL_NAME-nm",
             ),
             tool_path(
                 name = "objcopy",
-                path = "%{ARM_COMPILER_PATH}%/bin/arm-rpi-linux-gnueabihf-objcopy",
+                path = "$CROSSTOOL_DIR/bin/$CROSSTOOL_NAME-objcopy",
             ),
             tool_path(
                 name = "objdump",
-                path = "%{ARM_COMPILER_PATH}%/bin/arm-rpi-linux-gnueabihf-objdump",
+                path = "$CROSSTOOL_DIR/bin/$CROSSTOOL_NAME-objdump",
             ),
             tool_path(
                 name = "strip",
-                path = "%{ARM_COMPILER_PATH}%/bin/arm-rpi-linux-gnueabihf-strip",
+                path = "$CROSSTOOL_DIR/bin/$CROSSTOOL_NAME-strip",
             ),
         ]
     elif (ctx.attr.cpu == "local"):
EOF
}
