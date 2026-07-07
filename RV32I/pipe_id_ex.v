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