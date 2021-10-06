//=========================================================================
// Baseline Blocking Cache
//=========================================================================

`ifndef LAB3_MEM_BLOCKING_CACHE_BASE_V
`define LAB3_MEM_BLOCKING_CACHE_BASE_V

`include "vc/mem-msgs.v"
`include "vc/trace.v"

`include "lab3_mem/Definitions.sv"
`include "lab3_mem/BlockingCacheBaseCtrlVRTL.v"
`include "lab3_mem/BlockingCacheBaseDpathVRTL.v"

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

module lab3_mem_BlockingCacheBaseVRTL
#(
  parameter p_num_banks    = 0               // Total number of cache banks
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
  logic [2:0]        read_word_mux_sel;      // select by offset field
  logic              write_data_mux_sel;     // mem or proc
  logic              memreq_addr_mux_sel;    // refill or evict
  logic              tag_array_ren;
  logic              tag_array_wen;
  logic              data_array_ren;
  logic              data_array_wen;
  logic [15:0]       data_array_wben;
  logic              hit;
  logic [2:0]        cacheresp_type;
  logic [2:0]        memreq_type;

  logic [2:0]        cachereq_type;
  logic [31:0]       cachereq_addr;
  logic              tag_match;

  //----------------------------------------------------------------------
  // Control
  //----------------------------------------------------------------------

  lab3_mem_BlockingCacheBaseCtrlVRTL
  #(
    .p_idx_shamt            (c_idx_shamt)
  )
  ctrl
  (
    .clk               (clk),
    .reset             (reset),

    // Cache Request

    .cachereq_val      (cachereq_val),
    .cachereq_rdy      (cachereq_rdy),

    // Cache Response

    .cacheresp_val     (cacheresp_val),
    .cacheresp_rdy     (cacheresp_rdy),

    // Memory Request

    .memreq_val        (memreq_val),
    .memreq_rdy        (memreq_rdy),

    // Memory Response

    .memresp_val       (memresp_val),
    .memresp_rdy       (memresp_rdy),

    // control signals (ctrl->dpath)

    .cachereq_en        (cachereq_en),
    .memresp_en         (memresp_en),
    .evict_addr_reg_en  (evict_addr_reg_en),
    .read_data_reg_en   (read_data_reg_en),

    .read_word_mux_sel  (read_word_mux_sel),      // select by offset field
    .write_data_mux_sel (write_data_mux_sel),     // mem or proc
    .memreq_addr_mux_sel(memreq_addr_mux_sel),    // refill or evict
    
    .tag_array_ren      (tag_array_ren),
    .tag_array_wen      (tag_array_wen),

    .data_array_ren     (data_array_ren),
    .data_array_wen     (data_array_wen),
    .data_array_wben    (data_array_wben),

    .hit                (hit),
    .cacheresp_type     (cacheresp_type),
    .memreq_type        (memreq_type),

    // status signals (dpath->ctrl)

    .cachereq_type      (cachereq_type),
    .cachereq_addr      (cachereq_addr),

    .tag_match          (tag_match)
  );

  //----------------------------------------------------------------------
  // Datapath
  //----------------------------------------------------------------------

  lab3_mem_BlockingCacheBaseDpathVRTL
  #(
    .p_idx_shamt            (c_idx_shamt)
  )
  dpath
  (
    .clk               (clk),
    .reset             (reset),

    // Cache Request

    .cachereq_msg      (cachereq_msg),

    // Cache Response

    .cacheresp_msg     (cacheresp_msg),

    // Memory Request

    .memreq_msg        (memreq_msg),

    // Memory Response

    .memresp_msg       (memresp_msg),

    // control signals (ctrl->dpath)

    .cachereq_en        (cachereq_en),
    .memresp_en         (memresp_en),
    .evict_addr_reg_en  (evict_addr_reg_en),
    .read_data_reg_en   (read_data_reg_en),

    .read_word_mux_sel  (read_word_mux_sel),      // select by offset field
    .write_data_mux_sel (write_data_mux_sel),     // mem or proc
    .memreq_addr_mux_sel(memreq_addr_mux_sel),    // refill or evict
    
    .tag_array_ren      (tag_array_ren),
    .tag_array_wen      (tag_array_wen),

    .data_array_ren     (data_array_ren),
    .data_array_wen     (data_array_wen),
    .data_array_wben    (data_array_wben),

    .hit                (hit),
    .cacheresp_type     (cacheresp_type),
    .memreq_type        (memreq_type),

    // status signals (dpath->ctrl)

    .cachereq_type      (cachereq_type),
    .cachereq_addr      (cachereq_addr),

    .tag_match          (tag_match)

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

      STATE_I  :             vc_trace.append_str( trace_str, "(I )" );
      STATE_TC :             vc_trace.append_str( trace_str, "(TC)" );
      STATE_IN :             vc_trace.append_str( trace_str, "(IN)" );
      STATE_RD :             vc_trace.append_str( trace_str, "(RD)" );
      STATE_W  :             vc_trace.append_str( trace_str, "(W )" );
      default  :             vc_trace.append_str( trace_str, "(? )" );

    endcase

  end
  `VC_TRACE_END

endmodule

`endif
