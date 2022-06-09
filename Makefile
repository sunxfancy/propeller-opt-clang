INSIDE_DOCKER=$(shell [ -f /.dockerenv ] && echo 1 || echo 0 )

PWD = $(shell pwd)
ifeq ($(INSIDE_DOCKER), 0)
	DOCKER = docker run -it --rm --volume="$(PWD):/home/propeller/src" propeller 
	DOCKER_START = docker run -it --volume="$(PWD):/home/propeller/src" propeller 
else
	DOCKER = 
endif


CLANG_VERSION=14

PWD=$(shell pwd)
LLVM=$(PWD)/source.dir/llvm-project/llvm
TRUNK=$(PWD)/install.dir/trunk/bin
LABELS=$(PWD)/install.dir/labels/bin
PGO_LABELS=$(PWD)/install.dir/pgo-labels/bin
INSTRUMENTED=$(PWD)/install.dir/instrumented/bin
AUTOFDO=$(PWD)/source.dir/propeller
LABELS_PROF=$(PWD)/bench.dir/labels
PGO_LABELS_PROF=$(PWD)/bench.dir/pgo-labels
INSTRUMENTED_PROF=$(PWD)/build.dir/instrumented/profiles


include ipra/ipra.mk

build: .propeller .baseline .labels .instrumented

opt: .pgo-opt-clang .propeller-opt-clang

final: .pgo-propeller-opt-clang

bench: 
	make bench-labels
	make bench-instrumented
	make labels.create_llvm_prof
	make merge_prof
	make opt
	make bench-pgo-labels
	make pgo-labels.create_llvm_prof
	make final
	make test

test: 
	make baseline.test 
	make pgo-opt-clang.test 
	make propeller-opt-clang.test 
	make pgo-propeller-opt-clang.test

source.dir/.llvm-project: 
	mkdir -p source.dir/
	cd source.dir/ && git clone --depth 1 --single-branch --branch release/${CLANG_VERSION}.x https://github.com/llvm/llvm-project.git
	touch source.dir/.llvm-project
	
.trunk: source.dir/.llvm-project
	mkdir -p build.dir/trunk 
	mkdir -p install.dir/trunk
	cd build.dir/trunk && cmake -G Ninja $(LLVM) \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_TARGETS_TO_BUILD=X86 \
		-DLLVM_ENABLE_PROJECTS="clang;lld;compiler-rt;bolt" \
		-DCOMPILER_RT_BUILD_SANITIZERS=OFF \
		-DCOMPILER_RT_BUILD_XRAY=OFF \
		-DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
		-DCMAKE_INSTALL_PREFIX=$(PWD)/install.dir/trunk
	cd build.dir/trunk && ninja install -j $(shell nproc)
	touch .trunk

source.dir/.propeller: 
	mkdir -p source.dir/
	cd source.dir/ && git clone  --depth 1 --single-branch --branch propeller --recursive https://github.com/sunxfancy/autofdo.git propeller
	touch source.dir/.propeller

source.dir/.autofdo: 
	mkdir -p source.dir/
	cd source.dir/ && git clone  --depth 1 --single-branch --branch master --recursive https://github.com/sunxfancy/autofdo.git autofdo
	touch source.dir/.autofdo

.propeller: source.dir/.propeller .trunk
	cd source.dir/propeller && \
		aclocal -I . && autoheader && autoconf && automake --add-missing -c && \
		./configure --with-llvm=$(TRUNK)/llvm-config
	CC=$(TRUNK)/clang CXX=$(TRUNK)/clang++ cd source.dir/propeller && make
	touch .propeller

.autofdo: source.dir/.autofdo .trunk
	mkdir -p build.dir/autofdo
	mkdir -p install.dir/autofdo
	cd build.dir/autofdo && cmake -G Ninja $(AUTOFDO) \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_PATH=$(PWD)/install.dir/trunk \
		-DCMAKE_C_COMPILER=$(TRUNK)/clang \
		-DCMAKE_CXX_COMPILER=$(TRUNK)/clang++ \
		-DCMAKE_INSTALL_PREFIX=$(PWD)/install.dir/autofdo

	cd build.dir/autofdo && ninja install -j $(shell nproc)
	touch .autofdo

.baseline: .trunk 
	mkdir -p build.dir/baseline
	mkdir -p install.dir/baseline
	cd build.dir/baseline && cmake -G Ninja $(LLVM) \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_TARGETS_TO_BUILD=X86 \
		-DLLVM_OPTIMIZED_TABLEGEN=On \
		-DCMAKE_C_COMPILER=$(TRUNK)/clang \
		-DCMAKE_CXX_COMPILER=$(TRUNK)/clang++ \
		-DLLVM_ENABLE_PROJECTS="clang;lld" \
		-DLLVM_USE_LINKER=lld \
		-DCMAKE_INSTALL_PREFIX=$(PWD)/install.dir/baseline
	cd build.dir/baseline && ninja install -j $(shell nproc)
	touch .baseline

