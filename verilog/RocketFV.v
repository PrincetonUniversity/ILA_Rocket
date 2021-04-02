module RocketFV(input clock, input reset,
  input rvReset,
  //unconstrained control signals
  input io_interrupts_debug,
  input io_dmem_req_ready,
  input io_dmem_replay_next_rand,
  input io_imem_resp_bits_replay,
  input io_imem_resp_valid,
  input io_imem_resp_bits_btb_valid
  );

assume property (rvReset == 0);

//UN: reg io_interrupts_debug;
reg io_interrupts_mtip = 1'b0;
reg io_interrupts_msip = 1'b0;
reg io_interrupts_meip = 1'b0;


// *** DMEM control outside
//UN: reg io_dmem_req_ready;
//UN: reg io_dmem_replay_next_rand; // --> reg --> io_dmem_resp_replay ( io_dmem_resp_valid )
//wire io_dmem_s2_nack_rand;     // ready to kill at any time
//wire io_dmem_ordered; // assume always 1 when io_dmem_req_valid == 1

//UN: reg io_imem_resp_bits_replay;
//UN: reg io_imem_resp_valid;

// *** END DMEM control outside

// *** DMEM Remaining interface
wire          io_dmem_req_valid;
wire [31:0]   io_dmem_req_bits_addr;
wire [4:0]    io_dmem_req_bits_cmd;
wire [2:0]    io_dmem_req_bits_typ;
wire [31:0]   io_dmem_req_bits_data;
wire [6:0]    io_dmem_req_bits_tag;
wire [31:0]   io_dmem_s1_data; // this is the true write data!

wire          io_dmem_s1_kill;
wire          io_dmem_s2_nack; // From sharedMem -> cpu
wire          io_dmem_replay_next; 
wire          io_dmem_resp_valid;
wire          io_dmem_resp_bits_replay; // they should be the same

wire  [31:0]  io_dmem_resp_bits_addr;
wire  [6:0]   io_dmem_resp_bits_tag;
wire  [4:0]   io_dmem_resp_bits_cmd;
wire  [2:0]   io_dmem_resp_bits_typ;
wire  [31:0]  io_dmem_resp_bits_data;
wire          io_dmem_resp_bits_has_data;
wire  [31:0]  io_dmem_resp_bits_data_word_bypass = io_dmem_resp_bits_data;


// *** IMEM Remaining interface

wire  io_imem_req_valid;
wire [31:0] io_imem_req_bits_pc;

wire  io_imem_resp_ready;
wire  [31:0] io_imem_resp_bits_pc;
wire  [31:0] io_imem_resp_bits_data;

// *** Initial Stimulus for Simulation ONLY

/*
reg [31:0] counter;

always @(posedge clock) begin
  if (reset)
    counter <= 0;
  else begin
    counter <= counter + 1;
  end
end

always @(*) begin
  if (counter == 1000)
    $finish;
end


always @(posedge clock) begin
  if (counter == 20)
    io_interrupts_debug <= 1'b1;
  else if(io_imem_req_valid)
    io_interrupts_debug <= 1'b0;
end

reg flag_0 = 0;
always @(posedge clock) begin
  if (reset)
    io_imem_resp_valid <= 1'b0;
  else if (counter == 40)
    io_imem_resp_valid <= 1'b1;
  else if(flag_0 == 1'b1) 
    io_imem_resp_valid <= $random;
  else if(io_imem_req_valid) begin
    io_imem_resp_valid <= 1'b0;
    flag_0 <= 1'b1;
  end
end
// *** Randomize
always @(posedge clock) begin
  if(reset) begin
    io_dmem_req_ready <= 1'b0;
    io_dmem_replay_next_rand <= 1'b0;
    io_imem_resp_bits_replay <= 1'b0;
  end
  else if(counter > 40) begin
    io_dmem_req_ready <= $random;
    io_dmem_replay_next_rand <= $random;
    io_imem_resp_bits_replay <= $random;
  end
end*/
// *** END of Randomize

// *** END Intial Stimulus



// Bisimulation Control !!!
reg ex_monitor=0;
reg mem_monitor=0;

reg inst_begin = 0;
reg inst_issued = 0;
reg inst_finished = 0;
reg inst_finished_delay = 0;
reg inst_finished_delay2= 0;
reg inst_finished_delay3= 0;

reg second_finished = 0;
wire this_inst_finished = inst_finished & ~second_finished;

wire inst_finish1d = inst_finished_delay & ~inst_finished_delay2;
wire inst_finish2d = inst_finished_delay2& ~inst_finished_delay3;

// GM signal out

wire [31:0] mem_raddr0;
wire [31:0] mem_raddr1;
wire [31:0] mem_raddr2;

wire  [31:0] mem_rdata0;
wire  [31:0] mem_rdata1;
wire  [31:0] mem_rdata2;

wire        mem_wen0;
wire [31:0] mem_waddr0;
wire [31:0] mem_wdata0;
wire        GM_step;

// GM registers
  // Output states
  wire [31:0] GM_x0;
  wire [31:0] GM_x1;
  wire [31:0] GM_x10;
  wire [31:0] GM_x11;
  wire [31:0] GM_x12;
  wire [31:0] GM_x13;
  wire [31:0] GM_x14;
  wire [31:0] GM_x15;
  wire [31:0] GM_x16;
  wire [31:0] GM_x17;
  wire [31:0] GM_x18;
  wire [31:0] GM_x19;
  wire [31:0] GM_x2;
  wire [31:0] GM_x20;
  wire [31:0] GM_x21;
  wire [31:0] GM_x22;
  wire [31:0] GM_x23;
  wire [31:0] GM_x24;
  wire [31:0] GM_x25;
  wire [31:0] GM_x26;
  wire [31:0] GM_x27;
  wire [31:0] GM_x28;
  wire [31:0] GM_x29;
  wire [31:0] GM_x3;
  wire [31:0] GM_x30;
  wire [31:0] GM_x31;
  wire [31:0] GM_x4;
  wire [31:0] GM_x5;
  wire [31:0] GM_x6;
  wire [31:0] GM_x7;
  wire [31:0] GM_x8;
  wire [31:0] GM_x9;
  wire [31:0] GM_pc;

