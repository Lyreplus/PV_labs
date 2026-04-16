`ifndef REG_SCOREBOARD_SV
`define REG_SCOREBOARD_SV

`include "reg_if.sv"
`include "reg_transaction.sv"

class reg_scoreboard;
    string name;
    virtual reg_if rif;
    mailbox #(reg_observation) mon2scb;
    integer log_fh;

    logic [15:0] mem [0:31];
    bit prev_illegal;
    bit prev_illegal_same;
    bit prev_illegal_conflict;

    bit last_write_valid;
    logic [4:0] last_write_addr;
    logic [15:0] last_write_data;

    bit illegal_write_pending;
    logic [4:0] illegal_write_addr;
    logic [15:0] illegal_write_data;

    bit reset_released;

    bit req_fail[1:10];
    int req_fail_count[1:10];

    int total_samples;
    int error_count;
    int data_mismatch;
    int err_mismatch;
    int reset_mismatch;
    int x_mismatch;
    int verbose;

    function new(string name, virtual reg_if rif, mailbox #(reg_observation) mon2scb);
        this.name = name;
        this.rif = rif;
        this.mon2scb = mon2scb;
        log_fh = $fopen({name, "_errors.log"}, "a");
        if (!$value$plusargs("VERBOSE_LOG=%d", verbose)) begin
            verbose = 0;
        end
        total_samples = 0;
        error_count = 0;
        data_mismatch = 0;
        err_mismatch = 0;
        reset_mismatch = 0;
        x_mismatch = 0;
        for (int i = 1; i <= 10; i++) begin
            req_fail[i] = 1'b0;
            req_fail_count[i] = 0;
        end
        reset_model();
    endfunction

    function void reset_model();
        for (int i = 0; i < 32; i++) begin
            mem[i] = 16'h0000;
        end
        prev_illegal = 1'b0;
        prev_illegal_same = 1'b0;
        prev_illegal_conflict = 1'b0;
        last_write_valid = 1'b0;
        illegal_write_pending = 1'b0;
        reset_released = 1'b0;
    endfunction

    function bit is_all_x(logic [15:0] data);
        return (data === {16{1'bx}});
    endfunction

    function bit is_illegal(logic wr_en, logic [4:0] wr_addr,
                            logic [4:0] rd_addr1, logic [4:0] rd_addr2);
        return (rd_addr1 == rd_addr2) ||
               (wr_en && ((wr_addr == rd_addr1) || (wr_addr == rd_addr2)));
    endfunction

    task mark_req_fail(ref bit req_hit[1:10], input int idx, input string msg);
        if (!req_hit[idx]) begin
            req_fail_count[idx]++;
            req_hit[idx] = 1'b1;
        end
        req_fail[idx] = 1'b1;
        error_count++;
        log_error(msg);
    endtask

    function void log_error(string msg);
        if (log_fh) begin
            $fdisplay(log_fh, "%0t %s", $time, msg);
        end
    endfunction

    function string req_fail_string();
        string s;
        s = "";
        for (int i = 1; i <= 10; i++) begin
            if (req_fail[i]) begin
                if (s.len() > 0) begin
                    s = {s, ", "};
                end
                s = {s, $sformatf("REQ-%0d", i)};
            end
        end
        if (s.len() == 0) begin
            s = "NONE";
        end
        return s;
    endfunction

    function int get_error_count();
        return error_count;
    endfunction

    function int get_req_fail_count(int idx);
        if (idx >= 1 && idx <= 10) begin
            return req_fail_count[idx];
        end
        return 0;
    endfunction

    task close_log();
        if (log_fh) begin
            $fclose(log_fh);
            log_fh = 0;
        end
    endtask

    task process_posedge(reg_observation obs);
        bit illegal;
        bit illegal_same;
        bit illegal_conflict;
        bit rd1_mismatch;
        bit rd2_mismatch;
        bit req_hit[1:10];
        logic [15:0] exp_rd1;
        logic [15:0] exp_rd2;
        logic exp_err;

        total_samples++;

        for (int i = 1; i <= 10; i++) begin
            req_hit[i] = 1'b0;
        end

        if (obs.rst_n === 1'b0) begin
            if (obs.err !== 1'b0) begin
                reset_mismatch++;
                err_mismatch++;
                mark_req_fail(req_hit, 2, "REQ-002: err not cleared during reset");
            end
            if ((obs.rd_addr1 != obs.rd_addr2) && (obs.wr_en === 1'b0)) begin
                if ((obs.rd_data1 !== 16'h0000) || (obs.rd_data2 !== 16'h0000)) begin
                    reset_mismatch++;
                    mark_req_fail(req_hit, 1, "REQ-001: registers not cleared during reset");
                end
            end
            reset_model();
            return;
        end

        reset_released = 1'b1;

        illegal_same = (obs.rd_addr1 == obs.rd_addr2);
        illegal_conflict = obs.wr_en && ((obs.wr_addr == obs.rd_addr1) || (obs.wr_addr == obs.rd_addr2));
        illegal = illegal_same || illegal_conflict;
        exp_err = prev_illegal;

        if (obs.err !== exp_err) begin
            err_mismatch++;
            mark_req_fail(req_hit, 10, "REQ-010: err not registered from previous illegal");
            if (prev_illegal_same) begin
                mark_req_fail(req_hit, 6, "REQ-006: err not asserted for rd_addr1 == rd_addr2");
            end
            if (prev_illegal_conflict) begin
                mark_req_fail(req_hit, 7, "REQ-007: err not asserted for write/read conflict");
            end
        end

        if (illegal) begin
            if (!is_all_x(obs.rd_data1) || !is_all_x(obs.rd_data2)) begin
                x_mismatch++;
                mark_req_fail(req_hit, 9, "REQ-009: read data not X during illegal condition");
            end
        end else begin
            exp_rd1 = mem[obs.rd_addr1];
            exp_rd2 = mem[obs.rd_addr2];
            rd1_mismatch = (obs.rd_data1 !== exp_rd1);
            rd2_mismatch = (obs.rd_data2 !== exp_rd2);

            if (rd1_mismatch || rd2_mismatch) begin
                data_mismatch++;
                mark_req_fail(req_hit, 5, "REQ-005: read data mismatch");

                if (last_write_valid) begin
                    if ((rd1_mismatch && (obs.rd_addr1 == last_write_addr)) ||
                        (rd2_mismatch && (obs.rd_addr2 == last_write_addr))) begin
                        mark_req_fail(req_hit, 3, "REQ-003: write update not observed on read");
                    end
                end

                if (illegal_write_pending &&
                    ((obs.rd_addr1 == illegal_write_addr) || (obs.rd_addr2 == illegal_write_addr))) begin
                    mark_req_fail(req_hit, 8, "REQ-008: illegal write updated register");
                    illegal_write_pending = 1'b0;
                end
            end else if (illegal_write_pending &&
                       ((obs.rd_addr1 == illegal_write_addr) || (obs.rd_addr2 == illegal_write_addr))) begin
                illegal_write_pending = 1'b0;
            end
        end

        if (obs.wr_en && !illegal) begin
            mem[obs.wr_addr] = obs.wr_data;
            last_write_valid = 1'b1;
            last_write_addr = obs.wr_addr;
            last_write_data = obs.wr_data;
            if (illegal_write_pending && (obs.wr_addr == illegal_write_addr)) begin
                illegal_write_pending = 1'b0;
            end
        end

        if (illegal && obs.wr_en) begin
            illegal_write_pending = 1'b1;
            illegal_write_addr = obs.wr_addr;
            illegal_write_data = obs.wr_data;
        end

        prev_illegal = illegal;
        prev_illegal_same = illegal_same;
        prev_illegal_conflict = illegal_conflict;
    endtask

    task process_async(reg_observation obs);
        bit illegal;
        bit rd1_mismatch;
        bit rd2_mismatch;
        bit req_hit[1:10];
        logic [15:0] exp_rd1;
        logic [15:0] exp_rd2;

        if (!reset_released || obs.rst_n !== 1'b1) begin
            return;
        end

        for (int i = 1; i <= 10; i++) begin
            req_hit[i] = 1'b0;
        end

        if ($isunknown({obs.rd_addr1, obs.rd_addr2, obs.wr_addr, obs.wr_en})) begin
            return;
        end

        illegal = is_illegal(obs.wr_en, obs.wr_addr, obs.rd_addr1, obs.rd_addr2);
        if (illegal) begin
            if (!is_all_x(obs.rd_data1) || !is_all_x(obs.rd_data2)) begin
                x_mismatch++;
                mark_req_fail(req_hit, 9, "REQ-009: read data not X during illegal condition (async)");
            end
        end else begin
            if (obs.wr_en === 1'b1) begin
                return;
            end
            exp_rd1 = mem[obs.rd_addr1];
            exp_rd2 = mem[obs.rd_addr2];
            rd1_mismatch = (obs.rd_data1 !== exp_rd1);
            rd2_mismatch = (obs.rd_data2 !== exp_rd2);
            if (rd1_mismatch || rd2_mismatch) begin
                data_mismatch++;
                mark_req_fail(req_hit, 4, "REQ-004: read data not updating immediately on addr change");
                mark_req_fail(req_hit, 5, "REQ-005: read data mismatch (async)");
                if (verbose > 0) begin
                    log_error($sformatf("ASYNC rd1 addr=%0d exp=%0h got=%0h rd2 addr=%0d exp=%0h got=%0h wr_en=%0b wr_addr=%0d",
                                        obs.rd_addr1, exp_rd1, obs.rd_data1,
                                        obs.rd_addr2, exp_rd2, obs.rd_data2,
                                        obs.wr_en, obs.wr_addr));
                end
            end
        end
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

    function void report(string name);
        $display("\n[%s] Scoreboard summary", name);
        $display("  total samples   : %0d", total_samples);
        $display("  total errors    : %0d", error_count);
        $display("  data mismatches : %0d", data_mismatch);
        $display("  x mismatches    : %0d", x_mismatch);
        $display("  err mismatches  : %0d", err_mismatch);
        $display("  reset mismatches: %0d", reset_mismatch);
    endfunction
endclass
`endif
