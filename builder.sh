#!/bin/bash
set -e

fatal(){
  echo "$1"
  echo "Usage: $0 [debug|normal] [newlib|linux] [compiler|tools|clean|fesvr|spike|dpi|pk|version_only]"
  exit 1
}

CR=$'\n'

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
TARGET_VERSION_ONLY="no"


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
  elif [[ $tgt == "version_only" && x$TARGET_VERSION_ONLY == "xno" ]]; then
    TARGET_VERSION_ONLY="yes"
  else
    fatal "Error: bad target: $tgt"
  fi
done

if [[ x$TARGET_PK == "xyes"  && x$TARGET_SPIKE == "xno" ]]; then
  >&2 echo "Warning: PK's configure script requires SPIKE to be build first".
fi

newlib_install_folder=$PWD/"install"
linux_install_folder=$PWD/"install-linux"
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

NEWLIB_GCC_PATH=$newlib_install_folder
if [[ $BUILD_TOOLCHAIN == "newlib" ]]; then
  export RISCV_INSTALL=$newlib_install_folder
elif [[ $BUILD_TOOLCHAIN == "linux" ]]; then
  export RISCV_INSTALL=$linux_install_folder
else
  fatal "Error: bad toolchain: $BUILD_TOOLCHAIN"
fi

source ./build.common
source ./version.common

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

if [[ x$TARGET_CLEAN == "xyes" && x$TARGET_VERSION_ONLY == "xno" ]]; then
  echo "Cleaning RISC-V Compiler and Tools installation ($RISCV_INSTALL)."

  rm -fr $RISCV_INSTALL

  echo "Removed."
fi

if [[ x$TARGET_COMPILER == "xyes" ]]; then
  echo "Starting RISC-V Compiler build process"
  if [[ $BUILD_TOOLCHAIN == "newlib" ]]; then
    if [[ x$TARGET_VERSION_ONLY == "xno" ]]; then
      CXXFLAGS_FOR_TARGET_EXTRA="-g" CFLAGS_FOR_TARGET_EXTRA="-g" build_gcc_newlib riscv-gnu-toolchain --prefix=$RISCV_INSTALL --with-arch=rv64imfd  --with-abi=lp64d
    fi
    log_newlib_toolchain_version_to "$RISCV_INSTALL"
  else
    if [[ x$TARGET_VERSION_ONLY == "xno" ]]; then
      CXXFLAGS_FOR_TARGET_EXTRA="-g" CFLAGS_FOR_TARGET_EXTRA="-g" build_gcc_linux  riscv-gnu-toolchain --prefix=$RISCV_INSTALL --with-arch=rv64imafd --with-abi=lp64d
    fi
    log_linux_toolchain_version_to "$RISCV_INSTALL"
  fi

  echo -e "\\nRISC-V Compiler installation completed!"
fi

if [[ x$TARGET_FESVR == "xyes" ]]; then
  if [[ x$TARGET_VERSION_ONLY == "xno" ]]; then
    build_project riscv-fesvr --prefix=$RISCV_INSTALL
  fi
  log_fesvr_version_to "$RISCV_INSTALL"
fi

if [[ x$TARGET_SPIKE == "xyes" ]]; then
  if [[ x$TARGET_VERSION_ONLY == "xno" ]]; then
    build_project riscv-isa-sim --prefix=$RISCV_INSTALL --with-fesvr=$RISCV_INSTALL --enable-simpoint $spike_extra_flag
  fi
  log_spike_version_to "$RISCV_INSTALL" "${CR}For $BUILD_TYPE use"
fi

if [[ x$TARGET_DPI == "xyes" ]]; then
  if [[ x$TARGET_VERSION_ONLY == "xno" ]]; then
    build_project riscv-dpi --prefix=$RISCV_INSTALL --with-fesvr=$RISCV_INSTALL --enable-checker
  fi
  log_dpi_version_to "$RISCV_INSTALL"
fi

if [[ x$TARGET_PK == "xyes" ]]; then
  PATH="$NEWLIB_GCC_PATH/bin:$PATH" check_newlib_gcc
  if [[ x$TARGET_VERSION_ONLY == "xno" ]]; then
    PATH="$NEWLIB_GCC_PATH/bin:$PATH" CC=riscv64-unknown-elf-gcc CFLAGS="-g -D__riscv64 -march=rv64imfd -mabi=lp64d"  ASFLAGS="-march=rv64imfd -mabi=lp64d" build_project riscv-pk --prefix=$RISCV_INSTALL/riscv64-unknown-elf --host=riscv --disable-atomics
  fi
  log_pk_version_to "$RISCV_INSTALL" "${CR}Build by riscv64-unknown-elf-toolchain:${CR}$(cat $NEWLIB_GCC_PATH/version/riscv64-unknown-elf-toolchain)"
fi

echo -e "\\nCompleted!"
