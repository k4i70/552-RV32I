module memoryAccess (
	input wire mem_write,
	input wire [31:0] alu_result, 
	input wire [31:0] rs2_data, // Needs this for store instructions
	input wire [3:0] dmem_mask_base,
	output wire [31:0] o_dmem_addr, 
	output wire [31:0] o_dmem_wdata,
	output wire o_dmem_ren,
	output wire o_dmem_wen,
	input wire [31:0] i_dmem_rdata,
	output wire [3:0] o_dmem_mask,
	input wire mem_read,
	input wire [2:0] funct3,
	input wire i_unsigned
);

wire [1:0] byte_offset = alu_result[1:0];

// Align ALU result to address
assign o_dmem_addr = {alu_result[31:2], 2'b00};

// Barrel shifter to shift dmem_mask when asserted
assign o_dmem_mask = (byte_offset == 2'b00) ? dmem_mask_base :
					(byte_offset == 2'b01) ? ({dmem_mask_base[2:0], 1'b0}) :
					(byte_offset == 2'b10) ? ({dmem_mask_base[1:0], 2'b00}) :
											 ({dmem_mask_base[0], 3'b000});

wire [31:0] wdata_shifted;
barrel_shifter i_barrel_shifter (
	.in(rs2_data),
	.shft_amt(byte_offset),
	.out(wdata_shifted),
	.direction(1'b0)
);

assign o_dmem_wdata = wdata_shifted;

// Using external interface for memory address
assign o_dmem_addr = alu_result;

wire [31:0] rdata_shifted;
barrel_shifter i_barrel_shifter_rdata (
	.in(i_dmem_rdata),
	.shft_amt(byte_offset),
	.out(rdata_shifted),
	.direction(1'b1)
);

// For now, just read values when mem_write is low
assign o_dmem_ren = mem_read;
assign o_dmem_wen = mem_write;  

// Sign extend byte and half word to full length. 
wire [31:0] load_byte = i_unsigned ? {24'b0, rdata_shifted[7:0]} : 
						{{24{rdata_shifted[7]}}, rdata_shifted[7:0]};

wire [31:0] load_half = i_unsigned ? {16'b0, rdata_shifted[15:0]} : 
						{{16{rdata_shifted[15]}}, rdata_shifted[15:0]};

wire [31:0] load_word = rdata_shifted;

assign o_load_data = (funct3 == 3'b000) ? load_byte :
					 (funct3 == 3'b001) ? load_half :
					 (funct3 == 3'b010) ? load_word :
					 32'b0; // Default case
endmodule