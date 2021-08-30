#=========================================================================
# Integer Multiplier Fixed Latency RTL Model
#=========================================================================

from pymtl        import *
from pclib.ifcs   import InValRdyBundle, OutValRdyBundle
from pclib.rtl    import Mux, RegEn, RegRst, Reg
from pclib.rtl    import LeftLogicalShifter, RightLogicalShifter, Adder, Counter

from ReqMsg       import ReqMsg

#=========================================================================
# Constants
#=========================================================================

A_MUX_SEL_IN    = 0
A_MUX_SEL_SHIFT = 1
A_MUX_SEL_X     = 0

B_MUX_SEL_IN    = 0
B_MUX_SEL_SHIFT = 1
B_MUX_SEL_X     = 0

R_MUX_SEL_ZERO  = 0
R_MUX_SEL_ADD   = 1
R_MUX_SEL_X     = 0

#=========================================================================
# Integer Multiplier RTL Datapath
#=========================================================================

class IntMulDpathRTL(Model):

  # Constructor

  def __init__(s):

    #---------------------------------------------------------------------
    # Interface
    #---------------------------------------------------------------------

    s.req_msg_a  = InPort  (32)
    s.req_msg_b  = InPort  (32)
    s.resp_msg   = OutPort (32)

    # Control signals (ctrl -> dpath)

    s.a_mux_sel      = InPort (1)
    s.b_mux_sel      = InPort (1)
    s.result_mux_sel = InPort (1)
    s.result_en      = InPort (1)

    # Status signals (dpath -> ctrl)

    s.b_lsb = OutPort (1)

    #---------------------------------------------------------------------
    # Structural composition
    #---------------------------------------------------------------------

    s.a_shift_out =   Wire(32)
    s.b_shift_out =   Wire(32)
    s.add_out     =   Wire(32)
    
    # A mux

    s.a_mux = m = Mux(32, 2)
    s.connect_pairs(
      m.sel,                    s.a_mux_sel,
      m.in_[ A_MUX_SEL_IN    ], s.req_msg_a,
      m.in_[ A_MUX_SEL_SHIFT ], s.a_shift_out,
    )

    # A register

    s.a_reg = m = Reg(32)
    s.connect( m.in_, s.a_mux.out )

    # A shifter

    s.a_shifter = m = LeftLogicalShifter(32)
    s.connect_pairs(
      m.in_,    s.a_reg.out,
      m.shamt,  1,
      m.out,    s.a_shift_out,
    )

    # B mux

    s.b_mux = m = Mux(32, 2)
    s.connect_pairs(
      m.sel,                    s.b_mux_sel,
      m.in_[ B_MUX_SEL_IN    ], s.req_msg_b,
      m.in_[ B_MUX_SEL_SHIFT ], s.b_shift_out,
    )

    # B register

    s.b_reg = m = Reg(32)
    s.connect( m.in_, s.b_mux.out )

    # B shifter

    s.b_shifter = m = RightLogicalShifter(32)
    s.connect_pairs(
      m.in_,    s.b_reg.out,
      m.shamt,  1,
      m.out,    s.b_shift_out,
    )

    # RESULT mux

    s.result_mux = m = Mux(32, 2)
    s.connect_pairs(
      m.sel,  s.result_mux_sel,
      m.in_[R_MUX_SEL_ZERO], 0,
      m.in_[R_MUX_SEL_ADD],  s.add_out,
    )

    # RESULT register

    s.result_reg = m = RegEn(32)
    s.connect_pairs(
      m.en,  s.result_en,
      m.in_, s.result_mux.out,
    )

    # Adder
    s.adder = m = Adder(32)
    s.connect_pairs(
      m.in0,  s.a_reg.out,
      m.in1,  s.result_reg.out,
      m.cin,  0,
      m.out, s.add_out,
    )

    # connect to output port

    s.connect( s.result_reg.out, s.resp_msg )

    @s.combinational
    def block1():
      s.b_lsb.value = s.b_reg.out[0]

#=========================================================================
# Integer Multiplier RTL Control
#=========================================================================

