module control (
	input wire [6:0] opcode,
	input wire [2:0] funct3,
	input wire [6:0] funct7,
	input wire [5:0] o_format,
	output wire [2:0] alu_op,
	output wire [3:0] branch_op,
	output wire mem_write,
	output wire [1:0] reg_write_source_op,
	output wire reg_write,
	output wire alu_src_op,
	output wire pc_src_op,
	output wire [3:0] o_dmem_mask,
	output wire i_sub,
	output wire i_unsigned,
	output wire i_arith,
	output wire jalr_op,
	output wire alu_pc_op,
	output wire mem_read
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
// This module we get to design, so I'm thinking we have 3 bits for branch op which are funct3, and then have the first bit set for jump isntructions. 
wire jump_op = (o_format == J_TYPE || opcode == 7'b1100111); 
wire [2:0] branch_funct3 = (o_format == B_TYPE) ? funct3 : 3'b0;
assign branch_op = {jump_op, branch_funct3};

// Memory write logic
assign mem_write = (o_format == S_TYPE) ? 1'b1 : 1'b0; 

// Register write  logic
assign reg_write = (o_format == R_TYPE || o_format == I_TYPE || o_format == U_TYPE || o_format == J_TYPE) ? 1'b1 : 1'b0;

// Register write source logic
// 10 for ALU result, 00 for memory load, 01 for JAL instruction. 
// TODO: Verify this logic works, i'm not confident in this assign. 
assign reg_write_source_op = (o_format == J_TYPE || opcode == 7'b1100111) ? 2'b01 : // Catch for JAL and JALR instructions
	(opcode == 7'b0000011) ? 2'b10 : // Loads 
	2'b00; // Everything else we want to just read ALU result

// alu source logic
// 1 for immediate, 0 for rs2
assign alu_src_op = (o_format == R_TYPE || o_format == B_TYPE) ? 1'b0 : 1'b1;

// PC source logic
// 0 for PC + 4, 1 to take the output from the branch addr
assign pc_src_op = (o_format == B_TYPE || o_format == J_TYPE || opcode == 7'b1100111) ? 1'b1 : 1'b0;

// Dmem mask logic
assign o_dmem_mask = (o_format == S_TYPE || opcode == 7'b0000011) ? 
	(funct3[1:0] == 2'b00) ? 4'b0001 : 
	(funct3[1:0] == 2'b01) ? 4'b0011 :
	4'b1111 : 4'b0000;

// Subtract logic for ALU. 
assign i_sub = (o_format == R_TYPE && funct7 == 7'b0100000) ? 1'b1 : 1'b0; // Subtract for sub instruction. 

// i_unsigned logic for sltu instruction
assign i_unsigned = (o_format == R_TYPE && funct3 == 3'b011) 
	|| (o_format == I_TYPE && funct3 == 3'b011) 
	|| (o_format == B_TYPE && funct3[1] == 1'b1) ? 
	1'b1 : 1'b0; 

// i_arith logic for arithmetic right shift instruction
assign i_arith = (o_format == R_TYPE && funct3 == 3'b101 && funct7 == 7'b0100000) 
	|| (o_format == I_TYPE && funct3 == 3'b101 && funct7 == 7'b0100000) ?
	1'b1 : 1'b0;

assign jalr_op = (opcode == 7'b1100111) ? 1'b1 : 1'b0; 

// Allows us to use ALU for calculating AUIPC instructions. 
// LUI just needs the immediate (rs1=x0=0), only AUIPC needs PC as op1.
assign alu_pc_op = (opcode == 7'b0010111) ? 1'b1 : 1'b0; 

assign mem_read = (opcode == 7'b0000011) ? 1'b1 : 1'b0;

endmodule