riscv GM(
  .clk(clock),
  .rst(reset),
  .step(GM_step),
      .x0(GM_x0),
      .x1(GM_x1),
      .x2(GM_x2),
      .x3(GM_x3),
      .x4(GM_x4),
      .x5(GM_x5),
      .x6(GM_x6),
      .x7(GM_x7),
      .x8(GM_x8),
      .x9(GM_x9),
      .x10(GM_x10),
      .x11(GM_x11),
      .x12(GM_x12),
      .x13(GM_x13),
      .x14(GM_x14),
      .x15(GM_x15),
      .x16(GM_x16),
      .x17(GM_x17),
      .x18(GM_x18),
      .x19(GM_x19),
      .x20(GM_x20),
      .x21(GM_x21),
      .x22(GM_x22),
      .x23(GM_x23),
      .x24(GM_x24),
      .x25(GM_x25),
      .x26(GM_x26),
      .x27(GM_x27),
      .x28(GM_x28),
      .x29(GM_x29),
      .x30(GM_x30),
      .x31(GM_x31),
      .pc (GM_pc),
  .mem_raddr0(mem_raddr0),
  .mem_raddr1(mem_raddr1),
  .mem_raddr2(mem_raddr2),

  .mem_rdata0(mem_rdata0),
  .mem_rdata1(mem_rdata1),
  .mem_rdata2(mem_rdata2),
  
  .mem_wen0(mem_wen0),
  .mem_waddr0(mem_waddr0),
  .mem_wdata0(mem_wdata0)
  

  );


  //wire [29:0] pc_word_addr;
  //wire [31:0] pc_mem_inst;
  wire        reg_mem_mismatch_nxt; // accessible at finish1d
  wire        load_not_ack_yet;
  wire        resp_a_non_monitored_req;
  wire        sm_GM_step;
  wire        sm_Assumpt_Time;
// *** Shared Memory
ShareMem sm(
    .clock(clock), .reset(reset),
    // *** DMEM Control outside
    .io_dmem_req_ready(io_dmem_req_ready), // whether to accept or not
    //input io_dmem_replay_next, // --> reg --> io_dmem_resp_replay ( io_dmem_resp_valid )
    .io_dmem_replay_next_rand(io_dmem_replay_next_rand),   // can be 1 at any time (but only once , at the output)

    // *** IMEM Control outside
    .io_imem_resp_bits_replay(io_imem_resp_bits_replay),
    .io_imem_resp_valid(io_imem_resp_valid), // you can keep valid and give more data than needed, untill the next cycle of a new valid request

    // *** DMEM Interface 
        // -- req
    .io_dmem_s1_kill(io_dmem_s1_kill),
    .io_dmem_req_valid(io_dmem_req_valid),
    .io_dmem_req_bits_addr(io_dmem_req_bits_addr),
    .io_dmem_req_bits_tag(io_dmem_req_bits_tag),
    .io_dmem_req_bits_cmd(io_dmem_req_bits_cmd),
    .io_dmem_req_bits_typ(io_dmem_req_bits_typ),
    .io_dmem_req_bits_data(io_dmem_req_bits_data),
    .io_dmem_s1_data(io_dmem_s1_data),
        // -- resp
    .io_dmem_resp_bits_addr(io_dmem_resp_bits_addr),
    .io_dmem_resp_bits_tag(io_dmem_resp_bits_tag),
    .io_dmem_resp_bits_cmd(io_dmem_resp_bits_cmd),
    .io_dmem_resp_bits_typ(io_dmem_resp_bits_typ),
    .io_dmem_resp_bits_data(io_dmem_resp_bits_data),
    .io_dmem_resp_bits_has_data(io_dmem_resp_bits_has_data),

    .io_dmem_s2_nack(io_dmem_s2_nack),
    .io_dmem_replay_next(io_dmem_replay_next),
    .io_dmem_resp_valid(io_dmem_resp_valid),
    .io_dmem_resp_bits_replay(io_dmem_resp_bits_replay),
    .io_dmem_ordered(io_dmem_ordered),// 

    // *** IMEM Interface
    .io_imem_req_valid(io_imem_req_valid),
    .io_imem_req_bits_pc(io_imem_req_bits_pc),

    .io_imem_resp_ready(io_imem_resp_ready),
    .io_imem_resp_bits_pc(io_imem_resp_bits_pc),
    .io_imem_resp_bits_data(io_imem_resp_bits_data),

    // *** Control Interface
    .reg_mem_mismatch_nxt(reg_mem_mismatch_nxt),

    // *** ILA Vlg Interface

    .mem_raddr0(mem_raddr0),
    .mem_raddr1(mem_raddr1),
    .mem_raddr2(mem_raddr2),

    .mem_rdata0(mem_rdata0),
    .mem_rdata1(mem_rdata1),
    .mem_rdata2(mem_rdata2),

    .mem_wen0(mem_wen0),
    .mem_waddr0(mem_waddr0),
    .mem_wdata0(mem_wdata0),

    // *** mem fetch assertion
    //.pc_word_addr(pc_word_addr),
    //.pc_mem_inst(pc_mem_inst),

    // kill unrelated memory operation
    .ex_monitor(ex_monitor),
    .load_not_ack_yet(load_not_ack_yet),
    .resp_a_non_monitored_req(resp_a_non_monitored_req),

    .GM_step(sm_GM_step),
    .Assumpt_Time(sm_Assumpt_Time)
     );


// IMPL signal out
  wire [31:0] IMPL_ibuf_io_pc_o;
  wire [31:0] IMPL_wb_reg_pc_o;
  wire [31:0] first_valid_pc;
  wire IMPL_ctrl_killd_o;
  wire IMPL_ctrl_killx_o;
  wire IMPL_ctrl_killm_o;
  wire IMPL_wb_reg_valid_o;

  // Ibuf inst
  wire [31:0] IMPL_ibuf_io_inst_0_bits_inst_bits_o;
  wire        IMPL_ibuf_io_inst_0_valid_o;
  wire        IMPL_ex_reg_valid_o;
  wire        IMPL_mem_reg_valid_o;
  wire        IMPL_wb_valid_o;
  wire [31:0] IMPL_wb_reg_inst_o;


  wire IMPL_id_rs_0_in_use;
  wire IMPL_id_rs_1_in_use;
  wire [31:0] IMPL_ex_rs_0_o;
  wire [31:0] IMPL_ex_rs_1_o;

  wire no_first_valid_pc;

  //rf IDX
  wire [4:0]  rf_idx_i;
  wire [31:0] rf_idx_o;

