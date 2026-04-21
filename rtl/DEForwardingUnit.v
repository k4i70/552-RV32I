module DEForwardingUnit (
	input wire [4:0] rs1_addr,
	input wire [4:0] rs2_addr,
	input wire [4:0] ex_rd_addr,
	input wire ex_reg_write,
	input wire [4:0] mem_rd_addr,
	input wire mem_reg_write,
	input wire [4:0] wb_rd_addr,
	input wire wb_reg_write,

	output wire [1:0] forward_rs1_cnrl,
	output wire [1:0] forward_rs2_cnrl
);


// Sending control signals, decode stage contains the MUX this time
// DE-EX (10), DE-MEM (01), DE-WB (11), No forwarding (00)
assign forward_rs1_cnrl = (ex_reg_write && (ex_rd_addr != 0) && (ex_rd_addr == rs1_addr)) ? 2'b10 :
						(mem_reg_write && (mem_rd_addr != 0) && (mem_rd_addr == rs1_addr)) ? 2'b01 :
						(wb_reg_write && (wb_rd_addr != 0) && (wb_rd_addr == rs1_addr)) ? 2'b11 : 2'b00;

assign forward_rs2_cnrl = (ex_reg_write && (ex_rd_addr != 0) && (ex_rd_addr == rs2_addr)) ? 2'b10 :
						(mem_reg_write && (mem_rd_addr != 0) && (mem_rd_addr == rs2_addr)) ? 2'b01 :
						(wb_reg_write && (wb_rd_addr != 0) && (wb_rd_addr == rs2_addr)) ? 2'b11 : 2'b00;


endmodule