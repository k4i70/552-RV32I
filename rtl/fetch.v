module fetch #(
	parameter RESET_ADDR = 32'h00000000
)(
	input wire clk,
	input wire rst_n,
	input wire [31:0] address_in, 
	output wire [31:0] o_mem_raddr
);


// This is the PC register. 
assign address_in = (rst_n) ? RESET_ADDR : o_mem_raddr;







endmodule