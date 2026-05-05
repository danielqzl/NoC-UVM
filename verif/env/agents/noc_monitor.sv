`ifndef NOC_UVM_MONITOR 
`define NOC_UVM_MONITOR


class client_monitor_ch0 extends uvm_component;
    virtual client_if vif;
    uvm_analysis_port #(noc_transaction) rx_ap;

    int client_id;  //assigned from agent 
    int unsigned rx_interval_min, rx_interval_max;
    int unsigned rx_cntr;
    
    `uvm_component_utils(client_monitor_ch0)

    function new(string name="client_monitor_ch0", uvm_component parent=null);
        super.new(name, parent);
        rx_ap = new("rx_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(int)::get(this, "", "my_int_config", rx_interval_min);
        uvm_config_db#(int)::get(this, "", "my_int_config", rx_interval_max);
    endfunction
    
    task reset_phase(uvm_phase phase);
        vif.rd_ch[0] = '0;
        rx_cntr = $urandom_range(rx_interval_min, rx_interval_max);
    endtask


    task main_phase(uvm_phase phase);
        noc_transaction pkt;
    
        forever begin
            @(posedge vif.clk);
            if (rx_cntr > 0) rx_cntr = rx_cntr - 1;
            // check ch_0 
            if (vif.rx_ready[0] && rx_cntr == 0) begin
                // construct transaction
                pkt = noc_transaction::type_id::create("pkt");
                {pkt.source, pkt.dest_map, pkt.vc, pkt.padding} = vif.rx_packet_0[63:48];
                pkt.data = {96'b0, vif.rx_packet_0[47:0]};
                // append metadata
                pkt.rx_cid  = client_id;
                pkt.imp_src = "rx";
                rx_ap.write(pkt);
                // set rd_en 
                vif.rd_ch[0] = 1'b1;
                @(posedge vif.clk);
                vif.rd_ch[0] = 1'b0;
                // reset counter 
                rx_cntr = $urandom_range(rx_interval_min, rx_interval_max);
            end
        end
    endtask

endclass


class client_monitor_ch1 extends uvm_component;
    virtual client_if vif;
    uvm_analysis_port #(noc_transaction) rx_ap;

    int client_id;  //assigned from agent 
    int unsigned rx_interval_min, rx_interval_max;
    int unsigned rx_cntr;

    `uvm_component_utils(client_monitor_ch1)

    function new(string name="client_monitor_ch1", uvm_component parent=null);
        super.new(name, parent);
        rx_ap = new("rx_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(int)::get(this, "", "my_int_config", rx_interval_min);
        uvm_config_db#(int)::get(this, "", "my_int_config", rx_interval_max);
    endfunction


    task reset_phase(uvm_phase phase);
        vif.rd_ch[1]  = '0;
        rx_cntr = $urandom_range(rx_interval_min, rx_interval_max);
    endtask


    task main_phase(uvm_phase phase);
        noc_transaction pkt;

        forever begin
            @(posedge vif.clk);
            if (rx_cntr > 0) rx_cntr = rx_cntr - 1;
            // check ch_1 
            if (vif.rx_ready[1]) begin
                // construct transaction
                pkt = noc_transaction::type_id::create("pkt");
                {pkt.source, pkt.dest_map, pkt.vc, pkt.padding, pkt.data} = vif.rx_packet_1;
                // append metadata
                pkt.rx_cid  = client_id;
                pkt.imp_src = "rx";
                rx_ap.write(pkt);
                // set rd_en 
                vif.rd_ch[1] = 1'b1;
                @(posedge vif.clk);
                vif.rd_ch[1] = 1'b0;
                // reset counter 
                rx_cntr = $urandom_range(rx_interval_min, rx_interval_max);
            end
        end
    endtask

endclass

`endif
