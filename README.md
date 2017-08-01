# tensorflow-on-arm

Inspired by the [tensorflow-on-raspberry-pi](https://raw.githubusercontent.com/samjabrahams/tensorflow-on-raspberry-pi).
This script applies patch in bazel (for supports aarch64) and changes eigen version for compile with neon support.

# dependences
```shell
apt-get install openjdk-8-jdk automake autoconf
apt-get install curl zip unzip libtool swig zlib1g-dev pkg-config zip g++ unzip wget

# For python2.7
apt-get install python-numpy python-dev
 
# For python3
apt-get install python3-numpy python3-dev
```
tested on odroid-c1, odroid-c2, raspberry pi 2/3. 
