`ifndef NOC_UVM_TB_TOP
`define NOC_UVM_TB_TOP
`include "uvm_macros.svh"
//`include "noc_interface.sv"
import uvm_pkg::*;

module noc_tb_top;
   
    import noc_test_list::*;
    import noc_pkg:: *;

    // ----------------------------------------------------
    // clk Definition  
    // ----------------------------------------------------
    // NoC clk 
    logic noc_clk, noc_rst_n;
    always begin
        noc_clk = 1; #10; noc_clk = 0; #10;
    end

    // client clk
    logic [0:3] cclk, crst_n; 
    always begin
        cclk[0] = 1; #5; cclk[0] = 0; #5;
    end
    always begin
        cclk[1] = 1; #6; cclk[1] = 0; #6;
    end 
    always begin
        cclk[2] = 1; #7; cclk[2] = 0; #7;
    end 
    always begin   
        cclk[3] = 1; #8; cclk[3] = 0; #8;
    end


    // ----------------------------------------------------
    // Interface Instantiation 
    // ----------------------------------------------------
    client_if c_if[4]();
    for (genvar i = 0; i < 4; i++) begin : g_if_init
        assign c_if[i].clk = cclk[i];
        assign c_if[i].rst_n = crst_n[i];
    end
    
    // ----------------------------------------------------
    // DUT Instantiation 
    // ----------------------------------------------------
    NoC dut(
        .noc_clk(noc_clk), .noc_rst_n(noc_rst_n),
        .n0(c_if[0]),
        .n1(c_if[1]),
        .n2(c_if[2]),
        .n3(c_if[3])
    );

    initial begin
        noc_rst_n = '0;
        crst_n = '0;
        #20;
        noc_rst_n = '1;
        crst_n = '1;
    end

    // ----------------------------------------------------
    // UVM 
    // ----------------------------------------------------
    initial begin
        // Put each interface into config_db with a unique field name
        uvm_config_db#(virtual client_if)::set(uvm_root::get(), "*", "vif_0", c_if[0]);
        uvm_config_db#(virtual client_if)::set(uvm_root::get(), "*", "vif_1", c_if[1]);
        uvm_config_db#(virtual client_if)::set(uvm_root::get(), "*", "vif_2", c_if[2]);
        uvm_config_db#(virtual client_if)::set(uvm_root::get(), "*", "vif_3", c_if[3]);
        uvm_factory::get().print();
        run_test("noc_base_test");
        
    end

endmodule

`endif



