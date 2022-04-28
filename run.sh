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


# Set this path and run the script.
BASE_PROPELLER_CLANG_DIR=/home/propeller/src/propeller

PATH_TO_LLVM_SOURCES=${BASE_PROPELLER_CLANG_DIR}/sources
PATH_TO_TRUNK_LLVM_BUILD=${BASE_PROPELLER_CLANG_DIR}/trunk_llvm_build
# Build Trunk LLVM
mkdir -p ${PATH_TO_LLVM_SOURCES} && cd ${PATH_TO_LLVM_SOURCES}
git clone https://github.com/llvm/llvm-project.git
mkdir -p ${PATH_TO_TRUNK_LLVM_BUILD} && cd ${PATH_TO_TRUNK_LLVM_BUILD}
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_ENABLE_PROJECTS="clang;lld" ${PATH_TO_LLVM_SOURCES}/llvm-project/llvm
ninja

#Build create_llvm_prof
PATH_TO_CREATE_LLVM_PROF=${BASE_PROPELLER_CLANG_DIR}/create_llvm_prof_build
mkdir -p ${PATH_TO_CREATE_LLVM_PROF} && cd ${PATH_TO_CREATE_LLVM_PROF}
git clone --recursive https://github.com/google/autofdo.git
cd autofdo && git checkout origin/propeller
aclocal -I .; autoheader; autoconf; automake --add-missing -c
./configure --with-llvm=${PATH_TO_TRUNK_LLVM_BUILD}/bin/llvm-config \
  CC=${PATH_TO_TRUNK_LLVM_BUILD}/bin/clang \
  CXX=${PATH_TO_TRUNK_LLVM_BUILD}/bin/clang++
make
ls create_llvm_prof

# Common CMAKE Flags
COMMON_CMAKE_FLAGS=(
  "-DLLVM_OPTIMIZED_TABLEGEN=On"
  "-DCMAKE_BUILD_TYPE=Release"
  "-DLLVM_TARGETS_TO_BUILD=X86"
  "-DLLVM_ENABLE_PROJECTS=clang"
  "-DCMAKE_C_COMPILER=${PATH_TO_TRUNK_LLVM_BUILD}/bin/clang"
  "-DCMAKE_CXX_COMPILER=${PATH_TO_TRUNK_LLVM_BUILD}/bin/clang++" )

# Additional Baseline CMAKE flags
BASELINE_CC_LD_CMAKE_FLAGS=(
  "-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld"
  "-DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld"
  "-DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=lld" )

# Build Baseline Clang Binary
PATH_TO_BASELINE_CLANG_BUILD=${BASE_PROPELLER_CLANG_DIR}/baseline_clang_build
mkdir -p ${PATH_TO_BASELINE_CLANG_BUILD} && cd ${PATH_TO_BASELINE_CLANG_BUILD}
cmake -G Ninja "${COMMON_CMAKE_FLAGS[@]}" "${BASELINE_CC_LD_CMAKE_FLAGS[@]}" ${PATH_TO_LLVM_SOURCES}/llvm-project/llvm
ninja clang

# Labels CMAKE Flags
LABELS_CC_LD_CMAKE_FLAGS=(
  "-DCMAKE_C_FLAGS=-funique-internal-linkage-names -fbasic-block-sections=labels"
  "-DCMAKE_CXX_FLAGS=-funique-internal-linkage-names -fbasic-block-sections=labels"
  "-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld"
  "-DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld"
  "-DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=lld" )

# Build Labels Clang binary
PATH_TO_LABELS_CLANG_BUILD=${BASE_PROPELLER_CLANG_DIR}/labels_clang_build
mkdir -p ${PATH_TO_LABELS_CLANG_BUILD} && cd ${PATH_TO_LABELS_CLANG_BUILD}
cmake -G Ninja "${COMMON_CMAKE_FLAGS[@]}" "${LABELS_CC_LD_CMAKE_FLAGS[@]}" ${PATH_TO_LLVM_SOURCES}/llvm-project/llvm
ninja clang

