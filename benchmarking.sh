#!/bin/bash

## This script does the following:
## 1. It checks out and builds trunk LLVM.
## 2. It checks out and builds the create_llvm_prof tool.
## 3. It builds multiple clang binaries towards building a
##    propeller optimized clang binary.
## 4. It runs performance comparisons of a baseline clang
##    binary and the Propeller optimized clang binary.

## To run this script please set BASE_PROPELLER_CLANG_DIR and run:
## sh propeller_optimize_clang.sh

## The propeller optimized clang binary will be in:
## ${BASE_PROPELLER_CLANG_DIR}/propeller_build/bin/clang


SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Set this path and run the script.
BASE_PROPELLER_CLANG_DIR=$SCRIPTPATH/propeller
CLANG_VERSION=12
PATH_TO_LABELS_CLANG_BUILD=${BASE_PROPELLER_CLANG_DIR}/labels_clang_build
PATH_TO_LLVM_SOURCES=${BASE_PROPELLER_CLANG_DIR}/sources
# Set up Benchmarking and BUILD
BENCHMARKING_CLANG_BUILD=${BASE_PROPELLER_CLANG_DIR}/benchmarking_clang_build
mkdir -p ${BENCHMARKING_CLANG_BUILD} && cd ${BENCHMARKING_CLANG_BUILD}
mkdir -p symlink_to_clang_binary && cd symlink_to_clang_binary
ln -sf ${PATH_TO_LABELS_CLANG_BUILD}/bin/clang-${CLANG_VERSION} clang
ln -sf ${PATH_TO_LABELS_CLANG_BUILD}/bin/clang-${CLANG_VERSION} clang++


# Setup cmake for Benchmarking BUILD
cd ${BENCHMARKING_CLANG_BUILD}
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_ENABLE_PROJECTS=clang \
               -DCMAKE_C_COMPILER=${BENCHMARKING_CLANG_BUILD}/symlink_to_clang_binary/clang \
               -DCMAKE_CXX_COMPILER=${BENCHMARKING_CLANG_BUILD}/symlink_to_clang_binary/clang++ \
               ${PATH_TO_LLVM_SOURCES}/llvm-project/llvm

# Profile labels binary, just 10 compilations should do.
ninja -t commands | head -100 >& ./perf_commands.sh
chmod +x ./perf_commands.sh
perf record -e cycles:u -j any,u -- ./perf_commands.sh
ls perf.data
