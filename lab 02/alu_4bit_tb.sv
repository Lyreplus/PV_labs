`timescale 1ns/1ps

module alu_4bit_tb;

    typedef enum {
        RQ_001, RQ_002,         // Addition
        RQ_003, RQ_004, RQ_005, // Subtraction
        RQ_006, RQ_007,         // AND
        RQ_008, RQ_009,         // OR
        RQ_010, RQ_011,         // XOR
        RQ_012, RQ_013,         // NOT A
        RQ_014, RQ_015,         // Pass A
        RQ_016, RQ_017,         // Pass B
        RQ_018, RQ_019          // Invalid Opcode
    } req_id_e;

    logic [3:0] A, B;
    logic [2:0] op;
    logic [3:0] Y;
    logic carry;

    logic [3:0] expected_Y;
    logic expected_carry;

    integer i, j, k;
    integer errors = 0;
    int error_counts[20];

    alu_4bit_v0 dut (
        .A(A),
        .B(B),
        .op(op),
        .Y(Y),
        .carry(carry)
    );

    task automatic check_field(input req_id_e id,
                    input logic [3:0] actual,
                    input logic [3:0] expected,
                    input string field_name);
        if (actual !== expected) begin
            $display("ERROR [%0s]: Op=%b A=%h B=%h | %s mismatch: Got %b, Expected %b",
                     id.name(), op, A, B, field_name, actual, expected);
            error_counts[id]++;
            errors++;
        end
    endtask

    initial begin
        $display("Starting simulation ALU 4-bit...");
        foreach (error_counts[req]) error_counts[req] = 0;
        errors = 0;

        for (k = 0; k < 8; k = k + 1) begin
            op = k[2:0];
            $display("opcode: %b", op);
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    A = i[3:0];
                    B = j[3:0];
                    #1;

                    case (op)
                        3'b000: begin // ADD
                            {expected_carry, expected_Y} = A + B;
                            check_field(RQ_001, Y, expected_Y, "Y");
                            check_field(RQ_002, carry, expected_carry, "carry");
                        end
                        3'b001: begin // SUB
                            expected_Y = A - B;
                            expected_carry = (A < B);
                            check_field(RQ_003, Y, expected_Y, "Y");
                            if (A < B)
                                check_field(RQ_005, carry, expected_carry, "carry");
                            else
                                check_field(RQ_004, carry, expected_carry, "carry");
                        end
                        3'b010: begin // AND
                            expected_Y = A & B; expected_carry = 0;
                            check_field(RQ_006, Y, expected_Y, "Y");
                            check_field(RQ_007, carry, expected_carry, "carry");
                        end
                        3'b011: begin // OR
                            expected_Y = A | B; expected_carry = 0;
                            check_field(RQ_008, Y, expected_Y, "Y");
                            check_field(RQ_009, carry, expected_carry, "carry");
                        end
                        3'b100: begin // XOR
                            expected_Y = A ^ B; expected_carry = 0;
                            check_field(RQ_010, Y, expected_Y, "Y");
                            check_field(RQ_011, carry, expected_carry, "carry");
                        end
                        3'b101: begin // NOT A
                            expected_Y = ~A; expected_carry = 0;
                            check_field(RQ_012, Y, expected_Y, "Y");
                            check_field(RQ_013, carry, expected_carry, "carry");
                        end
                        3'b110: begin // PASS A
                            expected_Y = A; expected_carry = 0;
                            check_field(RQ_014, Y, expected_Y, "Y");
                            check_field(RQ_015, carry, expected_carry, "carry");
                        end
                        3'b111: begin // PASS B
                            expected_Y = B; expected_carry = 0;
                            check_field(RQ_016, Y, expected_Y, "Y");
                            check_field(RQ_017, carry, expected_carry, "carry");
                        end
                        default: begin
                            expected_Y = 4'b0000;
                            expected_carry = 1'b0;
                            check_field(RQ_018, Y, expected_Y, "Y");
                            check_field(RQ_019, carry, expected_carry, "carry");
                        end
                    endcase
                end
            end
        end

        $display("\n--- SUMMARY ---");
        if (errors == 0)
            $display("\n --- TEST passed");
        else
            $display(" \n --- TEST failed: %0d error(s) ---", errors);
            for (int r = 0; r < 20; r++) begin
                if (error_counts[r] > 0) begin
                    req_id_e req;
                    req = req_id_e'(r);
                    $display("\n Requirement %s: FAILED (%0d errors)", req.name(), error_counts[r]);
                end
            end
        $finish;
    end
endmodule
