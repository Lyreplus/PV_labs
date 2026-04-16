TOP := tb_regfile
TB := tb/tb_regfile.sv
WORK := work

VLIB := vlib
VMAP := vmap
VLOG := vlog
VSIM := vsim

DUT_DEFS ?=
VLOG_OPTS ?= +acc $(DUT_DEFS)

.PHONY: all build run sim gui clean

all: sim

build:
	@test -d $(WORK) || $(VLIB) $(WORK)
	$(VMAP) work ./work
	$(VLOG) $(VLOG_OPTS) $(TB)

run:
	$(VSIM) -c work.$(TOP) -do "run"

sim: build run

gui: build
	$(VSIM) work.$(TOP)

clean:
	rm -rf transcript
