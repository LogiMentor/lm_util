# lm_util_lfsr: issue #10 plan (phase A)

Status: plan only, no RTL or test change on this branch yet. Base: `main` at
`b5a6a7c` (tag `v0.1.0`). Branch: `fix/lfsr-reset-and-width`.

All measurements below were made with GHDL 6.0.0 (LLVM, `--std=08`), VUnit
4.7.1, Vivado 2023.1 (`xc7a35tcsg324-1`) and Quartus Prime Lite 23.1std
(MAX 10 `10M08SAE144C8G`), with temporary probes kept outside the repository.
Phase B turns the relevant probes into committed tests (section 3).

## 0. Findings at a glance

| # | Finding | Status |
| --- | --- | --- |
| F1 | Reset drives `rng_o <= f_int2slv(4327, g_data_w)`; `f_int2slv` uses `to_signed`, 4327 needs 14 signed bits: `NUMERIC_STD.TO_SIGNED: vector truncated` for `g_data_w <= 13`, once per clock edge with reset active. | confirmed |
| F2 | 4327 only appears on `rng_o` while reset is active; the state restarts from `seed_i`. Replacing 4327 with 0 leaves the sequence after reset (and after load) identical for every width 1..168. | hypothesis confirmed |
| F3 | Simulation-only: Vivado and Quartus report nothing about the constant and silently synthesize `4327 mod 2^N` (8 bits: `0xE7`, read back from the Vivado netlist). | new |
| F4 | `g_data_w` has only an upper bound (assert `<= 168`). Widths 1 and 2 have no taps: `f_lfsr` returns `'0'` and the output collapses to all zeros after N cycles. `g_data_w = 0` elaborates and fails at the first non-reset edge with an index error; negative values fail with an anonymous bound check. | confirmed |
| F5 | **The width-102 polynomial is not maximal.** The taps reproduce XAPP052 Table 3 row `102,101,36,35`, whose characteristic polynomial factors over GF(2) into degrees 3, 34 and 65. Some seeds cycle with period 7 (shown in simulation). All other widths 3..168 are primitive. | new |
| F6 | `seed_i = 0` (the XOR lock-up state) keeps the register at zero forever, after reset and after load. Only the port comment says "should be nonzero". | confirmed |
| F7 | The state lives in `variable v_rand_tmp`, plus `s_rng_reg`: synthesis builds 2N flip-flops (Vivado 16/128 FF, Quartus 16/128 registers for N = 8/64). The two registers differ only during reset. | new |
| F8 | `s_rng_reg` has a default initial value (`R100`); `R40` (literal 4327); header and docs call the unit "xorshift", which it is not. Quartus warns `10542` on the `v_rand` initial value inside `f_lfsr`. | new |

## 1. Unit analysis

### 1.1 Interface

```vhdl
generic( g_data_w : integer := 32 );
port(
  clk_i   : in  std_logic;                               -- clock
  rst_n_i : in  std_logic;                               -- synchronous, active low
  load_i  : in  std_logic;                               -- load seed
  seed_i  : in  std_logic_vector(g_data_w - 1 downto 0); -- seed
  rng_o   : out std_logic_vector(g_data_w - 1 downto 0)  -- registered output
);
```

- Reset is synchronous, active low, and has priority over `load_i`.
- There is no enable: with `rst_n_i = '1'` and `load_i = '0'` the register
  advances on every rising edge.
- `seed_i` has exactly `g_data_w` bits; a wider or narrower actual is
  rejected by GHDL at elaboration (bound check failure), so width mismatch is
  not a runtime concern.
- `g_data_w` is `integer`, not `positive`/`natural`.

Cycle semantics (all widths, verified):

| Cycle | `rng_o` |
| --- | --- |
| edge with `rst_n_i = '0'` | `4327 mod 2^N`; internal state := `seed_i` |
| first edge after release (`load_i = '0'`) | `step(seed_i)`: the seed itself never appears on `rng_o` after reset |
| edge with `load_i = '1'` | `seed_i` (state and output) |
| following edges | `step(previous)` |
| before the first edge (simulation) | `1` (default initial value of `s_rng_reg`) |
| first edges without any reset or load (simulation) | `U` for N >= 3 (state is uninitialized); N = 1 and 2 go to zeros |

`step(s) = (s(N-2 downto 0) & f_lfsr(s))`, i.e. a Fibonacci LFSR shifting
towards the MSB, new bit in bit 0.

### 1.2 Process structure and coding standard

- One clocked process `proc_rng`. The state is the process variable
  `v_rand_tmp`, read before it is written in the non-reset branch, hence a
  register (Vivado names it `proc_rng.v_rand_tmp_reg[*]`). `s_rng_reg` is a
  second register: in reset it takes the constant, otherwise the new state.
  Vivado: `v_rand_tmp_reg` are 8 `FDRE` (reset loads data through the LUT),
  `s_rng_reg_reg` are `FDSE` on bits 0, 1, 2, 5, 6, 7 and `FDRE` on 3, 4, i.e.
  `0xE7`.
