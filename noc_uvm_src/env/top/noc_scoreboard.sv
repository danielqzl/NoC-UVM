`ifndef NOC_UVM_SCOREBOARD 
`define NOC_UVM_SCOREBOARD

class net_scoreboard extends uvm_scoreboard;
    // RX packets come from monitor
    uvm_analysis_imp #(noc_transaction, net_scoreboard) rx_export;
    // TX packets come from driver
    uvm_analysis_imp #(noc_transaction, net_scoreboard) tx_export;
    
    `uvm_component_utils(net_scoreboard)
    
    int unsigned n_nodes = 4;

    typedef struct {
        bit [3:0] source;
        bit [7:0] recv_map;  // does each recipient confirms reception (clear bit on reception) 
        bit [143:0] data;
        bit  done;
        time tx_time;
        time rx_time;
    } pkt_info_s;

    pkt_info_s sent_q[8][3][$];

    function new(string name="net_scoreboard", uvm_component parent=null);
        super.new(name, parent);
        rx_export = new("rx_export", this);
        tx_export = new("tx_export", this);
    endfunction


    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(int)::get(this, "", "num_nodes", n_nodes))
            `uvm_fatal("SCB", "num_nodes not set in config_db")
    endfunction


    function void write(noc_transaction pkt);
        if (pkt.imp_src == "rx")
            rx_write(pkt);
        else if (pkt.imp_src == "tx")
            tx_write(pkt);
        else
            `uvm_fatal("SB", "write() called from unknown analysis_imp")
    endfunction


    // Called when driver sends packet
    function void tx_write(noc_transaction pkt);
        int ch = get_ch_from_vc(pkt.vc);
        pkt_info_s temp;
        temp.source = pkt.source;
        temp.recv_map = pkt.dest_map & ~(1<<pkt.source); //ignore itself 
        temp.tx_time = $time;
        temp.data = pkt.data;
        temp.done = 0;
        sent_q[pkt.source][ch].push_back(temp);
        // $display("Tx Write: src=%0d, vc=%0d, data=%h", pkt.source, pkt.vc, pkt.data);
    endfunction


    // Called when monitor receives packet
    function void rx_write(noc_transaction pkt);
        int ch = get_ch_from_vc(pkt.vc);
        check_rx(ch, pkt);
    endfunction


    // RX checker logic
    function void check_rx(int ch, noc_transaction pkt);
        // 1. Check wrong boardcast (should not receive the packet) 
        if ( pkt.dest_map[pkt.rx_cid] != 1'b1) 
            `uvm_error("SCB", $sformatf("RX check: Wrong multicast, src=%0d, dest=%0d", 
                                                pkt.source, pkt.rx_cid))

        // 2. Check source / recv node
        assert(pkt.source inside {[0:n_nodes]}) else `uvm_fatal("SCB", "RX: Invalid source")
        assert(pkt.rx_cid inside {[0:n_nodes]}) else `uvm_fatal("SCB", "RX: Invalid rx_cid")

        // 3. Find the packet sent  
        search_tx_queue(pkt, sent_q[pkt.source][ch]);
    endfunction


    // Search the matching packet in the tx queue. 
    function void search_tx_queue(noc_transaction pkt, ref pkt_info_s q[$]);
        int match = 0;

        foreach (q[i]) begin
            // match 
            if ((q[i].done == 0) && (pkt.data == q[i].data) /*&& ($time > q[i].tx_time)*/) begin
                match = 1;
                `uvm_info("SCB", $sformatf("Rx Check: packet match, rx_cid=%0d, src=%0d", pkt.rx_cid, pkt.source), UVM_LOW)
                // if the reception map has been cleared, then it is a duplicate
                if (q[i].recv_map[pkt.rx_cid] == 0 ) begin
                    `uvm_error("SCB", $sformatf("Rx Check: Duplicate Delivery, src=%0d, dest=%0d", 
                                                        pkt.source, pkt.rx_cid))
                end else begin
                    q[i].recv_map[pkt.rx_cid] = 0;
                    // all destinations received the packet, retire from Tx queue 
                    if(q[i].recv_map == 0) q[i].done = 1;
                end
            end
        end
        
        if (match == 0) begin
            `uvm_error("SCB", $sformatf("Rx Check: No Matching Tx Transcation, src=%0d, dest=%0d", 
                                pkt.source, pkt.rx_cid))
            pkt.print();
            // $display("q[0]: %h, done=%0d", q[0].data, q[0].done);
            // $display("q[1]: %h, done=%0d", q[1].data, q[1].done);
        end

    endfunction



    function int get_ch_from_vc(bit [1:0] vc);
        if (vc == 2'b01) return 0;
        else if (vc == 2'b10) return 1;
        else if (vc == 2'b11) return 2;
        else `uvm_error("SCB", $sformatf("Invalid pkt vc = %d", vc))
        return 0;
    endfunction


    // Offline check: all tx packets found 
    function void check_phase(uvm_phase phase);
        int pkt_count = 0;
        foreach (sent_q[i, j]) pkt_count += sent_q[i][j].size();

        `uvm_info("SCB", $sformatf("Checking %0d packets", pkt_count), UVM_LOW)
        foreach (sent_q[i, j, k]) begin
            pkt_info_s pkt = sent_q[i][j][k];
            if (pkt.done != 1 && pkt.recv_map != 0) begin 
                `uvm_error("SCB", $sformatf("Tx Check: Missing delivery, src=%0d", pkt.source))
                $display("remaining dest: %b, vc=%0d", pkt.recv_map, j);
                $display("data: %h", pkt.data);
            end
        end

        `uvm_info("SCB", "Packet Checking Complete", UVM_LOW)
    endfunction
    
endclass


`endif
