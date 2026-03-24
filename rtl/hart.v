module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available on the same cycle.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002000`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // this will immediately reflect the contents of memory at the specified
    // address, for the bytes enabled by the mask. When read enable is not
    // asserted, or for bytes not set in the mask, the value is undefined.
    input  wire [31:0] i_dmem_rdata,
	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    output wire [31:0] o_retire_dmem_addr,
    output wire [ 3:0] o_retire_dmem_mask,
    output wire        o_retire_dmem_ren,
    output wire        o_retire_dmem_wen,
    output wire [31:0] o_retire_dmem_rdata,
    output wire [31:0] o_retire_dmem_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);

    // Fill in your implementation here.

    // Intermediate signals
    wire [6:0] opcode;
    wire [31:0] next_pc;
    wire [31:0] wb_next_pc_unused;
    wire [2:0] funct3;
    wire [3:0] branch_op;
    wire [4:0] rd;
    wire [2:0] alu_op;
    wire [1:0] reg_write_source_op;
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] immediate;
    wire [31:0] alu_result;
    wire [31:0] branch_out;
    wire [31:0] WriteData;
    wire [3:0] dmem_mask_base;
    
    wire mem_write, reg_write, alu_src_op, pc_src_op, i_sub, i_unsigned, i_arith;
    wire jalr_op, alu_pc_op, mem_read, lui_op;

    wire [31:0] load_data;
    wire [4:0] i_rs1_raddr;
    wire [4:0] i_rs2_raddr;
    wire stall;
    reg [4:0] MW_rd;
    reg MW_reg_write;
    wire [31:0] rs1_forwarded_data;
    wire [31:0] rs2_forwarded_data;
    wire [1:0] forward_rs1_cnrl;
    wire [1:0] forward_rs2_cnrl;

    // Pipeline valid bits
    reg FD_valid;
    reg DE_valid;
    reg EM_valid;
    reg MW_valid;

    // IFID pipeline register
    reg [31:0] FD_i_instr;
    reg [31:0] FD_PC;

    // Branch res
    wire branch_taken;
    wire [31:0] branch_target;
    assign branch_taken = FD_valid && !stall && (jalr_op || (branch_out != 32'h4));
    assign branch_target = jalr_op ? ((branch_rs1_data + immediate) & ~32'h1) : (FD_PC + branch_out);
    assign next_pc = branch_taken ? branch_target : (o_imem_raddr + 32'h4);


    /** Instruction Fetch **/
    fetch i_fetch (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_stall(stall && !branch_taken),
        .address_in(next_pc), 
        .o_mem_raddr(o_imem_raddr)
    );

    // DE Forwarding Unit
    DEForwardingUnit i_DEForwardingUnit (
        .rs1_addr(DE_instr[19:15]),
        .rs2_addr(DE_instr[24:20]),
        .ex_rd_addr(EM_rd),
        .ex_reg_write(EM_reg_write),
        .mem_rd_addr(MW_rd),
        .mem_reg_write(MW_reg_write),
        .wb_rd_addr(MW_rd), 
        .wb_reg_write(MW_reg_write),
        .forward_rs1_cnrl(forward_rs1_cnrl),
        .forward_rs2_cnrl(forward_rs2_cnrl)
    );

    // Branch forwarding muxes
    wire [31:0] branch_rs1_data = (forward_rs1_cnrl == 2'b10) ? EM_ALUResult :
                                  (forward_rs1_cnrl == 2'b01) ? MW_ALUResult :
                                  (forward_rs1_cnrl == 2'b11) ? WriteData : rs1_data;

    wire [31:0] branch_rs2_data = (forward_rs2_cnrl == 2'b10) ? EM_ALUResult :
                                  (forward_rs2_cnrl == 2'b01) ? MW_ALUResult :
                                  (forward_rs2_cnrl == 2'b11) ? WriteData : rs2_data;


	// IFID pipeline register. 
    always @(posedge i_clk) begin
        if (i_rst) begin
            FD_i_instr <= 32'h00000013;
            FD_PC <= RESET_ADDR;
            FD_valid <= 1'b0;
        end else if (branch_taken) begin
            FD_i_instr <= 32'h00000013;
            FD_PC <= 32'b0;
            FD_valid <= 1'b0;
        end else if (!stall) begin
            FD_i_instr <= i_imem_rdata;
            FD_PC <= o_imem_raddr;
            FD_valid <= 1'b1;
        end else begin
            FD_i_instr <= FD_i_instr;
            FD_PC <= FD_PC;
            FD_valid <= FD_valid;
        end
    end



    /** Instruction Decode **/
    decode i_decode (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_instr(FD_i_instr),
        .opcode(opcode),
        .rd(rd),
        .o_immediate(immediate),
        .alu_op(alu_op),
        .branch_op(branch_op),
        .mem_write(mem_write),
        .reg_write_source_op(reg_write_source_op),
        .reg_write(reg_write),
        .alu_src_op(alu_src_op),
        .pc_src_op(pc_src_op),
        .o_dmem_mask(dmem_mask_base),
        .i_sub(i_sub),
        .i_unsigned(i_unsigned),
        .i_arith(i_arith),
        .o_rs1_rdata(rs1_data),
        .o_rs2_rdata(rs2_data),
        .reg_write_wb(MW_reg_write),
        .i_rd_waddr(MW_rd),
        .i_rd_wdata(WriteData),
        .jalr_op(jalr_op),
        .alu_pc_op(alu_pc_op),
        .mem_read(mem_read),
        .lui_op(lui_op),
        .funct3(funct3),
        .i_pc(FD_PC),
        .branch_out(branch_out),
        .i_rs1_raddr(i_rs1_raddr),
        .i_rs2_raddr(i_rs2_raddr),
        .branch_rs1_data(branch_rs1_data),
        .branch_rs2_data(branch_rs2_data)
    );

    // EX-EX and EX-MEM forwarding unit
    forwardingUnit i_forwardingUnit (
        .rs1_forwarded_data(rs1_forwarded_data),
        .rs2_forwarded_data(rs2_forwarded_data),
        .DE_rs1_data(DE_rs1_data),
        .DE_rs2_data(DE_rs2_data),
        .rs1_addr(DE_instr[19:15]),
        .rs2_addr(DE_instr[24:20]),
        .ex_dest_addr(EM_rd),
        .mem_dest_addr(MW_rd),
        .ex_reg_write(EM_reg_write),
        .mem_reg_write(MW_reg_write),
        .mem_data(WriteData),
        .ex_data(EM_ALUResult)
    );
        
    // DE control signals
    reg [1:0] DE_reg_write_source_op;
    reg DE_reg_write;
    reg DE_pc_src_op;
    reg DE_jalr_op;
    reg DE_mem_write;
    reg [3:0] DE_o_dmem_mask;
    reg DE_mem_read;
    reg [2:0] DE_funct3;
    reg [2:0] DE_alu_op;
    reg DE_alu_src_op;
    reg DE_i_sub;
    reg DE_i_unsigned;
    reg DE_i_arith;
    reg DE_alu_pc_op;
    reg DE_lui_op;
    reg [31:0] DE_PC;
    always @(posedge i_clk) begin
        if (i_rst) begin
            DE_reg_write_source_op <= 2'b0;
            DE_reg_write <= 1'b0;
            DE_pc_src_op <= 1'b0;
            DE_jalr_op <= 1'b0;
            DE_mem_write <= 1'b0;
            DE_o_dmem_mask <= 4'b0;
            DE_mem_read <= 1'b0;
            DE_funct3 <= 3'b0;
            DE_alu_op <= 3'b0;
            DE_alu_src_op <= 1'b0;
            DE_i_sub <= 1'b0;
            DE_i_unsigned <= 1'b0;
            DE_i_arith <= 1'b0;
            DE_alu_pc_op <= 1'b0;
            DE_lui_op <= 1'b0;
            DE_PC <= 32'b0;
            DE_valid <= 1'b0;
        end else if (stall) begin
            DE_reg_write_source_op <= 2'b0;
            DE_reg_write <= 1'b0;
            DE_pc_src_op <= 1'b0;
            DE_jalr_op <= 1'b0;
            DE_mem_write <= 1'b0;
            DE_o_dmem_mask <= 4'b0;
            DE_mem_read <= 1'b0;
            DE_funct3 <= 3'b0;
            DE_alu_op <= 3'b0;
            DE_alu_src_op <= 1'b0;
            DE_i_sub <= 1'b0;
            DE_i_unsigned <= 1'b0;
            DE_i_arith <= 1'b0;
            DE_alu_pc_op <= 1'b0;
            DE_lui_op <= 1'b0;
            DE_PC <= DE_PC;
            DE_valid <= 1'b0;
        end else begin
            DE_reg_write_source_op <= reg_write_source_op;
            DE_reg_write <= reg_write;
            DE_pc_src_op <= pc_src_op;
            DE_jalr_op <= jalr_op;
            DE_mem_write <= mem_write;
            DE_o_dmem_mask <= dmem_mask_base;
            DE_mem_read <= mem_read;
            DE_funct3 <= funct3;
            DE_alu_op <= alu_op;
            DE_alu_src_op <= alu_src_op;
            DE_i_sub <= i_sub;
            DE_i_unsigned <= i_unsigned;
            DE_i_arith <= i_arith;
            DE_alu_pc_op <= alu_pc_op;
            DE_lui_op <= lui_op;
            DE_PC <= FD_PC;
            DE_valid <= FD_valid;
        end
    end

    // DE data signals
    reg [4:0] DE_rd;
    reg [31:0] DE_rs1_data;
    reg [31:0] DE_rs2_data;
    reg [31:0] DE_immediate;
    reg [31:0] DE_branch_out;
    reg [31:0] DE_instr;
    always @(posedge i_clk) begin
        if (i_rst) begin
            DE_rd <= 5'b0;
            DE_rs1_data <= 32'b0;
            DE_rs2_data <= 32'b0;
            DE_immediate <= 32'b0;
            DE_branch_out <= 32'b0;
            DE_instr <= 32'b0;
        end else if (stall) begin
            DE_rd <= 5'b0;
            DE_rs1_data <= 32'b0;
            DE_rs2_data <= 32'b0;
            DE_immediate <= 32'b0;
            DE_branch_out <= 32'b0;
            DE_instr <= 32'b0;
        end else begin
            DE_rd <= rd;
            DE_rs1_data <= rs1_forwarded_data;
            DE_rs2_data <= rs2_forwarded_data;
            DE_immediate <= immediate;
            DE_branch_out <= branch_out;
            DE_instr <= FD_i_instr;
        end
    end



    /** Execute **/
    execute i_execute (
        .alu_src_op(DE_alu_src_op),
        .alu_op(DE_alu_op),
        .rs1_data(DE_rs1_data),
        .rs2_data(DE_rs2_data),
        .immediate(DE_immediate),
        .alu_result(alu_result),
        .i_sub(DE_i_sub),
        .i_unsigned(DE_i_unsigned),
        .i_arith(DE_i_arith),
        .alu_pc_op(DE_alu_pc_op),
        .PC(DE_PC),
        .lui_op(DE_lui_op)
    );


    // EM pipeline control signals
    reg [1:0] EM_reg_write_source_op;
    reg EM_reg_write;
    reg EM_pc_src_op;
    reg EM_jalr_op;
    reg EM_mem_write;
    reg [3:0] EM_o_dmem_mask;
    reg EM_mem_read;
    reg [2:0] EM_funct3;
    reg [31:0] EM_PC;
    reg [31:0] EM_instr;
    always @(posedge i_clk) begin
        if (i_rst) begin
            EM_reg_write_source_op <= 1'b0;
            EM_reg_write <= 1'b0;
            EM_pc_src_op <= 1'b0;
            EM_jalr_op <= 1'b0;
            EM_mem_write <= 1'b0;
            EM_o_dmem_mask <= 4'b0;
            EM_mem_read <= 1'b0;
            EM_funct3 <= 3'b0;
            EM_PC <= 32'b0;
            EM_instr <= 32'b0;
            EM_valid <= 1'b0;
        end else begin
            EM_reg_write_source_op <= DE_reg_write_source_op;
            EM_reg_write <= DE_reg_write;
            EM_pc_src_op <= DE_pc_src_op;
            EM_jalr_op <= DE_jalr_op;
            EM_mem_write <= DE_mem_write;
            EM_o_dmem_mask <= DE_o_dmem_mask;
            EM_mem_read <= DE_mem_read;
            EM_funct3 <= DE_funct3;
            EM_PC <= DE_PC;
            EM_instr <= DE_instr;
            EM_valid <= DE_valid;
        end
    end

    // EM data signals
    reg [4:0] EM_rd;
    reg [31:0] EM_rs1_data;
    reg [31:0] EM_rs2_data;
    reg [31:0] EM_ALUResult;
    reg [31:0] EM_branch_out;
    always @(posedge i_clk) begin
        if (i_rst) begin
            EM_rd <= 5'b0;
            EM_rs1_data <= 32'b0;
            EM_rs2_data <= 32'b0;
            EM_ALUResult <= 32'b0;
            EM_branch_out <= 32'b0;
        end else begin
            EM_rd <= DE_rd;
            EM_rs1_data <= DE_rs1_data;
            EM_rs2_data <= DE_rs2_data;
            EM_ALUResult <= alu_result;
            EM_branch_out <= DE_branch_out;
        end
    end
    


    /** Memory Access **/
    memoryAccess i_memoryAccess (
        .mem_write(EM_mem_write),
        .alu_result(EM_ALUResult), 
        .rs2_data(EM_rs2_data),
        .o_dmem_addr(o_dmem_addr), 
        .o_dmem_wdata(o_dmem_wdata),
        .o_dmem_ren(o_dmem_ren),
        .o_dmem_wen(o_dmem_wen),
        .i_dmem_rdata(i_dmem_rdata),
        .o_dmem_mask(o_dmem_mask),
        .dmem_mask_base(EM_o_dmem_mask),
        .mem_read(EM_mem_read),
        .funct3(EM_funct3),
        .o_load_data(load_data)
    );


    // MW pipeline control signals
    reg [1:0] MW_reg_write_source_op;
    reg MW_pc_src_op;
    reg MW_jalr_op;
    reg [31:0] MW_PC;
    reg [31:0] MW_instr;
    always @(posedge i_clk) begin
        if (i_rst) begin
            MW_reg_write_source_op <= 1'b0;
            MW_reg_write <= 1'b0;
            MW_pc_src_op <= 1'b0;
            MW_jalr_op <= 1'b0;
            MW_PC <= 32'b0;
            MW_instr <= 32'b0;
            MW_valid <= 1'b0;
        end else begin
            MW_reg_write_source_op <= EM_reg_write_source_op;
            MW_reg_write <= EM_reg_write;
            MW_pc_src_op <= EM_pc_src_op;
            MW_jalr_op <= EM_jalr_op;
            MW_PC <= EM_PC;
            MW_instr <= EM_instr;
            MW_valid <= EM_valid;
        end
    end

    // MW data signals
    reg [31:0] MW_rs1_data;
    reg [31:0] MW_rs2_data;
    reg [31:0] MW_ALUResult;
    reg [31:0] MW_branch_out;
    reg [31:0] MW_LoadData;
    reg [31:0] MW_dmem_addr;
    reg        MW_dmem_ren;
    reg        MW_dmem_wen;
    reg [3:0]  MW_dmem_mask;
    reg [31:0] MW_dmem_wdata;
    reg [31:0] MW_dmem_rdata;
    always @(posedge i_clk) begin
        if (i_rst) begin
            MW_rd <= 5'b0;
            MW_rs1_data <= 32'b0;
            MW_rs2_data <= 32'b0;
            MW_ALUResult <= 32'b0;
            MW_branch_out <= 32'b0;
            MW_LoadData <= 32'b0;
            MW_dmem_addr <= 32'b0;
            MW_dmem_ren <= 1'b0;
            MW_dmem_wen <= 1'b0;
            MW_dmem_mask <= 4'b0;
            MW_dmem_wdata <= 32'b0;
            MW_dmem_rdata <= 32'b0;
        end else begin
            MW_rd <= EM_rd;
            MW_rs1_data <= EM_rs1_data;
            MW_rs2_data <= EM_rs2_data;
            MW_ALUResult <= EM_ALUResult;
            MW_branch_out <= EM_branch_out;
            MW_LoadData <= load_data;
            MW_dmem_addr <= o_dmem_addr;
            MW_dmem_ren <= o_dmem_ren;
            MW_dmem_wen <= o_dmem_wen;
            MW_dmem_mask <= o_dmem_mask;
            MW_dmem_wdata <= o_dmem_wdata;
            MW_dmem_rdata <= i_dmem_rdata;
        end
    end


    /** Writeback **/
    writeback i_writeback (
        .RegWrite(MW_reg_write),
        .rd(MW_rd),
        .PC(MW_PC),
        .branch_out(MW_branch_out),
        .ALUResult(MW_ALUResult),
        .ReadData(MW_LoadData),
        .MemtoReg(MW_reg_write_source_op),
        .pc_src_op(MW_pc_src_op),
        .WriteData(WriteData),
        .current_PC(wb_next_pc_unused),
        .jalr_op(MW_jalr_op)
    );


    // Hazard detection unit, outputs stall signal to decode pipeline stage. 
    hazardDetection i_hazardDetection (
        .i_rs1_raddr(i_rs1_raddr),
        .i_rs2_raddr(i_rs2_raddr),
        .DE_rd(DE_rd),
        .stall(stall),
        .DE_mem_read(DE_mem_read)
    );


    // Declare retire signals and connect with assigns
    assign o_retire_valid = MW_valid;
    assign o_retire_inst = MW_instr;
    assign o_retire_trap = 1'b0; 
    assign o_retire_halt = (MW_instr == 32'h00100073); // Ebreak instruction
    assign o_retire_rs1_raddr = MW_instr[19:15];
    assign o_retire_rs2_raddr = MW_instr[24:20];
    assign o_retire_rs1_rdata = MW_rs1_data;
    assign o_retire_rs2_rdata = MW_rs2_data;
    assign o_retire_rd_waddr = MW_rd;
    assign o_retire_rd_wdata = WriteData;
    assign o_retire_pc = MW_PC;
    assign o_retire_next_pc = wb_next_pc_unused;
    assign o_retire_dmem_addr = MW_dmem_addr;
    assign o_retire_dmem_ren = MW_dmem_ren;
    assign o_retire_dmem_wen = MW_dmem_wen;
    assign o_retire_dmem_mask = MW_dmem_mask;
    assign o_retire_dmem_wdata = MW_dmem_wdata;
    assign o_retire_dmem_rdata = MW_dmem_rdata;


endmodule

`default_nettype wire