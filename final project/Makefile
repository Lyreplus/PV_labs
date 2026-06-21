UNIT = gcd
TESTBENCH = testbench
VFLAGS = +acc +cover
SEED ?= 12345

.PHONY: all setup run report report_html clean

all: setup run report report_html

setup:
	vlib work
	vmap work ./work
	vlog $(VFLAGS) $(UNIT).sv
	vlog $(VFLAGS) $(TESTBENCH)_$(UNIT).sv

run: setup
	vsim -c -coverage work.$(TESTBENCH)_$(UNIT) +UVM_VERBOSITY=UVM_LOW -sv_seed $(SEED) -do "coverage save -onexit test1.ucb; run -all; quit -f"

report: 
	vcover report -details -output gcd_cov_report.txt gcd_cov.ucdb
	vcover report gcd_cov.ucdb >> gcd_cov_report.txt

report_html:
	vcover report -details -html -output gcd_cov_html gcd_cov.ucdb
	vcover report gcd_cov.ucdb >> gcd_cov_report_html.txt

clean:
	rm -rf work transcript vsim.wlf modelsim.ini coverage_report *.ucb gcd_cov_report.txt gcd_cov_html gcd_cov.ucdb gcd_cov_report_html.txt