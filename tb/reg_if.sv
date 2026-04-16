`ifndef REG_IF_SV
`define REG_IF_SV

interface reg_if(input bit clk);
    logic rst_n;
    logic wr_en;
    logic [4:0] wr_addr;
    logic [15:0] wr_data;
    logic [4:0] rd_addr1;
    logic [4:0] rd_addr2;
    logic [15:0] rd_data1;
    logic [15:0] rd_data2;
    logic err;

    clocking cb_drv @(negedge clk);
        default input #1step output #1step;
        output rst_n;
        output wr_en;
        output wr_addr;
        output wr_data;
        output rd_addr1;
        output rd_addr2;
    endclocking: cb_drv

    clocking cb_mon @(posedge clk);
        default input #1step output #1step;
        input rst_n;
        input wr_en;
        input wr_addr;
        input wr_data;
        input rd_addr1;
        input rd_addr2;
        input rd_data1;
        input rd_data2;
        input err;
    endclocking: cb_mon

    modport drv_mp (clocking cb_drv);
    modport mon_mp (clocking cb_mon);
    modport chk_mp (input clk, rst_n, wr_en, wr_addr, wr_data, rd_addr1, rd_addr2, rd_data1, rd_data2, err);

    modport dut_mp (
        input clk, rst_n, wr_en, wr_addr, wr_data, rd_addr1, rd_addr2,
        output rd_data1, rd_data2, err
    );
endinterface //reg_if

`endif