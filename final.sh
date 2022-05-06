INSTALL_DIR=/home/propeller/src/install
BUILD_DIR=/home/propeller/src/build

BASE_PROPELLER_CLANG_DIR=/home/propeller/src/propeller
CLANG_VERSION=12

PATH_TO_LLVM_SOURCES=${BASE_PROPELLER_CLANG_DIR}/sources
CPATH=${INSTALL_DIR}/trunk/bin

cd ${INSTALL_DIR}/instrumented/profiles
$CPATH/llvm-profdata merge -output=clang.profdata *

PATH_TO_LLVM_SOURCES=${BASE_PROPELLER_CLANG_DIR}/sources
PATH_TO_TRUNK_LLVM_BUILD=${BASE_PROPELLER_CLANG_DIR}/trunk_llvm_build
BENCHMARKING_CLANG_BUILD=${BASE_PROPELLER_CLANG_DIR}/benchmarking_clang_build
PATH_TO_CREATE_LLVM_PROF=${BASE_PROPELLER_CLANG_DIR}/create_llvm_prof_build
PATH_TO_BASELINE_CLANG_BUILD=${BASE_PROPELLER_CLANG_DIR}/baseline_clang_build
PATH_TO_LABELS_CLANG_BUILD=${BASE_PROPELLER_CLANG_DIR}/labels_clang_build
# Convert profiles using create_llvm_prof
cd ${BENCHMARKING_CLANG_BUILD}
${PATH_TO_CREATE_LLVM_PROF}/autofdo/create_llvm_prof --format=propeller \
  --binary=${PATH_TO_LABELS_CLANG_BUILD}/bin/clang-${CLANG_VERSION} \
  --profile=perf.data --out=cluster.txt  --propeller_symorder=symorder.txt #2>/dev/null 1>/dev/null
ls cluster.txt symorder.txt

# Common CMAKE Flags
COMMON_CMAKE_FLAGS=(
  "-DLLVM_OPTIMIZED_TABLEGEN=On"
  "-DCMAKE_BUILD_TYPE=Release"
  "-DLLVM_TARGETS_TO_BUILD=X86"
  "-DLLVM_ENABLE_PROJECTS=clang"
  "-DCMAKE_C_COMPILER=${CPATH}/bin/clang"
  "-DCMAKE_CXX_COMPILER=${CPATH}/bin/clang++" )

# Set Propeller's CMAKE Flags
PROPELLER_CC_LD_CMAKE_FLAGS=(
  "-DCMAKE_C_FLAGS=-funique-internal-linkage-names -fbasic-block-sections=list=${BENCHMARKING_CLANG_BUILD}/cluster.txt"
  "-DCMAKE_CXX_FLAGS=-funique-internal-linkage-names -fbasic-block-sections=list=${BENCHMARKING_CLANG_BUILD}/cluster.txt"
  "-DCMAKE_EXE_LINKER_FLAGS=-Wl,--symbol-ordering-file=${BENCHMARKING_CLANG_BUILD}/symorder.txt -Wl,--no-warn-symbol-ordering -fuse-ld=lld"
  "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--symbol-ordering-file=${BENCHMARKING_CLANG_BUILD}/symorder.txt -Wl,--no-warn-symbol-ordering -fuse-ld=lld"
  "-DCMAKE_MODULE_LINKER_FLAGS=-Wl,--symbol-ordering-file=${BENCHMARKING_CLANG_BUILD}/symorder.txt -Wl,--no-warn-symbol-ordering -fuse-ld=lld"
  "-DLLVM_ENABLE_LTO=Thin"
  "-DLLVM_PROFDATA_FILE=${INSTALL_DIR}/instrumented/profiles/clang.profdata"
   )

# Build Propeller Optimized Clang
PATH_TO_PROPELLER_CLANG_BUILD=${BUILD_DIR}/propeller
mkdir -p ${PATH_TO_PROPELLER_CLANG_BUILD} && cd ${PATH_TO_PROPELLER_CLANG_BUILD}
cmake -G Ninja "${COMMON_CMAKE_FLAGS[@]}" "${PROPELLER_CC_LD_CMAKE_FLAGS[@]}" ${PATH_TO_LLVM_SOURCES}/llvm-project/llvm
ninja clang
