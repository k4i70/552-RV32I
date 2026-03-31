module branch (
    //control signals
    input wire [3:0] branch_op,
    input wire slt,
    input wire equal,
    input wire pc_src_op,

    //input signals
    input wire [31:0] imm_in,
    input wire jalr_op,
    input wire alu_pc_op,
    input wire [31:0] pc_in,

    //branch output signals
    output wire [31:0] branch_out
);

localparam BEQ = 3'b000;
localparam BNE = 3'b001;
localparam BLT = 3'b100;
localparam BGE = 3'b101;
localparam BLTU = 3'b110;
localparam BGEU = 3'b111;

wire [2:0] opsel = branch_op[2:0];

assign branch_out = (jalr_op) ? imm_in :
    (pc_src_op) ?  
    ((branch_op[3] == 1'b0) ? (
    //Branching
    (opsel == BEQ && equal) ? imm_in :
    (opsel == BNE && ~equal) ? imm_in :
    (opsel == BLT && slt) ? imm_in :
    (opsel == BGE && ~slt) ? imm_in :
    (opsel == BLTU && slt) ? imm_in :
    (opsel == BGEU && ~slt) ? imm_in : 
    32'h4)
    :
    //Jumping
    imm_in)
    : 32'h4;

endmodule