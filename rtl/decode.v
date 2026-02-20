module decode #(
	parameter RESET_ADDR = 32'h00000000
) (
	input wire clk,
	input wire rst,
	input wire [4:0] i_rs1_raddr,
	input wire [4:0] i_rs2_raddr,
	input wire i_rd_wen, 
	input wire [4:0] i_rd_waddr,
	input wire [31:0] i_rd_wdata,
	input wire [31:0] i_inst, 
	output wire [31:0] o_rs1_rdata,
	output wire [31:0] o_rs2_rdata,
	output wire [6:0] opcode, 
	output wire [4:0] rd,
	output wire [2:0] funct3,
	output wire [6:0] funct7,
	output wire [31:0] o_immediate 
);



assign opcode = i_inst[6:0]; // Opcode is always used

assign rd = (i_inst[5:0] == 6'b100011) 
	? 5'b0 : i_inst[11:7]; // Not S or B i_instuction

assign funct3 = (i_inst[4:0] == (5'b10111 || 5'b01111)) 
	? 3'b0 : i_inst[14:12] ; // Not U or J i_instuction

assign i_rs1_raddr = (i_inst[4:0] == (5'b10111 || 5'b00111)) 
	? 5'b0 : i_inst[19:15]; // Not U or J i_instuction

assign i_rs2_raddr = (i_inst[4:0] == (5'b10111 || 5'b00111) || 
	i_inst[6:0] == (7'b0010011 || 7'b0000011 || 7'b1100111)) 
	? 5'b0 : i_inst[24:20]; // Not U, J, or I i_instuction

assign funct7 = (i_inst[6:0] == 7'b0110011)
	? i_inst[31:25] : 7'b0; // Only R-type i_instuctions use funct7

// Control Module
control i_control (
	.opcode(opcode),
	.funct3(funct3),
	.funct7(funct7),
	.o_format(i_format)
);



// Also instantiate the register file and immediate generator here
rf i_rf (
	.clk(clk),
	.rst(rst),
	.i_rs1_raddr(i_rs1_raddr),
	.i_rs2_raddr(i_rs2_raddr),
	.i_rd_wen(i_rd_wen),
	.i_rd_waddr(i_rd_waddr),
	.i_rd_wdata(i_rd_wdata),
	.o_rs1_rdata(o_rs1_rdata),
	.o_rs2_rdata(o_rs2_rdata)
);

imm i_imm (
	.i_inst(i_inst),
	.i_format(i_format),
	.o_immediate(o_immediate)
);




endmodule