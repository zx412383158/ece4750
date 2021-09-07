#=========================================================================
# slti
#=========================================================================

import random

from pymtl import *
from inst_utils import *

#-------------------------------------------------------------------------
# gen_basic_test
#-------------------------------------------------------------------------

def gen_basic_test():
  return """
    csrr x1, mngr2proc < 5
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    slti x3, x1, 6
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
    gen_rimm_value_test( "slti", 0x00000000, 0xfff, 0x00000000 ),
    gen_rimm_value_test( "slti", 0x00000000, 0x7ff, 0x00000001 ),
    gen_rimm_value_test( "slti", 0xffffffff, 0x000, 0x00000001 ),
    gen_rimm_value_test( "slti", 0x00000fff, 0x000, 0x00000000 ),
  ]

#-------------------------------------------------------------------------
# gen_random_test
#-------------------------------------------------------------------------

def gen_random_test():
  asm_code = []
  for i in xrange(100):
    src  = Bits( 32, random.randint(0,0xffffffff) )
    imm  = Bits( 12, random.randint(0,0xfff) )
    dest = Bits( 32, src.int() < sext(imm,32).int() )
    asm_code.append( gen_rimm_value_test( "slti", src.int(), imm.int(), dest.int() ) )
  return asm_code
