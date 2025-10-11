`ifndef NOC_UVM_ENV
`define NOC_UVM_ENV

class net_env extends uvm_env;
 
    client_agent agents[4];
    net_scoreboard sb;

    `uvm_component_utils(net_env)

    function new(string name="net_env", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sb = net_scoreboard::type_id::create("sb", this);
        foreach (agents[i]) begin
            agents[i] = client_agent::type_id::create($sformatf("agent%0d", i), this);
            agents[i].client_id = i;
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        foreach (agents[i]) begin
            agents[i].mon_ch0.rx_ap.connect(sb.rx_export);
            agents[i].mon_ch1.rx_ap.connect(sb.rx_export);
            agents[i].drv_ch0.tx_ap.connect(sb.tx_export);
            agents[i].drv_ch1.tx_ap.connect(sb.tx_export);
        end

        `uvm_info(get_full_name(), "End of env connect_phase", UVM_LOW)
    endfunction

endclass

`endif




