module execute (
	input wire pc_src_op,
	input wire alu_src_op,
	input wire [2:0] alu_op,
	input wire [31:0] rs1_data,
	input wire [31:0] rs2_data,
	input wire [31:0] immediate,
	output wire [31:0] alu_result,
	output wire o_eq,
	output wire o_slt,
	input wire i_sub,
	input wire i_unsigned,
	input wire i_arith,
	input wire [3:0] branch_op,
	output wire [31:0] branch_out,
	input wire jalr_op,
	input wire alu_pc_op,
	input wire [31:0] PC,
	output wire 
);

// Most of this instantiates our ALU we already made
wire [31:0] op1_muxed = (alu_pc_op) ? PC : rs1_data; // If this is a U-type, use PC instead of rs1. 
wire [31:0] rs2_data_muxed = (alu_src_op) ? immediate : rs2_data; // Choose between intermediate and rs2. 

alu i_alu (
	.i_opsel(alu_op),
	.i_unsigned(i_unsigned),
	.i_sub(i_sub),
	.i_arith(i_arith),
	.i_op1(op1_muxed),
	.i_op2(rs2_data_muxed), // Select between rs2 data and immediate based on alu_src_op
	.o_result(alu_result),
	.o_eq(o_eq),
	.o_slt(o_slt)
);

branch i_branch (
	.branch_op(branch_op),
	.slt(o_slt),
	.equal(o_eq),
	.pc_src_op(pc_src_op), // Reuse alu_src_op to determine if this is a branch instruction
	.imm_in(immediate),
	.jalr_op(jalr_op),
	.alu_pc_op(alu_pc_op),
	.pc_in(PC),
	.branch_out(branch_out)
);
endmodule