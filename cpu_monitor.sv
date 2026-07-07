
class cpu_monitor;

    //1. trans
    cpu_transaction tr;
    //2. mailbox
    mailbox #(cpu_transaction) montoscb_mbx;
    //3. virtual interface and coverage
    virtual cpu_if vif;
    cpu_coverage cov;
    //4. constructor
    function new(mailbox #(cpu_transaction) mbx, virtual cpu_if vif, cpu_coverage cov);
        this.montoscb_mbx = mbx;
        this.vif = vif;
        this.cov = cov;
    endfunction
    //5.task run
    task run();
        $display("Monitor activated");
        forever begin
            // wait 1 clock
            @(vif.cb_monitor);  
            //check for R,I,LW
            if(vif.cb_monitor.monitor_reg_write && (vif.cb_monitor.monitor_rd != 5'b0)) begin
                tr            = new();
                tr.instr      = vif.cb_monitor.monitor_instr;
                tr.pc         = vif.cb_monitor.monitor_pc;
                tr.pc_next    = vif.cb_monitor.monitor_pc_next;
                tr.opcode     = vif.cb_monitor.monitor_opcode;
                tr.rd         = vif.cb_monitor.monitor_rd;
                tr.rs1        = vif.cb_monitor.monitor_rs1;
                tr.rs2        = vif.cb_monitor.monitor_rs2;
                tr.funct3     = vif.cb_monitor.monitor_funct3;
                tr.funct7     = vif.cb_monitor.monitor_funct7;
                tr.imm        = vif.cb_monitor.monitor_imm[11:0];
                tr.write_data = vif.cb_monitor.monitor_rd_data;
                tr.reg_write  = 1'b1;
                tr.forward_A    = vif.cb_monitor.monitor_forward_A;
                tr.forward_B    = vif.cb_monitor.monitor_forward_B;
                tr.PC_write     = vif.cb_monitor.monitor_PC_write;

                $display("Monitor captured [REG WRITE]:time: %0t | PC=0x%b | PC_Next=0x%b | Instr=0x%8h | rd=x%0d | data=0x%8h | mem_addr = 0x%d | funct7 = 0x%b | funct3 = 0x%b " ,
                         $time,
                         vif.cb_monitor.monitor_pc,
                         vif.cb_monitor.monitor_pc_next,
                         vif.cb_monitor.monitor_instr,
                         vif.cb_monitor.monitor_rd,
                         vif.cb_monitor.monitor_rd_data,
                         vif.cb_monitor.monitor_mem_addr,
                         vif.cb_monitor.monitor_funct7,
                         vif.cb_monitor.monitor_funct3);
                cov.sample(tr);
                montoscb_mbx.put(tr);
            end
            //check for SW
            else if(vif.cb_monitor.monitor_mem_write) begin
                tr          = new();
                tr.instr    = vif.cb_monitor.monitor_instr;
                tr.pc       = vif.cb_monitor.monitor_pc;
                tr.pc_next  = vif.cb_monitor.monitor_pc_next;
                tr.opcode   = vif.cb_monitor.monitor_opcode;
                tr.rs1      = vif.cb_monitor.monitor_rs1;
                tr.rs2      = vif.cb_monitor.monitor_rs2;
                tr.funct3   = vif.cb_monitor.monitor_funct3;
                tr.imm      = vif.cb_monitor.monitor_imm[11:0];
                tr.mem_addr = vif.cb_monitor.monitor_mem_addr;
                tr.mem_data = vif.cb_monitor.monitor_mem_data;
                tr.forward_A    = vif.cb_monitor.monitor_forward_A;
                tr.forward_B    = vif.cb_monitor.monitor_forward_B;
                tr.PC_write     = vif.cb_monitor.monitor_PC_write;
                
                $display("Monitor captured [MEM WRITE]:time: %0t | PC = 0x%b | PC Next = 0x%b | Instruction = 0x%8h | Memory Address = 0x%b | Memory Data = 0x%8h | funct3 = 0x%b",
                         $time, 
                         vif.cb_monitor.monitor_pc,
                         vif.cb_monitor.monitor_pc_next,
                         vif.cb_monitor.monitor_instr,
                         vif.cb_monitor.monitor_mem_addr,
                         vif.cb_monitor.monitor_mem_data,
                         vif.cb_monitor.monitor_funct3);
                cov.sample(tr);
                montoscb_mbx.put(tr);
            end
            //check for Branch
            else if(vif.cb_monitor.monitor_branch) begin
                tr = new();
                tr.instr = vif.cb_monitor.monitor_instr;
                tr.imm = vif.cb_monitor.monitor_imm;
                tr.branch = vif.cb_monitor.monitor_branch;
                tr.pc = vif.cb_monitor.monitor_pc;
                tr.pc_next = vif.cb_monitor.monitor_pc_next;
                tr.opcode = vif.cb_monitor.monitor_opcode;
                tr.rs1 = vif.cb_monitor.monitor_rs1;
                tr.rs2 = vif.cb_monitor.monitor_rs2;
                tr.forward_A = vif.cb_monitor.monitor_forward_A;
                tr.forward_B = vif.cb_monitor.monitor_forward_B;
                tr.PC_write = vif.cb_monitor.monitor_PC_write;

                $display("Monitor captured [BRANCH]:time: %0t | PC = 0x%b | PC Next = 0x%b | Instruction = 0x%8h | Immediate = 0x%0d", 
                         $time,
                         vif.cb_monitor.monitor_pc,
                         vif.cb_monitor.monitor_pc_next,
                         vif.cb_monitor.monitor_instr, 
                         vif.cb_monitor.monitor_imm,
                         vif.cb_monitor.monitor_branch);
                cov.sample(tr);
                montoscb_mbx.put(tr);
            end
        end
    endtask
endclass
