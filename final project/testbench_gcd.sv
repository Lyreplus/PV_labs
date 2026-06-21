//timescale
`timescale 1ns/1ps
`include "uvm_macros.svh"

package loc_constants;
    localparam int unsigned WIDTH = 16;
endpackage

import loc_constants::*;

// Interface
interface gcd_if(input logic clk, input logic rst_n);
    // input
    logic               in_valid;
    logic               in_ready;
    logic [WIDTH-1:0]   a_in;     
    logic [WIDTH-1:0]   b_in;

    // output
    logic               out_valid;
    logic               out_ready;
    logic [WIDTH-1:0]   gcd_out;
    
    clocking cb @(posedge clk);
        default input #1step output #1ns;

        input  in_ready, out_valid, gcd_out;
        output in_valid, a_in, b_in, out_ready;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step;
        input in_valid, in_ready, a_in, b_in, out_valid, out_ready, gcd_out;
    endclocking

    // time (worst case) + 10 for handshake margin
    localparam int unsigned MAX_TIMEOUT = (1 << WIDTH) + 10;

    always @(posedge clk) begin
        // Trigger the timer whenever a new transaction is accepted
        if (rst_n && in_valid && in_ready) begin
            fork
                begin
                    int count;
                    count = 0;
                    // Count up until the DUT finishes, resets, or times out
                    while (count <= MAX_TIMEOUT) begin
                        @(posedge clk);
                        if (out_valid || !rst_n) break; 
                        count++;
                    end
                    
                    // If the loop finished and out_valid never fired, we have a hang
                    if (count > MAX_TIMEOUT) begin
                        $error("[TIMEOUT] DUT hung! Exceeded max theoretical cycles (%0d)", MAX_TIMEOUT);
                    end
                end
            join_none
        end
    end

    // REQ 6,7,8,16 reset behavior
    property p_reset_behavior;
        @(posedge clk) !rst_n |=> (in_ready == 1'b1 && out_valid == 1'b0 && gcd_out == '0);
    endproperty

    assert_reset_behavior: assert property(p_reset_behavior) else $error("RESET VIOLATION: Signals did not default to IDLE state!");

    // REQ 9 handshake protocol
    property p_valid_no_drop(valid, ready);
        @(posedge clk) disable iff (!rst_n)
        (valid && !ready) |=> valid;
    endproperty

    assert_in_valid_no_drop: assert property(p_valid_no_drop(in_valid, in_ready)) 
        else $error("PROTOCOL VIOLATION: in_valid dropped before in_ready!");
    assert_out_valid_no_drop: assert property(p_valid_no_drop(out_valid, out_ready))
        else $error("PROTOCOL VIOLATION: out_valid dropped before out_ready!");

    // REQ 12 output stability
    property p_output_stable;
        @(posedge clk) disable iff (!rst_n || $isunknown(out_valid) || $isunknown(out_ready) || $isunknown(gcd_out))
        (out_valid && !out_ready) |=> (out_valid && $stable(gcd_out));
    endproperty

    assert_output_stable: assert property(p_output_stable)
        else $error("PROTOCOL VIOLATION: gcd_out changed while stalled!");

    // REQ 13 FSM start
    property p_in_ready_drop;
        @(posedge clk) disable iff (!rst_n)
        (in_valid && in_ready) |=> (!in_ready);
    endproperty
    assert_in_ready_drop: assert property(p_in_ready_drop)
        else $error("FSM VIOLATION: in_ready did not drop after input handshake!");

    // REQ 15 FSM to idle
    property p_out_valid_drop;
        @(posedge clk) disable iff (!rst_n)
        (out_valid && out_ready) |=> (!out_valid);
    endproperty

    assert_out_valid_drop: assert property(p_out_valid_drop)
        else $error("FSM VIOLATION: out_valid did not drop after output handshake!");   
    
    // REQ 18 input stability
    property p_input_stable_when_stalled;
        @(posedge clk) disable iff (!rst_n || $isunknown(in_ready) || $isunknown(in_valid) || $isunknown(a_in) || $isunknown(b_in))
        (in_valid && !in_ready) |=> (in_valid && $stable(a_in) && $stable(b_in));
    endproperty

    assert_input_stable: assert property(p_input_stable_when_stalled)
        else $error("PROTOCOL VIOLATION: in_valid dropped or input operands changed while stalled!");


    property p_no_infinite_hang;
        @(posedge clk) disable iff (!rst_n || $isunknown(in_valid) || $isunknown(out_ready))
        (in_valid && in_ready) |=> ##[1:MAX_TIMEOUT] out_valid;
    endproperty

    assert_no_infinite_hang: assert property(p_no_infinite_hang)
        else $error("TIMEOUT: Module exceeded maximum cycles without asserting out_valid!");
endinterface

package gcd_package;
    import loc_constants::*;
    import uvm_pkg::*;


    // Sequence Item (transaction)
    class gcd_sequence_item extends uvm_sequence_item;
        `uvm_object_utils(gcd_sequence_item)

        rand bit [15:0] a;
        rand bit [15:0] b;
        
        rand bit out_ready_delay; 

        bit [15:0] gcd_out;

        constraint c_ready_delay {
            out_ready_delay dist {0 := 80, 1 := 20}; // mostly ready immediately, sometimes stalled
        }

        function new(string name = "gcd_sequence_item");
            super.new(name);
        endfunction

        virtual function string convert2string();
            return $sformatf("A: %0d, B: %0d, OUT_DELAY: %0d | GCD_OUT: %0d", a, b, out_ready_delay, gcd_out);
        endfunction
    endclass

    // Sequences
    // Bring up sequence
    class gcd_bringup_seq extends uvm_sequence #(gcd_sequence_item);
        `uvm_object_utils(gcd_bringup_seq)

        function new(string name = "gcd_bringup_seq");
            super.new(name);
        endfunction

        virtual task body();
            `uvm_info("SEQ", "Executing bring up sequence", UVM_LOW)

            req = gcd_sequence_item::type_id::create("req");
            start_item(req);
            if (!req.randomize() with { a == 15; b == 5; out_ready_delay == 0; }) begin
                `uvm_error("SEQ", "Randomization failed for bring-up")
            end
            finish_item(req);
        endtask
    endclass

    // Directed Edge Case Sequences
    class gcd_directed_edge_case_seq extends uvm_sequence #(gcd_sequence_item);
        `uvm_object_utils(gcd_directed_edge_case_seq)

        function new(string name = "gcd_directed_edge_case_seq");
            super.new(name);
        endfunction

        virtual task body();
            `uvm_info("SEQ", "Executing directed edge case sequence", UVM_LOW)

            send_directed_item(0, 0); // GCD(0, 0)

            send_directed_item(18, 0); //GCD(18, 0), A != 0, B = 0

            send_directed_item(0, 24); //GCD(0, 24), A = 0, B != 0

            send_directed_item(27, 27); //GCD(27, 27), A = B

            // Max values
            send_directed_item((1 << WIDTH) - 1, 5); //GCD(WIDTH-1, 5), A = MAX, B != 0
            send_directed_item(5, (1 << WIDTH) - 1); //GCD(5, WIDTH-1), A != 0, B = MAX
            send_directed_item((1 << WIDTH) - 1, (1 << WIDTH) - 1); //GCD(WIDTH-1, WIDTH-1), A = MAX, B = MAX

        endtask

        task send_directed_item(bit [WIDTH-1:0] val_a, bit [WIDTH-1:0] val_b);
            req = gcd_sequence_item::type_id::create("req");
            start_item(req);
            if (!req.randomize() with { a == val_a; b == val_b; }) begin
                `uvm_error("SEQ", "Randomization failed for directed item")
            end
            finish_item(req);
        endtask
    endclass

    // Constrained Random Sequences
    class gcd_random_seq extends uvm_sequence #(gcd_sequence_item);
        `uvm_object_utils(gcd_random_seq)

        rand int number_transactions;

        constraint c_number_of_transactions {
            number_transactions inside {[250:500]}; // rand between 250 and 500
        }

        function new(string name = "gcd_random_seq");
            super.new(name);
        endfunction

        task body();
            if (!randomize()) begin
                `uvm_error("SEQ", "Randomization failed for number of transactions")
            end
            
            `uvm_info("SEQ", $sformatf("Executing Random Sequence with %0d transactions", number_transactions), UVM_LOW)

            for (int i = 0; i < number_transactions; i++) begin
                req = gcd_sequence_item::type_id::create("req");
                start_item(req);
                if (!req.randomize()) begin
                    `uvm_error("SEQ", "Randomization failed for transaction")
                end
                finish_item(req);
            end
        endtask
    endclass

    // Sequencer
    class gcd_sequencer extends uvm_sequencer #(gcd_sequence_item);
        `uvm_component_utils(gcd_sequencer)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    // Driver
    class gcd_driver extends uvm_driver #(gcd_sequence_item);
        `uvm_component_utils(gcd_driver)

        virtual gcd_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gcd_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("No virtual interface in DRV", {"Virtual interface not set for: ", get_full_name(), ".vif"});
            end 
        endfunction

        task run_phase(uvm_phase phase);
            gcd_sequence_item tr;

            vif.cb.in_valid <= 1'b0;
            vif.cb.out_ready <= 1'b1;
            vif.cb.a_in <= '0;
            vif.cb.b_in <= '0;
            
            forever begin
                seq_item_port.get_next_item(tr);

                // drive inputs
                @(vif.cb)
                vif.cb.a_in <= tr.a;
                vif.cb.b_in <= tr.b;
                vif.cb.in_valid <= 1'b1;

                // wait input handshake
                do begin
                    @(vif.cb);
                end while (vif.cb.in_ready !== 1'b1); 


                vif.cb.in_valid <= 1'b0;

                // output handshake
                if (tr.out_ready_delay > 0) begin
                    repeat (tr.out_ready_delay) @(vif.cb);
                end

                vif.cb.out_ready <= 1'b1;

                do begin
                    @(vif.cb);
                end while (vif.cb.out_valid !== 1'b1);

                tr.gcd_out = vif.cb.gcd_out;

                vif.cb.out_ready <= 1'b0;

                seq_item_port.item_done();
            end
        endtask
    endclass

    // Monitor
    class gcd_monitor extends uvm_monitor;
        `uvm_component_utils(gcd_monitor)

        virtual gcd_if vif;
        uvm_analysis_port #(gcd_sequence_item) analysis_port;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            analysis_port = new("analysis_port", this);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gcd_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("No virtual interface in MON", {"Virtual interface not set for: ", get_full_name(), ".vif"});
            end
        endfunction

        task run_phase(uvm_phase phase);
            gcd_sequence_item tr;

            forever begin
                tr = gcd_sequence_item::type_id::create("tr", this);

                do begin
                    @(vif.mon_cb);
                end while (!(vif.mon_cb.in_valid === 1'b1 && vif.mon_cb.in_ready === 1'b1));

                if ($isunknown(vif.mon_cb.a_in) || $isunknown(vif.mon_cb.b_in)) begin
                    `uvm_error("MON", "Unknown X/Z value detected on a and b input operands!")
                end

                tr.a = vif.mon_cb.a_in;
                tr.b = vif.mon_cb.b_in;

                do begin
                    @(vif.mon_cb);
                end while (!(vif.mon_cb.out_valid === 1'b1 && vif.mon_cb.out_ready === 1'b1));

                tr.gcd_out = vif.mon_cb.gcd_out;
                // log statement
                `uvm_info("MON", {"Catched transaction: ", tr.convert2string()}, UVM_LOW)
                analysis_port.write(tr);
            end
        endtask
    endclass

    // Agent
    class gcd_agent extends uvm_agent;
        `uvm_component_utils(gcd_agent)

        virtual gcd_if vif;

        gcd_sequencer   sequencer;
        gcd_driver      driver;
        gcd_monitor     monitor;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            if (!uvm_config_db#(virtual gcd_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("No virtual interface in AGENT", {"Virtual interface not set for: ", get_full_name(), ".vif"});
            end

            
            monitor = gcd_monitor::type_id::create("monitor", this);
            uvm_config_db#(virtual gcd_if)::set(this, "monitor", "vif", vif);

            // only if the agent is active
            if (get_is_active() == UVM_ACTIVE) begin
                sequencer   = gcd_sequencer::type_id::create("sequencer", this);
                driver      = gcd_driver::type_id::create("driver", this);
                uvm_config_db#(virtual gcd_if)::set(this, "driver", "vif", vif);
            end
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);

            if (get_is_active() == UVM_ACTIVE) begin
                driver.seq_item_port.connect(sequencer.seq_item_export);
            end
        endfunction
    endclass

    // Scoreboard and Coverage
    class gcd_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(gcd_scoreboard)

        // telemetry
        uvm_analysis_imp #(gcd_sequence_item, gcd_scoreboard) analysis_export;
 
        gcd_sequence_item cov_transaction;

        covergroup gcd_cg;
            option.per_instance = 1;

            cp_a: coverpoint cov_transaction.a {
                bins zero = {0};
                bins max  = {(1<<WIDTH)-1}; // 2^(WIDTH)-1
                bins others = {[1 : (1<<WIDTH)-2]};
            }

            cp_b: coverpoint cov_transaction.b {
                bins zero = {0};
                bins max  = {(1<<WIDTH)-1}; // 2^(WIDTH)-1
                bins others = {[1 : (1<<WIDTH)-2]};
            }

            cross_a_b: cross cp_a, cp_b;

            cp_mathematical_states: coverpoint (cov_transaction.a > cov_transaction.b) {
                bins a_greater_b = {1};
                bins b_greater_a = {0}; 
            }

            cp_equal: coverpoint (cov_transaction.a == cov_transaction.b) {
                bins a_equals_b = {1}; // GCD(A,A)
            }
        endgroup

        function new(string name, uvm_component parent);
            super.new(name, parent);
            analysis_export = new("analysis_export", this);
            gcd_cg = new();
        endfunction

        virtual function void write(gcd_sequence_item transaction);
            int expected_gcd;
            expected_gcd = calculate_gcd(transaction.a, transaction.b);

            // checker - start
            if (expected_gcd !== transaction.gcd_out) begin
                `uvm_error("CHECKER FAIL", $sformatf("GCD mismatch: expected %0d but got %0d for inputs A=%0d, B=%0d", expected_gcd, transaction.gcd_out, transaction.a, transaction.b))
            end else begin
                `uvm_info("CHECKER PASS", $sformatf("GCD match: expected %0d, got %0d for inputs A=%0d, B=%0d", expected_gcd, transaction.gcd_out, transaction.a, transaction.b), UVM_HIGH)
            end

            // coverage
            cov_transaction = transaction;
            gcd_cg.sample();
        endfunction

        // golden model GCD
        function int calculate_gcd(int a, int b);
            if (a == 0) return b;
            if (b == 0) return a;
            while (b != 0) begin
                int temp = b;
                b = a % b; // remainder
                a = temp;  // swap
            end
            return a;
        endfunction
    endclass

    // Environment
    class gcd_env extends uvm_env;
        `uvm_component_utils(gcd_env)

        gcd_agent      agent;
        gcd_scoreboard scoreboard;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            agent       = gcd_agent::type_id::create("agent", this);
            scoreboard  = gcd_scoreboard::type_id::create("scoreboard", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            
            // connection between monitor <-> scoreboard
            agent.monitor.analysis_port.connect(scoreboard.analysis_export);
        endfunction
    endclass

    // Tests
    class gcd_base_test extends uvm_test;
        `uvm_component_utils(gcd_base_test)

        gcd_env environment;

        function new(string name, uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            environment = gcd_env::type_id::create("environment", this);
        endfunction

        task run_phase(uvm_phase phase);
            // gives the DUT time to finish 
            phase.phase_done.set_drain_time(this, 2000ns); 
        endtask

        // print topology, debugging sake
        virtual function void end_of_elaboration_phase(uvm_phase phase);
            uvm_top.print_topology();
        endfunction
    endclass

    // 1- bringup
    class gcd_bringup_test extends gcd_base_test;
        `uvm_component_utils(gcd_bringup_test)

        function new(string name = "gcd_bringup_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            gcd_bringup_seq seq = gcd_bringup_seq::type_id::create("seq");
            phase.raise_objection(this);
            seq.start(environment.agent.sequencer);
            phase.drop_objection(this);
        endtask
    endclass

    // 2- directed edge case
    class gcd_directed_test extends gcd_base_test;
        `uvm_component_utils(gcd_directed_test)

        function new(string name = "gcd_directed_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            gcd_directed_edge_case_seq seq = gcd_directed_edge_case_seq::type_id::create("seq");
            phase.raise_objection(this);
            seq.start(environment.agent.sequencer);
            phase.drop_objection(this);
        endtask
    endclass

    // 3- constrained random
    class gcd_random_test extends gcd_base_test;
        `uvm_component_utils(gcd_random_test)

        function new(string name = "gcd_random_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            gcd_random_seq seq = gcd_random_seq::type_id::create("seq");
            phase.raise_objection(this);
            seq.start(environment.agent.sequencer);
            phase.drop_objection(this);
        endtask
    endclass

endpackage : gcd_package

// Testbench top module
module testbench_gcd;
    import loc_constants::*;
    import gcd_package::*;
    import uvm_pkg::*;

    logic clk;
    logic rst_n;

    // Clock start
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1;
        @(posedge clk);
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    end

    gcd_if gcd_if_inst(clk, rst_n);

        // DUT instance
    gcd #(
        .WIDTH(WIDTH) 
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(gcd_if_inst.in_valid),
        .in_ready(gcd_if_inst.in_ready),
        .a_in(gcd_if_inst.a_in),
        .b_in(gcd_if_inst.b_in),
        .out_valid(gcd_if_inst.out_valid),
        .out_ready(gcd_if_inst.out_ready),
        .gcd_out(gcd_if_inst.gcd_out)
    );

    initial begin
        automatic virtual gcd_if vif = gcd_if_inst;

        uvm_config_db#(virtual gcd_if)::set(null, "*", "vif", vif);

        run_test();
    end

endmodule : testbench_gcd