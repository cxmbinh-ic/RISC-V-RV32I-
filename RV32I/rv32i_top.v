module rv32i_top (
    input wire clk,
    input wire reset
);
    wire [31:0] pc_current, pc_next, instr;
    wire [31:0] id_pc, id_instr, id_rs1_data, id_rs2_data, id_imm_ext;
    wire        id_reg_write, id_alu_src, id_mem_write, id_mem_read, id_mem_to_reg, id_branch;
    wire [3:0]  id_alu_control;
    wire        PCWrite, IF_ID_Write, Control_Mux;
    wire        id_RegWrite_mux, id_MemWrite_mux, id_MemRead_mux, id_MemToReg_mux, id_ALUSrc_mux;
    wire [3:0]  id_ALUControl_mux;
    wire [1:0]  forward_A, forward_B;
    wire [31:0] ex_rs1_data_forwarded, ex_rs2_data_forwarded;
    wire [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_imm_ext;
    wire [4:0]  ex_rs1, ex_rs2, ex_rd;
    wire        branch_taken, ex_branch;
    wire [31:0] branch_taken_addr;
    wire        ex_RegWrite, ex_ALUSrc, ex_MemWrite, ex_MemRead, ex_MemToReg;
    wire [3:0]  ex_ALUControl;
    wire [31:0] ex_alu_src_b, ex_alu_result;
    wire        ex_zero;
    wire [31:0] mem_alu_result, mem_rs2_data, mem_read_data;
    wire [4:0]  mem_rd;
    wire        mem_RegWrite, mem_MemWrite, mem_MemRead, mem_MemToReg;
    wire [31:0] wb_read_data, wb_alu_result, wb_rd_data;
    wire [4:0]  wb_rd;
    wire        wb_RegWrite, wb_MemToReg;

    // IF Stage
    pc pc_inst (.clk(clk), .reset(reset), .en(PCWrite), .pc_in(pc_next), .pc_out(pc_current));
    IMEM imem_inst (.address(pc_current), .instruction(instr));

    pipe_if_id reg_IF_ID (
        .clk(clk), .reset(reset), .en(IF_ID_Write), .flush(branch_taken),
        .if_pc(pc_current), .if_instr(instr), .id_pc(id_pc), .id_instr(id_instr)
    );

    // ID Stage
    control_unit control_inst (
        .opcode(id_instr[6:0]), .funct3(id_instr[14:12]), .funct7_bit30(id_instr[30]),
        .RegWrite(id_reg_write), .ALUSrc(id_alu_src), .MemWrite(id_mem_write),
        .MemRead(id_mem_read), .MemToReg(id_mem_to_reg), .Branch(id_branch), .ALUControl(id_alu_control)
    );
    rf rf_inst (
        .clk(clk), .reset(reset), .reg_write(wb_RegWrite),
        .rs1_addr(id_instr[19:15]), .rs2_addr(id_instr[24:20]),
        .rd_addr(wb_rd), .rd_data(wb_rd_data),
        .rs1_data(id_rs1_data), .rs2_data(id_rs2_data)
    );
    imm_gen imm_gen_inst (.instr(id_instr), .imm_out(id_imm_ext));
    hazard_detection_unit hazard_detect_block (
    .ID_rs1(id_instr[19:15]), .ID_rs2(id_instr[24:20]),
    .ID_opcode(id_instr[6:0]),          
    .EX_rd(ex_rd), .EX_MemRead(ex_MemRead),
    .PCWrite(PCWrite), .IF_ID_Write(IF_ID_Write), .Control_Mux(Control_Mux)
);

    assign id_RegWrite_mux  = Control_Mux ? 1'b0    : id_reg_write;
    assign id_MemWrite_mux  = Control_Mux ? 1'b0    : id_mem_write;
    assign id_MemRead_mux   = Control_Mux ? 1'b0    : id_mem_read;
    assign id_ALUControl_mux= Control_Mux ? 4'b0000 : id_alu_control;
    assign id_MemToReg_mux  = Control_Mux ? 1'b0    : id_mem_to_reg;
    assign id_ALUSrc_mux    = Control_Mux ? 1'b0    : id_alu_src;

    pipe_id_ex reg_ID_EX (
        .clk(clk), .reset(reset), .flush(branch_taken),
        .id_RegWrite(id_RegWrite_mux), .id_ALUSrc(id_ALUSrc_mux),
        .id_MemWrite(id_MemWrite_mux), .id_MemRead(id_MemRead_mux),
        .id_MemToReg(id_MemToReg_mux), .id_ALUControl(id_ALUControl_mux),
        .id_pc(id_pc), .id_rs1_data(id_rs1_data), .id_rs2_data(id_rs2_data),
        .id_imm_ext(id_imm_ext), .id_rs1(id_instr[19:15]), .id_rs2(id_instr[24:20]),
        .id_rd(id_instr[11:7]), .id_branch(id_branch),
        .ex_RegWrite(ex_RegWrite), .ex_ALUSrc(ex_ALUSrc),
        .ex_MemWrite(ex_MemWrite), .ex_MemRead(ex_MemRead),
        .ex_MemToReg(ex_MemToReg), .ex_ALUControl(ex_ALUControl),
        .ex_pc(ex_pc), .ex_rs1_data(ex_rs1_data), .ex_rs2_data(ex_rs2_data),
        .ex_imm_ext(ex_imm_ext), .ex_rs1(ex_rs1), .ex_rs2(ex_rs2),
        .ex_rd(ex_rd), .ex_branch(ex_branch)
    );
 
    // EX Stage
    hazard_forward hazard_forward_inst (
        .clk(clk), .reset(reset),
        .mem_RegWrite(mem_RegWrite), .wb_RegWrite(wb_RegWrite),
        .ex_rs1(ex_rs1), .ex_rs2(ex_rs2), .mem_rd(mem_rd), .wb_rd(wb_rd),
        .forward_A(forward_A), .forward_B(forward_B)
    );
    
    assign ex_rs1_data_forwarded = (forward_A==2'b01) ? mem_alu_result : (forward_A==2'b10) ? wb_rd_data : ex_rs1_data;
    assign ex_rs2_data_forwarded = (forward_B==2'b01) ? mem_alu_result : (forward_B==2'b10) ? wb_rd_data : ex_rs2_data;
    assign ex_alu_src_b          = (ex_ALUSrc) ? ex_imm_ext : ex_rs2_data_forwarded;

    alu alu_inst (.A(ex_rs1_data_forwarded), .B(ex_alu_src_b),
                  .ALUControl(ex_ALUControl), .ALUResult(ex_alu_result), .Zero(ex_zero));

    assign branch_taken      = ex_branch && ex_zero;
    assign branch_taken_addr = ex_pc + ex_imm_ext;

    pipe_ex_mem reg_EX_MEM (
        .clk(clk), .reset(reset),
        .ex_RegWrite(ex_RegWrite), .ex_MemWrite(ex_MemWrite),
        .ex_MemRead(ex_MemRead), .ex_MemToReg(ex_MemToReg),
        .ex_alu_result(ex_alu_result), .ex_rs2_data(ex_rs2_data_forwarded), .ex_rd(ex_rd),
        .mem_RegWrite(mem_RegWrite), .mem_MemWrite(mem_MemWrite),
        .mem_MemRead(mem_MemRead), .mem_MemToReg(mem_MemToReg),
        .mem_alu_result(mem_alu_result), .mem_rs2_data(mem_rs2_data), .mem_rd(mem_rd)
    );

    // MEM Stage
    data_memory dmem_inst (
        .clk(clk), .MemWrite(mem_MemWrite), .MemRead(mem_MemRead),
        .Address(mem_alu_result), .WriteData(mem_rs2_data), .ReadData(mem_read_data)
    );

    pipe_mem_wb reg_MEM_WB (
        .clk(clk), .reset(reset),
        .mem_RegWrite(mem_RegWrite), .mem_MemToReg(mem_MemToReg),
        .mem_read_data(mem_read_data), .mem_alu_result(mem_alu_result), .mem_rd(mem_rd),
        .wb_RegWrite(wb_RegWrite), .wb_MemToReg(wb_MemToReg),
        .wb_read_data(wb_read_data), .wb_alu_result(wb_alu_result), .wb_rd(wb_rd)
    );

    // WB Stage
    assign wb_rd_data = (wb_MemToReg) ? wb_read_data : wb_alu_result;
    assign pc_next    = branch_taken  ? branch_taken_addr : pc_current + 32'd4;

endmodule