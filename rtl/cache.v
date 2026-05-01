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
    localparam DEPTH = 2 ** S;
    localparam W = 4;
    localparam T = 32 - O - S;
    localparam D = 2 ** O / 4;

    reg [31:0] datas0 [DEPTH - 1:0][D - 1:0];
    reg [31:0] datas1 [DEPTH - 1:0][D - 1:0];
    reg [31:0] datas2 [DEPTH - 1:0][D - 1:0];
    reg [31:0] datas3 [DEPTH - 1:0][D - 1:0];
    reg [T - 1:0] tags0 [DEPTH - 1:0];
    reg [T - 1:0] tags1 [DEPTH - 1:0];
    reg [T - 1:0] tags2 [DEPTH - 1:0];
    reg [T - 1:0] tags3 [DEPTH - 1:0];
    reg [3:0] valid [DEPTH - 1:0];
    reg [2:0] plru [DEPTH - 1:0];

    function [31:0] merge_masked_word;
        input [31:0] old_word;
        input [31:0] new_word;
        input [3:0] mask;
        begin
            merge_masked_word[31:24] = mask[3] ? new_word[31:24] : old_word[31:24];
            merge_masked_word[23:16] = mask[2] ? new_word[23:16] : old_word[23:16];
            merge_masked_word[15: 8] = mask[1] ? new_word[15: 8] : old_word[15: 8];
            merge_masked_word[ 7: 0] = mask[0] ? new_word[ 7: 0] : old_word[ 7: 0];
        end
    endfunction

    function [31:0] mask_word;
        input [31:0] word;
        input [3:0] mask;
        begin
            mask_word[31:24] = mask[3] ? word[31:24] : 8'h00;
            mask_word[23:16] = mask[2] ? word[23:16] : 8'h00;
            mask_word[15: 8] = mask[1] ? word[15: 8] : 8'h00;
            mask_word[ 7: 0] = mask[0] ? word[ 7: 0] : 8'h00;
        end
    endfunction

    function [1:0] choose_victim_way;
        input [3:0] valid_bits;
        input [2:0] plru_bits;
        begin
            if (!valid_bits[0]) begin
                choose_victim_way = 2'd0;
            end else if (!valid_bits[1]) begin
                choose_victim_way = 2'd1;
            end else if (!valid_bits[2]) begin
                choose_victim_way = 2'd2;
            end else if (!valid_bits[3]) begin
                choose_victim_way = 2'd3;
            end else if (!plru_bits[2]) begin
                choose_victim_way = plru_bits[1] ? 2'd1 : 2'd0;
            end else begin
                choose_victim_way = plru_bits[0] ? 2'd3 : 2'd2;
            end
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

    reg [31:0] cache_read_data;
    always @* begin
        case (hit_way)
            2'd0: cache_read_data = way0_data;
            2'd1: cache_read_data = way1_data;
            2'd2: cache_read_data = way2_data;
            default: cache_read_data = way3_data;
        endcase
    end

    wire [31:0] masked_read_data = mask_word(cache_read_data, i_req_mask);
    wire [31:0] hit_write_word = merge_masked_word(cache_read_data, i_req_wdata, i_req_mask);

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

    assign o_busy = (state == MISS_FILL) || (state == MISS_WB) || ((state == PREFETCH_FILL) && miss);
    assign o_mem_addr = (state == MISS_FILL) ? mem_req_addr :
                        (state == MISS_WB) ? writeback_addr :
                        (state == PREFETCH_FILL) ? mem_req_addr :
                        i_req_addr;
    assign o_mem_ren = (((state == MISS_FILL) || (state == PREFETCH_FILL)) &&
                        (words_requested < 32'd4) && i_mem_ready && !(hit && i_req_wen));
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

            for (set_idx = 0; set_idx < DEPTH; set_idx = set_idx + 1) begin
                valid[set_idx] <= 4'b0000;
                plru[set_idx] <= 3'b000;
            end
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

                            plru[req_set] <= update_plru(plru[req_set], hit_way);
                            serviced_a_miss <= 1'b0;

                            if (should_start_prefetch) begin
                                state <= PREFETCH_FILL;
                                miss_set <= prefetch_set;
                                miss_tag <= prefetch_tag;
                                miss_write <= 1'b0;
                                miss_write_data <= 32'h0;
                                miss_write_mask <= 4'h0;
                                miss_write_word_off <= 2'h0;
                                miss_way <= choose_victim_way(valid[prefetch_set], plru[prefetch_set]);
                                miss_write_word_data <= 32'h0;
                                mem_req_offset <= 4'h0;
                                words_requested <= 2'h0;
                                words_filled <= 2'h0;
                            end
                        end else begin
                            state <= MISS_FILL;
                            miss_set <= req_set;
                            miss_tag <= req_tag;
                            miss_write <= i_req_wen;
                            miss_write_data <= i_req_wdata;
                            miss_write_mask <= i_req_mask;
                            miss_write_word_off <= req_word_off;
                            miss_way <= choose_victim_way(valid[req_set], plru[req_set]);
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
                            fill_word = merge_masked_word(i_mem_rdata, miss_write_data, miss_write_mask);
                            miss_write_word_data <= fill_word;
                        end

                        case (miss_way)
                            2'd0: datas0[miss_set][words_filled] <= fill_word;
                            2'd1: datas1[miss_set][words_filled] <= fill_word;
                            2'd2: datas2[miss_set][words_filled] <= fill_word;
                            default: datas3[miss_set][words_filled] <= fill_word;
                        endcase

                        if (words_filled == {30'b0, req_word_off}) begin
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
                            plru[miss_set] <= update_plru(plru[miss_set], miss_way);
                            serviced_a_miss <= 1'b1;

                            if (miss_write) begin
                                state <= MISS_WB;
                            end else if (should_start_prefetch) begin
                                state <= PREFETCH_FILL;
                                miss_set <= prefetch_set;
                                miss_tag <= prefetch_tag;
                                miss_write <= 1'b0;
                                miss_write_data <= 32'h0;
                                miss_write_mask <= 4'h0;
                                miss_write_word_off <= 2'h0;
                                miss_way <= choose_victim_way(valid[prefetch_set], plru[prefetch_set]);
                                miss_write_word_data <= 32'h0;
                                mem_req_offset <= 4'h0;
                                words_requested <= 2'h0;
                                words_filled <= 2'h0;
                            end else begin
                                state <= READY;
                            end
                        end else begin
                            words_filled <= words_filled + 1'b1;
                        end
                    end
                end

                PREFETCH_FILL: begin
                    if (words_requested < 32'd4 && i_mem_ready && !(hit && i_req_wen)) begin
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
                            plru[miss_set] <= update_plru(plru[miss_set], miss_way);
                            state <= READY;
                        end else begin
                            words_filled <= words_filled + 1'b1;
                        end
                    end
                end

                MISS_WB: begin
                    if (i_mem_ready) begin
                        if (should_start_prefetch) begin
                            state <= PREFETCH_FILL;
                            miss_set <= prefetch_set;
                            miss_tag <= prefetch_tag;
                            miss_write <= 1'b0;
                            miss_write_data <= 32'h0;
                            miss_write_mask <= 4'h0;
                            miss_write_word_off <= 2'h0;
                            miss_way <= choose_victim_way(valid[prefetch_set], plru[prefetch_set]);
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
