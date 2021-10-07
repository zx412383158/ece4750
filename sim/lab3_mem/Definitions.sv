`ifndef DEFS_DONE
`define DEFS_DONE

//========================================================================
// Cache design parameter/struct
//========================================================================

package definitions;
  
  localparam size = 256;             // Cache size in bytes
  localparam dbw  = 32;              // Short name for data bitwidth
  localparam abw  = 32;              // Short name for addr bitwidth
  localparam clw  = 128;             // Short name for cacheline bitwidth
  localparam nway = 1;               // Short name for cache associate
  
  // cache controller states

  typedef enum logic [$clog2(12)-1:0] {
    STATE_I,            // STATE_IDLE,
    STATE_TC,           // STATE_TAG_CHECK,
    STATE_IN,           // STATE_INIT_DATA_ACCESS,
    STATE_RD,           // STATE_READ_DATA_ACCESS,
    STATE_WD,           // STATE_WRITE_DATA_ACCESS,
    STATE_EP,           // STATE_EVICT_PREPARE,
    STATE_ER,           // STATE_EVICT_REQUEST,
    STATE_EW,           // STATE_EVICT_WAIT,
    STATE_RR,           // STATE_REFILL_REQUEST,
    STATE_RW,           // STATE_REFILL_WAIT,
    STATE_RU,           // STATE_REFILL_UPDATE,
    STATE_W             // STATE_WAIT
  } state_t;

endpackage

//========================================================================
// import package into $unit
//========================================================================

  import definitions::*;

`endif