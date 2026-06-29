`include "cpu_if.sv"
`include "cpu_transaction.sv"
`include "cpu_gen.sv"
`include "cpu_driver.sv"
`include "cpu_monitor.sv"
`include "cpu_scoreboard.sv"
`include "cpu_env.sv"

module tb_top;

    bit clk;
    always #10 clk = ~clk;

    cpu_if intf(clk);

    rv32i_top my_cpu (
        .clk   (clk),
        .reset (intf.reset)
    );

    // ----------------------------------------------------------------
    // IMEM pre-load: ghi vào memory[] trong khi reset=1
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (intf.reset) begin
            my_cpu.imem_inst.memory[intf.drv_instr_addr] = intf.drv_instr;
        end
    end

    // ================================================================
    // PIPELINE SPY CHAIN
    // Mỗi instruction đi qua: IF → ID → EX → MEM → WB (4 clock edge)
    //
    // Ta spy tại ID stage (id_instr) rồi delay 3 clock đến WB.
    // Ta spy tại MEM stage (mem_*) rồi delay 1 clock đến WB.
    // Ta spy tại EX stage (ex_imm_ext, ex_branch) rồi delay 2 clock.
    // ================================================================

    // ---------- Delay chain: ID → EX → MEM → WB (3 flops) ----------
    // Source: id_instr tại posedge clock khi instruction đang ở ID stage

    logic [6:0]  ex_opcode,  mem_opcode,  wb_opcode;
    logic [4:0]  ex_rs1_spy, mem_rs1_spy, wb_rs1;
    logic [4:0]  ex_rs2_spy, mem_rs2_spy, wb_rs2;
    logic [2:0]  ex_funct3,  mem_funct3,  wb_funct3;
    logic        ex_funct7b5, mem_funct7b5, wb_funct7b5;

    // Delay 1: ID → EX  (latch id_instr fields vào ex_*)
    always @(posedge clk) begin
        ex_opcode   <= my_cpu.id_instr[6:0];
        ex_rs1_spy  <= my_cpu.id_instr[19:15];
        ex_rs2_spy  <= my_cpu.id_instr[24:20];
        ex_funct3   <= my_cpu.id_instr[14:12];
        ex_funct7b5 <= my_cpu.id_instr[30];
    end

    // Delay 2: EX → MEM
    always @(posedge clk) begin
        mem_opcode   <= ex_opcode;
        mem_rs1_spy  <= ex_rs1_spy;
        mem_rs2_spy  <= ex_rs2_spy;
        mem_funct3   <= ex_funct3;
        mem_funct7b5 <= ex_funct7b5;
    end

    // Delay 3: MEM → WB
    always @(posedge clk) begin
        wb_opcode   <= mem_opcode;
        wb_rs1      <= mem_rs1_spy;
        wb_rs2      <= mem_rs2_spy;
        wb_funct3   <= mem_funct3;
        wb_funct7b5 <= mem_funct7b5;
    end

    // ---------- Delay chain: EX → MEM → WB (2 flops) ----------
    // Source: ex_imm_ext, ex_branch

    logic [31:0] mem_imm,    wb_imm;
    logic        mem_branch, wb_branch;

    always @(posedge clk) begin
        mem_imm    <= my_cpu.ex_imm_ext;
        mem_branch <= my_cpu.ex_branch;
    end
    always @(posedge clk) begin
        wb_imm    <= mem_imm;
        wb_branch <= mem_branch;
    end

    // ---------- Delay chain: MEM → WB (1 flop) ----------
    // Source: mem_MemWrite, mem_alu_result, mem_rs2_data

    logic        wb_MemWrite;
    logic [31:0] wb_mem_addr;
    logic [31:0] wb_mem_data;

    always @(posedge clk) begin
        wb_MemWrite  <= my_cpu.mem_MemWrite;
        wb_mem_addr  <= my_cpu.mem_alu_result;
        wb_mem_data  <= my_cpu.mem_rs2_data;
    end

    // ---------- PC delay chain: IF → ID → EX → MEM → WB (4 flops) ----------
    logic [31:0] id_pc_spy, ex_pc_spy, mem_pc_spy, wb_pc_spy;
    logic [31:0] id_pcnext, ex_pcnext, mem_pcnext, wb_pcnext;

    always @(posedge clk) begin
        id_pc_spy <= my_cpu.pc_current;
        id_pcnext <= my_cpu.pc_next;
    end
    always @(posedge clk) begin
        ex_pc_spy <= id_pc_spy;
        ex_pcnext <= id_pcnext;
    end
    always @(posedge clk) begin
        mem_pc_spy <= ex_pc_spy;
        mem_pcnext <= ex_pcnext;
    end
    always @(posedge clk) begin
        wb_pc_spy <= mem_pc_spy;
        wb_pcnext <= mem_pcnext;
    end

    // ---------- wb_instr: id_instr delay 3 clock ----------
    logic [31:0] ex_instr_spy, mem_instr_spy, wb_instr_spy;

    always @(posedge clk) ex_instr_spy  <= my_cpu.id_instr;
    always @(posedge clk) mem_instr_spy <= ex_instr_spy;
    always @(posedge clk) wb_instr_spy  <= mem_instr_spy;

    // ================================================================
    // Drive interface signals — tất cả aligned tại WB stage
    // Monitor chỉ cần đọc 1 clock, không cần tự delay
    // ================================================================
    always @(posedge clk) begin
        if (!intf.reset) begin

            // --- WB stage: R / I / LW ---
            intf.monitor_instr     <= wb_instr_spy;
            intf.monitor_pc        <= wb_pc_spy;
            intf.monitor_pc_next   <= wb_pcnext;
            intf.monitor_rd        <= my_cpu.wb_rd;       // đã là WB signal
            intf.monitor_rd_data   <= my_cpu.wb_rd_data;  // đã là WB signal
            intf.monitor_reg_write <= my_cpu.wb_RegWrite; // đã là WB signal

            // Decoded fields — tất cả đã delay đúng đến WB
            intf.monitor_opcode    <= wb_opcode;
            intf.monitor_rs1       <= wb_rs1;
            intf.monitor_rs2       <= wb_rs2;
            intf.monitor_funct3    <= wb_funct3;
            intf.monitor_funct7b5  <= wb_funct7b5;
            intf.monitor_imm       <= wb_imm;

            // --- MEM stage spy (đã delay 1 clock → aligned với WB time) ---
            // SW: addr và data committed tại MEM, ta dùng wb_mem_* đã delay
            intf.monitor_mem_write <= wb_MemWrite;
            intf.monitor_mem_addr  <= wb_mem_addr;
            intf.monitor_mem_data  <= wb_mem_data;

            // --- Branch: resolved tại EX, đã delay 2 clock → WB time ---
            intf.monitor_branch    <= wb_branch;
        end
    end

    cpu_env env;

    initial begin
        clk = 0;
        env = new(intf);
        env.build();
        env.gen.num_instr = 20;
        env.run();
        $finish;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
    end

endmodule