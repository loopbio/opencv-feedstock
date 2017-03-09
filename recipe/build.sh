#!/usr/bin/env bash

#
# ----
# Meta
# ----
#
# At the moment this is just a POC, taylored to my machines (all with very
# recent processors and GPUs).
#
# Conda-features just makes it hard to have easy, not copy and paste,
# builds with different options. In particular, we should make at least
# two packages: turbo and turbo-cuda. We probably can manage that
# by defining a build matrix in conda-forge.yaml and change parameters
# accordingly.
#

#
# ----
# CUDA
# ----
#  Some googling:
#   http://docs.opencv.org/trunk/d2/dbc/cuda_intro.html
#   http://answers.opencv.org/question/5090/why-opencv-building-is-so-slow-with-cuda/
#   http://stackoverflow.com/questions/28010399/build-opencv-with-cuda-support
#
#  Do not generate too big, too generic package:
#   https://developer.nvidia.com/cuda-gpus
#    -DCUDA_ARCH_BIN="5.2 6.1" => Target only Maxwell and Pascal
#    -DCUDA_ARCH_PTX=OFF       => Do not generate PTX code
#
# An example set of parameters:
#    -DWITH_CUDA=ON                                                        \
#    -DCUDA_ARCH_BIN="5.2 6.1"                                             \
#    -DCUDA_ARCH_PTX=OFF                                                   \
#    -DCUDA_FAST_MATH=ON                                                   \
#    -DWITH_CUBLAS=ON                                                      \
#    -DWITH_CUFFT=ON                                                       \
#    -DWITH_NVCUVID=OFF                                                    \
#
# - I do not know how profitable this potentially is, specially when using only the python bindings.
# - It makes the package large (maybe we should just strip all the elfs)
# - Anything to do about cudnn?
# - I guess if we want ot use NVCUVID, we would do in a custom FFMPEG build.
#   https://developer.nvidia.com/nvidia-video-codec-sdk
#

#
# --------------------
# OpenCV Optimizations
# --------------------
#
# Main source of info is CMakeLists
#   https://github.com/opencv/opencv/blob/master/CMakeLists.txt
#
# A sample of a google search results
#   http://stackoverflow.com/questions/40150265/processor-optimization-flags-in-opencv
#   https://alliance.seas.upenn.edu/~cis700ii/dynamic/techinfo/2015/09/04/compiling-and-benchmarking-opencv-3-0/
#   https://sunglint.wordpress.com/2014/06/04/opencv-config-opt/
#   http://answers.opencv.org/question/696/how-to-enable-vectorization-in-opencv/
#
# An example set of parameters:
#    -DCMAKE_C_FLAGS="-O2 -std=cWHATEVER -march=native"                    \
#    -DCMAKE_CXX_FLAGS="-O2 -std=c++WHATEVER -march=native"                \
#    -DWITH_OPENMP=ON                                                      \
#    -DENABLE_AVX=ON                                                       \
#    -DENABLE_AVX2=ON                                                      \
#    -DENABLE_POPCNT=ON                                                    \
#    -DENABLE_SSE41=ON                                                     \
#    -DENABLE_SSE42=ON                                                     \
#    -DENABLE_SSSE3=ON                                                     \
#    -DENABLE_FMA3=ON                                                      \
#    -DENABLE_FAST_MATH=ON                                                 \
#
# - Maybe we could also check how well does clang here
#   (use clangdev in conda-forge)
# - Here John should say what he thinks is better
# - Run loopb benchmarks will be fun
# - What about TBB, full IPPCV and whatever I do not know?
#

set +x
SHORT_OS_STR=$(uname -s)

if [ "${SHORT_OS_STR:0:5}" == "Linux" ]; then
    DYNAMIC_EXT="so"
    OPENMP="-DWITH_OPENMP=1"
fi
if [ "${SHORT_OS_STR}" == "Darwin" ]; then
    DYNAMIC_EXT="dylib"
    OPENMP=""
fi

curl -L -O "https://github.com/opencv/opencv_contrib/archive/$PKG_VERSION.tar.gz"
test `openssl sha256 $PKG_VERSION.tar.gz | awk '{print $2}'` = "1e2bb6c9a41c602904cc7df3f8fb8f98363a88ea564f2a087240483426bf8cbe"
tar -zxf $PKG_VERSION.tar.gz

