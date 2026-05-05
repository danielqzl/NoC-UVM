
//-----------------------------------------------------------------------------
// NoC Crossbar Switch (Comb)
// M input to N output port  
// * The grant matrix must be one‑hot
// * Assume both sides are cleared  
//-----------------------------------------------------------------------------
module noc_crossbar #(
    parameter int N_INPUT = 3,
    parameter int N_OUTPUT = 6,
    parameter int DATA_WIDTH = 64
) (
    input  logic [DATA_WIDTH-1:0] in  [N_OUTPUT][N_INPUT], // Input port array
    input  logic [N_INPUT-1:0] grant  [N_OUTPUT],  // Per‑output select index
    output logic [DATA_WIDTH-1:0] out [N_OUTPUT]    // Output port array
);
    localparam int SEL_WIDTH = $clog2(N_INPUT);

    function automatic logic [SEL_WIDTH-1:0] onehot_to_binary(
        input logic [0:N_INPUT-1] onehot
    );
        for (int i = 0; i < N_INPUT; i++) begin
            if (onehot[i]) return i[SEL_WIDTH-1:0];
        end
        return '0; // no grant  
    endfunction

    logic [SEL_WIDTH-1:0] sel [N_OUTPUT];

    generate
        for (genvar i = 0; i < N_OUTPUT; i++) begin : gen_out_mux
            // A simple pass‑through per output channel
            always_comb begin
                sel[i] = onehot_to_binary(grant[i]);
                // Synthesis tools map this to a mux tree or tri‑state crossbar
                out[i] = in[i][ sel[i] ];
            end
        end
    endgenerate

endmodule


// ----------------------------------------------------------------------------
// N‑Port NoC Router
// ----------------------------------------------------------------------------
module noc_router 
    import noc_pkg:: *;
#(
    parameter N = 3,        // Number of Physical Port 
    parameter VC_CNT = 2,   // Number of Virual Channel 
    parameter VOQ_DEPTH = 4
)(
    input  logic clk,
    input  logic rst_n,

    // multicast map of each port
    input  logic [7:0] multicast_map [N],  

    input  link_s link_i [N],
    output link_s link_o [N]
);  

    localparam N_PORT = N * VC_CNT;  // each VC is treated like a separated output port 
    localparam N_VOQ = N_PORT * N;   // Number of VOQs 

    // flit inputs 
    flit_s flit_in[N]; 
    flit_s flit_deq[0:N_PORT-1][N]; 
    logic  [0:N_PORT-1] output_buf_valid_i;
    logic  [0:N_PORT-1] output_buf_full;

    // ------------------------------------------------------------------------
    // VOQ 
    // ------------------------------------------------------------------------
    logic [0:N-1][0:VC_CNT-1] voq_enq; // enqueue
    logic [0:VC_CNT-1][0:N-1] voq_inhibit [N];
    logic [0:N_PORT-1][0:N-1] voq_req; 
    logic [0:N-1] voq_grant [0:N_PORT-1]; 
    logic [0:N_PORT-1] arb_req_valid, arb_grant_valid;

    generate
    for (genvar i = 0; i < N; i++) begin // per physcial input port 
        for (genvar j = 0; j < VC_CNT; j++) begin // per virtual channel  
            for (genvar k = 0; k < N; k++) begin  // per physcial output port 
                // localparam l = (j * N) + k; // local queue index to input port  
                localparam l = (k * VC_CNT) + j;
                if (i != k) begin
                    noc_voq #(
                        .WIDTH (FLIT_W),
                        .DEPTH (VOQ_DEPTH),
                        .VC_ID(j),
                        .OUTPUT_ID(k), .N(N)
                    ) u_voq (
                        .clk(clk),   .rst_n(rst_n),
                        .multicast_map(multicast_map),
                        .valid_i(link_i[i].valid),
                        .flit_in(flit_in[i]),
                        .inhibit(voq_inhibit[i][j][k]), 
                        .grant(voq_grant[l][i]),
                        .grant_valid(arb_grant_valid[l]),
                        .flit_out(flit_deq[l][i]),
                        .req(voq_req[l][i])
                    );
                end else begin
                    assign voq_req[l][i] = 1'b0;
                    assign flit_deq[l][i] = '0;
                    assign voq_inhibit[i][j][k] = 1'b0;
                end
            end
        end
    end
    endgenerate

    always_comb begin : u_enq_ctrl
        for (int i = 0; i < N; i++) begin
            flit_in[i] = link_i[i].data;
            // Enqueue Logic - all VOQs for this input port has cleared  
            for (int j = 0; j < VC_CNT; j++)
                voq_enq[i][j] = ((voq_inhibit[i][j] == '0) && (link_i[i].valid == 1'b1));  
            // back-pressure
            for (int j = 0; j < VC_CNT; j++) begin
                link_o[i].ready[j] = (voq_inhibit[i][j] == '0);
            end
        end
    end

    // -------------------------------------------------------------------------
    // Arbitration – one RR arbiter per output port
    // -------------------------------------------------------------------------


    generate
    assign arb_req_valid = ~output_buf_full;
    for (genvar i = 0; i < N_PORT; i++) begin : g_arbiters
        rr_arbiter #(.N(N)) u_arb (
            .clk   (clk),
            .rst_n (rst_n),
            .req   (voq_req[i]),
            .req_valid (arb_req_valid[i]),
            .grant (voq_grant[i]),
            .grant_valid(arb_grant_valid[i])
        );
    end
    endgenerate

    // -------------------------------------------------------------------------
    // Cross‑bar
    // -------------------------------------------------------------------------
    flit_s crossbar_out[N_PORT];
    noc_crossbar  #(
        .N_INPUT(N),     
        .N_OUTPUT(N_PORT),     
        .DATA_WIDTH(FLIT_W)  
    ) u_cb (
        .in(flit_deq),  
        .grant(voq_grant), 
        .out(crossbar_out)   
    );

    // -------------------------------------------------------------------------
    // Output buffer
    // -------------------------------------------------------------------------
    generate
    for (genvar i = 0; i < N; i++) begin : g_output_buf
        localparam p = i * VC_CNT;  // slice endpoints 
        localparam q = p + VC_CNT - 1; 
        router_output_buffer u_out_buf (
            .clk(clk),
            .rst_n(rst_n),
            .flit_in(crossbar_out[p : q]),
            .valid_i(arb_grant_valid[p : q]),
            .full(output_buf_full[p : q]),
            .link_ready(link_i[i].ready),
            .link_o(link_o[i])
        );
    end
    endgenerate

