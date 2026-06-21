//timescale
`timescale 1ns/1ps

`define WIDTH 16

interface gcd_if(input logic clk, input logic rst_n);
    // input
    logic               in_valid;
    logic               in_ready;
    logic [WIDTH-1:0]        a_in;     
    logic [WIDTH-1:0]        b_in;

    // output
    logic               out_valid;
    logic               out_ready;
    logic [WIDTH-1:0]        gcd_out;
endinterface


class gcd_sequence_item extends uvm_sequence_item;
    `uvm_object_utils(gcd_sequence_item)

    rand bit [15:0] a;
    rand bit [15:0] b;
    
    rand bit out_ready_delay; 

    bit [15:0] gcd_out;

    constraint c_ready_delay {
        out_ready_delay dist {0 := 80, 1 := 20}; // mostly ready immediately, sometimes stalled
    }

    function new(string name = "gcd_sequence_item");
        super.new(name);
    endfunction
endclass

function void write(gcd_transaction tr);
    int expected_gcd;

    expected_gcd = calculate_gcd(tr.a, tr.b); 
    
    // checker
    if (expected_gcd !== tr.gcd_out) begin
        `uvm_error("FAIL", $sformatf("A=%0d, B=%0d. Expected %0d but got %0d", tr.a, tr.b, expected_gcd, tr.gcd_out))
    end else begin
        `uvm_info("PASS", $sformatf("GCD(%0d, %0d) = %0d is correct.", tr.a, tr.b, tr.gcd_out), UVM_HIGH)
    end
    
    cov_transaction = tr; 
    gcd_cg.sample();
endfunction

// GCD golden model
function int calculate_gcd(int a, int b);
    if (a == 0) return b;
    if (b == 0) return a;
    while (a != b) begin
        if (a > b) a = a - b;
        else       b = b - a;
    end
    return a;
endfunction


covergroup gcd_cg;
    option.per_instance = 1;

    // operand A
    cp_a: coverpoint cov_transaction.a {
        bins zero = {0};
        bins max  = {(1<<WIDTH)-1}; // 2^(WIDTH)-1
        bins others = {[1 : (1<<WIDTH)-2]};
    }

    // Coverpoint for Operand B
    cp_b: coverpoint cov_transaction.b {
        bins zero = {0};
        bins max  = {(1<<WIDTH)-1}; // 2^(WIDTH)-1
        bins others = {[1 : (1<<WIDTH)-2]};
    }

    // hit edge cases
    cross_a_b: cross cp_a, cp_b;
    
    cp_math_states: coverpoint {cov_transaction.a > cov_transaction.b} {
        bins a_greater_b = {1};
        bins b_greater_a = {0}; 
    }
    
    cp_equal: coverpoint {cov_transaction.a == cov_transaction.b} {
        bins a_equals_b = {1}; // GCD(A,A)
    }
endgroup


property p_input_stable_when_stalled;
    @(posedge clk) disable iff (!rst_n)
    (in_valid && !in_ready) |=> (in_valid && $stable(a_in) && $stable(b_in));
endproperty

assert_input_stable: assert property(p_input_stable_when_stalled)
    else $error("PROTOCOL VIOLATION: in_valid dropped or inputs changed while stalled!");

parameter MAX_TIMEOUT = 1000; 

property p_no_infinite_hang;
    @(posedge clk) disable iff (!rst_n)
    (in_valid && in_ready) |=> ##[1:MAX_TIMEOUT] out_valid;
endproperty

assert_no_infinite_hang: assert property(p_no_infinite_hang)
    else $error("TIMEOUT: Module exceeded maximum cycles without asserting out_valid!");

property p_input_stable;
    @(posedge clk) disable iff (!rst_n)
    (in_valid && !in_ready) |=> (in_valid && $stable(a_in) && $stable(b_in));
endproperty
assert_input_stable: assert property(p_input_stable) 
    else $error("Protocol Violation: Inputs changed while stalled");

property p_output_stable;
    @(posedge clk) disable iff (!rst_n)
    (out_valid && !out_ready) |=> (out_valid && $stable(gcd_out));
endproperty
assert_output_stable: assert property(p_output_stable)
    else $error("Protocol Violation: gcd_out changed before out_ready");