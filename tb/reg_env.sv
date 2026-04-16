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
    real target_cov;

    function new(string name,
                 virtual reg_if rif,
                 int unsigned seed,
                 int mailbox_depth = 32,
                 int min_random = 500,
                 int max_random = 1000,
                 real target_cov = 100.0);
        this.name = name;
        this.rif = rif;
        this.mailbox_depth = mailbox_depth;
        this.min_random = min_random;
        this.max_random = max_random;
        this.target_cov = target_cov;

        gen2drv = new(mailbox_depth);
        mon2scb = new(mailbox_depth);

        drv = new(rif, gen2drv);
        gen = new(rif, gen2drv, seed);
        mon = new(rif, mon2scb);
        scb = new(rif, mon2scb);
    endfunction

    task automatic run_random_phase();
        int remaining = max_random;
        int sent = 0;
        int batch;

        gen.start_random();

        while (remaining > 0) begin
            batch = (remaining > 25) ? 25 : remaining;
            gen.send_random(batch);
            sent += batch;
            remaining -= batch;

            repeat (batch + 2) @(posedge rif.clk);

            if (sent >= min_random && scb.get_coverage() >= target_cov) begin
                break;
            end
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
endclass
`endif
