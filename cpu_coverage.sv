class cpu_coverage;
    //1. transaction
    cpu_transaction tr;
    //2. covergroup
    covergroup cpu_cg;
        option.per_instance = 1;
        option.comment = "RISC-V RV32I Functional Coverage Model";
        //3. opcode coverage
        opcode_cp : coverpoint tr.opcode {
            bins R_type = {7'b0110011};
            bins I_type = {7'b0010011};
            bins L_type = {7'b0000011};
            bins S_type = {7'b0100011};
            bins B_type = {7'b1100011};
        }
        //4. register files coverage
        rd_cp : coverpoint tr.rd { bins all_regs[] = {[1:31]}; }
        rs1_cp : coverpoint tr.rs1 { bins all_regs[] = {[0:31]}; }
        rs2_cp : coverpoint tr.rs2 { bins all_regs[] = {[0:31]}; }
        //5. funct3 coverage
        funct3_cp : coverpoint tr.funct3 {
            bins funct3_000 = {3'b000};
            bins funct3_001 = {3'b001};
            bins funct3_010 = {3'b010};
            bins funct3_011 = {3'b011};
            bins funct3_100 = {3'b100};
            bins funct3_101 = {3'b101};
            bins funct3_110 = {3'b110};
            bins funct3_111 = {3'b111};
        }
        //6. funct7 coverage
        funct7_cp : coverpoint tr.funct7 {
            bins funct7_0000000 = {7'b0000000};
            bins funct7_0100000 = {7'b0100000};
        }
        ///// 7. Cross coverage
        //7.1 opcode x funct3 x funct7
        opcode_funct3_funct7_cross : cross opcode_cp, funct3_cp, funct7_cp{
            ignore_bins r_type = binsof(opcode_cp) intersect {7'b0110011}
                            && !binsof(funct3_cp) intersect {3'b000, 3'b101}
                            && !binsof(funct7_cp) intersect {7'b0000000};
            ignore_bins i_type = binsof(opcode_cp) intersect {7'b0010011}
                            && !binsof(funct3_cp) intersect {3'b101}
                            && !binsof(funct7_cp) intersect {7'b0000000};
            ignore_bins l_s_type = binsof(opcode_cp) intersect {7'b0000011, 7'b0100011}
                            && !binsof(funct3_cp) intersect {3'b010};// ignore all funct3 except 010 for LW and SW
            ignore_bins l_s_type2 = binsof(opcode_cp) intersect {7'b0000011, 7'b0100011}
                            && !binsof(funct7_cp) intersect {7'b0000000};// ignore all funct7 except 0000000 for LW and SW
            ignore_bins b_type = binsof(opcode_cp) intersect {7'b1100011}
                            && !binsof(funct3_cp) intersect {3'b000}; // ignore all funct3 except 000 for BEQ
            ignore_bins b_type2 = binsof(opcode_cp) intersect {7'b1100011}
                            && !binsof(funct7_cp) intersect {7'b0000000}; // ignore all funct7 except 0000000 for BEQ
        }
        //7.2 opcode x rd
        opcode_rd_cross : cross opcode_cp, rd_cp {
            ignore_bins s_b_type = binsof(opcode_cp) intersect {7'b0100011, 7'b1100011};
        }
        //8. hazard forward
        forward_cp : coverpoint {tr.forward_A, tr.forward_B} {
            bins no_forward = {2'b00};
            bins forward_A   = {2'b01};
            bins forward_B   = {2'b10};
        }
        //9. stall
        stall_cp : coverpoint tr.PC_write {
            bins stall = {1'b0};
            bins no_stall = {1'b1};
        }
    endgroup

    // ------------------------------------Contructor-----
    function new();
        cpu_cg = new();
    endfunction
    // ------------------------------------Sampling function-----
    function void sample(cpu_transaction tr);
        if (tr == null) begin
            $display("[COVERAGE] Warning: sample() called with null transaction at time %0t, skipping.", $time);
            return;
        end
        this.tr = tr;
        cpu_cg.sample();
    endfunction
    // ------------------------------------Get coverage-----
    function void display_coverage();
        $display("[OVERALL COVERAGE] CPU Coverage: %0.2f%%", cpu_cg.get_coverage());
        $display("[COVERAGE DETAILS] opcode coverage: %0.2f%%", cpu_cg.opcode_cp.get_coverage());
        $display("[COVERAGE DETAILS] rd coverage: %0.2f%%", cpu_cg.rd_cp.get_coverage());
        $display("[COVERAGE DETAILS] rs1 coverage: %0.2f%%", cpu_cg.rs1_cp.get_coverage());
        $display("[COVERAGE DETAILS] rs2 coverage: %0.2f%%", cpu_cg.rs2_cp.get_coverage());
        $display("[COVERAGE DETAILS] funct3 coverage: %0.2f%%", cpu_cg.funct3_cp.get_coverage());
        $display("[COVERAGE DETAILS] funct7 coverage: %0.2f%%", cpu_cg.funct7_cp.get_coverage());
        $display("[COVERAGE DETAILS] opcode x funct3 x funct7 cross coverage: %0.2f%%", cpu_cg.opcode_funct3_funct7_cross.get_coverage());
        $display("[COVERAGE DETAILS] opcode x rd cross coverage: %0.2f%%", cpu_cg.opcode_rd_cross.get_coverage());
        $display("[COVERAGE DETAILS] forwarding coverage: %0.2f%%", cpu_cg.forward_cp.get_coverage());
        $display("[COVERAGE DETAILS] stall coverage: %0.2f%%", cpu_cg.stall_cp.get_coverage());
    endfunction
endclass