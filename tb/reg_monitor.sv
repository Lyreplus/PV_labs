`ifndef REG_MONITOR_SV
`define REG_MONITOR_SV

`include "reg_if.sv"
`include "reg_transaction.sv"

class register_monitor;
	virtual reg_if rif;
	mailbox #(reg_observation) mon2scb;
	bit done;
	bit addr_pending;

	function new(virtual reg_if rif, mailbox #(reg_observation) mon2scb);
		this.rif = rif;
		this.mon2scb = mon2scb;
		this.done = 1'b0;
		this.addr_pending = 1'b0;
	endfunction

	task automatic send_sample(sample_kind_t kind);
		reg_observation obs = new();
		obs.kind = kind;
		obs.ts = $time;
		if (kind == SAMPLE_POSEDGE) begin
			obs.rst_n = rif.cb_mon.rst_n;
			obs.wr_en = rif.cb_mon.wr_en;
			obs.wr_addr = rif.cb_mon.wr_addr;
			obs.wr_data = rif.cb_mon.wr_data;
			obs.rd_addr1 = rif.cb_mon.rd_addr1;
			obs.rd_addr2 = rif.cb_mon.rd_addr2;
			obs.rd_data1 = rif.cb_mon.rd_data1;
			obs.rd_data2 = rif.cb_mon.rd_data2;
			obs.err = rif.cb_mon.err;
		end else begin
			#1step;
			obs.rst_n = rif.rst_n;
			obs.wr_en = rif.wr_en;
			obs.wr_addr = rif.wr_addr;
			obs.wr_data = rif.wr_data;
			obs.rd_addr1 = rif.rd_addr1;
			obs.rd_addr2 = rif.rd_addr2;
			obs.rd_data1 = rif.rd_data1;
			obs.rd_data2 = rif.rd_data2;
			obs.err = rif.err;
		end
		mon2scb.put(obs);
	endtask

	task run(ref bit stop_flag);
		fork : mon_threads
			begin : posedge_thread
				int flush = 0;
				forever begin
					@(posedge rif.clk);
					send_sample(SAMPLE_POSEDGE);
					if (stop_flag) begin
						flush++;
						if (flush >= 2) begin
							done = 1'b1;
							disable mon_threads;
						end
					end
				end
			end
			begin : addr_thread
				forever begin
					@(rif.rd_addr1 or rif.rd_addr2);
					if (!addr_pending) begin
						addr_pending = 1'b1;
						fork
							begin
								#1step;
								send_sample(SAMPLE_ADDR_CHANGE);
								addr_pending = 1'b0;
							end
						join_none
					end
				end
			end
		join
	endtask
endclass
`endif
