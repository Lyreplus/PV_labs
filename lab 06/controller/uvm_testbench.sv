`timescale 1ns/1ps
`include "uvm_macros.svh"

package controller_pkg;
    import uvm_pkg::*;

    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 32;

    class controller_transaction extends uvm_sequence_item;
    `uvm_object_utils(controller_transaction)

        // Master 0
        random logic [ADDR_WIDTH-1:0]   addr0;
        random logic [DATA_WIDTH-1:0]   wdata0;
        random logic                    is_write0;
        random logic                    use_m0;

        random logic [ADDR_WIDTH-1:0]   addr1;
        random logic [DATA_WIDTH-1:0]   wdata1;
        random logic                    is_write1;
        random logic                    use_m1;

        random int delay_cycles;
        random bit is_end;

        constraint valid_delay { delay_cycles inside {[0:8]}; }

        function new(string name = "controller_transaction");
            super.new(name);
        endfunction

        function string convert2string();
        return $sformatf("M0: use=%b addr=%0d we=%b | M1: use=%b addr=%0d we=%b | delay=%0d",
                         use_m0, addr0, is_write0, use_m1, addr1, is_write1, delay_cycles);
        endfunction

    endclass : controller_transaction

    class controller_sequencer extends uvm_sequencer #(controller_transaction);
    `uvm_object_utils(controller_sequencer)

        function new(string name = "controller_sequencer");
            super.new(name);
        endfunction

    endclass

    class controller_driver extends uvm_driver #(controller_transaction);
    `uvm_component_utils(controller_driver)
    endclass : controller_driver

    class controller_monitor extends uvm_monitor;
    `uvm_component_utils(controller_monitor)
    endclass : controller_monitor

    class controller_agent extends uvm_agent;
    `uvm_component_utils(controller_agent)
    endclass : controller_agent

    class controller_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(controller_scoreboard)
    endclass : controller_scoreboard

    class controller_en extends uvm_env;
    `uvm_component_utils(controller_env)
    endclass

    class controller_sequence extends uvm_sequence #(controller_transaction);
    `uvm_object_utils(controller_sequence)
    endclass : controller_sequence

    class controller_test extends uvm_test;
    `uvm_component_utils(controller_test)
    endclass: controller_test

endpackage : controller_pkg

module tb_uvm_simple_mem_ctrl;
    import uvm_pkg::*;
    import controller_pkg::*;
    // Parameters must match DUT
    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 32;
endmodule : tb_uvm_simple_mem_ctrl