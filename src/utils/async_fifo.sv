module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 8,
    parameter REG_RD = 0
) (
    // WRITE domain interface
    input  logic wclk,
    input  logic wrst_n,
    input  logic w_en,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic full,

    // READ domain interface
    input  logic rclk,
    input  logic rrst_n,
    input  logic r_en,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic empty
);
    parameter PTR_WIDTH = $clog2(DEPTH);

    logic [PTR_WIDTH:0] wr_ptr_bin, rd_ptr_bin;
    logic [PTR_WIDTH:0] wr_ptr_gray, rd_ptr_gray;
    logic [PTR_WIDTH:0] rd_ptr_gray_sync;
    logic [PTR_WIDTH:0] wr_ptr_gray_sync;

    //-------------------- Pointer synchronizers --------------------------
    synchronizer #(.WIDTH(PTR_WIDTH+1)) u_sync_rptr (
        .clk(wclk), .rst_n(wrst_n),
        .d_in(rd_ptr_gray), .d_out(rd_ptr_gray_sync)
    );

    synchronizer #(.WIDTH(PTR_WIDTH+1)) u_sync_wptr (
        .clk (rclk), .rst_n(rrst_n),
        .d_in(wr_ptr_gray), .d_out(wr_ptr_gray_sync)
    );

    write_ctrl #(.PTR_WIDTH(PTR_WIDTH)) u_wr_ctrl (
        .wr_clk(wclk), .wr_rst_n(wrst_n), .wr_en(w_en),
        .r_ptr_gray_sync(rd_ptr_gray_sync),
        .w_ptr_gray(wr_ptr_gray), .w_ptr_bin(wr_ptr_bin),
        .full(full)
    );

    read_ctrl #(.PTR_WIDTH(PTR_WIDTH)) u_rd_ctrl (
        .rd_clk(rclk), .rd_rst_n(rrst_n), .rd_en(r_en),
        .w_ptr_gray_sync(wr_ptr_gray_sync),
        .r_ptr_gray(rd_ptr_gray), .r_ptr_bin(rd_ptr_bin),
        .empty(empty)  
    );

    fifo_mem #(
        .WIDTH     (DATA_WIDTH),
        .PTR_WIDTH (PTR_WIDTH),
        .DEPTH     (DEPTH),
        .REG_RD    (REG_RD)
    ) u_mem (
        .wr_clk (wclk),
        .wr_en  (w_en & ~full),
        .wr_ptr (wr_ptr_bin),
        .wr_data(wdata),

        .rd_clk (rclk),
        .rd_en  (r_en & ~empty),
        .rd_ptr (rd_ptr_bin),
        .rd_data(rdata)
    );

endmodule


module fifo_mem #(
    parameter WIDTH     = 8,
    parameter PTR_WIDTH = 4,
    parameter DEPTH     = 1 << PTR_WIDTH,
    parameter REG_RD    = 0
) (
    // WRITE PORT -------------------------------------------------------------
    input  logic                wr_clk,
    input  logic                wr_en,
    input  logic [PTR_WIDTH:0]  wr_ptr,
    input  logic [WIDTH-1:0]    wr_data,

    // READ PORT --------------------------------------------------------------
    input  logic                rd_clk,
    input  logic                rd_en,
    input  logic [PTR_WIDTH:0]  rd_ptr,
    output logic [WIDTH-1:0]    rd_data
);
    (* ram_style = "distributed" *) logic [WIDTH-1:0] mem [0:DEPTH-1];

    logic [PTR_WIDTH-1:0] wr_addr, rd_addr;
    assign wr_addr = wr_ptr[PTR_WIDTH-1:0];
    assign rd_addr = rd_ptr[PTR_WIDTH-1:0];

    // WRITE 
    always_ff @(posedge wr_clk) begin
        if (wr_en) mem[wr_addr] <= wr_data;
    end

    // READ 
    generate
        if (REG_RD) begin
            // Sychronous Read 
            always_ff @(posedge rd_clk) begin
                if (rd_en) rd_data <= mem[rd_addr];
            end
        end else begin
            // Asynchronous Read
            assign rd_data = mem[rd_addr];
        end
    endgenerate

endmodule : fifo_mem


module write_ctrl #(parameter PTR_WIDTH = 3) (
    input  logic wr_clk,
    input  logic wr_rst_n,
    input  logic wr_en,
    // Synchronized read pointer from read clock domain
    input  logic [PTR_WIDTH:0] r_ptr_gray_sync,

    output logic [PTR_WIDTH:0] w_ptr_gray, w_ptr_bin,
    output logic full
);
    // Binary & Gray pointers (PTR_WIDTH + 1 to sense full)
    logic [PTR_WIDTH:0] w_ptr_bin_next;
    logic [PTR_WIDTH:0] w_ptr_gray_next;

    // Increment logic
    assign w_ptr_bin_next  = w_ptr_bin + (wr_en & ~full);
    assign w_ptr_gray_next = (w_ptr_bin_next >> 1) ^ w_ptr_bin_next;   // binary‑to‑gray

    // Sequential
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            w_ptr_bin  <= '0;
            w_ptr_gray <= '0;
        end else begin
            w_ptr_bin  <= w_ptr_bin_next;
            w_ptr_gray <= w_ptr_gray_next;
        end
    end

    // Full logic: 
    logic wfull;
    assign wfull = (w_ptr_gray_next == {~r_ptr_gray_sync[PTR_WIDTH:PTR_WIDTH-1],
                                       r_ptr_gray_sync[PTR_WIDTH-2:0]});
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n)
            full <= '0;
        else
            full <= wfull;
    end
endmodule


module read_ctrl #(parameter PTR_WIDTH = 3) (
    input  logic rd_clk,
    input  logic rd_rst_n,
    input  logic rd_en,
    // Synchronized write pointer from write clock domain
    input  logic [PTR_WIDTH:0] w_ptr_gray_sync,

    output logic [PTR_WIDTH:0] r_ptr_gray, r_ptr_bin,
    output logic empty  
);

    // Binary & Gray pointers
    logic [PTR_WIDTH:0] r_ptr_bin_next;
    logic [PTR_WIDTH:0] r_ptr_gray_next;

    // Increment logic
    assign r_ptr_bin_next  = r_ptr_bin + (rd_en & ~empty);
    assign r_ptr_gray_next = (r_ptr_bin_next >> 1) ^ r_ptr_bin_next;

    // Sequential
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            r_ptr_bin  <= '0;
            r_ptr_gray <= '0;
        end else begin
            r_ptr_bin  <= r_ptr_bin_next;
            r_ptr_gray <= r_ptr_gray_next;
        end
    end

    // Empty Logic 
    logic wire_empty;
    assign wire_empty = (r_ptr_gray_next == w_ptr_gray_sync);
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n)
            empty <= 1'b1;
        else
            empty <= wire_empty;
    end
endmodule