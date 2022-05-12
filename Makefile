INSIDE_DOCKER=$(shell [ -f /.dockerenv ] && echo 1 || echo 0 )

PWD = $(shell pwd)
ifeq ($(INSIDE_DOCKER), 0)
	DOCKER = docker run -it --rm --volume="$(PWD):/home/propeller/src" propeller 
	DOCKER_START = docker run -it --volume="$(PWD):/home/propeller/src" propeller 
else
	DOCKER = 
endif


CLANG_VERSION=12

PWD=$(shell pwd)
LLVM=$(PWD)/source.dir/llvm-project/llvm
TRUNK=$(PWD)/install.dir/trunk/bin
LABELS=$(PWD)/install.dir/labels/bin
INSTRUMENTED=$(PWD)/install.dir/instrumented/bin
AUTOFDO=$(PWD)/source.dir/autofdo

build: .autofdo .baseline .labels .instrumented

bench: 
	make bench-labels
	make bench-instrumented

source.dir/.llvm-project: 
	mkdir -p source.dir/
	cd source.dir/ && git clone --depth 1 --single-branch --branch release/${CLANG_VERSION}.x https://github.com/llvm/llvm-project.git
	touch source.dir/.llvm-project
	
.trunk: source.dir/.llvm-project build.dir install.dir
	mkdir -p build.dir/trunk 
	mkdir -p install.dir/trunk
	cd build.dir/trunk && cmake -G Ninja $(LLVM) \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_TARGETS_TO_BUILD=X86 \
		-DLLVM_ENABLE_PROJECTS="clang;lld;compiler-rt" \
		-DCOMPILER_RT_BUILD_SANITIZERS=OFF \
		-DCOMPILER_RT_BUILD_XRAY=OFF \
		-DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
		-DCMAKE_INSTALL_PREFIX=$(PWD)/install.dir/trunk
	cd build.dir/trunk && ninja install -j $(shell nproc)
	touch .trunk

source.dir/.autofdo: 
	mkdir -p source.dir/
	cd source.dir/ && git clone  --depth 1 --single-branch --branch propeller --recursive https://github.com/google/autofdo.git
	touch source.dir/.autofdo

.autofdo: source.dir/.autofdo .trunk
	cd source.dir/autofdo && \
		aclocal -I . && autoheader && autoconf && automake --add-missing -c && \
		./configure --with-llvm=$(TRUNK)/llvm-config
	CC=$(TRUNK)/clang CXX=$(TRUNK)/clang++ cd source.dir/autofdo && make
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

bench-labels: 
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

bench-instrumented: 
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

create_llvm_prof:
	cd bench.dir/labels && $(AUTOFDO)/create_llvm_prof --format=propeller \
		--binary=$(LABELS)/clang-$(CLANG_VERSION) \
		--profile=perf.data --out=cluster.txt  --propeller_symorder=symorder.txt

%.dir:
	mkdir -p $@

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