// Output states
  wire [31:0] IMPL_x0;
  wire [31:0] IMPL_x1;
  wire [31:0] IMPL_x10;
  wire [31:0] IMPL_x11;
  wire [31:0] IMPL_x12;
  wire [31:0] IMPL_x13;
  wire [31:0] IMPL_x14;
  wire [31:0] IMPL_x15;
  wire [31:0] IMPL_x16;
  wire [31:0] IMPL_x17;
  wire [31:0] IMPL_x18;
  wire [31:0] IMPL_x19;
  wire [31:0] IMPL_x2;
  wire [31:0] IMPL_x20;
  wire [31:0] IMPL_x21;
  wire [31:0] IMPL_x22;
  wire [31:0] IMPL_x23;
  wire [31:0] IMPL_x24;
  wire [31:0] IMPL_x25;
  wire [31:0] IMPL_x26;
  wire [31:0] IMPL_x27;
  wire [31:0] IMPL_x28;
  wire [31:0] IMPL_x29;
  wire [31:0] IMPL_x3;
  wire [31:0] IMPL_x30;
  wire [31:0] IMPL_x31;
  wire [31:0] IMPL_x4;
  wire [31:0] IMPL_x5;
  wire [31:0] IMPL_x6;
  wire [31:0] IMPL_x7;
  wire [31:0] IMPL_x8;
  wire [31:0] IMPL_x9;

