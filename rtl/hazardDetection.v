module hazardDetection(
	input wire [4:0] i_rs1_raddr,
	input wire [4:0] i_rs2_raddr,
	input wire [4:0] EM_rd,
	input wire EM_reg_write,
	input wire [4:0] MW_rd,
	input wire MW_reg_write,
	output wire stall
);

	// rs1 hazard:
	assign stall = ((EM_reg_write && (EM_rd != 0) && ((EM_rd == i_rs1_raddr) || (EM_rd == i_rs2_raddr))) ||
				(MW_reg_write && (MW_rd != 0) && ((MW_rd == i_rs1_raddr) || (MW_rd == i_rs2_raddr))));


endmodule