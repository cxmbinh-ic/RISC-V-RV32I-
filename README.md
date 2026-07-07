# RV32I 5-Stage Pipelined CPU — SystemVerilog Testbench

A functional-coverage-driven, class-based SystemVerilog testbench for a 5-stage
pipelined RISC-V (RV32I subset) CPU, including hazard detection, data
forwarding, and a golden-model scoreboard.

---

## 1. Project Overview

This repo contains:

- **`design.sv`** — the DUT: a classic 5-stage pipelined RV32I core
  (`rv32i_top`), with IF/ID/EX/MEM/WB pipeline registers, forwarding, hazard
  detection/stalling, and branch resolution.
- A **class-based (non-UVM) testbench** built around the standard
  generator → driver → monitor → scoreboard → coverage architecture,
  connected through mailboxes and a virtual interface.

The testbench randomly generates legal RV32I instructions, drives them into
instruction memory, lets the pipeline execute them, snoops internal pipeline
signals through a "spy chain" in `tb_top`, and checks results against a
golden reference model (register file + data memory) in the scoreboard.

---

## 2. Supported Instructions

The instruction generator (`cpu_trans_rilsb.sv`) constrains `rand` fields to
produce only legal, DUT-supported encodings:

| Type | Opcode      | Instructions |
|------|-------------|--------------|
| R    | `0110011`   | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU |
| I    | `0010011`   | ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTUI |
| L    | `0000011`   | LW |
| S    | `0100011`   | SW |
| B    | `1100011`   | BEQ (funct3 = `000` only) |

Additional constraints ensure `rd != x0` for register-writing instructions,
legal `funct3`/`funct7` combinations per opcode, and safe/in-range immediates
(so loads/stores stay within the memory bounds modeled by the scoreboard).

---

## 3. Design Under Test (`design.sv`)

`rv32i_top` is a textbook 5-stage RISC-V pipeline:

```
IF  →  ID  →  EX  →  MEM  →  WB
```

| Module | Role |
|---|---|
| `pc` | Program counter register with stall enable (`PCWrite`) |
| `IMEM` | 1024-word instruction memory, loaded from `program.hex` |
| `control_unit` | Instruction decode → control signals |
| `rf` | 32-entry register file |
| `imm_gen` | Immediate extraction/sign-extension per instruction format |
| `alu` | Arithmetic/logic unit |
| `hazard_detection_unit` | Detects load-use hazards, stalls PC/IF-ID |
| `hazard_forward` | EX-stage forwarding mux control (`forward_A`/`forward_B`) |
| `data_memory` | Data memory (load/store) |
| `pipe_if_id`, `pipe_id_ex`, `pipe_ex_mem`, `pipe_mem_wb` | Pipeline registers |

Key hazard/forwarding features exercised by the testbench:
- **Data forwarding** from EX/MEM and MEM/WB stages into the ALU inputs.
- **Load-use stall** via `PCWrite` / `IF_ID_Write` gating.
- **Branch resolution** in EX stage (`branch_taken`, `branch_taken_addr`).

---

## 4. Testbench Architecture

```
tb_top
 ├─ cpu_if            (interface + clocking blocks for driver/monitor)
 ├─ rv32i_top         (DUT instance)
 ├─ pipeline spy chain (delay registers that shadow ID→EX→MEM→WB signals)
 └─ cpu_env
     ├─ cpu_gen        → generates randomized cpu_transaction, sends via mailbox
     ├─ cpu_driver     → drives instructions into IMEM, applies reset
     ├─ cpu_monitor    → samples WB-stage results from the interface,
     │                   builds transactions, feeds coverage + scoreboard
     ├─ cpu_coverage   → functional coverage model (covergroup)
     └─ cpu_scoreboard → golden reference model + pass/fail checking
```

### File map

| File | Component | Description |
|---|---|---|
| `cpu_if.sv` | Interface | `cpu_if` — reset/instruction-load signals + full set of pipeline "monitor" signals, with `cb_driver`/`cb_monitor` clocking blocks |
| `cpu_trans_rilsb.sv` | Transaction | `cpu_transaction` — randomizable instruction fields, constraints, instruction encoder (`build_instruction`), and `display()` helper |
| `cpu_gen.sv` | Generator | `cpu_gen` — randomizes and emits `num_instr` transactions to the driver mailbox |
| `cpu_driver.sv` | Driver | `cpu_driver` — asserts reset, preloads instructions into `IMEM` one per cycle via `drv_instr`/`drv_instr_addr` |
| `cpu_monitor.sv` | Monitor | `cpu_monitor` — watches WB-stage signals each clock, classifies the operation (reg-write / mem-write / branch), builds a `cpu_transaction`, samples coverage, and forwards to the scoreboard |
| `cpu_coverage.sv` | Coverage | `cpu_coverage` — covergroup over opcode, rd/rs1/rs2, funct3, funct7, opcode×funct3×funct7 cross, opcode×rd cross, forwarding, and stall |
| `cpu_scb.sv` | Scoreboard | `cpu_scoreboard` — maintains a golden register file (32×32-bit) and golden data memory (64×32-bit), recomputes expected ALU/load/store results, and compares against DUT output |
| `cpu_env.sv` | Environment | `cpu_env` — instantiates and wires all components together, runs them concurrently (`fork...join_any`), then reports scoreboard + coverage results |
| `tb_top.sv` | Top testbench | Clock generation, DUT instantiation, IMEM preload logic, the pipeline "spy chain" that delays internal DUT signals to align them with the WB stage, and environment invocation |
| `design.sv` | DUT | `rv32i_top` and all submodules (5-stage pipelined RV32I core) |

