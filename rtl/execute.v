module execute (
	input wire alu_src_op,
	input wire [2:0] alu_op,
	input wire [31:0] rs1_data,
	input wire [31:0] rs2_data,
	input wire [31:0] immediate,
	output wire [31:0] alu_result,
	input wire i_sub,
	input wire i_unsigned,
	input wire i_arith,
	input wire alu_pc_op,
	input wire [31:0] PC,
	input wire lui_op
);

// Most of this instantiates our ALU we already made
wire [31:0] op1_muxed = (alu_pc_op) ? PC : (lui_op) ? 32'b0 : rs1_data; // AUIPC uses PC, LUI uses 0, otherwise rs1. 
wire [31:0] rs2_data_muxed = (alu_src_op) ? immediate : rs2_data; // Choose between intermediate and rs2. 

alu i_alu (
	.i_opsel(alu_op),
	.i_unsigned(i_unsigned),
	.i_sub(i_sub),
	.i_arith(i_arith),
	.i_op1(op1_muxed),
	.i_op2(rs2_data_muxed),
	.o_result(alu_result)
);
endmodule