endmodule


module router_output_buffer
    import noc_pkg:: *;
#(
    parameter N_VC = 2,
    parameter WIDTH = 64,
    parameter DEPTH = 4
) (
    input  logic clk,
    input  logic rst_n,
    input  flit_s flit_in [N_VC],
    input  logic [0:N_VC-1] valid_i,

    output logic [0:N_VC-1] full,
    
    input  logic [0:1] link_ready,  
    output link_s link_o
);

    logic [0:N_VC-1] empty;
    logic [0:N_VC-1] inject_en;
    logic vc_sel;
    flit_s flit_deq [N_VC];
    flit_s flit_out;

    generate
    for (genvar i = 0; i < N_VC; i++) begin
        sync_fifo #(.WIDTH (WIDTH), .DEPTH (DEPTH)) u_buffer (
            .clk(clk), .rst_n(rst_n), .clr(1'b0),
            .wr_en(valid_i[i]), 
            .wr_data(flit_in[i]), 
            .full(full[i]), 
            .rd_en(inject_en[i]),   // dequeue request
            .rd_data(flit_deq[i]),  // data out
            .empty(empty[i]) 
        );
    end
    endgenerate

    // link is ready and queue is not empty 
    assign inject_en[1] = link_ready[1] & ~empty[1]; 
    assign inject_en[0] = link_ready[0] & ~empty[0] & ~inject_en[1];  
    assign vc_sel = ~inject_en[0];
    Mux2 #(.WIDTH(FLIT_W)) u_mux_out(
        .in0(flit_deq[0]), .in1(flit_deq[1]), 
        .sel(vc_sel),
        .out(flit_out)
    ); 

    // send to link
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            link_o.valid <= 1'b0;
            link_o.data <= '0;
        end
        else if (inject_en != '0) begin
            link_o.valid  <= 1'b1;
            link_o.data   <= flit_out;
        end else begin
            link_o.valid  <= 1'b0;
        end
    end

endmodule