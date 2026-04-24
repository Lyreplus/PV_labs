vsim -do run.do
mv transcript transcript_v0
f="alu_4bit_tb.sv"
for i in {0..4}; do 
    j=$((i+1))
    sed -i "s/alu_4bit_v${i} dut (/alu_4bit_v${j} dut (/" alu_4bit_tb.sv; 
    vsim -do run.do
    mv transcript "transcript_v${j}"
done
