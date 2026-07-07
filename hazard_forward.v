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