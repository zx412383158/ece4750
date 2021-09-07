#=========================================================================
# lui
#=========================================================================

import random

from pymtl import *
from inst_utils import *

#-------------------------------------------------------------------------
# gen_basic_test
#-------------------------------------------------------------------------

def gen_basic_test():
  return """
    lui x1, 0x0001
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    csrw proc2mngr, x1 > 0x00001000
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
# gen_dest_dep_test
#-------------------------------------------------------------------------

def gen_dest_dep_test():
  return [
    gen_imm_dest_dep_test( 5, "lui", 0x00000f0f, 0x00f0f000 ),
    gen_imm_dest_dep_test( 4, "lui", 0x00000f0f, 0x00f0f000 ),
    gen_imm_dest_dep_test( 3, "lui", 0x00000f0f, 0x00f0f000 ),
    gen_imm_dest_dep_test( 2, "lui", 0x00000f0f, 0x00f0f000 ),
    gen_imm_dest_dep_test( 1, "lui", 0x00000f0f, 0x00f0f000 ),
    gen_imm_dest_dep_test( 0, "lui", 0x00000f0f, 0x00f0f000 ),
  ]

#-------------------------------------------------------------------------
# gen_random_test
#-------------------------------------------------------------------------

def gen_random_test():
  asm_code = []
  for i in xrange(100):
    imm  = Bits( 32, random.randint(0,0xfffff) )
    dest = imm << 12
    asm_code.append( gen_imm_value_test( "lui", imm.uint(), dest.uint() ) )
  return asm_code

