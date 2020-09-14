#!/bin/bash
set -e

fatal(){
  echo "$1"
  echo "Usage: $0 [debug|normal] [newlib|linux] [compiler|tools|clean|fesvr|spike|dpi|pk]"
  exit 1
}

if [[ $# != 3 ]]; then
  fatal "please provides 3 argument"
fi

BUILD_TYPE=$1
BUILD_TOOLCHAIN=$2
IFS='+' read -r -a BUILD_TARGETS <<< "$3"

TARGET_CLEAN="no"
TARGET_COMPILER="no"
TARGET_TOOLS="no"
TARGET_FESVR="no"
TARGET_SPIKE="no"
TARGET_DPI="no"
TARGET_PK="no"


for tgt in "${BUILD_TARGETS[@]}"; do
  if [[ $tgt == "clean" && x$TARGET_CLEAN == "xno" ]]; then
    TARGET_CLEAN="yes"
  elif [[ $tgt == "compiler" && x$TARGET_COMPILER == "xno" ]]; then
    TARGET_COMPILER="yes"
  elif [[ $tgt == "tools" && x$TARGET_TOOLS == "xno" ]]; then
    TARGET_TOOLS="yes"
    TARGET_FESVR="yes"
    TARGET_SPIKE="yes"
    TARGET_DPI="yes"
    TARGET_PK="yes"
  elif [[ $tgt == "fesvr" && x$TARGET_TOOLS == "xno" ]]; then
    TARGET_FESVR="yes"
  elif [[ $tgt == "spike" && x$TARGET_TOOLS == "xno" ]]; then
    TARGET_FESVR="yes"
    TARGET_SPIKE="yes"
  elif [[ $tgt == "dpi" && x$TARGET_TOOLS == "xno" ]]; then
    TARGET_FESVR="yes"
    TARGET_DPI="yes"
  elif [[ $tgt == "pk" && x$TARGET_TOOLS == "xno" ]]; then
    TARGET_PK="yes"
  else
    fatal "Error: bad target: $tgt"
  fi
done

if [[ x$TARGET_PK == "xyes"  && x$TARGET_SPIKE == "xno" ]]; then
  >&2 echo "Warning: PK's configure script requires SPIKE to be build first".
fi

newlib_install_folder="install"
linux_install_folder="install-linux"
spike_extra_flag=""


if [[ $BUILD_TYPE == "debug" ]]; then
  newlib_install_folder="${newlib_install_folder}-debug"
  linux_install_folder="${linux_install_folder}-debug"
  spike_extra_flag="--enable-dbg-trace"
elif [[ $BUILD_TYPE == "normal" ]]; then
  echo
else
  fatal "Error: bad build type: $BUILD_TYPE"
fi

NEWLIB_GCC_PATH=$PWD/$newlib_install_folder
if [[ $BUILD_TOOLCHAIN == "newlib" ]]; then
  export RISCV_INSTALL=$PWD/$newlib_install_folder
elif [[ $BUILD_TOOLCHAIN == "linux" ]]; then
  export RISCV_INSTALL=$PWD/$linux_install_folder
else
  fatal "Error: bad toolchain: $BUILD_TOOLCHAIN"
fi

echo "******************************************"
echo "                Task brief                "
echo "******************************************"
echo " Build type:        *    $BUILD_TYPE      "
echo "******************************************"
echo " Toolchain:         *    $BUILD_TOOLCHAIN "
echo "******************************************"
echo " Installation path: *    $RISCV_INSTALL   "
echo "******************************************"
echo " Target:            *                     "
echo "   CLEAN INSTALLED: *    $TARGET_CLEAN    "
echo "   COMPILER:        *    $TARGET_COMPILER "
echo "   FESVR:           *    $TARGET_FESVR    "
echo "   SPIKE:           *    $TARGET_SPIKE    "
echo "   DPI:             *    $TARGET_DPI      "
echo "   PRORY KERNEL:    *    $TARGET_PK       "
echo "******************************************"

source ./build.common

if [[ x$TARGET_CLEAN == "xyes" ]]; then
  echo "Cleaning RISC-V Compiler and Tools installation ($RISCV_INSTALL)."

  rm -fr $RISCV_INSTALL

  echo "Removed."
fi

if [[ x$TARGET_COMPILER == "xyes" ]]; then
  echo "Starting RISC-V Compiler build process"
  if [[ $BUILD_TOOLCHAIN == "newlib" ]]; then
    CXXFLAGS_FOR_TARGET_EXTRA="-g" CFLAGS_FOR_TARGET_EXTRA="-g" build_gcc_newlib riscv-gnu-toolchain --prefix=$RISCV_INSTALL --with-arch=rv64imfd  --with-abi=lp64d
  else
    CXXFLAGS_FOR_TARGET_EXTRA="-g" CFLAGS_FOR_TARGET_EXTRA="-g" build_gcc_linux  riscv-gnu-toolchain --prefix=$RISCV_INSTALL --with-arch=rv64imafd --with-abi=lp64d
  fi

  echo -e "\\nRISC-V Compiler installation completed!"
fi

if [[ x$TARGET_FESVR == "xyes" ]]; then
  build_project riscv-fesvr --prefix=$RISCV_INSTALL
fi

if [[ x$TARGET_SPIKE == "xyes" ]]; then
  build_project riscv-isa-sim --prefix=$RISCV_INSTALL --with-fesvr=$RISCV_INSTALL --enable-simpoint $spike_extra_flag
fi

if [[ x$TARGET_DPI == "xyes" ]]; then
  build_project riscv-dpi --prefix=$RISCV_INSTALL --with-fesvr=$RISCV_INSTALL --enable-checker
fi

if [[ x$TARGET_PK == "xyes" ]]; then
  PATH="$NEWLIB_GCC_PATH/bin:$PATH" check_newlib_gcc
  PATH="$NEWLIB_GCC_PATH/bin:$PATH" CC=riscv64-unknown-elf-gcc CFLAGS="-g -D__riscv64 -march=rv64imfd -mabi=lp64d"  ASFLAGS="-march=rv64imfd -mabi=lp64d" build_project riscv-pk --prefix=$RISCV_INSTALL/riscv64-unknown-elf --host=riscv --disable-atomics
fi

echo -e "\\nCompleted!"
