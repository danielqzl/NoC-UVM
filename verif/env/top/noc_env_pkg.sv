`ifndef NOC_UVM_ENV_PKG
`define NOC_UVM_ENV_PKG

package noc_env_pkg;
   
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import noc_agent_pkg::*;
  //import noc_ref_model_pkg::*;

  // include top env files 
  `include "noc_coverage.sv"
  `include "noc_scoreboard.sv"
  `include "noc_env.sv"

endpackage

`endif