- Coding standard:
  - `R90` "Prefer signals over variables": a preference, not a prohibition.
    A variable that is a register is the case the rule targets.
  - `R100` "Avoid default initialization": violated by
    `s_rng_reg ... := std_logic_vector(to_unsigned(1, g_data_w))`.
  - `R40` "Avoid hard-coded numeric literals": `4327` is an anonymous
    literal with no documented meaning.
  - `4.8` asserts for invalid generics: only the upper bound is asserted.
  - `R20` functions reference only their arguments: `f_lfsr` complies; its
    local `v_rand` initial value triggers Quartus warning `10542`.
- Header: "xorshift random number generator ... produces a sequence of
  2^g_data_w - 1" is inaccurate. It is an LFSR, not Marsaglia's xorshift, and
  the period is `2^N - 1` only for a primitive polynomial and a nonzero seed.
  The same "LFSR/xorshift" wording is in `README.md` and `docs/user_guide.md`.

### 1.3 Feedback, lock-up and polynomials

- Feedback is XOR of the taps; the lock-up state is all zeros. Every tap set
  has an even number of taps, so all ones is not a fixed point.
- Source of the taps: Xilinx XAPP052 (P. Alfke, "Efficient Shift Registers,
  LFSR Counters, and Long Pseudo-Random Sequence Generators", v1.1, 1996),
  Table 3, which lists 1-based taps for an XNOR counter. All 166 rows (3..168)
  were extracted from the published PDF and compared with the RTL: every RTL
  row is the table row minus one. XNOR and XOR with the same taps give
  complementary sequences of the same characteristic polynomial (every row
  has an even number of taps), so the
  table's maximality claim carries over to XOR (lock-up moves from all ones to
  all zeros).
- Independent verification, not relying on the table:
  - a Python model with taps parsed from the RTL matches the RTL output for
    200 steps at every width 1..168 (seeded from a 168-bit pattern);
  - exhaustive period from a nonzero seed: `2^N - 1` for every N in 3..20;
  - primitivity of the characteristic polynomial
    `P(x) = x^N + sum(x^(N-1-i))` over the 0-based taps `i`, for every N in
    3..168: irreducibility (Rabin test) and order `2^N - 1`, using the
    complete prime factorization of `2^N - 1` (from the cyclotomic factors
    `Phi_d(2)`, d | N, all factored; every factor passes `sympy.isprime`,
    deterministic below 2^64 and BPSW above).
  - Result: 165 of 166 primitive. **N = 102 is not**: `P` factors into
    irreducibles of degree 3 (`x^3 + x + 1`), 34 and 65 (factorization
    computed for both the polynomial and its reciprocal). The seed
    `0x25CB972E5CB972E5CB972E5CB9` (102 bits) returns to its first output
    after 7 cycles in GHDL with the unmodified RTL.
  - Among taps of the same shape (`102,101,k,k-1`, 1-based) the only
    primitive choice is `102,101,26,25`; there is no primitive trinomial of
    degree 102.
- Widths 1 and 2: no taps, so the feedback bit is the constant `'0'`. The
  output reaches zero after N edges whatever the seed.

### 1.4 Role of 4327 (probe)

A probe testbench instantiated, for every width 1..168, the unmodified unit
and a copy whose reset assigns `(others => '0')` instead of the constant, with
identical inputs, and drove: reset for 3 edges with a nonzero seed, 200 free
steps, a load of a second seed, 20 steps, a second reset with seed 0, 30 steps.

| Check | Result (all 168 widths) |
| --- | --- |
| `rng_o` during reset | `4327 mod 2^N` (unmodified) and 0 (copy) |
| `rng_o` on the 200 steps after release | identical between the two units |
| `rng_o` on load and 20 steps after | identical; on the load edge `rng_o = seed_i` |
| `NUMERIC_STD.TO_SIGNED: vector truncated` | widths 1..13 only, exactly once per edge in reset (5 per window: 3 + 2) |
| reset with `seed_i = 0`, then free run | `rng_o` stays 0 for both units |

So the hypothesis holds: the constant only defines what consumers see on
`rng_o` while reset is active, not the sequence after it. N = 13 warns but
keeps the bit pattern of 4327 (`to_signed` needs the 14th bit only for the
sign).

### 1.5 Seed behavior

| Seed | Behavior |
| --- | --- |
| 0 (lock-up) | stays 0 after reset or load, forever |
| all ones | normal sequence (not a fixed point with XOR) |
| nonzero, N in 3..168 except 102 | period `2^N - 1` |
| nonzero, N = 102 | period depends on the seed; a period-7 seed exists |
| any, N = 1 or 2 | zeros after N edges |
| wider or narrower vector | rejected at elaboration (port width is `g_data_w`) |

### 1.6 Out-of-range widths (GHDL)

| `g_data_w` | Today |
| --- | --- |
| 169 | `assertion failure: g_data_w out of supported range in f_lfsr` |
| 3..168 | elaborates |
| 1, 2 | elaborates, output collapses to zero |
| 0 | elaborates; first non-reset edge: `index (0) out of bounds (-1 downto 0)` at the feedback assignment |
| -1 | elaboration `bound check failure` at the `s_rng_reg` initial value, no message |

### 1.7 Vendor synthesis today (8 and 64 bits)

