`ifndef NOC_UVM_DRIVER
`define NOC_UVM_DRIVER


class client_driver_ch0 extends uvm_driver #(noc_transaction);
    virtual client_if vif;
    uvm_analysis_port #(noc_transaction) tx_ap;

    int client_id;  //assigned from agent

    `uvm_component_utils(client_driver_ch0)

    function new(string name="client_driver_ch0", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tx_ap = new("tx_ap", this);
    endfunction

    task reset_pahse (uvm_phase phase);
        vif.tx_req[0] = '0;
        vif.tx_packet_0 = '0;
    endtask

    task main_phase(uvm_phase phase);
        noc_transaction pkt;
        forever begin
            @(posedge vif.clk);
            if (vif.tx_ready[0]) begin
                seq_item_port.try_next_item(pkt);
                if (pkt != null) begin
                    assert(pkt.source == client_id) 
                    else `uvm_error("DRIVER", $sformatf("ch0: Invalid source, at agent=%0d", client_id))
                    assert(pkt.vc == 2'b01) 
                    else `uvm_error("DRIVER", $sformatf("ch0: Invalid VC from pkt, at agent=%0d", client_id))

                    vif.tx_packet_0  <= pkt.pack_1f();
                    vif.tx_req[0]    <= 1'b1;
                    @(posedge vif.clk);
                    vif.tx_req[0]    <= 0;
                    seq_item_port.item_done();
                    
                    // Append meta data 
                    pkt.imp_src  = "tx";
                    tx_ap.write(pkt); 
                end
            end
        end
    endtask

endclass


class client_driver_ch1 extends uvm_driver #(noc_transaction);
 
    virtual client_if vif;
    uvm_analysis_port #(noc_transaction) tx_ap;

    int client_id;  //assigned from agent

    `uvm_component_utils(client_driver_ch1)

    function new(string name="client_driver_ch1", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tx_ap = new("tx_ap", this);
    endfunction

    task reset_pahse (uvm_phase phase);
        vif.tx_req[1] = '0;
        vif.tx_packet_1 = '0;
    endtask

    task main_phase(uvm_phase phase);
        noc_transaction pkt;
        forever begin
            @(posedge vif.clk);
            if (vif.tx_ready[1]) begin
                seq_item_port.try_next_item(pkt);
                if (pkt != null) begin
                    assert(pkt.source == client_id) 
                    else `uvm_error("DRIVER", $sformatf("ch0: Invalid source, at agent=%0d", client_id))
                    assert(pkt.vc == 2'b10) 
                    else `uvm_error("DRIVER", $sformatf("ch0: Invalid VC from pkt, at agent=%0d", client_id))

                    vif.tx_packet_1  <= pkt.pack_3f();
                    vif.tx_req[1]    <= 1'b1;
                    @(posedge vif.clk);
                    vif.tx_req[1]    <= 0;
                    seq_item_port.item_done();

                    // Append meta data 
                    pkt.imp_src  = "tx";
                    tx_ap.write(pkt); 
                end
            end
        end
    endtask
endclass



`endif





