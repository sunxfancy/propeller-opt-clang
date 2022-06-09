
CC = $(TRUNK)/clang
ENABLE_IPRA = -mllvm -enable-ipra -O3
NO_IPRA = -O3
COUNTER = $(PWD)/build.dir/counter
source.dir/.snubench:
	mkdir -p source.dir/
	cd source.dir && wget http://www.cprover.org/goto-cc/examples/binaries/SNU-real-time.tar.gz && tar -xvf ./SNU-real-time.tar.gz
	touch source.dir/.snubench

adpcm: source.dir/.snubench
	mkdir -p build.dir/adpcm
	cd build.dir/adpcm && $(CC) $(ENABLE_IPRA) -S ../../source.dir/SNU-real-time/adpcm-test.c -o adpcm.ipra.S \
	                   && $(CC) $(NO_IPRA) -S  ../../source.dir/SNU-real-time/adpcm-test.c -o adpcm.S
	cd build.dir/adpcm && $(CC) $(ENABLE_IPRA) ../../source.dir/SNU-real-time/adpcm-test.c -o adpcm.ipra \
	                   && $(CC) $(NO_IPRA) ../../source.dir/SNU-real-time/adpcm-test.c -o adpcm


counter:
	mkdir -p build.dir
	cd build.dir && go build ../ipra/counter.go

adpcm-report:
	mkdir -p build.dir/adpcm
	cd build.dir/adpcm && $(COUNTER) < ./adpcm.ipra.S > ./adpcm.ipra.csv  \
					   && $(COUNTER) < ./adpcm.S > ./adpcm.csv