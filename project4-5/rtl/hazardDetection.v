module hazardDetection(
	input wire [4:0] i_rs1_raddr,
	input wire [4:0] i_rs2_raddr,
	input wire [4:0] DE_rd,
	input wire DE_mem_read,
	output wire stall
);

// Now only stall on Load-Use hazard
assign stall = DE_mem_read && (DE_rd != 0) &&
	((DE_rd == i_rs1_raddr) || (DE_rd == i_rs2_raddr));

endmodule