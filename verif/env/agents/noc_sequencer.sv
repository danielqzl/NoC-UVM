`ifndef NOC_UVM_SEQUENCER
`define NOC_UVM_SEQUENCER

class client_sequencer extends uvm_sequencer #(noc_transaction);
    int client_id;
    virtual client_if vif;
    
    `uvm_component_utils(client_sequencer)

    function new(string name, uvm_component parent=null);
        super.new(name, parent);
    endfunction

endclass


// virtual sequencer 
class client_vsequencer extends uvm_sequencer #(noc_transaction);
    int client_id;
    
    `uvm_component_utils(client_vsequencer)

    // Handles to real sequencers
    client_sequencer sqr_ch0;
    client_sequencer sqr_ch1;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass

`endif




