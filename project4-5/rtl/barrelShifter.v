module barrel_shifter (
	input wire [31:0] in,
	input wire [1:0] shft_amt,
	output wire [31:0] out,
	input wire direction
);


wire [31:0] left_shifted;
wire [31:0] right_shifted;

// Include byte offset as this is only used for memory access. 
assign left_shifted = (shft_amt == 2'b00) ? in :
						(shft_amt == 2'b01) ? {in[23:0], 8'b0} :
						(shft_amt == 2'b10) ? {in[15:0], 16'b0} :
											   {in[7:0], 24'b0};

assign right_shifted = (shft_amt == 2'b00) ? in :
						(shft_amt == 2'b01) ? {8'b0, in[31:8]} :
						(shft_amt == 2'b10) ? {16'b0, in[31:16]} :
											   {24'b0, in[31:24]};


assign out = (direction) ? 
	(left_shifted) : (right_shifted);

endmodule