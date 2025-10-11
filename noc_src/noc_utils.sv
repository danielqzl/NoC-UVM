package noc_pkg;
    parameter int N_NODE = 5;

    parameter int FLIT_W = 64;          // width of a flit (bits)
    parameter int FLIT_PAY_W  = FLIT_W-16;   // payload bits inside a flit

    parameter int PAY_W    = 144;
    parameter int PACKET_W = PAY_W + 16;
    
    parameter int FLITS_PER_PACKET = 3;
    parameter int VC_CNT = 2;           // Virtual Channel Count at node 

    parameter logic [1:0] VC_REQ =  2'b01;
    parameter logic [1:0] VC_DATA = 2'b10;
    //parameter logic [1:0] VC_RES =  2'b10;


    typedef struct packed {
        logic [3:0] src;  // 4 bit - source client
        logic [7:0] dst;  // 8 bit - destination client (0‑7), 
        logic [1:0] vc;   // 2 bit - virtual channel       
        logic first;      // 1 bit - marks first flit of the packet
        logic last;       // 1 bit - marks last flit of the packet
        logic [FLIT_PAY_W-1:0] data;  // payload
    } flit_s;

    typedef struct packed {
        logic [3:0] source;        // id of the client
        logic [7:0] dest_bitmap;   // destination client 0‑4 
        logic [1:0] vc;            // virtual channel / type 
        logic [1:0] padding;       // padding 
        // logic [1:0] flit_cnt;   // number of flit to send (1/3)
    } packet_header_s;
    

    // short packet (1 flit)
    typedef struct packed {
        packet_header_s        header;
        logic [FLIT_PAY_W-1:0] payload;
    } packet_1_s;

    // long packet (3 flits)
    typedef struct packed {
        packet_header_s   header;
        logic [PAY_W-1:0] payload;
    } packet_3_s;


    typedef struct {
        logic valid;
        flit_s data;
        logic [0:1] ready;
    } link_s;


endpackage : noc_pkg



// ----------------------------------------------------------------------------
// Client Interface
// ----------------------------------------------------------------------------
interface client_if ();
    import noc_pkg:: *;

    logic     clk, rst_n;   // client clk & rst
    
    packet_1_s  tx_packet_0; 
    packet_3_s  tx_packet_1;
    logic [0:1] tx_req;       // request transmit 
    logic [0:1] tx_ready;     // Transmitter is not busy 
    logic [0:1] tx_success;   // Transmit Request success  
 

    packet_1_s rx_packet_0;
    packet_3_s rx_packet_1;
    logic [0:1] rx_ready;
    logic [0:1] rd_ch;

    modport node (
        input  clk, rst_n,

        output tx_ready,
        output tx_success,
        input  tx_req,
        input  tx_packet_0,
        input  tx_packet_1,

        output rx_packet_0,
        output rx_packet_1,
        output rx_ready,
        input  rd_ch
    );
   
    modport client (
        output clk, rst_n,

        input  tx_ready,
        input  tx_success,
        output tx_req,
        output tx_packet_0,
        output tx_packet_1,
        
        input  rx_packet_0,
        input  rx_packet_1,
        input  rx_ready,
        output rd_ch
    );

endinterface


