/**
  *
  * testbench.v
  *
  */
  
//`include "bp_be_dcache_pkt.vh"

module testbench
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_be_dcache_pkg::*;
 import bp_cce_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(bp_params_p)

   // interface widths
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   , parameter cce_trace_p = 0
   , parameter axe_trace_p = 0
   , parameter instr_count = 1
   , parameter skip_init_p = 0
   , parameter lce_perf_trace_p = 0

   , parameter mem_zero_p         = 1
   , parameter mem_load_p         = 0
   , parameter mem_file_p         = "inv"
   , parameter mem_cap_in_bytes_p = 2**20
   // CCE testing uses any address it wants, no DRAM offset required
   , parameter mem_offset_p       = '0

   , parameter use_max_latency_p      = 0
   , parameter use_random_latency_p   = 1
   , parameter use_dramsim2_latency_p = 0

   , parameter max_latency_p = 15

   , parameter dram_clock_period_in_ps_p = 1000
   , parameter dram_cfg_p                = "dram_ch.ini"
   , parameter dram_sys_cfg_p            = "dram_sys.ini"
   , parameter dram_capacity_p           = 16384

   // LCE Trace Replay Width
   , localparam dcache_opcode_width_lp=$bits(bp_be_dcache_opcode_e)
   , localparam tr_ring_width_lp=(dcache_opcode_width_lp+paddr_width_p+dword_width_p)
   , localparam tr_rom_addr_width_p = 20

   )
  (input clk_i
   , input reset_i
   );

`declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
`declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
`declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

// CFG IF
bp_cce_mem_msg_s       cfg_io_cmd_lo;
logic                 cfg_io_cmd_v_lo, cfg_io_cmd_yumi_li;
bp_cce_mem_msg_s       cfg_io_resp_li;
logic                 cfg_io_resp_v_li, cfg_io_resp_ready_lo;

bp_cce_mem_msg_s      cfg_mem_cmd_lo;
logic                 cfg_mem_cmd_v_lo, cfg_mem_cmd_yumi_li;
bp_cce_mem_msg_s      cfg_mem_resp_li;
logic                 cfg_mem_resp_v_li, cfg_mem_resp_ready_lo;

// CCE-MEM IF
bp_cce_mem_msg_s       mem_resp;
logic                  mem_resp_v, mem_resp_ready;
bp_cce_mem_msg_s       mem_cmd;
logic                  mem_cmd_v, mem_cmd_yumi;

// LCE-CCE IF
bp_lce_cce_req_s       lce_req;
logic                  lce_req_v, lce_req_ready;
bp_lce_cce_resp_s      lce_resp;
logic                  lce_resp_v, lce_resp_ready;
bp_lce_cmd_s           lce_cmd;
logic                  lce_cmd_v, lce_cmd_ready;
bp_lce_cmd_s           lce_cmd_lo;
logic                  lce_cmd_v_lo, lce_cmd_ready_li;
// Single LCE setup - LCE should never send a Data Command
assign lce_cmd_ready_li = '0;

// Trace Replay for LCE
logic                        tr_v_li, tr_ready_lo;
logic [tr_ring_width_lp-1:0] tr_data_li;
logic                        tr_v_lo, tr_yumi_li;
logic [tr_ring_width_lp-1:0] tr_data_lo;
logic tr_done_lo;

bsg_trace_node_master #(
  .id_p('0)
  ,.ring_width_p(tr_ring_width_lp)
  ,.rom_addr_width_p(tr_rom_addr_width_p)
) trace_node_master (
  .clk_i(clk_i)
  ,.reset_i(reset_i)
  ,.en_i(1'b1)

  ,.v_i(tr_v_li)
  ,.data_i(tr_data_li)
  ,.ready_o(tr_ready_lo)

  ,.v_o(tr_v_lo)
  ,.yumi_i(tr_yumi_li)
  ,.data_o(tr_data_lo)

  ,.done_o(tr_done_lo)
);

// LCE
bp_me_nonsynth_mock_lce #(
  .bp_params_p(bp_params_p)
  ,.axe_trace_p(axe_trace_p)
  ,.perf_trace_p(lce_perf_trace_p)
) lce (
  .clk_i(clk_i)
  ,.reset_i(reset_i)
  ,.freeze_i('0)

  ,.lce_id_i('0)

  ,.tr_pkt_i(tr_data_lo)
  ,.tr_pkt_v_i(tr_v_lo)
  ,.tr_pkt_yumi_o(tr_yumi_li)

  ,.tr_pkt_v_o(tr_v_li)
  ,.tr_pkt_o(tr_data_li)
  ,.tr_pkt_ready_i(tr_ready_lo)

  ,.lce_req_o(lce_req)
  ,.lce_req_v_o(lce_req_v)
  ,.lce_req_ready_i(lce_req_ready)

  ,.lce_resp_o(lce_resp)
  ,.lce_resp_v_o(lce_resp_v)
  ,.lce_resp_ready_i(lce_resp_ready)

  ,.lce_cmd_i(lce_cmd)
  ,.lce_cmd_v_i(lce_cmd_v)
  ,.lce_cmd_ready_o(lce_cmd_ready)

  ,.lce_cmd_o(lce_cmd_lo)
  ,.lce_cmd_v_o(lce_cmd_v_lo)
  ,.lce_cmd_ready_i(lce_cmd_ready_li)
);

// TODO: Transduce between mem and io
assign cfg_mem_cmd_lo = cfg_io_cmd_lo;
assign cfg_mem_cmd_v_lo = cfg_io_cmd_v_lo;
assign cfg_io_cmd_yumi_li = cfg_mem_cmd_yumi_li;

assign cfg_io_resp_li = cfg_mem_resp_li;
assign cfg_io_resp_v_li = cfg_mem_resp_v_li;
assign cfg_mem_resp_ready_lo = cfg_io_resp_ready_lo;

bp_cfg_bus_s cfg_bus_lo;
bp_cfg
 #(.bp_params_p(bp_params_p))
 cfg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_i(cfg_mem_cmd_lo)
   ,.mem_cmd_v_i(cfg_mem_cmd_v_lo)
   ,.mem_cmd_yumi_o(cfg_mem_cmd_yumi_li)

   ,.mem_resp_o(cfg_mem_resp_li)
   ,.mem_resp_v_o(cfg_mem_resp_v_li)
   ,.mem_resp_ready_i(cfg_mem_resp_ready_lo)

   ,.cfg_bus_o(cfg_bus_lo)
   ,.irf_data_i()
   ,.npc_data_i()
   ,.csr_data_i()
   ,.priv_data_i()
   ,.cce_ucode_data_i()
   ,.cord_i()
   ,.did_i()
   );

// CCE
wrapper
#(.bp_params_p(bp_params_p)
  ,.cce_trace_p(cce_trace_p)
 )
wrapper
 (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.cfg_bus_i(cfg_bus_lo)
  ,.cfg_cce_ucode_data_o()

  ,.lce_cmd_o(lce_cmd)
  ,.lce_cmd_v_o(lce_cmd_v)
  ,.lce_cmd_ready_i(lce_cmd_ready)

  ,.lce_req_i(lce_req)
  ,.lce_req_v_i(lce_req_v)
  ,.lce_req_ready_o(lce_req_ready)

  ,.lce_resp_i(lce_resp)
  ,.lce_resp_v_i(lce_resp_v)
  ,.lce_resp_ready_o(lce_resp_ready)

  ,.mem_resp_i(mem_resp)
  ,.mem_resp_v_i(mem_resp_v)
  ,.mem_resp_ready_o(mem_resp_ready)

  ,.mem_cmd_i('0)
  ,.mem_cmd_v_i('0)
  ,.mem_cmd_ready_o()

  ,.mem_cmd_o(mem_cmd)
  ,.mem_cmd_v_o(mem_cmd_v)
  ,.mem_cmd_yumi_i(mem_cmd_yumi)

  ,.mem_resp_o()
  ,.mem_resp_v_o()
  ,.mem_resp_yumi_i('0)
);

// DRAM
bp_mem
#(.bp_params_p(bp_params_p)
  ,.mem_cap_in_bytes_p(mem_cap_in_bytes_p)
  ,.mem_zero_p(mem_zero_p)
  ,.mem_load_p(mem_load_p)
  ,.mem_file_p(mem_file_p)
  ,.mem_offset_p(mem_offset_p)

  ,.use_max_latency_p(use_max_latency_p)
  ,.use_random_latency_p(use_random_latency_p)
  ,.use_dramsim2_latency_p(use_dramsim2_latency_p)
  ,.max_latency_p(max_latency_p)

  ,.dram_clock_period_in_ps_p(dram_clock_period_in_ps_p)
  ,.dram_cfg_p(dram_cfg_p)
  ,.dram_sys_cfg_p(dram_sys_cfg_p)
  ,.dram_capacity_p(dram_capacity_p)
  )
mem
 (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.mem_cmd_i(mem_cmd)
  ,.mem_cmd_v_i(mem_cmd_v)
  ,.mem_cmd_yumi_o(mem_cmd_yumi)

  ,.mem_resp_o(mem_resp)
  ,.mem_resp_v_o(mem_resp_v)
  ,.mem_resp_ready_i(mem_resp_ready)
  );

// CFG loader
localparam cce_instr_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p);
bp_cce_mmio_cfg_loader
  #(.bp_params_p(bp_params_p)
    ,.inst_width_p(`bp_cce_inst_width)
    ,.inst_ram_addr_width_p(cce_instr_ram_addr_width_lp)
    ,.inst_ram_els_p(num_cce_instr_ram_els_p)
    ,.skip_ram_init_p(skip_init_p)
  )
  cfg_loader
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.io_cmd_o(cfg_io_cmd_lo)
   ,.io_cmd_v_o(cfg_io_cmd_v_lo)
   ,.io_cmd_yumi_i(cfg_io_cmd_yumi_li)
   
   ,.io_resp_i(cfg_io_resp_li)
   ,.io_resp_v_i(cfg_io_resp_v_li)
   ,.io_resp_ready_o(cfg_io_resp_ready_lo)
  );


// Program done info
localparam max_clock_cnt_lp    = 2**30-1;
localparam lg_max_clock_cnt_lp = `BSG_SAFE_CLOG2(max_clock_cnt_lp);
logic [lg_max_clock_cnt_lp-1:0] clock_cnt;

bsg_counter_clear_up
 #(.max_val_p(max_clock_cnt_lp)
   ,.init_val_p(0)
   )
 clock_counter
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.clear_i(reset_i)
   ,.up_i(1'b1)

   ,.count_o(clock_cnt)
   );

always_ff @(negedge clk_i) begin
  if (tr_done_lo) begin
    $display("Bytes: %d Clocks: %d mBPC: %d "
             , instr_count*64
             , clock_cnt
             , (instr_count*64*1000) / clock_cnt
             );
    $display("Test PASSed");
    $finish(0);
  end
end



endmodule : testbench

