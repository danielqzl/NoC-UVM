`ifndef NOC_UVM_BASIC_SEQ 
`define NOC_UVM_BASIC_SEQ


class noc_base_seq extends uvm_sequence#(noc_transaction);
    // Defaults, to be overridden from test
    int unsigned num_nodes = 4;
    int unsigned tx_interval_min = 0;
    int unsigned tx_interval_max = 10;
    int unsigned tx_interval;
    int unsigned total_packets = 10;
    int client_id;
    bit [1:0] pkt_vc;  
    const bit [1:0] def_vc_list = '{2'b01, 2'b10};

    `uvm_object_utils(noc_base_seq)
    `uvm_declare_p_sequencer(client_sequencer)

    function new(string name="noc_base_seq");
        super.new(name);
    endfunction

    virtual task pre_body();
        // Get values from config DB (if set, otherwise keep defaults)
        void'(uvm_config_db#(int)::get(p_sequencer, "", "tx_interval_min", tx_interval_min));
        void'(uvm_config_db#(int)::get(p_sequencer, "", "tx_interval_max", tx_interval_max));
        void'(uvm_config_db#(int)::get(p_sequencer, "", "num_nodes", num_nodes));
        void'(uvm_config_db#(int)::get(p_sequencer, "", "total_packets", total_packets));
        client_id = p_sequencer.client_id;
    endtask

    virtual task body();
        noc_transaction pkt;
        // $display(num_nodes);
        repeat (total_packets) begin    
            pkt = noc_transaction::type_id::create("pkt");
            pkt.vc = pkt_vc;
            pkt.source = client_id; // force source to agent ID

            if(!pkt.randomize() with {
                dest_map < (1 << num_nodes);  
                dest_map > 0;    // must send to at least one client
            })
                `uvm_error("SEQ", "Packet Randomization failed")
            
            start_item(pkt);
            finish_item(pkt);

            // randomize delay and wait cycles
            tx_interval = $urandom_range(tx_interval_min, tx_interval_max);
            repeat (tx_interval) @(posedge p_sequencer.vif.clk);  
        end
        // end of sequence 
    endtask
   
endclass


// Sequence for ch0
class noc_base_seq_ch0 extends noc_base_seq;
    `uvm_object_utils(noc_base_seq_ch0)
    function new(string name = "noc_base_seq_ch0");
        super.new(name);
    endfunction 

    virtual task pre_body();
        super.pre_body();
        pkt_vc = 2'b01;
    endtask

    virtual task body();
        super.body();
    endtask

endclass


// Sequence for ch1 
class noc_base_seq_ch1 extends noc_base_seq;
    `uvm_object_utils(noc_base_seq_ch1)
    function new(string name = "noc_base_seq_ch1");
        super.new(name);
    endfunction 

    virtual task pre_body();
        super.pre_body();
        pkt_vc = 2'b10;
    endtask

    virtual task body();
        super.body();
    endtask

endclass


// Virtual Sequence 
class noc_base_vseq extends uvm_sequence;
    `uvm_object_utils(noc_base_vseq)
    `uvm_declare_p_sequencer(client_vsequencer)
    
    function new (string name = "noc_base_vseq");
		super.new (name);
	endfunction

    noc_base_seq_ch0 seq_ch0;
    noc_base_seq_ch1 seq_ch1;

    task pre_body();
		seq_ch0 = noc_base_seq_ch0::type_id::create ("seq_ch0");
		seq_ch1 = noc_base_seq_ch1::type_id::create ("seq_ch1");
	endtask

	task body();
		fork
			seq_ch0.start(p_sequencer.sqr_ch0);
			seq_ch1.start(p_sequencer.sqr_ch1);
		join
	endtask

endclass

`endif


