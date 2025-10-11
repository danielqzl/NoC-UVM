
// ----------------------------------------------------------------------------
// Virtual Output Queue
// ----------------------------------------------------------------------------
module noc_voq 
    import noc_pkg::*;
#(
    parameter int WIDTH = 64,
    parameter int DEPTH = 4,
    parameter int VC_ID = 0,
    parameter int OUTPUT_ID = 0,

    parameter int N = 3
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [7:0] multicast_map [N], 

    input  logic enqueue,
    input  flit_s flit_in,

    //input  logic inhibit_in,
    output logic inhibit, inhibit_d1,
      
     
    input  logic grant, grant_valid,
    output flit_s flit_out,
    output logic req
);
    logic full, full_p, empty;
    logic match;
    logic accept_flit;
    logic wr_en, rd_en;

    assign rd_en = grant & grant_valid;
    voq_fifo #(.WIDTH (WIDTH), .DEPTH (DEPTH)) u_queue (
        .clk(clk), .rst_n(rst_n), .clr(1'b0),
        .wr_en(wr_en), 
        .wr_data(flit_in), 
        .full(full), 
        .full_p(full_p),
        .rd_en(rd_en),   // dequeue request
        .rd_data(flit_out),  // data out
        .empty(empty) 
    );

    assign req = ~empty;

    assign match = |(flit_in.dst & multicast_map[OUTPUT_ID]); 
    assign accept_flit = (match & (flit_in.vc[1] == VC_ID));

    // need to accept flit but currently has <2 free slot, store the flit in reserved area. 
    assign inhibit = accept_flit & full_p;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            inhibit_d1 <= '0;
        end else if (inhibit) begin
            inhibit_d1 <= '1;
        end else if (!full) begin
            inhibit_d1 <= 0;
        end
    end 

    // only enqueue when commanded and should accept 
    assign wr_en = accept_flit & enqueue; 
             
endmodule



module voq_fifo #(
    parameter int DEPTH = 8, // must be a power of 2
    parameter int WIDTH = 64,
    parameter bit SHOW_AHEAD = 1'b1
) (
    input  logic clk, rst_n,
    input  logic clr,

    input  logic wr_en, 
    input  logic [WIDTH-1:0] wr_data,
    output logic full, full_p,

    input  logic rd_en,
    output logic [WIDTH-1:0] rd_data,
    output logic empty
);

    localparam PTR_W = $clog2(DEPTH);
    logic [PTR_W:0] w_ptr, r_ptr;
    logic [PTR_W:0] w_ptr_1;  // second read ptr

    logic [WIDTH-1:0] fifo [DEPTH];

    // To write data to FIFO
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            w_ptr <= '0;
            for (int i = 0; i < DEPTH; i++) fifo[i] <= '0; 
        end else if (clr) begin
            w_ptr <= '0;
        end else if(wr_en & !full)begin
            fifo[w_ptr[PTR_W-1:0]] <= wr_data;
            w_ptr <= w_ptr + 1;
        end
    end

    assign w_ptr_1 = w_ptr + 1;

    // Read pointer 
    always_ff @(posedge clk) begin
        if (!rst_n | clr) begin
            r_ptr <= 0;
        end else if(rd_en & !empty) begin
            r_ptr <= r_ptr + 1;
        end
    end

    // To read data from FIFO
    generate 
        if (SHOW_AHEAD) begin : g_showahead  // combinational read path
            assign rd_data = fifo[r_ptr[PTR_W-1:0]];
        end 
        else begin : g_registered       // registered read path
            logic [WIDTH-1:0] rd_data_r;
            always_ff @(posedge clk) begin
                if(rd_en & !empty) begin
                    rd_data_r <= fifo[r_ptr[PTR_W-1:0]];
                end
            end
            assign rd_data = rd_data_r;
        end
    endgenerate

    assign full  = ((w_ptr[PTR_W] != r_ptr[PTR_W]) && (w_ptr[PTR_W-1:0] == r_ptr[PTR_W-1:0]));
    assign empty = ((w_ptr[PTR_W] == r_ptr[PTR_W]) && (w_ptr[PTR_W-1:0] == r_ptr[PTR_W-1:0]));

    assign full_p = ((w_ptr_1[PTR_W] != r_ptr[PTR_W]) && (w_ptr_1[PTR_W-1:0] == r_ptr[PTR_W-1:0]));
endmodule




