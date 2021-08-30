//========================================================================
// Integer Multiplier Fixed-Latency Implementation
//========================================================================

`ifndef LAB1_IMUL_INT_MUL_BASE_V
`define LAB1_IMUL_INT_MUL_BASE_V

`include "vc/trace.v"
`include "vc/regs.v"
//========================================================================
// Integer Multiplier Fixed-Latency Datapath
//========================================================================

module lab1_imul_IntMulAltDpath
#(
  parameter p_nbits = 16
)(
  input  logic clk,
  input  logic reset,

  // Data signals

  input  logic [2*p_nbits-1:0] req_msg,
  output logic [  p_nbits-1:0] resp_msg,

  // Control signals

  input  logic tc,
  input  logic reg_a_en,
  input  logic reg_b_en

  // Status signals
);

  // A reg
  logic [p_nbits-1: 0] reg_a_out;
  vc_EnResetReg #(p_nbits, 0) reg_a
  (
    .clk    (clk),
    .reset  (reset),
    .q      (reg_a_out),
    .d      (req_msg[2*p_nbits-1:p_nbits]),
    .en     (reg_a_en)
  );
  
  // B reg
  logic [p_nbits-1: 0] reg_b_out;
  vc_EnResetReg #(p_nbits, 0) reg_b
  (
    .clk    (clk),
    .reset  (reset),
    .q      (reg_b_out),
    .d      (req_msg[p_nbits-1:0]),
    .en     (reg_b_en)
  );

  // Multiply
  logic signed [2*p_nbits-1:0] product_sig;
  logic        [2*p_nbits-1:0] product_usig;

  assign product_sig  = $signed(reg_a_out) * $signed(reg_b_out);
  assign product_usig = reg_a_out * reg_b_out;
  assign resp_msg = (tc ? product_sig[p_nbits-1:0] : product_usig[p_nbits-1:0]);
  
endmodule

//========================================================================
// Integer Multiplier Fixed-Latency Datapath
//========================================================================

typedef enum logic [$clog2(3)-1:0] {
  STATE_IDLE,
  STATE_CALC,
  STATE_DONE
} state_t;

module lab1_im1_IntMulAltCtrl(
  input logic clk,
  input logic reset,

  // Dataflow signals

  input  logic req_val,
  output logic req_rdy,
  output logic resp_val,
  input  logic resp_rdy,

  // Control signals

  output logic tc,
  output logic reg_a_en,
  output logic reg_b_en

  // Data signals
);

  //----------------------------------------------------------------------
  // State
  //----------------------------------------------------------------------

  state_t state, next_state;

  always_ff @(posedge clk) begin
    if (reset) state <= STATE_IDLE;
    else       state <= next_state;
  end

  //  a counter
  
  logic [3:0] cntr_value;
  logic cntr_rst;

  always_ff @(posedge clk) begin
    if (cntr_rst) cntr_value <= 0;
    else          cntr_value <= cntr_value + 1;
  end 
  
  //----------------------------------------------------------------------
  // State Transitions
  //----------------------------------------------------------------------

  logic req_go;
  logic resp_go;
  logic is_calc_done;

  assign req_go       = req_val  && req_rdy;
  assign resp_go      = resp_val && resp_rdy;
  assign is_calc_done = cntr_value == 3;

  always_comb begin

    next_state = state;

    case ( state )

      STATE_IDLE: if ( req_go    )             next_state = STATE_CALC;
      STATE_CALC: if ( is_calc_done )
                    if ( req_val && resp_rdy ) next_state = STATE_CALC;
                    else if ( resp_rdy )       next_state = STATE_IDLE;
                    else                       next_state = STATE_DONE;
      STATE_DONE: if ( resp_go   )             next_state = STATE_IDLE;
      default:                                 next_state = STATE_IDLE;

    endcase

  end

  //----------------------------------------------------------------------
  // State Outputs
  //----------------------------------------------------------------------

  task  cs
  (
    input logic cs_req_rdy,
    input logic cs_resp_val,
    input logic cs_cntr_rst,
    input logic cs_reg_a_en,
    input logic cs_reg_b_en,
    input logic cs_tc
  );
  begin
    req_rdy  = cs_req_rdy;
    resp_val = cs_resp_val;
    cntr_rst = cs_cntr_rst;
    reg_a_en = cs_reg_a_en;
    reg_b_en = cs_reg_b_en;
    tc       = cs_tc;   
  end
  endtask

  always_comb begin
    case ( state )
      STATE_IDLE: cs(1, 0, 1, 1, 1, 'x);
      STATE_CALC: begin
                    cs(0, 0, 0, 0, 0, 1);
                    if ( req_val && resp_rdy ) cs(1, 1, 1, 1, 1, 'x);
                    else if ( resp_rdy )       cs(0, 1, 1, 0, 0, 'x);
                  end
      STATE_DONE: cs(0, 1, 1, 0, 0, 'x);
      default:    cs(0, 0, 1, 0, 0, 'x);
    endcase
  end

endmodule

//========================================================================
// Integer Multiplier Fixed-Latency Implementation
//========================================================================

module lab1_imul_IntMulAltVRTL
(
  input  logic        clk,
  input  logic        reset,

  input  logic        req_val,
  output logic        req_rdy,
  input  logic [63:0] req_msg,

  output logic        resp_val,
  input  logic        resp_rdy,
  output logic [31:0] resp_msg
);

  // Control signals

  logic tc;
  logic reg_a_en;
  logic reg_b_en;

  // Control unit

  lab1_im1_IntMulAltCtrl ctrl
  (
    .*
  );

  // Datapath
  lab1_imul_IntMulAltDpath #(32) dpath
  (
    .*
  );


  //----------------------------------------------------------------------
  // Line Tracing
  //----------------------------------------------------------------------

  `ifndef SYNTHESIS

  logic [`VC_TRACE_NBITS-1:0] str;
  `VC_TRACE_BEGIN
  begin

    $sformat( str, "%x:%x", req_msg[63:32], req_msg[31:0] );
    vc_trace.append_val_rdy_str( trace_str, req_val, req_rdy, str );

    vc_trace.append_str( trace_str, "(" );

    $sformat( str, "%x", dpath.product_sig[31:0] );
    vc_trace.append_str( trace_str, str);

    vc_trace.append_str( trace_str, ":" );

    $sformat( str, "%x", dpath.product_usig[31:0] );
    vc_trace.append_str( trace_str, str);
    vc_trace.append_str( trace_str, " " );

    case ( ctrl.state )

      ctrl.STATE_IDLE:
        vc_trace.append_str( trace_str, "I " );

      ctrl.STATE_CALC:
        vc_trace.append_str( trace_str, "C " );

      ctrl.STATE_DONE:
        vc_trace.append_str( trace_str, "D " );

      default:
        vc_trace.append_str( trace_str, "? " );

    endcase

    vc_trace.append_str( trace_str, ")" );

    $sformat( str, "%x", resp_msg );
    vc_trace.append_val_rdy_str( trace_str, resp_val, resp_rdy, str );

  end
  `VC_TRACE_END

  `endif /* SYNTHESIS */

endmodule

`endif /* LAB1_IMUL_INT_MUL_BASE_V */

