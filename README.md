# RV32I 5-Stage Pipelined CPU — SystemVerilog Testbench + SVA Checker

A functional-coverage-driven, class-based SystemVerilog testbench **plus a
`bind`-based SystemVerilog Assertions (SVA) checker**, for a 5-stage
pipelined RISC-V (RV32I subset) CPU — covering hazard detection, data
forwarding, branch resolution, and a golden-model scoreboard.

---

## 1. Project Overview

This repo contains:

- **`design.sv`** — the DUT: a classic 5-stage pipelined RV32I core
  (`rv32i_top`), with IF/ID/EX/MEM/WB pipeline registers, forwarding, hazard
  detection/stalling, and branch resolution.
- A **class-based (non-UVM) testbench** built around the standard
  generator → driver → monitor → scoreboard → coverage architecture,
  connected through mailboxes and a virtual interface.
- **`cpu_sva.sv`** — a standalone SVA checker module (`rv32i_top_checker`),
  attached to the DUT via `bind`, implementing 24 properties (F1–F24) that
  directly check reset behavior, load-use hazard stalling, data forwarding,
  and branch resolution at the signal/cycle level — independent of the
  class-based testbench above.

The testbench randomly generates legal RV32I instructions, drives them into
instruction memory, lets the pipeline execute them, snoops internal pipeline
signals through a "spy chain" in `tb_top`, and checks results against a
golden reference model (register file + data memory) in the scoreboard.
Meanwhile, the SVA checker watches the same internal pipeline signals cycle
by cycle, catching structural/timing violations (wrong stall, wrong forward
selection, wrong flush behavior) that a data-correctness scoreboard alone
can miss.

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

