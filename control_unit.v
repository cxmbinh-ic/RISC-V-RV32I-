module control_unit (
    input  wire [6:0] opcode,       // inst[6:0]
    input  wire [2:0] funct3,       // inst[14:12]
    input  wire       funct7_bit30, // inst[30] (The ADD/SUB and Shift modifier)
    output reg        RegWrite,     // Write enable for Register File
    output reg        ALUSrc,       // ALU second operand selector
    output reg        MemWrite,     // Write enable for Data Memory
    output reg        MemRead,      // Read enable for Data Memory
    output reg        MemToReg,     // Register File write-back data selector
    output reg        Branch,       //use for flush
    output reg  [3:0] ALUControl    // 4-bit command routed straight to the ALU
);

    // Internal 2-bit wire connecting the Main Decoder to the ALU Decoder stage
    reg [1:0] ALUOp;

    // =========================================================================
    // 1. THE MAIN DECODER (Decodes the Opcode Category)
    // =========================================================================
    always @(*) begin
        // Default fallbacks to guarantee no latches are synthesized
        RegWrite = 1'b0;
        ALUSrc   = 1'b0;
        MemWrite = 1'b0;
        MemRead  = 1'b0;
        MemToReg = 1'b0;
        ALUOp    = 2'b00;
        Branch   = 1'b0;

        case (opcode)
            // R-Type Math (add, sub, and, or, xor, sll, srl, sra, slt, sltu)
            7'b0110011: begin
                RegWrite = 1'b1; // Yes, write result to rd
                ALUSrc   = 1'b0; // Use register rs2 data
                MemToReg = 1'b0; // Route ALU output to rd
                ALUOp    = 2'b10; // Pass control to the ALU Decoder specialist
            end

            // I-Type Math (addi, andi, ori, xori, slli, srli, srai, slti, sltiu)
            7'b0010011: begin
                RegWrite = 1'b1; // Yes, write result to rd
                ALUSrc   = 1'b1; // Use immediate constant from imm_gen
                MemToReg = 1'b0; // Route ALU output to rd
                ALUOp    = 2'b11; // Look at funct3, ignore funct7 (mostly)
            end

            // LW (Load Word)
            7'b0000011: begin
                RegWrite = 1'b1; // Yes, write loaded RAM data into rd
                ALUSrc   = 1'b1; // Calculate address using Base (rs1) + Offset (Imm)
                MemRead  = 1'b1; // Turn on RAM read circuits
                MemToReg = 1'b1; // Select RAM data to write back to rd
                ALUOp    = 2'b00; // Force an ADD operation to compute memory address
            end

            // SW (Store Word)
            7'b0100011: begin
                RegWrite = 1'b0; // Do not overwrite any registers
                ALUSrc   = 1'b1; // Calculate address using Base (rs1) + Offset (Imm)
                MemWrite = 1'b1; // Turn on RAM write enable strobe
                ALUOp    = 2'b00; // Force an ADD operation to compute memory address
            end

            // BEQ / BNE / BLT / BGE (Conditional Branches)
            7'b1100011: begin
                RegWrite = 1'b0; // Do not overwrite any registers
                ALUSrc   = 1'b0; // Compare register rs1 directly with rs2
                ALUOp    = 2'b01; // Force a SUBTRACTION to check equality/comparison
                Branch   = 1'b1; // Trigger branch logic in the EX stage to potentially flush the pipeline
            end

            default: begin
                // Keeps default values safe if opcode is unknown
            end
        endcase
    end

    // =========================================================================
    // 2. THE ALU DECODER (Decodes the Exact Mathematical Action)
    // =========================================================================
    always @(*) begin
        case (ALUOp)
            2'b00: ALUControl = 4'b0000; // Force ADD (Used by LW and SW for addressing)
            2'b01: ALUControl = 4'b0001; // Force SUB (Used by Branch to compare)
            
            //  R-Type Math Category: Look closely at funct3 and funct7 modifiers
            2'b10: begin 
                case (funct3)
                    3'b000: begin
                        if (funct7_bit30) 
                            ALUControl = 4'b0001; // SUB (bit 30 is 1)
                        else              
                            ALUControl = 4'b0000; // ADD (bit 30 is 0)
                    end
                    3'b111: ALUControl = 4'b0010; // AND
                    3'b110: ALUControl = 4'b0011; // OR
                    3'b100: ALUControl = 4'b0100; // XOR
                    3'b001: ALUControl = 4'b0101; // SLL (Shift Left Logical)
                    3'b101: begin
                        if (funct7_bit30)
                            ALUControl = 4'b0111; // SRA (Arithmetic Shift Right)
                        else
                            ALUControl = 4'b0110; // SRL (Logical Shift Right)
                    end
                    3'b010: ALUControl = 4'b1000; // SLT (Set Less Than Signed)
                    3'b011: ALUControl = 4'b1001; // SLTU (Set Less Than Unsigned)
                    default: ALUControl = 4'b0000;
                endcase
            end

            // I-Type Math Category: Look at funct3
            2'b11: begin
                case (funct3)
                    3'b000: ALUControl = 4'b0000; // ADDI
                    3'b111: ALUControl = 4'b0010; // ANDI
                    3'b110: ALUControl = 4'b0011; // ORI
                    3'b100: ALUControl = 4'b0100; // XORI
                    3'b001: ALUControl = 4'b0101; // SLLI
                    3'b101: begin
                        if (funct7_bit30)
                            ALUControl = 4'b0111; // SRAI
                        else
                            ALUControl = 4'b0110; // SRLI
                    end
                    3'b010: ALUControl = 4'b1000; // SLTI
                    3'b011: ALUControl = 4'b1001; // SLTUI
                    default: ALUControl = 4'b0000;
                endcase
            end

            default: ALUControl = 4'b0000;
        endcase
    end

endmodule