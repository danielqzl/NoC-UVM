
// ----------------------------------------------------------------------------
// Receiver
// ----------------------------------------------------------------------------
module noc_receiver 
    import noc_pkg:: *;
#(
    parameter int NUM_OUTPUT_CH = 2,
    parameter DATA_BUF_DEPTH = 4
) (
    input  logic client_clk, client_rst_n,
    input  logic noc_clk, noc_rst_n,

    // Node-side
    output logic [0:1] packet_ready,
    output packet_1_s packet_0,
    output packet_3_s packet_1,
    //output packet_1_s packet_2, 
    input  logic [0:1] rd_vc,

    // Link-side
    input  logic link_valid,
    input  logic [FLIT_W-1:0] link_data,
    output logic [0:1] link_ready 
);
    
    localparam PAD_W = FLIT_PAY_W*2;
    // ----------------------------------------------------
    // Signals 
    // ----------------------------------------------------
    flit_s flit_i;
    assign flit_i = link_data;
    logic  [0:1] vc_w_en;
    logic  [0:1] vc_full;
    
    // ----------------------------------------------------
    // Channel 0 - (VC0)
    // ----------------------------------------------------

    assign vc_w_en[0] = (flit_i.vc == VC_REQ) && (link_valid & ~iq_full[0]);
    assign vc_w_en[1] = (flit_i.vc == VC_DATA) && (link_valid & ~iq_full[1]);

    logic [0:1] iq_full, iq_empty;
    logic [0:1] afifo_full, afifo_wr_en, afifo_empty;
    flit_s flit_iq_o [2]; 

    voq_fifo #(.WIDTH (FLIT_W), .DEPTH (4)) q_vc_0 (
        .clk(noc_clk), .rst_n(noc_rst_n), .clr(1'b0),
        .wr_en(vc_w_en[0]), 
        .wr_data(flit_i), 
        .full(iq_full[0]), 
        .full_p(vc_full[0]),
        .rd_en(afifo_wr_en[0]),   // dequeue request
        .rd_data(flit_iq_o[0]),  // data out
        .empty(iq_empty[0]) 
    );

    assign afifo_wr_en = ~iq_empty & ~afifo_full;
    
    async_fifo #(
        .DATA_WIDTH(FLIT_W), 
        .DEPTH(4),
        .REG_RD(0)
    ) afifo_0 (
        .wclk(noc_clk), .wrst_n(noc_rst_n),
        .w_en(afifo_wr_en[0]), .wdata(flit_iq_o[0]),
        .full(afifo_full[0]), 
        .rclk(client_clk), .rrst_n(client_rst_n),
        .r_en(rd_vc[0]), .rdata(packet_0),
        .empty(afifo_empty[0])
    );
    assign link_ready = ~vc_full & ~iq_full;
    assign packet_ready[0] = ~afifo_empty[0];

    // ----------------------------------------------------
    // Channel 1
    // ----------------------------------------------------
    flit_s flit_deq;
    logic asm_wr_en, asm_rd_en;
    logic asm_full, asm_packet_ready;
    logic [PACKET_W-1:0] asm_packet;
    logic buf_full, buf_empty;


    voq_fifo #(.WIDTH (FLIT_W), .DEPTH (4)) iq_vc_1 (
        .clk(noc_clk), .rst_n(noc_rst_n), .clr(1'b0),
        .wr_en(vc_w_en[1]), 
        .wr_data(flit_i), 
        .full(iq_full[1]), 
        .full_p(vc_full[1]),
        .rd_en(afifo_wr_en[1]),   // dequeue request
        .rd_data(flit_iq_o[1]),  // data out
        .empty(iq_empty[1]) 
    );

    async_fifo #(
        .DATA_WIDTH(FLIT_W), 
        .DEPTH(4),
        .REG_RD(0)
    ) afifo_1 (
        .wclk(noc_clk), .wrst_n(noc_rst_n),
        .w_en(afifo_wr_en[1]), .wdata(flit_iq_o[1]),
        .full(afifo_full[1]), 
        .rclk(client_clk), .rrst_n(client_rst_n),
        .r_en(asm_wr_en), .rdata(flit_deq),
        .empty(afifo_empty[1])
    );

    // -- CDC -- 

    assign asm_wr_en = ~afifo_empty[1] & ~asm_full;
    recv_assembler #(.DEPTH(4)) vc_1_assembler (
        .clk(client_clk), .rst_n(client_rst_n),
        .valid_i(asm_wr_en),
        .flit_i(flit_deq),
        .full(asm_full),
        .packet_o(asm_packet), 
        .packet_ready(asm_packet_ready),
        .read(asm_rd_en)
    );


    // Move assembled packet from assembler to buffer
    assign asm_rd_en = asm_packet_ready & ~buf_full;
    assign packet_ready[1] = ~buf_empty;

    sync_fifo #(.DEPTH(4), .WIDTH(PACKET_W)) u_buf_1 (
        .clk(client_clk), .rst_n(client_rst_n),  .clr(1'b0),
        .full(buf_full),  .empty(buf_empty), 
        .wr_en(asm_rd_en), .wr_data(asm_packet), 
        .rd_en(rd_vc[1]),  .rd_data(packet_1)
    );

    /*
    // ----------------------------------------------------
    // output selection
    // ----------------------------------------------------
    logic [1:0] rd_sel;
    Mux4 #(.WIDTH(PACKET_W)) u_enqueue_mux(
        .in0(packet_0),
        .in1(packet_1),
        .in2(packet_2),
        .in3({PACKET_W{1'b0}}), //should not be selected 
        .sel(rd_sel),
        .out(packet_o)
    );

    
    always_ff @(posedge client_clk) begin
        if (rd_vc[0]) rd_sel <= 0;
        else if (rd_vc[1]) rd_sel <= 1;
        else if (rd_vc[2]) rd_sel <= 2;
        else rd_sel <= 3;
    end
    */

    /*
    // ----------------------------------------------------
    // Channel 2 (optional)
    // ----------------------------------------------------
    generate
        if (NUM_OUTPUT_CH == 3) begin // define CH 2
            logic vc_2_w_en, vc_2_full, vc_2_empty;
            assign vc_2_w_en = (flit_i.vc == VC_RES && link_valid);

            async_fifo #(
                .DATA_WIDTH(FLIT_W), 
                .DEPTH(4),
                .REG_RD(1)
            ) queue_vc_2 (
                .wclk(noc_clk), .wrst_n(noc_rst_n),
                .w_en(vc_2_w_en), .wdata(flit_i),
                .full(vc_2_full), 
                .rclk(client_clk), .rrst_n(client_rst_n),
                .r_en(rd_vc[2]), .rdata(packet_2),
                .empty(vc_2_empty)
            );
            assign link_ready[1] = !vc_1_full && !vc_2_full;
            assign packet_ready[2] = ~vc_2_empty;
        end
        else begin
            assign link_ready[1] = ~vc_1_full;
            assign packet_ready[2] = 0;
        end
    endgenerate
    */

