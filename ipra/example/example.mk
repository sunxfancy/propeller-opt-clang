

FDO-example:
	mkdir -p build.dir/example
	cd build.dir/example && $(FDO) config ../../ipra/example -DCMAKE_BUILD_TYPE=Release && \
		$(FDO) build --pgo && \
		$(FDO) test --pgo && \
		$(FDO) opt --pgo


example:
	mkdir -p build.dir/example
	cd build.dir/example && $(CC) -O3 -S $(PWD)/ipra/example/main.c -o no_ipra.S
	cd build.dir/example && $(CC) -O3 -S $(ENABLE_IPRA) $(PWD)/ipra/example/main.c -o ipra.S
	cd build.dir/example && $(CC) -O3 -S -fprofile-instr-use=instrumented/PGO.profdata $(PWD)/ipra/example/main.c -o no_ipra_pgo.S
	cd build.dir/example && $(CC) -O3 -S $(ENABLE_IPRA) -fprofile-instr-use=instrumented/PGO.profdata $(PWD)/ipra/example/main.c -o ipra_pgo.S

	cd build.dir/example && $(CC) -O3 -S $(PWD)/ipra/example/main2.c -o no_ipra2.S
	cd build.dir/example && $(CC) -O3 -S $(ENABLE_IPRA) $(PWD)/ipra/example/main2.c -o ipra2.S
	cd build.dir/example && $(CC) -O3 -S -fprofile-instr-use=instrumented/PGO.profdata $(PWD)/ipra/example/main2.c -o no_ipra_pgo2.S
	cd build.dir/example && $(CC) -O3 -S $(ENABLE_IPRA) -fprofile-instr-use=instrumented/PGO.profdata $(PWD)/ipra/example/main2.c -o ipra_pgo2.S

count-static:
	mkdir -p build.dir/count
	cd build.dir/count && $(CC) -O3 -S $(PWD)/ipra/example/main.c -o no_ipra.S
	cd build.dir/count && $(COUNTER) < no_ipra.S 

count:
	cd build.dir/example && $(CC) -O3 -S -fprofile-instr-use=instrumented/PGO.profdata $(PWD)/ipra/example/main.c -o no_ipra_pgo.S
	cd build.dir/example && $(CC) -O3 -S $(ENABLE_IPRA) -fprofile-instr-use=instrumented/PGO.profdata $(PWD)/ipra/example/main.c -o ipra_pgo.S