| Tool | Result |
| --- | --- |
| Vivado 2023.1 | passes; only `Synth 8-7080` (parallel synthesis, generic). No message about the reset constant. 14 LUT / 16 FF (N = 8), 98 LUT / 128 FF (N = 64). |
| Quartus 23.1std MAX 10 | passes; `Warning (10542)` on `lm_util_lfsr.vhd(67)` (`v_rand` initial value in `f_lfsr`). No message about the reset constant. 17 LE / 16 registers (N = 8), 129 LE / 128 registers (N = 64). |

Both tools synthesize the truncated value; the defect is invisible in
synthesis and only shows as a simulation warning.

### 1.8 Width table

The full table for N = 1..168 is in the appendix. Summary:

| N | Warning | `rng_o` in reset | Taps | Maximal |
| --- | --- | --- | --- | --- |
| 1 | yes | 1 | no | no |
| 2 | yes | 3 | no | no |
| 3..5 | yes | 7 | yes | yes |
| 6 | yes | 39 | yes | yes |
| 7 | yes | 103 | yes | yes |
| 8..12 | yes | 231 | yes | yes |
| 13 | yes | 4327 | yes | yes |
| 14..101, 103..168 | no | 4327 | yes | yes |
| 102 | no | 4327 | yes | **no** |

### 1.9 Other integer-to-vector conversions with generic-dependent widths

Listed only; no change planned in this issue.

- `src/lm_util_lfsr.vhd`: `to_unsigned(1, g_data_w)` (default initial value),
  fine for N >= 1.
- `sim/tb/tb_vu_lm_util_delay*.vhd`: `f_int2slv(0 | 1 | i, g_data_w)` with
  `i <= g_delay`; regression widths 10 and 32, no truncation.
- `sim/tb/tb_vu_lm_util_counter.vhd`: `f_int2slv(g_load_dat, g_data_w)`,
  width 16, no truncation.
- `sim/tb/tb_vu_lm_util_ccd_sync_bus.vhd`: `f_nat2slv(16#A5#, g_bus_width)`
  and `16#3C#`, width 8, no truncation (would warn below 8).
- `sim/tb/tb_vu_lm_util_delay_var.vhd`: `f_nat2slv(g_delay, C_DELAY_W)`,
  width derived from `g_delay_max`, no truncation.
- `sim/tb/tb_vu_lm_util_bitsum.vhd`: `to_unsigned(g_d_in, g_din_w)`; the
  full-level configuration `g_din_w = 15, g_d_in = 65535` needs 16 bits, so
  it truncates (to 32767) with a `TO_UNSIGNED` warning. Candidate for a
  separate issue.

## 2. Options

Options are listed without a choice. "Consumers" are downstream IPs that copy
the unit.

### a) `rng_o` during reset

| Option | During reset | First edge after release | Registers | Notes |
| --- | --- | --- | --- | --- |
| a1. keep `4327 mod 2^N`, computed without warning, e.g. `resize(to_unsigned(4327, 13), g_data_w)` in a named constant | as today | `step(seed_i)` | 2N | Bit-identical to today at every width (warning-free `resize` checked for N = 1..168). Keeps an unexplained constant; `R40` satisfied only by naming it. |
| a2. 0 | 0 | `step(seed_i)` | 2N | Simplest constant, no conversion at all. Reset value changes at every width (4327 is odd, so `4327 mod 2^N` is never 0). All zeros on `rng_o` looks like the lock-up state to a consumer that monitors it. |
| a3. `seed_i` (reset behaves like load) | `seed_i` of the previous edge | `step(seed_i)` | N | One register: output and state are identical in every cycle, so synthesis halves the FFs (to be confirmed by the synthesis case). Reset and load share one semantics. The reset value depends on an input. Changes the reset value at every width unless the seed equals the old constant. |
| a4. new generic for the reset value | configurable | `step(seed_i)` | 2N | Interface change for every consumer; no use case known. |

In every option the sequence after release is unchanged (F2).

### b) Lower bound of `g_data_w`

| Option | Accepted widths | Consequences |
| --- | --- | --- |
| b1. elaboration assert with the real minimum (`3 <= g_data_w <= 168`, `severity failure`, one message for both bounds) | 3..168 | Consumers at 1 or 2 (which got a constant zero) stop at elaboration: breaking. No new logic. For 0 and negative values the assert must be reached before any declaration fails: the default initial value has to go (see d) and phase B must show it with the elaboration checks. Optionally `g_data_w : positive`, which rejects 0 and negatives with the tool's own range message instead of ours. |
| b2. define taps for 1 and 2 (`x + 1`: feedback = bit 0; `x^2 + x + 1`: taps 1, 0) | 1..168 | Maximal at every width: N = 2 has period 3; N = 1 is the constant `'1'` (period `2^1 - 1 = 1`), mathematically maximal but useless. Behavior change for 1 and 2 (from zero to a sequence). The null slices of the shift at N = 1 need a vendor synthesis check. Lower bound becomes 1 (assert as in b1). |

### c) `seed_i = 0` (lock-up)

