`ifndef NOC_UVM_TEST_LIST 
`define NOC_UVM_TEST_LIST

package noc_test_list;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import noc_env_pkg::*;
    import noc_seq_list::*;

    // including noc test list

    `include "noc_basic_test.sv"
    `include "noc_stress_test.sv"

endpackage 

`endif





