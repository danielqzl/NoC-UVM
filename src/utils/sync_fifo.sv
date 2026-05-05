module sync_fifo #(
    parameter int DEPTH = 8, // must be a power of 2
    parameter int WIDTH = 64,
    parameter bit SHOW_AHEAD = 1'b1
) (
    input  logic clk, rst_n,
    input  logic clr,

    input  logic wr_en, 
    input  logic [WIDTH-1:0] wr_data,
    output logic full,

    input  logic rd_en,
    output logic [WIDTH-1:0] rd_data,
    output logic empty
);

    localparam PTR_W = $clog2(DEPTH);
    logic [PTR_W:0] w_ptr, r_ptr;

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
endmodule

