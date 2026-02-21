module control (
	input wire [6:0] opcode,
	input wire [2:0] funct3,
	input wire [6:0] funct7,
	input wire [5:0] o_format,
	output wire [2:0] alu_op,
	output wire [2:0] branch_op,
	output wire mem_write,
	output wire [1:0] reg_write_source_op,
	output wire reg_write,
	output wire alu_src_op,
	output wire pc_src_op,
	output wire [2:0] o_dmem_mask
);

// parameters for instruction formats, used for readability. 
// Copied from decode module
localparam R_TYPE = 6'b000001;
localparam I_TYPE = 6'b000010;
localparam S_TYPE = 6'b000100;
localparam B_TYPE = 6'b001000;
localparam U_TYPE = 6'b010000;
localparam J_TYPE = 6'b100000;

// ALU op control logic
// Can assign funct3 to ALU_op for R-type and I-type instructions due to the design of the ALU
assign alu_op = (o_format == R_TYPE || o_format == I_TYPE) ? funct3 : 3'b0;

// Branch op logic
// This module we get to design, so I'm thinking we have 3 bits for branch op, and just pass the funct3 and have that logic handle it. 
assign branch_op = (o_format == B_TYPE) ? funct3 : 3'b0;

// Memory write logic
assign mem_write = (o_format == S_TYPE) ? 1'b1 : 1'b0; 

// Register write  logic
assign reg_write = (o_format == R_TYPE || o_format == I_TYPE || o_format == U_TYPE || o_format == J_TYPE) ? 1'b1 : 1'b0;

// Register write source logic
// 10 for ALU result, 00 for memory load, 01 for JAL instruction. 
// TODO: Verify this logic works, i'm not confident in this assign. 
assign reg_write_source_op = (o_format == J_TYPE || opcode == 7'b1100111) ? 2'b01 : // Catch for JAL and JALR instructions
	(o_format == R_TYPE || o_format == I_TYPE || o_format == U_TYPE) ? 2'b10 : 
	(o_format == S_TYPE || o_format == B_TYPE) ? 2'b00 : 
	2'b11; // Default to 11, just becuase

// alu source logic
// 1 for w_op2, 0 for immediate output
assign alu_src_op = (o_format == R_TYPE) ? 1'b0 : 1'b1;

// PC source logic
// 0 for PC + 4, 1 to take the output from the branch addr
assign pc_src_op = (o_format == B_TYPE || o_format == J_TYPE || opcode == 7'b1100111) ? 1'b1 : 1'b0;

// Dmem mask logic
assign o_dmem_mask = (o_format == S_TYPE) ? funct3 : 3'b0;



endmodule