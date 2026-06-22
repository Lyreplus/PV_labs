UNIT = gcd
TESTBENCH = testbench
VFLAGS = +acc +cover
SEED ?= 12345
TEST ?= gcd_random_test
UCDB_OUT ?= gcd_cov.ucdb

.PHONY: all setup run report report_html clean

all: setup run report report_html

setup:
	vlib work
	vmap work ./work
	vlog $(VFLAGS) $(UNIT).sv
	vlog +acc $(TESTBENCH)_$(UNIT).sv

run_all: setup 
	$(MAKE) run TEST=gcd_bringup_test UCDB_OUT=bringup.ucdb
	$(MAKE) run TEST=gcd_directed_test UCDB_OUT=directed.ucdb
	$(MAKE) run TEST=gcd_random_test UCDB_OUT=random.ucdb
	vcover merge gcd_cov.ucdb bringup.ucdb directed.ucdb random.ucdb

run: setup
	vsim -c -coverage work.$(TESTBENCH)_$(UNIT) +UVM_VERBOSITY=UVM_LOW +UVM_TESTNAME=$(TEST) -sv_seed $(SEED) -do "coverage save -onexit $(UCDB_OUT); run -all; quit -f"

report: 
	vcover report -details -output gcd_cov_report.txt gcd_cov.ucdb
	vcover report gcd_cov.ucdb >> gcd_cov_report.txt

report_html:
	vcover report -details -html -output gcd_cov_html gcd_cov.ucdb
	vcover report gcd_cov.ucdb >> gcd_cov_report_html.txt

clean:
	rm -rf work transcript vsim.wlf modelsim.ini coverage_report *.ucb gcd_cov_report.txt gcd_cov_html gcd_cov.ucdb gcd_cov_report_html.txt bringup.ucdb directed.ucdb random.ucdb