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
