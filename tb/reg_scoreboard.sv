`ifndef REG_SCOREBOARD_SV
`define REG_SCOREBOARD_SV

`include "reg_if.sv"
`include "reg_transaction.sv"

class reg_scoreboard;
    virtual reg_if rif;
    mailbox #(reg_observation) mon2scb;

    logic [15:0] mem [0:31];
    bit prev_illegal;

    int total_samples;
    int error_count;
    int data_mismatch;
    int err_mismatch;
    int reset_mismatch;
    int x_mismatch;

    bit cov_reset;
    bit cov_write;
    bit cov_read;
    bit cov_illegal_same;
    bit cov_illegal_conflict;
    bit cov_err;
    bit cov_x_output;
    bit cov_addr_change;

    covergroup req_cg;
        option.per_instance = 1;
        reset_cp : coverpoint cov_reset { bins hit = {1}; }
        write_cp : coverpoint cov_write { bins hit = {1}; }
        read_cp : coverpoint cov_read { bins hit = {1}; }
        ill_same_cp : coverpoint cov_illegal_same { bins hit = {1}; }
        ill_conf_cp : coverpoint cov_illegal_conflict { bins hit = {1}; }
        err_cp : coverpoint cov_err { bins hit = {1}; }
        x_cp : coverpoint cov_x_output { bins hit = {1}; }
        addr_change_cp : coverpoint cov_addr_change { bins hit = {1}; }
    endgroup

    function new(virtual reg_if rif, mailbox #(reg_observation) mon2scb);
        this.rif = rif;
        this.mon2scb = mon2scb;
        req_cg = new();
        total_samples = 0;
        error_count = 0;
        data_mismatch = 0;
        err_mismatch = 0;
        reset_mismatch = 0;
        x_mismatch = 0;
        cov_reset = 1'b0;
        cov_write = 1'b0;
        cov_read = 1'b0;
        cov_illegal_same = 1'b0;
        cov_illegal_conflict = 1'b0;
        cov_err = 1'b0;
        cov_x_output = 1'b0;
        cov_addr_change = 1'b0;
        reset_model();
    endfunction

    function void reset_model();
        for (int i = 0; i < 32; i++) begin
            mem[i] = 16'h0000;
        end
        prev_illegal = 1'b0;
    endfunction

    function bit is_all_x(logic [15:0] data);
        return (data === {16{1'bx}});
    endfunction

    function bit is_illegal(logic wr_en, logic [4:0] wr_addr,
                            logic [4:0] rd_addr1, logic [4:0] rd_addr2);
        return (rd_addr1 == rd_addr2) ||
               (wr_en && ((wr_addr == rd_addr1) || (wr_addr == rd_addr2)));
    endfunction

    task process_posedge(reg_observation obs);
        bit illegal;
        logic [15:0] exp_rd1;
        logic [15:0] exp_rd2;
        logic exp_err;

        total_samples++;

        if (obs.rst_n === 1'b0) begin
            if (obs.err !== 1'b0) begin
                reset_mismatch++;
                error_count++;
            end
            reset_model();
            cov_reset = 1'b1;
            req_cg.sample();
            return;
        end

        illegal = is_illegal(obs.wr_en, obs.wr_addr, obs.rd_addr1, obs.rd_addr2);
        exp_err = prev_illegal;

        if (obs.err !== exp_err) begin
            err_mismatch++;
            error_count++;
        end

        if (illegal) begin
            exp_rd1 = {16{1'bx}};
            exp_rd2 = {16{1'bx}};
            if (!is_all_x(obs.rd_data1) || !is_all_x(obs.rd_data2)) begin
                x_mismatch++;
                error_count++;
            end
            cov_x_output = 1'b1;
        end else begin
            exp_rd1 = mem[obs.rd_addr1];
            exp_rd2 = mem[obs.rd_addr2];
            if (obs.rd_data1 !== exp_rd1 || obs.rd_data2 !== exp_rd2) begin
                data_mismatch++;
                error_count++;
            end
            cov_read = 1'b1;
        end

        if (obs.wr_en && !illegal) begin
            mem[obs.wr_addr] = obs.wr_data;
            cov_write = 1'b1;
        end

        if (obs.rd_addr1 == obs.rd_addr2) begin
            cov_illegal_same = 1'b1;
        end

        if (obs.wr_en && ((obs.wr_addr == obs.rd_addr1) || (obs.wr_addr == obs.rd_addr2))) begin
            cov_illegal_conflict = 1'b1;
        end

        if (exp_err) begin
            cov_err = 1'b1;
        end

        prev_illegal = illegal;
        req_cg.sample();
    endtask

    task process_async(reg_observation obs);
        bit illegal;
        logic [15:0] exp_rd1;
        logic [15:0] exp_rd2;

        if (obs.rst_n !== 1'b1) begin
            return;
        end

        illegal = is_illegal(obs.wr_en, obs.wr_addr, obs.rd_addr1, obs.rd_addr2);
        if (illegal) begin
            if (!is_all_x(obs.rd_data1) || !is_all_x(obs.rd_data2)) begin
                x_mismatch++;
                error_count++;
            end
            cov_x_output = 1'b1;
        end else begin
            exp_rd1 = mem[obs.rd_addr1];
            exp_rd2 = mem[obs.rd_addr2];
            if (obs.rd_data1 !== exp_rd1 || obs.rd_data2 !== exp_rd2) begin
                data_mismatch++;
                error_count++;
            end
            cov_read = 1'b1;
        end

        cov_addr_change = 1'b1;

        req_cg.sample();
    endtask

    task run(ref bit stop_flag, output bit done);
        reg_observation obs;
        int idle_cycles = 0;
        done = 1'b0;
        forever begin
            if (mon2scb.try_get(obs)) begin
                idle_cycles = 0;
                do begin
                    if (obs.kind == SAMPLE_POSEDGE) begin
                        process_posedge(obs);
                    end else begin
                        process_async(obs);
                    end
                end while (mon2scb.try_get(obs));
            end else begin
                @(posedge rif.clk);
                if (stop_flag) begin
                    idle_cycles++;
                    if (idle_cycles >= 2) begin
                        done = 1'b1;
                        break;
                    end
                end
            end
        end
    endtask

    function real get_coverage();
        return req_cg.get_inst_coverage();
    endfunction

    function void report(string name);
        $display("\n[%s] Scoreboard summary", name);
        $display("  total samples   : %0d", total_samples);
        $display("  total errors    : %0d", error_count);
        $display("  data mismatches : %0d", data_mismatch);
        $display("  x mismatches    : %0d", x_mismatch);
        $display("  err mismatches  : %0d", err_mismatch);
        $display("  reset mismatches: %0d", reset_mismatch);
        $display("  coverage        : %0.2f%%", get_coverage());
    endfunction
endclass
`endif
