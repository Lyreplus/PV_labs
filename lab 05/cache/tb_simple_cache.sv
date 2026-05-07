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

    logic read_prev, write_prev;
    logic valid_accessed;

    // needed for coverage
    assign valid_accessed = dut.valid_array[dut.index];

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

    always_ff @(posedge clk) begin
        if (reset) begin
            read_prev  <= 0;
            write_prev <= 0;
        end else begin
            read_prev  <= read;
            write_prev <= write;
        end
    end

    // ADD COVERAGE STATEMENTS HERE

    covergroup cache_cov @(posedge clk iff !reset);
        option.per_instance = 1;
        option.name = "Coverage for simple_cache";

        tag_bin: coverpoint dut.tag {
            bins tag = {[dut.TAG_WIDTH-1:0]};
        } 

        index_bin: coverpoint dut.index {
            bins index = {[dut.INDEX_WIDTH-1:0]};
        }

        offset_bin: coverpoint dut.offset {
            bins offset = {[dut.OFFSET_WIDTH-1:0]};
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

        hit_miss_cross: cross hit, valid_accessed {
            bins hit_valid   = binsof(hit) intersect {1'b1} && binsof(valid_accessed) intersect {1'b1};
            bins miss_valid  = binsof(hit) intersect {1'b0} && binsof(valid_accessed) intersect {1'b1};
            bins hit_invalid = binsof(hit) intersect {1'b1} && binsof(valid_accessed) intersect {1'b0};
            bins miss_invalid= binsof(hit) intersect {1'b0} && binsof(valid_accessed) intersect {1'b0};
        }

        read_write_prev_hit: cross read_prev, write_prev, hit {
            bins read_hit       = binsof(read_prev) intersect {1'b1} && binsof(write_prev) intersect {1'b0} && binsof(hit) intersect {1'b1};
            bins read_miss      = binsof(read_prev) intersect {1'b1} && binsof(write_prev) intersect {1'b0} && binsof(hit) intersect {1'b0};
            
            bins write_hit      = binsof(read_prev) intersect {1'b0} && binsof(write_prev) intersect {1'b1} && binsof(hit) intersect {1'b1};
            bins write_miss     = binsof(read_prev) intersect {1'b0} && binsof(write_prev) intersect {1'b1} && binsof(hit) intersect {1'b0};
            
            bins collision_hit  = binsof(read_prev) intersect {1'b1} && binsof(write_prev) intersect {1'b1} && binsof(hit) intersect {1'b1};
            bins collision_miss = binsof(read_prev) intersect {1'b1} && binsof(write_prev) intersect {1'b1} && binsof(hit) intersect {1'b0};
            
            bins idle           = binsof(read_prev) intersect {1'b0} && binsof(write_prev) intersect {1'b0} && binsof(hit) intersect {1'b0};
            illegal_bins fake   = binsof(read_prev) intersect {1'b0} && binsof(write_prev) intersect {1'b0} && binsof(hit) intersect {1'b1};
        }

    endgroup

    covergroup cache_cov_reset @(posedge clk);
        option.per_instance = 1;
        option.name = "Coverage for simple_cache - reset behavior";
        
        reset_cp: coverpoint dut.reset {
            bins reset_active = {1'b1};
            bins reset_inactive = {1'b0};
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
    cache_cov_reset cov_reset = new();

endmodule