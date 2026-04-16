`ifndef REG_CHECKER_SV
`define REG_CHECKER_SV

`include "reg_if.sv"

module reg_checker(reg_if.chk_mp rif);
    logic illegal_comb;

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
        else $error("err not registered as previous illegal condition");

    assert property (err_reset)
        else $error("err not cleared during reset");

    assert property (addr_stable)
        else $error("addresses changed within a clock cycle");

    // illegal, outputs must be X immediately
    always_comb begin
        if (rif.rst_n && illegal_comb) begin
            assert (rif.rd_data1 === {16{1'bx}})
                else $error("rd_data1 not X during illegal condition");
            assert (rif.rd_data2 === {16{1'bx}})
                else $error("rd_data2 not X during illegal condition");
        end
    end
endmodule
`endif
