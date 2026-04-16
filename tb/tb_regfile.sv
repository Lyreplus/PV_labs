`timescale 1ns/1ps
`include "reg_env.sv"
`include "reg_checker.sv"

`ifndef DUT0
`define DUT0 regfile_0
`endif

`ifndef DUT1
`define DUT1 regfile_1
`endif

`ifndef DUT2
`define DUT2 regfile_2
`endif

`ifndef DUT3
`define DUT3 regfile_3
`endif

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

        log_clear_fh = $fopen("regfile_0_errors.log", "w");
        if (log_clear_fh) $fclose(log_clear_fh);
        log_clear_fh = $fopen("regfile_1_errors.log", "w");
        if (log_clear_fh) $fclose(log_clear_fh);
        log_clear_fh = $fopen("regfile_2_errors.log", "w");
        if (log_clear_fh) $fclose(log_clear_fh);
        log_clear_fh = $fopen("regfile_3_errors.log", "w");
        if (log_clear_fh) $fclose(log_clear_fh);

        env0 = new("regfile_0", rif0, 32'h10);
        env1 = new("regfile_1", rif1, 32'h20);
        env2 = new("regfile_2", rif2, 32'h30);
        env3 = new("regfile_3", rif3, 32'h40);

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

