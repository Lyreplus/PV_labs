if {![file exists work]} { vlib work }
vmap work ./work

set DUT_DEFS ""
# Example if your DUTs are named regfile_v0..v3:
set DUT_DEFS "+define+DUT0=regfile_v0 +define+DUT1=regfile_v1 +define+DUT2=regfile_v2 +define+DUT3=regfile_v3"

vlog +acc $DUT_DEFS tb/tb_regfile.sv
vsim work.tb_regfile
run -all