# Set up Benchmarking and BUILD
BENCHMARKING_CLANG_BUILD=${BASE_PROPELLER_CLANG_DIR}/benchmarking_clang_build
mkdir -p ${BENCHMARKING_CLANG_BUILD} && cd ${BENCHMARKING_CLANG_BUILD}
mkdir symlink_to_clang_binary && cd symlink_to_clang_binary
ln -sf ${PATH_TO_LABELS_CLANG_BUILD}/bin/clang-12 clang
ln -sf ${PATH_TO_LABELS_CLANG_BUILD}/bin/clang-12 clang++

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

# Convert profiles using create_llvm_prof
cd ${BENCHMARKING_CLANG_BUILD}
${PATH_TO_CREATE_LLVM_PROF}/autofdo/create_llvm_prof --format=propeller \
  --binary=${PATH_TO_LABELS_CLANG_BUILD}/bin/clang-12 \
  --profile=perf.data --out=cluster.txt  --propeller_symorder=symorder.txt 2>/dev/null 1>/dev/null
ls cluster.txt symorder.txt

# Set Propeller's CMAKE Flags
PROPELLER_CC_LD_CMAKE_FLAGS=(
  "-DCMAKE_C_FLAGS=-funique-internal-linkage-names -fbasic-block-sections=list=${BENCHMARKING_CLANG_BUILD}/cluster.txt"
  "-DCMAKE_CXX_FLAGS=-funique-internal-linkage-names -fbasic-block-sections=list=${BENCHMARKING_CLANG_BUILD}/cluster.txt"
  "-DCMAKE_EXE_LINKER_FLAGS=-Wl,--symbol-ordering-file=${BENCHMARKING_CLANG_BUILD}/symorder.txt -Wl,--no-warn-symbol-ordering -fuse-ld=lld"
  "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--symbol-ordering-file=${BENCHMARKING_CLANG_BUILD}/symorder.txt -Wl,--no-warn-symbol-ordering -fuse-ld=lld"
  "-DCMAKE_MODULE_LINKER_FLAGS=-Wl,--symbol-ordering-file=${BENCHMARKING_CLANG_BUILD}/symorder.txt -Wl,--no-warn-symbol-ordering -fuse-ld=lld" )

# Build Propeller Optimized Clang
PATH_TO_PROPELLER_CLANG_BUILD=${BASE_PROPELLER_CLANG_DIR}/propeller_build
mkdir -p ${PATH_TO_PROPELLER_CLANG_BUILD} && cd ${PATH_TO_PROPELLER_CLANG_BUILD}
cmake -G Ninja "${COMMON_CMAKE_FLAGS[@]}" "${PROPELLER_CC_LD_CMAKE_FLAGS[@]}" ${PATH_TO_LLVM_SOURCES}/llvm-project/llvm
ninja clang

# Run comparison of baseline verus propeller optimized clang
cd ${BENCHMARKING_CLANG_BUILD}/symlink_to_clang_binary
ln -sf ${PATH_TO_BASELINE_CLANG_BUILD}/bin/clang-12 clang
ln -sf ${PATH_TO_BASELINE_CLANG_BUILD}/bin/clang-12 clang++
cd ..
ninja clean
perf stat -r5 -e instructions,cycles,L1-icache-misses,iTLB-misses -- bash -c "ninja -j48 clang && ninja clean"

cd ${BENCHMARKING_CLANG_BUILD}/symlink_to_clang_binary
ln -sf ${PATH_TO_PROPELLER_CLANG_BUILD}/bin/clang-12 clang
ln -sf ${PATH_TO_PROPELLER_CLANG_BUILD}/bin/clang-12 clang++
cd ..
ninja clean
perf stat -r5 -e instructions,cycles,L1-icache-misses,iTLB-misses -- bash -c "ninja -j48 clang && ninja clean"