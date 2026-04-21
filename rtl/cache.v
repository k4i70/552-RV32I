`default_nettype none

module cache (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // External memory interface. See hart interface for details. This
    // interface is nearly identical to the phase 5 memory interface, with the
    // exception that the byte mask (`o_mem_mask`) has been removed. This is
    // no longer needed as the cache will only access the memory at word
    // granularity, and implement masking internally.
    input  wire        i_mem_ready,
    output wire [31:0] o_mem_addr,
    output wire        o_mem_ren,
    output wire        o_mem_wen,
    output wire [31:0] o_mem_wdata,
    input  wire [31:0] i_mem_rdata,
    input  wire        i_mem_valid,
    // Interface to CPU hart. This is nearly identical to the phase 5 hart memory
    // interface, but includes a stall signal (`o_busy`), and the input/output
    // polarities are swapped for obvious reasons.
    //
    // The CPU should use this as a stall signal for both instruction fetch
    // (IF) and memory (MEM) stages, from the instruction or data cache
    // respectively. If a memory request is made (`i_req_ren` for instruction
    // cache, or either `i_req_ren` or `i_req_wen` for data cache), this
    // should be asserted *combinationally* if the request results in a cache
    // miss.
    //
    // In case of a cache miss, the CPU must stall the respective pipeline
    // stage and deassert ren/wen on subsequent cycles, until the cache
    // deasserts `o_busy` to indicate it has serviced the cache miss. However,
    // the CPU must keep the other request lines constant. For example, the
    // CPU should not change the request address while stalling.
    output wire        o_busy,
    // 32-bit read/write address to access from the cache. This should be
    // 32-bit aligned (i.e. the two LSBs should be zero). See `i_req_mask` for
    // how to perform half-word and byte accesses to unaligned addresses.
    input  wire [31:0] i_req_addr,
    // When asserted, the cache should perform a read at the aligned address
    // specified by `i_req_addr` and return the 32-bit word at that address,
    // either immediately (i.e. combinationally) on a cache hit, or
    // synchronously on a cache miss. It is illegal to assert this and
    // `i_dmem_wen` on the same cycle.
    input  wire        i_req_ren,
    // When asserted, the cache should perform a write at the aligned address
    // specified by `i_req_addr` with the 32-bit word provided in
    // `o_req_wdata` (specified by the mask). This is necessarily synchronous,
    // but may either happen on the next clock edge (on a cache hit) or after
    // multiple cycles of latency (cache miss). As the cache is write-through
    // and write-allocate, writes must be applied to both the cache and
    // underlying memory.
    // It is illegal to assert this and `i_dmem_ren` on the same cycle.
    input  wire        i_req_wen,
    // The memory interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    input  wire [ 3:0] i_req_mask,
    // The 32-bit word to write to memory, if the request is a write
    // (i_req_wen is asserted). Only the bytes corresponding to set bits in
    // the mask should be written into the cache (and to backing memory).
    input  wire [31:0] i_req_wdata,
    // THe 32-bit data word read from memory on a read request.
    output wire [31:0] o_res_rdata
);
    // These parameters are equivalent to those provided in the project
    // 6 specification. Feel free to use them, but hardcoding these numbers
    // rather than using the localparams is also permitted, as long as the
    // same values are used (and consistent with the project specification).
    //
    // 32 sets * 2 ways per set * 16 bytes per way = 1K cache
    localparam O = 4;            // 4 bit offset => 16 byte cache line
    localparam S = 5;            // 5 bit set index => 32 sets
    localparam DEPTH = 32;   // 32 sets
    localparam W = 2;            // 2 way set associative, NMRU
    localparam T = 23;   // 23 bit tag
    localparam D = 4;   // 16 bytes per line / 4 bytes per word = 4 words per line

    // The following memory arrays model the cache structure. As this is
    // an internal implementation detail, you are *free* to modify these
    // arrays as you please.

    // Backing memory, modeled as two separate ways.
    reg [   31:0] datas0 [DEPTH - 1:0][D - 1:0];
    reg [   31:0] datas1 [DEPTH - 1:0][D - 1:0];
    reg [T - 1:0] tags0  [DEPTH - 1:0];
    reg [T - 1:0] tags1  [DEPTH - 1:0];
    reg [1:0] valid [DEPTH - 1:0];
    reg       lru   [DEPTH - 1:0];

    // Address decoding
    wire [T-1:0]     req_tag      = i_req_addr[31:9];
    wire [S-1:0]     req_set      = i_req_addr[8:4];
    wire [3:0]       req_offset   = i_req_addr[3:0];
    wire [1:0]       req_word_off = i_req_addr[3:2];
    
    // Hit/Miss detection 
    wire way0_match = valid[req_set][0] && (tags0[req_set] == req_tag);
    wire way1_match = valid[req_set][1] && (tags1[req_set] == req_tag);
    wire hit = way0_match || way1_match;
    wire hit_way = way1_match;  // 0 if way0 hits, 1 if way1 hits
    
    wire miss = (i_req_ren || i_req_wen) && !hit;

    // Read path
    wire [31:0] way0_data = datas0[req_set][req_word_off];
    wire [31:0] way1_data = datas1[req_set][req_word_off];
    wire [31:0] cache_read_data = hit_way ? way1_data : way0_data;
    
    // Apply read mask
    wire [31:0] masked_read_data;
    assign masked_read_data[31:24] = i_req_mask[3] ? cache_read_data[31:24] : 8'h00;
    assign masked_read_data[23:16] = i_req_mask[2] ? cache_read_data[23:16] : 8'h00;
    assign masked_read_data[15: 8] = i_req_mask[1] ? cache_read_data[15: 8] : 8'h00;
    assign masked_read_data[ 7: 0] = i_req_mask[0] ? cache_read_data[ 7: 0] : 8'h00;
    
    // Miss handling state machine
    reg state;
    localparam READY = 1'b0;
    localparam MISS  = 1'b1;
    
    reg [S-1:0] miss_set;
    reg [T-1:0] miss_tag;
    reg [3:0]   mem_req_offset;
    reg [3:0]   words_filled;   // Tracks which words have been filled (0-3)
    reg         miss_write;
    reg [31:0]  miss_write_data;
    reg [3:0]   miss_write_mask;
    reg [1:0]   miss_write_word_off;  // Which word was being written
    reg         read_inflight;

    reg         serviced_a_miss;
    reg [31:0]  serviced_data;

    // Write data mask: for writes during miss fill
    wire [31:0] write_word;
    assign write_word[31:24] = miss_write_mask[3] ? miss_write_data[31:24] : 8'h00;
    assign write_word[23:16] = miss_write_mask[2] ? miss_write_data[23:16] : 8'h00;
    assign write_word[15: 8] = miss_write_mask[1] ? miss_write_data[15: 8] : 8'h00;
    assign write_word[ 7: 0] = miss_write_mask[0] ? miss_write_data[ 7: 0] : 8'h00;
    
    // Determine replacement way on miss
    wire victim_way = lru[miss_set];  // 0 if way0 is LRU, 1 if way1 is LRU
    
    // Memory request generation
    // During miss handling, request words sequentially from memory
    wire [31:0] mem_req_addr = {miss_tag, miss_set, mem_req_offset};
    
    // For write-through on hits, address is the request address
    wire [31:0] write_req_addr = i_req_addr;
    wire [31:0] write_req_data = i_req_wdata;
    wire write_hit_wait = (state == READY) && hit && i_req_wen && !i_mem_ready;

    assign o_busy = (state == MISS) || miss || write_hit_wait;
    assign o_mem_addr = (state == MISS) ? mem_req_addr : write_req_addr;

    // Memory reads: issue one miss-fill read at a time when memory is ready.
    assign o_mem_ren = (state == MISS) && (words_filled < 4) && !read_inflight && i_mem_ready;

    // Memory writes: write hits (write-through) or write misses (after fetch)
    assign o_mem_wen = (hit && i_req_wen && i_mem_ready) ||
                        ((state == MISS) && miss_write && (words_filled == 4) && i_mem_ready);

    // Write data: the word being written
    assign o_mem_wdata = (hit && i_req_wen) ? write_req_data : write_word;

    // Cache update on memory return
    // Output assignment
    assign o_res_rdata = hit ? masked_read_data : (serviced_a_miss ? serviced_data : 32'h0);

    // Sequential logic - state machine and cache updates
    
    always @(posedge i_clk) begin
        if (i_rst) begin
            state <= READY;
            words_filled <= 4'h0;
            mem_req_offset <= 4'h0;
            miss_set <= 5'h0;
            miss_tag <= 23'h0;
            miss_write <= 1'b0;
            miss_write_data <= 32'h0;
            miss_write_mask <= 4'h0;
            miss_write_word_off <= 2'h0;
            read_inflight <= 1'b0;
            serviced_a_miss <= 1'b0;
            serviced_data <= 32'b0;
            
            // Initialize cache as empty
            valid[ 0] <= 2'b00; lru[ 0] <= 1'b0;
            valid[ 1] <= 2'b00; lru[ 1] <= 1'b0;
            valid[ 2] <= 2'b00; lru[ 2] <= 1'b0;
            valid[ 3] <= 2'b00; lru[ 3] <= 1'b0;
            valid[ 4] <= 2'b00; lru[ 4] <= 1'b0;
            valid[ 5] <= 2'b00; lru[ 5] <= 1'b0;
            valid[ 6] <= 2'b00; lru[ 6] <= 1'b0;
            valid[ 7] <= 2'b00; lru[ 7] <= 1'b0;
            valid[ 8] <= 2'b00; lru[ 8] <= 1'b0;
            valid[ 9] <= 2'b00; lru[ 9] <= 1'b0;
            valid[10] <= 2'b00; lru[10] <= 1'b0;
            valid[11] <= 2'b00; lru[11] <= 1'b0;
            valid[12] <= 2'b00; lru[12] <= 1'b0;
            valid[13] <= 2'b00; lru[13] <= 1'b0;
            valid[14] <= 2'b00; lru[14] <= 1'b0;
            valid[15] <= 2'b00; lru[15] <= 1'b0;
            valid[16] <= 2'b00; lru[16] <= 1'b0;
            valid[17] <= 2'b00; lru[17] <= 1'b0;
            valid[18] <= 2'b00; lru[18] <= 1'b0;
            valid[19] <= 2'b00; lru[19] <= 1'b0;
            valid[20] <= 2'b00; lru[20] <= 1'b0;
            valid[21] <= 2'b00; lru[21] <= 1'b0;
            valid[22] <= 2'b00; lru[22] <= 1'b0;
            valid[23] <= 2'b00; lru[23] <= 1'b0;
            valid[24] <= 2'b00; lru[24] <= 1'b0;
            valid[25] <= 2'b00; lru[25] <= 1'b0;
            valid[26] <= 2'b00; lru[26] <= 1'b0;
            valid[27] <= 2'b00; lru[27] <= 1'b0;
            valid[28] <= 2'b00; lru[28] <= 1'b0;
            valid[29] <= 2'b00; lru[29] <= 1'b0;
            valid[30] <= 2'b00; lru[30] <= 1'b0;
            valid[31] <= 2'b00; lru[31] <= 1'b0;
        end
        else begin
            case (state)
                READY: begin
                    if (i_req_ren || i_req_wen) begin
                        if (hit) begin
                            // Cache hit
                            if (i_req_wen) begin
                                // Hit on write: update cache with mask and write to memory (write-through)
                                if (way0_match) begin
                                    // Update way 0 with masked write
                                    if (i_req_mask[3]) datas0[req_set][req_word_off][31:24] <= i_req_wdata[31:24];
                                    if (i_req_mask[2]) datas0[req_set][req_word_off][23:16] <= i_req_wdata[23:16];
                                    if (i_req_mask[1]) datas0[req_set][req_word_off][15: 8] <= i_req_wdata[15: 8];
                                    if (i_req_mask[0]) datas0[req_set][req_word_off][ 7: 0] <= i_req_wdata[ 7: 0];
                                end else begin
                                    // Update way 1 with masked write
                                    if (i_req_mask[3]) datas1[req_set][req_word_off][31:24] <= i_req_wdata[31:24];
                                    if (i_req_mask[2]) datas1[req_set][req_word_off][23:16] <= i_req_wdata[23:16];
                                    if (i_req_mask[1]) datas1[req_set][req_word_off][15: 8] <= i_req_wdata[15: 8];
                                    if (i_req_mask[0]) datas1[req_set][req_word_off][ 7: 0] <= i_req_wdata[ 7: 0];
                                end
                            end
                            
                            // Update LRU: accessed way is now MRU
                            lru[req_set] <= !hit_way;
                            serviced_a_miss <= 1'b0;
                        end
                        else begin
                            // Cache miss: need to fetch the line
                            state <= MISS;
                            miss_set <= req_set;
                            miss_tag <= req_tag;
                            miss_write <= i_req_wen;
                            miss_write_data <= i_req_wdata;
                            miss_write_mask <= i_req_mask;
                            miss_write_word_off <= req_word_off;
                            words_filled <= 4'h0;
                            mem_req_offset <= 4'h0;
                            read_inflight <= 1'b0;
                            serviced_a_miss <= 1'b0;
                        end
                    end else begin
                        serviced_a_miss <= 1'b0;
                    end
                end
                
                MISS: begin
                    // Fill cache line word by word (for both read and write misses)
                    if (words_filled < 4) begin
                        if (!read_inflight && i_mem_ready) begin
                            // Request next word in the cache line.
                            read_inflight <= 1'b1;
                        end
                        // Fetch phase: get all 4 words from memory
                        if (i_mem_valid) begin
                            read_inflight <= 1'b0;
                            // Word received from memory
                            if (victim_way == 1'b0) begin
                                datas0[miss_set][words_filled] <= i_mem_rdata;
                            end else begin
                                datas1[miss_set][words_filled] <= i_mem_rdata;
                            end
                            
                            if (words_filled == 3) begin
                                // All words received, allocate line in cache
                                if (victim_way == 1'b0) begin
                                    tags0[miss_set] <= miss_tag;
                                    valid[miss_set][0] <= 1'b1;
                                    // For write misses, merge in the write data to the appropriate word
                                    if (miss_write) begin
                                        if (miss_write_mask[3]) datas0[miss_set][miss_write_word_off][31:24] <= miss_write_data[31:24];
                                        if (miss_write_mask[2]) datas0[miss_set][miss_write_word_off][23:16] <= miss_write_data[23:16];
                                        if (miss_write_mask[1]) datas0[miss_set][miss_write_word_off][15: 8] <= miss_write_data[15: 8];
                                        if (miss_write_mask[0]) datas0[miss_set][miss_write_word_off][ 7: 0] <= miss_write_data[ 7: 0];
                                    end
                                    serviced_data <= datas0[miss_set][req_word_off];
                                end else begin
                                    tags1[miss_set] <= miss_tag;
                                    valid[miss_set][1] <= 1'b1;
                                    // For write misses, merge in the write data to the appropriate word
                                    if (miss_write) begin
                                        if (miss_write_mask[3]) datas1[miss_set][miss_write_word_off][31:24] <= miss_write_data[31:24];
                                        if (miss_write_mask[2]) datas1[miss_set][miss_write_word_off][23:16] <= miss_write_data[23:16];
                                        if (miss_write_mask[1]) datas1[miss_set][miss_write_word_off][15: 8] <= miss_write_data[15: 8];
                                        if (miss_write_mask[0]) datas1[miss_set][miss_write_word_off][ 7: 0] <= miss_write_data[ 7: 0];
                                    end
                                    serviced_data <= datas1[miss_set][req_word_off];
                                end
                                lru[miss_set] <= !victim_way;
                                serviced_a_miss <= 1'b1;
                                
                                if (miss_write) begin
                                    // write the word to memory
                                    words_filled <= 4'h4;
                                    mem_req_offset <= miss_write_word_off << 2;  // Set address to written word
                                end else begin
                                    // Hit
                                    state <= READY;
                                end
                            end else begin
                                words_filled <= words_filled + 1;
                                mem_req_offset <= mem_req_offset + 4'h4;
                            end
                        end
                    end
                    else if (miss_write) begin
                        // Write phase: send the modified word to memory
                        if (i_mem_ready) begin
                            // Write complete
                            state <= READY;
                        end
                    end
                end

                default: begin
                    // Recover from any unexpected state encoding.
                    state <= READY;
                    words_filled <= 4'h0;
                    mem_req_offset <= 4'h0;
                    read_inflight <= 1'b0;
                    serviced_a_miss <= 1'b0;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
