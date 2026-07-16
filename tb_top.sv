`include "cpu_if.sv"
`include "cpu_trans_rilsb.sv"
`include "cpu_gen.sv"
`include "cpu_driver.sv"
`include "cpu_coverage.sv"
`include "cpu_monitor.sv"
`include "cpu_scb.sv"
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
    // IMEM pre-load
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (intf.reset) begin
            my_cpu.imem_inst.memory[intf.drv_instr_addr] = intf.drv_instr;
        end
    end


    // ================================================================
    // PIPELINE SPY CHAIN
    // ================================================================

    // ---------- Delay chain: ID → EX → MEM → WB ----------

    logic [6:0]  ex_opcode,  mem_opcode,  wb_opcode;
    logic [4:0]  ex_rs1_spy, mem_rs1_spy, wb_rs1;
    logic [4:0]  ex_rs2_spy, mem_rs2_spy, wb_rs2;
    logic [2:0]  ex_funct3,  mem_funct3,  wb_funct3;
    logic [6:0]  ex_funct7, mem_funct7, wb_funct7;
    logic        ex_PC_write, mem_PC_write, wb_PC_write;

    //for SVA driver
    assign Control_Mux_SVA = my_cpu.Control_Mux;

    // Delay 1: ID → EX 
    always @(posedge clk) begin
        ex_opcode   <= my_cpu.id_instr[6:0];
        ex_rs1_spy  <= my_cpu.id_instr[19:15];
        ex_rs2_spy  <= my_cpu.id_instr[24:20];
        ex_funct3   <= my_cpu.id_instr[14:12];
        ex_funct7   <= my_cpu.id_instr[31:25];
        ex_PC_write <= my_cpu.PCWrite;
    end

    // Delay 2: EX → MEM
    always @(posedge clk) begin
        mem_opcode   <= ex_opcode;
        mem_rs1_spy  <= ex_rs1_spy;
        mem_rs2_spy  <= ex_rs2_spy;
        mem_funct3   <= ex_funct3;
        mem_funct7   <= ex_funct7;
        mem_PC_write <= ex_PC_write;
    end

    // Delay 3: MEM → WB
    always @(posedge clk) begin
        wb_opcode   <= mem_opcode;
        wb_rs1      <= mem_rs1_spy;
        wb_rs2      <= mem_rs2_spy;
        wb_funct3   <= mem_funct3;
        wb_funct7   <= mem_funct7;
        wb_PC_write <= mem_PC_write;
    end

    // ---------- Delay chain: EX → MEM → WB ----------

    logic [31:0] mem_imm,    wb_imm;
    logic        mem_branch, wb_branch;
    logic [1:0]  mem_forward_A, wb_forward_A;
    logic [1:0]  mem_forward_B, wb_forward_B;

    always @(posedge clk) begin
        mem_imm    <= my_cpu.ex_imm_ext;
        mem_branch <= my_cpu.ex_branch;
        mem_forward_A <= my_cpu.forward_A;
        mem_forward_B <= my_cpu.forward_B;
    end
    always @(posedge clk) begin
        wb_imm    <= mem_imm;
        wb_branch <= mem_branch;
        wb_forward_A <= mem_forward_A;
        wb_forward_B <= mem_forward_B;
    end

    // ---------- Delay chain: MEM → WB  ----------

    logic        wb_MemWrite;
    logic [31:0] wb_mem_addr;
    logic [31:0] wb_mem_data;

    always @(posedge clk) begin
        wb_MemWrite  <= my_cpu.mem_MemWrite;
        wb_mem_addr  <= my_cpu.mem_alu_result;
        wb_mem_data  <= my_cpu.mem_rs2_data;
    end

    // ---------- PC delay chain: IF → ID → EX → MEM → WB  ----------
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
    // Drive interface signals
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

            // Decoded fields 
            intf.monitor_opcode    <= wb_opcode;
            intf.monitor_rs1       <= wb_rs1;
            intf.monitor_rs2       <= wb_rs2;
            intf.monitor_funct3    <= wb_funct3;
            intf.monitor_funct7    <= wb_funct7;
            intf.monitor_imm       <= wb_imm;

            // --- MEM stage spy ---
            intf.monitor_mem_write <= wb_MemWrite;
            intf.monitor_mem_addr  <= wb_mem_addr;
            intf.monitor_mem_data  <= wb_mem_data;

            // --- Branch ----
            intf.monitor_branch    <= wb_branch;
            // --- Forwarding and stall signals ---
            intf.monitor_forward_A <= wb_forward_A;
            intf.monitor_forward_B <= wb_forward_B;
            intf.monitor_PC_write  <= wb_PC_write;
        end
    end

    cpu_env env;

    initial begin
        clk = 0;
        env = new(intf);
        env.build();
        env.gen.num_instr = 3000;
        env.run();// for task run randomize
        //env.run_direct(); for task run direct
        $finish;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
    end

endmodule
