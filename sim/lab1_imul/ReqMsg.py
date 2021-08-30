#=========================================================================
# ReqMsg
#=========================================================================

from pymtl import *

#-------------------------------------------------------------------------
# ReqMsg
#-------------------------------------------------------------------------
# BitStruct designed to hold two operands for a multiply

class ReqMsg( BitStructDefinition ):

  def __init__( s, nbits=16 ):
    s.a = BitField(nbits)
    s.b = BitField(nbits)

  def __str__( s ):
    return "{}:{}".format( s.a, s.b )

