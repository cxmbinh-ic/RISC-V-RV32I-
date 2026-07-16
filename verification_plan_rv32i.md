# Verification Plan — RV32I 5-Stage Pipeline Core (`rv32i_top`)

**Source documents:** `mas_rv32i_pipeline.md` (spec), `design.sv` (RTL), existing testbench (`cpu_gen/driver/monitor/scb/coverage/env.sv`)
**Status:** Draft v1 — cross-checked against RTL, not just the spec. Items where the spec and RTL disagree, or where the existing testbench has a gap, are called out explicitly rather than silently assumed.

---

## 1. Scope

**In scope:** Functional correctness of hazard detection, forwarding, branch resolution/flush, and reset behavior in `rv32i_top`, for R-type, I-type, loads (LW), stores (SW), and branches (BEQ-style, since `imm_gen`/`control_unit` only decode one branch immediate shape and the ALU's only comparison funct3 wired into `control_unit`'s B-type path is effectively equality via `ALUOp=01→ALUControl=SUB`, `Zero` flag).

**Out of scope (per MAS §1/§5):** JAL/JALR, LUI/AUIPC, timing/synthesis closure, any external memory interface.

**RTL cross-check finding:** `control_unit`'s opcode `case` statement (design.sv, module 4) has no entry for opcode `7'b1101111` (JAL) or `7'b0110111`/`7'b0010111` (LUI/AUIPC) — it falls to `default` (everything deasserted). This **confirms** the MAS's hedge in §5 ("jumps... lower priority, check with architecture owner") — the RTL as-is does not implement them. Flagged in Section 6 as a closed question rather than an open one: **jumps are out of scope for this drop**, confirmed by RTL, not just by spec wording.

---


## 2. Feature List

Broken into independently-testable units, including the negative/false cases the MAS only implies.

### 2.1 Reset
| ID | Feature |
|---|---|
| F1 | PC clears to 0 on reset |
| F2 | All pipeline registers (IF/ID, ID/EX, EX/MEM, MEM/WB) clear control fields (`RegWrite`, `MemWrite`, `MemRead`, `Branch`) to 0 on reset |
| F3 | Register file `x0`–`x31` clears to 0 on reset |
| F4 | Reset asserted **mid-instruction / mid-stall** does not leave the pipeline in an inconsistent state (e.g., a stall's `Control_Mux` doesn't get "stuck" across reset) |

### 2.2 Load-Use Hazard
| ID | Feature |
|---|---|
| F5 | Stall triggers when EX-stage load's `rd` matches ID-stage `rs1` |
| F6 | Stall triggers when EX-stage load's `rd` matches ID-stage `rs2`, **and** ID-stage opcode is R-type, B-type, or S-type |
| F7 | Stall does **not** trigger when ID-stage opcode is I-type/L-type matching on rs2 only (per RTL: `hazard_detection_unit` only checks rs2 match for R/B/S-type — this is narrower than "any instruction using rs2", worth confirming intentional) |
| F8 | Stall does not trigger when there is no load-use dependency (false-stall check) |
| F9 | Stall lasts exactly one cycle; a bubble (NOP-equivalent control signals) lands in EX the cycle after |
| F10 | PC and IF/ID instruction are held (not advanced) during the stall cycle |

### 2.3 Forwarding
| ID | Feature |
|---|---|
| F11 | MEM-stage result forwards to EX `rs1` operand when `mem_rd == ex_rs1` and `mem_RegW1rite` |
| F12 | MEM-stage result forwards to EX `rs2` operand under the mirrored condition |
| F13 | WB-stage result forwards to EX `rs1`/`rs2` when no MEM-stage hazard exists but a WB-stage one does |
| F14 | MEM-stage forward takes priority over WB-stage forward when both hazards exist simultaneously |
| F15 | No forwarding occurs when `rd == 0` (writes to `x0` are not treated as real dependencies) |
| F16 | No forwarding occurs when neither MEM nor WB has a pending write to the needed register |
| F17 | The forwarded value that reaches the ALU input is the *correct* value (data check, not just mux-select check) |

### 2.4 Branching
| ID | Feature |
|---|---|
| F18 | Branch is resolved in EX stage via ALU `Zero` flag |
| F19 | Taken branch flushes IF/ID and ID/EX (both must show NOP/deasserted control the cycle after) |
| F20 | Taken branch redirects PC to `ex_pc + ex_imm_ext` |
| F21 | Not-taken branch does **not** flush and PC continues as `pc_current + 4` |
| F22 | Branch immediate is correctly sign-extended and shaped per the B-type encoding in `imm_gen` |

### 2.5 Cross-Cutting / Interaction
| ID | Feature |
|---|---|
| F23 | Load-use stall and branch-taken occurring on the same cycle resolve without corrupting architectural state (flagged as **open interaction**, not yet defined behavior — see Section 6) |
| F24 | Back-to-back load-use hazards (a load feeding a load feeding an ALU op) stall correctly each time, not just once |

---

## 3. Checking Strategy

| Feature IDs | Mechanism | Status in current testbench |
|---|---|---|
| F1–F4 (reset) | **New assertions needed** | Not currently checked anywhere — scoreboard has no reset-phase model |
| F5–F10 (hazard) | **New assertions** (structural, cycle-exact) | `cpu_coverage.sv` has a `stall_cp` coverpoint (hit/no-hit), but nothing checks the stall is *correct*, only that it *happened* |
| F11–F16 (forward select) | **New assertions** | `cpu_coverage.sv` has a `forward_cp` coverpoint — same gap: coverage without correctness checking |
| F17 (forward data value) | **Scoreboard extension**, since this is a data-correctness claim, or an assertion comparing `ex_rs1_data_forwarded` to the golden source directly | Currently **not checked at all** — `cpu_scb.sv` only models R/I-type ALU, LW, SW result correctness; it never inspects whether a forward actually fed the right operand into the ALU in the first place. If the ALU gets the *wrong* forwarded operand but coincidentally produces a value that still matches the golden model on a later check, this hole would hide the bug. |
| F18–F22 (branch) | **New assertions**, plus scoreboard extension for F20 (PC redirect) | **Confirmed gap:** `cpu_scb.sv`'s `run()` task only has `if/else if` branches for opcodes `0110011`, `0010011`, `0000011`, `0100011` — branch opcode `1100011` has **no handling at all**. Branch correctness is currently unchecked by the scoreboard entirely. This makes F18–F22 assertions higher priority, not lower — they're the only checker for this feature class right now. |
| F23–F24 (interaction) | **New assertions**, directed tests specifically targeting the overlap | Not checked; not even covered (no cross-coverage between `stall_cp` and branch activity exists in `cpu_coverage.sv`) |

---

## 4. Test Scenarios

### 4.1 Directed tests (write these first, before trusting random)
| Test | Purpose | Feature(s) |
|---|---|---|
| T1 | `LW x1, 0(x0)` immediately followed by `ADD x2, x1, x1` | F5, F9, F10 |
| T2 | `LW x1, 0(x0)` immediately followed by `SW x1, 0(x2)` (rs2 hazard, S-type) | F6 |
| T3 | `LW x1, 0(x0)` immediately followed by `ADDI x2, x3, 4` (no dependency) | F8 |
| T4 | Two back-to-back `LW`s where the second depends on the first's `rd` | F24 |
| T5 | `ADD x1, x2, x3` immediately followed by `SUB x4, x1, x5` (MEM-stage forward) | F11, F17 |
| T6 | `ADD x1, x2, x3`, one bubble instruction, then `SUB x4, x1, x5` (WB-stage forward) | F13, F17 |
| T7 | `ADD x2, x1, x3` follow two instructions both having rd equal `x1` (MEM and WB forward in simutaneously) | F14 |
| T8 | Any instruction writing `x0` as destination, immediately followed by a consumer of `x0` | F15 |
| T9 | `BEQ` where operands are equal (taken) immediately followed by 2–3 instructions that must be squashed | F18–F20 |
| T10 | `BEQ` where operands are not equal (not taken) | F21 |
| T11 | **The overlap case**: a load-use hazard instruction pair positioned so the stall cycle coincides with a branch resolving in EX | F23 |
| T12 | Assert `reset` mid-stall (assert reset exactly on the stall cycle from T1) | F4 |
| T13 | Assert `reset` mid-branch-flush window | F4 |

### 4.2 Random generation guidance (for `cpu_gen.sv`)
The current generator produces 2000 generic instructions (`env.gen.num_instr = 2000`). For this plan, bias/weight the constraints so random testing actually stresses the features above rather than mostly generating independent, non-hazardous instructions:
- Weight `rd`/`rs1`/`rs2` selection so consecutive instructions share registers more often than uniform-random would produce (hazards are rare in pure uniform-random 32-register selection).
- Explicitly force a percentage of instructions to be loads followed immediately by a consuming instruction.
- Explicitly force a percentage of branches, split roughly evenly between taken/not-taken (data-dependent, so this needs the branch operands constrained, not just the opcode).

---

## 5. Coverage Plan

### 5.1 Already exists in `cpu_coverage.sv` — keep, reuse
- `opcode_cp`, `rd_cp`, `rs1_cp`, `rs2_cp`, `funct3_cp`, `funct7_cp` and their crosses — covers instruction-type diversity (feeds F5–F22 indirectly by ensuring enough instruction variety hits the pipeline).
- `stall_cp` — covers "did a stall happen at all."
- `forward_cp` — covers "did a forward happen at all."

### 5.2 Bug found while reviewing existing coverage (flag for the coverage owner)
`forward_cp` is defined as `coverpoint {tr.forward_A, tr.forward_B}` with only 3 bins (`2'b00`, `2'b01`, `2'b10`) — but `forward_A` and `forward_B` are each 2 bits, so the concatenation `{forward_A, forward_B}` is actually **4 bits wide** (16 possible values), not 2. As written, this coverpoint is almost certainly not sampling what it was intended to (e.g., "forward_A==2'b01 AND forward_B==2'b10 simultaneously" is a real, valid, unrepresented state). This should be split into two separate coverpoints (`forward_A_cp`, `forward_B_cp`) rather than concatenated, or fixed to properly enumerate the 4-bit space.

