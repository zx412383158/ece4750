//=========================================================================
// Baseline Blocking Cache Control
//=========================================================================

`ifndef LAB3_MEM_BLOCKING_CACHE_BASE_CTRL_V
`define LAB3_MEM_BLOCKING_CACHE_BASE_CTRL_V

`include "vc/mem-msgs.v"
`include "vc/assert.v"
`include "vc/regs.v"
`include "vc/regfiles.v"

`include "lab3_mem/Definitions.sv"

module lab3_mem_BlockingCacheBaseCtrlVRTL
#(
  parameter p_idx_shamt    = 0
)
(
  input  logic                        clk,
  input  logic                        reset,

  // Cache Request

  input  logic                        cachereq_val,
  output logic                        cachereq_rdy,

  // Cache Response

  output logic                        cacheresp_val,
  input  logic                        cacheresp_rdy,

  // Memory Request

  output logic                        memreq_val,
  input  logic                        memreq_rdy,

  // Memory Response

  input  logic                        memresp_val,
  output logic                        memresp_rdy,

  // control signals (ctrl->dpath)

  output  logic              cachereq_en,
  output  logic              memresp_en,
  output  logic              evict_addr_reg_en,
  output  logic              read_data_reg_en,

  output  logic              cacheresp_data_mux_sel,
  output  logic              write_data_mux_sel,     // mem or proc
  output  logic              memreq_addr_mux_sel,    // refill or evict
  
  output  logic              tag_array_ren,
  output  logic              tag_array_wen,

  output  logic              data_array_ren,
  output  logic              data_array_wen,
  output  logic [clw/8-1:0]  data_array_wben,

  output  logic              hit,

  output  logic [2:0]        cacheresp_type,
  output  logic [2:0]        memreq_type,

  // status signals (dpath->ctrl)

  input   logic [2:0]        cachereq_type,
  input   logic [abw-1:0]    cachereq_addr,

  input   logic              tag_match

 );

  // local parameters not meant to be set from outside
  localparam nway = 1;               // Short name for cache associate
  localparam nbl  = size*8/clw;      // Number of blocks in the cache
  localparam nby  = nbl/nway;        // Number of blocks per way
  localparam idw  = $clog2(nby);     // Short name for idx bitwidth
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

  //========================================================================
  // val/dirty regfile
  //========================================================================
  logic       match;
  logic       rf_wen, rf_ren;
  logic [1:0] rf_state, rf_update;
  logic [1:0] val_dirty_state;
  logic       valid, dirty;

  vc_Regfile_1r1w #(2, 16) val_dirty_rf
  (
    .clk  (clk),
    .reset (reset),

    // Read port
    .read_addr  (idx),
    .read_data  (rf_state),

    // Write port
    .write_en   (rf_wen),
    .write_addr (idx),
    .write_data (rf_update)
  );

  vc_EnResetReg #(1, 0) hit_reg
  (
    .clk    (clk),
    .reset  (reset),
    .en     (rf_ren),
    .d      (match),
    .q      (hit)
  );
  
  assign valid = rf_state[1];
  assign dirty = rf_state[0];

  assign match = valid && tag_match;

  //========================================================================
  // State
  //========================================================================

  state_t state, next_state;

  always_ff @(posedge clk) begin
    if ( reset ) state <= STATE_I;
    else         state <= next_state;
  end

  //----------------------------------------------------------------------
  // State Transitions
  //----------------------------------------------------------------------

  logic cachereq_go;
  logic cacheresp_go;
  logic memreq_go;
  logic memresp_go;

  assign cachereq_go    = cachereq_val && cachereq_rdy;
  assign cacheresp_go   = cacheresp_val && cacheresp_rdy;
  assign memreq_go      = memreq_val && memreq_rdy;
  assign memresp_go     = memresp_val && memresp_rdy; 

  logic tc2in;
  logic tc2rd;
  logic tc2wd;
  logic tc2rr;
  logic tc2ep;

  logic ru2rd;
  logic ru2wd;

  assign tc2in    = (cachereq_type == `VC_MEM_RESP_MSG_TYPE_WRITE_INIT);
  assign tc2rd    = (cachereq_type == `VC_MEM_REQ_MSG_TYPE_READ) && match;
  assign tc2wd    = (cachereq_type == `VC_MEM_REQ_MSG_TYPE_WRITE) && match;
  assign tc2rr    = !match && !dirty;
  assign tc2ep    = !match && dirty;
  
  assign ru2rd    = (cachereq_type == `VC_MEM_REQ_MSG_TYPE_READ);
  assign ru2wd    = (cachereq_type == `VC_MEM_REQ_MSG_TYPE_WRITE);

  always_comb begin
    
    next_state = state;

    case ( state )
      STATE_I   : if(cachereq_go)     next_state = STATE_TC;
      STATE_TC  : if(tc2in)           next_state = STATE_IN;
                  else if(tc2rd)      next_state = STATE_RD;
                  else if(tc2wd)      next_state = STATE_WD;
                  else if(tc2rr)      next_state = STATE_RR;
                  else if(tc2ep)      next_state = STATE_EP;
      STATE_IN  :                     next_state = STATE_W;
      STATE_RD  :                     next_state = STATE_W;
      STATE_WD  :                     next_state = STATE_W;
      STATE_RR  : if(memreq_go)       next_state = STATE_RW;
      STATE_RW  : if(memresp_go)      next_state = STATE_RU;
      STATE_RU  : if(ru2rd)           next_state = STATE_RD;
                  else if(ru2wd)      next_state = STATE_WD;
      STATE_EP  :                     next_state = STATE_ER;
      STATE_ER  : if(memreq_go)       next_state = STATE_EW;
      STATE_EW  : if(memresp_go)      next_state = STATE_RR;
      STATE_W   : if(cacheresp_go)    next_state = STATE_I;
      default:                        next_state = STATE_I;
    endcase

  end

  //----------------------------------------------------------------------
  // State Outputs
  //----------------------------------------------------------------------

  // Generic Parameters -- yes or no

  localparam n = 1'd0;
  localparam y = 1'd1;

  // Memory Request Type

  localparam nr       = 3'dx;   // No request
  localparam ld       = 3'd0;   // Load
  localparam st       = 3'd1;   // Store
  localparam in       = 3'd2;   // Init

  // Readword Mux Select

  localparam rw_n = 1'b0;
  localparam rw_y = 1'b1;


  // Write Data Mux Select

  localparam wd_x = 1'dx;
  localparam wd_c = 1'd0;
  localparam wd_m = 1'd1;

  // Memory Request Address Mux Select

  localparam ma_x = 1'dx;   // Don't care
  localparam ma_e = 1'd0;   // evict cacheline
  localparam ma_c = 1'd1;   // refill cahcheline

  // Data Array Wben

  localparam wb_n = 16'h0;
  localparam wb_a = 16'hFFFF;

  // val/dirty update

  localparam vd_x = 2'bx;

  task cs0
  (
    input logic             cs_evict_addr_reg_en,
    input logic             cs_read_data_reg_en,

    input logic             cs_tag_array_ren,
    input logic             cs_tag_array_wen,

    input logic             cs_rf_ren,
    input logic             cs_rf_wen,
    input logic [1:0]       cs_rf_update,

    input logic             cs_data_array_ren,
    input logic             cs_data_array_wen,
    input logic [clw/8-1:0] cs_data_array_wben,

    input logic             cs_cacheresp_data_mux_sel,
    input logic             cs_write_data_mux_sel,
    input logic             cs_memreq_addr_mux_sel,

    input logic [2:0]       cs_memreq_type
  );
  begin
    

    evict_addr_reg_en       = cs_evict_addr_reg_en;
    read_data_reg_en        = cs_read_data_reg_en;

    tag_array_ren           = cs_tag_array_ren;
    tag_array_wen           = cs_tag_array_wen;

    rf_ren                  = cs_rf_ren;
    rf_wen                  = cs_rf_wen;
    rf_update               = cs_rf_update;

    data_array_ren          = cs_data_array_ren;
    data_array_wen          = cs_data_array_wen;
    data_array_wben         = cs_data_array_wben;

    cacheresp_data_mux_sel  = cs_cacheresp_data_mux_sel;
    write_data_mux_sel      = cs_write_data_mux_sel;
    memreq_addr_mux_sel     = cs_memreq_addr_mux_sel;
    
    memreq_type             = cs_memreq_type;
  end
  endtask

  task cs1
  (
    input logic           cs_cachereq_rdy,
    input logic           cs_cacheresp_val,

    input logic           cs_memresp_rdy,
    input logic           cs_memreq_val,

    input logic           cs_cachereq_en,
    input logic           cs_memresp_en
  );
  begin
    cachereq_rdy        = cs_cachereq_rdy;
    cacheresp_val       = cs_cacheresp_val;
    
    memresp_rdy         = cs_memresp_rdy;
    memreq_val          = cs_memreq_val;

    cachereq_en         = cs_cachereq_en;
    memresp_en          = cs_memresp_en;
  end
  endtask

  logic [1:0]   vd_v;
  logic [1:0]   vd_d;
  logic [1:0]   vd_c;
  logic [15:0]  wb_y;

  assign vd_v = rf_state | 2'b10;
  assign vd_d = rf_state | 2'b11;
  assign vd_c = rf_state & 2'b10;

  always_comb begin
    case (offset[3:2])
      2'd0: wb_y = 16'h000F;
      2'd1: wb_y = 16'h00F0;
      2'd2: wb_y = 16'h0F00;
      2'd3: wb_y = 16'hF000;
      default: wb_y = wb_n;
    endcase
  end

  always_comb begin
    case ( state )
      //               ev_reg rd_reg tag tag rf  rf  rf    data data data  c_data w_data  m_addr m_req
      //               en     en     ren wen ren wen date  ren  wen  wben  muxsel muxsel  muxsel type
      STATE_I   : cs0( n,     n,     n,  n,  n,  n,  vd_x, n,   n,   wb_n, rw_n,  wd_x,   ma_x,  nr );
      STATE_TC  : cs0( n,     n,     y,  n,  y,  n,  vd_x, n,   n,   wb_n, rw_n,  wd_x,   ma_x,  nr );
      STATE_IN  : cs0( n,     n,     n,  y,  n,  y,  vd_v, n,   y,   wb_y, rw_n,  wd_c,   ma_x,  nr );
      STATE_RD  : cs0( n,     y,     n,  n,  n,  n,  vd_x, y,   n,   wb_n, rw_n,  wd_c,   ma_x,  nr );
      STATE_WD  : cs0( n,     n,     n,  n,  n,  y,  vd_d, n,   y,   wb_y, rw_n,  wd_c,   ma_x,  nr );
      STATE_RR  : cs0( n,     n,     n,  n,  n,  n,  vd_x, n,   n,   wb_n, rw_n,  wd_x,   ma_c,  ld );
      STATE_RW  : cs0( n,     n,     n,  n,  n,  n,  vd_x, n,   n,   wb_n, rw_n,  wd_x,   ma_x,  nr );
      STATE_RU  : cs0( n,     n,     n,  y,  n,  y,  vd_v, n,   y,   wb_a, rw_n,  wd_m,   ma_x,  nr );
      STATE_EP  : cs0( y,     y,     y,  n,  n,  n,  vd_x, y,   n,   wb_n, rw_n,  wd_x,   ma_x,  nr );
      STATE_ER  : cs0( n,     n,     n,  n,  n,  n,  vd_x, n,   n,   wb_n, rw_n,  wd_x,   ma_e,  st );
      STATE_EW  : cs0( n,     n,     n,  n,  n,  n,  vd_x, n,   n,   wb_n, rw_n,  wd_x,   ma_x,  nr );
      STATE_W   : cs0( n,     n,     n,  n,  n,  n,  vd_x, n,   n,   wb_n, rw_y,  wd_x,   ma_x,  nr );
      default   : cs0( n,     n,     n,  n,  n,  n,  vd_x, n,   n,   wb_n, rw_n,  wd_x,   ma_x,  nr );
    endcase
  end

  always_comb begin
    case ( state )
      //               c_req c_resp m_resp m_req c_req m_resp
      //               rdy   val    rdy    val   en    en
      STATE_I   : cs1( y,    n,     n,     n,    y,    n );
      STATE_RR  : cs1( n,    n,     n,     y,    n,    n );
      STATE_RW  : cs1( n,    n,     y,     n,    n,    y );
      STATE_ER  : cs1( n,    n,     n,     y,    n,    n );
      STATE_EW  : cs1( n,    n,     y,     n,    n,    y );
      STATE_W   : cs1( n,    y,     n,     n,    n,    n );
      default   : cs1( n,    n,     n,     n,    n,    n );
      endcase
  end

  assign cacheresp_type = cachereq_type;

endmodule

`endif
