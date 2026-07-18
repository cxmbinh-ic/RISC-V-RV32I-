
// -----------------------------------------------------------------------------
// 1. PC — Program Counter
// -----------------------------------------------------------------------------
module pc(
    input clk,
    input reset,
    input en,
    input [31:0] pc_in,
    output reg [31:0] pc_out
);
always @(posedge clk or posedge reset) begin
    if (reset)
        pc_out <= 32'b0;
    else if (en)
        pc_out <= pc_in;
end
endmodule

// -----------------------------------------------------------------------------
// 2. IMEM — Instruction Memory
// -----------------------------------------------------------------------------
module IMEM(
    input [31:0] address,
    output reg [31:0] instruction
);
reg [31:0] memory [0:1023];
always @(*) begin
    instruction = memory[address[11:2]];
end
initial begin
    $readmemh("program.hex", memory);
end
endmodule

// -----------------------------------------------------------------------------
// 3. ALU
// -----------------------------------------------------------------------------
module alu (
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [3:0]  ALUControl,
    output reg  [31:0] ALUResult,
    output wire        Zero
);
assign Zero = (ALUResult == 32'b0);
always @(*) begin
    case (ALUControl)
        4'b0000: ALUResult = A + B;
        4'b0001: ALUResult = A - B;
        4'b0010: ALUResult = A & B;
        4'b0011: ALUResult = A | B;
        4'b0100: ALUResult = A ^ B;
        4'b0101: ALUResult = A << B[4:0];
        4'b0110: ALUResult = A >> B[4:0];
        4'b0111: ALUResult = $signed(A) >>> B[4:0];
        4'b1000: ALUResult = ($signed(A) < $signed(B)) ? 32'b1 : 32'b0;
        4'b1001: ALUResult = (A < B) ? 32'b1 : 32'b0;
        default: ALUResult = 32'b0;
    endcase
end
endmodule

// -----------------------------------------------------------------------------
// 4. Control Unit
// -----------------------------------------------------------------------------
module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire       funct7_bit30,
    output reg        RegWrite,
    output reg        ALUSrc,
    output reg        MemWrite,
    output reg        MemRead,
    output reg        MemToReg,
    output reg        Branch,
    output reg  [3:0] ALUControl
);
reg [1:0] ALUOp;
always @(*) begin
    RegWrite = 1'b0; ALUSrc = 1'b0; MemWrite = 1'b0;
    MemRead  = 1'b0; MemToReg = 1'b0; ALUOp = 2'b00; Branch = 1'b0;
    case (opcode)
        7'b0110011: begin RegWrite=1'b1; ALUSrc=1'b0; MemToReg=1'b0; ALUOp=2'b10; end
        7'b0010011: begin RegWrite=1'b1; ALUSrc=1'b1; MemToReg=1'b0; ALUOp=2'b11; end
        7'b0000011: begin RegWrite=1'b1; ALUSrc=1'b1; MemRead=1'b1;  MemToReg=1'b1; ALUOp=2'b00; end
        7'b0100011: begin ALUSrc=1'b1; MemWrite=1'b1; ALUOp=2'b00; end
        7'b1100011: begin ALUSrc=1'b0; ALUOp=2'b01; Branch=1'b1; end
        default: begin end
    endcase
end
always @(*) begin
    case (ALUOp)
        2'b00: ALUControl = 4'b0000;
        2'b01: ALUControl = 4'b0001;
        2'b10: begin
            case (funct3)
                3'b000: ALUControl = funct7_bit30 ? 4'b0001 : 4'b0000;
                3'b111: ALUControl = 4'b0010;
                3'b110: ALUControl = 4'b0011;
                3'b100: ALUControl = 4'b0100;
                3'b001: ALUControl = 4'b0101;
                3'b101: ALUControl = funct7_bit30 ? 4'b0111 : 4'b0110;
                3'b010: ALUControl = 4'b1000;
                3'b011: ALUControl = 4'b1001;
                default: ALUControl = 4'b0000;
            endcase
        end
        2'b11: begin
            case (funct3)
                3'b000: ALUControl = 4'b0000;
                3'b111: ALUControl = 4'b0010;
                3'b110: ALUControl = 4'b0011;
                3'b100: ALUControl = 4'b0100;
                3'b001: ALUControl = 4'b0101;
                3'b101: ALUControl = funct7_bit30 ? 4'b0111 : 4'b0110;
                3'b010: ALUControl = 4'b1000;
                3'b011: ALUControl = 4'b1001;
                default: ALUControl = 4'b0000;
            endcase
        end
        default: ALUControl = 4'b0000;
    endcase
