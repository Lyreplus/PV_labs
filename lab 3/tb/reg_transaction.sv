`ifndef REG_TRANSACTION_SV
`define REG_TRANSACTION_SV

// used later with mailbox in monitor and scoreboard
class reg_transaction;
// random transaction 
	rand bit wr_en;
	rand bit [4:0] wr_addr;
	rand bit [15:0] wr_data;
	rand bit [4:0] rd_addr1;
	rand bit [4:0] rd_addr2;
	rand bit illegal_en;

	bit is_end;
	bit illegal;

// Constraints
	constraint addr_c {
		wr_addr inside {[0:31]};
		rd_addr1 inside {[0:31]};
		rd_addr2 inside {[0:31]};
	}

//weighted randomization to increase the likelihood of generating write transactions, illegal_en flag is also randomized 
	constraint wr_en_c { wr_en dist {1 := 1, 0 := 1}; }

	constraint illegal_dist { illegal_en dist {1 := 1, 0 := 3}; }

// data corner cases, 96 % of the time random
	constraint data_corners {
		wr_data dist {
			16'h0000 := 1,
			16'hFFFF := 1,
			16'hAAAA := 1,
			16'h5555 := 1,
			[0:16'hFFFF] :/ 96
		};
	}

// address collision bias 
	constraint addr_collisions {
		rd_addr1 dist { rd_addr2 := 2, [0:31] :/ 8 };
		wr_addr dist { rd_addr1 := 1, rd_addr2 := 1, [0:31] :/ 8 };
	}

// illegal transaction:
// - rd_addr1 and rd_addr2 the same
// - wr_en is high and wr_addr matches rd_addr1 or rd_addr2

	constraint illegal_c {
		if (illegal_en) {
			(rd_addr1 == rd_addr2) ||
			(wr_en && ((wr_addr == rd_addr1) || (wr_addr == rd_addr2)));
		} else {
			rd_addr1 != rd_addr2;
			if (wr_en) {
				wr_addr != rd_addr1;
				wr_addr != rd_addr2;
			}
		}
	}

// non end and legal by default
	function new();
		is_end = 1'b0;
		illegal = 1'b0;
	endfunction

// calculation of illegal flag
	function void post_randomize();
		illegal = (rd_addr1 == rd_addr2) ||
				  (wr_en && ((wr_addr == rd_addr1) || (wr_addr == rd_addr2)));
	endfunction

	function reg_transaction copy();
		reg_transaction tr = new();
		tr.wr_en = wr_en;
		tr.wr_addr = wr_addr;
		tr.wr_data = wr_data;
		tr.rd_addr1 = rd_addr1;
		tr.rd_addr2 = rd_addr2;
		tr.illegal_en = illegal_en;
		tr.is_end = is_end;
		tr.illegal = illegal;
		return tr;
	endfunction
endclass

class reg_observation;
	time ts;
	logic rst_n;
	logic wr_en;
	logic [4:0] wr_addr;
	logic [15:0] wr_data;
	logic [4:0] rd_addr1;
	logic [4:0] rd_addr2;
	logic [15:0] rd_data1;
	logic [15:0] rd_data2;
	logic err;
endclass

`endif
