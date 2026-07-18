interface cpu_if(input logic clk);
logic reset;
logic [31:0] drv_instr;
logic [9:0]  drv_instr_addr;
//for monitor
logic [31:0] monitor_pc;
logic [31:0] monitor_pc_next;
logic [31:0] monitor_instr;
logic        monitor_reg_write;
logic [4:0]  monitor_rd;
logic [31:0] monitor_rd_data;
logic        monitor_mem_write;
logic [31:0] monitor_mem_addr;
logic [31:0] monitor_mem_data;
logic [31:0] monitor_imm;
//for branch
logic        monitor_branch;
//for scoreboard checking branch
logic        monitor_branch_taken;
logic [31:0] monitor_id_pc;
logic [31:0] monitor_id_pc_next;
logic [31:0] monitor_mem_pc;
logic [31:0] monitor_mem_pc_next;
// decoded instruction fields
logic [6:0]  monitor_opcode;
logic [4:0]  monitor_rs1;
logic [4:0]  monitor_rs2;
logic [2:0]  monitor_funct3;
logic [6:0]  monitor_funct7;
//checking coverage forward and stall
logic [1:0]  monitor_forward_A;
logic [1:0]  monitor_forward_B;
logic        monitor_PC_write;
// for real time stall for SVA
logic        Control_Mux_SVA;
//clocking driver
clocking cb_driver @(posedge clk);
default input #1step output #1ns;
output reset, drv_instr, drv_instr_addr;
endclocking
//clocking monitor
clocking cb_monitor @(posedge clk);
default input #1step output #1ns;
input monitor_pc, monitor_pc_next, monitor_instr, monitor_reg_write, monitor_rd,
      monitor_rd_data, monitor_mem_write, monitor_mem_addr, monitor_mem_data,
      monitor_imm, monitor_branch, monitor_opcode, monitor_rs1, monitor_rs2, monitor_funct3, monitor_funct7,
      monitor_forward_A, monitor_forward_B, monitor_PC_write,
      monitor_branch_taken, monitor_id_pc, monitor_id_pc_next, monitor_mem_pc, monitor_mem_pc_next ;
endclocking
endinterface
