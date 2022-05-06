SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Set this path and run the script.
BASE_PROPELLER_CLANG_DIR=$SCRIPTPATH/propeller
CLANG_VERSION=12

PATH_TO_LLVM_SOURCES=${BASE_PROPELLER_CLANG_DIR}/sources
INSTALL_DIR=$SCRIPTPATH/install
BUILD_DIR=$SCRIPTPATH/build

CPATH=${INSTALL_DIR}/instrumented/bin
cmake -G Ninja ${TOPLEV}/llvm-project/llvm -DLLVM_TARGETS_TO_BUILD=X86 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=$CPATH/clang -DCMAKE_CXX_COMPILER=$CPATH/clang++ \
    -DLLVM_ENABLE_PROJECTS="clang" \
    -DLLVM_USE_LINKER=lld
ninja clang
