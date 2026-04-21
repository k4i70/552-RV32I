module hazardDetection(
	input wire [4:0] i_rs1_raddr,
	input wire [4:0] i_rs2_raddr,
	input wire [4:0] DE_rd,
	input wire DE_mem_read,
	input wire DE_reg_write,
	input wire [4:0] EM_rd,
	input wire EM_mem_read,
	input wire [6:0] opcode,
	input wire imem_wait,
	input wire dmem_wait,
	output wire stall
);

    wire is_branch = (opcode == 7'b1100011);
    wire is_jalr = (opcode == 7'b1100111);

    wire rs1_conflict_de = (DE_rd != 0) && (DE_rd == i_rs1_raddr) && DE_reg_write;
    wire rs2_conflict_de = (DE_rd != 0) && (DE_rd == i_rs2_raddr) && DE_reg_write;
    
    wire rs1_conflict_em_load = (EM_rd != 0) && (EM_rd == i_rs1_raddr) && EM_mem_read;
    wire rs2_conflict_em_load = (EM_rd != 0) && (EM_rd == i_rs2_raddr) && EM_mem_read;

    // Load-Use Hazard
    wire load_use_hazard = DE_mem_read && (DE_rd != 0) &&
        ((DE_rd == i_rs1_raddr) || (DE_rd == i_rs2_raddr));

    // Branch/Jalr Hazards 
    // Needs data immediately
    wire branch_hazard = (is_branch && (rs1_conflict_de || rs2_conflict_de || rs1_conflict_em_load || rs2_conflict_em_load));
    wire jalr_hazard = (is_jalr && (rs1_conflict_de || rs1_conflict_em_load));

    // Stall for internal hazards, memory waits, or data dependencies
    assign stall = load_use_hazard || branch_hazard || jalr_hazard || imem_wait || dmem_wait;

endmodule