class IntMulCtrlRTL(Model):

  def __init__(s):

    #---------------------------------------------------------------------
    # Interface
    #---------------------------------------------------------------------

    s.req_val    = InPort  (1)
    s.req_rdy    = OutPort (1)

    s.resp_val   = OutPort (1)
    s.resp_rdy   = InPort  (1)

    # Control signals (ctrl -> dpath)

    s.a_mux_sel      = OutPort (1)
    s.b_mux_sel      = OutPort (1)
    s.result_mux_sel = OutPort (1)
    s.result_en      = OutPort (1)

    # Status signals (dpath -> ctrl)

    s.b_lsb = InPort (1)

    # State element

    s.STATE_IDLE = 0
    s.STATE_CALC = 1
    s.STATE_DONE = 2

    s.state = RegRst( 2, reset_value = s.STATE_IDLE )

    #---------------------------------------------------------------------
    # State Transition Logic
    #---------------------------------------------------------------------

    s.cntr_en  = Wire(1)
    s.cntr_rst = Wire(1)

    s.cntr = m = Counter(6)
    s.connect_pairs(
      m.en,   s.cntr_en,
      m.rst,  s.cntr_rst,
    )

    @s.combinational
    def state_transitions():

      curr_state = s.state.out
      next_state = s.state.out

      # Transistions out of IDLE state

      if ( curr_state == s.STATE_IDLE ):
        if ( s.req_val and s.req_rdy ):
          next_state = s.STATE_CALC
      
      # Transistions out of CALC state

      if ( curr_state == s.STATE_CALC ):
        if ( s.cntr.out == 32 ):
          next_state = s.STATE_DONE

      # Transistions out of DONE state

      if ( curr_state == s.STATE_DONE ):
        if ( s.resp_val and s.resp_rdy ):
          next_state = s.STATE_IDLE

      s.state.in_.value = next_state

    #---------------------------------------------------------------------
    # State Output Logic
    #---------------------------------------------------------------------

    s.do_add    = Wire(1)
    s.do_shift  = Wire(1)

    @s.combinational
    def state_outputs():

      current_state = s.state.out

      # In IDLE state we simply wait for inputs to arrive and latch them

      if current_state == s.STATE_IDLE:
        s.req_rdy.value        = 1
        s.resp_val.value       = 0
        s.cntr_en.value        = 1
        s.cntr_rst.value       = 1
        s.a_mux_sel.value      = A_MUX_SEL_IN
        s.b_mux_sel.value      = B_MUX_SEL_IN
        s.result_mux_sel.value = R_MUX_SEL_ZERO
        s.result_en.value      = 1

      # In CALC state we iteratively swap/sub to calculate GCD

      elif current_state == s.STATE_CALC:

        s.do_add.value    = s.b_lsb
        s.do_shift.value  = s.cntr.out < 32

        s.req_rdy.value        = 0
        s.resp_val.value       = 0
        s.cntr_en.value        = 1
        s.cntr_rst.value       = 0
        s.a_mux_sel.value      = A_MUX_SEL_SHIFT
        s.b_mux_sel.value      = B_MUX_SEL_SHIFT
        s.result_mux_sel.value = R_MUX_SEL_ADD
        s.result_en.value      = s.do_add

        if not s.do_shift:
          s.req_rdy.value        = 0
          s.resp_val.value       = 0
          s.cntr_en.value        = 1
          s.cntr_rst.value       = 0
          s.a_mux_sel.value      = A_MUX_SEL_SHIFT
          s.b_mux_sel.value      = B_MUX_SEL_SHIFT
          s.result_mux_sel.value = R_MUX_SEL_ADD
          s.result_en.value      = 0

        
      # In DONE state we simply wait for output transaction to occur

      elif current_state == s.STATE_DONE:
        s.req_rdy.value        = 0
        s.resp_val.value       = 1
        s.cntr_en.value        = 1
        s.cntr_rst.value       = 1
        s.a_mux_sel.value      = A_MUX_SEL_SHIFT
        s.b_mux_sel.value      = B_MUX_SEL_SHIFT
        s.result_mux_sel.value = R_MUX_SEL_ADD
        s.result_en.value      = 0

#=========================================================================
# Integer Multiplier Fixed Latency
#=========================================================================

class IntMulBasePRTL( Model ):

  # Constructor

  def __init__( s ):

    # Interface

    s.req    = InValRdyBundle  ( ReqMsg(32) )
    s.resp   = OutValRdyBundle ( Bits(32)   )

    # Instantiate datapath and control

    s.dpath = IntMulDpathRTL()
    s.ctrl  = IntMulCtrlRTL ()

    # Connect input interface to dpath/ctrl

    s.connect( s.req.msg.a,       s.dpath.req_msg_a )
    s.connect( s.req.msg.b,       s.dpath.req_msg_b )

    s.connect( s.req.val,         s.ctrl.req_val    )
    s.connect( s.req.rdy,         s.ctrl.req_rdy    )

    # Connect dpath/ctrl to output interface

    s.connect( s.dpath.resp_msg,  s.resp.msg        )
    s.connect( s.ctrl.resp_val,   s.resp.val        )
    s.connect( s.ctrl.resp_rdy,   s.resp.rdy        )

    # Connect status/control signals

    s.connect_auto( s.dpath, s.ctrl )

  # Line tracing

  def line_trace( s ):

    state_str = "? "
    if s.ctrl.state.out == s.ctrl.STATE_IDLE:
      state_str = "I "
    if s.ctrl.state.out == s.ctrl.STATE_CALC:
      if s.ctrl.do_shift:
        state_str = "Cs"
      else:
        state_str = "C "
    if s.ctrl.state.out == s.ctrl.STATE_DONE:
      state_str = "D "

    return "{}({} {} {}){}".format(
      s.req,
      s.dpath.a_reg.out,
      s.dpath.b_reg.out,
      state_str,
      s.resp,
    )