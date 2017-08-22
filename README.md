# Tensorflow-on-arm

Inspired by the [tensorflow-on-raspberry-pi](https://github.com/samjabrahams/tensorflow-on-raspberry-pi).
This script applies patch in bazel (for supports aarch64) and changes eigen version for compile with neon support.

## Dependences
```shell
apt-get install openjdk-8-jdk automake autoconf
apt-get install curl zip unzip libtool swig zlib1g-dev pkg-config git zip g++ unzip wget

# For python2.7
apt-get install python-numpy python-dev python-virtualenv
 
# For python3
apt-get install python3-numpy python3-dev python3-virtualenv
```
## Building from Source
```shell
cd build_tensorflow/

# Edit tweaks like bazel resources, board model, and others
vim build_tensorflow.conf

# Finally, compile tensorflow.
chmod +x build_tensorflow.sh
./build_tensorflow.sh

# If no output errors, the pip package will be in the directory: /tmp/tensorflow_pkg/ 
```
