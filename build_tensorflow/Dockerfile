FROM debian:buster

RUN dpkg --add-architecture armhf && dpkg --add-architecture arm64 \
    && apt-get update && apt-get install -y \
        openjdk-11-jdk automake autoconf libpng-dev \
        curl zip unzip libtool swig zlib1g-dev pkg-config git wget xz-utils \
        python3-numpy python3-pip python3-mock \
        libpython3-dev libpython3-all-dev \
        libpython3-dev:armhf libpython3-all-dev:armhf \
        libpython3-dev:arm64 libpython3-all-dev:arm64 g++ gcc

RUN pip3 install -U --user keras_applications==1.0.8 --no-deps \
    && pip3 install -U --user keras_preprocessing==1.1.0 --no-deps \
    && pip3 install portpicker \
    && ldconfig

RUN /bin/bash -c "update-alternatives --install /usr/bin/python python /usr/bin/python3 150"

WORKDIR /root
RUN git clone https://github.com/lhelontra/tensorflow-on-arm/

WORKDIR /root/tensorflow-on-arm/build_tensorflow/
RUN git checkout v2.3.0
CMD ["/bin/bash"]