.labels: .trunk 
	mkdir -p build.dir/labels
	mkdir -p install.dir/labels
	cd build.dir/labels && cmake -G Ninja $(LLVM) \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_TARGETS_TO_BUILD=X86 \
		-DLLVM_OPTIMIZED_TABLEGEN=On \
		-DCMAKE_C_COMPILER=$(TRUNK)/clang \
		-DCMAKE_CXX_COMPILER=$(TRUNK)/clang++ \
		-DLLVM_ENABLE_PROJECTS="clang;lld" \
		-DLLVM_USE_LINKER=lld \
		-DCMAKE_C_FLAGS="-funique-internal-linkage-names -fbasic-block-sections=labels" \
		-DCMAKE_CXX_FLAGS="-funique-internal-linkage-names -fbasic-block-sections=labels" \
		-DCMAKE_INSTALL_PREFIX=$(PWD)/install.dir/labels
	cd build.dir/labels && ninja install -j $(shell nproc)
	touch .labels

.instrumented: .trunk 
	mkdir -p build.dir/instrumented
	mkdir -p install.dir/instrumented
	cd build.dir/instrumented && cmake -G Ninja $(LLVM) \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_TARGETS_TO_BUILD=X86 \
		-DLLVM_OPTIMIZED_TABLEGEN=On \
		-DCMAKE_C_COMPILER=$(TRUNK)/clang \
		-DCMAKE_CXX_COMPILER=$(TRUNK)/clang++ \
		-DLLVM_ENABLE_PROJECTS="clang;lld" \
		-DLLVM_USE_LINKER=lld \
		-DLLVM_BUILD_INSTRUMENTED=ON \
		-DCMAKE_INSTALL_PREFIX=$(PWD)/install.dir/instrumented
	cd build.dir/instrumented && ninja install -j $(shell nproc)
	touch .instrumented

bench-labels: .labels
	mkdir -p bench.dir/labels
	cd bench.dir/labels && cmake -G Ninja $(LLVM) \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_TARGETS_TO_BUILD=X86 \
		-DLLVM_OPTIMIZED_TABLEGEN=On \
		-DCMAKE_C_COMPILER=$(LABELS)/clang \
		-DCMAKE_CXX_COMPILER=$(LABELS)/clang++ \
		-DLLVM_ENABLE_PROJECTS="clang;lld" \
		-DLLVM_USE_LINKER=lld 
	cd bench.dir/labels && (ninja -t commands | head -100 > ./perf_commands.sh)
	cd bench.dir/labels && chmod +x ./perf_commands.sh
	cd bench.dir/labels && (perf record -e cycles:u -j any,u -- ./perf_commands.sh)

bench-instrumented: .instrumented
	mkdir -p bench.dir/instrumented
	cd bench.dir/instrumented && cmake -G Ninja $(LLVM) \
    	-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_TARGETS_TO_BUILD=X86 \
		-DLLVM_OPTIMIZED_TABLEGEN=On \
		-DCMAKE_C_COMPILER=$(INSTRUMENTED)/clang \
		-DCMAKE_CXX_COMPILER=$(INSTRUMENTED)/clang++ \
		-DLLVM_ENABLE_PROJECTS="clang" \
		-DLLVM_USE_LINKER=lld 
	cd bench.dir/instrumented && ninja clang 

%.create_llvm_prof: 
	cd $(PWD)/bench.dir/$(basename $@) && $(AUTOFDO)/create_llvm_prof --format=propeller \
		--binary=$(PWD)/install.dir/$(basename $@)/bin/clang-$(CLANG_VERSION) \
		--profile=perf.data --out=cluster.txt  --propeller_symorder=symorder.txt

merge_prof:
	cd $(INSTRUMENTED_PROF) && $(TRUNK)/llvm-profdata merge -output=clang.profdata *

