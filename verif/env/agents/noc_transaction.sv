`ifndef NOC_UVM_TRANSACTION 
`define NOC_UVM_TRANSACTION

class noc_transaction extends uvm_sequence_item;
    // header 
    bit      [3:0]   source;
    rand bit [7:0]   dest_map;
    bit      [1:0]   vc;
    bit      [1:0]   padding = 2'b10;
    // payload 
    rand bit [143:0] data;

    // Metadata
    int    rx_cid;   // who receives the packet  
    string imp_src;    // tx or rx 

    function new(string name="noc_transaction");
        super.new(name);
    endfunction

    `uvm_object_utils_begin(noc_transaction)
        `uvm_field_int(source, UVM_ALL_ON)
        `uvm_field_int(dest_map, UVM_ALL_ON)
        `uvm_field_int(vc, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)

        `uvm_field_int(rx_cid, UVM_ALL_ON)
        `uvm_field_string(imp_src, UVM_ALL_ON)
    `uvm_object_utils_end

    // Constraint: if is a 1-flit packet, then restrict payload to 48 bits only
    constraint c_payload_size {
        if (vc != 2'b10)
            data[143:48] == '0;  // upper bits must be zero -> effectively 48-bit
    }

    function bit [160:0] pack_3f();
        return {source, dest_map, vc, padding, data};
    endfunction

    function bit [63:0] pack_1f();
        return {source, dest_map, vc, padding, data[47:0]};
    endfunction

    function bit [15:0] pack_header();
        return {source, dest_map, vc, padding};
    endfunction

endclass



`endif


