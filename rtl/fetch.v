module fetch #(
	parameter RESET_ADDR = 32'h00000000
)(
	input wire i_clk,
	input wire i_rst,
	input wire i_stall,
	input wire [31:0] address_in, 
	output wire [31:0] o_mem_raddr
);


// This is the PC register. 
reg [31:0] PC;


always @(posedge i_clk) begin
	if (i_rst) begin
		PC <= RESET_ADDR;
	end else if (!i_stall) begin
		PC <= address_in;
	end
end

assign o_mem_raddr = PC; 


endmodule