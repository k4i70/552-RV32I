module memoryAccess (
	input wire clk,
	input wire rst_n,
	input wire mem_write,
	input wire [31:0] alu_result, 
	input wire [31:0] rs2_data, // Needs this for store instructions
	output wire [31:0] o_dmem_addr, 
	output wire [31:0] o_dmem_wdata,
	input wire o_dmem_ren,
	input wire o_dmem_wen,
	input wire [3:0] o_dmem_mask
	output wire [31:0] i_dmem_rdata
);

// Using external interface for memory address
assign o_dmem_addr = alu_result;

assign o_dmem_wdata = rs2_data;

// For now, just read values when mem_write is low
assign dmem_ren = ~mem_write;
assign dmem_wen = mem_write;  

// Dmem mask 


endmodule