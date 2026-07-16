// =============================================================================
// SVA Checker for rv32i_top — Features F1 through F24
// =============================================================================

module rv32i_top_checker (
    input wire clk,
    input wire reset,

    // IF stage
    input wire [31:0] pc_current,

    // IF/ID register outputs
    input wire [31:0] id_pc, id_instr,

    // ID/EX register outputs
    input wire        ex_RegWrite, ex_ALUSrc, ex_MemWrite, ex_MemRead, ex_MemToReg,
    input wire [3:0]  ex_ALUControl,
    input wire [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_imm_ext,
    input wire [4:0]  ex_rs1, ex_rs2, ex_rd,
    input wire        ex_branch,

    // EX/MEM register outputs
    input wire        mem_RegWrite, mem_MemWrite, mem_MemRead, mem_MemToReg,
    input wire [31:0] mem_alu_result, mem_rs2_data,
    input wire [4:0]  mem_rd,

    // MEM/WB register outputs
    input wire        wb_RegWrite, wb_MemToReg,
    input wire [31:0] wb_read_data, wb_alu_result,
    input wire [4:0]  wb_rd,

    // Hazard detection unit outputs
    input wire        PCWrite, IF_ID_Write, Control_Mux,
    // Hazard forwarding unit outputs
    input wire [1:0] forward_A, forward_B,
    input wire [31:0] ex_rs1_data_forwarded, ex_rs2_data_forwarded,
    // bonus
    input wire [31:0] wb_rd_data,
    input wire [31:0] id_imm_ext,
    // branch
    input wire branch_taken,
    input wire ex_zero
);

// ---------------------------------------------------------------------
// Shadow registers replacing $past() throughout this file. Xsim's
// support for $past appears incomplete in this environment (it broke
// assertion-region tracking for every property declared after the
// first usage, not just inside action blocks as we first suspected).
// Manually tracking "previous cycle" values with an ordinary
// always @(posedge clk) is functionally identical and universally
// supported by any tool, so we sidestep the issue entirely.
// ---------------------------------------------------------------------
reg [31:0] prev_pc_current, prev_id_pc, prev_id_instr, prev_ex_pc, prev_ex_imm_ext;
always @(posedge clk) begin
    prev_pc_current <= pc_current;
    prev_id_pc      <= id_pc;
    prev_id_instr   <= id_instr;
    prev_ex_pc      <= ex_pc;
    prev_ex_imm_ext <= ex_imm_ext;
end


// F1 — PC clears to 0 after reset.
property p_F1_pc_reset;
    @(posedge clk)
    reset |-> (pc_current == 32'h0000_0000);
endproperty
a_F1_pc_reset: assert property (p_F1_pc_reset)
    else $error("[F1] pc_current != 0 while reset asserted. Got 0x%08h", pc_current);



// F2 — Pipeline registers clear control fields to 0 after reset.

property p_F2_if_id_reset;
    @(posedge clk)
    reset |=> (id_pc == 32'h0000_0000 && id_instr == 32'h0000_0013);
endproperty
a_F2_if_id_reset: assert property (p_F2_if_id_reset)
    else $error("[F2] IF/ID did not clear to NOP after reset. id_pc=0x%08h id_instr=0x%08h",
                 id_pc, id_instr);

// ID/EX
property p_F2_id_ex_reset;
    @(posedge clk)
    reset |=> (
        ex_RegWrite    == 1'b0  && ex_ALUSrc    == 1'b0  && ex_MemWrite == 1'b0 &&
        ex_MemRead     == 1'b0  && ex_MemToReg  == 1'b0  && ex_ALUControl == 4'b0000 &&
        ex_pc          == 32'b0 && ex_rs1_data  == 32'b0 && ex_rs2_data == 32'b0 &&
        ex_imm_ext     == 32'b0 && ex_rs1       == 5'b0  && ex_rs2      == 5'b0 &&
        ex_rd          == 5'b0  && ex_branch    == 1'b0
    );
endproperty
a_F2_id_ex_reset: assert property (p_F2_id_ex_reset)
    else $error("[F2] ID/EX did not clear after reset.");

// EX/MEM
property p_F2_ex_mem_reset;
    @(posedge clk)
    reset |=> (
        mem_RegWrite   == 1'b0  && mem_MemWrite == 1'b0  && mem_MemRead == 1'b0 &&
        mem_MemToReg   == 1'b0  && mem_alu_result == 32'b0 && mem_rs2_data == 32'b0 &&
        mem_rd         == 5'b0
    );
endproperty
a_F2_ex_mem_reset: assert property (p_F2_ex_mem_reset)
    else $error("[F2] EX/MEM did not clear after reset.");

// MEM/WB
property p_F2_mem_wb_reset;
    @(posedge clk)
    reset |=> (
        wb_RegWrite    == 1'b0  && wb_MemToReg == 1'b0 &&
        wb_read_data   == 32'b0 && wb_alu_result == 32'b0 && wb_rd == 5'b0
    );
endproperty
a_F2_mem_wb_reset: assert property (p_F2_mem_wb_reset)
    else $error("[F2] MEM/WB did not clear after reset.");


// F3 — Register file x0-x31 clears to 0 on reset.

genvar gi;
generate
    for (gi = 0; gi < 32; gi = gi + 1) begin : f3_regfile_reset
        property p_F3_regfile_reset;
            @(posedge clk)
            reset |-> (rf_inst.reg_file[gi] == 32'h0000_0000);
        endproperty
        a_F3_regfile_reset: assert property (p_F3_regfile_reset)
            else $error("[F3] reg_file[%0d] != 0 while reset asserted. Got 0x%08h",
                         gi, rf_inst.reg_file[gi]);
    end
endgenerate


// F4 — hazard_detection_unit outputs return to default (no-stall) state

property p_F4_hazard_default_after_reset;
    @(posedge clk)
    reset |=> (PCWrite == 1'b1 && IF_ID_Write == 1'b1 && Control_Mux == 1'b0);
endproperty
a_F4_hazard_default_after_reset: assert property (p_F4_hazard_default_after_reset)
    else $error("[F4] hazard outputs not default one cycle after reset. PCWrite=%b IF_ID_Write=%b Control_Mux=%b",
                 PCWrite, IF_ID_Write, Control_Mux);


// F5 — Load-use stall on rs1: an EX-stage load whose rd matches the

property p_F5_stall_rs1;
    @(posedge clk) disable iff (reset)
    (ex_MemRead && (ex_rd != 5'b0) && (ex_rd == id_instr[19:15]))
    |->
    (PCWrite == 1'b0 && IF_ID_Write == 1'b0 && Control_Mux == 1'b1);
endproperty
a_F5_stall_rs1: assert property (p_F5_stall_rs1)
    else $error("[F5] load-use stall on rs1 did not occur. ex_rd=%0d id_rs1=%0d",
                 ex_rd, id_instr[19:15]);


// F6 — Load-use stall on rs2: same trigger shape as F5, but on rs2, and

property p_F6_stall_rs2;
    @(posedge clk) disable iff (reset)
    (ex_MemRead && (ex_rd != 5'b0) && (ex_rd == id_instr[24:20]) &&
     (id_instr[6:0] == 7'b0110011 ||   // R-type
      id_instr[6:0] == 7'b1100011 ||   // B-type
      id_instr[6:0] == 7'b0100011))    // S-type
    |->
    (PCWrite == 1'b0 && IF_ID_Write == 1'b0 && Control_Mux == 1'b1);
endproperty
a_F6_stall_rs2: assert property (p_F6_stall_rs2)
    else $error("[F6] load-use stall on rs2 did not occur. ex_rd=%0d id_rs2=%0d id_opcode=%b",
                 ex_rd, id_instr[24:20], id_instr[6:0]);

//F7 - no load-use stall on rs2 with I,L-type instructions
property p_F7_no_stall_rs2_iltype;
    @(posedge clk) disable iff (reset)
    (ex_MemRead && (ex_rd != 5'b0) && (ex_rd == id_instr[24:20]) &&
     (id_instr[6:0] == 7'b0010011 ||   // I-type
      id_instr[6:0] == 7'b0000011))    // L-type
    |->
    (PCWrite == 1'b1 && IF_ID_Write == 1'b1 && Control_Mux == 1'b0);
endproperty
a_F7_no_stall_rs2_iltype: assert property (p_F7_no_stall_rs2_iltype)
    else $error("[F7] load-use stall on rs2 occurred with I/L-type instruction. ex_rd=%0d id_rs2=%0d id_opcode=%b",
                 ex_rd, id_instr[24:20], id_instr[6:0]);

//F8 - no load-use stall with not stall.
property p_F8_no_stall;
    @(posedge clk) disable iff(reset)
    (ex_MemRead && (ex_rd != 5'b0) && (ex_rd != id_instr[19:15]) && (ex_rd != id_instr[24:20]))
    |->
    (PCWrite == 1'b1 && IF_ID_Write == 1'b1 && Control_Mux == 1'b0);
endproperty
a_F8_no_stall: assert property (p_F8_no_stall)
    else $error("[F8] unexpected load-use stall occurred. ex_rd=%0d id_rs1=%0d id_rs2=%0d",
                 ex_rd, id_instr[19:15], id_instr[24:20]);

//F9 - stall in one cycle, NOP in EX( next cycle)
property p_F9_bubble_lands_in_ex;
    @(posedge clk) disable iff (reset)
    Control_Mux
    |=>
    (ex_RegWrite   == 1'b0 && ex_MemWrite == 1'b0 && ex_MemRead == 1'b0 &&
     ex_MemToReg   == 1'b0 && ex_ALUControl == 4'b0000 && Control_Mux == 1'b0);
endproperty
a_F9_bubble_lands_in_ex: assert property (p_F9_bubble_lands_in_ex)
    else $error("[F9] no bubble in EX one cycle after stall and stall only one cycle. ex_RegWrite=%b ex_MemRead=%b ex_ALUControl=%b control_mux=%b",
                 ex_RegWrite, ex_MemRead, ex_ALUControl, Control_Mux);

//F10 - pc and instr are held in stall cycle
// (a) PC held while PCWrite is deasserted.
property p_F10a_pc_held;
    @(posedge clk) disable iff (reset)
    !PCWrite
    |=>
    (pc_current == prev_pc_current);
endproperty
a_F10a_pc_held: assert property (p_F10a_pc_held)
    else $error("[F10a] PC advanced during stall. pc_current=0x%08h", pc_current);

// (b) IF/ID instruction held while IF_ID_Write is deasserted.
property p_F10b_if_id_held;
    @(posedge clk) disable iff (reset)
    !IF_ID_Write
    |=>
    (id_pc == prev_id_pc && id_instr == prev_id_instr);
endproperty
a_F10b_if_id_held: assert property (p_F10b_if_id_held)
    else $error("[F10b] IF/ID advanced during stall. id_pc=0x%08h id_instr=0x%08h",
                 id_pc, id_instr);

//F11 - forwarding when rd = rs1 Mem stage
property p_F11_forwarding_rs1;
    @(posedge clk) disable iff (reset)
    (mem_RegWrite  && (mem_rd != 5'b0) && (mem_rd == ex_rs1))
    |->
    (forward_A == 2'b01);
endproperty
a_F11_forwarding_rs1: assert property (p_F11_forwarding_rs1)
    else $error("[F11] forwarding failed for rs1. forward_A=0x%02b mem_rd=0x%02b ex_rs1=0x%02b",
                 forward_A, mem_rd, ex_rs1);

//F12 - forwarding when rd = rs2 Mem stage
property p_F12_forwarding_rs2;
    @(posedge clk) disable iff (reset)
    (mem_RegWrite && (mem_rd != 5'b0) && (mem_rd == ex_rs2))
    |->
    (forward_B == 2'b01);
endproperty
a_F12_forwarding_rs2: assert property (p_F12_forwarding_rs2)
    else $error("[F12] forwarding failed for rs2. forward_B=0x%02b mem_rd=0x%02b ex_rs2=0x%02b",
                 forward_B, mem_rd, ex_rs2);
//F13 - forwarding when rd = rs1 or rs2 on WB stage without MEM stage
//F13a - forwarding when rd = rs1 on WB stage without MEM stage
property p_F13a_forwarding_wb_no_mem;
    @(posedge clk) disable iff (reset)
    (wb_RegWrite && !wb_MemToReg && (wb_rd != 5'b0) && ((wb_rd == ex_rs1))
    && !((mem_RegWrite && (mem_rd != 5'b0) && (mem_rd == ex_rs1))))
    |->
    ((forward_A == 2'b10));
endproperty
a_F13a_forwarding_wb_no_mem: assert property (p_F13a_forwarding_wb_no_mem)
    else $error("[F13a] forwarding failed for rs1 on WB stage without MEM stage. forward_A=0x%02b wb_rd=0x%02b ex_rs1=0x%02b",
                 forward_A, wb_rd, ex_rs1);
//F13b - forwarding when rd = rs2 on WB stage without MEM stage
property p_F13b_forwarding_wb_no_mem;
    @(posedge clk) disable iff (reset)
    (wb_RegWrite && (wb_rd != 5'b0) && ((wb_rd == ex_rs2))
    && !((mem_RegWrite && (mem_rd != 5'b0) && (mem_rd == ex_rs2))))
    |->
    ((forward_B == 2'b10));
endproperty
a_F13b_forwarding_wb_no_mem: assert property (p_F13b_forwarding_wb_no_mem)
    else $error("[F13b] forwarding failed for rs2 on WB stage without MEM stage. forward_B=0x%02b wb_rd=0x%02b ex_rs2=0x%02b",
                 forward_B, wb_rd, ex_rs2);

//F14 - forwarding when rd = rs1 or rs2 on WB stage with MEM stage
//F14a - forwarding when rd = rs1 on WB stage with MEM stage
property p_F14a_forwarding_wb_with_mem;
    @(posedge clk) disable iff (reset)
    (wb_RegWrite && (wb_rd != 5'b0) && ((wb_rd == ex_rs1))
    && ((mem_RegWrite && (mem_rd != 5'b0) && (mem_rd == ex_rs1))))
    |->
    ((forward_A == 2'b01));
endproperty
a_F14a_forwarding_wb_with_mem: assert property (p_F14a_forwarding_wb_with_mem)
    else $error("[F14a] forwarding failed for rs1 on WB stage with MEM stage. forward_A=0x%02b wb_rd=0x%02b ex_rs1=0x%02b mem_rd=0x%02b",
                 forward_A, wb_rd, ex_rs1, mem_rd);
//F14b - forwarding when rd = rs2 on WB stage with MEM stage
property p_F14b_forwarding_wb_with_mem;
    @(posedge clk) disable iff (reset)
    (wb_RegWrite && (wb_rd != 5'b0) && ((wb_rd == ex_rs2))
    && ((mem_RegWrite && (mem_rd != 5'b0) && (mem_rd == ex_rs2))))
    |->
    ((forward_B == 2'b01));
endproperty
a_F14b_forwarding_wb_with_mem: assert property (p_F14b_forwarding_wb_with_mem)
    else $error("[F14b] forwarding failed for rs2 on WB stage with MEM stage. forward_B=0x%02b wb_rd=0x%02b ex_rs2=0x%02b mem_rd=0x%02b",
                 forward_B, wb_rd, ex_rs2, mem_rd);

//F15 - no forwarding when rd = 0
property p_F15a_no_mem_forward_rs1_rd_zero;
    @(posedge clk) disable iff(reset)
    (mem_RegWrite && (mem_rd == 5'b0))
    |->
    (forward_A != 2'b01);
endproperty

// F15b: same, for rs2
property p_F15b_no_mem_forward_rs2_rd_zero;
    @(posedge clk) disable iff(reset)
    (mem_RegWrite && (mem_rd == 5'b0))
    |->
    (forward_B != 2'b01);
endproperty

// F15c: a WB-stage write to x0 must never be selected as rs1's forward source
property p_F15c_no_wb_forward_rs1_rd_zero;
    @(posedge clk) disable iff(reset)
    (wb_RegWrite && (wb_rd == 5'b0))
    |->
    (forward_A != 2'b10);
endproperty

// F15d: same, for rs2
property p_F15d_no_wb_forward_rs2_rd_zero;
    @(posedge clk) disable iff(reset)
    (wb_RegWrite && (wb_rd == 5'b0))
    |->
    (forward_B != 2'b10);
endproperty

//F16 - no forwarding when rd != rs1 and rd != rs2
//F16a - no forwarding when rd != rs1
property p_F16a_no_forwarding_rd_not_rs1;
    @(posedge clk) disable iff (reset)
    !((mem_RegWrite && (mem_rd != 5'b0) && (mem_rd == ex_rs1))) &&
    (wb_RegWrite && (wb_rd != 5'b0) && (wb_rd != ex_rs1))
    |->
    ((forward_A == 2'b00));
endproperty
a_F16a_no_forwarding_rd_not_rs1: assert property (p_F16a_no_forwarding_rd_not_rs1)
    else $error("[F16a] no forwarding when rd != rs1. forward_A=0x%02b mem_rd=0x%02b wb_rd=0x%02b ex_rs1=0x%02b",
                 forward_A, mem_rd, wb_rd, ex_rs1);

//F16b - no forwarding when rd != rs2
property p_F16b_no_forwarding_rd_not_rs2;
    @(posedge clk) disable iff (reset)
    !((mem_RegWrite && (mem_rd != 5'b0) && (mem_rd == ex_rs2))) &&
    (wb_RegWrite && (wb_rd != 5'b0) && (wb_rd != ex_rs2))
    |->
    ((forward_B == 2'b00));
endproperty
a_F16b_no_forwarding_rd_not_rs2: assert property (p_F16b_no_forwarding_rd_not_rs2)
    else $error("[F16b] no forwarding when rd != rs2. forward_B=0x%02b mem_rd=0x%02b wb_rd=0x%02b ex_rs2=0x%02b",
                 forward_B, mem_rd, wb_rd, ex_rs2);

//F17 - check data when forwarding occurs
//F17a - check data when forwarding occurs for rs1 at MEM stage only
property p_F17a_data_forwarding_rs1_mem;
    @(posedge clk) disable iff (reset)
    (mem_RegWrite && (mem_rd != 5'b0) && (mem_rd == ex_rs1)) &&
    !((wb_RegWrite && (wb_rd != 5'b0) && (wb_rd == ex_rs1)))
    |->
    (ex_rs1_data_forwarded == mem_alu_result);
endproperty
a_F17a_data_forwarding_rs1_mem: assert property (p_F17a_data_forwarding_rs1_mem)
    else $error("[F17a] data forwarding failed for rs1 at MEM stage. ex_rs1_data=0x%08h mem_alu_result=0x%08h",
                 ex_rs1_data_forwarded, mem_alu_result);

//F17b - check data when forwarding occurs for rs1 at WB stage only
property p_F17b_data_forwarding_rs1_wb;
    @(posedge clk) disable iff (reset)
    (wb_RegWrite && (wb_rd != 5'b0) && (wb_rd == ex_rs1)) &&
    !((mem_RegWrite && (mem_rd != 5'b0) && (mem_rd == ex_rs1)))
    |->
    (ex_rs1_data_forwarded == wb_rd_data);
endproperty
a_F17b_data_forwarding_rs1_wb: assert property (p_F17b_data_forwarding_rs1_wb)
    else $error("[F17b] data forwarding failed for rs1 at WB stage. ex_rs1_data=0x%08h wb_rd_data=0x%08h",
                 ex_rs1_data_forwarded, wb_rd_data);

//F17c - check data when no forwarding occurs for rs1
property p_F17c_data_no_forwarding_rs1;
    @(posedge clk) disable iff (reset)
    !((mem_RegWrite && (mem_rd != 5'b0) && (mem_rd == ex_rs1))) &&
    !((wb_RegWrite && (wb_rd != 5'b0) && (wb_rd == ex_rs1)))
    |->
    (ex_rs1_data_forwarded == ex_rs1_data);
endproperty
a_F17c_data_no_forwarding_rs1: assert property (p_F17c_data_no_forwarding_rs1)
    else $error("[F17c] data forwarding occurred for rs1 when it shouldn't have. ex_rs1_data=0x%08h ex_rs1_data_forwarded=0x%08h",
                 ex_rs1_data, ex_rs1_data_forwarded);
// --rs2 minor edits
//F17d - check data when forwarding occurs for rs2 at MEM stage only
property p_F17d_data_forwarding_rs2_mem;
    @(posedge clk) disable iff (reset)
    (mem_RegWrite && (mem_rd != 5'b0) && (mem_rd == ex_rs2)) &&
    !((wb_RegWrite && (wb_rd != 5'b0) && (wb_rd == ex_rs2)))
    |->
    (ex_rs2_data_forwarded == mem_alu_result);
endproperty
a_F17d_data_forwarding_rs2_mem: assert property (p_F17d_data_forwarding_rs2_mem)
    else $error("[F17d] data forwarding failed for rs2 at MEM stage. ex_rs2_data=0x%08h mem_alu_result=0x%08h",
                 ex_rs2_data_forwarded, mem_alu_result);
//F17e - check data when forwarding occurs for rs2 at WB stage only
property p_F17e_data_forwarding_rs2_wb;
    @(posedge clk) disable iff (reset)
    (wb_RegWrite && (wb_rd != 5'b0) && (wb_rd == ex_rs2)) &&
    !((mem_RegWrite && (mem_rd != 5'b0) && (mem_rd == ex_rs2)))
    |->
    (ex_rs2_data_forwarded == wb_rd_data);
endproperty
a_F17e_data_forwarding_rs2_wb: assert property (p_F17e_data_forwarding_rs2_wb)
    else $error("[F17e] data forwarding failed for rs2 at WB stage. ex_rs2_data=0x%08h wb_rd_data=0x%08h",
                 ex_rs2_data_forwarded, wb_rd_data);
//F17f - check data when no forwarding occurs for rs2
property p_F17f_data_no_forwarding_rs2;
    @(posedge clk) disable iff (reset)
    !((mem_RegWrite && (mem_rd != 5'b0) && (mem_rd == ex_rs2))) &&
    !((wb_RegWrite && (wb_rd != 5'b0) && (wb_rd == ex_rs2)))
    |->
    (ex_rs2_data_forwarded == ex_rs2_data);
endproperty
a_F17f_data_no_forwarding_rs2: assert property (p_F17f_data_no_forwarding_rs2)
    else $error("[F17f] data forwarding occurred for rs2 when it shouldn't have. ex_rs2_data=0x%08h ex_rs2_data_forwarded=0x%08h",
                 ex_rs2_data, ex_rs2_data_forwarded);


/////////-------- Branch


//F18 - ex_zero when branch taken
property p_F18_ex_zero_when_branch_taken;
    @(posedge clk) disable iff (reset)
    branch_taken
    |->
    (ex_zero == 1'b1);
endproperty
a_F18_ex_zero_when_branch_taken: assert property (p_F18_ex_zero_when_branch_taken)
    else $error("[F18] ex_zero not asserted when branch taken. ex_zero=%b branch_taken=%b",
                 ex_zero, branch_taken);

//F19 - NOP in the cycle after branch taken( then flush) must be NOP
//F19a - NOP in IF/ID
property p_F19a_nop_after_branch_taken;
    @(posedge clk) disable iff(reset)
    branch_taken
    |=>
    (id_pc == 32'b0 && id_instr == 32'h00000013);
endproperty
a_F19a_nop_after_branch_taken: assert property (p_F19a_nop_after_branch_taken)
    else $error("[F19a] there is no NOP in after cycle branch taken. id_pc=%02b id_instr=%08h branch_taken=%02b",
    id_pc, id_instr, branch_taken);
//F19b - NOP in ID/EX
property p_F19b_nop_after_branch_taken;
    @(posedge clk) disable iff(reset)
    branch_taken
    |=>
    (
        ex_RegWrite == 1'b0 && ex_ALUSrc==1'b0&& ex_MemWrite==1'b0&&
        ex_MemRead==1'b0 &&  ex_MemToReg ==1'b0 && ex_ALUControl == 4'b0 &&
        ex_pc == 32'b0 && ex_rs1_data == 32'b0 && ex_rs2_data == 32'b0 &&
        ex_imm_ext == 32'b0 && ex_rs1 == 5'b0 && ex_rs2 == 5'b0 &&
        ex_rd == 5'b0 && ex_branch == 1'b0
    );
endproperty
a_F19b_nop_after_branch_taken: assert property (p_F19b_nop_after_branch_taken)
    else $error("[F19b] there is no NOP in after cycle branch taken.");


//F20 - branch taken redirects PC with right value
property p_F20_branch_taken_redirect_pc;
    @(posedge clk) disable iff(reset)
    branch_taken
    |=>
    (pc_current == prev_ex_imm_ext + prev_ex_pc);
endproperty
a_F20_branch_taken_redirect_pc: assert property (p_F20_branch_taken_redirect_pc)
    else $error("[F20] branch taken redirect to wrong pc. pc_current=0x%08h",
    pc_current);


//F21 - not taken branch pc still pc = pc + 4
property p_F21_no_branch_taken_normal_pc;
    @(posedge clk) disable iff(reset)
    (!branch_taken && PCWrite)
    |=>
    (pc_current == prev_pc_current + 32'd4);
endproperty
a_F21_no_branch_taken_normal_pc: assert property (p_F21_no_branch_taken_normal_pc)
    else $error("[F21] no branch taken but with wrong pc in next cycle. pc_current=0x%0d prev_pc_current=0x%0d",
    pc_current, prev_pc_current);


//F22 - Branch immediate is correctly sign-extended and shaped per the B-type encoding in `imm_gen`
property p_F22_branch_imm_shape;
    @(posedge clk) disable iff (reset)
    (id_instr[6:0] == 7'b1100011)
    |->
    (id_imm_ext == { {19{id_instr[31]}}, id_instr[31], id_instr[7],
                      id_instr[30:25], id_instr[11:8], 1'b0 });
endproperty
a_F22_branch_imm_shape: assert property (p_F22_branch_imm_shape)
    else $error("[F22] B-type immediate incorrectly shaped. id_instr=0x%08h id_imm_ext=0x%08h",
                 id_instr, id_imm_ext);


////------------------CROSSSSSSS---------------

//F23 - no branch taken and stall in EX_stage
property p_F23_no_branch_taken_stall_one_cycle;
    @(posedge clk) disable iff(reset)
    !(Control_Mux && branch_taken);
endproperty
a_F23_no_branch_taken_stall_one_cycle: assert property(p_F23_no_branch_taken_stall_one_cycle)
    else $error("[F23] branch_taken and stall happend in the same stage. Control_Mux = %b branch_taken = %b",
    Control_Mux, branch_taken);

//F24 - double stall a.k.a back-to-back load use hazard
// sequece for first
sequence seq_double_stall;
    (Control_Mux) ##1
    !(Control_Mux) ##1
    (ex_MemRead && (ex_rd != 5'b0) && 
     ((ex_rd == id_instr[19:15]) ||
      (ex_rd == id_instr[24:20] &&
       (id_instr[6:0] == 7'b0110011 || id_instr[6:0] == 7'b1100011 || id_instr[6:0] == 7'b0100011))));
endsequence
//property
property p_F24_double_stall;
    @(posedge clk) disable iff(reset)
    seq_double_stall |-> Control_Mux;
endproperty
a_F24_double_stall: assert property (p_F24_double_stall)
    else $error("[F24] second load-use hazard following a resolved stall did not trigger its own stall.");







endmodule



// Attach the checker to every instance of rv32i_top — no RTL edit needed,
// no dependency on the testbench's chosen instance name (my_cpu, dut, etc).
bind rv32i_top rv32i_top_checker checker_inst (.*);