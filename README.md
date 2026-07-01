# RV32I 5-Stage Pipelined CPU with SystemVerilog Testbench

A synthesizable **RISC-V RV32I** CPU core implementing a classic 5-stage pipeline (IF → ID → EX → MEM → WB), verified with a hand-rolled **SystemVerilog OOP testbench** (generator → driver → monitor → scoreboard) built around a constrained-random instruction stream and a golden reference model.

---

## Features

### CPU Core (`design.sv`)
- 5-stage pipeline: **IF, ID, EX, MEM, WB**
- Supported RV32I instruction subset:
  - **R-type**: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
  - **I-type**: ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTUI
  - **Load / Store**: LW, SW
  - **Branch**: BEQ, BNE (SUB-based comparison)
- **Hazard handling**
  - Load-use hazard detection with pipeline stall (`hazard_detection_unit`)
  - Full EX-stage forwarding from MEM and WB stages (`hazard_forward`)
  - Control/branch hazard resolved at EX with pipeline flush
- 32-entry register file with `x0` hardwired behavior enforced at write time
- Single-cycle combinational ALU, control unit, and immediate generator
- Instruction memory (1024 words) and data memory (64 words), simulation-only (`$readmemh` / behavioral RAM)

### Verification Environment (SystemVerilog, class-based, non-UVM)
| File | Role |
|---|---|
| `cpu_if.sv` | Virtual interface with `cb_driver` / `cb_monitor` clocking blocks |
| `cpu_trans_rilsb.sv` | `cpu_transaction`: randomizable RV32I instruction with legality constraints, instruction encoder, and disassembly display |
| `cpu_gen.sv` | Generator — produces a constrained-random instruction stream |
| `cpu_driver.sv` | Driver — resets the DUT and loads instructions into instruction memory via the interface |
| `cpu_monitor.sv` | Monitor — samples committed CPU state (register writes, memory writes, branches) aligned at the WB stage |
| `cpu_scb.sv` | Scoreboard — maintains a golden register file + golden RAM model and self-checks every committed instruction |
| `cpu_env.sv` | Environment — wires generator, driver, monitor, and scoreboard together via mailboxes and runs them concurrently |
| `tb_top.sv` | Top-level testbench: instantiates the DUT, drives the clock, spies on internal pipeline signals, and delays them into WB-stage-aligned monitor signals |

**Testbench topology**: `Generator → mailbox → Driver → DUT → (internal spy/delay chain) → Interface → Monitor → mailbox → Scoreboard`

> **Note:** Instruction memory is preloaded via a hierarchical backdoor write (`my_cpu.imem_inst.memory[...]`) during reset, not through a bus transaction. There is no AXI / AHB / APB / Wishbone interface in this design — all communication is point-to-point custom signals plus a simulation-only backdoor load.

---

## Repository Structure

```
.
├── design.sv            # RTL: PC, IMEM, ALU, control unit, register file,
│                         #      immediate generator, hazard units, pipeline
│                         #      registers, data memory, rv32i_top
├── cpu_if.sv             # SV interface + clocking blocks (driver/monitor)
├── cpu_trans_rilsb.sv    # Transaction class (randomized instruction, constraints)
├── cpu_gen.sv            # Generator class
├── cpu_driver.sv         # Driver class
├── cpu_monitor.sv        # Monitor class
├── cpu_scb.sv            # Scoreboard class (golden model + self-check)
├── cpu_env.sv            # Environment class (wires everything together)
├── tb_top.sv             # Top-level testbench module
└── README.md
```

---

## How the Testbench Works

1. **Generate** — `cpu_gen` randomizes `num_instr` legal RV32I instructions (R/I/LW/SW/BEQ/BNE), encodes each into a 32-bit word, and pushes it to the driver via a mailbox.
2. **Drive** — `cpu_driver` asserts `reset`, then loads each generated instruction word into the DUT's instruction memory at sequential addresses, and finally releases `reset`.
3. **Execute** — `rv32i_top` fetches, decodes, executes, and commits instructions through its 5-stage pipeline with hazard stalling and forwarding.
4. **Spy/Align** — `tb_top` taps internal pipeline signals (opcode, rs1/rs2, funct3/7, immediate, PC, memory address/data) and delays them through shift registers so every signal lines up at the WB stage.
5. **Monitor** — `cpu_monitor` samples the WB-aligned signals every clock and classifies each commit as a register write, a memory write (SW), or a resolved branch, forwarding a transaction to the scoreboard.
6. **Score** — `cpu_scoreboard` maintains its own golden register file and golden RAM, independently computes the expected result for each instruction, and compares it against the DUT's actual result, reporting PASS/FAIL and a final summary.

---

## Running the Simulation

This project was developed for **EDA Playground** (or any simulator supporting SystemVerilog classes, interfaces, and clocking blocks, e.g. Questa/VCS/Xcelium).

1. Compile in this order (or use `` `include `` as `tb_top.sv` does):
   ```
   design.sv
   cpu_if.sv
   cpu_trans_rilsb.sv
   cpu_gen.sv
   cpu_driver.sv
   cpu_monitor.sv
   cpu_scb.sv
   cpu_env.sv
   tb_top.sv
   ```
2. Provide a `program.hex` file if `IMEM` is initialized via `$readmemh` (or rely purely on the driver's backdoor load — check `design.sv` / `cpu_driver.sv` for which path is active in your setup).
3. Run simulation; a `dump.vcd` waveform is generated automatically for debugging.
4. Check the scoreboard summary printed at the end of the run:
   ```
   =================================================
   Scoreboard Summary: Total=<N> | PASS=<N> | FAIL=<N>
   =================================================
   ```

---

## Known Limitations / Roadmap

- No memory-mapped or standard bus protocol (AXI-Lite / APB / Wishbone) — the core talks to instruction/data memory over plain address/data wires.
- Instruction preload uses simulation-only hierarchical backdoor access; won't synthesize as-is for FPGA/ASIC bring-up.
- No JAL/JALR, LUI/AUIPC, or CSR support yet — only R/I/L/S/B-type subset.
- No exception/interrupt handling.

**Planned improvements**
- [ ] Add JAL/JALR/LUI/AUIPC support
- [ ] Replace backdoor instruction load with a real memory-mapped load interface
- [ ] Add functional coverage (`covergroup`) for opcode/hazard scenarios
- [ ] Port testbench to UVM
- [ ] FPGA synthesis target with a simple AXI-Lite wrapper for instruction/data memory

---