Rocket dut(
    .clock(clock),
    .reset(rvReset),
    
    .io_interrupts_debug(io_interrupts_debug), // not always ?!
    .io_interrupts_mtip(io_interrupts_mtip),
    .io_interrupts_msip(io_interrupts_msip),
    .io_interrupts_meip(io_interrupts_meip),
    .io_hartid(32'd0),


      .io_imem_req_valid(io_imem_req_valid),
      .io_imem_req_bits_pc(io_imem_req_bits_pc),
      .io_imem_req_bits_speculative(), // not really useful

      .io_imem_resp_valid(io_imem_resp_valid),  // IMEM Control
      .io_imem_resp_bits_replay(io_imem_resp_bits_replay), // if it is 1, then replay previous request ( should Finally be 0)
                  // ^---IMEM control

      .io_imem_resp_ready(io_imem_resp_ready),  // from cpu to mem, 
      .io_imem_resp_bits_pc(io_imem_resp_bits_pc),
      .io_imem_resp_bits_data(io_imem_resp_bits_data),
      .io_imem_resp_bits_mask(2'b11),
      .io_imem_resp_bits_xcpt_if(1'b0), // determine page fault?
      
      .io_imem_resp_bits_btb_valid(io_imem_resp_bits_btb_valid),
      .io_imem_resp_bits_btb_bits_taken(),
      .io_imem_resp_bits_btb_bits_mask(),
      .io_imem_resp_bits_btb_bits_bridx(),
      .io_imem_resp_bits_btb_bits_target(),
      .io_imem_resp_bits_btb_bits_entry(),
      .io_imem_resp_bits_btb_bits_bht_history(),
      .io_imem_resp_bits_btb_bits_bht_value(),

      .io_imem_npc(), // NC inside

    
    .io_dmem_req_ready(io_dmem_req_ready),      // DMEM OUT CONTROL
    .io_dmem_replay_next(io_dmem_replay_next),  // DMEM OUT CONTROL
    .io_dmem_resp_valid(io_dmem_resp_valid),    // DMEM OUT CONTROL
    .io_dmem_resp_bits_replay(io_dmem_resp_bits_replay), // DMEM OUT CONTROL


    .io_dmem_req_valid(io_dmem_req_valid),
    .io_dmem_req_bits_addr(io_dmem_req_bits_addr),
    .io_dmem_req_bits_cmd(io_dmem_req_bits_cmd),
    .io_dmem_req_bits_typ(io_dmem_req_bits_typ),
    .io_dmem_req_bits_data(io_dmem_req_bits_data),
    .io_dmem_req_bits_tag(io_dmem_req_bits_tag), // needs to save it, in order to replay
    .io_dmem_req_bits_phys(), // assume it should be 1'b0

    .io_dmem_s1_kill(io_dmem_s1_kill),
    .io_dmem_s2_nack(io_dmem_s2_nack),
    .io_dmem_s1_data(io_dmem_s1_data), // NC
    .io_dmem_ordered(io_dmem_ordered), // assume always 1 when io_dmem_req_valid == 1
    .io_dmem_xcpt_ma_ld(1'b0),
    .io_dmem_xcpt_ma_st(1'b0),
    .io_dmem_xcpt_pf_ld(1'b0),
    .io_dmem_xcpt_pf_st(1'b0),

    // dmem has no masks
    .io_dmem_resp_bits_addr(io_dmem_resp_bits_addr),
    .io_dmem_resp_bits_tag(io_dmem_resp_bits_tag),
    .io_dmem_resp_bits_cmd(io_dmem_resp_bits_cmd),
    .io_dmem_resp_bits_typ(io_dmem_resp_bits_typ),
    .io_dmem_resp_bits_data(io_dmem_resp_bits_data),
    .io_dmem_resp_bits_has_data(io_dmem_resp_bits_has_data),
    .io_dmem_resp_bits_data_word_bypass(io_dmem_resp_bits_data_word_bypass), // = io_dmem_resp_bits_data
    .io_dmem_resp_bits_store_data(), // don't care
    .io_dmem_invalidate_lr(),  // don't care

    .io_rocc_fpu_resp_ready(1'b0),
    .io_rocc_fpu_req_valid(1'b0),
    .io_rocc_autl_grant_bits_is_builtin_type(),
    .io_rocc_autl_grant_bits_client_xact_id(),
    .io_rocc_autl_grant_ready(1'b1),
    .io_rocc_autl_acquire_bits_is_builtin_type(1'b1),
    .io_rocc_autl_acquire_bits_client_xact_id(1'b0),
    .io_rocc_autl_acquire_valid(1'b0),
    .io_rocc_busy(1'b0),
    .io_rocc_interrupt(1'b0),
    .io_rocc_mem_invalidate_lr(1'b1),
    .io_rocc_mem_s1_kill(1'b0),
    .io_rocc_mem_req_valid(1'b0),
    .io_rocc_resp_valid(1'b0),
    .io_rocc_cmd_ready(1'b0),
    .io_fpu_cp_resp_valid(1'b0),
    .io_fpu_cp_resp_bits_data(33'd0),
    .io_fpu_fcsr_rdy(1'b1),
    .io_fpu_nack_mem(1'b0),
    .io_fpu_illegal_rm(1'b0),
    .io_fpu_fcsr_flags_valid(1'b0),
    .io_fpu_fcsr_flags_bits(5'd0),
    .io_fpu_toint_data(0),


    // Ibuf inst
      .ibuf_io_inst_0_bits_inst_bits_o(IMPL_ibuf_io_inst_0_bits_inst_bits_o),
      .ibuf_io_inst_0_valid_o(IMPL_ibuf_io_inst_0_valid_o),
      .ex_reg_valid_o(IMPL_ex_reg_valid_o),
      .mem_reg_valid_o(IMPL_mem_reg_valid_o),
      .wb_valid_o(IMPL_wb_valid_o),
      .wb_reg_valid_o(IMPL_wb_reg_valid_o),
      .wb_reg_inst_o(IMPL_wb_reg_inst_o),

      .ctrl_killd_o(IMPL_ctrl_killd_o),
      .ctrl_killx_o(IMPL_ctrl_killx_o),
      .ctrl_killm_o(IMPL_ctrl_killm_o),

    // PC
      .ibuf_io_pc_o(IMPL_ibuf_io_pc_o),
      .wb_reg_pc_o(IMPL_wb_reg_pc_o),
      .first_valid_pc(first_valid_pc),
      .no_first_valid_pc(no_first_valid_pc),

      .rf_idx_i(rf_idx_i),
      .rf_idx_o(rf_idx_o),

      .id_rs_0_in_use(IMPL_id_rs_0_in_use),
      .id_rs_1_in_use(IMPL_id_rs_1_in_use),

      .ex_rs_0_o(IMPL_ex_rs_0_o),
      .ex_rs_1_o(IMPL_ex_rs_1_o),
    // Output states
      .x0(IMPL_x0),
      .x1(IMPL_x1),
      .x2(IMPL_x2),
      .x3(IMPL_x3),
      .x4(IMPL_x4),
      .x5(IMPL_x5),
      .x6(IMPL_x6),
      .x7(IMPL_x7),
      .x8(IMPL_x8),
      .x9(IMPL_x9),
      .x10(IMPL_x10),
      .x11(IMPL_x11),
      .x12(IMPL_x12),
      .x13(IMPL_x13),
      .x14(IMPL_x14),
      .x15(IMPL_x15),
      .x16(IMPL_x16),
      .x17(IMPL_x17),
      .x18(IMPL_x18),
      .x19(IMPL_x19),
      .x20(IMPL_x20),
      .x21(IMPL_x21),
      .x22(IMPL_x22),
      .x23(IMPL_x23),
      .x24(IMPL_x24),
      .x25(IMPL_x25),
      .x26(IMPL_x26),
      .x27(IMPL_x27),
      .x28(IMPL_x28),
      .x29(IMPL_x29),
      .x30(IMPL_x30),
      .x31(IMPL_x31)


    );

reg[15:0] enough_cnt = 0;
always @(posedge clock) begin 
  if(reset)
    enough_cnt <= 0;
  else if(IMPL_wb_valid_o == 1'b1 && enough_cnt < 16'd65535)
    enough_cnt <= enough_cnt + 1'b1;
end

wire nondetStart;
wire inst_begin_cond = ~inst_begin & nondetStart & ~inst_issued;
assign nondetStart = IMPL_ibuf_io_inst_0_valid_o & ~ IMPL_ctrl_killd_o & (enough_cnt == 16'd5) ;
//assume property (~nondetStart | (IMPL_ibuf_io_inst_0_valid_o & ~ IMPL_ctrl_killd_o & (enough_cnt > 16'd10) ) );

//wire inst_begin_cond = ~inst_begin & IMPL_ibuf_io_inst_0_valid_o & ~inst_issued;
// only for simulation
/*
reg [31:0] begin_cnt = 0;
always @(posedge clock) begin
  if(inst_begin_cond)
    begin_cnt <= begin_cnt + 1;
end*/
// END only for simulation

reg inst_has_begun = 0;
always @(posedge clock) begin
  if(reset)
    inst_has_begun <= 1'b0;
  else if(inst_begin_cond)
    inst_has_begun <= 1'b1;
end

always @(posedge clock) begin
  if(reset)
    inst_begin <= 1'b0;
  else if(inst_begin_cond ) //if( inst_begin_cond  )
    inst_begin <= 1'b1;
  else if( inst_begin & IMPL_ex_reg_valid_o)
    inst_begin <= 1'b0;
end

always @(posedge clock) begin
  if(reset)
    inst_issued <= 1'b0;
  else if( inst_begin & IMPL_ex_reg_valid_o )
    inst_issued <= 1'b1;
end

always @(posedge clock) begin
  if(reset) 
    ex_monitor <= 1'b0;
  else if(inst_begin & IMPL_ex_reg_valid_o & ~IMPL_ctrl_killx_o)
    ex_monitor <= 1'b1;
  else if(ex_monitor & IMPL_mem_reg_valid_o)
    ex_monitor <= 1'b0;
  else if(IMPL_ctrl_killx_o)
    ex_monitor <= 1'b0;
end

always @(posedge clock) begin
  if(reset)
    mem_monitor <= 1'b0;
  else if(ex_monitor & IMPL_mem_reg_valid_o & ~IMPL_ctrl_killm_o)
    mem_monitor <= 1'b1;
  else if(mem_monitor & IMPL_wb_valid_o)
    mem_monitor <= 1'b0;
  else if(IMPL_ctrl_killm_o)
    mem_monitor <= 1'b0;
end

always @(posedge clock) begin
  if(reset) begin 
    inst_finished <= 1'b0;
    inst_finished_delay <= 1'b0;
    inst_finished_delay2 <= 1'b0;
    inst_finished_delay3 <= 1'b0;
  end
  else begin
    inst_finished_delay <= inst_finished;
    inst_finished_delay2 <= inst_finished_delay;
    inst_finished_delay3 <= inst_finished_delay2;
    if(mem_monitor & IMPL_wb_valid_o)
      inst_finished <= 1'b1;
  end
end


wire before_next_inst_commited = this_inst_finished & (IMPL_wb_valid_o);
always @(posedge clock) begin 
  if(reset)
    second_finished <= 1'b0;
  else if(before_next_inst_commited)
    second_finished <= 1'b1;
end

// *** Assumptions
// --  GPR Assumptions
wire inst_gpr_assert_cond = mem_monitor & IMPL_wb_valid_o;

    assume property (~( inst_gpr_assert_cond ) | (IMPL_x0 == GM_x0) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x1 == GM_x1) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x2 == GM_x2) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x3 == GM_x3) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x4 == GM_x4) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x5 == GM_x5) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x6 == GM_x6) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x7 == GM_x7) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x8 == GM_x8) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x9 == GM_x9) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x10 == GM_x10) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x11 == GM_x11) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x12 == GM_x12) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x13 == GM_x13) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x14 == GM_x14) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x15 == GM_x15) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x16 == GM_x16) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x17 == GM_x17) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x18 == GM_x18) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x19 == GM_x19) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x20 == GM_x20) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x21 == GM_x21) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x22 == GM_x22) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x23 == GM_x23) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x24 == GM_x24) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x25 == GM_x25) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x26 == GM_x26) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x27 == GM_x27) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x28 == GM_x28) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x29 == GM_x29) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x30 == GM_x30) );
    assume property (~( inst_gpr_assert_cond ) | (IMPL_x31 == GM_x31) );

