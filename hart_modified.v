module hart2 #(
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

    //--------------------------------------------------------------------------
    // Combinational wires — outputs of each stage's logic, fed into the next
    // pipeline register.
    //--------------------------------------------------------------------------

    // IF stage
    wire        fetch_valid;     // PC has been initialised (fetch.o_retire_valid)

    // ID stage — combinational decode outputs
    wire [6:0]  dec_opcode;      // used internally by decode/control, wired out here
    wire [5:0]  dec_format;
    wire [4:0]  dec_rd;
    wire [4:0]  dec_rs1_raddr;
    wire [4:0]  dec_rs2_raddr;
    wire [31:0] dec_rs1_data;
    wire [31:0] dec_rs2_data;
    wire [31:0] dec_immediate;
    wire [2:0]  dec_alu_op;
    wire [3:0]  dec_branch_op;
    wire        dec_alu_src;
    wire        dec_alu_pc;
    wire        dec_pc_src;
    wire        dec_jalr;
    wire        dec_sub;
    wire        dec_unsigned;
    wire        dec_arith;
    wire        dec_lui;
    wire        dec_reg_write;
    wire [1:0]  dec_reg_write_src;
    wire        dec_mem_write;
    wire        dec_mem_read;
    wire [3:0]  dec_dmem_mask;

    // EX stage — combinational execute outputs
    wire [31:0] ex_alu_result;
    wire        ex_eq;
    wire        ex_slt;
    wire [31:0] ex_branch_out;

    // MEM stage — combinational memory output
    wire [31:0] mem_load_data;

    // WB stage outputs (writeback module wires)
    wire [31:0] wb_write_data;   // the value written to the register file
    wire [4:0]  wb_rd_out;       // destination register (pass-through of MW_rd)
    wire        wb_reg_write;    // reg write enable (pass-through of MW_reg_write)
    wire [31:0] wb_next_pc;      // next PC fed back to fetch

    // Gate regfile writes on WB-stage valid (MW_valid declared below — OK in Verilog)
    wire reg_write_wb_safe = wb_reg_write & MW_valid;

    //--------------------------------------------------------------------------
    // IF stage
    //--------------------------------------------------------------------------
    fetch i_fetch (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .address_in     (wb_next_pc),
        .o_mem_raddr    (o_imem_raddr),
        .o_retire_valid (fetch_valid)
    );

    //--------------------------------------------------------------------------
    // IF/ID pipeline register  (FD_*)
    //--------------------------------------------------------------------------
    reg        FD_valid;
    reg [31:0] FD_pc;
    reg [31:0] FD_instr;

    always @(posedge i_clk) begin
        if (i_rst) begin
            FD_valid <= 1'b0;
            FD_pc    <= 32'b0;
            FD_instr <= 32'b0;
        end else begin
            FD_valid <= fetch_valid;
            FD_pc    <= o_imem_raddr;
            FD_instr <= i_imem_rdata;
        end
    end

    //--------------------------------------------------------------------------
    // ID stage
    //--------------------------------------------------------------------------
    decode i_decode (
        .i_clk              (i_clk),
        .i_rst              (i_rst),
        .i_instr            (FD_instr),
        .opcode             (dec_opcode),
        .rd                 (dec_rd),
        .o_immediate        (dec_immediate),
        .o_format           (dec_format),
        .alu_op             (dec_alu_op),
        .branch_op          (dec_branch_op),
        .mem_write          (dec_mem_write),
        .reg_write_source_op(dec_reg_write_src),
        .reg_write          (dec_reg_write),
        .alu_src_op         (dec_alu_src),
        .pc_src_op          (dec_pc_src),
        .o_dmem_mask        (dec_dmem_mask),
        .i_sub              (dec_sub),
        .i_unsigned         (dec_unsigned),
        .i_arith            (dec_arith),
        .o_rs1_rdata        (dec_rs1_data),
        .o_rs2_rdata        (dec_rs2_data),
        .reg_write_wb       (reg_write_wb_safe),
        .i_rd_waddr         (wb_rd_out),
        .i_rd_wdata         (wb_write_data),
        .rs1_raddr          (dec_rs1_raddr),
        .rs2_raddr          (dec_rs2_raddr),
        .jalr_op            (dec_jalr),
        .alu_pc_op          (dec_alu_pc),
        .mem_read           (dec_mem_read),
        .lui_op             (dec_lui)
    );

    //--------------------------------------------------------------------------
    // ID/EX pipeline register  (DE_*)
    //--------------------------------------------------------------------------
    reg        DE_valid;
    reg [31:0] DE_pc;
    reg [31:0] DE_instr;
    reg [4:0]  DE_rs1_raddr;
    reg [4:0]  DE_rs2_raddr;
    reg [31:0] DE_rs1_data;
    reg [31:0] DE_rs2_data;
    reg [4:0]  DE_rd;
    reg [31:0] DE_immediate;
    reg [2:0]  DE_alu_op;
    reg [3:0]  DE_branch_op;
    reg        DE_alu_src;
    reg        DE_alu_pc;
    reg        DE_pc_src;
    reg        DE_jalr;
    reg        DE_sub;
    reg        DE_unsigned;
    reg        DE_arith;
    reg        DE_lui;
    reg        DE_reg_write;
    reg [1:0]  DE_reg_write_src;
    reg        DE_mem_write;
    reg        DE_mem_read;
    reg [3:0]  DE_dmem_mask;
    reg [2:0]  DE_funct3;         // carried forward for use by the MEM stage

    always @(posedge i_clk) begin
        if (i_rst) begin
            DE_valid         <= 1'b0;
            DE_pc            <= 32'b0;
            DE_instr         <= 32'b0;
            DE_rs1_raddr     <= 5'b0;
            DE_rs2_raddr     <= 5'b0;
            DE_rs1_data      <= 32'b0;
            DE_rs2_data      <= 32'b0;
            DE_rd            <= 5'b0;
            DE_immediate     <= 32'b0;
            DE_alu_op        <= 3'b0;
            DE_branch_op     <= 4'b0;
            DE_alu_src       <= 1'b0;
            DE_alu_pc        <= 1'b0;
            DE_pc_src        <= 1'b0;
            DE_jalr          <= 1'b0;
            DE_sub           <= 1'b0;
            DE_unsigned      <= 1'b0;
            DE_arith         <= 1'b0;
            DE_lui           <= 1'b0;
            DE_reg_write     <= 1'b0;
            DE_reg_write_src <= 2'b0;
            DE_mem_write     <= 1'b0;
            DE_mem_read      <= 1'b0;
            DE_dmem_mask     <= 4'b0;
            DE_funct3        <= 3'b0;
        end else begin
            DE_valid         <= FD_valid;
            DE_pc            <= FD_pc;
            DE_instr         <= FD_instr;
            DE_rs1_raddr     <= dec_rs1_raddr;
            DE_rs2_raddr     <= dec_rs2_raddr;
            DE_rs1_data      <= dec_rs1_data;
            DE_rs2_data      <= dec_rs2_data;
            DE_rd            <= dec_rd;
            DE_immediate     <= dec_immediate;
            DE_alu_op        <= dec_alu_op;
            DE_branch_op     <= dec_branch_op;
            DE_alu_src       <= dec_alu_src;
            DE_alu_pc        <= dec_alu_pc;
            DE_pc_src        <= dec_pc_src;
            DE_jalr          <= dec_jalr;
            DE_sub           <= dec_sub;
            DE_unsigned      <= dec_unsigned;
            DE_arith         <= dec_arith;
            DE_lui           <= dec_lui;
            DE_reg_write     <= dec_reg_write;
            DE_reg_write_src <= dec_reg_write_src;
            DE_mem_write     <= dec_mem_write;
            DE_mem_read      <= dec_mem_read;
            DE_dmem_mask     <= dec_dmem_mask;
            DE_funct3        <= FD_instr[14:12];
        end
    end

    //--------------------------------------------------------------------------
    // EX stage
    //--------------------------------------------------------------------------
    execute i_execute (
        .pc_src_op  (DE_pc_src),
        .alu_src_op (DE_alu_src),
        .alu_op     (DE_alu_op),
        .rs1_data   (DE_rs1_data),
        .rs2_data   (DE_rs2_data),
        .immediate  (DE_immediate),
        .alu_result (ex_alu_result),
        .o_eq       (ex_eq),
        .o_slt      (ex_slt),
        .i_sub      (DE_sub),
        .i_unsigned (DE_unsigned),
        .i_arith    (DE_arith),
        .branch_op  (DE_branch_op),
        .branch_out (ex_branch_out),
        .jalr_op    (DE_jalr),
        .alu_pc_op  (DE_alu_pc),
        .PC         (DE_pc),
        .lui_op     (DE_lui)
    );

    //--------------------------------------------------------------------------
    // EX/MEM pipeline register  (EM_*)
    //--------------------------------------------------------------------------
    reg        EM_valid;
    reg [31:0] EM_pc;
    reg [31:0] EM_instr;
    reg [4:0]  EM_rs1_raddr;
    reg [4:0]  EM_rs2_raddr;
    reg [31:0] EM_rs1_data;
    reg [31:0] EM_rs2_data;
    reg [4:0]  EM_rd;
    reg [31:0] EM_alu_result;
    reg [31:0] EM_branch_out;
    reg        EM_reg_write;
    reg [1:0]  EM_reg_write_src;
    reg        EM_pc_src;
    reg        EM_jalr;
    reg        EM_mem_write;
    reg        EM_mem_read;
    reg [3:0]  EM_dmem_mask;
    reg [2:0]  EM_funct3;
    reg        EM_unsigned;

    always @(posedge i_clk) begin
        if (i_rst) begin
            EM_valid         <= 1'b0;
            EM_pc            <= 32'b0;
            EM_instr         <= 32'b0;
            EM_rs1_raddr     <= 5'b0;
            EM_rs2_raddr     <= 5'b0;
            EM_rs1_data      <= 32'b0;
            EM_rs2_data      <= 32'b0;
            EM_rd            <= 5'b0;
            EM_alu_result    <= 32'b0;
            EM_branch_out    <= 32'b0;
            EM_reg_write     <= 1'b0;
            EM_reg_write_src <= 2'b0;
            EM_pc_src        <= 1'b0;
            EM_jalr          <= 1'b0;
            EM_mem_write     <= 1'b0;
            EM_mem_read      <= 1'b0;
            EM_dmem_mask     <= 4'b0;
            EM_funct3        <= 3'b0;
            EM_unsigned      <= 1'b0;
        end else begin
            EM_valid         <= DE_valid;
            EM_pc            <= DE_pc;
            EM_instr         <= DE_instr;
            EM_rs1_raddr     <= DE_rs1_raddr;
            EM_rs2_raddr     <= DE_rs2_raddr;
            EM_rs1_data      <= DE_rs1_data;
            EM_rs2_data      <= DE_rs2_data;
            EM_rd            <= DE_rd;
            EM_alu_result    <= ex_alu_result;
            EM_branch_out    <= ex_branch_out;
            EM_reg_write     <= DE_reg_write;
            EM_reg_write_src <= DE_reg_write_src;
            EM_pc_src        <= DE_pc_src;
            EM_jalr          <= DE_jalr;
            EM_mem_write     <= DE_mem_write;
            EM_mem_read      <= DE_mem_read;
            EM_dmem_mask     <= DE_dmem_mask;
            EM_funct3        <= DE_funct3;
            EM_unsigned      <= DE_unsigned;
        end
    end

    //--------------------------------------------------------------------------
    // MEM stage
    //--------------------------------------------------------------------------
    memoryAccess i_memoryAccess (
        .mem_write      (EM_mem_write),
        .alu_result     (EM_alu_result),
        .rs2_data       (EM_rs2_data),
        .o_dmem_addr    (o_dmem_addr),
        .o_dmem_wdata   (o_dmem_wdata),
        .o_dmem_ren     (o_dmem_ren),
        .o_dmem_wen     (o_dmem_wen),
        .i_dmem_rdata   (i_dmem_rdata),
        .o_dmem_mask    (o_dmem_mask),
        .dmem_mask_base (EM_dmem_mask),
        .mem_read       (EM_mem_read),
        .funct3         (EM_funct3),
        .i_unsigned     (EM_unsigned),
        .o_load_data    (mem_load_data)
    );

    //--------------------------------------------------------------------------
    // MEM/WB pipeline register  (MW_*)
    //--------------------------------------------------------------------------
    reg        MW_valid;
    reg [31:0] MW_pc;
    reg [31:0] MW_instr;
    reg [4:0]  MW_rs1_raddr;
    reg [4:0]  MW_rs2_raddr;
    reg [31:0] MW_rs1_data;
    reg [31:0] MW_rs2_data;
    reg [4:0]  MW_rd;
    reg [31:0] MW_alu_result;
    reg [31:0] MW_load_data;
    reg [31:0] MW_branch_out;
    reg        MW_reg_write;
    reg [1:0]  MW_reg_write_src;
    reg        MW_pc_src;
    reg        MW_jalr;

    always @(posedge i_clk) begin
        if (i_rst) begin
            MW_valid         <= 1'b0;
            MW_pc            <= 32'b0;
            MW_instr         <= 32'b0;
            MW_rs1_raddr     <= 5'b0;
            MW_rs2_raddr     <= 5'b0;
            MW_rs1_data      <= 32'b0;
            MW_rs2_data      <= 32'b0;
            MW_rd            <= 5'b0;
            MW_alu_result    <= 32'b0;
            MW_load_data     <= 32'b0;
            MW_branch_out    <= 32'b0;
            MW_reg_write     <= 1'b0;
            MW_reg_write_src <= 2'b0;
            MW_pc_src        <= 1'b0;
            MW_jalr          <= 1'b0;
        end else begin
            MW_valid         <= EM_valid;
            MW_pc            <= EM_pc;
            MW_instr         <= EM_instr;
            MW_rs1_raddr     <= EM_rs1_raddr;
            MW_rs2_raddr     <= EM_rs2_raddr;
            MW_rs1_data      <= EM_rs1_data;
            MW_rs2_data      <= EM_rs2_data;
            MW_rd            <= EM_rd;
            MW_alu_result    <= EM_alu_result;
            MW_load_data     <= mem_load_data;
            MW_branch_out    <= EM_branch_out;
            MW_reg_write     <= EM_reg_write;
            MW_reg_write_src <= EM_reg_write_src;
            MW_pc_src        <= EM_pc_src;
            MW_jalr          <= EM_jalr;
        end
    end

    //--------------------------------------------------------------------------
    // WB stage
    //--------------------------------------------------------------------------
    writeback i_writeback (
        .RegWrite    (MW_reg_write),
        .rd          (MW_rd),
        .PC          (MW_pc),
        .branch_out  (MW_branch_out),
        .ALUResult   (MW_alu_result),
        .ReadData    (MW_load_data),
        .MemtoReg    (MW_reg_write_src),
        .pc_src_op   (MW_pc_src),
        .rd_out      (wb_rd_out),
        .WriteData   (wb_write_data),
        .reg_write_wb(wb_reg_write),
        .current_PC  (wb_next_pc),
        .jalr_op     (MW_jalr)
    );

    //--------------------------------------------------------------------------
    // Retire signals — all sourced from the WB stage (MW registers + WB outputs)
    //--------------------------------------------------------------------------
    assign o_retire_valid     = MW_valid;
    assign o_retire_inst      = MW_instr;
    assign o_retire_trap      = 1'b0;
    assign o_retire_halt      = (MW_instr == 32'h00100073);
    assign o_retire_rs1_raddr = MW_rs1_raddr;
    assign o_retire_rs2_raddr = MW_rs2_raddr;
    assign o_retire_rs1_rdata = MW_rs1_data;
    assign o_retire_rs2_rdata = MW_rs2_data;
    assign o_retire_rd_waddr  = wb_rd_out;
    assign o_retire_rd_wdata  = wb_write_data;
    assign o_retire_pc        = MW_pc;
    assign o_retire_next_pc   = wb_next_pc;

endmodule

`default_nettype wire
