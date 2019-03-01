#!/bin/bash
# License: MIT. See license file in root directory
# Copyright(c) JetsonHacks (2017-2018)

OPENCV_VERSION=3.4.5
# Jetson TX2
ARCH_BIN=6.2
INSTALL_DIR=/usr/local
# Download the opencv_extras repository
# If you are installing the opencv testdata, ie
#  OPENCV_TEST_DATA_PATH=../opencv_extra/testdata
# Make sure that you set this to YES
# Value should be YES or NO
DOWNLOAD_OPENCV_EXTRAS=YES
# Source code directory
OPENCV_SOURCE_DIR=$HOME
WHEREAMI=$PWD

CLEANUP=true

function usage
{
    echo "usage: ./buildAndPackage.sh [[-s sourcedir ] | [-h]]"
    echo "-s | --sourcedir   Directory in which to place the opencv sources (default $HOME)"
    echo "-i | --installdir  Directory in which to install opencv libraries (default /usr/local)"
    echo "-h | --help  This message"
}

# Iterate through command line inputs
while [ "$1" != "" ]; do
    case $1 in
        -s | --sourcedir )      shift
				OPENCV_SOURCE_DIR=$1
                                ;;
        -i | --installdir )     shift
                                INSTALL_DIR=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

CMAKE_INSTALL_PREFIX=$INSTALL_DIR

source scripts/jetson_variables.sh

# Print out the current configuration
echo "Build configuration: "
echo " NVIDIA Jetson $JETSON_BOARD"
echo " Operating System: $JETSON_L4T_STRING [Jetpack $JETSON_JETPACK]"
echo " Current OpenCV Installation: $JETSON_OPENCV"
echo " OpenCV binaries will be installed in: $CMAKE_INSTALL_PREFIX"
echo " OpenCV Source will be installed in: $OPENCV_SOURCE_DIR"

if [ $DOWNLOAD_OPENCV_EXTRAS == "YES" ] ; then
 echo "Also installing opencv_extras"
fi

# Repository setup
apt-add-repository universe
apt-get update

# Download dependencies for the desired configuration
cd $WHEREAMI
apt-get install -y \
    cmake \
    ccache \
    git \
    curl \
    pkg-config

# https://devtalk.nvidia.com/default/topic/1007290/jetson-tx2/building-opencv-with-opengl-support-/post/5141945/#5141945
#cd /usr/local/cuda/include
#patch -N cuda_gl_interop.h $WHEREAMI'/patches/OpenGLHeader.patch' 
# Clean up the OpenGL tegra libs that usually get crushed
#cd /usr/lib/aarch64-linux-gnu/
#ln -sf tegra/libGL.so libGL.so

# Python 2.7
apt-get install -y python-dev python-numpy python-py python-pytest
# Python 3.5
apt-get install -y python3-dev python3-numpy python3-py python3-pytest

# GStreamer support
#apt-get install -y libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev 

cd $OPENCV_SOURCE_DIR
git clone https://github.com/opencv/opencv.git
cd opencv
git checkout -b v${OPENCV_VERSION} ${OPENCV_VERSION}

if [ $DOWNLOAD_OPENCV_EXTRAS == "YES" ] ; then
 echo "Installing opencv_extras"
 # This is for the test data
 cd $OPENCV_SOURCE_DIR
 git clone https://github.com/opencv/opencv_extra.git
 cd opencv_extra
 git checkout -b v${OPENCV_VERSION} ${OPENCV_VERSION}
fi

cd $OPENCV_SOURCE_DIR/opencv
mkdir build
cd build

export PATH=/usr/lib/ccache:${PATH}

time cmake \
    -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DBUILD_PNG=OFF \
    -DBUILD_TIFF=OFF \
    -DBUILD_TBB=OFF \
    -DBUILD_JPEG=OFF \
    -DBUILD_JASPER=OFF \
    -DBUILD_ZLIB=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_opencv_java=OFF \
    -DBUILD_opencv_python2=ON \
    -DBUILD_opencv_python3=OFF \
    -DENABLE_PRECOMPILED_HEADERS=OFF \
    -DWITH_OPENCL=OFF \
    -DWITH_OPENMP=ON \
    -DWITH_FFMPEG=OFF \
    -DWITH_GSTREAMER=OFF \
    -DWITH_GSTREAMER_0_10=OFF \
    -DWITH_CUDA=OFF \
    -DENABLE_FAST_MATH=ON \
    -DCUDA_FAST_MATH=ON \
    -DWITH_LIBV4L=OFF \
    -DWITH_GTK=OFF \
    -DWITH_VTK=OFF \
    -DWITH_TBB=OFF \
    -DWITH_1394=OFF \
    -DWITH_OPENEXR=OFF \
    -DCUDA_ARCH_BIN=${ARCH_BIN} \
    -DCUDA_ARCH_PTX="" \
    -DWITH_QT=OFF \
    -DWITH_OPENGL=OFF \
    -DCPACK_BINARY_DEB=ON \
    -DINSTALL_C_EXAMPLES=OFF \
    -DINSTALL_TESTS=OFF \
    -DOPENCV_TEST_DATA_PATH=../opencv_extra/testdata \
    ../

    #-DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda-8.0 \

if [ $? -eq 0 ] ; then
  echo "CMake configuration make successful"
else
  # Try to make again
  echo "CMake issues " >&2
  echo "Please check the configuration being used"
  exit 1
fi

