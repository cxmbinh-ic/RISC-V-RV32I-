class cpu_transaction;
    rand bit [6:0] opcode;
    rand bit [4:0] rd;
    rand bit [2:0] funct3;
    rand bit [4:0] rs1;
    rand bit [4:0] rs2;
    rand bit [6:0] funct7;
    rand bit [11:0] imm;

    // Assembled 32-bit instruction word
    bit [31:0] instr;

    // For monitor and scoreboard
    bit [31:0] write_data;
    bit        reg_write;
    bit        mem_write;
    bit        mem_read;
    bit [31:0] mem_addr;
    bit [31:0] mem_data;
    bit        branch;
    bit [31:0] pc;
    bit [31:0] pc_next;
    bit [31:0] imm_ext;

    constraint solve_order {
        solve opcode before funct3, funct7, rd, rs1, rs2, imm;
        solve funct3 before funct7;
    }

    // -------------------------------------------------------------------------
    // constraint 1: R, I, L(LW), S(SW), B opcodes
    // -------------------------------------------------------------------------
    constraint legal_opcode {
        opcode inside {
            7'b0110011,   // R-type : ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
            7'b0010011,   // I-type : ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTUI
            7'b0000011,   // L-type : LW
            7'b0100011,   // S-type : SW
            7'b1100011    // B-type : BEQ, BNE only (SUB-based comparison)
        };
    }

    // -------------------------------------------------------------------------
    // constraint 2: rd != x0 cho các lệnh write register
    // -------------------------------------------------------------------------
    constraint legal_rd {
        if (opcode inside {7'b0110011, 7'b0010011, 7'b0000011})
            rd != 5'b00000;
    }

    // -------------------------------------------------------------------------
    // constraint 3: legal funct3 theo opcode
    // -------------------------------------------------------------------------
    constraint legal_funct3 {
        if (opcode == 7'b0110011)       // R-type
            funct3 inside {3'b000, 3'b111, 3'b110, 3'b100,
                           3'b001, 3'b101, 3'b010, 3'b011};
        else if (opcode == 7'b0010011)  // I-type ALU
            funct3 inside {3'b000, 3'b111, 3'b110, 3'b100,
                           3'b001, 3'b101, 3'b010, 3'b011};
        else if (opcode == 7'b0000011)  // LW
            funct3 == 3'b010;
        else if (opcode == 7'b0100011)  // SW
            funct3 == 3'b010;
        else if(opcode == 7'b1100011 )  //BEQ
            funct3 == 3'b000;

        
    }

    // -------------------------------------------------------------------------
    // constraint 4: legal funct7
    // -------------------------------------------------------------------------
    constraint legal_funct7 {
        if (opcode == 7'b0110011)
            if (funct3 == 3'b000 || funct3 == 3'b101)
                funct7 inside {7'b0000000, 7'b0100000};
            else
                funct7 == 7'b0000000;
        else if (opcode == 7'b0010011)
            if (funct3 == 3'b101)
                funct7 inside {7'b0000000, 7'b0100000};
            else
                funct7 == 7'b0000000;
        else
            funct7 == 7'b0000000;
    }

    // -------------------------------------------------------------------------
    // constraint 5: safe immediate
    // -------------------------------------------------------------------------
    constraint safe_imm {
        if (opcode == 7'b0010011)
            if (funct3 == 3'b001 || funct3 == 3'b101)
                imm inside {[12'h000 : 12'h01F]};
            else
                imm inside {[12'hF80 : 12'hFFF],
                            [12'h000 : 12'h07F]};
        else if (opcode inside {7'b0000011, 7'b0100011})
            imm inside {[12'h000 : 12'h03C]};
        else if (opcode == 7'b1100011) {
            imm[0]    == 1'b0;
            imm[11]   == 1'b0;
            imm[10:1] inside {[10'h001 : 10'h010]};
        }
    }

    // -------------------------------------------------------------------------
    // Build 32-bit instruction word
    // -------------------------------------------------------------------------
    function void build_instruction();
        case (opcode)
            7'b0110011:
                instr = {funct7, rs2, rs1, funct3, rd, opcode};
            7'b0010011:
                if (funct3 == 3'b001 || funct3 == 3'b101)
                    instr = {funct7, imm[4:0], rs1, funct3, rd, opcode};
                else
                    instr = {imm, rs1, funct3, rd, opcode};
            7'b0000011:
                instr = {imm, rs1, funct3, rd, opcode};
            7'b0100011:
                instr = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
            7'b1100011:
                instr = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
            default:
                instr = 32'h00000013;
        endcase
    endfunction

    // -------------------------------------------------------------------------
    // Display helper
    // -------------------------------------------------------------------------
    function void display(string tag = "");
        string op_name;
        case (opcode)
            7'b0110011: begin
                case ({funct7[5], funct3})
                    4'b0000: op_name = "ADD  ";
                    4'b1000: op_name = "SUB  ";
                    4'b0111: op_name = "AND  ";
                    4'b0110: op_name = "OR   ";
                    4'b0100: op_name = "XOR  ";
                    4'b0001: op_name = "SLL  ";
                    4'b0101: op_name = "SRL  ";
                    4'b1101: op_name = "SRA  ";
                    4'b0010: op_name = "SLT  ";
                    4'b0011: op_name = "SLTU ";
                    default: op_name = "R?   ";
                endcase
            end
            7'b0010011: begin
                case ({funct7[5], funct3})
                    4'b0000: op_name = "ADDI ";
                    4'b0111: op_name = "ANDI ";
                    4'b0110: op_name = "ORI  ";
                    4'b0100: op_name = "XORI ";
                    4'b0001: op_name = "SLLI ";
                    4'b0101: op_name = "SRLI ";
                    4'b1101: op_name = "SRAI ";
                    4'b0010: op_name = "SLTI ";
                    4'b0011: op_name = "SLTUI";
                    default: op_name = "I?   ";
                endcase
            end
            7'b0000011: op_name = "LW   ";
            7'b0100011: op_name = "SW   ";
            7'b1100011: op_name = "B";
            default: op_name = "NOP  ";
        endcase

        $display("[%s] time=%0t | %s | rd=x%0d rs1=x%0d rs2=x%0d imm=%0d | instr=0x%08h",
                  tag, $time, op_name,
                  rd, rs1, rs2, $signed({{20{imm[11]}}, imm}),
                  instr);
    endfunction

endclass