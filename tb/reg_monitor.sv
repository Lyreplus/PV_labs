`ifndef REG_MONITOR_SV
`define REG_MONITOR_SV

`include "reg_if.sv"
`include "reg_transaction.sv"

class register_monitor;
	virtual reg_if rif;
	mailbox #(reg_observation) mon2scb; // monitor to scoreboard mailbox

	function new(virtual reg_if rif, mailbox #(reg_observation) mon2scb);
		this.rif = rif;
		this.mon2scb = mon2scb;
	endfunction

	task automatic send_sample();
		reg_observation obs = new();
		obs.ts = $time;
		obs.rst_n = rif.cb.rst_n;
		obs.wr_en = rif.cb.wr_en;
		obs.wr_addr = rif.cb.wr_addr;
		obs.wr_data = rif.cb.wr_data;
		obs.rd_addr1 = rif.cb.rd_addr1;
		obs.rd_addr2 = rif.cb.rd_addr2;
		obs.rd_data1 = rif.cb.rd_data1;
		obs.rd_data2 = rif.cb.rd_data2;
		obs.err = rif.cb.err;
		mon2scb.put(obs);
	endtask

	task run();
		forever begin
			@(posedge rif.clk);
			send_sample();
		end
	endtask
endclass
`endif
