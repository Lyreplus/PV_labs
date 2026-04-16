`ifndef REG_GENERATOR_SV
`define REG_GENERATOR_SV

`include "reg_if.sv"
`include "reg_transaction.sv"

// The register generator is responsible for creating both directed and random transactions
// It sends these transactions to the driver via the gen2drv mailbox
// Directed transactions are predefined sequences that test specific scenarios, including legal and illegal cases
// Random transactions are generated using SystemVerilog's randomization features, with constraints to ensure they are valid or intentionally illegal
// The generator also has a method to send an end-of-test transaction, which signals the driver to stop and allows the monitor and scoreboard to finish processing
// The generator uses a seed for randomization to allow for reproducibility of test runs
// The generator can be extended with additional directed test cases or more complex randomization constraints as needed
// generator communicates through transactions
class register_generator;
    virtual reg_if rif;
    mailbox #(reg_transaction) gen2drv;
    int unsigned seed;
    bit random_started;

    function new(virtual reg_if rif, mailbox #(reg_transaction) gen2drv, int unsigned seed = 32'h1);
        this.rif = rif;
        this.gen2drv = gen2drv;
        this.seed = seed;
        this.random_started = 1'b0;
    endfunction

    task automatic start_random();
        if (!random_started) begin
            process::self().srandom(seed);
            random_started = 1'b1;
        end
    endtask

    task automatic send(reg_transaction tr);
        gen2drv.put(tr);
    endtask

    task automatic t_req001_002_reset_read();
        reg_transaction tr;

        // REQ-001, REQ-002: after reset, registers are 0 and err is 0
        tr = new();
        tr.wr_en = 1'b0;
        tr.wr_addr = 5'd0;
        tr.wr_data = 16'h0000;
        tr.rd_addr1 = 5'd0;
        tr.rd_addr2 = 5'd1;
        send(tr);
    endtask

    task automatic t_req003_write_update();
        reg_transaction tr;

        // REQ-003: legal write then read back
        tr = new();
        tr.wr_en = 1'b1;
        tr.wr_addr = 5'd3;
        tr.wr_data = 16'h1234;
        tr.rd_addr1 = 5'd0;
        tr.rd_addr2 = 5'd1;
        send(tr);

        tr = new();
        tr.wr_en = 1'b0;
        tr.wr_addr = 5'd0;
        tr.wr_data = 16'h0000;
        tr.rd_addr1 = 5'd3;
        tr.rd_addr2 = 5'd4;
        send(tr);
    endtask

    task automatic t_req004_read_immediate();
        reg_transaction tr;

        // REQ-004: rd_data updates immediately on address change
        tr = new();
        tr.wr_en = 1'b1;
        tr.wr_addr = 5'd8;
        tr.wr_data = 16'h0A0A;
        tr.rd_addr1 = 5'd0;
        tr.rd_addr2 = 5'd1;
        send(tr);

        tr = new();
        tr.wr_en = 1'b1;
        tr.wr_addr = 5'd9;
        tr.wr_data = 16'h0B0B;
        tr.rd_addr1 = 5'd0;
        tr.rd_addr2 = 5'd1;
        send(tr);

        tr = new();
        tr.wr_en = 1'b0;
        tr.wr_addr = 5'd0;
        tr.wr_data = 16'h0000;
        tr.rd_addr1 = 5'd8;
        tr.rd_addr2 = 5'd9;
        send(tr);

        tr = new();
        tr.wr_en = 1'b0;
        tr.wr_addr = 5'd0;
        tr.wr_data = 16'h0000;
        tr.rd_addr1 = 5'd9;
        tr.rd_addr2 = 5'd8;
        send(tr);
    endtask

    task automatic t_req006_same_read_addr_illegal();
        reg_transaction tr;

        // REQ-006: rd_addr1 == rd_addr2 -> illegal
        tr = new();
        tr.wr_en = 1'b0;
        tr.wr_addr = 5'd0;
        tr.wr_data = 16'h0000;
        tr.rd_addr1 = 5'd10;
        tr.rd_addr2 = 5'd10;
        send(tr);
    endtask

    task automatic t_req007_write_read_conflict_illegal();
        reg_transaction tr;

        // REQ-007: write/read conflict -> illegal
        tr = new();
        tr.wr_en = 1'b1;
        tr.wr_addr = 5'd12;
        tr.wr_data = 16'hBEEF;
        tr.rd_addr1 = 5'd12;
        tr.rd_addr2 = 5'd1;
        send(tr);
    endtask

    task run_directed();
        t_req001_002_reset_read();
        t_req003_write_update();
        t_req004_read_immediate();
        t_req006_same_read_addr_illegal();
        t_req007_write_read_conflict_illegal();
    endtask

    task automatic rand_req003_write_update(int count, output int sent);
        reg_transaction wr_tr;
        reg_transaction rd_tr;

        sent = 0;
        start_random();

        repeat (count) begin
            wr_tr = new();
            if (!wr_tr.randomize() with { illegal_en == 0; wr_en == 1; }) begin
                wr_tr.illegal_en = 1'b0;
                wr_tr.wr_en = 1'b1;
                wr_tr.wr_addr = 5'd0;
                wr_tr.wr_data = 16'h1234;
                wr_tr.rd_addr1 = 5'd1;
                wr_tr.rd_addr2 = 5'd2;
            end
            send(wr_tr);
            sent++;

            rd_tr = new();
            if (!rd_tr.randomize() with {
                illegal_en == 0;
                wr_en == 0;
                rd_addr1 == wr_tr.wr_addr;
                rd_addr2 != rd_addr1;
            }) begin
                rd_tr.illegal_en = 1'b0;
                rd_tr.wr_en = 1'b0;
                rd_tr.wr_addr = 5'd0;
                rd_tr.wr_data = 16'h0000;
                rd_tr.rd_addr1 = wr_tr.wr_addr;
                rd_tr.rd_addr2 = wr_tr.wr_addr + 5'd1;
            end
            rd_tr.wr_addr = 5'd0;
            rd_tr.wr_data = 16'h0000;
            send(rd_tr);
            sent++;
        end
    endtask

    task automatic rand_req004_read_immediate(int count, output int sent);
        reg_transaction tr;
        bit [4:0] last_addr1;
        bit [4:0] last_addr2;
        int prefill = 4;

        sent = 0;
        start_random();

        repeat (prefill) begin
            tr = new();
            if (!tr.randomize() with { illegal_en == 0; wr_en == 1; }) begin
                tr.illegal_en = 1'b0;
                tr.wr_en = 1'b1;
                tr.wr_addr = 5'd4;
                tr.wr_data = 16'h0A0A;
                tr.rd_addr1 = 5'd0;
                tr.rd_addr2 = 5'd1;
            end
            send(tr);
            sent++;
        end

        last_addr1 = 5'h1F;
        last_addr2 = 5'h00;
        repeat (count) begin
            tr = new();
            if (!tr.randomize() with {
                illegal_en == 0;
                wr_en == 0;
                rd_addr1 != rd_addr2;
                (rd_addr1 != last_addr1) || (rd_addr2 != last_addr2);
            }) begin
                tr.illegal_en = 1'b0;
                tr.wr_en = 1'b0;
                tr.wr_addr = 5'd0;
                tr.wr_data = 16'h0000;
                tr.rd_addr1 = last_addr1 + 5'd1;
                tr.rd_addr2 = last_addr2 + 5'd2;
            end
            tr.wr_addr = 5'd0;
            tr.wr_data = 16'h0000;
            send(tr);
            sent++;
            last_addr1 = tr.rd_addr1;
            last_addr2 = tr.rd_addr2;
        end
    endtask

    task automatic rand_req005_read_contents(int count, output int sent);
        reg_transaction tr;
        int prefill = 4;

        sent = 0;
        start_random();

        repeat (prefill) begin
            tr = new();
            if (!tr.randomize() with { illegal_en == 0; wr_en == 1; }) begin
                tr.illegal_en = 1'b0;
                tr.wr_en = 1'b1;
                tr.wr_addr = 5'd6;
                tr.wr_data = 16'h5A5A;
                tr.rd_addr1 = 5'd0;
                tr.rd_addr2 = 5'd1;
            end
            send(tr);
            sent++;
        end

        repeat (count) begin
            tr = new();
            if (!tr.randomize() with { illegal_en == 0; wr_en == 0; rd_addr1 != rd_addr2; }) begin
                tr.illegal_en = 1'b0;
                tr.wr_en = 1'b0;
                tr.wr_addr = 5'd0;
                tr.wr_data = 16'h0000;
                tr.rd_addr1 = 5'd2;
                tr.rd_addr2 = 5'd3;
            end
            tr.wr_addr = 5'd0;
            tr.wr_data = 16'h0000;
            send(tr);
            sent++;
        end
    endtask

    task automatic rand_req008_no_write_on_illegal(int count, output int sent);
        reg_transaction wr_tr;
        reg_transaction ill_tr;
        reg_transaction rd_tr;

        sent = 0;
        start_random();

        repeat (count) begin
            wr_tr = new();
            if (!wr_tr.randomize() with { illegal_en == 0; wr_en == 1; }) begin
                wr_tr.illegal_en = 1'b0;
                wr_tr.wr_en = 1'b1;
                wr_tr.wr_addr = 5'd9;
                wr_tr.wr_data = 16'h1111;
                wr_tr.rd_addr1 = 5'd0;
                wr_tr.rd_addr2 = 5'd1;
            end
            send(wr_tr);
            sent++;

            ill_tr = new();
            if (!ill_tr.randomize() with {
                illegal_en == 1;
                wr_en == 1;
                wr_addr == wr_tr.wr_addr;
                rd_addr1 != rd_addr2;
                (rd_addr1 == wr_addr) || (rd_addr2 == wr_addr);
            }) begin
                ill_tr.illegal_en = 1'b1;
                ill_tr.wr_en = 1'b1;
                ill_tr.wr_addr = wr_tr.wr_addr;
                ill_tr.wr_data = 16'hAAAA;
                ill_tr.rd_addr1 = wr_tr.wr_addr;
                ill_tr.rd_addr2 = wr_tr.wr_addr + 5'd1;
            end
            send(ill_tr);
            sent++;

            rd_tr = new();
            if (!rd_tr.randomize() with {
                illegal_en == 0;
                wr_en == 0;
                rd_addr1 == wr_tr.wr_addr;
                rd_addr2 != rd_addr1;
            }) begin
                rd_tr.illegal_en = 1'b0;
                rd_tr.wr_en = 1'b0;
                rd_tr.wr_addr = 5'd0;
                rd_tr.wr_data = 16'h0000;
                rd_tr.rd_addr1 = wr_tr.wr_addr;
                rd_tr.rd_addr2 = wr_tr.wr_addr + 5'd1;
            end
            rd_tr.wr_addr = 5'd0;
            rd_tr.wr_data = 16'h0000;
            send(rd_tr);
            sent++;
        end
    endtask

    task automatic rand_req009_x_on_illegal(int count, output int sent);
        reg_transaction tr;

        sent = 0;
        start_random();

        repeat (count) begin
            tr = new();
            if (!tr.randomize() with {
                illegal_en == 1;
                wr_en == 0;
                rd_addr1 == rd_addr2;
            }) begin
                tr.illegal_en = 1'b1;
                tr.wr_en = 1'b0;
                tr.wr_addr = 5'd0;
                tr.wr_data = 16'h0000;
                tr.rd_addr1 = 5'd14;
                tr.rd_addr2 = 5'd14;
            end
            tr.wr_addr = 5'd0;
            tr.wr_data = 16'h0000;
            send(tr);
            sent++;
        end
    endtask

    task automatic rand_req010_err_registered(int count, output int sent);
        reg_transaction ill_tr;
        reg_transaction ok_tr;

        sent = 0;
        start_random();

        repeat (count) begin
            ill_tr = new();
            if (!ill_tr.randomize() with {
                illegal_en == 1;
                wr_en == 0;
                rd_addr1 == rd_addr2;
            }) begin
                ill_tr.illegal_en = 1'b1;
                ill_tr.wr_en = 1'b0;
                ill_tr.wr_addr = 5'd0;
                ill_tr.wr_data = 16'h0000;
                ill_tr.rd_addr1 = 5'd5;
                ill_tr.rd_addr2 = 5'd5;
            end
            ill_tr.wr_addr = 5'd0;
            ill_tr.wr_data = 16'h0000;
            send(ill_tr);
            sent++;

            ok_tr = new();
            if (!ok_tr.randomize() with {
                illegal_en == 0;
                wr_en == 0;
                rd_addr1 != rd_addr2;
            }) begin
                ok_tr.illegal_en = 1'b0;
                ok_tr.wr_en = 1'b0;
                ok_tr.wr_addr = 5'd0;
                ok_tr.wr_data = 16'h0000;
                ok_tr.rd_addr1 = 5'd6;
                ok_tr.rd_addr2 = 5'd7;
            end
            ok_tr.wr_addr = 5'd0;
            ok_tr.wr_data = 16'h0000;
            send(ok_tr);
            sent++;
        end
    endtask

    task send_random(int count);
        reg_transaction tr;
        start_random();
        repeat (count) begin
            tr = new();
            if (!tr.randomize()) begin
                tr = new();
                tr.wr_en = 1'b0;
                tr.rd_addr1 = 5'd0;
                tr.rd_addr2 = 5'd1;
            end
            send(tr);
        end
    endtask

    task send_end();
        reg_transaction tr = new();
        tr.is_end = 1'b1;
        send(tr);
    endtask
endclass
`endif