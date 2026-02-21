module fetch #(
	parameter RESET_ADDR = 32'h00000000
)(
	input wire i_clk,
	input wire i_rst,
	input wire [31:0] address_in, 
	output wire [31:0] o_mem_raddr,
	output wire o_retire_valid
);


// This is the PC register. 
// This is where the clock cycle is set, rest is combinational.
reg [31:0] PC;
reg PC_valid; 


always @(posedge i_clk) begin
	if (i_rst) begin
		PC <= RESET_ADDR; // On reset, set PC to reset address
		PC_valid <= 1'b0; // On reset, PC is not valid
	end else if (!PC_valid) begin
		// First cycle after reset: keep PC at RESET_ADDR, just assert valid
		PC_valid <= 1'b1;
	end else begin
		PC <= address_in; // Otherwise, update PC to the next instruction address
	end
end

assign o_mem_raddr = PC; 
assign o_retire_valid = PC_valid; 



endmodule