| Option | Behavior | Cost |
| --- | --- | --- |
| c1. no protection, documented (header, port comment, user guide) | as today | none |
| c2. substitute a fixed nonzero value when loading a zero seed (reset and `load_i`) | never enters lock-up from the seed path | zero detect of `seed_i` (estimate: about `ceil((N-1)/5)` LUT6, i.e. 2 / 13 / 34 at N = 8 / 64 / 168; about N/3 LE on MAX 10) plus a mux that is absorbed in the existing load mux; no FF. Outside the feedback loop. To be measured by the synthesis case. |
| c2'. escape from lock-up at run time: if the state is zero, shift in `'1'` | also recovers from an upset that zeroes the state | same zero detect, but on the state, i.e. in the feedback path (timing at large N). Changes the sequence only for the zero state. |
| c3. simulation assert when a zero seed is loaded (`translate_off/on`, guarded against metavalues) | warns, logic unchanged | none in hardware. Severity to choose; with the TB failing on warnings (section 3) it must be tested as an expected message. |

c3 can be combined with c1 or c2. With a3 and c2, the value shown during
reset with a zero seed must be defined (raw 0 or the substitute).

### d) `variable v_rand_tmp`

The standard prefers signals (`R90`), it does not forbid variables.

| Option | Notes |
| --- | --- |
| d1. keep the variable, document the deviation in a comment (standard section 5) | No change. `R100` (default initial value) can still be fixed independently. |
| d2. rewrite with signals, cycle-for-cycle equivalent: a function `f_lfsr_next(s)` (shift and feedback); reset: `s_state <= seed_i`, `s_rng_reg <=` reset value; load: both `<= seed_i`; otherwise both `<= f_lfsr_next(s_state)`. With a3 a single `s_state` drives `rng_o`. | Same register count as today (or N with a3). Verified by the reference model test at every width and by the synthesis register count. Also remove the default initial value (`R100`): simulation shows `U` instead of `1` before the first reset; on hardware the power-up value follows the tool default (Vivado `INIT`), which only matters without reset. |

### e) `f_int2slv` in `lm_util_pkg`

| Option | Impact on pkg consumers |
| --- | --- |
| e1. leave `f_int2slv` unchanged; the LFSR does not use it (a1 uses `resize(to_unsigned(...))`, a2 and a3 need no conversion) | none; the copied pkg stays compatible. |
| e2. add a new function, e.g. `f_nat2slv_wrap(n, w)` returning `n mod 2^w` without warning | additive, not breaking; but a consumer that copies the new LFSR must also copy the newer pkg. Silent wrap is a semantic some callers may misuse. |
| e3. change `f_int2slv` (silent wrap, or `to_unsigned` for non-negative inputs) | behavior change for every pkg consumer; hides genuine truncation elsewhere. Note: switching the LFSR to the existing `f_nat2slv` (`to_unsigned`) only moves the threshold (4327 needs 13 unsigned bits: warning for N <= 12). |

Independent of e: the doc comments of `f_int2slv` ("Example: f_int2sl(1)",
"n std_logic input (only 0 and 1 are allowed)") and `f_nat2slv` are wrong.
Fixing them changes no behavior.

### f) Width 102 (new)

| Option | Consequences |
| --- | --- |
| f1. replace the taps with `102,101,26,25` (0-based `101,100,25,24`), primitive and of the same shape | The sequence at N = 102 changes for every seed; maximal afterwards. Header notes the deviation from XAPP052 row 102. |
| f2. keep and document as non-maximal | No sequence change; consumers at 102 keep seed-dependent periods (down to 7). |
| f3. reject 102 at elaboration | Breaking for 102, leaves a hole in the range. |

### g) Primitivity check in the repository (new)

| Option | Notes |
| --- | --- |
| g1. `sim/scripts/check_lfsr_taps.py`, standard library only: parses the RTL taps, checks irreducibility and order against a committed list of the prime factors of `2^N - 1` (N <= 168), and verifies that list itself (product equals `2^N - 1`, each factor passes a Miller-Rabin test). Run in CI. | Verifies all 166 widths in seconds, no new dependency. Factors above 2^64 are probable primes, as with the BPSW test used for this plan. |
| g2. same check using `sympy` (factoring at run time, about 40 s) | New dependency in `requirements*.txt`. |
| g3. no script; exhaustive period in the testbench for small widths only | Would not have found N = 102. |

## 3. Tests

### 3.1 Failing on the NUMERIC_STD warning

- GHDL 6.0.0: the IEEE `numeric_std` asserts are `severity warning`.
  `--assert-level=warning` stops the simulation at the first one (exit code
  1, `assertion failed`). `--ieee-asserts=disable` hides them (must not be
  used); `--ieee-asserts=disable-at-0` does not hide this one (it is not at
  time 0).
- VUnit 4.7.1: the simulation option `vhdl_assert_stop_level = "warning"`
  passes `--assert-level=warning` to GHDL. Probe: 8 bits fails, 14 bits
  passes; with the default stop level (`error`) 8 bits passes despite the
  warnings. Set it on the LFSR testbench only:
  `lib.test_bench("tb_vu_lm_util_lfsr").set_sim_option("vhdl_assert_stop_level", "warning")`.
