// tb_simple_cache.sv
module tb_simple_cache;

    // Parameters
    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 32;

    // DUT signals
    logic clk, reset;
    logic read, write;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] data_in;
    logic [DATA_WIDTH-1:0] data_out;
    logic hit;

    // Instantiate DUT
    simple_cache dut (
        .clk(clk), .reset(reset),
        .read(read), .write(write),
        .addr(addr), .data_in(data_in),
        .data_out(data_out), .hit(hit)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Reset
        clk = 0; reset = 1;
        read = 0; write = 0;
        addr = 0; data_in = 0;
        #20 reset = 0;

        // Random stimulus
        repeat (200) begin
            @(posedge clk);
            addr = $urandom_range(0,255);
            if ($urandom_range(0,1)) begin
                read = 1; write = 0;
            end else begin
                read = 0; write = 1;
                data_in = $urandom();
            end
        end

        // ADD ADDITIONAL STIMULUS AS NEEDED HERE

        #50
        $display("TEST FINISHED");
        $finish;
    end

    // ADD COVERAGE STATEMENTS HERE
    covergroup cache_cov @(posedge clk);
        option.per_instance = 1;
        option.name = "Coverage for simple_cache";

        tag_bins: coverpoint dut.tag {
            bins tag_0 = {2'b00};
            bins tag_1 = {2'b01};
            bins tag_2 = {2'b10};
            bins tag_3 = {2'b11};
        }

        index_bins: coverpoint dut.index {
            bins index_0  = {4'b0000};
            bins index_1  = {4'b0001};
            bins index_2  = {4'b0010};
            bins index_3  = {4'b0011};
            bins index_4  = {4'b0100};
            bins index_5  = {4'b0101};
            bins index_6  = {4'b0110};
            bins index_7  = {4'b0111};
            bins index_8  = {4'b1000};
            bins index_9  = {4'b1001};
            bins index_10 = {4'b1010};
            bins index_11 = {4'b1011};
            bins index_12 = {4'b1100};
            bins index_13 = {4'b1101};
            bins index_14 = {4'b1110};
            bins index_15 = {4'b1111};
        }

        offset_bins: coverpoint dut.offset {
            bins offset_0 = {2'b00};
            bins offset_1 = {2'b01};
            bins offset_2 = {2'b10};
            bins offset_3 = {2'b11};
        }

        coverpoint hit {
            bins hit_bin = {1'b1};
            bins miss_bin = {1'b0};
        }

        validity: coverpoint dut.valid_array[dut.index] {
            bins valid_bin = {1'b1};
            bins invalid_bin = {1'b0};
        }

        coverpoint write;
        coverpoint read;

        read_write: cross read, write {
            bins read_only  = binsof(read) intersect {1'b1} && binsof(write) intersect {1'b0};
            bins write_only = binsof(read) intersect {1'b0} && binsof(write) intersect {1'b1};
            bins illegal    = binsof(read) intersect {1'b1} && binsof(write) intersect {1'b1};
        }

    endgroup

    cache_cov cov = new();

endmodule