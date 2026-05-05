module NoC 
    import noc_pkg:: *;
(   
    input  logic noc_clk, noc_rst_n,

    client_if.node n0,
    client_if.node n1,
    client_if.node n2,
    client_if.node n3
);
    localparam VOQ_DEPTH = 4;

    link_s link [10];

    client_node #(2) node_0 (
        .in(n0),
        .noc_clk(noc_clk), .noc_rst_n(noc_rst_n),
        .link_o(link[0]), 
        .link_i(link[1])
    );

    client_node #(2) node_1 (
        .in(n1),
        .noc_clk(noc_clk), .noc_rst_n(noc_rst_n),
        .link_o(link[2]), 
        .link_i(link[3])
    );

    client_node #(2) node_2 (
        .in(n2),
        .noc_clk(noc_clk), .noc_rst_n(noc_rst_n),
        .link_o(link[4]), 
        .link_i(link[5])
    );

    client_node #(2) node_3 (
        .in(n3),
        .noc_clk(noc_clk), .noc_rst_n(noc_rst_n),
        .link_o(link[6]), 
        .link_i(link[7])
    );


    noc_router #(
        .N(3),        
        .VC_CNT(2),  
        .VOQ_DEPTH(VOQ_DEPTH)
    ) u_router_0 (  
        .clk(noc_clk),  .rst_n(noc_rst_n),
        .multicast_map('{8'b0001, 8'b0010, 8'b1100}),
        .link_i('{link[0], link[2], link[9]}),
        .link_o('{link[1], link[3], link[8]})
    );

    noc_router #(
        .N(3),        
        .VC_CNT(2),  
        .VOQ_DEPTH(VOQ_DEPTH)
    ) u_router_1 (  
        .clk(noc_clk),  .rst_n(noc_rst_n),
        .multicast_map('{8'b0100, 8'b1000, 8'b0011}),
        .link_i('{link[4], link[6], link[8]}),
        .link_o('{link[5], link[7], link[9]})
    );



endmodule


