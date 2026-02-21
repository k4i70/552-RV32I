module writeback #(
	parameter RESET_ADDR = 32'h00000000
)(

	//control signals
	input wire RegWrite,
	input wire [1:0] MemtoReg,
	input wire pc_src_op,

	//register signals
	input wire [4:0] rd,

	
	//data signals
	input wire [31:0] ReadData,
	input wire [31:0] ALUResult,
	input wire [31:0] Branch_out,

	//PC signals
	input wire [31:0] PC,


	//output signals
	output wire [31:0] WriteData,
	output wire [4:0] rd_out,

	//output control signals
	output wire reg_write_wb,
	output wire [31:0] current_PC
);


// Write back Data MUX
assign WriteData = (MemtoReg == 2'b10) ? PC + 32'h4 :
					(MemtoReg == 2'b10)? ReadData:
										ALUResult;
assign rd_out = rd;

// Pass through control signals
assign reg_write_wb = RegWrite;

assign current_PC = (pc_src_op) ? PC + Branch_out : PC + 32'h4;

endmodule