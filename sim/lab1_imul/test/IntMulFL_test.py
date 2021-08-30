#=========================================================================
# IntMulFL_test
#=========================================================================

import pytest
import random

random.seed(0xdeadbeef)

from pymtl      import *
from pclib.test import mk_test_case_table, run_sim
from pclib.test import TestSource, TestSink

from lab1_imul.ReqMsg     import ReqMsg
from lab1_imul.IntMulFL   import IntMulFL

#-------------------------------------------------------------------------
# TestHarness
#-------------------------------------------------------------------------

class TestHarness (Model):

  def __init__( s, imul, src_msgs, sink_msgs,
                src_delay, sink_delay,
                dump_vcd=False, test_verilog=False ):

    # Instantiate models

    s.src  = TestSource ( ReqMsg(32), src_msgs,  src_delay  )
    s.imul = imul
    s.sink = TestSink   ( Bits(32),   sink_msgs, sink_delay )

    # Dump VCD

    if dump_vcd:
      s.imul.vcd_file = dump_vcd

    # Translation

    if test_verilog:
      s.imul = TranslationTool( s.imul )

    # Connect

    s.connect( s.src.out,  s.imul.req  )
    s.connect( s.imul.resp, s.sink.in_ )

  def done( s ):
    return s.src.done and s.sink.done

  def line_trace( s ):
    return s.src.line_trace()  + " > " + \
           s.imul.line_trace()  + " > " + \
           s.sink.line_trace()

#-------------------------------------------------------------------------
# mk_req_msg
#-------------------------------------------------------------------------

def req( a, b ):
  msg = ReqMsg(32)
  msg.a = a
  msg.b = b
  return msg

def resp( a ):
  return Bits( 32, a, trunc=True )

#----------------------------------------------------------------------
# Test Case: small positive * positive
#----------------------------------------------------------------------

small_pos_pos_msgs = [
  req(  2,  3 ), resp(   6 ),
  req(  4,  5 ), resp(  20 ),
  req(  3,  4 ), resp(  12 ),
  req( 10, 13 ), resp( 130 ),
  req(  8,  7 ), resp(  56 ),
]

small_neg_pos_msgs = [
  req( -1,  1 ), resp(  -1  ),
  req( -2,  4 ), resp(  -8  ),
  req( -8,  8 ), resp(  -64 ),
  req( -16, 10), resp( -160 ),
]

small_pos_neg_msgs = [
  req( 1,  -1 ), resp(  -1  ),
  req( 2,  -4 ), resp(  -8  ),
  req( 8,  -8 ), resp(  -64 ),
  req( 16, -10), resp( -160 ),
]

small_neg_neg_msgs = [
  req( -1,  -1 ), resp(  1  ),
  req( -2,  -4 ), resp(  8  ),
  req( -8,  -8 ), resp(  64 ),
  req( -128, -64), resp( 8192 ),
]

large_pos_pos_msgs = [
  req( 0x0fffffff,   0x64 ), resp( 0x3fffff9c ),
  req( 0x0fffffff,  0x160 ), resp( 0xfffffea0 ),
  req( 0x0fffffff, 0x1314 ), resp( 0x3fffecec ),
]

large_neg_pos_msgs = [
  req( 0xffffffff,   0x64 ), resp( 0xffffff9c ),
  req( 0xffffffff,  0x160 ), resp( 0xfffffea0 ),
  req( 0xffffffff, 0x1314 ), resp( 0xffffecec ),
]

LSB_masked_msg = [
  req( 0xffffffff, 0xffffff00 ), resp( 0x00000100 ),
  req( 0xffffffff, 0xffff0000 ), resp( 0x00010000 ),
  req( 0xffffffff, 0xff000000 ), resp( 0x01000000 ),
]

Mid_masked_msg = [
  req( 0xffffffff, 0xffff00ff ), resp( 0x0000ff01 ),
  req( 0xffffffff, 0xff0000ff ), resp( 0x00ffff01 ),
  req( 0xffffffff, 0xff00ffff ), resp( 0x00ff0001 ),
]

#-------------------------------------------------------------------------
# Test Case: random
#-------------------------------------------------------------------------

random.seed(0xdeadbeef)
random_msgs = []
for i in xrange(50):
  a = random.randint(0, 0xffffffff)
  b = random.randint(0, 0xffffffff)
  c = a * b
  random_msgs.extend([req(a, b), resp(c)])


#-------------------------------------------------------------------------
# Test Case Table
#-------------------------------------------------------------------------

test_case_table = mk_test_case_table([
    ("msgs                            src_delay sink_delay"),
    ["small_pos_pos",     small_pos_pos_msgs,   0,        0],
    ["small_neg_pos",     small_neg_pos_msgs,   0,        0],
    ["small_pos_neg",     small_pos_neg_msgs,   0,        0],
    ["small_neg_neg",     small_neg_neg_msgs,   0,        0],
    ["large_pos_pos",     large_pos_pos_msgs,   0,        0],
    ["large_neg_pos",     large_neg_pos_msgs,   0,        0],
    ["LSB_masked   ",     LSB_masked_msg,       0,        0],
    ["Mid_masked   ",     Mid_masked_msg,       0,        0],
    ["random       ",     random_msgs,          0,        0],
])

#-------------------------------------------------------------------------
# Test cases
#-------------------------------------------------------------------------


@pytest.mark.parametrize(**test_case_table)
def test(test_params, dump_vcd):
  run_sim(TestHarness(IntMulFL(),
                      test_params.msgs[::2], test_params.msgs[1::2],
                      test_params.src_delay, test_params.sink_delay))