// --  PC Assumption
    assume property (~( inst_begin_cond ) | (IMPL_ibuf_io_pc_o == GM_pc) );

// --  Memory fetch assumption:
    //assign pc_word_addr = IMPL_ibuf_io_pc_o[31:2];
    reg [31:0] instruction_interested;
    always @(posedge clock) begin 
        if(inst_begin_cond)
            instruction_interested <= IMPL_ibuf_io_inst_0_bits_inst_bits_o;
    end

    assume property ( ~ (GM_step) | (instruction_interested == mem_rdata0 ) );

    //assume property (~( IMPL_ibuf_io_inst_0_valid_o ) | (pc_mem_inst == IMPL_ibuf_io_inst_0_bits_inst_bits_o) ); // inst_begin_cond

// assumption that bypassing network is working correctly
   reg[31:0] id_rs_0_reg;
   reg[4:0]  id_rs_0_field;
   reg[31:0] id_rs_1_reg;
   reg[4:0]  id_rs_1_field;

   reg       id_rs_0_in_use;
   reg       id_rs_1_in_use;

   always @(posedge clock) begin 
    if(reset) begin 
      id_rs_0_in_use <= 1'b0;
      id_rs_1_in_use <= 1'b0;
      id_rs_0_field  <= 5'd0;
      id_rs_1_field  <= 5'd0;
    end
    else begin 
      if(inst_begin_cond) begin 
        id_rs_0_in_use <= IMPL_id_rs_0_in_use;
        id_rs_1_in_use <= IMPL_id_rs_1_in_use;
        id_rs_0_field <= IMPL_ibuf_io_inst_0_bits_inst_bits_o[19:15];
        id_rs_1_field <= IMPL_ibuf_io_inst_0_bits_inst_bits_o[24:20];
      end
    end
   end

   always @(posedge clock) begin 
    if(inst_begin & IMPL_ex_reg_valid_o & ~IMPL_ctrl_killx_o ) begin 
      id_rs_0_reg <= IMPL_ex_rs_0_o;
      id_rs_1_reg <= IMPL_ex_rs_1_o;
    end
   end

   // @ inst_begin_cond load
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd0 ) || (IMPL_x0 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd1 ) || (IMPL_x1 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd2 ) || (IMPL_x2 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd3 ) || (IMPL_x3 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd4 ) || (IMPL_x4 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd5 ) || (IMPL_x5 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd6 ) || (IMPL_x6 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd7 ) || (IMPL_x7 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd8 ) || (IMPL_x8 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd9 ) || (IMPL_x9 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd10 ) || (IMPL_x10 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd11 ) || (IMPL_x11 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd12 ) || (IMPL_x12 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd13 ) || (IMPL_x13 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd14 ) || (IMPL_x14 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd15 ) || (IMPL_x15 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd16 ) || (IMPL_x16 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd17 ) || (IMPL_x17 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd18 ) || (IMPL_x18 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd19 ) || (IMPL_x19 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd20 ) || (IMPL_x20 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd21 ) || (IMPL_x21 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd22 ) || (IMPL_x22 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd23 ) || (IMPL_x23 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd24 ) || (IMPL_x24 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd25 ) || (IMPL_x25 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd26 ) || (IMPL_x26 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd27 ) || (IMPL_x27 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd28 ) || (IMPL_x28 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd29 ) || (IMPL_x29 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd30 ) || (IMPL_x30 == id_rs_0_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_0_in_use == 1'b1 && id_rs_0_field == 5'd31 ) || (IMPL_x31 == id_rs_0_reg ) ) );


     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd0  ) || (IMPL_x0  == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd1  ) || (IMPL_x1  == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd2  ) || (IMPL_x2  == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd3  ) || (IMPL_x3  == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd4  ) || (IMPL_x4  == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd5  ) || (IMPL_x5  == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd6  ) || (IMPL_x6  == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd7  ) || (IMPL_x7  == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd8  ) || (IMPL_x8  == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd9  ) || (IMPL_x9  == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd10 ) || (IMPL_x10 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd11 ) || (IMPL_x11 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd12 ) || (IMPL_x12 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd13 ) || (IMPL_x13 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd14 ) || (IMPL_x14 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd15 ) || (IMPL_x15 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd16 ) || (IMPL_x16 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd17 ) || (IMPL_x17 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd18 ) || (IMPL_x18 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd19 ) || (IMPL_x19 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd20 ) || (IMPL_x20 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd21 ) || (IMPL_x21 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd22 ) || (IMPL_x22 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd23 ) || (IMPL_x23 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd24 ) || (IMPL_x24 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd25 ) || (IMPL_x25 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd26 ) || (IMPL_x26 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd27 ) || (IMPL_x27 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd28 ) || (IMPL_x28 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd29 ) || (IMPL_x29 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd30 ) || (IMPL_x30 == id_rs_1_reg ) ) );
     assume property (~inst_gpr_assert_cond || ( ~( id_rs_1_in_use == 1'b1 && id_rs_1_field == 5'd31 ) || (IMPL_x31 == id_rs_1_reg ) ) );

   // @ inst_gpr_assert_cond assume they are the same



    assign  sm_GM_step = GM_step;
    assign  sm_Assumpt_Time = IMPL_ibuf_io_inst_0_valid_o;
