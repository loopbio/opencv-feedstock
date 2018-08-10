#!/usr/bin/env bash

set +x

mkdir -p build
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

# FFMPEG building requires pkgconfig
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$PREFIX/lib/pkgconfig

# Custom libjpeg-turbo location
LIBJPEG_TURBO_DIR=${PREFIX}/lib/libjpeg-turbo/prefixed

cmake -LAH                                                                \
    -DCMAKE_RULE_MESSAGES=ON                                              \
    -DCMAKE_VERBOSE_MAKEFILE=OFF                                          \
    -DCMAKE_BUILD_TYPE="Release"                                          \
    -DCMAKE_INSTALL_PREFIX=${PREFIX}                                      \
    -DCMAKE_CXX_FLAGS=-isystem\ ${PREFIX}/include                         \
    -DCMAKE_PREFIX_PATH=${PREFIX}                                         \
    -DCMAKE_INSTALL_LIBDIR=${PREFIX}/lib                                  \
    -DENABLE_CXX11=ON                                                     \
    -DWITH_OPENMP=OFF                                                     \
    -DBUILD_opencv_dnn=ON                                                 \
    -DBUILD_SHARED_LIBS=ON                                                \
    -DCPU_BASELINE="SSE3"                                                 \
    -DCPU_DISPATH="SSE4_1;SSE4_2;AVX;FP16;AVX2"                           \
    -DENABLE_FAST_MATH=OFF                                                \
    -DWITH_LAPACK=OFF                                                     \
    -DWITH_IPP=ON                                                         \
    -DBUILD_IPP=ON                                                        \
    -DWITH_TBB=ON                                                         \
    -DBUILD_TBB=OFF                                                       \
    -DTBBROOT=${PREFIX}                                                   \
    -DWITH_EIGEN=ON                                                       \
    -DBUILD_TESTS=OFF                                                     \
    -DBUILD_DOCS=OFF                                                      \
    -DBUILD_PERF_TESTS=OFF                                                \
    -DBUILD_ZLIB=OFF                                                      \
    -DHDF5_ROOT=${PREFIX}                                                 \
    -DWITH_TIFF=ON                                                        \
    -DBUILD_TIFF=OFF                                                      \
    -DWITH_PNG=ON                                                         \
    -DBUILD_PNG=OFF                                                       \
    -DWITH_OPENEXR=ON                                                     \
    -DBUILD_OPENEXR=ON                                                    \
    -DWITH_JASPER=ON                                                      \
    -DBUILD_JASPER=OFF                                                    \
    -DWITH_WEBP=ON                                                        \
    -DBUILD_WEBP=OFF                                                      \
    -DWITH_JPEG=ON                                                        \
    -DBUILD_JPEG=OFF                                                      \
    -DJPEG_INCLUDE_DIR=${LIBJPEG_TURBO_DIR}/include/                      \
    -DJPEG_LIBRARY=${LIBJPEG_TURBO_DIR}/lib/libturbojpeg.a                \
    -DWITH_CUDA=OFF                                                       \
    -DWITH_OPENCL=OFF                                                     \
    -DWITH_OPENGL=OFF                                                     \
    -DWITH_CSTRIPES=OFF                                                   \
    -DWITH_OPENNI=OFF                                                     \
    -DWITH_FFMPEG=ON                                                      \
    -DWITH_GSTREAMER=OFF                                                  \
    -DWITH_MATLAB=OFF                                                     \
    -DWITH_VTK=OFF                                                        \
    -DWITH_QT=5                                                           \
    -DWITH_GPHOTO2=OFF                                                    \
    -DINSTALL_C_EXAMPLES=OFF                                              \
    -DOPENCV_EXTRA_MODULES_PATH="../opencv_contrib-$PKG_VERSION/modules"  \
    -DCMAKE_SKIP_RPATH:bool=ON                                            \
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
    ..

make install --no-print-directory -j${CPU_COUNT}

# Notes:
#
#  Do not put libs in lib64:
#  -DCMAKE_INSTALL_LIBDIR=${PREFIX}/lib
#
#  TBB. Need to globally add the env include dir,
#  otherwise tbb headers cannot be found by several modules.
#  As of 3.4.1, OpenCV also fails to build itself TBB,
#  and to properly transmit includes specifically to
#  the libraries that need them.
#  -DCMAKE_CXX_FLAGS=-isystem\ ${PREFIX}/include
#  -DWITH_TBB=ON
#  -DBUILD_TBB=OFF
#  -DTBBROOT=${PREFIX}
# Alternative config for TBB
#  -DWITH_TBB=ON
#  -DTBB_LIB_DIR=${LIBRARY_PATH}
#  -DTBB_INCLUDE_DIRS=${INCLUDE_PATH}
#  -DTBB_STDDEF_PATH=${INCLUDE_PATH}/tbb/tbb_stddef.h"
# I think it won't work, because opencv submodules do not honor these envvars
#
# Libjpeg-turbo static + symbols prefixed
#  -DJPEG_INCLUDE_DIR=${LIBJPEG_TURBO_DIR}/include/
#  -DJPEG_LIBRARY=${LIBJPEG_TURBO_DIR}/lib/libturbojpeg.a
