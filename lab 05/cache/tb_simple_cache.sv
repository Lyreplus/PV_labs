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

        tag_bin: coverpoint dut.tag {
            bins tag = {[ADDR_WIDTH-1 -: TAG_WIDTH]};

        index_bin: coverpoint dut.index{
            bins index = {[OFFSET_WIDTH+INDEX_WIDTH-1 -: INDEX_WIDTH]};
        }

        offset_bin: coverpoint dut.offset {
            bins offset = {[OFFSET_WIDTH-1 -: OFFSET_WIDTH]};
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
            bins nothing    = binsof(read) intersect {1'b0} && binsof(write) intersect {1'b0};
        }

    endgroup

    // miss on invalid line
    property miss_on_invalid;
        @(posedge clk) disable iff (reset) (read && !dut.valid_array[dut.index]) |-> (hit == 0);
    endproperty

    // hit on valid line with matching tag
    property hit_on_valid;
        @(posedge clk) disable iff (reset) (read && dut.valid_array[dut.index] && dut.tag_array[dut.index] == dut.tag) |-> (hit == 1);
    endproperty

    cover property (miss_on_invalid);
    cover property (hit_on_valid);

    cache_cov cov = new();

endmodule