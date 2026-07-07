module imm_gen (
    input  wire [31:0] instr,       // Raw 32-bit machine instruction from IMEM
    output reg  [31:0] imm_out     // Full sign-extended 32-bit constant output
);

    // Extract the opcode to decide how to unpack the scrambled bits
    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        case (opcode)
            // -----------------------------------------------------------------
            // 1. I-Type: ADDI, ANDI, ORI, XORI, LW (Loads)
            // -----------------------------------------------------------------
            7'b0010011, // OP-IMM (Arithmetic with Immediate)
            7'b0000011: // LOAD (Load Word, Byte, Halfword)
                imm_out = { {20{instr[31]}}, instr[31:20] };

            // -----------------------------------------------------------------
            // 2. S-Type: SW (Store Word), SB, SH
            // -----------------------------------------------------------------
            7'b0100011: // STORE
                imm_out = { {20{instr[31]}}, instr[31:25], instr[11:7] };

            // -----------------------------------------------------------------
            // 3. B-Type: BEQ, BNE, BLT, BGE (Conditional Branches)
            // -----------------------------------------------------------------
            // Note: RISC-V branches count by multiples of 2 bytes, so bit 0 is 
            // always 1'b0. The instruction only stores bits 12 down to 1.
            7'b1100011: // BRANCH
                imm_out = { {19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0 };

            // -----------------------------------------------------------------
            // 4. U-Type: LUI (Load Upper Immediate), AUIPC
            // -----------------------------------------------------------------
            // No sign extension needed here! It places the 20-bit constant 
            // directly into the top 20 bits and pads the bottom 12 bits with zeros.
            7'b0110111, // LUI
            7'b0010111: // AUIPC
                imm_out = { instr[31:12], 12'b0 };

            // -----------------------------------------------------------------
            // 5. J-Type: JAL (Jump and Link)
            // -----------------------------------------------------------------
            // Like B-type, jumps are always half-word aligned, so bit 0 is 1'b0.
            7'b1101111: // JAL (Unconditional Jump)
                imm_out = { {11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0 };

            // -----------------------------------------------------------------
            // Default Fallback (Prevents synthesis latches)
            // -----------------------------------------------------------------
            default: 
                imm_out = 32'b0;
        endcase
    end

endmodule