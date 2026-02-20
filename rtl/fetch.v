module fetch #(
	parameter RESET_ADDR = 32'h00000000
)(
	input wire clk;
	input wire rst_n;
	input wire [31:0] address_in, 
	output wire [31:0] o_mem_raddr;
);




// This module includes the program counter
// But I think not much else
PC i_pc (
	.clk(clk),
	.rst(~rst_n),
	.next_pc(instruction_in), // This is a placeholder, will be updated later
	.current_pc(instruction_out) // This is not used in this module, but can be used for debugging
);



endmodule