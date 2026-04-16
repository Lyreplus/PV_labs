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

    bit stop_flag;
    bit scb_done;

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
        int per_req;
        int sent;
        int total_sent;
        int remaining;
        int batch;
        int est_total;

        total_sent = 0;
        per_req = (min_random > 0) ? (min_random / 6) : 1;
        if (per_req < 1) begin
            per_req = 1;
        end

        est_total = 10 * per_req + 8;
        if (est_total > max_random) begin
            per_req = (max_random > 8) ? ((max_random - 8) / 10) : 1;
            if (per_req < 1) begin
                per_req = 1;
            end
        end

        gen.rand_req003_write_update(per_req, sent);
        total_sent += sent;
        repeat (sent + 2) @(posedge rif.clk);

        gen.rand_req004_read_immediate(per_req, sent);
        total_sent += sent;
        repeat (sent + 2) @(posedge rif.clk);

        gen.rand_req005_read_contents(per_req, sent);
        total_sent += sent;
        repeat (sent + 2) @(posedge rif.clk);

        gen.rand_req008_no_write_on_illegal(per_req, sent);
        total_sent += sent;
        repeat (sent + 2) @(posedge rif.clk);

        gen.rand_req009_x_on_illegal(per_req, sent);
        total_sent += sent;
        repeat (sent + 2) @(posedge rif.clk);

        gen.rand_req010_err_registered(per_req, sent);
        total_sent += sent;
        repeat (sent + 2) @(posedge rif.clk);

        if (total_sent < min_random) begin
            int extra = min_random - total_sent;
            gen.send_random(extra);
            total_sent += extra;
            repeat (extra + 2) @(posedge rif.clk);
        end

        remaining = max_random - total_sent;
        if (remaining < 0) begin
            remaining = 0;
        end

        while (remaining > 0) begin
            batch = (remaining > 25) ? 25 : remaining;
            gen.send_random(batch);
            total_sent += batch;
            remaining -= batch;
            repeat (batch + 2) @(posedge rif.clk);
        end
    endtask

    task run();
        stop_flag = 1'b0;
        scb_done = 1'b0;

        fork
            mon.run(stop_flag);
            scb.run(stop_flag, scb_done);
        join_none

        drv.reset_dut();

        fork
            drv.run(stop_flag);
        join_none

        gen.run_directed();
        run_random_phase();
        gen.send_end();

        wait (stop_flag);
        wait (scb_done);
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

    task close_logs();
        scb.close_log();
    endtask
endclass
`endif
