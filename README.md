# Build PGO and propeller optimized clang


## Build PGO-optimized clang 

PGO is an important method provided by clang to optimize final binary with better layout and optimization results. 

Use `-fprofile-instr-generate` to build PGO-instructmented binary. After running the executable file, there is a profile data created. In LLVM project, we can use a similar option to enable this build: `DLLVM_BUILD_INSTRUMENTED=ON`

Then, you can use `llvm-profdata merge` to convert the output into a readable file.

Finally, use `-fprofile-instr-use` to enable the profile in the final version of the binanry. In LLVM project, the option `-DLLVM_PROFDATA_FILE=clang.profdata` has the same functionialty. 

Using clang for example, there are 3 targets need to run:
1. `.instrumented` target will build the instrumented version of `clang`
2. `bench-instrumented` target will run instrumented clang to do profiling
3. `merge_prof` need to merge the profiles and use it in `.pgo` target to build a PGO-optimized `clang`


## Build propeller optimized clang

propeller is an offline tool to convert `perf` profiling data into a cluster file `cluster.txt` and a symbol ordering file `symorder.txt` to provide post-link optimization. 

Use `-funique-internal-linkage-names -fbasic-block-sections=labels` to build the labeled version of clang and use `perf` tool to do profiling. 

Then, use `create_llvm_prof` to convert the collected profiles into `cluster.txt` and `symorder.txt`.

Finally, pass the `cluster.txt` into the compiler using `-funique-internal-linkage-names -fbasic-block-sections=list=cluster.txt` and pass the `-Wl,--symbol-ordering-file=symorder.txt` into linker. (linker should be `lld`)


Using clang for example, there are 3 targets need to run:
1. `.labeled` target will build the labeled version of `clang`
2. `bench-labeled` target will run instrumented clang to do profiling
3. `labels.create_llvm_prof` need to merge the profiles and use it in `.propeller` target to build a propeller-optimized `clang`



## Build PGO+propeller optimized clang

On top of PGO-optimized clang, we can use propeller to optimize its finally code layout. 

1. In target `pgo-labels` , we need to build a labeled PGO-optimized clang. `-Wl,--lto-basic-block-sections=labels` should be passed to the linker since it's using LTO.
2. `bench-pgo-labels` target will profile the labeled clang.
3. `.final` target will build the PGO+propeller optimized clang. Especially, `-Wl,--lto-basic-block-sections=cluster.txt` also need to pass into the linker when LTO enabled.



