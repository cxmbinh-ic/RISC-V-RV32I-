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