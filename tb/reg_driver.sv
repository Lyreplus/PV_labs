`ifndef REG_DRIVER_SV
`define REG_DRIVER_SV

`include "reg_if.sv"
`include "reg_transaction.sv"

class register_driver;
    virtual reg_if rif;
    mailbox #(reg_transaction) gen2drv;
    bit done;

    function new(virtual reg_if rif, mailbox #(reg_transaction) gen2drv);
        this.rif = rif;
        this.gen2drv = gen2drv;
        this.done = 1'b0;
    endfunction

    task automatic init_signals();
        rif.cb_drv.rst_n <= 1'b1;
        rif.cb_drv.wr_en <= 1'b0;
        rif.cb_drv.wr_addr <= '0;
        rif.cb_drv.wr_data <= '0;
        rif.cb_drv.rd_addr1 <= '0;
        rif.cb_drv.rd_addr2 <= '0;
    endtask

// reset of the DUT
    task automatic reset_dut();
        init_signals();
        rif.cb_drv.rst_n <= 1'b0;
        @(posedge rif.clk);
        rif.cb_drv.rst_n <= 1'b1;
        @(posedge rif.clk); // ensure DUT has time to come out of reset before starting transactions
    endtask

    task run();
        reg_transaction tr;
        forever begin
            gen2drv.get(tr);
            if (tr.is_end) begin
                rif.cb_drv.wr_en <= 1'b0;
                done = 1'b1;
                break;
            end

            @(rif.cb_drv); //driver clocking block
            rif.cb_drv.wr_en <= tr.wr_en;
            rif.cb_drv.wr_addr <= tr.wr_addr;
            rif.cb_drv.wr_data <= tr.wr_data;
            rif.cb_drv.rd_addr1 <= tr.rd_addr1;
            rif.cb_drv.rd_addr2 <= tr.rd_addr2;
        end
    endtask
endclass
`endif