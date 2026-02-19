module decode #(
	parameter RESET_ADDR = 32'h00000000
);

input wire clk;
input wire rst;
input wire [31:0] instr;
output wire [6:0] opcode;
output wire [4:0] rs1;
output wire [4:0] rs2;
output wire [4:0] rd;
output wire [2:0] funct3;
output wire [6:0] funct7;

assign opcode = instr[6:0]; // Opcode is always used

assign rd = (instr[5:0] == 6'b100011) 
	? 5'b0 : instr[11:7]; // Not S or B instruction

assign funct3 = (instr[4:0] == (5'b10111 || 5'b01111)) 
	? 3'b0 : instr[14:12] ; // Not U or J instruction

assign rs1 = (instr[4:0] == (5'b10111 || 5'b00111)) 
	? 5'b0 : instr[19:15]; // Not U or J instruction

assign rs2 = (instr[4:0] == (5'b10111 || 5'b00111) || 
	instr[6:0] == (7'b0010011 || 7'b0000011 || 7'b1100111)) 
	? 5'b0 : instr[24:20]; // Not U, J, or I instruction

assign funct7 = (instr[6:0] == 7'b0110011)
	? instr[31:25] : 7'b0; // Only R-type instructions use funct7



endmodule