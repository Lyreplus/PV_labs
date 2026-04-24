`timescale 1ns/1ps

`ifndef DUT0
`define DUT0 regfile_v0
`endif

`ifndef DUT1
`define DUT1 regfile_v1
`endif

`ifndef DUT2
`define DUT2 regfile_v2
`endif

`ifndef DUT3
`define DUT3 regfile_v3
`endif

// ******** CONSTANTS ********

package register_constants;
        localparam int ADDRESS_LENGTH = 5;
        localparam int DATA_WIDTH = 16;
endpackage

import register_constants::*;

// ******** INTERFACE ********

interface register_interface(input bit clk);
    logic                       rst_n, wr_en, err;
    logic [ADDRESS_LENGTH-1:0]  wr_addr, rd_addr1, rd_addr2;
    logic [DATA_WIDTH-1:0]      wr_data, rd_data1, rd_data2;

    clocking clockingblock @(posedge clk);
        default input #1step output #0;
        inout rst_n;

        inout wr_en;
        inout wr_addr;
        inout wr_data;

        inout rd_addr1;
        inout rd_addr2;

        input rd_data1;
        input rd_data2;
        input err;
    endclocking: clockingblock

endinterface //register_interface

// ******** TRANSACTION ********

class register_transaction;
    // transaction input
	rand bit                        rst_n, wr_en;
	rand bit [ADDRESS_LENGTH-1:0]   wr_addr, rd_addr1, rd_addr2;
	rand bit [DATA_WIDTH-1:0]       wr_data;
	
    // transaction output
    logic [15:0]                    rd_data1;
	logic [15:0]                    rd_data2;
	logic                           err;

    // transaction control
	bit                             is_end;
	bit                             illegal;

    // Constraints
	constraint addresses {
		wr_addr inside {[0:31]};
		rd_addr1 inside {[0:31]};
		rd_addr2 inside {[0:31]};
	}

    constraint data {
        wr_data inside {[0:16'hFFFF]};
    }

    constraint rst_enable { rst_n dist {1'b1 := 1, 1'b0 := 9}; }

	constraint wr_enable { wr_en dist {1'b1 := 1, 1'b0 := 1}; }

	constraint corner_cases_data {
		wr_data dist {
			16'h0123 := 1,
            16'h9876 := 1,
			16'hFEDC := 1,
			16'hFFFF := 1,
			16'hAAAA := 1,
            16'h5555 := 1,
			[0:16'hFFFF] :/ 94
		};
	}

	constraint addresses_collisions {
		rd_addr1 dist { rd_addr2 := 1, [0:31] :/ 4 };
		wr_addr dist { rd_addr1 := 1, rd_addr2 := 1, [0:31] :/ 8 };
	}

	function new();
		is_end = 1'b0;
		illegal = 1'b0;
	endfunction

	function void illegal_check();
		illegal = (rd_addr1 == rd_addr2) ||
				  (wr_en && ((wr_addr == rd_addr1) || (wr_addr == rd_addr2)));
	endfunction

    function void pre_randomize();
        $display("Seed: %0d", $urandom);
    endfunction
endclass

// ******** DRIVER ********

class register_driver;
    virtual interface register_interface rif;
    mailbox #(register_transaction) gen2drv;
    bit done;

    function new(virtual register_interface rif, mailbox #(register_transaction) gen2drv);
        this.rif = rif;
        this.gen2drv = gen2drv;
        this.done = 1'b0;
    endfunction

    // automatic to 
    task automatic init_signals();
        rif.clockingblock.rst_n <= 1'b1;
        rif.clockingblock.wr_en <= 1'b0;
        rif.clockingblock.wr_addr <= '0;
        rif.clockingblock.wr_data <= '0;
        rif.clockingblock.rd_addr1 <= '0;
        rif.clockingblock.rd_addr2 <= '0;
    endtask

    task automatic reset_dut();
        init_signals();

        rif.clockingblock.rst_n <= 1'b0;
        repeat (2) @(posedge rif.clk);

        rif.clockingblock.rst_n <= 1'b1;
        @(posedge rif.clk); // DUT has time to come out of reset before transactions
    endtask

    task run();
        reg_transaction tr;
        forever begin
            gen2drv.get(tr);
            if (tr.is_end) begin
                rif.clockingblock.wr_en <= 1'b0;
                done = 1'b1;
                break;
            end

            @(negedge rif.clk);
            rif.wr_en <= tr.wr_en;
            rif.wr_addr <= tr.wr_addr;
            rif.wr_data <= tr.wr_data;
            rif.rd_addr1 <= tr.rd_addr1;
            rif.rd_addr2 <= tr.rd_addr2;
        end
    endtask
endclass

module tb_regfile;
    logic clk;
    int cycle_count;
    time start_time;
    time end_time;
    integer log_clear_fh;

    reg_if rif0(clk);
    reg_if rif1(clk);
    reg_if rif2(clk);
    reg_if rif3(clk);

    reg_env env0;
    reg_env env1;
    reg_env env2;
    reg_env env3;

    `DUT0 dut0 (
        .clk(clk),
        .rst_n(rif0.rst_n),
        .wr_en(rif0.wr_en),
        .wr_addr(rif0.wr_addr),
        .wr_data(rif0.wr_data),
        .rd_addr1(rif0.rd_addr1),
        .rd_addr2(rif0.rd_addr2),
        .rd_data1(rif0.rd_data1),
        .rd_data2(rif0.rd_data2),
        .err(rif0.err)
    );

    `DUT1 dut1 (
        .clk(clk),
        .rst_n(rif1.rst_n),
        .wr_en(rif1.wr_en),
        .wr_addr(rif1.wr_addr),
        .wr_data(rif1.wr_data),
        .rd_addr1(rif1.rd_addr1),
        .rd_addr2(rif1.rd_addr2),
        .rd_data1(rif1.rd_data1),
        .rd_data2(rif1.rd_data2),
        .err(rif1.err)
    );

    `DUT2 dut2 (
        .clk(clk),
        .rst_n(rif2.rst_n),
        .wr_en(rif2.wr_en),
        .wr_addr(rif2.wr_addr),
        .wr_data(rif2.wr_data),
        .rd_addr1(rif2.rd_addr1),
        .rd_addr2(rif2.rd_addr2),
        .rd_data1(rif2.rd_data1),
        .rd_data2(rif2.rd_data2),
        .err(rif2.err)
    );

    `DUT3 dut3 (
        .clk(clk),
        .rst_n(rif3.rst_n),
        .wr_en(rif3.wr_en),
        .wr_addr(rif3.wr_addr),
        .wr_data(rif3.wr_data),
        .rd_addr1(rif3.rd_addr1),
        .rd_addr2(rif3.rd_addr2),
        .rd_data1(rif3.rd_data1),
        .rd_data2(rif3.rd_data2),
        .err(rif3.err)
    );

    reg_checker #(.NAME("regfile_0")) chk0(rif0);
    reg_checker #(.NAME("regfile_1")) chk1(rif1);
    reg_checker #(.NAME("regfile_2")) chk2(rif2);
    reg_checker #(.NAME("regfile_3")) chk3(rif3);

    always #5 clk = ~clk;

    always @(posedge clk) begin
        cycle_count++;
    end

    initial begin
        clk = 1'b0;
        cycle_count = 0;
        start_time = $time;

        log_clear_fh = $fopen("regfile_v0_errors.log", "w");
        if (log_clear_fh) $fclose(log_clear_fh);
        log_clear_fh = $fopen("regfile_v1_errors.log", "w");
        if (log_clear_fh) $fclose(log_clear_fh);
        log_clear_fh = $fopen("regfile_v2_errors.log", "w");
        if (log_clear_fh) $fclose(log_clear_fh);
        log_clear_fh = $fopen("regfile_v3_errors.log", "w");
        if (log_clear_fh) $fclose(log_clear_fh);

        env0 = new("regfile_v0", rif0, 32'h10);
        env1 = new("regfile_v1", rif1, 32'h20);
        env2 = new("regfile_v2", rif2, 32'h30);
        env3 = new("regfile_v3", rif3, 32'h40);

        fork
            env0.run();
            env1.run();
            env2.run();
            env3.run();
        join

        end_time = $time;
        $display("\nSimulation time: %0t ns (%0d cycles)", end_time - start_time, cycle_count);

        env0.report();
        env1.report();
        env2.report();
        env3.report();

        $display("\nDesign summary (failed transactions per requirement)");
        $display("------------------------------------------------------------------------------------------------------------");
        $display("%-12s | %3s %3s %3s %3s %3s %3s %3s %3s %3s %3s | %6s",
             "Design", "R1", "R2", "R3", "R4", "R5", "R6", "R7", "R8", "R9", "R10", "Total");
        $display("%-12s | %3d %3d %3d %3d %3d %3d %3d %3d %3d %3d | %6d",
             env0.name,
             env0.req_fail_count(1), env0.req_fail_count(2), env0.req_fail_count(3), env0.req_fail_count(4),
             env0.req_fail_count(5), env0.req_fail_count(6), env0.req_fail_count(7), env0.req_fail_count(8),
             env0.req_fail_count(9), env0.req_fail_count(10), env0.total_errors());
        $display("%-12s | %3d %3d %3d %3d %3d %3d %3d %3d %3d %3d | %6d",
             env1.name,
             env1.req_fail_count(1), env1.req_fail_count(2), env1.req_fail_count(3), env1.req_fail_count(4),
             env1.req_fail_count(5), env1.req_fail_count(6), env1.req_fail_count(7), env1.req_fail_count(8),
             env1.req_fail_count(9), env1.req_fail_count(10), env1.total_errors());
        $display("%-12s | %3d %3d %3d %3d %3d %3d %3d %3d %3d %3d | %6d",
             env2.name,
             env2.req_fail_count(1), env2.req_fail_count(2), env2.req_fail_count(3), env2.req_fail_count(4),
             env2.req_fail_count(5), env2.req_fail_count(6), env2.req_fail_count(7), env2.req_fail_count(8),
             env2.req_fail_count(9), env2.req_fail_count(10), env2.total_errors());
        $display("%-12s | %3d %3d %3d %3d %3d %3d %3d %3d %3d %3d | %6d",
             env3.name,
             env3.req_fail_count(1), env3.req_fail_count(2), env3.req_fail_count(3), env3.req_fail_count(4),
             env3.req_fail_count(5), env3.req_fail_count(6), env3.req_fail_count(7), env3.req_fail_count(8),
             env3.req_fail_count(9), env3.req_fail_count(10), env3.total_errors());

        env0.close_logs();
        env1.close_logs();
        env2.close_logs();
        env3.close_logs();

        $finish;
    end
endmodule