endmodule : noc_receiver


// ----------------------------------------------------------------------------
// Assembler - collects constant-length multi-flit packets
// ----------------------------------------------------------------------------
module recv_assembler 
    import noc_pkg:: *;
#(
    parameter int DEPTH = 4
) (
    input  logic clk, rst_n,
    input  logic valid_i,
    input  logic read,
    input  var flit_s flit_i,

    output logic full,
    output logic [PACKET_W-1:0] packet_o,
    output logic packet_ready
);

    localparam int TAG_W = 4;
    localparam int CNT_W = $clog2(FLITS_PER_PACKET);


    logic [0:DEPTH-1] free, ready;
    logic [TAG_W-1:0] packet_tag [DEPTH];
    logic [0:DEPTH-1] tag_valid;
     
    logic [15:0]      header  [DEPTH];
    logic [PAY_W-1:0] payload [DEPTH];

    assign full = (free == '0); // None free

    // buffer input
    logic [3:0] packet_tag_i;
    assign packet_tag_i = {flit_i.src};

    logic [$clog2(DEPTH)-1:0] input_idx, new_idx, read_idx;
    logic tag_hit;
    assign tag_valid = ~free & ~ready;
    tag_lookup #(.DEPTH(DEPTH), .WIDTH(TAG_W)) u_tag_lookup (
        .tag_array(packet_tag), .tag_in(packet_tag_i), .tag_valid(tag_valid),  
        .hit(tag_hit), .index(input_idx)
    );

    // Accept path 
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            header <= '{default: '0};
            payload <= '{default: '0};
        // 1. Invalid OR Full (Cannot allocate a new entry) 
        end else if (!valid_i || (flit_i.first && full)) begin
            
        end 
        // 2. New packet, Find a free entry
        else if (flit_i.first) begin
            packet_tag[new_idx] <= packet_tag_i;
            header [new_idx] <= flit_i[63:FLIT_PAY_W];
            payload[new_idx][FLIT_PAY_W-1:0] <= flit_i.data;
        end 
        // 3. Existing flit, append to packet buffer 
        else if (tag_hit) begin
            payload[input_idx] <= {payload[input_idx][PACKET_W - FLIT_PAY_W-1:0], flit_i.data}; 
        end
    end

    // status register
    always_ff @(posedge clk) begin
        for (int i = 0; i < DEPTH; i++) begin
            if (!rst_n) begin
                free[i] <= '1;
                ready[i] <= '0;
            end 
            else if (ready[i] && read && (read_idx == i)) begin 
                free[i] <= 1'b1;
                ready[i] <= 1'b0;
            end
            // last flit, packet ready 
            else if (valid_i && flit_i.last && tag_hit && (input_idx == i)) begin 
                ready[i] <= 1'b1;
            end
            else if (valid_i && flit_i.first && !full && (new_idx == i)) begin
                free[i] <= 1'b0;
            end
        end
    end


    assign read_idx = find_first_high(ready);
    assign new_idx = find_first_high(free);
    // output port: first ready entry(packet)
    always_comb begin
        if (ready == '0)
            packet_ready = 1'b0;
        else begin
            packet_ready = 1'b1;
            packet_o = {header[read_idx], payload[read_idx]};
        end
    end


    // Find the first high bit: Must ensure vector is not all zero 
    function automatic logic [$clog2(DEPTH)-1:0] find_first_high (
        input logic [0:DEPTH-1] vec
    );
        for (int i = 0; i < DEPTH; i++) begin
            if (vec[i]) begin
                return i[$clog2(DEPTH)-1:0];
            end
        end
        return '0;
    endfunction


endmodule : recv_assembler
