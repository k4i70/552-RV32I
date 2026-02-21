module writeback #(
	parameter RESET_ADDR = 32'h00000000
)(
	input wire clk,
	input wire rst_n,

	//control signals
	input wire PCSrc,
	input wire MemtoReg,

	
	
	//data signals
	input wire ReadData,
	input wire ALUResult,


);



endmodule