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

    // End simulation
    #20;
    $display("[%0t] TEST COMPLETE.", $time);
    $finish;
  end

  // checked against registered PC value with $past

  // concurrent assertions
  // Reset: after a reset cycle, PC must be zero.
  property p_reset_pc_zero;
    @(posedge clk) !rst_n |=> (dut.pc == 8'h00);
  endproperty
  assert property (p_reset_pc_zero)
    else $error("PC not zero after reset");

  // Branch priority: branch_en asserted, PC loads branch_addr.
  property p_branch_priority_load;
    @(posedge clk) disable iff (!rst_n)
      $past(branch_en) |-> (dut.pc == $past(branch_addr));
  endproperty

  assert property (p_branch_priority_load)
    else $error("Branch priority load failed");

  // Branch priority: branch_en is asserted, PC mustnt be old PC + 2.
  property p_branch_priority_not_increment;
    @(posedge clk) disable iff (!rst_n)
      $past(branch_en) |-> (dut.pc != ($past(dut.pc) + 8'd2));
  endproperty

  assert property (p_branch_priority_not_increment)
    else $error("Branch priority not-increment failed");

  // PC increment when pc_en is true and branch_en is false.
  property p_pc_increment;
    @(posedge clk) disable iff (!rst_n)
      ($past(pc_en) && !$past(branch_en)) |-> (dut.pc == ($past(dut.pc) + 8'd2));
  endproperty
  assert property (p_pc_increment)
    else $error("PC increment failed");

  // PC stability when no control signals are asserted.
  property p_pc_hold;
    @(posedge clk) disable iff (!rst_n)
      (!$past(pc_en) && !$past(branch_en)) |-> (dut.pc == $past(dut.pc));
  endproperty

  assert property (p_pc_hold)
    else $error("PC hold failed");

  // Instruction must always match memory at current PC.
  property p_instr_matches_mem;
    @(posedge clk) disable iff (!rst_n)
      (instr == dut.mem[dut.pc]);
  endproperty

  assert property (p_instr_matches_mem)
    else $error("Instruction does not match memory at PC");

  // PC must stay within [0, 255].
  property p_pc_in_range;
    @(posedge clk) disable iff (!rst_n)
      (dut.pc inside {[8'h00:8'hFF]});
  endproperty
  assert property (p_pc_in_range)
    else $error("PC out of range");

endmodule

