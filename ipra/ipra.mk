
CC = $(TRUNK)/clang
CXX = $(TRUNK)/clang++
ENABLE_IPRA =  -mllvm -enable-ipra
NO_IPRA = 
COUNTER = $(PWD)/build.dir/counter

download_bench: source.dir/.snubench source.dir/.dparser source.dir/.vorbis-tools source.dir/.C_FFT

source.dir/.snubench:
	mkdir -p source.dir/
	cd source.dir && wget http://www.cprover.org/goto-cc/examples/binaries/SNU-real-time.tar.gz && tar -xvf ./SNU-real-time.tar.gz
	touch source.dir/.snubench

source.dir/.dparser:
	mkdir -p source.dir/
	cd source.dir && wget https://github.com/jplevyak/dparser/archive/refs/heads/master.zip && unzip ./master.zip && rm ./master.zip
	touch source.dir/.dparser

source.dir/.vorbis-tools:
	mkdir -p source.dir/
	cd source.dir && wget https://github.com/xiph/vorbis-tools/archive/refs/heads/master.zip && unzip ./master.zip && rm ./master.zip
	touch source.dir/.vorbis-tools

source.dir/.C_FFT:
	mkdir -p source.dir/ 
	cd source.dir && wget https://github.com/sunxfancy/C_FFT/archive/refs/heads/master.zip && unzip ./master.zip && rm ./master.zip
	touch source.dir/.C_FFT

build.dir/counter: ipra/counter.go
	mkdir -p build.dir
	cd build.dir && go build ../ipra/counter.go

%.snu-build: source.dir/.snubench
	mkdir -p build.dir/snubench
	cd build.dir/snubench && $(CC) -O1 $(ENABLE_IPRA) -S ../../source.dir/SNU-real-time/$(basename $@).c -o $(basename $@).O1.ipra.S \
	                   && $(CC) -O1 $(NO_IPRA) -S  ../../source.dir/SNU-real-time/$(basename $@).c -o $(basename $@).O1.S
	cd build.dir/snubench && $(CC) -O0 $(ENABLE_IPRA) -S ../../source.dir/SNU-real-time/$(basename $@).c -o $(basename $@).O0.ipra.S \
	                   && $(CC) -O0 $(NO_IPRA) -S  ../../source.dir/SNU-real-time/$(basename $@).c -o $(basename $@).O0.S

%.snu:  %.snu-build  build.dir/counter
	mkdir -p build.dir/snubench
	cd build.dir/snubench && $(COUNTER) < ./$(basename $@).O1.ipra.S > ./$(basename $@).O1.ipra.csv  \
					   && $(COUNTER) < ./$(basename $@).O1.S > ./$(basename $@).O1.csv
	cd build.dir/snubench && $(COUNTER) < ./$(basename $@).O0.ipra.S > ./$(basename $@).O0.ipra.csv  \
					   && $(COUNTER) < ./$(basename $@).O0.S > ./$(basename $@).O0.csv


SNU = adpcm-test.snu bs.snu crc.snu fft1k.snu fibcall.snu fir.snu insertsort.snu jfdctint.snu \
      lms.snu ludcmp.snu matmul.snu minver.snu qsort-exam.snu qurt.snu select.snu sqrt.snu

snubench: $(SNU)



dparser.ipra:
	mkdir -p build.dir/dparser.ipra
	cd build.dir/dparser.ipra && cmake ../../source.dir/dparser-master -G Ninja \
	 	-DCMAKE_C_COMPILER=$(CC) \
		-DCMAKE_CXX_COMPILER=$(CXX) \
		-DCMAKE_C_FLAGS="-fno-inline-functions -flto=full -fuse-ld=lld" \
		-DCMAKE_CXX_FLAGS="-fno-inline-functions -flto=full -fuse-ld=lld" \
		-DCMAKE_EXE_LINKER_FLAGS="-Wl,-mllvm -Wl,-enable-ipra" \
		-DCMAKE_SHARED_LINKER_FLAGS="-Wl,-mllvm -Wl,-enable-ipra" \
		-DCMAKE_MODULE_LINKER_FLAGS="-Wl,-mllvm -Wl,-enable-ipra" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=../../install.dir/dparser.ipra
	cd build.dir/dparser.ipra && ninja install


dparser:
	mkdir -p build.dir/dparser
	cd build.dir/dparser && cmake ../../source.dir/dparser-master -G Ninja \
	 	-DCMAKE_C_COMPILER=$(CC) \
		-DCMAKE_CXX_COMPILER=$(CXX) \
		-DCMAKE_C_FLAGS="-fno-inline-functions -flto=full -fuse-ld=lld" \
		-DCMAKE_CXX_FLAGS="-fno-inline-functions -flto=full -fuse-ld=lld" \
		-DCMAKE_EXE_LINKER_FLAGS="-flto=full  -fuse-ld=lld" \
		-DCMAKE_SHARED_LINKER_FLAGS="-flto=full  -fuse-ld=lld" \
		-DCMAKE_MODULE_LINKER_FLAGS="-flto=full  -fuse-ld=lld" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=../../install.dir/dparser
	cd build.dir/dparser && ninja install


dparser-bench:
	cd build.dir/ && perf stat -o no-ipra-c.txt -r5 -e instructions,cycles,L1-icache-misses,iTLB-misses -- ./dparser/make_dparser -o test.c  ../source.dir/dparser-master/tests/ansic.test.g
	cd build.dir/ && perf stat -o ipra-c.txt -r5 -e instructions,cycles,L1-icache-misses,iTLB-misses -- ./dparser.ipra/make_dparser -o test.c  ../source.dir/dparser-master/tests/ansic.test.g
	cd build.dir/ && perf stat -o no-ipra-p.txt -r5 -e instructions,cycles,L1-icache-misses,iTLB-misses -- ./dparser/make_dparser -o test.c  ../source.dir/dparser-master/tests/python.test.g
	cd build.dir/ && perf stat -o ipra-p.txt -r5 -e instructions,cycles,L1-icache-misses,iTLB-misses -- ./dparser.ipra/make_dparser -o test.c  ../source.dir/dparser-master/tests/python.test.g