.pgo-opt-clang:
	mkdir -p build.dir/pgo-opt-clang
	mkdir -p install.dir/pgo-opt-clang
	cd build.dir/pgo-opt-clang && cmake -G Ninja $(LLVM) \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_TARGETS_TO_BUILD=X86 \
		-DLLVM_OPTIMIZED_TABLEGEN=On \
		-DCMAKE_C_COMPILER=$(TRUNK)/clang \
		-DCMAKE_CXX_COMPILER=$(TRUNK)/clang++ \
		-DLLVM_ENABLE_PROJECTS="clang;lld" \
		-DLLVM_USE_LINKER=lld \
		-DLLVM_ENABLE_LTO=Thin  \
		-DLLVM_PROFDATA_FILE=$(INSTRUMENTED_PROF)/clang.profdata \
		-DCMAKE_INSTALL_PREFIX=$(PWD)/install.dir/pgo-opt-clang
	cd build.dir/pgo-opt-clang && ninja install -j $(shell nproc)
	touch .pgo-opt-clang

.propeller-opt-clang:
	mkdir -p build.dir/propeller-opt-clang
	mkdir -p install.dir/propeller-opt-clang
	cd build.dir/propeller-opt-clang && cmake -G Ninja $(LLVM) \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_TARGETS_TO_BUILD=X86 \
		-DLLVM_OPTIMIZED_TABLEGEN=On \
		-DCMAKE_C_COMPILER=$(TRUNK)/clang \
		-DCMAKE_CXX_COMPILER=$(TRUNK)/clang++ \
		-DLLVM_ENABLE_PROJECTS="clang;lld" \
		-DLLVM_USE_LINKER=lld \
		-DCMAKE_C_FLAGS="-funique-internal-linkage-names -fbasic-block-sections=list=$(LABELS_PROF)/cluster.txt" \
		-DCMAKE_CXX_FLAGS="-funique-internal-linkage-names -fbasic-block-sections=list=$(LABELS_PROF)/cluster.txt" \
		-DCMAKE_EXE_LINKER_FLAGS="-Wl,--symbol-ordering-file=$(LABELS_PROF)/symorder.txt -Wl,--no-warn-symbol-ordering -fuse-ld=lld" \
  		-DCMAKE_SHARED_LINKER_FLAGS="-Wl,--symbol-ordering-file=$(LABELS_PROF)/symorder.txt -Wl,--no-warn-symbol-ordering -fuse-ld=lld" \
  		-DCMAKE_MODULE_LINKER_FLAGS="-Wl,--symbol-ordering-file=$(LABELS_PROF)/symorder.txt -Wl,--no-warn-symbol-ordering -fuse-ld=lld" \
		-DCMAKE_INSTALL_PREFIX=$(PWD)/install.dir/propeller-opt-clang
	cd build.dir/propeller-opt-clang && ninja install -j $(shell nproc)
	touch .propeller-opt-clang


.pgo-labels: .trunk 
	mkdir -p build.dir/pgo-labels
	mkdir -p install.dir/pgo-labels
	cd build.dir/pgo-labels && cmake -G Ninja $(LLVM) \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_TARGETS_TO_BUILD=X86 \
		-DLLVM_OPTIMIZED_TABLEGEN=On \
		-DCMAKE_C_COMPILER=$(TRUNK)/clang \
		-DCMAKE_CXX_COMPILER=$(TRUNK)/clang++ \
		-DLLVM_ENABLE_PROJECTS="clang;lld" \
		-DLLVM_USE_LINKER=lld \
		-DLLVM_ENABLE_LTO=Thin  \
		-DLLVM_PROFDATA_FILE=$(INSTRUMENTED_PROF)/clang.profdata \
		-DCMAKE_C_FLAGS="-funique-internal-linkage-names -fbasic-block-sections=labels" \
		-DCMAKE_CXX_FLAGS="-funique-internal-linkage-names -fbasic-block-sections=labels" \
		-DCMAKE_EXE_LINKER_FLAGS="-Wl,--lto-basic-block-sections=labels -fuse-ld=lld" \
  		-DCMAKE_SHARED_LINKER_FLAGS="-Wl,--lto-basic-block-sections=labels -fuse-ld=lld" \
  		-DCMAKE_MODULE_LINKER_FLAGS="-Wl,--lto-basic-block-sections=labels -fuse-ld=lld" \
		-DCMAKE_INSTALL_PREFIX=$(PWD)/install.dir/pgo-labels
	cd build.dir/pgo-labels && ninja install -j $(shell nproc)
	touch .pgo-labels


bench-pgo-labels: .pgo-labels
	mkdir -p bench.dir/pgo-labels
	cd bench.dir/pgo-labels && cmake -G Ninja $(LLVM) \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_TARGETS_TO_BUILD=X86 \
		-DLLVM_OPTIMIZED_TABLEGEN=On \
		-DCMAKE_C_COMPILER=$(PGO_LABELS)/clang \
		-DCMAKE_CXX_COMPILER=$(PGO_LABELS)/clang++ \
		-DLLVM_ENABLE_PROJECTS="clang;lld" \
		-DLLVM_USE_LINKER=lld 
	cd bench.dir/pgo-labels && (ninja -t commands | head -100 > ./perf_commands.sh)
	cd bench.dir/pgo-labels && chmod +x ./perf_commands.sh
	cd bench.dir/pgo-labels && (perf record -e cycles:u -j any,u -- ./perf_commands.sh)

