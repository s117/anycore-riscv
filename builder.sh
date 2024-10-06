#!/bin/bash
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
CR=$'\n'

fatal() {
  echo "$1"
  echo "Usage: $0 [debug|normal] [newlib|linux] [compiler|tools|fesvr|spike|dpi|pk|clean|version_only]"
  exit 1
}

parse_args() {
  if [ $# -ne 3 ]; then
    fatal "please provides 3 arguments"
  fi

  BUILD_TYPE=$1
  BUILD_TOOLCHAIN=$2
  IFS='+' read -r -a BUILD_TARGETS <<<"$3"

  CLEAN_MODE="no"
  VERSION_ONLY_MODE="no"
  TARGET_COMPILER="no"
  TARGET_FESVR="no"
  TARGET_SPIKE="no"
  TARGET_DPI="no"
  TARGET_PK="no"

  for tgt in "${BUILD_TARGETS[@]}"; do
    if [ "${tgt}" = "clean" ]; then
      CLEAN_MODE="yes"
    elif [ "${tgt}" = "version_only" ]; then
      VERSION_ONLY_MODE="yes"
    elif [ "${tgt}" = "all" ]; then
      TARGET_COMPILER="yes"
      TARGET_FESVR="yes"
      TARGET_SPIKE="yes"
      TARGET_DPI="yes"
      TARGET_PK="yes"
      CLEAN_MODE_ALL="yes"
    elif [ "${tgt}" = "compiler" ]; then
      TARGET_COMPILER="yes"
    elif [ "${tgt}" = "tools" ]; then
      TARGET_FESVR="yes"
      TARGET_SPIKE="yes"
      TARGET_DPI="yes"
      TARGET_PK="yes"
    elif [ "${tgt}" = "fesvr" ]; then
      TARGET_FESVR="yes"
    elif [ "${tgt}" = "spike" ]; then
      TARGET_FESVR="yes"
      TARGET_SPIKE="yes"
    elif [ "${tgt}" = "dpi" ]; then
      TARGET_FESVR="yes"
      TARGET_DPI="yes"
    elif [ "${tgt}" = "pk" ]; then
      TARGET_PK="yes"
      TARGET_FESVR="yes"
      TARGET_SPIKE="yes"
    else
      fatal "Error: bad target: ${tgt}"
    fi
  done

  if [ "${BUILD_TOOLCHAIN}" = "newlib" ]; then
    RISCV_INSTALL="$PWD/install"
    RISCV_TOOLCHAIN_PREFIX="riscv64-unknown-elf-"
  elif [ "${BUILD_TOOLCHAIN}" = "linux" ]; then
    RISCV_INSTALL="$PWD/install-linux"
    RISCV_TOOLCHAIN_PREFIX="riscv64-unknown-linux-gnu-"
  else
    fatal "Error: bad toolchain: ${BUILD_TOOLCHAIN}"
  fi

  if [ "${BUILD_TYPE}" = "debug" ]; then
    RISCV_INSTALL="${RISCV_INSTALL}-debug"
    spike_extra_flag="--enable-dbg-trace"
  elif [ "${BUILD_TYPE}" = "normal" ]; then
    echo
  else
    fatal "Error: bad build type: ${BUILD_TYPE}"
  fi

  echo "******************************************"
  echo "                Task brief                "
  echo "******************************************"
  echo " Build type:        *  ${BUILD_TYPE}      "
  echo "******************************************"
  echo " Toolchain:         *  ${BUILD_TOOLCHAIN} "
  echo "******************************************"
  echo " Installation path: *  ${RISCV_INSTALL}   "
  echo "******************************************"
  echo " Target:            *                     "
  echo "   CLEAN:           *  ${CLEAN_MODE}      "
  echo "   COMPILER:        *  ${TARGET_COMPILER} "
  echo "   FESVR:           *  ${TARGET_FESVR}    "
  echo "   SPIKE:           *  ${TARGET_SPIKE}    "
  echo "   DPI:             *  ${TARGET_DPI}      "
  echo "   PRORY KERNEL:    *  ${TARGET_PK}       "
  echo "******************************************"
}

parse_args "$@"

source "${SCRIPT_DIR}/build.common"
source "${SCRIPT_DIR}/version.common"

if [ "${CLEAN_MODE}" = "yes" ]; then
  echo "Cleanning build files...${CR}"
  [ "${TARGET_COMPILER}" = "yes" ] && [ "${BUILD_TOOLCHAIN}" = "newlib" ] && clean_gcc_newlib riscv-gnu-toolchain
  [ "${TARGET_COMPILER}" = "yes" ] && [ "${BUILD_TOOLCHAIN}" = "linux" ] && clean_gcc_linux riscv-gnu-toolchain
  [ "${TARGET_DPI}" = "yes" ] && clean_project riscv-dpi
  [ "${TARGET_FESVR}" = "yes" ] && clean_project riscv-fesvr
  [ "${TARGET_SPIKE}" = "yes" ] && clean_project riscv-isa-sim
  [ "${TARGET_PK}" = "yes" ] && clean_project riscv-pk
  echo

  if [ "${CLEAN_MODE_ALL}" = "yes" ]; then
    echo "Cleaning RISC-V Compiler and Tools installation.${CR}"
    if [ -e "${RISCV_INSTALL}" ]; then
      echo "Removing ${RISCV_INSTALL}"
      rm -fr "${RISCV_INSTALL}"
    fi
    echo
  fi

  exit 0
fi

if [ "${TARGET_COMPILER}" = "yes" ]; then
  if [ "${BUILD_TOOLCHAIN}" = "newlib" ]; then
    if [ "${VERSION_ONLY_MODE}" != "yes" ]; then
      CXXFLAGS_FOR_TARGET_EXTRA="-g" CFLAGS_FOR_TARGET_EXTRA="-g" build_gcc_newlib riscv-gnu-toolchain --prefix="${RISCV_INSTALL}" --with-arch=rv64imfd --with-abi=lp64d
    fi
    log_newlib_toolchain_version_to "${RISCV_INSTALL}"
  else
    if [ "${VERSION_ONLY_MODE}" != "yes" ]; then
      CXXFLAGS_FOR_TARGET_EXTRA="-g" CFLAGS_FOR_TARGET_EXTRA="-g" build_gcc_linux riscv-gnu-toolchain --prefix="${RISCV_INSTALL}" --with-arch=rv64imafd --with-abi=lp64d
    fi
    log_linux_toolchain_version_to "${RISCV_INSTALL}"
  fi
fi

if [ "${TARGET_FESVR}" = "yes" ]; then
  if [ "${VERSION_ONLY_MODE}" != "yes" ]; then
    build_project riscv-fesvr --prefix="${RISCV_INSTALL}"
  fi
  log_fesvr_version_to "${RISCV_INSTALL}"
fi

if [ "${TARGET_SPIKE}" = "yes" ]; then
  if [ "${VERSION_ONLY_MODE}" != "yes" ]; then
    build_project riscv-isa-sim --prefix="${RISCV_INSTALL}" --with-fesvr="${RISCV_INSTALL}" --enable-simpoint ${spike_extra_flag}
  fi
  log_spike_version_to "${RISCV_INSTALL}" "${CR}For ${BUILD_TYPE} use"
fi

if [ "${TARGET_DPI}" = "yes" ]; then
  if [ "${VERSION_ONLY_MODE}" != "yes" ]; then
    build_project riscv-dpi --prefix="${RISCV_INSTALL}" --with-fesvr="${RISCV_INSTALL}" --enable-checker
  fi
  log_dpi_version_to "${RISCV_INSTALL}"
fi

if [ "${TARGET_PK}" = "yes" ]; then
  if [ "${VERSION_ONLY_MODE}" != "yes" ]; then
    (
      export PATH="${RISCV_INSTALL}/bin:${PATH}"
      export CC="${RISCV_TOOLCHAIN_PREFIX}gcc"
      export AR="${RISCV_TOOLCHAIN_PREFIX}ar"
      export RANLIB="${RISCV_TOOLCHAIN_PREFIX}ranlib"
      export CFLAGS="-g -D__riscv64 -march=rv64imfd -mabi=lp64d"
      export ASFLAGS="-march=rv64imfd -mabi=lp64d"
      check_command "${CC}"
      check_command "${AR}"
      check_command "${RANLIB}"
      build_project riscv-pk --prefix="${RISCV_INSTALL}/riscv64-unknown-elf" --host=riscv --disable-atomics
    )
  fi
  log_pk_version_to "${RISCV_INSTALL}" "${CR}Build by ${RISCV_TOOLCHAIN_PREFIX}toolchain:${CR}$(cat "${RISCV_INSTALL}/version/${RISCV_TOOLCHAIN_PREFIX}toolchain")"
fi

echo -e "\\nCompleted!"
