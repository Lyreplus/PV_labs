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

    clocking cb @(posedge clk);
        default input #1step output #0;
        inout rst_n;
        inout wr_en;
        inout wr_addr;
        inout wr_data;
        inout rd_addr1;
        inout rd_addr2;
        input rd_data1;
        input rd_data2;
        input err;
    endclocking: cb

endinterface //reg_if

`endif