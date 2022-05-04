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
CLANG_VERSION=12

PATH_TO_LLVM_SOURCES=${BASE_PROPELLER_CLANG_DIR}/sources
PATH_TO_TRUNK_LLVM_BUILD=${BASE_PROPELLER_CLANG_DIR}/trunk_llvm_build
# Build Trunk LLVM
mkdir -p ${PATH_TO_LLVM_SOURCES} && cd ${PATH_TO_LLVM_SOURCES}
git clone --depth 1 --single-branch --branch release/${CLANG_VERSION}.x https://github.com/llvm/llvm-project.git
mkdir -p ${PATH_TO_TRUNK_LLVM_BUILD} && cd ${PATH_TO_TRUNK_LLVM_BUILD}
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD=X86 -DLLVM_ENABLE_PROJECTS="clang;lld" ${PATH_TO_LLVM_SOURCES}/llvm-project/llvm
ninja

#Build create_llvm_prof
PATH_TO_CREATE_LLVM_PROF=${BASE_PROPELLER_CLANG_DIR}/create_llvm_prof_build
mkdir -p ${PATH_TO_CREATE_LLVM_PROF} && cd ${PATH_TO_CREATE_LLVM_PROF}
git clone  --depth 1 --single-branch --branch propeller --recursive https://github.com/google/autofdo.git
cd autofdo 
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
