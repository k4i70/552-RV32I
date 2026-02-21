module decode #(
	parameter RESET_ADDR = 32'h00000000
) (
	input wire [4:0] i_rs1_raddr,
	input wire [4:0] i_rs2_raddr,
	input wire i_rd_wen, 
	input wire [4:0] i_rd_waddr,
	input wire [31:0] i_rd_wdata,
	input wire [31:0] i_instr, 
	input wire reg_write_wb,
	output wire [31:0] o_rs1_rdata,
	output wire [31:0] o_rs2_rdata,
	output wire [6:0] opcode, 
	output wire [4:0] rd,
	output wire [31:0] o_immediate,
	output wire [5:0] o_format,
	output wire [2:0] alu_op,
	output wire [3:0] branch_op,
	output wire mem_write,
	output wire [1:0] reg_write_source_op,
	output wire reg_write,
	output wire alu_src_op,
	output wire pc_src_op,
	output wire [2:0] o_dmem_mask,
	output wire i_sub,
	output wire i_unsigned,
	output wire i_arith
);

// parameters for instruction formats, used for readability. 
localparam R_TYPE = 6'b000001;
localparam I_TYPE = 6'b000010;
localparam S_TYPE = 6'b000100;
localparam B_TYPE = 6'b001000;
localparam U_TYPE = 6'b010000;
localparam J_TYPE = 6'b100000;

// One hot decoder for instruction format. 
assign o_format = (opcode == 7'b0110011) ? R_TYPE : 
	(opcode == 7'b0010011 || opcode == 7'b0000011 || opcode == 7'b1100111) ? I_TYPE : 
	(opcode == 7'b0100011) ? S_TYPE : 
	(opcode == 7'b1100011) ? B_TYPE : 
	(opcode == 7'b0110111 || opcode == 7'b0010111) ? U_TYPE : 
	(opcode == 7'b1101111) ? J_TYPE : 6'b0; // Default to 0, hopefully don't happen. 

assign opcode = i_instr[6:0]; // Opcode is always used

assign rd = (o_format == S_TYPE || o_format == B_TYPE) 
	? 5'b0 : i_instr[11:7]; // Not S or B i_instruction

assign funct3 = (o_format == U_TYPE || o_format == J_TYPE) 
	? 3'b0 : i_instr[14:12] ; // Not U or J i_instruction

assign i_rs1_raddr = (o_format == U_TYPE || o_format == J_TYPE) 
	? 5'b0 : i_instr[19:15]; // Not U or J i_instruction

assign i_rs2_raddr = (o_format == U_TYPE || o_format == J_TYPE || o_format == I_TYPE) 
	? 5'b0 : i_instr[24:20]; // Not U, J, or I i_instruction

assign funct7 = (o_format == R_TYPE)
	? i_instr[31:25] : 7'b0; // Only R-type i_instructions use funct7

// Control Module
control i_control (
	.opcode(opcode),
	.funct3(funct3),
	.funct7(funct7),
	.o_format(o_format),
	.alu_op(alu_op),
	.branch_op(branch_op),
	.mem_write(mem_write),
	.reg_write_source_op(reg_write_source_op),
	.reg_write(reg_write),
	.alu_src_op(alu_src_op),
	.pc_src_op(pc_src_op),
	.o_dmem_mask(o_dmem_mask),
	.i_sub(i_sub),
	.i_unsigned(i_unsigned),
	.i_arith(i_arith)
);


// Instantiate the register file
rf i_rf (
	.i_rs1_raddr(i_rs1_raddr),
	.i_rs2_raddr(i_rs2_raddr),
	.i_rd_wen(reg_write_wb),
	.i_rd_waddr(i_rd_waddr),
	.i_rd_wdata(i_rd_wdata),
	.o_rs1_rdata(o_rs1_rdata),
	.o_rs2_rdata(o_rs2_rdata)
);

// Link immediate generator here as well
imm i_imm (
	.i_inst(i_instr),
	.i_format(o_format),
	.o_immediate(o_immediate)
);




endmodule