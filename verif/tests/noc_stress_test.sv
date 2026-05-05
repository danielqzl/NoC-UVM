`ifndef NOC_UVM_STRESS_TEST 
`define NOC_UVM_STRESS_TEST


class noc_stress_test extends uvm_test;
    parameter int N_NODE = 4;

    `uvm_component_utils(noc_stress_test)

    net_env env;
    noc_base_vseq vseq [N_NODE];


    function new(string name = "noc_stress_test", uvm_component parent=null);
        super.new(name, parent);
    endfunction


    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env = net_env::type_id::create("env", this);

        assign_seq();
        setup_config();

    endfunction


    virtual function void assign_seq();
        for(int i = 0; i < N_NODE; i++)
            vseq[i] = noc_base_vseq::type_id::create($sformatf("vseq_n%0d", i));
    endfunction


    virtual function void setup_config();
        uvm_config_db#(int)::set(this, "env.*", "num_nodes", N_NODE);
        // time delay between tranmit
        uvm_config_db#(int)::set(this, "env.*", "tx_interval_min", 1);
        uvm_config_db#(int)::set(this, "env.*", "tx_interval_max", 2);
        // time delay between packet reception 
        uvm_config_db#(int)::set(this, "env.*", "rx_interval_min", 5);
        uvm_config_db#(int)::set(this, "env.*", "rx_interval_max", 10); 

        uvm_config_db#(int)::set(this, "env.*", "total_packets", 7);
    endfunction


    virtual task run_phase(uvm_phase phase);
        `uvm_info(get_full_name(), "Test enter run_phase", UVM_LOW)
        
        phase.phase_done.set_drain_time(this, 1200ns);
        phase.raise_objection(this, "Test raise objection");
        
        fork 
            vseq[0].start(env.agents[0].vsqr);
            vseq[1].start(env.agents[1].vsqr);
            vseq[2].start(env.agents[2].vsqr);
            vseq[3].start(env.agents[3].vsqr);
        join
        
        `uvm_info(get_full_name(), "All sequences end", UVM_LOW)

        #100ns;
        phase.drop_objection(this);

    endtask

endclass


`endif