- Consequence: any other warning in that testbench also fails it (for
  example metavalue warnings from `to_integer` on `U`), which is intended;
  the testbench must not convert uninitialized values.

### 3.2 VUnit testbench `tb_vu_lm_util_lfsr`

One testbench with a `for ... generate` over widths `g_w_min .. g_w_max`
(one elaboration for all widths; the probe with 336 instances ran in about
15 s). The reference model is independent of the RTL: its own tap table,
transcribed from XAPP052 (1-based), with the width-102 row per decision f.
Seeds: a 168-bit pattern with bit 0 set, all ones, a single MSB.

| Test | Checks | Expected before the fix |
| --- | --- | --- |
| `reset_value` | `rng_o` during reset equals the chosen value (a); no warning (stop level) | **fails**: warning at the first reset edge (widths 1..13). Under a2/a3 the value check also fails at every width. Under a1 only the warning fails. |
| `sequence` | release, then 300 steps equal to the model; first value `step(seed)` | passes for 3..168 (equal to the probe), but **fails at 102** if the model uses f1 taps. Widths 1, 2: **fail** under b2, not instantiated under b1. |
| `load` | `rng_o = seed_i` on the load edge, then the model | passes (same caveats) |
| `reset_priority` | reset and load together: reset wins | passes |
| `seed_zero` | c1: stays 0 after reset and after load; c2: nonzero and equal to the model from the substitute; c3: expected message | c1 passes; c2 **fails**; c3 **fails** (no message) |
| `period` | widths 3..16 (fast) and 17..20 (full): first return to the initial state after exactly `2^N - 1` steps | passes |
| `w102_short_cycle` (if f1) | seed `0x25CB972E5CB972E5CB972E5CB9`: no repeat within 1000 steps | **fails** (repeats after 7) |

`run.py`: fast level one configuration over the accepted range; full level
adds one configuration per width for diagnosis, if wanted (decision 9).

### 3.3 Elaboration checks (`sim/scripts/check_elab_failures.py`)

With b1 (message for example `g_data_w must be in range 3 to 168`):

| Case | Expected after | Today |
| --- | --- | --- |
| `g_data_w = 3`, `168` (positive controls) | elaborates | elaborates |
| `169` | fails with the new message | fails with the old message, so **fails** the check |
| `2`, `1` | fails with the message | **elaborates** |
| `0` | fails with the message | **elaborates** (index error only on a clock edge) |
| `-1` | fails with the message | **fails without the message** (bound check) |

With b2: positive controls 1, 2, 3, 168; negatives 0, -1, 169.

### 3.4 Vendor synthesis (`tools/synth/cases.toml`)

Cases: `lfsr_3` (smallest, or `lfsr_1`/`lfsr_2` with b2), `lfsr_8`,
`lfsr_64`, `lfsr_102` (with f1), `lfsr_168`. Since the warning does not exist
in synthesis (F3), a case can only fail before the fix through new checks in
the runner (decision 8):

| Check | Vivado | Quartus | Today |
| --- | --- | --- | --- |
| no tool warning that names `lm_util_lfsr.vhd` | warning lines from the log | `Warning (` lines of the map report | Vivado passes; Quartus **fails** (`10542`) |
| register count of the unit | `FD*` cells under the DUT | `Total registers` | 2N; with a3 the expected N **fails** today |
| reset value of `rng_o` (Vivado) | `FDSE` = 1, `FDRE` = 0 per output bit | not available | equals `4327 mod 2^N`; any other choice **fails** today |
| c2 cost | LUT count recorded in the summary, compared before/after | LE count | recorded only |

Each new check needs a negative case, as for the existing checks. Without
runner changes the cases can only add `expect_*_regex` hints (status
`review`, never a failure).

## 4. Impact on downstream IPs

Reported in the review discussion only, not in this file.

## 5. Phase B commits and closure criteria

Each commit is small and checkable on its own. "Fails" means: fails for the
stated reason and no other.

| # | Commit | Acceptance criterion |
| --- | --- | --- |
| B1 | test: tap primitivity check (g1 or g2), wired in CI | fails listing N = 102 only (if f1); all other widths primitive; runs in seconds |
| B2 | test: `tb_vu_lm_util_lfsr` + `run.py` entries with stop level `warning` | fails exactly as in 3.2 for the chosen options; the other existing tests unchanged |
| B3 | test: LFSR elaboration checks | fails exactly as in 3.3 |
| B4 | test: synthesis cases (+ runner checks and their negative cases, if decided) | fails as in 3.4; negative cases pass; `--dry-run` in CI still green |
| B5 | fix: width-102 taps (if f1) | B1 green; `sequence` and `w102_short_cycle` green at 102 |
| B6 | fix: width range assert (b1 or b2), default initial value removed | B3 green, every case with the intended message |
| B7 | fix: reset value (a), signal rewrite (d), no use of `f_int2slv` (e1) or the new pkg function (e2) | `reset_value` green at every width with stop level `warning`; `sequence`, `load`, `period` green; synthesis register count and reset value as expected |
| B8 | fix: zero seed (c), if c2/c2'/c3 | `seed_zero` green; c2 cost recorded by B4 cases |
| B9 | docs: unit header (Fibonacci LFSR, XOR, XAPP052 source and deviation at 102, lock-up, cycle semantics, accepted range), README and user guide wording, pkg doc comments (if decided), CHANGELOG | `tools/check_public_safety.py` and `pre-commit run --all-files` green; full and fast VUnit regressions, elaboration checks and the vendor cases on Vivado and Quartus pass, with the logs kept outside the repository |