.pgo-propeller-opt-clang:
	mkdir -p build.dir/pgo-propeller-opt-clang
	mkdir -p install.dir/pgo-propeller-opt-clang
	cd build.dir/pgo-propeller-opt-clang && cmake -G Ninja $(LLVM) \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_TARGETS_TO_BUILD=X86 \
		-DLLVM_OPTIMIZED_TABLEGEN=On \
		-DCMAKE_C_COMPILER=$(TRUNK)/clang \
		-DCMAKE_CXX_COMPILER=$(TRUNK)/clang++ \
		-DLLVM_ENABLE_PROJECTS="clang;lld" \
		-DLLVM_USE_LINKER=lld \
		-DCMAKE_C_FLAGS="-funique-internal-linkage-names -fbasic-block-sections=list=$(PGO_LABELS_PROF)/cluster.txt" \
		-DCMAKE_CXX_FLAGS="-funique-internal-linkage-names -fbasic-block-sections=list=$(PGO_LABELS_PROF)/cluster.txt" \
		-DCMAKE_EXE_LINKER_FLAGS="-Wl,--symbol-ordering-file=$(PGO_LABELS_PROF)/symorder.txt -Wl,--lto-basic-block-sections=$(PGO_LABELS_PROF)/cluster.txt -Wl,--no-warn-symbol-ordering -fuse-ld=lld" \
  		-DCMAKE_SHARED_LINKER_FLAGS="-Wl,--symbol-ordering-file=$(PGO_LABELS_PROF)/symorder.txt -Wl,--lto-basic-block-sections=$(PGO_LABELS_PROF)/cluster.txt -Wl,--no-warn-symbol-ordering -fuse-ld=lld" \
  		-DCMAKE_MODULE_LINKER_FLAGS="-Wl,--symbol-ordering-file=$(PGO_LABELS_PROF)/symorder.txt -Wl,--lto-basic-block-sections=$(PGO_LABELS_PROF)/cluster.txt -Wl,--no-warn-symbol-ordering -fuse-ld=lld" \
		-DLLVM_ENABLE_LTO=Thin  \
		-DLLVM_PROFDATA_FILE=$(INSTRUMENTED_PROF)/clang.profdata \
		-DCMAKE_INSTALL_PREFIX=$(PWD)/install.dir/pgo-propeller-opt-clang
	cd build.dir/pgo-propeller-opt-clang && ninja install -j $(shell nproc)
	touch .pgo-propeller-opt-clang

%.test:
	mkdir -p test.dir/$(basename $@)
	cd test.dir/$(basename $@) && cmake -G Ninja $(LLVM) \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_TARGETS_TO_BUILD=X86 \
		-DLLVM_OPTIMIZED_TABLEGEN=On \
		-DCMAKE_C_COMPILER=$(PWD)/install.dir/$(basename $@)/bin/clang \
		-DCMAKE_CXX_COMPILER=$(PWD)/install.dir/$(basename $@)/bin/clang++ \
		-DLLVM_ENABLE_PROJECTS="clang;lld" \
		-DLLVM_USE_LINKER=lld 
	cd test.dir/$(basename $@) && (ninja -t commands | head -100 > ./perf_commands.sh)
	cd test.dir/$(basename $@) && chmod +x ./perf_commands.sh
	cd test.dir/$(basename $@) && perf stat -o $(PWD)/$(basename $@).txt -r5 -e instructions,cycles,L1-icache-misses,iTLB-misses -- bash ./perf_commands.sh

# This is for directly install 
preinstall:
	apt-get update \
		&& apt-get install -y git ca-certificates \
		&& apt-get install -y build-essential \
		&& apt-get install -y flex bison ninja-build \
		&& apt-get install -y libtool autoconf automake \
		&& DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y gdb gdbserver \
		&& apt-get install -y libelf-dev libssl-dev libtinfo-dev pkg-config \
		&& apt-get install -y linux-tools-common linux-tools-generic linux-tools-`uname -r` 


# For docker build and start

create-container: docker/.build-docker
	$(DOCKER_START) /bin/bash

start: docker/.build-docker
	$(DOCKER) /bin/bash

docker/.build-docker: docker/Dockerfile
	cd docker/ && docker build . --tag propeller
	touch docker/.build-docker
