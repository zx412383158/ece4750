//=========================================================================
// Baseline Blocking Cache Datapath
//=========================================================================

`ifndef LAB3_MEM_BLOCKING_CACHE_BASE_DPATH_V
`define LAB3_MEM_BLOCKING_CACHE_BASE_DPATH_V

`include "vc/arithmetic.v"
`include "vc/mem-msgs.v"
`include "vc/muxes.v"
`include "vc/regs.v"
`include "vc/srams.v"

`include "lab3_mem/Definitions.sv"

module lab3_mem_BlockingCacheBaseDpathVRTL
#(
  parameter p_idx_shamt    = 0
)
(
  input  logic                        clk,
  input  logic                        reset,

  // Cache Request

  input  mem_req_4B_t                 cachereq_msg,

  // Cache Response

  output mem_resp_4B_t                cacheresp_msg,

  // Memory Request

  output mem_req_16B_t                memreq_msg,

  // Memory Response

  input  mem_resp_16B_t               memresp_msg,

  // control signals (ctrl->dpath)

  input  logic              cachereq_en,
  input  logic              memresp_en,
  input  logic              evict_addr_reg_en,
  input  logic              read_data_reg_en,

  input  logic              cacheresp_data_mux_sel,
  input  logic              write_data_mux_sel,     // mem or proc
  input  logic              memreq_addr_mux_sel,    // refill or evict

  input  logic              tag_array_ren,
  input  logic              tag_array_wen,

  input  logic              data_array_ren,
  input  logic              data_array_wen,
  input  logic [clw/8-1:0]  data_array_wben,

  input  logic              hit,

  input  logic [2:0]        cacheresp_type,
  input  logic [2:0]        memreq_type,

  // status signals (dpath->ctrl)

  output logic [2:0]        cachereq_type,
  output logic [abw-1:0]    cachereq_addr,

  output logic              tag_match

);

  // local parameters not meant to be set from outside
  localparam nway = 1;               // Short name for cache associate
  localparam nbl  = size*8/clw;      // Number of blocks in the cache
  localparam nby  = nbl/nway;        // Number of blocks per way
  localparam idw  = $clog2(nby);     // Short name for index bitwidth
  localparam ofw  = $clog2(clw/8);   // Short name for the offset bitwidth
  // In this lab, to simplify things, we always use all bits except for the
  // offset in the tag, rather than storing the "normal" 24 bits. This way,
  // when implementing a multi-banked cache, we don't need to worry about
  // re-inserting the bank id into the address of a cacheline.
  localparam tgw  = abw - ofw;       // Short name for the tag bitwidth

  logic [tgw-1:0] tag;
  logic [idw-1:0] idx;
  logic [ofw-1:0] offset;

  assign tag    = cachereq_addr[abw-1:ofw];
  assign idx    = cachereq_addr[idw+p_idx_shamt+ofw-1:p_idx_shamt+ofw];
  assign offset = cachereq_addr[ofw-1:0];

  //--------------------------------------------------------------------
  // Input req
  //--------------------------------------------------------------------

  // Cache req

  logic [7:0]     cachereq_opaque;
  logic [dbw-1:0] cachereq_data;

  vc_EnResetReg #(8, 0) cachereq_opaque_reg
  (
    .clk    (clk),
    .reset  (reset),
    .en     (cachereq_en),
    .d      (cachereq_msg.opaque),
    .q      (cachereq_opaque)
  );

  vc_EnResetReg #(3, 0) cachereq_type_reg
  (
    .clk    (clk),
    .reset  (reset),
    .en     (cachereq_en),
    .d      (cachereq_msg.type_),
    .q      (cachereq_type)
  );

  vc_EnResetReg #(abw, 0) cachereq_addr_reg
  (
    .clk    (clk),
    .reset  (reset),
    .en     (cachereq_en),
    .d      (cachereq_msg.addr),
    .q      (cachereq_addr)
  );

  vc_EnResetReg #(dbw, 0) cachereq_data_reg
  (
    .clk    (clk),
    .reset  (reset),
    .en     (cachereq_en),
    .d      (cachereq_msg.data),
    .q      (cachereq_data)
  );

  // Mem resp

  logic [clw-1:0] memresp_data;

  vc_EnResetReg #(clw, 0) memresp_data_reg
  (
    .clk    (clk),
    .reset  (reset),
    .en     (memresp_en),
    .d      (memresp_msg.data),
    .q      (memresp_data)
  );

  //--------------------------------------------------------------------
  // Tag array
  //--------------------------------------------------------------------
  logic [tgw-1:0] tag_array_out;

  vc_CombinationalBitSRAM_1rw #(tgw, nbl) cache_tag_array
  (
    .clk        (clk),
    .reset      (reset),

    // Read port (combinational read)

    .read_en    (tag_array_ren),
    .read_addr  (idx),
    .read_data  (tag_array_out),
    
    // Write port

    .write_en   (tag_array_wen),
    .write_addr (idx),
    .write_data (tag)
  );

  vc_EqComparator #(tgw) cache_tag_comparator
  (
    .in0    (tag),
    .in1    (tag_array_out),
    .out    (tag_match)
  );

  //--------------------------------------------------------------------
  // Data array
  //--------------------------------------------------------------------
  logic [clw-1:0] cachereq_data_repl;
  logic [clw-1:0] data_array_in;
  logic [clw-1:0] data_array_out;
  logic [clw-1:0] read_data;

  // Data arry write select mux
  // This mux chooses among Cachereq, Memresp
  vc_Mux2 #(clw) write_data_mux
  (
    .in0  (cachereq_data_repl),
    .in1  (memresp_data),
    .sel  (write_data_mux_sel),
    .out  (data_array_in)
  );

  vc_CombinationalSRAM_1rw #(clw, nbl) cache_data_array
  (
    .clk            (clk),
    .reset          (reset),

    // Read port (combinational read)

    .read_en        (data_array_ren),
    .read_addr      (idx),
    .read_data      (data_array_out),
    
    // Write port

    .write_en       (data_array_wen),
    .write_byte_en  (data_array_wben),
    .write_addr     (idx),
    .write_data     (data_array_in)
  );

  vc_EnResetReg #(clw, 0) read_data_reg
  (
    .clk    (clk),
    .reset  (reset),
    .en     (read_data_reg_en),
    .d      (data_array_out),
    .q      (read_data)
  );

  // repl component

  assign cachereq_data_repl = {4{cachereq_data}};
  
  //--------------------------------------------------------------------
  // evict/refill
  //--------------------------------------------------------------------
  logic [abw-1:0] evict_addr;
  logic [abw-1:0] refill_addr;

  vc_EnResetReg #(abw, 0) evict_addr_reg
  (
    .clk    (clk),
    .reset  (reset),
    .en     (evict_addr_reg_en),
    .d      ({tag_array_out, {ofw{1'b0}}}),
    .q      (evict_addr)
  );

  // memreq addr select mux
  vc_Mux2 #(abw) memreq_addr_mux
  (
    .in0  (evict_addr),
    .in1  (refill_addr),
    .sel  (memreq_addr_mux_sel),
    .out  (memreq_msg.addr)
  );

  assign refill_addr = {tag, {ofw{1'b0}}};
  
  assign memreq_msg.type_   = memreq_type;
  assign memreq_msg.opaque  = 8'b0;
  assign memreq_msg.len     = 4'b0;
  assign memreq_msg.data    = read_data;
  
  //--------------------------------------------------------------------
  // cache resp
  //-------------------------------------------------------------------- 
  logic [dbw-1:0] read_word;

  // read word select mux
  vc_Mux4 #(dbw) read_word_mux
  (
    .in0  (read_data[31:0]),
    .in1  (read_data[63:32]),
    .in2  (read_data[95:64]),
    .in3  (read_data[127:96]),
    .sel  (offset[3:2]),
    .out  (read_word)
  );

  vc_Mux2 #(abw) cacheresp_data_mux
  (
    .in0  (0),
    .in1  (read_word),
    .sel  (cacheresp_data_mux_sel),
    .out  (cacheresp_msg.data)
  );

  assign cacheresp_msg.type_  = cacheresp_type;
  assign cacheresp_msg.opaque = cachereq_opaque;
  assign cacheresp_msg.len    = 2'b0;
  assign cacheresp_msg.test   = {1'b0, hit};
  
endmodule

`endif
