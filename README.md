# Tensorflow-on-arm

Inspired by the [tensorflow-on-raspberry-pi](https://github.com/samjabrahams/tensorflow-on-raspberry-pi).
Tool for compile tensorflow for arm.

## Dependences
```shell
# NOTE: the libpng12-dev have in wheezy, jessie or sid distro.
apt-get install openjdk-8-jdk automake autoconf
apt-get install curl zip unzip libtool swig libpng12-dev zlib1g-dev pkg-config git g++ wget xz-utils

# For python2.7
apt-get install python-numpy python-dev python-pip python-mock

# if using a virtual environment, omit the --user argument
pip install -U --user keras_applications==1.0.5 --no-deps
pip install -U --user keras_preprocessing==1.0.3 --no-deps

# For python3
apt-get install python3-numpy python3-dev python3-pip python3-mock

# if using a virtual environment, omit the --user argument
pip3 install -U --user keras_applications==1.0.5 --no-deps
pip3 install -U --user keras_preprocessing==1.0.3 --no-deps
```

## TensorFlow on Raspberry Pi

### It's officially supported!

Python wheels for TensorFlow are being [officially supported](https://medium.com/tensorflow/tensorflow-1-9-officially-supports-the-raspberry-pi-b91669b0aa0). As well, this repository maintain up-to-date tensorflow wheels for raspberry pi.

### installation
[Check out the official TensorFlow website for more information.](https://www.tensorflow.org/install/install_raspbian)


## Cross-compilation
Make you sure added arm architecture, see how to adds in debian flavors:
```shell
dpkg --add-architecture armhf
echo "deb [arch=armhf] http://httpredir.debian.org/debian/ stretch main contrib non-free" >> /etc/apt/sources.list
```
if you want compile python support:
```shell
# For python2.7
apt-get install libpython-all-dev:armhf

# For python3
apt-get install libpython3-all-dev:armhf
```
using docker
```shell
cd build_tensorflow/
docker build -t tf-arm -f Dockerfile .
docker run -it -v /tmp/tensorflow_pkg/:/tmp/tensorflow_pkg/ --env TF_PYTHON_VERSION=3.5 tf-arm ./build_tensorflow.sh configs/<conf-name> # rpi.conf, rk3399.conf ...
```

## Edit tweaks like bazel resources, board model, and others
see configuration file examples in: build_tensorflow/configs/

## Finally, compile tensorflow.
```shell
cd build_tensorflow/
chmod +x build_tensorflow.sh
TF_PYTHON_VERSION=3.5 ./build_tensorflow.sh <path-of-config>
# If no output errors, the pip package will be in the directory: /tmp/tensorflow_pkg/
```
