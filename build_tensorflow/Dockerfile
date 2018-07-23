FROM debian:stretch

RUN apt-get update && apt-get install -y \
        openjdk-8-jdk automake autoconf \
        curl zip unzip libtool swig zlib1g-dev pkg-config git g++ wget xz-utils \
        python3-numpy python3-dev python3-pip python3-mock \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
    && echo "deb [arch=amd64] http://httpredir.debian.org/debian/ jessie main contrib non-free" > /etc/apt/sources.list.d/jessie.list \
    && apt-get update && apt-get install -y \
        libpng12-dev \
    && rm -f /etc/apt/sources.list.d/jessie.list \
    && dpkg --add-architecture armhf \
    && echo "deb [arch=armhf] http://httpredir.debian.org/debian/ stretch main contrib non-free" > /etc/apt/sources.list.d/armhf.list \
    && apt-get update && apt-get install -y \
        libpython3-all-dev:armhf \
    && rm -rf /var/lib/apt/lists/*

COPY . /root

WORKDIR /root
RUN mkdir -p sources userconfigs
VOLUME /root/userconfigs

# Pull TensorFlow source tree and checkout selected version tag
WORKDIR /root/sources
ENV TF_VERSION_TAG "v1.9.0"
ENV TF_GIT_REPOSITORY "https://github.com/tensorflow/tensorflow.git"
RUN git clone --quiet --depth=1 --branch ${TF_VERSION_TAG} \
        ${TF_GIT_REPOSITORY} tensorflow

WORKDIR /root
CMD ["/bin/bash"]
