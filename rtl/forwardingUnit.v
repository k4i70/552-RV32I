module forwardingUnit (
	output wire [31:0] rs1_forwarded_data,
	output wire [31:0] rs2_forwarded_data,
	input wire [31:0] DE_rs1_data,
	input wire [31:0] DE_rs2_data,
	input wire [4:0] rs1_addr,
	input wire [4:0] rs2_addr,
	input wire [4:0] ex_dest_addr,
	input wire [4:0] mem_dest_addr,
	input wire ex_reg_write,
	input wire mem_reg_write,
	input wire [31:0] ex_data,
	input wire [31:0] mem_data
);

// Forwarding wires
wire rs1_EX_forwarded;
wire rs2_EX_forwarded;
wire rs1_MEM_forwarded;
wire rs2_MEM_forwarded;

// Mux will chose between orginal value (00), EX value (10), and mem value (01)

// EX-EX forward when ex_reg_write && ex_dest_addr != 0 && ex_dest_addr == rs_addr
assign rs1_EX_forwarded = ex_reg_write && (ex_dest_addr != 0) && (ex_dest_addr == rs1_addr);
assign rs2_EX_forwarded = ex_reg_write && (ex_dest_addr != 0) && (ex_dest_addr == rs2_addr);

// MEM-EX forward when mem_reg_write && mem_dest_addr != 0 && mem_dest_addr == rs_addr
assign rs1_MEM_forwarded = mem_reg_write && (mem_dest_addr != 0) && (mem_dest_addr == rs1_addr);
assign rs2_MEM_forwarded = mem_reg_write && (mem_dest_addr != 0) && (mem_dest_addr == rs2_addr);


// Forwarding mux for rs1
assign rs1_forwarded_data = rs1_EX_forwarded ? ex_data :
						   rs1_MEM_forwarded ? mem_data : DE_rs1_data;

// Forwarding mux for rs2
assign rs2_forwarded_data = rs2_EX_forwarded ? ex_data :
						   rs2_MEM_forwarded ? mem_data : DE_rs2_data;


endmodule