### 5.3 New coverpoints needed
| Coverpoint | Purpose | Maps to |
|---|---|---|
| `branch_taken_cp` | taken vs. not-taken, both must be hit | F18, F21 |
| `reset_timing_cp` | reset asserted: at idle / mid-stall / mid-branch-flush | F4 |
| `stall_x_branch_cross` | cross of `stall_cp` and `branch_taken_cp` on the same cycle | F23 |
| `forward_x0_cp` | instruction with `rd==0` immediately followed by a consumer of `x0` (confirms F15 is actually exercised, not just implemented) | F15 |
| `back_to_back_load_cp` | two dependent loads in a row | F24 |

---

## 6. Open Questions / Risks

| # | Question | Status |
|---|---|---|
| Q1 | JAL/JALR/LUI/AUIPC — confirmed out of scope by RTL cross-check (Section 1). Should this be formally signed off by the architecture owner, or just noted in this plan? | **Recommend:** get written confirmation before final signoff — "the RTL happens to not implement it" and "it's officially descoped" aren't the same thing if the RTL gets extended later. |
| Q2 | F23 (stall + branch same-cycle) — the MAS explicitly says to "think about" this but doesn't define expected behavior. What *should* happen — does flush override the stall unconditionally? | **Blocking** — needs an answer from the RTL designer before T11 can be written as pass/fail rather than "observe and report." |
| Q3 | F7 — hazard unit only checks rs2 for R/B/S-type, not I/L-type. Is this intentional (I-type doesn't read rs2, so it's a non-issue) or an oversight for some other instruction class? | Likely intentional (I-type genuinely has no rs2 field semantics) — low risk, confirm and close. |
| Q4 | Scoreboard has zero branch-opcode handling (Section 3). Is extending `cpu_scb.sv` in scope for this verification pass, or do assertions alone cover branch correctness for now? | **Recommend:** raise with the DV lead — this is a real coverage-strategy decision, not just an implementation detail. |

---

## 7. Exit / Signoff Criteria

- All F1–F24 have a passing assertion or scoreboard check (Section 3) with zero failures across the full directed test list (Section 4.1) and at least one full random regression (2000+ instructions).
- All coverpoints in Section 5.1 and 5.3 at 100%, or waived with an explicit reason (e.g., a bin genuinely unreachable given ISA scope).
- Q1, Q2, and Q4 formally closed (answer documented, not just discussed) before this plan is marked final.
- No open assertion is left as "observe and report" — F23 in particular must have a defined pass/fail condition before signoff, not just a printed warning.