### Why the "spy chain"?

The monitor only has access to interface (`cpu_if`) signals, which are
registered at the WB stage. Since `id_instr`, forwarding signals, branch
info, etc. are only naturally available earlier in the pipeline (ID/EX/MEM),
`tb_top` implements a chain of `always @(posedge clk)` shift registers that
delay each signal by the correct number of cycles so it lines up with the
instruction reaching WB. This lets the monitor observe a consistent, fully
decoded view of each instruction at the moment its result is committed.

---

## 5. Verification Flow

1. **Generate** — `cpu_gen` randomizes `cpu_transaction`s (default `num_instr
   = 2000`, set in `tb_top`) and encodes them into 32-bit instruction words.
2. **Drive** — `cpu_driver` holds reset for 2 cycles, then loads each
   instruction word into `IMEM` at sequential addresses, then releases reset.
3. **Execute** — the DUT pipeline fetches/decodes/executes instructions,
   handling hazards and forwarding internally.
4. **Spy/Align** — `tb_top`'s delay chains propagate ID-stage decode info and
   EX/MEM-stage forwarding/branch info down to the WB stage.
5. **Monitor** — each cycle, `cpu_monitor` classifies the retiring
   instruction (register write / memory write / branch), packages it as a
   `cpu_transaction`, and:
   - samples the coverage model, and
   - sends it to the scoreboard.
6. **Score** — `cpu_scoreboard` recomputes the expected result using its own
   golden register file / memory and compares against the DUT's actual
   output, incrementing `finish_count`/`error_count`.
7. **Report** — after generation finishes (+5000 extra cycles to drain the
   pipeline), `cpu_env` prints the scoreboard summary and full coverage
   report.

---

## 6. Functional Coverage Model

Defined in `cpu_coverage.sv`, sampled once per retired (WB-stage)
instruction:

- **`opcode_cp`** — R/I/L/S/B type coverage
- **`rd_cp` / `rs1_cp` / `rs2_cp`** — register operand coverage (all 32 regs)
- **`funct3_cp` / `funct7_cp`** — function-field coverage
- **`opcode_funct3_funct7_cross`** — cross coverage of legal opcode/funct3/funct7 combinations (illegal combinations excluded via `ignore_bins`)
- **`opcode_rd_cross`** — destination register usage per instruction type
- **`forward_cp`** — forwarding path exercised (none / forward-A / forward-B)
- **`stall_cp`** — pipeline stall vs. no-stall cycles (via `PC_write`)

---

## 7. How to Run

This testbench is run using **Xilinx Vivado Simulator (xsim)**.

1. Open Vivado and create a new project (or a scratchpad simulation-only project).
2. Add `design.sv` and `tb_top.sv` as simulation sources (the `` `include ``
   directives in `tb_top.sv` pull in the rest of the class files automatically,
   so they just need to sit in the same directory).
3. Set `tb_top` as the top module for simulation.
4. Run Behavioral Simulation (`Run Simulation` → `Run Behavioral Simulation`).
5. Let the simulation run to completion (`run -all`, or set the run time long
   enough to reach the `$finish` call) to get the scoreboard and coverage report.

**Requirements:**
- A `program.hex` file in the run directory (loaded by `IMEM` via
  `$readmemh`) — used only for any fixed pre-load; the testbench itself
  writes randomized instructions directly into `IMEM` at runtime.
- Waveform dump is enabled by default (`dump.vcd`, full hierarchy).

**Key parameters to tune** (in `tb_top.sv`):
- `env.gen.num_instr` — number of random instructions to generate (default 2000)
- The `repeat(5000) @(posedge vif.clk)` drain period after generation finishes, to let the last instructions clear the pipeline before reporting

---

## 8. Sample Output

```
[ENVIRONMENT] Launching all parallel components...
STARTING GENERATING CPU INSTR
........
Scoreboard Summary: Total=2092 | PASS=2092 | FAIL=0
=================================================
[OVERALL COVERAGE] CPU Coverage: 100.00%
[COVERAGE DETAILS] opcode coverage: 100.00%
[COVERAGE DETAILS] rd coverage: 100.00%
[COVERAGE DETAILS] rs1 coverage: 100.00%
[COVERAGE DETAILS] rs2 coverage: 100.00%
[COVERAGE DETAILS] funct3 coverage: 100.00%
[COVERAGE DETAILS] funct7 coverage: 100.00%
[COVERAGE DETAILS] opcode x funct3 x funct7 cross coverage: 100.00%
[COVERAGE DETAILS] opcode x rd cross coverage: 100.00%
[COVERAGE DETAILS] forwarding coverage: 100.00%
[COVERAGE DETAILS] stall coverage: 100.00%
[ENVIRONMENT] Testbench finished.
$finish called at time : 99990 ns : File "E:/verilog/RV32I_testbench/tb_top.sv" Line 188
```

---

## 9. Possible Extensions

- Add JAL/JALR and remaining B-type branches (BNE, BLT, BGE, BLTU, BGEU)
- Extend the golden data memory / register file to model unaligned access checks
- Add assertions (SVA) for hazard/forwarding control signals directly at the DUT boundary
- Move from mailbox-based classes to a full UVM environment (sequencer/agent/env) for reuse
