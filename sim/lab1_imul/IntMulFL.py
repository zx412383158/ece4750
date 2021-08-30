#=========================================================================
# Integer Multiplier FL Model
#=========================================================================

from pymtl      import *
from pclib.ifcs import InValRdyBundle, OutValRdyBundle
from pclib.fl   import InValRdyQueueAdapterFL, OutValRdyQueueAdapterFL

from ReqMsg     import ReqMsg

class IntMulFL( Model ):

  # Constructor

  def __init__( s ):

    # Interface

    s.req    = InValRdyBundle  ( ReqMsg(32) )
    s.resp   = OutValRdyBundle ( Bits(32)   )

    # Adapters

    s.req_q  = InValRdyQueueAdapterFL  ( s.req  )
    s.resp_q = OutValRdyQueueAdapterFL ( s.resp )

    # Concurrent block

    @s.tick_fl
    def block():
      req_msg = s.req_q.popleft()
      result = Bits( 32, req_msg.a * req_msg.b, trunc=True )
      s.resp_q.append( result )

  # Line tracing

  def line_trace( s ):
    return "{}(){}".format( s.req, s.resp )

