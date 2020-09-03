# Tensorflow-on-arm

Inspired by [tensorflow-on-raspberry-pi](https://github.com/samjabrahams/tensorflow-on-raspberry-pi).
Tool to compile tensorflow for ARM.

## Dependencies
```shell
apt-get install openjdk-8-jdk automake autoconf
apt-get install curl zip unzip libtool swig libpng-dev zlib1g-dev pkg-config git g++ wget xz-utils

# For python2.7
apt-get install python-numpy python-dev python-pip python-mock

# If using a virtual environment, omit the --user argument
pip install -U --user keras_applications==1.0.8 --no-deps
pip install -U --user keras_preprocessing==1.1.0 --no-deps

# For python3
apt-get install python3-numpy python3-dev python3-pip python3-mock

# If using a virtual environment, omit the --user argument
pip3 install -U --user keras_applications==1.0.8 --no-deps
pip3 install -U --user keras_preprocessing==1.1.0 --no-deps
```

## TensorFlow on Raspberry Pi

### It's officially supported!

Python wheels for TensorFlow are [officially supported](https://medium.com/tensorflow/tensorflow-1-9-officially-supports-the-raspberry-pi-b91669b0aa0). This repository also maintains up-to-date TensorFlow wheels for Raspberry Pi.

### Installation
[Check out the official TensorFlow website for more information.](https://www.tensorflow.org/install/install_raspbian)


## Cross-compilation
Make you sure add the ARM architecture to your package manager, see how to add it in Debian flavors:
```shell
dpkg --add-architecture armhf
echo "deb [arch=armhf] http://httpredir.debian.org/debian/ buster main contrib non-free" >> /etc/apt/sources.list
```
If you want compile Python support:
```shell
# For python2.7
apt-get install libpython-all-dev:armhf

# For python3
apt-get install libpython3-all-dev:armhf
```
### Using Docker

#### Python 3.7

```shell
cd build_tensorflow/
docker build -t tf-arm -f Dockerfile .
docker run -it -v /tmp/tensorflow_pkg/:/tmp/tensorflow_pkg/ --env TF_PYTHON_VERSION=3.7 tf-arm ./build_tensorflow.sh configs/<conf-name> # rpi.conf, rk3399.conf ...
```

#### Python 3.8

```shell
cd build_tensorflow/
docker build -t tf-arm -f Dockerfile.bullseye .
docker run -it -v /tmp/tensorflow_pkg/:/tmp/tensorflow_pkg/ --env TF_PYTHON_VERSION=3.8 tf-arm ./build_tensorflow.sh configs/<conf-name> # rpi.conf, rk3399.conf ...
```

## Edit tweaks like Bazel resources, board model, and others.
See configuration file examples in: build_tensorflow/configs/

## Finally, compile TensorFlow.
```shell
cd build_tensorflow/
chmod +x build_tensorflow.sh
TF_PYTHON_VERSION=3.5 ./build_tensorflow.sh <path-of-config> [noclean]
# The optional [noclean] argument omits 'bazel clean' before building for debugging purposes.
# If no output errors, the pip package will be in the directory: /tmp/tensorflow_pkg/
```
