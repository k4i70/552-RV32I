module PC #(
	parameter RESET_ADDR = 32'h00000000
)(
	input clk;
	input rst;
	input [31:0] next_pc;
	output reg [31:0] current_pc;
);

// This is the program counter implementation
always @(posedge clk) begin
	if (rst) begin
		current_pc <= RESET_ADDR;
	end else begin
		current_pc <= next_pc;
	end
end



endmodule