# Consider $ nvpmodel -m 2 or $ nvpmodel -m 0
NUM_CPU=$(nproc)
time make -j$(($NUM_CPU - 1))
if [ $? -eq 0 ] ; then
  echo "OpenCV make successful"
else
  # Try to make again; Sometimes there are issues with the build
  # because of lack of resources or concurrency issues
  echo "Make did not build " >&2
  echo "Retrying ... "
  # Single thread this time
  make
  if [ $? -eq 0 ] ; then
    echo "OpenCV make successful"
  else
    # Try to make again
    echo "Make did not successfully build" >&2
    echo "Please fix issues and retry build"
    exit 1
  fi
fi

echo "Installing ... "
make install
if [ $? -eq 0 ] ; then
   echo "OpenCV installed in: $CMAKE_INSTALL_PREFIX"
else
   echo "There was an issue with the final installation"
   exit 1
fi

# check installation
IMPORT_CHECK="$(python -c "import cv2 ; print cv2.__version__")"
if [[ $IMPORT_CHECK != *$OPENCV_VERSION* ]]; then
  echo "There was an error loading OpenCV in the Python sanity test."
  echo "The loaded version does not match the version built here."
  echo "Please check the installation."
  echo "The first check should be the PYTHONPATH environment variable."
fi

echo "Starting Packaging"
ldconfig  
NUM_CPU=$(nproc)
time make package -j$(($NUM_CPU - 1))
if [ $? -eq 0 ] ; then
  echo "OpenCV make package successful"
else
  # Try to make again; Sometimes there are issues with the build
  # because of lack of resources or concurrency issues
  echo "Make package did not build " >&2
  echo "Retrying ... "
  # Single thread this time
  make package
  if [ $? -eq 0 ] ; then
    echo "OpenCV make package successful"
  else
    # Try to make again
    echo "Make package did not successfully build" >&2
    echo "Please fix issues and retry build"
    exit 1
  fi
fi


# check installation
#IMPORT_CHECK="$(python -c "import cv2 ; print(cv2.__version__)")"
#if [[ $IMPORT_CHECK != *$OPENCV_VERSION* ]]; then
#  echo "There was an error loading OpenCV in the Python sanity test."
#  echo "The loaded version does not match the version built here."
#  echo "Please check the installation."
#  echo "The first check should be the PYTHONPATH environment variable."
#fi

pushd ${OPENCV_SOURCE_DIR}/opencv/build

export DEBIAN_PACKAGE_DEV="OpenCV-3.4.5-${OPENCV_ARCH}-dev.deb"
export DEBIAN_PACKAGE_LIBS="OpenCV-3.4.5-${OPENCV_ARCH}-libs.deb"
export DEBIAN_PACKAGE_PYTHON="OpenCV-3.4.5-${OPENCV_ARCH}-python.deb"
export DEBIAN_PACKAGE_LICENSES="OpenCV-3.4.5-${OPENCV_ARCH}-licenses.deb"
export DEBIAN_PACKAGE_SCRIPTS="OpenCV-3.4.5-${OPENCV_ARCH}-scripts.deb"

time curl \
	-H "X-JFrog-Art-Api: ${ARTIFACTORY_PASSWORD}" \
	-T "${OPENCV_SOURCE_DIR}/opencv/build/${DEBIAN_PACKAGE_DEV}" \
	"https://sixriver.jfrog.io/sixriver/debian/pool/main/o/opencv/${DEBIAN_PACKAGE_DEV};deb.distribution=${DISTRO};deb.component=main;deb.architecture=${ARCH}"

time curl \
	-H "X-JFrog-Art-Api: ${ARTIFACTORY_PASSWORD}" \
	-T "${OPENCV_SOURCE_DIR}/opencv/build/${DEBIAN_PACKAGE_LIBS}" \
	"https://sixriver.jfrog.io/sixriver/debian/pool/main/o/opencv/${DEBIAN_PACKAGE_LIBS};deb.distribution=${DISTRO};deb.component=main;deb.architecture=${ARCH}"

time curl \
	-H "X-JFrog-Art-Api: ${ARTIFACTORY_PASSWORD}" \
	-T "${OPENCV_SOURCE_DIR}/opencv/build/${DEBIAN_PACKAGE_PYTHON}" \
	"https://sixriver.jfrog.io/sixriver/debian/pool/main/o/opencv/${DEBIAN_PACKAGE_PYTHON};deb.distribution=${DISTRO};deb.component=main;deb.architecture=${ARCH}"

time curl \
	-H "X-JFrog-Art-Api: ${ARTIFACTORY_PASSWORD}" \
	-T "${OPENCV_SOURCE_DIR}/opencv/build/${DEBIAN_PACKAGE_LICENSES}" \
	"https://sixriver.jfrog.io/sixriver/debian/pool/main/o/opencv/${DEBIAN_PACKAGE_LICENSES};deb.distribution=${DISTRO};deb.component=main;deb.architecture=${ARCH}"

time curl \
	-H "X-JFrog-Art-Api: ${ARTIFACTORY_PASSWORD}" \
	-T "${OPENCV_SOURCE_DIR}/opencv/build/${DEBIAN_PACKAGE_SCRIPTS}" \
	"https://sixriver.jfrog.io/sixriver/debian/pool/main/o/opencv/${DEBIAN_PACKAGE_SCRIPTS};deb.distribution=${DISTRO};deb.component=main;deb.architecture=${ARCH}"

popd

rm -rf ${OPENCV_SOURCE_DIR}/build
