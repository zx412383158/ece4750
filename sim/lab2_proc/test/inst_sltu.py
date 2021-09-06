#=========================================================================
# sltu
#=========================================================================

import random

from pymtl import *
from inst_utils import *

#-------------------------------------------------------------------------
# gen_basic_test
#-------------------------------------------------------------------------

def gen_basic_test():
  return """
    csrr x1, mngr2proc < 4
    csrr x2, mngr2proc < 5
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    sltu x3, x1, x2
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    csrw proc2mngr, x3 > 1
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
  """

#-------------------------------------------------------------------------
# gen_value_test
#-------------------------------------------------------------------------

def gen_value_test():
  return [

    gen_rr_value_test( "sltu", 0x00000000, 0x00000000, 0x00000000 ),
    gen_rr_value_test( "sltu", 0x00000001, 0x00000001, 0x00000000 ),
    gen_rr_value_test( "sltu", 0x00000003, 0x00000007, 0x00000001 ),

    gen_rr_value_test( "sltu", 0x00000000, 0xffff8000, 0x00000001 ),
    gen_rr_value_test( "sltu", 0x80000000, 0x00000000, 0x00000000 ),
    gen_rr_value_test( "sltu", 0x80000000, 0xffff8000, 0x00000001 ),

    gen_rr_value_test( "sltu", 0x00000000, 0x00007fff, 0x00000001 ),
    gen_rr_value_test( "sltu", 0x7fffffff, 0x00000000, 0x00000000 ),
    gen_rr_value_test( "sltu", 0x7fffffff, 0x00007fff, 0x00000000 ),

    gen_rr_value_test( "sltu", 0x80000000, 0x00007fff, 0x00000000 ),
    gen_rr_value_test( "sltu", 0x7fffffff, 0xffff8000, 0x00000001 ),

    gen_rr_value_test( "sltu", 0x00000000, 0xffffffff, 0x00000001 ),
    gen_rr_value_test( "sltu", 0xffffffff, 0x00000001, 0x00000000 ),
    gen_rr_value_test( "sltu", 0xffffffff, 0xffffffff, 0x00000000 ),

  ]

#-------------------------------------------------------------------------
# gen_random_test
#-------------------------------------------------------------------------

def gen_random_test():
  asm_code = []
  for i in xrange(100):
    src0 = Bits( 32, random.randint(0,0xffffffff) )
    src1 = Bits( 32, random.randint(0,0xffffffff) )
    dest = Bits( 32, src0.uint() < src1.uint())
    asm_code.append( gen_rr_value_test( "sltu", src0.uint(), src1.uint(), dest.uint() ) )
  return asm_code
