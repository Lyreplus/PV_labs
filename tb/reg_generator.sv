`ifndef REG_GENERATOR_SV
`define REG_GENERATOR_SV

`include "reg_if.sv"
`include "reg_transaction.sv"

// register generator responsible for creating both directed and random transactions
// sends them to the driver via the gen2drv mailbox
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

    function automatic void set_tr(
        ref reg_transaction tr,
        bit wr_en,
        logic [4:0] wr_addr,
        logic [15:0] wr_data,
        logic [4:0] rd_addr1,
        logic [4:0] rd_addr2,
        bit illegal_en
    );
        tr.wr_en = wr_en;
        tr.wr_addr = wr_addr;
        tr.wr_data = wr_data;
        tr.rd_addr1 = rd_addr1;
        tr.rd_addr2 = rd_addr2;
        tr.illegal_en = illegal_en;
        tr.illegal = (rd_addr1 == rd_addr2) ||
                     (wr_en && ((wr_addr == rd_addr1) || (wr_addr == rd_addr2)));
    endfunction

    function automatic void force_read_only(ref reg_transaction tr);
        tr.wr_en = 1'b0;
        tr.wr_addr = 5'd0;
        tr.wr_data = 16'h0000;
        tr.illegal = (tr.rd_addr1 == tr.rd_addr2);
    endfunction

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

    task automatic t_rand_001(int count, output int sent);
        reg_transaction tr;
        reg_transaction tr2;
        reg_transaction tr3;
        int remaining;
        int sel;

        sent = 0;
        start_random();

        while (sent < count) begin
            remaining = count - sent;
            if (remaining == 1) begin
                void'(std::randomize(sel) with { sel inside {[0:1]}; });
            end else if (remaining == 2) begin
                void'(std::randomize(sel) with { sel inside {[0:3]}; });
            end else begin
                void'(std::randomize(sel) with { sel inside {[0:4]}; });
            end

            case (sel)
                0: begin
                    tr = new();
                    if (!tr.randomize() with { illegal_en == 0; }) begin
                        set_tr(tr, 1'b0, 5'd0, 16'h0000, 5'd0, 5'd1, 1'b0);
                    end
                    send(tr);
                    sent++;
                end
                1: begin
                    tr = new();
                    if (!tr.randomize() with { illegal_en == 1; wr_en == 0; rd_addr1 == rd_addr2; }) begin
                        set_tr(tr, 1'b0, 5'd0, 16'h0000, 5'd3, 5'd3, 1'b1);
                    end
                    force_read_only(tr);
                    send(tr);
                    sent++;
                end
                2: begin
                    tr = new();
                    if (!tr.randomize() with { illegal_en == 0; wr_en == 1; }) begin
                        set_tr(tr, 1'b1, 5'd7, 16'h1234, 5'd0, 5'd1, 1'b0);
                    end
                    send(tr);
                    sent++;

                    tr2 = new();
                    if (!tr2.randomize() with {
                        illegal_en == 0;
                        wr_en == 0;
                        rd_addr1 == tr.wr_addr;
                        rd_addr2 != rd_addr1;
                    }) begin
                        set_tr(tr2, 1'b0, 5'd0, 16'h0000, tr.wr_addr, tr.wr_addr + 5'd1, 1'b0);
                    end
                    force_read_only(tr2);
                    send(tr2);
                    sent++;
                end
                3: begin
                    tr = new();
                    if (!tr.randomize() with { illegal_en == 0; wr_en == 0; rd_addr1 != rd_addr2; }) begin
                        set_tr(tr, 1'b0, 5'd0, 16'h0000, 5'd4, 5'd5, 1'b0);
                    end
                    force_read_only(tr);
                    send(tr);
                    sent++;

                    tr2 = new();
                    if (!tr2.randomize() with {
                        illegal_en == 0;
                        wr_en == 0;
                        rd_addr1 != rd_addr2;
                        (rd_addr1 != tr.rd_addr1) || (rd_addr2 != tr.rd_addr2);
                    }) begin
                        set_tr(tr2, 1'b0, 5'd0, 16'h0000, tr.rd_addr1 + 5'd1, tr.rd_addr2 + 5'd1, 1'b0);
                    end
                    force_read_only(tr2);
                    send(tr2);
                    sent++;
                end
                default: begin
                    tr = new();
                    if (!tr.randomize() with { illegal_en == 0; wr_en == 1; }) begin
                        set_tr(tr, 1'b1, 5'd9, 16'h1111, 5'd0, 5'd1, 1'b0);
                    end
                    send(tr);
                    sent++;

                    tr2 = new();
                    if (!tr2.randomize() with {
                        illegal_en == 1;
                        wr_en == 1;
                        wr_addr == tr.wr_addr;
                        rd_addr1 != rd_addr2;
                        (rd_addr1 == wr_addr) || (rd_addr2 == wr_addr);
                    }) begin
                        set_tr(tr2, 1'b1, tr.wr_addr, 16'hAAAA, tr.wr_addr, tr.wr_addr + 5'd1, 1'b1);
                    end
                    send(tr2);
                    sent++;

                    tr3 = new();
                    if (!tr3.randomize() with {
                        illegal_en == 0;
                        wr_en == 0;
                        rd_addr1 == tr.wr_addr;
                        rd_addr2 != rd_addr1;
                    }) begin
                        set_tr(tr3, 1'b0, 5'd0, 16'h0000, tr.wr_addr, tr.wr_addr + 5'd1, 1'b0);
                    end
                    force_read_only(tr3);
                    send(tr3);
                    sent++;
                end
            endcase
        end
    endtask

    task send_end();
        reg_transaction tr = new();
        tr.is_end = 1'b1;
        send(tr);
    endtask
endclass
`endif