Closure review (independent): replays B1..B4 on their own commits to see
each failure, then the branch head to see everything green; checks that the
sequence after reset is unchanged for every width except 102 (model and
probe evidence), that no NUMERIC_STD warning remains in the LFSR testbench,
and that the changelog matches the observed behavior.

### Proposed changelog entry (v0.2.0)

Wording depends on the decisions; bracketed parts are alternatives.

```markdown
## v0.2.0 - <date>

### Breaking Changes

- `lm_util_lfsr` rejects `g_data_w` outside 3..168 at elaboration with
  `severity failure`. Widths 1 and 2 had no feedback taps and produced a
  constant zero; 0 and negative widths failed later without a message.
  [b2: widths 1 and 2 now have feedback taps (`x + 1`, `x^2 + x + 1`).]
- `lm_util_lfsr` with `g_data_w = 102` uses the taps 102, 101, 26, 25. The
  previous taps (XAPP052 row 102, 101, 36, 35) do not give a maximal
  sequence: the polynomial factors into degrees 3, 34 and 65 and some seeds
  repeated after 7 cycles. The sequence for width 102 changes for every seed.
- [a2: `rng_o` is 0 while reset is active.] [a3: `rng_o` shows `seed_i`
  while reset is active, as on `load_i`; the unit uses N flip-flops
  instead of 2N.] It was `4327 mod 2^g_data_w`. The sequence after reset
  is unchanged.
- [c2: a zero seed is replaced by <value> on reset and load; the register
  can no longer start in the all-zero lock-up state.]

### Fixed

- `lm_util_lfsr` no longer reports `NUMERIC_STD.TO_SIGNED: vector truncated`
  on every clock edge with reset active for `g_data_w <= 13`. [a1: the
  value on `rng_o` during reset is unchanged.]

### Changed

- `lm_util_lfsr` keeps its state in signals and has no default initial
  value; before the first reset `rng_o` is uninitialized in simulation.
- Documentation describes `lm_util_lfsr` as a Fibonacci LFSR with XOR
  feedback (it was called xorshift), the all-zero lock-up state and the
  cycle semantics of reset and load.
- Test coverage: `tb_vu_lm_util_lfsr` checks every accepted width against
  an independent reference model, fails on any VHDL warning, and checks the
  full period for widths up to 16 (20 in the full regression); a script
  checks that every tap set is a primitive polynomial; elaboration checks
  for the rejected widths; vendor synthesis cases for `lm_util_lfsr`.
```

## 6. Decisions required

