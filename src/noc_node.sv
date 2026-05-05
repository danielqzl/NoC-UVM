module client_node 
    import noc_pkg:: *;
#(
    parameter int NUM_OUTPUT_CH = 2
) (
    client_if.node in,

    input  logic noc_clk, noc_rst_n,    
    output link_s link_o,
    input  link_s link_i
);
    import noc_pkg:: *;

    noc_transmitter u_transmiter (
        .client_clk(in.clk), .client_rst_n(in.rst_n),
        .noc_clk(noc_clk), .noc_rst_n(noc_rst_n),
        
        .tx_req  (in.tx_req),
        .tx_packet_0(in.tx_packet_0),
        .tx_packet_1(in.tx_packet_1), 
        //.tx_packet_2(in.tx_packet_2), 
        .tx_ready(in.tx_ready),
        .tx_success(in.tx_success),
        
        .link_ready(link_i.ready),
        .link_valid(link_o.valid),
        .link_data (link_o.data)
    );

    noc_receiver #(NUM_OUTPUT_CH) u_receiver (
        .client_clk(in.clk), .client_rst_n(in.rst_n),
        .noc_clk(noc_clk), .noc_rst_n(noc_rst_n),
        
        .rd_vc(in.rd_ch),
        .packet_0(in.rx_packet_0),
        .packet_1(in.rx_packet_1),
        //.packet_2(in.rx_packet_2),
        .packet_ready(in.rx_ready), 
        
        .link_ready(link_o.ready),
        .link_valid(link_i.valid),
        .link_data (link_i.data)
    );

endmodule