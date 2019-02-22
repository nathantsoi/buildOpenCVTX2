#!/bin/bash
apt-get update
apt-get install -y software-properties-common wget

wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
apt-add-repository "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-6.0 main"

apt-get update
apt-get install -y \
  ccache \
  libboost-all-dev \
  mesa-common-dev \
  libflann-dev \
  cmake \
  clang-6.0 \
  libeigen3-dev \
  libgtest-dev \
  git \
  curl \
  ruby \
  ruby-dev \
  rubygems \
  libffi-dev \
  build-essential \
  libqhull-dev \
  zlib1g-dev

update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-6.0 100
update-alternatives --install /usr/bin/clang clang /usr/bin/clang-6.0 100

chmod 777 build

rm -rf build
mkdir build
cd build || exit 1

export PATH=/usr/lib/ccache:$PATH

cmake .. \
    -DCMAKE_INSTALL_PREFIX=install \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DPCL_ENABLE_SSE=OFF \
    -DWITH_CUDA=OFF \
    -DWITH_DAVIDSDK=OFF \
    -DWITH_DOCS=OFF \
    -DWITH_DSSDK=OFF \
    -DWITH_ENSENSO=OFF \
    -DWITH_FZAPI=OFF \
    -DWITH_LIBUSB=ON \
    -DWITH_OPENGL=OFF \
    -DWITH_OPENNI=OFF \
    -DWITH_OPENNI2=OFF \
    -DWITH_PCAP=OFF \
    -DWITH_PNG=ON \
    -DWITH_QHULL=ON \
    -DWITH_QT=OFF \
    -DWITH_RSSDK=OFF \
    -DWITH_VTK=OFF


make -j8 install

make package

export DEBIAN_PACKAGE="PCL-1.8.1-Linux-${ARCH}.deb"

echo ${ARCH}

mv "PCL-1.8.1-Linux.deb" "${DEBIAN_PACKAGE}"

time curl \
	-H "X-JFrog-Art-Api: ${ARTIFACTORY_PASSWORD}" \
	-T "${DEBIAN_PACKAGE}" \
	"https://sixriver.jfrog.io/sixriver/debian/pool/main/p/pcl/${DEBIAN_PACKAGE};deb.distribution=${DISTRO};deb.component=main;deb.architecture=${ARCH}"

rm -rf build