1. Reset value on `rng_o` (a1, a2, a3, a4).
2. Lower bound (b1 or b2); `g_data_w` type `integer` or `positive`.
3. Zero seed (c1, c2, c2', c3, or a combination); if c2, the substitute value.
4. Variable (d1) or signals (d2); remove the default initial value (`R100`)
   yes/no.
5. `f_int2slv` (e1, e2, e3); fix the pkg doc comments in this issue yes/no.
6. Width 102 (f1, f2, f3).
7. Primitivity check (g1, g2, g3); in CI yes/no.
8. Synthesis: extend the runner (no-warning, register count, reset value
   checks with negative cases) or add the cases with regex hints only.
9. Testbench layout: single generate configuration only, or also one
   configuration per width in the full level.
10. Version: v0.2.0 with the breaking changes above.
11. Out of scope, to confirm: an enable port; replacing the `f_lfsr`
    if-chain with a table; the `tb_vu_lm_util_bitsum` full-level truncation
    (1.9) as a separate issue.
12. This plan file stays out of `main` at the squash merge yes/no.

## Appendix: width table

`rng_o` in reset is the value observed in simulation (equal to
`4327 mod 2^N` at every width). "Warning" is
`NUMERIC_STD.TO_SIGNED: vector truncated` during reset. "Maximal" is the
primitivity of the characteristic polynomial (exhaustive period for N <= 20).

| N | NUMERIC_STD warning | `rng_o` in reset | taps defined | maximal (primitive) |
| ---: | :---: | ---: | :---: | :---: |
| 1 | yes | 1 (0x1) | no | no |
| 2 | yes | 3 (0x3) | no | no |
| 3 | yes | 7 (0x7) | yes | yes |
| 4 | yes | 7 (0x7) | yes | yes |
| 5 | yes | 7 (0x7) | yes | yes |
| 6 | yes | 39 (0x27) | yes | yes |
| 7 | yes | 103 (0x67) | yes | yes |
| 8 | yes | 231 (0xE7) | yes | yes |
| 9 | yes | 231 (0xE7) | yes | yes |
| 10 | yes | 231 (0xE7) | yes | yes |
| 11 | yes | 231 (0xE7) | yes | yes |
| 12 | yes | 231 (0xE7) | yes | yes |
| 13 | yes | 4327 (0x10E7) | yes | yes |
| 14 | no | 4327 (0x10E7) | yes | yes |
| 15 | no | 4327 (0x10E7) | yes | yes |
| 16 | no | 4327 (0x10E7) | yes | yes |
| 17 | no | 4327 (0x10E7) | yes | yes |
| 18 | no | 4327 (0x10E7) | yes | yes |
| 19 | no | 4327 (0x10E7) | yes | yes |
| 20 | no | 4327 (0x10E7) | yes | yes |
| 21 | no | 4327 (0x10E7) | yes | yes |
| 22 | no | 4327 (0x10E7) | yes | yes |
| 23 | no | 4327 (0x10E7) | yes | yes |
| 24 | no | 4327 (0x10E7) | yes | yes |
| 25 | no | 4327 (0x10E7) | yes | yes |
| 26 | no | 4327 (0x10E7) | yes | yes |
| 27 | no | 4327 (0x10E7) | yes | yes |
| 28 | no | 4327 (0x10E7) | yes | yes |
| 29 | no | 4327 (0x10E7) | yes | yes |
| 30 | no | 4327 (0x10E7) | yes | yes |
| 31 | no | 4327 (0x10E7) | yes | yes |
| 32 | no | 4327 (0x10E7) | yes | yes |
| 33 | no | 4327 (0x10E7) | yes | yes |
| 34 | no | 4327 (0x10E7) | yes | yes |
| 35 | no | 4327 (0x10E7) | yes | yes |
| 36 | no | 4327 (0x10E7) | yes | yes |
| 37 | no | 4327 (0x10E7) | yes | yes |
| 38 | no | 4327 (0x10E7) | yes | yes |
| 39 | no | 4327 (0x10E7) | yes | yes |
| 40 | no | 4327 (0x10E7) | yes | yes |
| 41 | no | 4327 (0x10E7) | yes | yes |
| 42 | no | 4327 (0x10E7) | yes | yes |
| 43 | no | 4327 (0x10E7) | yes | yes |
| 44 | no | 4327 (0x10E7) | yes | yes |
| 45 | no | 4327 (0x10E7) | yes | yes |
| 46 | no | 4327 (0x10E7) | yes | yes |
| 47 | no | 4327 (0x10E7) | yes | yes |
| 48 | no | 4327 (0x10E7) | yes | yes |
| 49 | no | 4327 (0x10E7) | yes | yes |
| 50 | no | 4327 (0x10E7) | yes | yes |
| 51 | no | 4327 (0x10E7) | yes | yes |
| 52 | no | 4327 (0x10E7) | yes | yes |
| 53 | no | 4327 (0x10E7) | yes | yes |
| 54 | no | 4327 (0x10E7) | yes | yes |
| 55 | no | 4327 (0x10E7) | yes | yes |
| 56 | no | 4327 (0x10E7) | yes | yes |
| 57 | no | 4327 (0x10E7) | yes | yes |
| 58 | no | 4327 (0x10E7) | yes | yes |
| 59 | no | 4327 (0x10E7) | yes | yes |
| 60 | no | 4327 (0x10E7) | yes | yes |
| 61 | no | 4327 (0x10E7) | yes | yes |
| 62 | no | 4327 (0x10E7) | yes | yes |
| 63 | no | 4327 (0x10E7) | yes | yes |
| 64 | no | 4327 (0x10E7) | yes | yes |
| 65 | no | 4327 (0x10E7) | yes | yes |
| 66 | no | 4327 (0x10E7) | yes | yes |
| 67 | no | 4327 (0x10E7) | yes | yes |
| 68 | no | 4327 (0x10E7) | yes | yes |
| 69 | no | 4327 (0x10E7) | yes | yes |
| 70 | no | 4327 (0x10E7) | yes | yes |
| 71 | no | 4327 (0x10E7) | yes | yes |
| 72 | no | 4327 (0x10E7) | yes | yes |
| 73 | no | 4327 (0x10E7) | yes | yes |
| 74 | no | 4327 (0x10E7) | yes | yes |
| 75 | no | 4327 (0x10E7) | yes | yes |
| 76 | no | 4327 (0x10E7) | yes | yes |
| 77 | no | 4327 (0x10E7) | yes | yes |
| 78 | no | 4327 (0x10E7) | yes | yes |
| 79 | no | 4327 (0x10E7) | yes | yes |
| 80 | no | 4327 (0x10E7) | yes | yes |
| 81 | no | 4327 (0x10E7) | yes | yes |
| 82 | no | 4327 (0x10E7) | yes | yes |
| 83 | no | 4327 (0x10E7) | yes | yes |
| 84 | no | 4327 (0x10E7) | yes | yes |
| 85 | no | 4327 (0x10E7) | yes | yes |
| 86 | no | 4327 (0x10E7) | yes | yes |
| 87 | no | 4327 (0x10E7) | yes | yes |
| 88 | no | 4327 (0x10E7) | yes | yes |
| 89 | no | 4327 (0x10E7) | yes | yes |
| 90 | no | 4327 (0x10E7) | yes | yes |
| 91 | no | 4327 (0x10E7) | yes | yes |
| 92 | no | 4327 (0x10E7) | yes | yes |
| 93 | no | 4327 (0x10E7) | yes | yes |
| 94 | no | 4327 (0x10E7) | yes | yes |
| 95 | no | 4327 (0x10E7) | yes | yes |
| 96 | no | 4327 (0x10E7) | yes | yes |
| 97 | no | 4327 (0x10E7) | yes | yes |
| 98 | no | 4327 (0x10E7) | yes | yes |
| 99 | no | 4327 (0x10E7) | yes | yes |
| 100 | no | 4327 (0x10E7) | yes | yes |
| 101 | no | 4327 (0x10E7) | yes | yes |
| 102 | no | 4327 (0x10E7) | yes | **no** (3 x 34 x 65) |
| 103 | no | 4327 (0x10E7) | yes | yes |
| 104 | no | 4327 (0x10E7) | yes | yes |
| 105 | no | 4327 (0x10E7) | yes | yes |
| 106 | no | 4327 (0x10E7) | yes | yes |
| 107 | no | 4327 (0x10E7) | yes | yes |
| 108 | no | 4327 (0x10E7) | yes | yes |
| 109 | no | 4327 (0x10E7) | yes | yes |
| 110 | no | 4327 (0x10E7) | yes | yes |
| 111 | no | 4327 (0x10E7) | yes | yes |
| 112 | no | 4327 (0x10E7) | yes | yes |
| 113 | no | 4327 (0x10E7) | yes | yes |
| 114 | no | 4327 (0x10E7) | yes | yes |
| 115 | no | 4327 (0x10E7) | yes | yes |
| 116 | no | 4327 (0x10E7) | yes | yes |
| 117 | no | 4327 (0x10E7) | yes | yes |
| 118 | no | 4327 (0x10E7) | yes | yes |
| 119 | no | 4327 (0x10E7) | yes | yes |
| 120 | no | 4327 (0x10E7) | yes | yes |
| 121 | no | 4327 (0x10E7) | yes | yes |
| 122 | no | 4327 (0x10E7) | yes | yes |
| 123 | no | 4327 (0x10E7) | yes | yes |
| 124 | no | 4327 (0x10E7) | yes | yes |
| 125 | no | 4327 (0x10E7) | yes | yes |
| 126 | no | 4327 (0x10E7) | yes | yes |
| 127 | no | 4327 (0x10E7) | yes | yes |
| 128 | no | 4327 (0x10E7) | yes | yes |
| 129 | no | 4327 (0x10E7) | yes | yes |
| 130 | no | 4327 (0x10E7) | yes | yes |
| 131 | no | 4327 (0x10E7) | yes | yes |
| 132 | no | 4327 (0x10E7) | yes | yes |
| 133 | no | 4327 (0x10E7) | yes | yes |
| 134 | no | 4327 (0x10E7) | yes | yes |
| 135 | no | 4327 (0x10E7) | yes | yes |
| 136 | no | 4327 (0x10E7) | yes | yes |
| 137 | no | 4327 (0x10E7) | yes | yes |
| 138 | no | 4327 (0x10E7) | yes | yes |
| 139 | no | 4327 (0x10E7) | yes | yes |
| 140 | no | 4327 (0x10E7) | yes | yes |
| 141 | no | 4327 (0x10E7) | yes | yes |
| 142 | no | 4327 (0x10E7) | yes | yes |
| 143 | no | 4327 (0x10E7) | yes | yes |
| 144 | no | 4327 (0x10E7) | yes | yes |
| 145 | no | 4327 (0x10E7) | yes | yes |
| 146 | no | 4327 (0x10E7) | yes | yes |
| 147 | no | 4327 (0x10E7) | yes | yes |
| 148 | no | 4327 (0x10E7) | yes | yes |
| 149 | no | 4327 (0x10E7) | yes | yes |
| 150 | no | 4327 (0x10E7) | yes | yes |
| 151 | no | 4327 (0x10E7) | yes | yes |
| 152 | no | 4327 (0x10E7) | yes | yes |
| 153 | no | 4327 (0x10E7) | yes | yes |
| 154 | no | 4327 (0x10E7) | yes | yes |
| 155 | no | 4327 (0x10E7) | yes | yes |
| 156 | no | 4327 (0x10E7) | yes | yes |
| 157 | no | 4327 (0x10E7) | yes | yes |
| 158 | no | 4327 (0x10E7) | yes | yes |
| 159 | no | 4327 (0x10E7) | yes | yes |
| 160 | no | 4327 (0x10E7) | yes | yes |
| 161 | no | 4327 (0x10E7) | yes | yes |
| 162 | no | 4327 (0x10E7) | yes | yes |
| 163 | no | 4327 (0x10E7) | yes | yes |
| 164 | no | 4327 (0x10E7) | yes | yes |
| 165 | no | 4327 (0x10E7) | yes | yes |
| 166 | no | 4327 (0x10E7) | yes | yes |
| 167 | no | 4327 (0x10E7) | yes | yes |
| 168 | no | 4327 (0x10E7) | yes | yes |