# Contrib has patches that need to be applied
# https://github.com/opencv/opencv_contrib/issues/919
patch -p0 <$RECIPE_DIR/opencv_contrib_freetype.patch
# N.B. do not use git diff here

mkdir build
cd build

if [ $PY3K -eq 1 ]; then
    PY_MAJOR=3
    PY_UNSET_MAJOR=2
    LIB_PYTHON="${PREFIX}/lib/libpython${PY_VER}m${SHLIB_EXT}"
    INC_PYTHON="$PREFIX/include/python${PY_VER}m"
else
    PY_MAJOR=2
    PY_UNSET_MAJOR=3
    LIB_PYTHON="${PREFIX}/lib/libpython${PY_VER}${SHLIB_EXT}"
    INC_PYTHON="$PREFIX/include/python${PY_VER}"
fi


PYTHON_SET_FLAG="-DBUILD_opencv_python${PY_MAJOR}=1"
PYTHON_SET_EXE="-DPYTHON${PY_MAJOR}_EXECUTABLE=${PYTHON}"
PYTHON_SET_INC="-DPYTHON${PY_MAJOR}_INCLUDE_DIR=${INC_PYTHON} "
PYTHON_SET_NUMPY="-DPYTHON${PY_MAJOR}_NUMPY_INCLUDE_DIRS=${SP_DIR}/numpy/core/include"
PYTHON_SET_LIB="-DPYTHON${PY_MAJOR}_LIBRARY=${LIB_PYTHON}"
PYTHON_SET_SP="-DPYTHON${PY_MAJOR}_PACKAGES_PATH=${SP_DIR}"

PYTHON_UNSET_FLAG="-DBUILD_opencv_python${PY_UNSET_MAJOR}=0"
PYTHON_UNSET_EXE="-DPYTHON${PY_UNSET_MAJOR}_EXECUTABLE="
PYTHON_UNSET_INC="-DPYTHON${PY_UNSET_MAJOR}_INCLUDE_DIR="
PYTHON_UNSET_NUMPY="-DPYTHON${PY_UNSET_MAJOR}_NUMPY_INCLUDE_DIRS="
PYTHON_UNSET_LIB="-DPYTHON${PY_UNSET_MAJOR}_LIBRARY="
PYTHON_UNSET_SP="-DPYTHON${PY_UNSET_MAJOR}_PACKAGES_PATH="

# For some reason OpenCV just won't see hdf5.h without updating the CFLAGS
export CFLAGS="$CFLAGS -I$PREFIX/include"
export CXXFLAGS="$CXXFLAGS -I$PREFIX/include"