end
endmodule

// -----------------------------------------------------------------------------
// 5. Register File
// -----------------------------------------------------------------------------
module rf(
    input clk, reset,
    input [4:0]  rs1_addr, rs2_addr, rd_addr,
    input [31:0] rd_data,
    input        reg_write,
    output reg [31:0] rs1_data, rs2_data
);
reg [31:0] reg_file [0:31];
integer i;
always @(posedge clk or posedge reset) begin
    if (reset)
        for (i = 0; i < 32; i = i + 1) reg_file[i] <= 32'b0;
    else if (reg_write && rd_addr != 5'b0)
        reg_file[rd_addr] <= rd_data;
end
always @(*) begin
    if(rs1_addr == rd_addr && reg_write && rd_addr != 5'b0)
        rs1_data = rd_data;
    else
        rs1_data = reg_file[rs1_addr];
    if(rs2_addr == rd_addr && reg_write && rd_addr != 5'b0)
        rs2_data = rd_data;
    else
        rs2_data = reg_file[rs2_addr];
end
endmodule

// -----------------------------------------------------------------------------
// 6. Immediate Generator
// ----------------------------------------------------------------------------- 
module imm_gen (
    input  wire [31:0] instr,
    output reg  [31:0] imm_out
);
wire [6:0] opcode = instr[6:0];
always @(*) begin
    case (opcode)
        7'b0010011, 7'b0000011: imm_out = { {20{instr[31]}}, instr[31:20] };
        7'b0100011:             imm_out = { {20{instr[31]}}, instr[31:25], instr[11:7] };
        7'b1100011:             imm_out = { {19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0 };
        7'b0110111, 7'b0010111: imm_out = { instr[31:12], 12'b0 };
        7'b1101111:             imm_out = { {11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0 };
        default:                imm_out = 32'b0;
    endcase
end
endmodule

// -----------------------------------------------------------------------------
// 7. Hazard Detection Unit
// -----------------------------------------------------------------------------
module hazard_detection_unit (
    input  wire [4:0] ID_rs1, ID_rs2, EX_rd,
    input  wire [6:0] ID_opcode,          
    input  wire       EX_MemRead,
    output reg        PCWrite, IF_ID_Write, Control_Mux
);
always @(*) begin
    PCWrite = 1'b1; IF_ID_Write = 1'b1; Control_Mux = 1'b0;

    
    if (EX_MemRead && (EX_rd != 5'b0) &&
       ((EX_rd == ID_rs1) ||
        ((EX_rd == ID_rs2) &&
         (ID_opcode == 7'b0110011 ||   // R-type
          ID_opcode == 7'b1100011 ||   // B-type
          ID_opcode == 7'b0100011))))  // S-type
    begin
        PCWrite = 1'b0; IF_ID_Write = 1'b0; Control_Mux = 1'b1;
    end
end
endmodule

// -----------------------------------------------------------------------------
// 8. Hazard Forward (Forwarding Unit)
// -----------------------------------------------------------------------------
module hazard_forward (
    input clk, reset,
    input        mem_RegWrite, wb_RegWrite,
    input [4:0]  ex_rs1, ex_rs2, mem_rd, wb_rd,
    output reg [1:0] forward_A, forward_B
);
always @(*) begin
    forward_A = 2'b00; forward_B = 2'b00;
    if (mem_RegWrite && (mem_rd != 0) && (mem_rd == ex_rs1))      forward_A = 2'b01;
    else if (wb_RegWrite && (wb_rd != 0) && (wb_rd == ex_rs1))    forward_A = 2'b10;
    if (mem_RegWrite && (mem_rd != 0) && (mem_rd == ex_rs2))      forward_B = 2'b01;
    else if (wb_RegWrite && (wb_rd != 0) && (wb_rd == ex_rs2))    forward_B = 2'b10;
end
endmodule

// -----------------------------------------------------------------------------
// 9. Data Memory
// -----------------------------------------------------------------------------
module data_memory (
    input  wire        clk, MemWrite, MemRead,
    input  wire [31:0] Address, WriteData,
    output wire [31:0] ReadData
);
reg [31:0] ram [0:63];
int ri;
initial begin
    for (ri = 0; ri < 64; ri = ri + 1)
        ram[ri] = 32'h00000000;
end
wire [5:0] word_addr = Address[7:2];
always @(posedge clk) begin
    if (MemWrite) ram[word_addr] <= WriteData;
end
assign ReadData = (MemRead) ? ram[word_addr] : 32'b0;
endmodule

// -----------------------------------------------------------------------------
// 10. Pipeline Register: IF/ID
// -----------------------------------------------------------------------------
module pipe_if_id (
    input  wire        clk, reset, en, flush,
    input  wire [31:0] if_pc, if_instr,
    output reg  [31:0] id_pc, id_instr
);
always @(posedge clk) begin
    if (reset || flush) begin
        id_pc    <= 32'b0;
        id_instr <= 32'h00000013;
    end else if (en) begin
        id_pc    <= if_pc;
        id_instr <= if_instr;
    end
end
endmodule

// -----------------------------------------------------------------------------
// 11. Pipeline Register: ID/EX
// -----------------------------------------------------------------------------
module pipe_id_ex (
    input  wire        clk, reset, flush,
    input  wire        id_RegWrite, id_ALUSrc, id_MemWrite, id_MemRead, id_MemToReg,
    input  wire [3:0]  id_ALUControl,
    input  wire [31:0] id_pc, id_rs1_data, id_rs2_data, id_imm_ext,
    input  wire [4:0]  id_rs1, id_rs2, id_rd,
    input  wire        id_branch,           // FIX: was [4:0]
    output reg         ex_RegWrite, ex_ALUSrc, ex_MemWrite, ex_MemRead, ex_MemToReg,
    output reg  [3:0]  ex_ALUControl,
    output reg  [31:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_imm_ext,
    output reg  [4:0]  ex_rs1, ex_rs2, ex_rd,
    output reg         ex_branch             // FIX: was [4:0]
);
always @(posedge clk) begin
    if (reset || flush) begin
        ex_RegWrite<=1'b0; ex_ALUSrc<=1'b0; ex_MemWrite<=1'b0;
        ex_MemRead<=1'b0;  ex_MemToReg<=1'b0; ex_ALUControl<=4'b0;
        ex_pc<=32'b0; ex_rs1_data<=32'b0; ex_rs2_data<=32'b0;
        ex_imm_ext<=32'b0; ex_rs1<=5'b0; ex_rs2<=5'b0;
        ex_rd<=5'b0; ex_branch<=1'b0;
    end else begin
        ex_RegWrite<=id_RegWrite; ex_ALUSrc<=id_ALUSrc;
        ex_MemWrite<=id_MemWrite; ex_MemRead<=id_MemRead;
        ex_MemToReg<=id_MemToReg; ex_ALUControl<=id_ALUControl;
        ex_pc<=id_pc; ex_rs1_data<=id_rs1_data; ex_rs2_data<=id_rs2_data;
        ex_imm_ext<=id_imm_ext; ex_rs1<=id_rs1; ex_rs2<=id_rs2;
        ex_rd<=id_rd; ex_branch<=id_branch;
    end
end
endmodule

// -----------------------------------------------------------------------------
// 12. Pipeline Register: EX/MEM
// -----------------------------------------------------------------------------
module pipe_ex_mem (
    input  wire        clk, reset,
    input  wire        ex_RegWrite, ex_MemWrite, ex_MemRead, ex_MemToReg,
    input  wire [31:0] ex_alu_result, ex_rs2_data,
    input  wire [4:0]  ex_rd,
    output reg         mem_RegWrite, mem_MemWrite, mem_MemRead, mem_MemToReg,
    output reg  [31:0] mem_alu_result, mem_rs2_data,
    output reg  [4:0]  mem_rd
);
always @(posedge clk) begin
    if (reset) begin
        mem_RegWrite<=1'b0; mem_MemWrite<=1'b0; mem_MemRead<=1'b0; mem_MemToReg<=1'b0;
        mem_alu_result<=32'b0; mem_rs2_data<=32'b0; mem_rd<=5'b0;
    end else begin
        mem_RegWrite<=ex_RegWrite; mem_MemWrite<=ex_MemWrite;
        mem_MemRead<=ex_MemRead;   mem_MemToReg<=ex_MemToReg;
        mem_alu_result<=ex_alu_result; mem_rs2_data<=ex_rs2_data;
        mem_rd<=ex_rd;
    end
end
endmodule

// -----------------------------------------------------------------------------
// 13. Pipeline Register: MEM/WB
// -----------------------------------------------------------------------------
module pipe_mem_wb (
    input  wire        clk, reset,
    input  wire        mem_RegWrite, mem_MemToReg,
    input  wire [31:0] mem_read_data, mem_alu_result,
    input  wire [4:0]  mem_rd,
    output reg         wb_RegWrite, wb_MemToReg,
    output reg  [31:0] wb_read_data, wb_alu_result,
    output reg  [4:0]  wb_rd
);
always @(posedge clk) begin
    if (reset) begin
        wb_RegWrite<=1'b0; wb_MemToReg<=1'b0;
        wb_read_data<=32'b0; wb_alu_result<=32'b0; wb_rd<=5'b0;
    end else begin
        wb_RegWrite<=mem_RegWrite; wb_MemToReg<=mem_MemToReg;
        wb_read_data<=mem_read_data; wb_alu_result<=mem_alu_result;
        wb_rd<=mem_rd;
    end
end
endmodule

// -----------------------------------------------------------------------------
// 14. TOP — rv32i_top
// -----------------------------------------------------------------------------
module rv32i_top (
    input wire clk,
    input wire reset
);
    wire [31:0] pc_current, pc_next, instr;
    wire [31:0] id_pc, id_instr, id_rs1_data, id_rs2_data, id_imm_ext;
    wire        id_reg_write, id_alu_src, id_mem_write, id_mem_read, id_mem_to_reg, id_branch;
    wire [3:0]  id_alu_control;
    wire        PCWrite, IF_ID_Write, Control_Mux;
    wire        id_RegWrite_mux, id_MemWrite_mux, id_MemRead_mux, id_MemToReg_mux, id_ALUSrc_mux, id_branch_mux;
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
    assign id_branch_mux    = Control_Mux ? 1'b0    : id_branch;

    pipe_id_ex reg_ID_EX (
        .clk(clk), .reset(reset), .flush(branch_taken),
        .id_RegWrite(id_RegWrite_mux), .id_ALUSrc(id_ALUSrc_mux),
        .id_MemWrite(id_MemWrite_mux), .id_MemRead(id_MemRead_mux),
        .id_MemToReg(id_MemToReg_mux), .id_ALUControl(id_ALUControl_mux),
        .id_pc(id_pc), .id_rs1_data(id_rs1_data), .id_rs2_data(id_rs2_data),
        .id_imm_ext(id_imm_ext), .id_rs1(id_instr[19:15]), .id_rs2(id_instr[24:20]),
        .id_rd(id_instr[11:7]), .id_branch(id_branch_mux),
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

