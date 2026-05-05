// ----------------------------------------------------------------------------
// transmitter  packet => flits 
// ----------------------------------------------------------------------------
module noc_transmitter
    import noc_pkg:: *;
(
    input  logic client_clk, client_rst_n,
    input  logic noc_clk, noc_rst_n,
    // Client-side
    input  logic [0:1] tx_req,           
    input  packet_1_s  tx_packet_0,
    input  packet_3_s  tx_packet_1,
    //input  packet_1_s  tx_packet_2, 

    output logic [0:1] tx_ready,
    output logic [0:1] tx_success,

    // Link‑side flit interface
    input  logic [0:1] link_ready,
    output logic link_valid,
    output logic [FLIT_W-1:0] link_data
);
    // Internal Signals 
    // Enqueue 
    flit_s flit_enq [2]; 
    flit_s flit_deq [2];
    
    // Inject Control
    flit_s flit_out;
    logic  vc_sel;

    // async FIFO enqueue 
    logic [0:1] vc_full, vc_empty;
    logic [0:1] vc_w_en;
    logic [0:1] vc_inject_en;

    // To flit counter
    logic last_flit_flag;
    logic flit_cntr_rst;



    // ----------------------------------------------------
    // Datapath - Ch 0
    // ----------------------------------------------------
    always_comb begin : u_vc_0_ctrl
        flit_enq[0] = tx_packet_0;
        flit_enq[0].first = 1'b0;  
        flit_enq[0].last  = 1'b0;

        tx_ready[0] = ~vc_full[0];
        vc_w_en[0]  = tx_req[0] & tx_ready[0];
    end
    
    async_fifo #(.DATA_WIDTH(FLIT_W), .DEPTH(8)) queue_vc_0 (
        .wclk(client_clk), .wrst_n(client_rst_n),
        .w_en(vc_w_en[0]), .wdata(flit_enq[0]),
        .full(vc_full[0]), 
        
        .rclk(noc_clk), .rrst_n(noc_rst_n),
        .r_en(vc_inject_en[0]), .rdata(flit_deq[0]),
        .empty(vc_empty[0])
    );
    
    
    // ----------------------------------------------------
    // Datapath - Ch 1
    // ----------------------------------------------------
    // buffer signals 
    logic  buf_empty;
    logic  buf_rd_en;
    flit_s buf_rd_flit;

    // FSM Signal  
    logic send_en, fsm_ready;

    // Flit counter
    logic [1:0] flit_cntr;
    always_ff @(posedge client_clk) begin
        if (!client_rst_n || flit_cntr_rst) 
            flit_cntr <= '0;
        else if (send_en)
            flit_cntr <= flit_cntr + 1'b1; 
    end
    assign last_flit_flag = (flit_cntr == 2);


    // flit enqueue wire 
    assign flit_enq[1].src   = tx_packet_1.header.source;
    assign flit_enq[1].dst   = tx_packet_1.header.dest_bitmap;
    assign flit_enq[1].vc    = tx_packet_1.header.vc;
    assign flit_enq[1].first = (flit_cntr == 0);
    assign flit_enq[1].last  = (flit_cntr == 2);
 
    Mux4 #(.WIDTH(FLIT_PAY_W)) u_enqueue_mux(
        .in0(tx_packet_1.payload[3*FLIT_PAY_W-1 : 2*FLIT_PAY_W]),
        .in1(tx_packet_1.payload[2*FLIT_PAY_W-1 : 1*FLIT_PAY_W]),
        .in2(tx_packet_1.payload[1*FLIT_PAY_W-1 : 0]),
        .in3({FLIT_PAY_W{1'b0}}), //should not be selected 
        .sel(flit_cntr),
        .out(flit_enq[1].data)
    );
    
    noc_transmitter_fsm vc1_fsm(
        .clk(client_clk), .rst_n(client_rst_n),
        .tranmit_req(tx_req[1]),
        .queue_ready(buf_empty),
        .last_flit(last_flit_flag),
        
        .flit_cntr_rst(flit_cntr_rst),
        .send_en(send_en),
        .ready(fsm_ready),
        .success(tx_success[1])  
    );


    // Enqueue Contrl
    always_comb begin : u_vc1_ctrl
        tx_ready[1] = fsm_ready & buf_empty; 
        vc_w_en[1]  = send_en; 
        buf_rd_en  = ~vc_full[1] & ~buf_empty; // transfer flit if buffer is not empty 
    end

    sync_fifo #(.DEPTH(4), .WIDTH(FLIT_W)) u_buf_1 (
        .clk(client_clk),  .rst_n(client_rst_n),  .clr(1'b0),
        .full(),  .empty(buf_empty), 
        .wr_en(vc_w_en[1]),   .wr_data(flit_enq[1]), 
        .rd_en(buf_rd_en), .rd_data(buf_rd_flit) 
    );

    async_fifo #(.DATA_WIDTH(FLIT_W), .DEPTH(8)) queue_vc_1 (
        .wclk(client_clk), .wrst_n(client_rst_n),
        .w_en(buf_rd_en), .wdata(buf_rd_flit),
        .full(vc_full[1]), 
        .rclk(noc_clk), .rrst_n(noc_rst_n),
        .r_en(vc_inject_en[1]), .rdata(flit_deq[1]),
        .empty(vc_empty[1])
    );


    // ----------------------------------------------------
    // Inject Flits (CDC) 
    // ----------------------------------------------------
    // link is ready and queue is not empty 
    assign vc_inject_en[1] = link_ready[1] & ~vc_empty[1]; // vc 1 has priority  
    assign vc_inject_en[0] = link_ready[0] & ~vc_empty[0] & ~vc_inject_en[1];  
    assign vc_sel = ~vc_inject_en[0];

    Mux2 #(.WIDTH(FLIT_W)) u_mux_queue_out(
        .in0(flit_deq[0]), .in1(flit_deq[1]), 
        .sel(vc_sel),
        .out(flit_out)
    ); 
    
    // send to link
    always_ff @(posedge noc_clk) begin
        if (!noc_rst_n) begin
            link_valid <= 1'b0;
            link_data <= '0;
        end else if (|vc_inject_en) begin
            link_valid  <= 1'b1;
            link_data   <= flit_out;
        end else begin
            link_valid  <= 1'b0;
        end
    end

endmodule : noc_transmitter



module noc_transmitter_fsm(
    input  logic clk, rst_n,

    input  logic tranmit_req,
    input  logic queue_ready,
    input  logic last_flit,

    output logic flit_cntr_rst,
    output logic send_en,
    output logic ready,
    output logic success  
);
    typedef enum logic {
        IDLE, SEND
    } state_t;

    state_t state, next_state;

    always_ff @(posedge clk) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next state logic
    always_comb begin
        flit_cntr_rst = 1'b0;
        send_en = 1'b0;
        ready = 1'b0;
        success = 1'b0;
        case (state)
            IDLE: begin
                ready = 1'b1;
                if (tranmit_req == 1'b1) begin
                    if (queue_ready) begin
                        success = 1'b1;
                        next_state = SEND;
                    end else begin
                        next_state = IDLE;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            SEND: begin
                send_en = 1'b1;
                if (last_flit) begin
                    flit_cntr_rst = 1'b1;
                    next_state = IDLE;
                end else 
                    next_state = SEND;
            end
            default: next_state = IDLE;
        endcase
    end
endmodule













