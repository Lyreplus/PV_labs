module packet (
    input  wire clk,
    input  wire reset,
    input  wire start_pkt,
    input  wire hdr_done,
    input  wire payload_done,
    input  wire chk_ok,
    input  wire chk_fail,
    input  wire abort,
    output reg  valid_pkt,
    output reg  error_pkt,
    output reg [2:0] state
);

    // State encoding
    localparam IDLE     = 3'd0;
    localparam HEADER   = 3'd1;
    localparam PAYLOAD  = 3'd2;
    localparam CHECKSUM = 3'd3;
    localparam DONE     = 3'd4;

    always @(posedge clk) begin
        if (reset) begin
            state     <= IDLE;
            valid_pkt <= 0;
            error_pkt <= 0;
        end else begin
            valid_pkt <= 0;
            error_pkt <= 0;
            if (abort) begin
                state <= IDLE;
            end else begin
                case (state)
                    IDLE:    if (start_pkt) state <= HEADER;
                    HEADER:  if (hdr_done)  state <= PAYLOAD;
                    PAYLOAD: if (payload_done) state <= CHECKSUM;
                    CHECKSUM: begin
                        if (chk_ok) begin
                            state     <= DONE;
                            valid_pkt <= 1;
                        end else if (chk_fail) begin
                            state     <= IDLE;
                            error_pkt <= 1;
                        end
                    end
                    DONE:    state <= IDLE;
                    default: state <= IDLE;
                endcase
            end
        end
    end

    // FORMAL STATEMENTS BELOW --------------------------------

`ifdef FORMAL
    initial assume(reset);


    idle_after_reset: assert property (@(posedge clk) reset |=> (state == IDLE));
    flags_zero_after_reset: assume property (@(posedge clk) reset |=> (chk_ok == 1'b0 && chk_fail == 1'b0));
    
    only_one_chk_flag: assume property (@(posedge clk) disable iff (reset) (state == CHECKSUM) |-> (chk_ok != chk_fail));

    //ALWAYS A STATE

    always_a_state: assert property (@(posedge clk) disable iff (reset) state == IDLE       ||
                                                        state == HEADER     ||
                                                        state == PAYLOAD    ||
                                                        state == CHECKSUM   ||
                                                        state == DONE
                                                        );

    // CORRECT STATE
    done_if_valid: assert property (@(posedge clk) disable iff (reset) valid_pkt |-> (state == DONE));
    idle_if_error: assert property (@(posedge clk) disable iff (reset) error_pkt |-> (state == IDLE));

    // STATE TRANSITIONS
    header_after_idle: assert property (@(posedge clk) disable iff (reset) start_pkt && (state == IDLE) && !abort |=> (state == HEADER));
    payload_after_header: assert property (@(posedge clk) disable iff (reset) hdr_done && (state == HEADER) && !abort |=> (state == PAYLOAD));
    checksum_after_payload: assert property (@(posedge clk) disable iff (reset) payload_done && (state == PAYLOAD) && !abort |=> (state == CHECKSUM));
    done_after_checksum_ok: assert property (@(posedge clk) disable iff (reset) chk_ok && (state == CHECKSUM) && !abort |=> (state == DONE));
    idle_after_checksum_fail: assert property (@(posedge clk) disable iff (reset) chk_fail && (state == CHECKSUM) && !abort |=> (state == IDLE));
    idle_after_done: assert property (@(posedge clk) disable iff (reset) (state == DONE) && !abort |=> (state == IDLE));
    idle_after_abort: assert property (@(posedge clk) disable iff (reset) abort |=> (state == IDLE));

    // PUT ASSERTIONS TO STAY IN A STATE UNTIL THE PROPER SIGNALS
    header_if_hdr_not_done: assert property (@(posedge clk) disable iff (reset) (state == HEADER) |-> !hdr_done);
    payload_if_payload_not_done: assert property (@(posedge clk) disable iff (reset) (state == PAYLOAD) |-> !payload_done);

    // MUTEXED SIGNALS
    
`endif

endmodule