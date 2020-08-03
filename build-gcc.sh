#!/bin/bash
# Script to build RISC-V GNU Toolchain.

# This file uses source code from the University of Berkeley RISC-V project
# in original or modified form.
# Please see LICENSE for details.


### If using NCSU RHEL-6 machine
#source scl_source enable devtoolset-3

#Path to the directory where the compiled RISC-V GCC should be installed
export RISCV_INSTALL=$PWD/install

### Set the correct compiler path if using a custom GCC build
#GCC_PATH=/afs/eos.ncsu.edu/lockers/research/ece/ericro/common/gcc920_64
#GCC_SUFFIX=920

#export CC=$GCC_PATH/bin/gcc$GCC_SUFFIX
#export CXX=$GCC_PATH/bin/g++$GCC_SUFFIX
#export LD=$GCC_PATH/bin/ld$GCC_SUFFIX
#export AR=$GCC_PATH/bin/ar$GCC_SUFFIX
#export RANLIB=$GCC_PATH/bin/ranlib$GCC_SUFFIX
#export LDFLAGS="-L$GCC_PATH/lib64"
##export LD_LIBRARY_PATH="$GCC_PATH/lib64"

#CFLAGS="-g -O0"
#CXXFLAGS="-g -O0"
#
#export CFLAGS
#export CXXFLAGS

source ./build.common

build_gcc_newlib riscv-gnu-toolchain --prefix=$RISCV_INSTALL --with-arch=rv64imfd --with-abi=lp64d
