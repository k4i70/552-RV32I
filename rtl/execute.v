module execute (
	input wire alu_src_op,
	input wire [2:0] alu_op,
	input wire [31:0] rs1_data,
	input wire [31:0] rs2_data,
	input wire [31:0] immediate,
	output wire [31:0] alu_result
	output wire o_eq,
	output wire o_slt
);

// Most of this instantiates our ALU we already made

wire [31:0] rs2_data_muxed = (alu_src_op) ? immediate : rs2_data; 

alu i_alu (
	.op(alu_op),
	.in1(rs1_data),
	.in2(rs2_data_muxed), // Select between rs2 data and immediate based on alu_src_op
	.result(alu_result)
	.o_eq(o_eq),
	.o_slt(o_slt)
);


endmodule