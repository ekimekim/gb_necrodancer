
# avoid implicit rules for clarity
.SUFFIXES: .asm .o .gb
.PHONY: bgb clean tests testroms debug

ASMS := $(wildcard *.asm)
OBJS := $(ASMS:.asm=.o)
DEBUGOBJS := $(addprefix build/debug/,$(OBJS))
RELEASEOBJS := $(addprefix build/release/,$(OBJS))
INCLUDES := $(wildcard include/*.asm)
ASSETS := $(shell find assets/ -type f)
TESTS := $(wildcard tests/*.py)
RGBFIX_ARGS := -C

all: build/release/rom.gb tests/.uptodate

include/palettes.asm: assets/entities.png assets/entities.sprite16.csv assets/entities.sprite8.csv tools/csv_to_assets.py
	python tools/csv_to_assets.py assets/entities.sprite8.csv
	python tools/csv_to_assets.py assets/entities.sprite16.csv --tall

include/assets/.uptodate: $(ASSETS) tools/assets_to_asm.py include/palettes.asm
	python tools/assets_to_asm.py assets/ include/assets/
	touch $@

tests/.uptodate: $(TESTS) tools/unit_test_gen.py $(DEBUGOBJS)
	python tools/unit_test_gen.py .
	touch "$@"

testroms: tests/.uptodate

tests: testroms
	./runtests

build/debug/%.o: %.asm $(INCLUDES) include/assets/.uptodate build/debug
	rgbasm -DDEBUG=1 -i include/ -v -o $@ $<

build/release/%.o: %.asm $(INCLUDES) include/assets/.uptodate build/release
	rgbasm -DDEBUG=0 -i include/ -v -o $@ $<

build/debug/rom.gb: $(DEBUGOBJS)
# note padding with 0x40 = ld b, b = BGB breakpoint
	rgblink -n $(@:.gb=.sym) -o $@ -p 0x40 $^
	rgbfix -v -p 0x40 $(RGBFIX_ARGS) $@

build/release/rom.gb: $(RELEASEOBJS)
	rgblink -n $(@:.gb=.sym) -o $@ $^
	rgbfix -v -p 0 $(RGBFIX_ARGS) $@

build/debug build/release:
	mkdir -p $@

debug: build/debug/rom.gb
	bgb $<

bgb: build/release/rom.gb
	bgb $<

clean:
	rm -f build/*/*.o build/*/rom.sym build/*/rom.gb rom.gb include/assets/.uptodate include/assets/*.asm tests/*/*.{asm,o,sym,gb}

copy: build/release/rom.gb
	copy-rom necrodancer build/release/rom.gb
