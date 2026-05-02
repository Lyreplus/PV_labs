`timescale 1ns/1ps

module tb_fetch_unit;

  // DUT interface signals
  reg         clk;
  reg         rst_n;
  reg         pc_en;
  reg         branch_en;
  reg  [7:0]  branch_addr;
  wire [15:0] instr;

  // Instantiate DUT
  fetch_unit dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .pc_en      (pc_en),
    .branch_en  (branch_en),
    .branch_addr(branch_addr),
    .instr      (instr)
  );

  // Clock generation: 10ns period
  initial clk = 0;
  always #5 clk = ~clk;

  // Directed test sequence
  initial begin
    integer i;
  
    // Initialize inputs
    clk         = 0;
    rst_n       = 0;
    pc_en       = 0;
    branch_en   = 0;
    branch_addr = 8'h00;

    $display("[%0t] STARTING SIMULATION ...", $time);

    // Apply reset
    #5;
    @(posedge clk);
    rst_n = 1;
    @(posedge clk);
    $display("[%0t] TEST #1: Reset released, pc should be 0, instr=%0d", $time, instr);

    // Sequential pc increments
    pc_en = 1;
    for (i = 1; i <= 4; i = i + 1) begin
      @(posedge clk);
      $display("[%0t] TEST #%1d: pc increment, pc=%0h, instr=%0d", $time, i, dut.pc, instr);
    end
    pc_en = 0;

    // Branch test
    branch_addr = 8'h10;
    branch_en   = 1;
    @(posedge clk);
    branch_en   = 0;
    $display("[%0t] TEST #5: Branch taken to addr=0x%0h, pc=%0h, instr=%0d", $time, branch_addr, dut.pc, instr);

    // Branch priority over pc_en
    branch_addr = 8'h20;
    pc_en       = 1;
    branch_en   = 1;
    @(posedge clk);
    branch_en   = 0;
    pc_en       = 0;
    $display("[%0t] TEST #6: Branch priority test, pc should be 0x20, instr=%0d", $time, instr);

    // No control signals
    @(posedge clk);
    $display("[%0t] TEST #7: No control active, pc=%0h, instr=%0d", $time, dut.pc, instr);

    // sequential enable signal
    pc_en = 1;
    @(posedge clk)
    $display("[%0t] TEST #8: Sequential read, before: pc=%0h, instr=%0d", $time, dut.pc, instr);
    @(posedge clk)
    pc_en = 0;
    $display("[%0t] TEST #8: Sequential read, after: pc=%0h, instr=%0d", $time, dut.pc, instr);

    // End simulation
    #20;
    $display("[%0t] TEST COMPLETE.", $time);
    $finish;
  end

  // INSERT ASSERTIONS BELOW

  // used $error because we have design bugs that require investigation. Added value of signals to better debug.
  // added disable iff (!rst_n) also for assertions 5 & 6 because we have to consider the first reset edge, when signals pc/instr are still X, because system verilog samples assertions before nonblocking updates

  // Assertion 1

    property reset_pc_zero;
        @(posedge clk) !rst_n |=> (dut.pc == 8'h00);
    endproperty

    assert property (reset_pc_zero)
    else $error("On reset PC hasn't gone to zero: pc=%0h", dut.pc);

  // Assertion 2

    property branch_precedence_over_pc_en;
        @(posedge clk) 
        disable iff (!rst_n)
        branch_en |=> (dut.pc == $past(branch_addr));
    endproperty

    assert property (branch_precedence_over_pc_en)
    else $error("No precedence for branch_en over pc_en");

  // Assertion 3

    property pc_en_increment;
        @(posedge clk)
        disable iff (!rst_n)
        (pc_en && !branch_en) |=> dut.pc == ($past(dut.pc) + 8'd2);
    endproperty
    
    assert property (pc_en_increment)
    else $error("PC hasn't incremented by 2 on pc_en && !branch_en. pc = %0h, Past pc = %0h", dut.pc, $past(dut.pc));

  // Assertion 4

    property pc_stability;
        @(posedge clk)
        disable iff (!rst_n)
        (!pc_en && !branch_en) |=> dut.pc == ($past(dut.pc));
    endproperty

    assert property (pc_stability)
    else $error("PC hasn't hold its value on !pc_en && !branch_en. pc = %0h, Past pc = %0h", dut.pc, $past(dut.pc));

  // Assertion 5

    property instruction_consistency;
        @(posedge clk)
        disable iff (!rst_n)
        (instr == dut.mem[dut.pc]);
    endproperty

    assert property (instruction_consistency)
    else $error("instruction isn't equal to mem[pc]. Instr = %0h, Mem[pc] = %0h", instr, dut.mem[dut.pc]);

  // Assertion 6

    property pc_range_safety;
        @(posedge clk)
        disable iff (!rst_n)
        (dut.pc inside {[8'h00:8'hFF]});
    endproperty

    assert property (pc_range_safety)
    else $error("PC out of range. PC = %0h", dut.pc);

endmodule