JAL/JALR and LUI/AUIPC are **not implemented in the RTL** (confirmed by
`control_unit`'s opcode decode falling to `default` for those encodings) and
are therefore out of scope for both the testbench and the SVA checker in
this revision.

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

Key hazard/forwarding features exercised by both the testbench and the SVA
checker:
- **Data forwarding** from EX/MEM and MEM/WB stages into the ALU inputs.
- **Load-use stall** via `PCWrite` / `IF_ID_Write` / `Control_Mux` gating.
- **Branch resolution** in EX stage (`branch_taken`, `ex_zero`), with PC
  redirect and IF/ID + ID/EX flush.

---

## 4. Testbench Architecture

```
tb_top
 ├─ cpu_if            (interface + clocking blocks for driver/monitor)
 ├─ rv32i_top         (DUT instance)
 │   └─ rv32i_top_checker   (bound in via cpu_sva.sv, not instantiated here)
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
| `cpu_sva.sv` | **SVA checker** | `rv32i_top_checker` — 24 concurrent-assertion properties (F1–F24) covering reset, load-use hazard stalling, forwarding correctness (mux-select **and** data value), branch resolution/flush, and stall×branch interaction; attached via `bind rv32i_top rv32i_top_checker checker_inst (.*);` |
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

The SVA checker does **not** need this spy chain — it taps ID/EX/MEM/WB
pipeline register signals directly, at their natural stage, since concurrent
assertions are evaluated cycle-by-cycle rather than needing everything
re-aligned to a single retirement point.

---

## 5. SVA Checker (`cpu_sva.sv`)

A `bind`-based checker module, `rv32i_top_checker`, attaches to every
instance of `rv32i_top` without any modification to `design.sv`:

```systemverilog
bind rv32i_top rv32i_top_checker checker_inst (.*);
```

It implements **24 properties (F1–F24)**, grouped as follows:

| Group | IDs | Checks |
|---|---|---|
| Reset | F1–F4 | PC clears to 0; IF/ID, ID/EX, EX/MEM, MEM/WB pipeline registers clear control fields to 0/NOP; register file `x0`–`x31` clears to 0; hazard unit outputs return to default (no-stall) one cycle after reset |
| Load-use hazard | F5–F10 | Stall triggers correctly on rs1/rs2 matches (with correct opcode-class gating for rs2), does **not** trigger on I/L-type rs2 or on non-hazards (false-stall check), lasts exactly one cycle, and holds PC/IF-ID during the stall |
| Forwarding | F11–F17 | Correct forward-select for MEM-stage and WB-stage sources, MEM-over-WB priority when both hazards exist, no forwarding on `rd == x0` or on no pending write, and — critically — that the **forwarded data value itself** is correct (not just that the mux selected the right source) |
| Branching | F18–F22 | Branch resolves via `ex_zero`; taken branch produces a NOP in IF/ID and ID/EX the following cycle; PC redirects to the correct target; not-taken branch continues as `pc + 4`; B-type immediate is correctly shaped/sign-extended |
| Cross-cutting | F23–F24 | Stall and branch-taken control signals never assert simultaneously (structural mutual-exclusivity check); a second load-use hazard immediately following a resolved stall triggers its own independent stall |

**Simulator note:** XSim's `$past()` support proved unreliable across
multiple properties in this file, so "previous cycle" values (`prev_pc`,
`prev_ex_pc`, `prev_ex_imm_ext`, etc., used in F20/F21) are tracked manually
via shadow registers in an ordinary `always @(posedge clk)` block instead of
`$past()`. Sequence local variables were avoided for the same reason — F24
uses a fixed-offset `##1 ##1` sequence shape rather than a counted/unbounded
repetition, which is why it currently checks exactly two chained hazards
rather than an arbitrary-length chain.

**Known open item:** F23 checks that `Control_Mux` and `branch_taken` are
never both asserted in the same cycle — i.e., it confirms the two control
paths are structurally exclusive in this RTL. It does **not** yet define or
check *what the correct resolution should be* if a stall and a branch
genuinely needed to overlap; that's tracked as an open question in the
verification plan rather than a closed assertion.

---

## 6. Verification Flow

1. **Generate** — `cpu_gen` randomizes `cpu_transaction`s (default `num_instr
   = 2000`, set in `tb_top`) and encodes them into 32-bit instruction words.
2. **Drive** — `cpu_driver` holds reset for 2 cycles, then loads each
   instruction word into `IMEM` at sequential addresses, then releases reset.
3. **Execute** — the DUT pipeline fetches/decodes/executes instructions,
   handling hazards and forwarding internally, while the SVA checker
   evaluates F1–F24 against internal pipeline signals every cycle.
4. **Spy/Align** — `tb_top`'s delay chains propagate ID-stage decode info and
   EX/MEM-stage forwarding/branch info down to the WB stage (for the
   class-based scoreboard/coverage path only — independent of the SVA
   checker).
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
   report. SVA assertion failures (if any) print inline via `$error` during
   the run, tagged by feature ID (e.g. `[F5]`, `[F20]`).

---

## 7. Functional Coverage Model

Defined in `cpu_coverage.sv`, sampled once per retired (WB-stage)
instruction:

- **`opcode_cp`** — R/I/L/S/B type coverage
- **`rd_cp` / `rs1_cp` / `rs2_cp`** — register operand coverage (all 32 regs)
- **`funct3_cp` / `funct7_cp`** — function-field coverage
- **`opcode_funct3_funct7_cross`** — cross coverage of legal opcode/funct3/funct7 combinations (illegal combinations excluded via `ignore_bins`)
- **`opcode_rd_cross`** — destination register usage per instruction type
- **`forward_cp`** — forwarding path exercised (none / forward-A / forward-B)
- **`stall_cp`** — pipeline stall vs. no-stall cycles (via `PC_write`)

> **Known bug (flagged, not yet fixed):** `forward_cp` is coded as
> `coverpoint {forward_A, forward_B}` with only 3 bins defined, but the
> concatenation of two 2-bit signals is actually 4 bits wide (16 possible
> values) — so this coverpoint is not sampling the full forwarding state
> space as intended. Planned fix: split into separate `forward_A_cp` /
> `forward_B_cp` coverpoints.

---

## 8. How to Run

This testbench and checker are run using **Xilinx Vivado Simulator (xsim)**.

1. Open Vivado and create a new project (or a scratchpad simulation-only project).
2. Add `design.sv`, `cpu_sva.sv`, and `tb_top.sv` as simulation sources (the
   `` `include `` directives in `tb_top.sv` pull in the rest of the class
   files automatically, so they just need to sit in the same directory).
3. Set `tb_top` as the top module for simulation.
4. Run Behavioral Simulation (setting run Run simulation -> xsim.simulate.xsim.more_options*: -sv_seed random, then run until you find a bug or full coverage and no bug)(`Run Simulation` → `Run Behavioral Simulation`).
   The SVA checker attaches automatically via `bind` — no extra
   instantiation or top-module changes are needed.
5. Let the simulation run to completion (`run -all`, or set the run time long
   enough to reach the `$finish` call) to get the scoreboard, coverage, and
   assertion pass/fail report.

**Requirements:**
- A `program.hex` file in the run directory (loaded by `IMEM` via
  `$readmemh`) — used only for any fixed pre-load; the testbench itself
  writes randomized instructions directly into `IMEM` at runtime.
- Waveform dump is enabled by default (`dump.vcd`, full hierarchy). The
  bound checker instance appears nested under the DUT instance path in the
  waveform viewer (e.g. `tb_top.<dut_instance>.checker_inst`).

**Key parameters to tune** (in `tb_top.sv`):
- `env.gen.num_instr` — number of random instructions to generate (default 2000)
- The `repeat(5000) @(posedge vif.clk)` drain period after generation finishes, to let the last instructions clear the pipeline before reporting

---

## 9. Sample Output

```
Scoreboard Summary: Total=516 | PASS=516 | FAIL=0
=================================================
[OVERALL COVERAGE] CPU Coverage: 99.80%
[COVERAGE DETAILS] opcode coverage: 100.00%
[COVERAGE DETAILS] rd coverage: 100.00%
[COVERAGE DETAILS] rs1 coverage: 100.00%
[COVERAGE DETAILS] rs2 coverage: 100.00%
[COVERAGE DETAILS] funct3 coverage: 100.00%
[COVERAGE DETAILS] funct7 coverage: 100.00%
[COVERAGE DETAILS] opcode x funct3 x funct7 cross coverage: 100.00%
[COVERAGE DETAILS] opcode x rd cross coverage: 97.85%
[COVERAGE DETAILS] forwarding A coverage: 100.00%
[COVERAGE DETAILS] forwarding B coverage: 100.00%
[COVERAGE DETAILS] stall coverage: 100.00%
[ENVIRONMENT] Testbench finished.
```

No `[F1]`–`[F24]` assertion errors printed during the run indicates all SVA
properties held across the full random regression.

---

## 10. Possible Extensions

- Add JAL/JALR and remaining B-type branches (BNE, BLT, BGE, BLTU, BGEU) —
  and their corresponding F-series properties in `cpu_sva.sv`
- Extend the golden data memory / register file to model unaligned access checks
- Generalize F24 to an arbitrary-length chain of back-to-back load-use
  hazards using a counted sequence local variable, rather than the current
  fixed two-hazard shape
- Define and assert expected behavior for the stall/branch same-cycle
  interaction (currently F23 only confirms the two conditions are
  structurally exclusive, not that a defined resolution was verified)
- Move from mailbox-based classes to a full UVM environment (sequencer/agent/env) for reuse
