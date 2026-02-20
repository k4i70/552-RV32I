module memoryAccess (
	input wire clk,
	input wire rst_n,
	input wire mem_write,
	input wire [31:0] alu_result, 
	input wire [31:0] rs2_data, // Needs this for store instructions
	output wire [31:0] o_dmem_addr, 
	output wire [31:0] o_dmem_wdata,
	input wire dmem_ren,
	input wire dmem_wen
);

// Using external interface for memory address





endmodule