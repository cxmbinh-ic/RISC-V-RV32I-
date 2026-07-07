module alu (
    input  wire [31:0] A,           // Operand A (typically from rs1_data)
    input  wire [31:0] B,           // Operand B (typically from rs2_data or immediate)
    input  wire [3:0]  ALUControl,  // 4-bit control signal from the Control Unit/Decoder
    output reg  [31:0] ALUResult,   // 32-bit mathematical calculation output
    output wire        Zero         // High (1'b1) if ALUResult is exactly 0 (used for branches)
);

    // Continuous assignment for the Zero Flag
    // If ALUResult is 0, the expression evaluates to 1. Otherwise, it is 0.
    assign Zero = (ALUResult == 32'b0);

    always @(*) begin
        case (ALUControl)
            4'b0000: ALUResult = A + B;                      // ADD / ADDI
            4'b0001: ALUResult = A - B;                      // SUB
            4'b0010: ALUResult = A & B;                      // AND / ANDI
            4'b0011: ALUResult = A | B;                      // OR / ORI
            4'b0100: ALUResult = A ^ B;                      // XOR / XORI
            4'b0101: ALUResult = A << B[4:0];                // SLL / SLLI (Shift Left Logical)
            4'b0110: ALUResult = A >> B[4:0];                // SRL / SRLI (Shift Right Logical)
            4'b0111: ALUResult = $signed(A) >>> B[4:0];      // SRA / SRAI (Shift Right Arithmetic)
            4'b1000: ALUResult = ($signed(A) < $signed(B)) ? 32'b1 : 32'b0;   // SLT / SLTI (Set Less Than Signed)
            4'b1001: ALUResult = (A < B) ? 32'b1 : 32'b0;    // SLTU / SLTUI (Set Less Than Unsigned)
            default: ALUResult = 32'b0;                      // Default fallback to prevent latches
        endcase
    end

endmodule
