SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Set this path and run the script.
BASE_PROPELLER_CLANG_DIR=$SCRIPTPATH/propeller
CLANG_VERSION=12
BENCHMARKING_CLANG_BUILD=${BASE_PROPELLER_CLANG_DIR}/benchmarking_clang_build
PATH_TO_BASELINE_CLANG_BUILD=${BASE_PROPELLER_CLANG_DIR}/baseline_clang_build
PATH_TO_PROPELLER_CLANG_BUILD=${BASE_PROPELLER_CLANG_DIR}/propeller_build


# Run comparison of baseline verus propeller optimized clang
cd ${BENCHMARKING_CLANG_BUILD}/symlink_to_clang_binary
ln -sf ${PATH_TO_BASELINE_CLANG_BUILD}/bin/clang-${CLANG_VERSION} clang
ln -sf ${PATH_TO_BASELINE_CLANG_BUILD}/bin/clang-${CLANG_VERSION} clang++
cd ..
ninja clean
perf stat -r5 -e instructions,cycles,L1-icache-misses,iTLB-misses -- bash -c "ninja -j8 clang && ninja clean"

cd ${BENCHMARKING_CLANG_BUILD}/symlink_to_clang_binary
ln -sf ${PATH_TO_PROPELLER_CLANG_BUILD}/bin/clang-${CLANG_VERSION} clang
ln -sf ${PATH_TO_PROPELLER_CLANG_BUILD}/bin/clang-${CLANG_VERSION} clang++
cd ..
ninja clean
perf stat -r5 -e instructions,cycles,L1-icache-misses,iTLB-misses -- bash -c "ninja -j8 clang && ninja clean"