cmake .. -LAH                                                             \
    $OPENMP                                                               \
    -DOpenBLAS=1                                                          \
    -DOpenBLAS_INCLUDE_DIR=$PREFIX/include                                \
    -DOpenBLAS_LIB=$PREFIX/lib/libopenblas$SHLIB_EXT                      \
    -DWITH_EIGEN=1                                                        \
    -DWITH_IPP=1                                                          \
    -DBUILD_TESTS=0                                                       \
    -DBUILD_DOCS=0                                                        \
    -DBUILD_PERF_TESTS=0                                                  \
    -DBUILD_ZLIB=0                                                        \
    -DHDF5_DIR=$PREFIX                                                    \
    -DHDF5_INCLUDE_DIRS=$PREFIX/include                                   \
    -DHDF5_C_LIBRARY_hdf5=$PREFIX/lib/libhdf5$SHLIB_EXT                   \
    -DHDF5_C_LIBRARY_z=$PREFIX/lib/libz$SHLIB_EXT                         \
    -DFREETYPE_INCLUDE_DIRS=$PREFIX/include/freetype2                     \
    -DFREETYPE_LIBRARIES=$PREFIX/lib/libfreetype$SHLIB_EXT                \
    -DPNG_LIBRARY_RELEASE=$PREFIX/lib/libpng$SHLIB_EXT                    \
    -DPNG_INCLUDE_DIRS=$PREFIX/include                                    \
    -DJPEG_INCLUDE_DIR=$PREFIX/include                                    \
    -DJPEG_LIBRARY=$PREFIX/lib/libjpeg$SHLIB_EXT                          \
    -DTIFF_INCLUDE_DIR=$PREFIX/include                                    \
    -DTIFF_LIBRARY=$PREFIX/lib/libtiff$SHLIB_EXT                          \
    -DJASPER_INCLUDE_DIR=$PREFIX/include                                  \
    -DJASPER_LIBRARY_RELEASE=$PREFIX/lib/libjasper$SHLIB_EXT              \
    -DWEBP_INCLUDE_DIR=$PREFIX/include                                    \
    -DWEBP_LIBRARY=$PREFIX/lib/libwebp$SHLIB_EXT                          \
    -DHARFBUZZ_INCLUDE_DIRS=$PREFIX/include/harfbuzz                      \
    -DHARFBUZZ_LIBRARIES=$PREFIX/lib/libharfbuzz$SHLIB_EXT                \
    -DZLIB_LIBRARY_RELEASE=$PREFIX/lib/libz$SHLIB_EXT                     \
    -DZLIB_INCLUDE_DIR=$PREFIX/include                                    \
    -DHDF5_z_LIBRARY_RELEASE=$PREFIX/lib/libz$SHLIB_EXT                   \
    -DBUILD_TIFF=0                                                        \
    -DBUILD_PNG=0                                                         \
    -DBUILD_OPENEXR=1                                                     \
    -DBUILD_JASPER=0                                                      \
    -DWITH_JPEG=ON                                                        \
    -DBUILD_JPEG=OFF                                                      \
    -DJPEG_INCLUDE_DIR=$PREFIX/include                                    \
    -DJPEG_LIBRARY=$PREFIX/lib/libjpeg$SHLIB_EXT                          \
    -DWITH_LIBV4L=ON                                                      \
    -DWITH_OPENCL=0                                                       \
    -DWITH_OPENNI=0                                                       \
    -DWITH_MATLAB=0                                                       \
    -DWITH_VTK=0                                                          \
    -DWITH_GPHOTO2=0                                                      \
    -DINSTALL_C_EXAMPLES=0                                                \
    -DOPENCV_EXTRA_MODULES_PATH="../opencv_contrib-$PKG_VERSION/modules"  \
    -DCMAKE_BUILD_TYPE="Release"                                          \
    -DCMAKE_SKIP_RPATH:bool=ON                                            \
    -DCMAKE_INSTALL_PREFIX=$PREFIX                                        \
    -DPYTHON_PACKAGES_PATH=${SP_DIR}                                      \
    -DPYTHON_EXECUTABLE=${PYTHON}                                         \
    -DPYTHON_INCLUDE_DIR=${INC_PYTHON}                                    \
    -DPYTHON_LIBRARY=${LIB_PYTHON}                                        \
    $PYTHON_SET_FLAG                                                      \
    $PYTHON_SET_EXE                                                       \
    $PYTHON_SET_INC                                                       \
    $PYTHON_SET_NUMPY                                                     \
    $PYTHON_SET_LIB                                                       \
    $PYTHON_SET_SP                                                        \
    $PYTHON_UNSET_FLAG                                                    \
    $PYTHON_UNSET_EXE                                                     \
    $PYTHON_UNSET_INC                                                     \
    $PYTHON_UNSET_NUMPY                                                   \
    $PYTHON_UNSET_LIB                                                     \
    $PYTHON_UNSET_SP                                                      \
    -DWITH_FFMPEG=ON                                                      \
    -DWITH_GTK=ON                                                         \
    -DWITH_OPENMP=ON                                                      \
    -DENABLE_AVX=ON                                                       \
    -DENABLE_AVX2=ON                                                      \
    -DENABLE_POPCNT=ON                                                    \
    -DENABLE_SSE41=ON                                                     \
    -DENABLE_SSE42=ON                                                     \
    -DENABLE_SSSE3=ON                                                     \
    -DENABLE_FMA3=ON                                                      \
    -DENABLE_FAST_MATH=ON                                                 \
    -DWITH_CUDA=${WITH_CUDA}                                              \
    -DCUDA_ARCH_BIN="5.2 6.1"                                             \
    -DCUDA_ARCH_PTX=OFF                                                   \
    -DCUDA_FAST_MATH=${WITH_CUDA}                                         \
    -DWITH_CUBLAS=${WITH_CUDA}                                            \
    -DWITH_CUFFT=${WITH_CUDA}                                             \
    -DWITH_NVCUVID=OFF

# make -j$CPU_COUNT
make -j8
make install
