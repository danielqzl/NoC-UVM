module tag_lookup #(
    parameter DEPTH = 8,
    parameter WIDTH = 16
)(
    input  var logic [WIDTH-1:0] tag_array [DEPTH],
    input  logic [WIDTH-1:0] tag_in,
    input  logic [0:DEPTH-1] tag_valid,
    output logic             hit,
    output logic [$clog2(DEPTH)-1:0] index
);
    logic [$clog2(DEPTH)-1:0] match_index;

    always_comb begin
        hit = 1'b0;
        match_index = '0;
        for (int i = 0; i < DEPTH; i++) begin
            if (tag_valid[i] && (tag_array[i] == tag_in)) begin
                hit = 1'b1;
                match_index = i[$clog2(DEPTH)-1:0];
                break;
            end
        end
    end

    assign index = match_index;

endmodule
