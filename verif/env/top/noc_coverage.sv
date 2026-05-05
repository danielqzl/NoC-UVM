`ifndef NOC_UVM_COVERAGE
`define NOC_UVM_COVERAGE


class noc_coverage#(type T=noc_transaction) extends uvm_subscriber #(T);

    `uvm_component_utils(noc_coverage)

    int N; //num_nodes 

    // sampled fields
    bit [3:0] src;
    bit [7:0] dst_map;
    bit [1:0] vc;

    covergroup cg_noc_routing;
        option.per_instance = 1;

        // source node coverage
        cp_src : coverpoint src {
            bins valid_src[] = {[0:N-1]};
        }

        // VC coverage
        cp_vc : coverpoint vc {
            bins vc0 = {2'b10};
            bins vc1 = {2'b01};
        }

        // multicast population count
        cp_mc_size : coverpoint $countones(dst_map) {
            bins unicast  = {1};
            bins multicast[] = {[2:N-1]};
        }

        // destination bitmap
        cp_dst_map : coverpoint dst_map {

            // ignore illegal/self-send cases
            ignore_bins no_dest = {0};

            // optional - auto bins for all legal maps
            bins legal_maps[] = {[1:(1<<N)-1]};
        }

        // source -> VC combinations
        x_src_vc : cross cp_src, cp_vc;

        // source -> multicast size
        x_src_mcsize : cross cp_src, cp_mc_size;

        // source -> destination map
        x_src_dst : cross cp_src, cp_dst_map {
            // ignore cases where source bit is set
            ignore_bins self_send =
                binsof(cp_src) intersect {[0:N-1]} &&
                binsof(cp_dst_map) with ((dst_map & (1 << cp_src)) != 0);
        }

        // full routing scenario
        x_src_dst_vc : cross cp_src, cp_dst_map, cp_vc {
            ignore_bins self_send =
                binsof(cp_src) intersect {[0:N-1]} &&
                binsof(cp_dst_map) with ((dst_map & (1 << cp_src)) != 0);
        }

    endgroup


    function new(string name = "noc_coverage", uvm_component parent = null);
        super.new(name, parent);
        uvm_config_db#(int)::get(this, "", "num_nodes", N);
        cg_noc_routing = new();
    endfunction


    virtual function void write(noc_transaction t);
        src     = t.source;
        dst_map = t.dest_map;
        vc      = t.vc;
        cg_noc_routing.sample();
    endfunction

endclass


`endif