// --  No interrupt assumption:
    wire isLB = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00000003;
    wire isLW = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00002003;
    wire isLH = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00001003;
    wire isLD = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00003003;
    wire isLBU = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00004003;
    wire isLHU = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00005003;
    wire isLWU = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00006003;
    wire isSB = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00000023;
    wire isSH = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00001023;
    wire isSW = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00002023;
    wire isSD = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00003023;
    wire isBEQ = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00000063;
    wire isBNE = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00001063;
    wire isBLT = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00004063;
    wire isBGE = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00005063;
    wire isBLTU = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00006063;
    wire isBGEU = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00007063;
    wire isJAL = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000007f) == 32'h0000006f;
    wire isJALR = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00000067;
    wire isLUI = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000007f) == 32'h00000037;
    wire isAUIPC = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000007f) == 32'h00000017;
    wire isADDI = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00000013;
    wire isSLTI = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00002013;
    wire isSLTIU = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00003013;
    wire isXORI = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00004013;
    wire isORI = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00006013;
    wire isANDI = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00007013;
    wire isSRLI = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hfe00707f) == 32'h00005013;
    wire isSRAI = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hfe00707f) == 32'h40005013;
    wire isSLLI = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hfe00707f) == 32'h00001013;
    wire isADD = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hfe00707f) == 32'h00000033;
    wire isSUB = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hfe00707f) == 32'h40000033;
    wire isSLL = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hfe00707f) == 32'h00001033;
    wire isSLT = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hfe00707f) == 32'h00002033;
    wire isSLTU = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hfe00707f) == 32'h00003033;
    wire isXOR = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hfe00707f) == 32'h00004033;
    wire isSRL = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hfe00707f) == 32'h00005033;
    wire isSRA = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hfe00707f) == 32'h40005033;
    wire isOR = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hfe00707f) == 32'h00006033;
    wire isAND = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hfe00707f) == 32'h00007033;
    wire isCSRRW = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00001073;
    wire isCSRRS = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00002073;
    wire isCSRRC = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00003073;
    wire isCSRRWI = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00005073;
    wire isCSRRSI = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00006073;
    wire isCSRRCI = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'h0000707f) == 32'h00007073;
    wire isECALL = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hffffffff) == 32'h00000073;
    wire isEBREAK = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hffffffff) == 32'h00100073;
    wire isSRET = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hffffffff) == 32'h10200073;
    wire isMRET = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hffffffff) == 32'h30200073;
    wire isSFENCE_VM = (IMPL_ibuf_io_inst_0_bits_inst_bits_o & 32'hfff07fff) == 32'h10400073;


    wire WBisLB = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00000003;
    wire WBisLW = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00002003;
    wire WBisLH = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00001003;
    wire WBisLD = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00003003;
    wire WBisLBU = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00004003;
    wire WBisLHU = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00005003;
    wire WBisLWU = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00006003;
    wire WBisSB = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00000023;
    wire WBisSH = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00001023;
    wire WBisSW = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00002023;
    wire WBisSD = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00003023;
    wire WBisBEQ = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00000063;
    wire WBisBNE = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00001063;
    wire WBisBLT = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00004063;
    wire WBisBGE = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00005063;
    wire WBisBLTU = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00006063;
    wire WBisBGEU = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00007063;
    wire WBisJAL = (IMPL_wb_reg_inst_o & 32'h0000007f) == 32'h0000006f;
    wire WBisJALR = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00000067;
    wire WBisLUI = (IMPL_wb_reg_inst_o & 32'h0000007f) == 32'h00000037;
    wire WBisAUIPC = (IMPL_wb_reg_inst_o & 32'h0000007f) == 32'h00000017;
    wire WBisADDI = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00000013;
    wire WBisSLTI = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00002013;
    wire WBisSLTIU = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00003013;
    wire WBisXORI = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00004013;
    wire WBisORI = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00006013;
    wire WBisANDI = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00007013;
    wire WBisSRLI = (IMPL_wb_reg_inst_o & 32'hfe00707f) == 32'h00005013;
    wire WBisSRAI = (IMPL_wb_reg_inst_o & 32'hfe00707f) == 32'h40005013;
    wire WBisSLLI = (IMPL_wb_reg_inst_o & 32'hfe00707f) == 32'h00001013;
    wire WBisADD = (IMPL_wb_reg_inst_o & 32'hfe00707f) == 32'h00000033;
    wire WBisSUB = (IMPL_wb_reg_inst_o & 32'hfe00707f) == 32'h40000033;
    wire WBisSLL = (IMPL_wb_reg_inst_o & 32'hfe00707f) == 32'h00001033;
    wire WBisSLT = (IMPL_wb_reg_inst_o & 32'hfe00707f) == 32'h00002033;
    wire WBisSLTU = (IMPL_wb_reg_inst_o & 32'hfe00707f) == 32'h00003033;
    wire WBisXOR = (IMPL_wb_reg_inst_o & 32'hfe00707f) == 32'h00004033;
    wire WBisSRL = (IMPL_wb_reg_inst_o & 32'hfe00707f) == 32'h00005033;
    wire WBisSRA = (IMPL_wb_reg_inst_o & 32'hfe00707f) == 32'h40005033;
    wire WBisOR = (IMPL_wb_reg_inst_o & 32'hfe00707f) == 32'h00006033;
    wire WBisAND = (IMPL_wb_reg_inst_o & 32'hfe00707f) == 32'h00007033;
    wire WBisCSRRW = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00001073;
    wire WBisCSRRS = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00002073;
    wire WBisCSRRC = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00003073;
    wire WBisCSRRWI = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00005073;
    wire WBisCSRRSI = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00006073;
    wire WBisCSRRCI = (IMPL_wb_reg_inst_o & 32'h0000707f) == 32'h00007073;
    wire WBisECALL = (IMPL_wb_reg_inst_o & 32'hffffffff) == 32'h00000073;
    wire WBisEBREAK = (IMPL_wb_reg_inst_o & 32'hffffffff) == 32'h00100073;
    wire WBisSRET = (IMPL_wb_reg_inst_o & 32'hffffffff) == 32'h10200073;
    wire WBisMRET = (IMPL_wb_reg_inst_o & 32'hffffffff) == 32'h30200073;
    wire WBisSFENCE_VM = (IMPL_wb_reg_inst_o & 32'hfff07fff) == 32'h10400073;


    //wire isBranch = isBEQ | isBNE | isBGEU | isBGE | isBLT | isBLTU;
    wire DECODE_isLoad = isLW | isLB | isLBU | isLH | isLHU;
    wire WBisBranch = WBisBEQ | WBisBNE | WBisBGEU | WBisBGE | WBisBLT | WBisBLTU;
    wire DECODE_validInstructions = 
      isSB | isSH | isSW | isLW | isLB | isLBU | isLH | isLHU |
       isBEQ | isBNE | isBLT | isBGE | isBLTU | isBGEU | isJAL | isJALR | 
      isLUI | isAUIPC | isADDI | isSLTI | isSLTIU | isXORI | isORI | isANDI | 
      isSRLI | isSRAI | isSLLI | isADD | isSUB | isSLL | isSLT | isSLTU | isXOR | 
      isSRL | isSRA | isOR | isAND ;
    wire WB_validInstructions = 
      WBisSB | WBisSH | WBisSW | WBisLW | WBisLB | WBisLBU | WBisLH | WBisLHU |
       WBisBEQ | WBisBNE | WBisBLT | WBisBGE | WBisBLTU | WBisBGEU | WBisJAL | WBisJALR | 
      WBisLUI | WBisAUIPC | WBisADDI | WBisSLTI | WBisSLTIU | WBisXORI | WBisORI | WBisANDI | 
      WBisSRLI | WBisSRAI | WBisSLLI | WBisADD | WBisSUB | WBisSLL | WBisSLT | WBisSLTU | WBisXOR | 
      WBisSRL | WBisSRA | WBisOR | WBisAND ;

      // | isCSRRW | isCSRRS | isCSRRC | isCSRRWI | 
      //isCSRRSI | isCSRRCI | isECALL | isEBREAK | isSRET | isMRET | isSFENCE.VM |


    wire[31:0] WBimmS = { { 20{IMPL_wb_reg_inst_o[31]} } , IMPL_wb_reg_inst_o[31:25], IMPL_wb_reg_inst_o[11:7] };
    wire[31:0] WBimmI = { { 20{IMPL_wb_reg_inst_o[31]} } , IMPL_wb_reg_inst_o[31:20] };
    wire[31:0] WBimmJ = { { 11{IMPL_wb_reg_inst_o[31]} } , IMPL_wb_reg_inst_o[31] , IMPL_wb_reg_inst_o[19:12] , IMPL_wb_reg_inst_o[20], IMPL_wb_reg_inst_o[30:21],1'b0 };
    wire[31:0] WBimmB = { { 19{IMPL_wb_reg_inst_o[31]} } , IMPL_wb_reg_inst_o[31], IMPL_wb_reg_inst_o[7], IMPL_wb_reg_inst_o[30:25], IMPL_wb_reg_inst_o[11:8], 1'b0 };
    assign rf_idx_i = IMPL_wb_reg_inst_o[19:15]; //rs1
    wire[1:0] loadAddr = rf_idx_o[1:0] + WBimmI[1:0];
    wire[1:0] storeAddr= rf_idx_o[1:0] + WBimmS[1:0];

    //a0
    wire CommitPointAll = IMPL_wb_valid_o;
    assume property (~CommitPointAll | (~WBisJAL  |(( IMPL_wb_reg_pc_o + WBimmJ ) & 2'b11) == 2'b00 ) );
    assume property (~CommitPointAll | (~WBisJALR |(( rf_idx_o + WBimmI )&2'b10) == 2'b00 ) );
    assume property (~CommitPointAll | (~WBisBranch | ((  IMPL_wb_reg_pc_o + WBimmB) & 2'b11) == 2'b00 ) );
    assume property (~CommitPointAll | (~WBisLH | (loadAddr[0] == 1'b0 ) ));
    assume property (~CommitPointAll | (~WBisLHU | (loadAddr[0] == 1'b0 ) ));
    assume property (~CommitPointAll | (~WBisLW | (loadAddr == 2'b00 ) ));

    assume property (~CommitPointAll | (~WBisSH | (storeAddr[0] == 1'b0 ) ));
    assume property (~CommitPointAll | (~WBisSW | (storeAddr == 2'b00 ) ));
    assume property (~CommitPointAll | (GM_x0 == 0) );
    assume property (~CommitPointAll | (GM_pc[1:0] == 2'b00) );
    assume property (GM_x0 == 0);
    

  // for verifying PC, if we don't limit interrupt, then the value after one instruction can be anything (not Btarget/Jtarget/PC+4 ...)
    assume property ( ~(inst_has_begun | inst_begin_cond) | (io_interrupts_debug == 1'b0) );
// -- Valid Instruction Decode Assumption
    
    // Let's just verify one instruction at a time
    // Do:
      assume property (~IMPL_ibuf_io_inst_0_valid_o |  DECODE_validInstructions ); //valid instructions : too tight for this :(isBEQ|isADD|isLW|isSW)    DECODE_validInstructions
      assume property ( ~inst_begin_cond | isAND ); // one instruction a time
    // Instead of:
    //assume property (~IMPL_ibuf_io_inst_0_valid_o | DECODE_validInstructions); //valid instruction
    assume property (~IMPL_wb_reg_valid_o | WB_validInstructions);

// *** Assertions
    wire justFinish = inst_finished & ~inst_finished_delay;

    // sequence monitor for handling LOAD 
    reg isInstLoad = 1'b0;
    reg delay_check = 1'b0;
    reg check_ready = 1'b0;
    reg check_ready_delay1 = 1'b0;
    wire delay_check_point = check_ready & ~check_ready_delay1;

    reg[4:0] inst_decode_rd;
    always @(posedge clock) begin 
      if(reset) begin
        isInstLoad <= 1'b0;
      end
      else if(inst_begin_cond) begin
        isInstLoad <= DECODE_isLoad;
        inst_decode_rd <= IMPL_ibuf_io_inst_0_bits_inst_bits_o[11:7];
      end
    end
    // 

    always @(posedge clock) begin 
      if(reset)
        delay_check <= 1'b0;
      else if(mem_monitor & IMPL_wb_valid_o & isInstLoad & (load_not_ack_yet & ~ (io_dmem_resp_valid & io_dmem_resp_bits_has_data ) )) 
        delay_check <= 1'b1;
      else if(delay_check & (io_dmem_resp_valid & io_dmem_resp_bits_has_data )  )
        delay_check <= 1'b0;
    end

    always @(posedge clock) begin 
      if(reset)
        check_ready <= 1'b0;
      else if( delay_check & (io_dmem_resp_valid & io_dmem_resp_bits_has_data )  ) 
        check_ready <= 1'b1;
    end

    always @(posedge clock) begin
      if(reset)
        check_ready_delay1 <= 1'b0;
      else
        check_ready_delay1 <= check_ready;
    end

// --  GPR Assertion
    assign GM_step = mem_monitor & IMPL_wb_valid_o;
    x0_nouse: assert property ( justFinish |-> (GM_x0 == IMPL_x0) );

    property x1_no_resp_overlap;
      (
        ~resp_a_non_monitored_req ##1
        ( justFinish & ( ~delay_check | (inst_decode_rd != 5'd1 )  ) )
      )  |-> (GM_x1 == IMPL_x1);
    endproperty

    reg[31:0] GM_origin_x1;
    always @(*) begin 
      if(inst_gpr_assert_cond)
        GM_origin_x1 <= GM_x1;
    end

    property x1_resp_overlap ;
      (
          (resp_a_non_monitored_req && (io_dmem_resp_bits_tag[5:1] == 5'd1) ) ##1
          (justFinish)
      )  |-> (GM_origin_x1 == GM_x1);
    endproperty

    property x1_load_delay;
      ( delay_check_point & (inst_decode_rd == 5'd1) ) |->  (GM_x1 == IMPL_x1) ;
    endproperty

    //assert property ( ( justFinish & ~resp_a_non_monitored_req & (~delay_check | (inst_decode_rd != 5'd1 )  ) ) |-> (GM_x1 == IMPL_x1) );
    //assert property ( ( justFinish & resp_a_non_monitored_req & (io_dmem_resp_bits_tag[5:1] == 5'd1)) |-> (GM_x1 == before_val_GM_x1) );
    //assert property ( ( delay_check_point & (inst_decode_rd == 5'd1) ) |->  (GM_x1 == IMPL_x1) );

    x1_nro: assert property (x1_no_resp_overlap);
    x1_ro:  assert property (x1_resp_overlap);
    x1_ld:  assert property (x1_load_delay);
/*
    assert property ( ~justFinish | (GM_x2 == IMPL_x2) );
    assert property ( ~justFinish | (GM_x3 == IMPL_x3) );
    assert property ( ~justFinish | (GM_x4 == IMPL_x4) );
    assert property ( ~justFinish | (GM_x5 == IMPL_x5) );
    assert property ( ~justFinish | (GM_x6 == IMPL_x6) );
    assert property ( ~justFinish | (GM_x7 == IMPL_x7) );
    assert property ( ~justFinish | (GM_x8 == IMPL_x8) );
    assert property ( ~justFinish | (GM_x9 == IMPL_x9) );
    assert property ( ~justFinish | (GM_x10 == IMPL_x10) );
    assert property ( ~justFinish | (GM_x11 == IMPL_x11) );
    assert property ( ~justFinish | (GM_x12 == IMPL_x12) );
    assert property ( ~justFinish | (GM_x13 == IMPL_x13) );
    assert property ( ~justFinish | (GM_x14 == IMPL_x14) );
    assert property ( ~justFinish | (GM_x15 == IMPL_x15) );
    assert property ( ~justFinish | (GM_x16 == IMPL_x16) );
    assert property ( ~justFinish | (GM_x17 == IMPL_x17) );
    assert property ( ~justFinish | (GM_x18 == IMPL_x18) );
    assert property ( ~justFinish | (GM_x19 == IMPL_x19) );
    assert property ( ~justFinish | (GM_x20 == IMPL_x20) );
    assert property ( ~justFinish | (GM_x21 == IMPL_x21) );
    assert property ( ~justFinish | (GM_x22 == IMPL_x22) );
    assert property ( ~justFinish | (GM_x23 == IMPL_x23) );
    assert property ( ~justFinish | (GM_x24 == IMPL_x24) );
    assert property ( ~justFinish | (GM_x25 == IMPL_x25) );
    assert property ( ~justFinish | (GM_x26 == IMPL_x26) );
    assert property ( ~justFinish | (GM_x27 == IMPL_x27) );
    assert property ( ~justFinish | (GM_x28 == IMPL_x28) );
    assert property ( ~justFinish | (GM_x29 == IMPL_x29) );
    assert property ( ~justFinish | (GM_x30 == IMPL_x30) );
    assert property ( ~justFinish | (GM_x31 == IMPL_x31) );
*/
// --  Harder Assertion: PC
    // wait till next pc
    //assert property 
    /*
    assert property ( (justFinish & ~no_first_valid_pc) |-> (first_valid_pc == GM_pc) );
    reg no_valid_pc_reg;
    always @(posedge clock) begin 
      if(reset)
        no_valid_pc_reg <= 1'b0;
      else if (justFinish & no_first_valid_pc)
        no_valid_pc_reg <= 1'b1;
      else if (no_valid_pc_reg & first_valid_pc )
        no_valid_pc_reg <= 1'b0;
    end

    assert property( (no_valid_pc_reg & first_valid_pc) |-> (first_valid_pc == GM_pc) );*/
    pc_a: assert property ( before_next_inst_commited |-> ( IMPL_wb_reg_pc_o == GM_pc)  );
    //cover property  (justFinish&no_first_valid_pc);
// --  Even Harder Assertion: Mem write (may not reply in time)
    mem_match: assert property ( inst_finish1d |->  ~reg_mem_mismatch_nxt );


endmodule
