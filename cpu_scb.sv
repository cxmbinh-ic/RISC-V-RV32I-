class cpu_scoreboard;
    //1. trans
    cpu_transaction tr_actual;   // from monitor (actual CPU result)
    

    //2. mailboxes
    mailbox #(cpu_transaction) scb_mbx;     // monitor → scoreboard
    

    //3. golden reference model
    bit [31:0] golden_rf  [0:31];  // mirrored register file
    bit [31:0] golden_ram [0:63];  // mirrored data memory (64 words)

    //4. constructor
    function new(mailbox #(cpu_transaction) mbx
                 );
        this.scb_mbx     = mbx;
        for (int i = 0; i < 32; i++) golden_rf[i]  = 32'b0;
        for (int i = 0; i < 64; i++) golden_ram[i] = 32'b0;
    endfunction

    //5. counters
    int finish_count = 0;
    int error_count  = 0;
    int total_count  = 0;

    //6. task run
    task run();
        $display("Scoreboard activated");
        forever begin
            scb_mbx.get(tr_actual);

            // -----------------------------------------------------------
            // R-type and I-type ALU
            // Monitor captures at WB stage → compare write_data directly
            // -----------------------------------------------------------
            if (tr_actual.opcode inside {7'b0110011, 7'b0010011}) begin
                bit [31:0] expected_data;
                bit [31:0] sco_rs1 = golden_rf[tr_actual.rs1];
                bit [31:0] sco_rs2 = golden_rf[tr_actual.rs2];
                bit signed [31:0] sco_imm = $signed(tr_actual.imm[11:0]);

                case (tr_actual.opcode)
                    7'b0110011: begin
                        case ({tr_actual.funct7[5], tr_actual.funct3})
                            4'b0000: expected_data = sco_rs1 + sco_rs2;
                            4'b1000: expected_data = sco_rs1 - sco_rs2;
                            4'b0111: expected_data = sco_rs1 & sco_rs2;
                            4'b0110: expected_data = sco_rs1 | sco_rs2;
                            4'b0100: expected_data = sco_rs1 ^ sco_rs2;
                            4'b0001: expected_data = sco_rs1 << sco_rs2[4:0];
                            4'b0101: expected_data = sco_rs1 >> sco_rs2[4:0];
                            4'b1101: expected_data = $signed(sco_rs1) >>> sco_rs2[4:0];
                            4'b0010: expected_data = ($signed(sco_rs1) < $signed(sco_rs2)) ? 32'b1 : 32'b0;
                            4'b0011: expected_data = (sco_rs1 < sco_rs2) ? 32'b1 : 32'b0;
                            default: expected_data = 32'b0;
                        endcase
                    end
                    7'b0010011: begin
                        case ({tr_actual.funct7[5], tr_actual.funct3})
                            4'b0000: expected_data = sco_rs1 + sco_imm;
                            4'b0111: expected_data = sco_rs1 & sco_imm;
                            4'b0110: expected_data = sco_rs1 | sco_imm;
                            4'b0100: expected_data = sco_rs1 ^ sco_imm;
                            4'b0001: expected_data = sco_rs1 << tr_actual.imm[4:0];
                            4'b0101: expected_data = sco_rs1 >> tr_actual.imm[4:0];
                            4'b1101: expected_data = $signed(sco_rs1) >>> tr_actual.imm[4:0];
                            4'b0010: expected_data = ($signed(sco_rs1) < $signed(sco_imm)) ? 32'b1 : 32'b0;
                            4'b0011: expected_data = (sco_rs1 < sco_imm) ? 32'b1 : 32'b0;
                            default: expected_data = 32'b0;
                        endcase
                    end
                    default: expected_data = 32'b0;
                endcase

                if (tr_actual.write_data == expected_data) begin
                    finish_count++;
                    $display("Scoreboard PASS: PC=0x%8h | Instr=0x%8h | rd=x%0d | Expected=0x%8h | Actual=0x%8h",
                             tr_actual.pc, tr_actual.instr, tr_actual.rd,
                             expected_data, tr_actual.write_data);
                end else begin
                    error_count++;
                    $error("Scoreboard FAIL: PC=0x%8h | Instr=0x%8h | rd=x%0d | Expected=0x%8h | Actual=0x%8h",
                           tr_actual.pc, tr_actual.instr, tr_actual.rd,
                           expected_data, tr_actual.write_data);
                end
                if (tr_actual.rd != 5'b0)
                    golden_rf[tr_actual.rd] = expected_data;
                total_count++;
            end

            // -----------------------------------------------------------
            // LW — Load Word
            // Monitor captures at WB stage (reg_write path)
            // FIX: don't check mem_addr (it belongs to next instruction's
            //      MEM stage at WB capture time). Instead:
            //      1. Compute expected_addr from golden model
            //      2. Compare tr_actual.write_data against golden_ram
            // -----------------------------------------------------------
            else if (tr_actual.opcode == 7'b0000011) begin
                bit [31:0] sco_rs1        = golden_rf[tr_actual.rs1];
                bit signed [31:0] sco_imm = $signed(tr_actual.imm[11:0]);
                bit [31:0] expected_addr  = sco_rs1 + sco_imm;
                bit [5:0]  word_idx       = expected_addr[7:2];
                bit [31:0] expected_data  = golden_ram[word_idx];

                // Compare the loaded data against golden RAM
                if (tr_actual.write_data === expected_data) begin
                    finish_count++;
                    $display("Scoreboard PASS [LW]: PC=0x%8h | Instr=0x%8h | Addr=0x%8h | Data=0x%8h",
                             tr_actual.pc, tr_actual.instr, expected_addr, tr_actual.write_data);
                end else begin
                    error_count++;
                    $error("Scoreboard FAIL [LW]: PC=0x%8h | Instr=0x%8h | Addr=0x%8h | ExpData=0x%8h | ActData=0x%8h",
                           tr_actual.pc, tr_actual.instr, expected_addr,
                           expected_data, tr_actual.write_data);
                end
                // Update golden RF with loaded value
                if (tr_actual.rd != 5'b0)
                    golden_rf[tr_actual.rd] = expected_data;
                total_count++;
            end

            // -----------------------------------------------------------
            // SW — Store Word
            // Monitor captures at MEM stage (mem_write path)
            // mem_addr is correctly populated from wb_alu_result spy
            // FIX: use === for X-safe comparison, update golden_ram
            // -----------------------------------------------------------
            else if (tr_actual.opcode == 7'b0100011) begin
                bit [31:0] sco_rs1        = golden_rf[tr_actual.rs1];
                bit signed [31:0] sco_imm = $signed(tr_actual.imm[11:0]);
                bit [31:0] expected_addr  = sco_rs1 + sco_imm;

                if (tr_actual.mem_addr === expected_addr) begin
                    finish_count++;
                    $display("Scoreboard PASS [SW]: PC=0x%8h | Instr=0x%8h | Addr=0x%8h | Data=0x%8h",
                             tr_actual.pc, tr_actual.instr,
                             tr_actual.mem_addr, tr_actual.mem_data);
                    // Update golden RAM with stored value
                    golden_ram[expected_addr[7:2]] = golden_rf[tr_actual.rs2];
                end else begin
                    error_count++;
                    $error("Scoreboard FAIL [SW]: PC=0x%8h | Instr=0x%8h | ExpAddr=0x%8h | ActAddr=0x%8h",
                           tr_actual.pc, tr_actual.instr,
                           expected_addr, tr_actual.mem_addr);
                end
                total_count++;
            end

        end // forever
    endtask

    function void report();
        $display("=================================================");
        $display("Scoreboard Summary: Total=%0d | PASS=%0d | FAIL=%0d",
                  total_count, finish_count, error_count);
        $display("=================================================");
    endfunction

endclass