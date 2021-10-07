//=========================================================================
// Alternative Blocking Cache
//=========================================================================

`ifndef LAB3_MEM_BLOCKING_CACHE_ALT_V
`define LAB3_MEM_BLOCKING_CACHE_ALT_V

`include "vc/mem-msgs.v"
`include "vc/trace.v"

`include "lab3_mem/BlockingCacheAltCtrlVRTL.v"
`include "lab3_mem/BlockingCacheAltDpathVRTL.v"

// Note on p_num_banks:
// In a multi-banked cache design, cache lines are interleaved to
// different cache banks, so that consecutive cache lines correspond to a
// different bank. The following is the addressing structure in our
// four-banked data caches:
//
// +--------------------------+--------------+--------+--------+--------+
// |        22b               |     4b       |   2b   |   2b   |   2b   |
// |        tag               |   index      |bank idx| offset | subwd  |
// +--------------------------+--------------+--------+--------+--------+
//
// We will compose a four-banked cache in lab5, the multi-core lab

module lab3_mem_BlockingCacheAltVRTL
#(
  parameter p_num_banks  = 0              // Total number of cache banks
)
(
  input  logic           clk,
  input  logic           reset,

  // Cache Request

  input  mem_req_4B_t    cachereq_msg,
  input  logic           cachereq_val,
  output logic           cachereq_rdy,

  // Cache Response

  output mem_resp_4B_t   cacheresp_msg,
  output logic           cacheresp_val,
  input  logic           cacheresp_rdy,

  // Memory Request

  output mem_req_16B_t   memreq_msg,
  output logic           memreq_val,
  input  logic           memreq_rdy,

  // Memory Response

  input  mem_resp_16B_t  memresp_msg,
  input  logic           memresp_val,
  output logic           memresp_rdy
);

  // calculate the index shift amount based on number of banks

  localparam c_idx_shamt = $clog2( p_num_banks );

  logic              cachereq_en;
  logic              memresp_en;
  logic              evict_addr_reg_en;
  logic              read_data_reg_en;
  logic              cacheresp_data_mux_sel; // select by offset field
  logic              write_data_mux_sel;     // mem or proc
  logic              memreq_addr_mux_sel;    // refill or evict
  logic              cache_way_mux_sel;
  logic              tag_array_ren;
  logic              tag_array0_wen;
  logic              tag_array1_wen;
  logic              data_array_ren;
  logic [clw/8-1:0]  data_array_wben;
  logic              data_array0_wen;
  logic              data_array1_wen;
  logic              hit;
  logic [2:0]        cacheresp_type;
  logic [2:0]        memreq_type;

  logic [2:0]        cachereq_type;
  logic [31:0]       cachereq_addr;
  logic              tag_match0;
  logic              tag_match1;

  //----------------------------------------------------------------------
  // Control
  //----------------------------------------------------------------------

  lab3_mem_BlockingCacheAltCtrlVRTL
  #(
    .p_idx_shamt            (c_idx_shamt)
  )
  ctrl
  (
    .*
  );

  //----------------------------------------------------------------------
  // Datapath
  //----------------------------------------------------------------------

  lab3_mem_BlockingCacheAltDpathVRTL
  #(
    .p_idx_shamt            (c_idx_shamt)
  )
  dpath
  (
    .*
  );


  //----------------------------------------------------------------------
  // Line tracing
  //----------------------------------------------------------------------
  vc_MemReqMsg4BTrace cachereq_msg_trace
  (
    .clk   (clk),
    .reset (reset),
    .val   (cachereq_val),
    .rdy   (cachereq_rdy),
    .msg   (cachereq_msg)
  );

  vc_MemRespMsg4BTrace cacheresp_msg_trace
  (
    .clk   (clk),
    .reset (reset),
    .val   (cacheresp_val),
    .rdy   (cacheresp_rdy),
    .msg   (cacheresp_msg)
  );

  vc_MemReqMsg16BTrace memreq_msg_trace
  (
    .clk   (clk),
    .reset (reset),
    .val   (memreq_val),
    .rdy   (memreq_rdy),
    .msg   (memreq_msg)
  );

  vc_MemRespMsg16BTrace memresp_msg_trace
  (
    .clk   (clk),
    .reset (reset),
    .val   (memresp_val),
    .rdy   (memresp_rdy),
    .msg   (memresp_msg)
  );

  `VC_TRACE_BEGIN
  begin

    case ( ctrl.state )

      STATE_I  :              vc_trace.append_str( trace_str, "(I )" );
      STATE_TC :              vc_trace.append_str( trace_str, "(TC)" );
      STATE_IN :              vc_trace.append_str( trace_str, "(IN)" );
      STATE_RD :              vc_trace.append_str( trace_str, "(RD)" );
      STATE_WD :              vc_trace.append_str( trace_str, "(WD)" );
      STATE_EP :              vc_trace.append_str( trace_str, "(EP)" );
      STATE_ER :              vc_trace.append_str( trace_str, "(ER)" );
      STATE_EW :              vc_trace.append_str( trace_str, "(EW)" );
      STATE_RR :              vc_trace.append_str( trace_str, "(RR)" );
      STATE_RW :              vc_trace.append_str( trace_str, "(RW)" );
      STATE_RU :              vc_trace.append_str( trace_str, "(RU)" );
      STATE_W  :              vc_trace.append_str( trace_str, "(W )" );
      default  :              vc_trace.append_str( trace_str, "(? )" );

    endcase

  end
  `VC_TRACE_END

endmodule

`endif
