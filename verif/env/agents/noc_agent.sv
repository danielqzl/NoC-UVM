`ifndef NOC_UVM_AGENT 
`define NOC_UVM_AGENT


class client_agent extends uvm_agent;
    // channel 0
    client_monitor_ch0  mon_ch0;
    client_sequencer    sqr_ch0;
    client_driver_ch0   drv_ch0;
    // channel 1
    client_monitor_ch1  mon_ch1;
    client_sequencer    sqr_ch1;
    client_driver_ch1   drv_ch1;
    // virtual sequencer
    client_vsequencer    vsqr;

    int client_id = 0;
    virtual client_if vif;

    `uvm_component_utils(client_agent)

    function new(string name="client_agent", uvm_component parent=null);
        super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon_ch0 = client_monitor_ch0::type_id::create("mon_ch0", this);
        sqr_ch0 = client_sequencer::type_id::create("sqr_ch0", this);
        drv_ch0 = client_driver_ch0::type_id::create("drv_ch0", this);

        mon_ch1 = client_monitor_ch1::type_id::create("mon_ch1", this);
        sqr_ch1 = client_sequencer::type_id::create("sqr_ch1", this);
        drv_ch1 = client_driver_ch1::type_id::create("drv_ch1", this);

        vsqr = client_vsequencer::type_id::create("vsqr", this);

        mon_ch0.client_id = client_id;
        sqr_ch0.client_id = client_id;
        drv_ch0.client_id = client_id;

        mon_ch1.client_id = client_id;
        sqr_ch1.client_id = client_id;
        drv_ch1.client_id = client_id;

        vsqr.client_id = client_id;

    endfunction


    function void connect_phase(uvm_phase phase);
        // Retrieve virtual interface from config_db
        uvm_config_db#(virtual client_if)::get(this, "", $sformatf("vif_%0d", client_id), vif);
            

        mon_ch0.vif = vif;
        sqr_ch0.vif = vif;
        drv_ch0.vif = vif;

        mon_ch1.vif = vif;
        sqr_ch1.vif = vif;
        drv_ch1.vif = vif;
 
        drv_ch0.seq_item_port.connect(sqr_ch0.seq_item_export);
        drv_ch1.seq_item_port.connect(sqr_ch1.seq_item_export);

        // pass sequencer handles into vseqr 
        vsqr.sqr_ch0 = sqr_ch0;
        vsqr.sqr_ch1 = sqr_ch1;

        // `uvm_info(get_full_name(), "End of Agent connect_phase", UVM_LOW)
    endfunction

endclass

`endif
