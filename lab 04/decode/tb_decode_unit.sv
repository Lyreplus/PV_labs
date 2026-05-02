`timescale 1ns/1ps

module tb_decode_unit;

  // DUT interface
  reg         clk;
  reg         rst_n;
  reg         instr_valid;
  reg  [15:0] instr;
  wire        decode_done;
  wire [3:0]  opcode, rd, rs, imm;
  wire        hazard_stall;

  // Instantiate DUT
  decode_unit dut (
    .clk(clk),
    .rst_n(rst_n),
    .instr_valid(instr_valid),
    .instr(instr),
    .decode_done(decode_done),
    .opcode(opcode),
    .rd(rd),
    .rs(rs),
    .imm(imm),
    .hazard_stall(hazard_stall)
  );

  // Clock generation: 10ns period
  initial clk = 0;
  always #5 clk = ~clk;

  // Directed test sequence
  initial begin
    integer i;

    // Initialize inputs
    rst_n = 0;
    instr_valid = 0;
    instr = 16'h0000;
  
    $display("[%0t] STARTING SIMULATION ...", $time);

    // Apply reset
    #5;
    @(posedge clk);
    rst_n = 1;
    @(posedge clk);
    $display("[%0t] TEST #1: Reset released, outputs should be 0", $time);

    // Decode instruction without hazard
    instr = 16'h1234; // opcode=1, rd=2, rs=3, imm=4
    instr_valid = 1;
    @(posedge clk);
    instr_valid = 0;
    // Wait for decode_done
    repeat (3) @(posedge clk);
    $display("[%0t] TEST #2: decode_done=%b, opcode=%0h, rd=%0h, rs=%0h, imm=%0h",
             $time, decode_done, opcode, rd, rs, imm);

    // Decode instruction with hazard (rs == last_rd)
    instr = 16'h3A20; // opcode=3, rd=A, rs=2 (matches previous rd), imm=0
    instr_valid = 1;
    @(posedge clk);
    instr_valid = 0;
    // Stall should assert
    @(posedge clk);
    $display("[%0t] TEST #3: hazard_stall=%b", $time, hazard_stall);

    // Wait for stall to clear and decode to complete
    repeat (4) @(posedge clk);
    $display("[%0t] TEST #4: decode_done=%b, opcode=%0h, rd=%0h, rs=%0h, imm=%0h",
             $time, decode_done, opcode, rd, rs, imm);

    // Decode instruction after hazard clears
    instr = 16'h4B21; // opcode=4, rd=B, rs=2 (no hazard with last_rd=A), imm=1
    instr_valid = 1;
    @(posedge clk);
    instr_valid = 0;
    repeat (3) @(posedge clk);
    $display("[%0t] TEST #5: decode_done=%b, opcode=%0h, rd=%0h, rs=%0h, imm=%0h",
             $time, decode_done, opcode, rd, rs, imm);

    // Finish
    #20;
    $display("[%0t] TEST COMPLETE.", $time);
    $finish;
  end

  // INSERT ASSERTIONS BELOW

    property PT01_instruction_acceptance;
      @(posedge clk) disable iff (!rst_n)
        instr_valid == 1'b1 |=> !hazard_stall |->  (opcode == $past(instr[15:12]))  &&
                                          (rd     == $past(instr[11:8]))   &&
                                          (rs     == $past(instr[7:4]))    &&
                                          (imm    == $past(instr[3:0]));
    endproperty

    assert property (PT01_instruction_acceptance)
    else $error("PT01: instruction hasn't been accepted or fields haven't been filled with corresponding bits of instr after instr_valid is high and no hazard stall in the same cycle");

    property PT02_decode_latency;
      @(posedge clk) disable iff (!rst_n)
      instr_valid == 1'b1 |=> !hazard_stall |-> ##2 decode_done == 1'b1;
    endproperty

    assert property (PT02_decode_latency)
    else $error("PT02: decode_done hasn't been asserted in cycle N+2 after instruction acceptance");

    property PT03_decode_single_cycle;
      @(posedge clk) disable iff (!rst_n)
        decode_done == 1'b1 |=> decode_done == 1'b0;
    endproperty

    assert property (PT03_decode_single_cycle)
    else $error("PT03: decode_done hasn't endured for only a single cycle");

    property PT04_hazard_occurrence;
      @(posedge clk) disable iff (!rst_n)
      (rd == instr[7:4]) && instr_valid |=> hazard_stall == 1'b1;
    endproperty

    assert property (PT04_hazard_occurrence)
    else $error("PT04: hazard_stall hasn't been asserted when rs matches previous rd");

    property PT05_hazard_current_instruction;
      @(posedge clk) disable iff (!rst_n)
      (rd == instr[7:4]) && instr_valid |=> (opcode != instr[15:12])  &&
                                            (rd     != instr[11:8])   &&
                                            (rs     != instr[7:4])    &&
                                            (imm    != instr[3:0]);
    endproperty
    
    assert property (PT05_hazard_current_instruction)
    else $error("PT05: current instruction fields haven't been blocked from being accepted when hazard_stall is asserted");
    
    property PT06_hazard_decode_done;
      @(posedge clk) disable iff (!rst_n)
      (rd == instr[7:4]) && instr_valid |=> decode_done == 1'b0;
    endproperty

    assert property (PT06_hazard_decode_done)
    else $error("PT06: decode_done has been asserted when hazard occurs");

    property PT07_retain_instruction_during_hazard;
      @(posedge clk) disable iff (!rst_n)
      (hazard_stall == 1'b1) && (instr_valid == 1'b1) |=> (opcode == $past(opcode))  &&
                                                           (rd     == $past(rd))      &&
                                                           (rs     == $past(rs))      &&
                                                           (imm    == $past(imm));
    endproperty

    assert property (PT07_retain_instruction_during_hazard)
    else $error("PT07: decoded fields haven't been retained during hazard stall");

    property PT08_reset_behaviour;
      @(posedge clk) !rst_n |=> (decode_done == 1'b0) &&
                                (opcode == 4'h0)      &&
                                (rd     == 4'h0)      &&
                                (rs     == 4'h0)      &&
                                (imm    == 4'h0)      &&
                                (hazard_stall == 1'b0);
    endproperty

    assert property (PT08_reset_behaviour)
    else $error("PT10: On reset, outputs haven't been initialized to zero or decode_done and hazard_stall haven't been deasserted");
endmodule