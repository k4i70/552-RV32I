`default_nettype none

module cache (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_mem_ready,
    output wire [31:0] o_mem_addr,
    output wire        o_mem_ren,
    output wire        o_mem_wen,
    output wire [31:0] o_mem_wdata,
    input  wire [31:0] i_mem_rdata,
    input  wire        i_mem_valid,
    output wire        o_busy,
    input  wire [31:0] i_req_addr,
    input  wire        i_req_ren,
    input  wire        i_req_wen,
    input  wire [ 3:0] i_req_mask,
    input  wire [31:0] i_req_wdata,
    output wire [31:0] o_res_rdata
);
    localparam O = 4;
    localparam S = 5;
    localparam DEPTH = 32;
    localparam W = 4;
    localparam T = 23;
    localparam D = 4;

    reg [31:0] datas0 [DEPTH - 1:0][D - 1:0];
    reg [31:0] datas1 [DEPTH - 1:0][D - 1:0];
    reg [31:0] datas2 [DEPTH - 1:0][D - 1:0];
    reg [31:0] datas3 [DEPTH - 1:0][D - 1:0];
    reg [T - 1:0] tags0 [DEPTH - 1:0];
    reg [T - 1:0] tags1 [DEPTH - 1:0];
    reg [T - 1:0] tags2 [DEPTH - 1:0];
    reg [T - 1:0] tags3 [DEPTH - 1:0];
    reg [3:0] valid [31:0];
    reg [2:0] plru [31:0];



    // cache_read_data must be declared after hit_way and way*_data are defined
    reg [31:0] cache_read_data;

    // Inline mask_word and merge_masked_word as combinational logic
    wire [31:0] masked_read_data;
    wire [31:0] hit_write_word;


    function [1:0] choose_victim_way;
        input [3:0] valid_bits;
        input [2:0] plru_bits;
        begin
            choose_victim_way = !valid_bits[0] ? 2'd0 :
                                !valid_bits[1] ? 2'd1 :
                                !valid_bits[2] ? 2'd2 :
                                !valid_bits[3] ? 2'd3 :
                                (!plru_bits[2] ? (plru_bits[1] ? 2'd1 : 2'd0)
                                               : (plru_bits[0] ? 2'd3 : 2'd2));
        end
    endfunction

    function [2:0] update_plru;
        input [2:0] plru_bits;
        input [1:0] accessed_way;
        begin
            case (accessed_way)
                2'd0: update_plru = {1'b1, 1'b1, plru_bits[0]};
                2'd1: update_plru = {1'b1, 1'b0, plru_bits[0]};
                2'd2: update_plru = {1'b0, plru_bits[1], 1'b1};
                default: update_plru = {1'b0, plru_bits[1], 1'b0};
            endcase
        end
    endfunction

    wire [27:0] req_line_addr = i_req_addr[31:4];
    wire [27:0] prefetch_line_addr = req_line_addr + 28'd1;
    wire [31:0] prefetch_addr = {prefetch_line_addr, 4'h0};
    wire [T-1:0] prefetch_tag = prefetch_addr[31:9];
    wire [S-1:0] prefetch_set = prefetch_addr[8:4];
    wire [1:0] req_word_off = i_req_addr[3:2];
    wire prefetch_way0_match = valid[prefetch_set][0] && (tags0[prefetch_set] == prefetch_tag);
    wire prefetch_way1_match = valid[prefetch_set][1] && (tags1[prefetch_set] == prefetch_tag);
    wire prefetch_way2_match = valid[prefetch_set][2] && (tags2[prefetch_set] == prefetch_tag);
    wire prefetch_way3_match = valid[prefetch_set][3] && (tags3[prefetch_set] == prefetch_tag);
    wire prefetch_hit = prefetch_way0_match || prefetch_way1_match || prefetch_way2_match || prefetch_way3_match;
    wire request_is_read = i_req_ren && !i_req_wen;
    wire request_is_prefetch_point = request_is_read && (req_word_off == 2'd3);
    wire should_start_prefetch = request_is_prefetch_point && !prefetch_hit;

    wire [T-1:0] req_tag = i_req_addr[31:9];
    wire [S-1:0] req_set = i_req_addr[8:4];

    wire way0_match = valid[req_set][0] && (tags0[req_set] == req_tag);
    wire way1_match = valid[req_set][1] && (tags1[req_set] == req_tag);
    wire way2_match = valid[req_set][2] && (tags2[req_set] == req_tag);
    wire way3_match = valid[req_set][3] && (tags3[req_set] == req_tag);
    wire hit = way0_match || way1_match || way2_match || way3_match;
    wire [1:0] hit_way = way3_match ? 2'd3 :
                         way2_match ? 2'd2 :
                         way1_match ? 2'd1 : 2'd0;
    wire miss = (i_req_ren || i_req_wen) && !hit;


    wire [31:0] way0_data = datas0[req_set][req_word_off];
    wire [31:0] way1_data = datas1[req_set][req_word_off];
    wire [31:0] way2_data = datas2[req_set][req_word_off];
    wire [31:0] way3_data = datas3[req_set][req_word_off];

    // Now that hit_way and way*_data are defined, define cache_read_data
    always @* begin
        case (hit_way)
            2'd0: cache_read_data = way0_data;
            2'd1: cache_read_data = way1_data;
            2'd2: cache_read_data = way2_data;
            default: cache_read_data = way3_data;
        endcase
    end

    assign masked_read_data = {
        i_req_mask[3] ? cache_read_data[31:24] : 8'h00,
        i_req_mask[2] ? cache_read_data[23:16] : 8'h00,
        i_req_mask[1] ? cache_read_data[15:8]  : 8'h00,
        i_req_mask[0] ? cache_read_data[7:0]   : 8'h00
    };

    assign hit_write_word = {
        i_req_mask[3] ? i_req_wdata[31:24] : cache_read_data[31:24],
        i_req_mask[2] ? i_req_wdata[23:16] : cache_read_data[23:16],
        i_req_mask[1] ? i_req_wdata[15:8]  : cache_read_data[15:8],
        i_req_mask[0] ? i_req_wdata[7:0]   : cache_read_data[7:0]
    };

    // ...existing code...


    reg [1:0] state;
    localparam READY = 2'd0;
    localparam MISS_FILL = 2'd1;
    localparam MISS_WB = 2'd2;
    localparam PREFETCH_FILL = 2'd3;

    reg [S-1:0] miss_set;
    reg [T-1:0] miss_tag;
    reg [3:0] mem_req_offset;
    reg [31:0] words_requested;
    reg [31:0] words_filled;
    reg miss_write;
    reg [31:0] miss_write_data;
    reg [3:0] miss_write_mask;
    reg [1:0] miss_write_word_off;
    reg [1:0] miss_way;
    reg [31:0] miss_write_word_data;
    reg [31:0] fill_word;
    reg serviced_a_miss;
    reg [31:0] serviced_data;

    wire [31:0] mem_req_addr = {miss_tag, miss_set, mem_req_offset};
    wire [31:0] writeback_addr = {miss_tag, miss_set, miss_write_word_off, 2'b00};
    wire [27:0] miss_line_addr = {miss_tag, miss_set};
    wire [27:0] miss_prefetch_line_addr = miss_line_addr + 28'd1;
    wire [31:0] miss_prefetch_addr = {miss_prefetch_line_addr, 4'h0};
    wire [T-1:0] miss_prefetch_tag = miss_prefetch_addr[31:9];
    wire [S-1:0] miss_prefetch_set = miss_prefetch_addr[8:4];
    wire miss_prefetch_way0_match = valid[miss_prefetch_set][0] && (tags0[miss_prefetch_set] == miss_prefetch_tag);
    wire miss_prefetch_way1_match = valid[miss_prefetch_set][1] && (tags1[miss_prefetch_set] == miss_prefetch_tag);
    wire miss_prefetch_way2_match = valid[miss_prefetch_set][2] && (tags2[miss_prefetch_set] == miss_prefetch_tag);
    wire miss_prefetch_way3_match = valid[miss_prefetch_set][3] && (tags3[miss_prefetch_set] == miss_prefetch_tag);
    wire miss_prefetch_hit = miss_prefetch_way0_match || miss_prefetch_way1_match || miss_prefetch_way2_match || miss_prefetch_way3_match;
    wire miss_should_start_prefetch = !miss_write && (miss_write_word_off == 2'd3) && !miss_prefetch_hit;

    // Also report busy on the request cycle that discovers a miss, before the
    // registered fill state is visible to the pipeline.
    assign o_busy = (state != READY) || miss;
    assign o_mem_addr = (state == MISS_FILL) ? mem_req_addr :
                        (state == MISS_WB) ? writeback_addr :
                        (state == PREFETCH_FILL) ? mem_req_addr :
                        i_req_addr;
    // Remove !(hit && i_req_wen) from prefetch gating to avoid deadlock
    assign o_mem_ren = (((state == MISS_FILL) || (state == PREFETCH_FILL)) &&
                        (words_requested < 32'd4) && i_mem_ready);
    assign o_mem_wen = (hit && i_req_wen && i_mem_ready) ||
                       ((state == MISS_WB) && i_mem_ready);
    assign o_mem_wdata = (hit && i_req_wen) ? hit_write_word : miss_write_word_data;
    assign o_res_rdata = hit ? masked_read_data : (serviced_a_miss ? serviced_data : 32'h0);

    integer set_idx;

    always @(posedge i_clk) begin
        if (i_rst) begin
            state <= READY;
            mem_req_offset <= 4'h0;
            words_requested <= 2'h0;
            words_filled <= 2'h0;
            miss_set <= {S{1'b0}};
            miss_tag <= {T{1'b0}};
            miss_write <= 1'b0;
            miss_write_data <= 32'h0;
            miss_write_mask <= 4'h0;
            miss_write_word_off <= 2'h0;
            miss_way <= 2'h0;
            miss_write_word_data <= 32'h0;
            serviced_a_miss <= 1'b0;
            serviced_data <= 32'h0;

            valid[0] <= 4'b0000; plru[0] <= 3'b000;
            valid[1] <= 4'b0000; plru[1] <= 3'b000;
            valid[2] <= 4'b0000; plru[2] <= 3'b000;
            valid[3] <= 4'b0000; plru[3] <= 3'b000;
            valid[4] <= 4'b0000; plru[4] <= 3'b000;
            valid[5] <= 4'b0000; plru[5] <= 3'b000;
            valid[6] <= 4'b0000; plru[6] <= 3'b000;
            valid[7] <= 4'b0000; plru[7] <= 3'b000;
            valid[8] <= 4'b0000; plru[8] <= 3'b000;
            valid[9] <= 4'b0000; plru[9] <= 3'b000;
            valid[10] <= 4'b0000; plru[10] <= 3'b000;
            valid[11] <= 4'b0000; plru[11] <= 3'b000;
            valid[12] <= 4'b0000; plru[12] <= 3'b000;
            valid[13] <= 4'b0000; plru[13] <= 3'b000;
            valid[14] <= 4'b0000; plru[14] <= 3'b000;
            valid[15] <= 4'b0000; plru[15] <= 3'b000;
            valid[16] <= 4'b0000; plru[16] <= 3'b000;
            valid[17] <= 4'b0000; plru[17] <= 3'b000;
            valid[18] <= 4'b0000; plru[18] <= 3'b000;
            valid[19] <= 4'b0000; plru[19] <= 3'b000;
            valid[20] <= 4'b0000; plru[20] <= 3'b000;
            valid[21] <= 4'b0000; plru[21] <= 3'b000;
            valid[22] <= 4'b0000; plru[22] <= 3'b000;
            valid[23] <= 4'b0000; plru[23] <= 3'b000;
            valid[24] <= 4'b0000; plru[24] <= 3'b000;
            valid[25] <= 4'b0000; plru[25] <= 3'b000;
            valid[26] <= 4'b0000; plru[26] <= 3'b000;
            valid[27] <= 4'b0000; plru[27] <= 3'b000;
            valid[28] <= 4'b0000; plru[28] <= 3'b000;
            valid[29] <= 4'b0000; plru[29] <= 3'b000;
            valid[30] <= 4'b0000; plru[30] <= 3'b000;
            valid[31] <= 4'b0000; plru[31] <= 3'b000;
        end else begin
            case (state)
                READY: begin
                    if (i_req_ren || i_req_wen) begin
                        if (hit) begin
                            if (i_req_wen) begin
                                case (hit_way)
                                    2'd0: datas0[req_set][req_word_off] <= hit_write_word;
                                    2'd1: datas1[req_set][req_word_off] <= hit_write_word;
                                    2'd2: datas2[req_set][req_word_off] <= hit_write_word;
                                    default: datas3[req_set][req_word_off] <= hit_write_word;
                                endcase
                            end

                            plru[req_set] <= (hit_way == 2'd0) ? {1'b1, 1'b1, plru[req_set][0]} :
                                              (hit_way == 2'd1) ? {1'b1, 1'b0, plru[req_set][0]} :
                                              (hit_way == 2'd2) ? {1'b0, plru[req_set][1], 1'b1} :
                                                                 {1'b0, plru[req_set][1], 1'b0};
                            serviced_a_miss <= 1'b0;
                        end else begin
                            state <= MISS_FILL;
                            miss_set <= req_set;
                            miss_tag <= req_tag;
                            miss_write <= i_req_wen;
                            miss_write_data <= i_req_wdata;
                            miss_write_mask <= i_req_mask;
                            miss_write_word_off <= req_word_off;
                            miss_way <= !valid[req_set][0] ? 2'd0 :
                                        !valid[req_set][1] ? 2'd1 :
                                        !valid[req_set][2] ? 2'd2 :
                                        !valid[req_set][3] ? 2'd3 :
                                        (!plru[req_set][2] ? (plru[req_set][1] ? 2'd1 : 2'd0)
                                                          : (plru[req_set][0] ? 2'd3 : 2'd2));
                            miss_write_word_data <= 32'h0;
                            mem_req_offset <= 4'h0;
                            words_requested <= 2'h0;
                            words_filled <= 2'h0;
                            serviced_a_miss <= 1'b0;
                        end
                    end else begin
                        serviced_a_miss <= 1'b0;
                    end
                end

                MISS_FILL: begin
                    if (words_requested < 32'd4 && i_mem_ready) begin
                        words_requested <= words_requested + 1'b1;
                        mem_req_offset <= mem_req_offset + 4'h4;
                    end

                    if (i_mem_valid) begin
                        fill_word = i_mem_rdata;
                        if (miss_write && (words_filled == {30'b0, miss_write_word_off})) begin
                            fill_word = {
                                miss_write_mask[3] ? miss_write_data[31:24] : i_mem_rdata[31:24],
                                miss_write_mask[2] ? miss_write_data[23:16] : i_mem_rdata[23:16],
                                miss_write_mask[1] ? miss_write_data[15:8]  : i_mem_rdata[15:8],
                                miss_write_mask[0] ? miss_write_data[7:0]   : i_mem_rdata[7:0]
                            };
                            miss_write_word_data <= fill_word;
                        end

                        case (miss_way)
                            2'd0: datas0[miss_set][words_filled] <= fill_word;
                            2'd1: datas1[miss_set][words_filled] <= fill_word;
                            2'd2: datas2[miss_set][words_filled] <= fill_word;
                            default: datas3[miss_set][words_filled] <= fill_word;
                        endcase

                        if (words_filled == {30'b0, miss_write_word_off}) begin
                            serviced_data <= fill_word;
                        end

                        if (words_filled == 32'd3) begin
                            case (miss_way)
                                2'd0: tags0[miss_set] <= miss_tag;
                                2'd1: tags1[miss_set] <= miss_tag;
                                2'd2: tags2[miss_set] <= miss_tag;
                                default: tags3[miss_set] <= miss_tag;
                            endcase
                            valid[miss_set][miss_way] <= 1'b1;
                            plru[miss_set] <= (miss_way == 2'd0) ? {1'b1, 1'b1, plru[miss_set][0]} :
                                               (miss_way == 2'd1) ? {1'b1, 1'b0, plru[miss_set][0]} :
                                               (miss_way == 2'd2) ? {1'b0, plru[miss_set][1], 1'b1} :
                                                                  {1'b0, plru[miss_set][1], 1'b0};
                            serviced_a_miss <= 1'b1;

                            if (miss_write) begin
                                state <= MISS_WB;
                            end else if (miss_should_start_prefetch && (words_requested == words_filled)) begin
                                state <= PREFETCH_FILL;
                                miss_set <= miss_prefetch_set;
                                miss_tag <= miss_prefetch_tag;
                                miss_write <= 1'b0;
                                miss_write_data <= 32'h0;
                                miss_write_mask <= 4'h0;
                                miss_write_word_off <= 2'h0;
                                miss_way <= !valid[miss_prefetch_set][0] ? 2'd0 :
                                            !valid[miss_prefetch_set][1] ? 2'd1 :
                                            !valid[miss_prefetch_set][2] ? 2'd2 :
                                            !valid[miss_prefetch_set][3] ? 2'd3 :
                                            (!plru[miss_prefetch_set][2] ? (plru[miss_prefetch_set][1] ? 2'd1 : 2'd0)
                                                                        : (plru[miss_prefetch_set][0] ? 2'd3 : 2'd2));
                                miss_write_word_data <= 32'h0;
                                mem_req_offset <= 4'h0;
                                words_requested <= 2'h0;
                                words_filled <= 2'h0;
                            end else begin
                                state <= READY;
                                mem_req_offset <= 4'h0;
                                words_requested <= 32'h0;
                                                            words_filled <= 32'h0;
                            end
                        end else begin
                            words_filled <= words_filled + 1'b1;
                        end
                    end
                end

                PREFETCH_FILL: begin
                    if (words_requested < 32'd4 && i_mem_ready) begin
                        words_requested <= words_requested + 1'b1;
                        mem_req_offset <= mem_req_offset + 4'h4;
                    end

                    if (i_mem_valid) begin
                        fill_word = i_mem_rdata;

                        case (miss_way)
                            2'd0: datas0[miss_set][words_filled] <= fill_word;
                            2'd1: datas1[miss_set][words_filled] <= fill_word;
                            2'd2: datas2[miss_set][words_filled] <= fill_word;
                            default: datas3[miss_set][words_filled] <= fill_word;
                        endcase

                        if (words_filled == 32'd3) begin
                            case (miss_way)
                                2'd0: tags0[miss_set] <= miss_tag;
                                2'd1: tags1[miss_set] <= miss_tag;
                                2'd2: tags2[miss_set] <= miss_tag;
                                default: tags3[miss_set] <= miss_tag;
                            endcase
                            valid[miss_set][miss_way] <= 1'b1;
                            plru[miss_set] <= (miss_way == 2'd0) ? {1'b1, 1'b1, plru[miss_set][0]} :
                                               (miss_way == 2'd1) ? {1'b1, 1'b0, plru[miss_set][0]} :
                                               (miss_way == 2'd2) ? {1'b0, plru[miss_set][1], 1'b1} :
                                                                  {1'b0, plru[miss_set][1], 1'b0};
                            state <= READY;
                        end else begin
                            words_filled <= words_filled + 1'b1;
                        end
                    end
                end

                MISS_WB: begin
                        if (i_mem_ready) begin
                        if (miss_should_start_prefetch && (words_requested == words_filled)) begin
                            state <= PREFETCH_FILL;
                            miss_set <= miss_prefetch_set;
                            miss_tag <= miss_prefetch_tag;
                            miss_write <= 1'b0;
                            miss_write_data <= 32'h0;
                            miss_write_mask <= 4'h0;
                            miss_write_word_off <= 2'h0;
                            miss_way <= !valid[miss_prefetch_set][0] ? 2'd0 :
                                        !valid[miss_prefetch_set][1] ? 2'd1 :
                                        !valid[miss_prefetch_set][2] ? 2'd2 :
                                        !valid[miss_prefetch_set][3] ? 2'd3 :
                                        (!plru[miss_prefetch_set][2] ? (plru[miss_prefetch_set][1] ? 2'd1 : 2'd0)
                                                                    : (plru[miss_prefetch_set][0] ? 2'd3 : 2'd2));
                            miss_write_word_data <= 32'h0;
                            mem_req_offset <= 4'h0;
                            words_requested <= 2'h0;
                            words_filled <= 2'h0;
                        end else begin
                            state <= READY;
                        end
                    end
                end

                default: begin
                    state <= READY;
                    words_requested <= 2'h0;
                    words_filled <= 2'h0;
                    mem_req_offset <= 4'h0;
                    serviced_a_miss <= 1'b0;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
