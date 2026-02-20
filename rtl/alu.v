`default_nettype none

// The arithmetic logic unit (ALU) is responsible for performing the core
// calculations of the processor. It takes two 32-bit operands and outputs
// a 32 bit result based on the selection operation - addition, comparison,
// shift, or logical operation. This ALU is a purely combinational block, so
// you should not attempt to add any registers or pipeline it.
module alu (
    // NOTE: Both 3'b010 and 3'b011 are used for set less than operations and
    // your implementation should output the same result for both codes. The
    // reason for this will become clear in project 3.
    //
    // Major operation selection.
    // 3'b000: addition/subtraction if `i_sub` asserted
    // 3'b001: shift left logical
    // 3'b010,
    // 3'b011: set less than/unsigned if `i_unsigned` asserted
    // 3'b100: exclusive or
    // 3'b101: shift right logical/arithmetic if `i_arith` asserted
    // 3'b110: or
    // 3'b111: and
    input  wire [ 2:0] i_opsel,
    // When asserted, addition operations should subtract instead.
    // This is only used for `i_opsel == 3'b000` (addition/subtraction).
    input  wire        i_sub,
    // When asserted, comparison operations should be treated as unsigned.
    // This is used for branch comparisons and set less than unsigned. For
    // b ranch operations, the ALU result is not used, only the comparison
    // results.
    input  wire        i_unsigned,
    // When asserted, right shifts should be treated as arithmetic instead of
    // logical. This is only used for `i_opsel == 3'b101` (shift right).
    input  wire        i_arith,
    // First 32-bit input operand.
    input  wire [31:0] i_op1,
    // Second 32-bit input operand.
    input  wire [31:0] i_op2,
    // 32-bit output result. Any carry out should be ignored.
    output wire [31:0] o_result,
    // Equality result. This is used externally to determine if a branch
    // should be taken.
    output wire        o_eq,
    // Set less than result. This is used externally to determine if a branch
    // should be taken.
    output wire        o_slt
);
    // TODO: Fill in your implementation here.

    // Declare signed wire copies so they can be used for signed operations.
    wire signed [31:0] signed_op1 = i_op1;
    wire signed [31:0] signed_op2 = i_op2;

    
    assign o_result = (i_opsel == 3'b000) ? 
        // Addition/subtraction
        ((i_sub) ? (i_op1 - i_op2) : (i_op1 + i_op2)) :
        (i_opsel == 3'b001) ?
        // Shift left logical
        // RV32I spec only uses last 5 bits of second operator for shift amount. 
        (sll16) : 
        (i_opsel == 3'b010 || i_opsel == 3'b011) ?
        // set less than/unsigned
        ((i_unsigned) ? ((i_op1 < i_op2) ? 32'b1 : 32'b0) : ((signed_op1 < signed_op2) ? 32'b1 : 32'b0)) :
        (i_opsel == 3'b100) ?
        // exclusive or
        (i_op1 ^ i_op2) :
        (i_opsel == 3'b101) ?
        // shift right logical/arithmetic if 'i_arith' asserted
        // RV32I spec only uses last 5 bits of second operator for shift amount. 
        // Code is failing and compiler not respecting arithmetic shift, so changing strategy.
        // Barrel shifter approach
        ((i_arith) ? (sra16) : (srl16)) :
        (i_opsel == 3'b110) ?
        // or
        (i_op1 | i_op2) :
        (i_opsel == 3'b111) ?
        // and
        (i_op1 & i_op2) :
        32'b0; // Default case

    // Equality result
    assign o_eq = (i_op1 == i_op2) ? 32'b1 : 32'b0;

    // Set less than result
    // Use same logic as above. 
    assign o_slt = (i_unsigned) ? ((i_op1 < i_op2) ? 32'b1 : 32'b0) : ((signed_op1 < signed_op2) ? 32'b1 : 32'b0);
        

        
    // Shift right arithmetic barrel shifter
    wire msb = i_op1[31];
    wire [4:0] shamt = i_op2[4:0];
    wire [31:0] sra1 = shamt[0] ? {msb, i_op1[31:1]} : i_op1;
    wire [31:0] sra2 = shamt[1] ? {{2{msb}}, sra1[31:2]} : sra1;
    wire [31:0] sra4 = shamt[2] ? {{4{msb}}, sra2[31:4]} : sra2;
    wire [31:0] sra8 = shamt[3] ? {{8{msb}}, sra4[31:8]} : sra4;
    wire [31:0] sra16 = shamt[4] ? {{16{msb}}, sra8[31:16]} : sra8;
    

    // Shift left logical barrel shifter
    wire [31:0] sll1 = shamt[0] ? {i_op1[30:0], 1'b0} : i_op1;
    wire [31:0] sll2 = shamt[1] ? {sll1[30:0], 2'b0} : sll1;
    wire [31:0] sll4 = shamt[2] ? {sll2[30:0], 4'b0} : sll2;
    wire [31:0] sll8 = shamt[3] ? {sll4[30:0], 8'b0} : sll4;
    wire [31:0] sll16 = shamt[4] ? {sll8[30:0], 16'b0} : sll8;


    // Shift right logical barrel shifter
    wire [31:0] srl1 = shamt[0] ? {1'b0, i_op1[31:1]} : i_op1;
    wire [31:0] srl2 = shamt[1] ? {2'b0, srl1[31:2]} : srl1;
    wire [31:0] srl4 = shamt[2] ? {4'b0, srl2[31:4]} : srl2;
    wire [31:0] srl8 = shamt[3] ? {8'b0, srl4[31:8]} : srl4;
    wire [31:0] srl16 = shamt[4] ? {16'b0, srl8[31:16]} : srl8;


    // 

endmodule

`default_nettype wire
