`ifndef REG_ENV_SV
`define REG_ENV_SV

`include "reg_if.sv"
`include "reg_transaction.sv"
`include "reg_generator.sv"
`include "reg_driver.sv"
`include "reg_monitor.sv"
`include "reg_scoreboard.sv"

class reg_env;
    string name;
    virtual reg_if rif;

    register_driver drv;
    register_generator gen;
    register_monitor mon;
    reg_scoreboard scb;

    mailbox #(reg_transaction) gen2drv;
    mailbox #(reg_observation) mon2scb;

    int mailbox_depth;
    int max_random;
    int min_random;

    function new(string name,
                 virtual reg_if rif,
                 int unsigned seed,
                 int mailbox_depth = 32,
                 int min_random = 500,
                 int max_random = 1000);
        this.name = name;
        this.rif = rif;
        this.mailbox_depth = mailbox_depth;
        this.min_random = min_random;
        this.max_random = max_random;

        gen2drv = new(mailbox_depth);
        mon2scb = new(mailbox_depth);

        drv = new(rif, gen2drv);
        gen = new(rif, gen2drv, seed);
        mon = new(rif, mon2scb);
        scb = new(name, rif, mon2scb);
    endfunction

    task automatic run_random_phase();
        int sent;
        int target;

        target = max_random;
        if (target < min_random) begin
            target = min_random;
        end
        if (target < 1) begin
            target = 1;
        end

        gen.t_rand_001(target, sent);
        repeat (sent + 2) @(posedge rif.clk);
    endtask

    task run();
        fork
            mon.run();
            scb.run();
        join_none

        drv.reset_dut();

        fork
            drv.run();
        join_none

        gen.run_directed();
        run_random_phase();
        gen.send_end();
        repeat (5) @(posedge rif.clk);
    endtask

    function void report();
        scb.report(name);
    endfunction

    function string req_fail_list();
        return scb.req_fail_string();
    endfunction

    function int total_errors();
        return scb.get_error_count();
    endfunction

    function int req_fail_count(int idx);
        return scb.get_req_fail_count(idx);
    endfunction

    task close_logs();
        scb.close_log();
    endtask
endclass
`endif
