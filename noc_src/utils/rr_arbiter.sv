// ----------------------------------------------------------------------------
// Round Robin Arbiter - Masked Approach 
// Balance between speed and area
// ----------------------------------------------------------------------------
module rr_arbiter #(
    parameter N = 3
)(
    input  logic         clk, rst_n,
    input  logic [N-1:0] req,
    input  logic         req_valid,
    output logic [N-1:0] grant,
    output logic         grant_valid
);

    assign grant_valid = (req_valid && (|req != 0));

    logic [N-1:0] mask, mask_next;
    logic [N-1:0] masked_req;
    logic [N-1:0] masked_grant, unmasked_grant; 

    assign masked_req = req & mask;

    fixed_priority_arbiter #(N) u_pa_unmasked (
        .req(req), 
        .grant(unmasked_grant)
    );
    
    fixed_priority_arbiter #(N) u_pa_masked (
        .req(masked_req), 
        .grant(masked_grant)
    );
    
    always_comb begin
        mask_next = mask;
        if (grant_valid) begin
            mask_next = '1;
            for (int i = 0; i < N; i++) begin
                mask_next[i] = 1'b0;
                if (grant[i]) break;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) 
            mask <= '1;
        else if(req_valid)	 
            mask <= mask_next;
    end

    assign grant = (masked_req == '0) ? unmasked_grant : masked_grant;
  
endmodule



module fixed_priority_arbiter #(
    parameter N = 4
) (
    input  logic [N-1:0] req,
    output logic [N-1:0] grant
);

    logic [N-1:0] higher_pri_req;
    assign higher_pri_req[0] = 1'b0; //LSB has the highest priority 
    
    generate
    for (genvar i = 0; i < N - 1; i++) begin
        assign higher_pri_req[i+1] = higher_pri_req[i] | req[i];
    end
    endgenerate

    assign grant[N-1:0] = req[N-1:0] & ~higher_pri_req[N-1:0];

endmodule

