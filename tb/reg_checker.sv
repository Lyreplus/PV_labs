`ifndef REG_CHECKER_SV
`define REG_CHECKER_SV

`include "reg_if.sv"

module reg_checker #(string NAME = "dut")(reg_if.chk_mp rif);
    logic illegal_comb;
    integer log_fh;

    function void log_error(string msg);
        if (log_fh) begin
            $fdisplay(log_fh, "%0t %s", $time, msg);
        end
    endfunction

    initial begin
        log_fh = $fopen({NAME, "_errors.log"}, "a");
    end

    always_comb begin
        illegal_comb = (rif.rd_addr1 == rif.rd_addr2) ||
                       (rif.wr_en && ((rif.wr_addr == rif.rd_addr1) || (rif.wr_addr == rif.rd_addr2)));
    end

    // err reflects illegal condition of the previous cycle
    property err_registered;
        @(posedge rif.clk) disable iff (!rif.rst_n)
            rif.err == $past(illegal_comb);
    endproperty

    // err cleared during reset
    property err_reset;
        @(posedge rif.clk)
            (!rif.rst_n) |-> (rif.err == 1'b0);
    endproperty

    // addresses stable within a clock cycle
    property addr_stable;
        @(posedge rif.clk) disable iff (!rif.rst_n)
            $stable(rif.rd_addr1) && $stable(rif.rd_addr2) &&
            $stable(rif.wr_addr) && $stable(rif.wr_en);
    endproperty

    assert property (err_registered)
        else log_error("REQ-010: err not registered as previous illegal condition");

    assert property (err_reset)
        else log_error("REQ-002: err not cleared during reset");

    assert property (addr_stable)
        else log_error("TB: addresses changed within a clock cycle");

    // illegal, outputs must be X immediately
    always_comb begin
        if (rif.rst_n && illegal_comb) begin
            if (rif.rd_data1 !== {16{1'bx}}) begin
                log_error("REQ-009: rd_data1 not X during illegal condition");
            end
            if (rif.rd_data2 !== {16{1'bx}}) begin
                log_error("REQ-009: rd_data2 not X during illegal condition");
            end
        end
    end

    final begin
        if (log_fh) begin
            $fclose(log_fh);
            log_fh = 0;
        end
    end
endmodule
`endif
