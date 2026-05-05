`ifndef NOC_UVM_AGENT_PKG
`define NOC_UVM_AGENT_PKG

package noc_agent_pkg;
 
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // include Agent components : driver,monitor,sequencer
  `include "noc_transaction.sv"
  `include "noc_sequencer.sv"
  `include "noc_driver.sv"
  `include "noc_monitor.sv"
  `include "noc_agent.sv"

endpackage

`endif



