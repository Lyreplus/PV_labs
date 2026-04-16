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

    task run_directed();
        reg_transaction tr;

        // write and read
        tr = new();
        tr.wr_en = 1'b1;
        tr.wr_addr = 5'd3;
        tr.wr_data = 16'h1234;
        tr.rd_addr1 = 5'd3;
        tr.rd_addr2 = 5'd4;
        send(tr);

        tr = new();
        tr.wr_en = 1'b0;
        tr.wr_addr = 5'd0;
        tr.wr_data = 16'h0000;
        tr.rd_addr1 = 5'd3;
        tr.rd_addr2 = 5'd4;
        send(tr);

        // 2nd write/read sequence
        tr = new();
        tr.wr_en = 1'b1;
        tr.wr_addr = 5'd7;
        tr.wr_data = 16'hA55A;
        tr.rd_addr1 = 5'd7;
        tr.rd_addr2 = 5'd3;
        send(tr);

        tr = new();
        tr.wr_en = 1'b0;
        tr.wr_addr = 5'd0;
        tr.wr_data = 16'h0000;
        tr.rd_addr1 = 5'd7;
        tr.rd_addr2 = 5'd3;
        send(tr);

        // illegal same read address
        tr = new();
        tr.wr_en = 1'b0;
        tr.wr_addr = 5'd0;
        tr.wr_data = 16'h0000;
        tr.rd_addr1 = 5'd10;
        tr.rd_addr2 = 5'd10;
        send(tr);

        // illegal write and read conflict
        tr = new();
        tr.wr_en = 1'b1;
        tr.wr_addr = 5'd12;
        tr.wr_data = 16'hBEEF;
        tr.rd_addr1 = 5'd12;
        tr.rd_addr2 = 5'd1;
        send(tr);

        // no write on illegal
        tr = new();
        tr.wr_en = 1'b1;
        tr.wr_addr = 5'd15;
        tr.wr_data = 16'h0F0F;
        tr.rd_addr1 = 5'd15;
        tr.rd_addr2 = 5'd2;
        send(tr);

        tr = new();
        tr.wr_en = 1'b0;
        tr.wr_addr = 5'd0;
        tr.wr_data = 16'h0000;
        tr.rd_addr1 = 5'd15;
        tr.rd_addr2 = 5'd2;
        send(tr);
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