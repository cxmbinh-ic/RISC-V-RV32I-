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
// decoded instruction fields — aligned tại WB stage bởi tb_top
logic [6:0]  monitor_opcode;
logic [4:0]  monitor_rs1;
logic [4:0]  monitor_rs2;
logic [2:0]  monitor_funct3;
logic        monitor_funct7b5;
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
      monitor_imm, monitor_branch,
      monitor_opcode, monitor_rs1, monitor_rs2, monitor_funct3, monitor_funct7b5;
endclocking
endinterface