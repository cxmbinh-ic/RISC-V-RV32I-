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