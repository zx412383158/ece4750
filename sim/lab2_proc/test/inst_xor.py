#=========================================================================
# xor
#=========================================================================

import random

from pymtl import *
from inst_utils import *

#-------------------------------------------------------------------------
# gen_basic_test
#-------------------------------------------------------------------------

def gen_basic_test():
  return """
    csrr x1, mngr2proc < 0x0f0f0f0f
    csrr x2, mngr2proc < 0x00ff00ff
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    xor x3, x1, x2
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    csrw proc2mngr, x3 > 0x0ff00ff0
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
    gen_rr_value_test( "xor", 0xff00ff00, 0x0f0f0f0f, 0xf00ff00f ),
    gen_rr_value_test( "xor", 0x0ff00ff0, 0xf0f0f0f0, 0xff00ff00 ),
    gen_rr_value_test( "xor", 0x00ff00ff, 0x0f0f0f0f, 0x0ff00ff0 ),
    gen_rr_value_test( "xor", 0xf00ff00f, 0xf0f0f0f0, 0x00ff00ff ),
  ]

#-------------------------------------------------------------------------
# gen_random_test
#-------------------------------------------------------------------------

def gen_random_test():
  asm_code = []
  for i in xrange(100):
    src0 = Bits( 32, random.randint(0,0xffffffff) )
    src1 = Bits( 32, random.randint(0,0xffffffff) )
    dest = src0 ^ src1
    asm_code.append( gen_rr_value_test( "xor", src0.uint(), src1.uint(), dest.uint() ) )
  return asm_code

