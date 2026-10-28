# Changelog

## v0.2.0 - unreleased

### Breaking Changes

- `lm_util_lfsr` rejects `g_data_w` outside 3..168 at elaboration with
  `severity failure` (`g_data_w must be in range 3 to 168`). Widths 1 and 2
  had no feedback taps and produced a constant zero; 0 failed at the first
  clock edge with an index error and negative widths without a message.
- `lm_util_lfsr` shows the effective seed on `rng_o` while reset is active:
  reset loads `seed_i` like `load_i`. It showed the constant 4327 truncated
  to `g_data_w` bits. The sequence after the release of reset and after a
  load is unchanged (checked against the v0.1.0 unit for every width 3..168
  except 102).
- `lm_util_lfsr` with `g_data_w = 102` uses the taps 102, 99, 97, 96 from
  the table of Ward and Molteno (University of Otago, Electronics Technical
  Report 2012-1). The previous taps, the XAPP052 row 102, 101, 36, 35, are
  not a primitive polynomial (it factors into degrees 3, 34 and 65) and some
  seeds repeated every 7 steps. The 102-bit sequence changes for every seed.
- `lm_util_lfsr` replaces a zero seed, the lock-up state of the XOR
  feedback, with all ones on reset and load. A zero seed kept the register
  at zero.
- `lm_util_lfsr` has no default initial value: before the first edge with
  reset or load `rng_o` is `'U'` in simulation (it was all zeros except bit
  0, then `'U'` after the first edge).
- `lm_util_lfsr` registers are renamed: the state is the signal `s_state`,
  which drives `rng_o`; the process variable `v_rand_tmp` and the output
  register `s_rng_reg` are gone. Timing constraints or debug probes that
  name them must be updated.

### Fixed

- `lm_util_lfsr` no longer reports `NUMERIC_STD.TO_SIGNED: vector truncated`
  on every clock edge with reset active for `g_data_w <= 13`, and Quartus no
  longer warns about an initialized variable in `f_lfsr`.
- `lm_util_pkg`: the comments of `f_int2slv`, `f_nat2slv`, `f_int2sl` and
  `f_slv2sl` describe the functions (they named other functions or wrong
  argument types). No code change.

### Changed

- `lm_util_lfsr` uses `g_data_w` flip-flops instead of `2 * g_data_w`
  (Vivado 2023.1 and Quartus Prime Lite 23.1std, 8 and 64 bits), and no
  longer uses `lm_util_pkg`. Its header and the user guide describe it as a
  Fibonacci LFSR with XOR feedback (it was called xorshift).
- `tools/check_lfsr_taps.py` checks that every `lm_util_lfsr` tap set is a
  primitive polynomial over GF(2) (irreducible, order `2^N - 1`), with the
  factors of `2^N - 1` in a data file that the script verifies; it runs in
  CI. It accepts only the exact form of `f_lfsr` (one XOR of `v_rand` bits
  per width, widths 3..168 in order) and of the shift in `f_lfsr_next`, and
  fails on anything else.
- Vendor synthesis runner: `registers` (flip-flop count) and `no_warnings`
  (no tool warning that names given sources) structural checks, with the
  same report completeness rule as the other checks (Vivado log included),
  and negative cases; new `lfsr_8` and `lfsr_64` cases.
- Test coverage: `tb_vu_lm_util_lfsr` runs with
  `vhdl_assert_stop_level = "warning"` and checks `lm_util_lfsr` against a
  reference model and against a test-only copy of the v0.1.0 unit (widths
  3, 4, 8, 13, 14, 32, 102, 168 in the fast regression, 3..168 in the full
  one), the period `2^N - 1` for widths 3..16 and the 102-bit seed that
  repeated every 7 steps; elaboration checks for the rejected widths.
- `sim/scripts/run.py` uses GHDL when `VUNIT_SIMULATOR` is not set; another
  simulator runs only when the variable names it. VUnit alone took the first
  simulator in the `PATH`, ModelSim before GHDL, and the GHDL flags were
  applied only when the variable was set to `ghdl`. The runner prints the
  simulator it uses and, for GHDL, the version and backend.

### CI

- The VUnit job uploads only `vunit_xunit.xml` and the `output.txt` of each
  test on every run, and the rest of the test output only when the job
  fails, without GHDL executables, objects and compiled libraries; both
  artifacts are kept 7 days. It uploaded the whole `vunit_out` on every run,
  about 400 MB, almost all of it GHDL executables.

## v0.1.0 - 2026-10-18

First tagged version.

### Breaking Changes

- CRC `match_o` is now a held level instead of a one-cycle idle-cleared pulse.
  It clears on reset, `init_i`, or the next checked data update. Designs that
  require a pulse should qualify or edge-detect it at the protocol boundary that
  marks the end of the CRC field.
- `lm_util_bitsum` output `bitsum_o` is now `f_ceil_log2(g_din_w + 1)` bits wide
  (one bit wider for power-of-two input widths), so the all-ones count no
  longer wraps to zero.
- `lm_util_counter` down direction now counts `g_wd_timer-1 .. 0` with reset
  loading `g_wd_timer-1` and the watchdog pulse on 0, symmetric to the up
  direction. Previously it underflowed from 0 through the full register range.
- `lm_util_pulse_stretch` input pulse is defined active high (`g_out_level`
  only sets the output polarity). Stretch mode now adds exactly
  `g_pulse_overlength` cycles after the input falling edge and is retriggered
  by a new rising edge; fixed-length mode produces a pulse also for
  `g_pulse_length = 1` and ignores edges arriving while the window is running.
- `lm_util_delay_pulse` and the `lm_util_delay_var` pulse architecture trigger
  on the pulse leading edge, so pulses wider than one clock cycle are delayed
  from their leading edge and an input held active beyond the delay cannot
  retrigger a second output pulse; reset drives the output to the inactive
  level of the configured polarity in every delay configuration. In the
  `lm_util_delay_var` pulse architecture `dv_o` pulses together with the
  delayed output pulse, consistent with the SRL architecture.
- `lm_util_delay_var` with `g_delay_max = 1` and `g_arch_type = C_LM_PULSE`
  follows the pulse architecture: leading-edge trigger, one-cycle output
  pulse with `dv_o`, inactive output level on reset. It was a plain register
  that reset the output to `'0'` and passed a held input through.
- `lm_util_delay_var` rejects any `g_arch_type` other than `C_LM_SRL` and
  `C_LM_PULSE` at elaboration, for every `g_delay_max` (the never-implemented
  "mem" architecture included). Previously `g_delay_max = 1` accepted any
  value.
- `lm_util_ccd_resync` stops elaboration with `severity failure` when
  `g_meta_levels < 2` (was `severity error`, which some flows only report).
  `lm_util_ccd_sync_pulse` now does the same for `g_delay_len < 2`.
- `lm_util_pkg` functions that returned wrong results now return the correct
  ones, which changes the result for callers that relied on the old values:
  - `f_div_ceil_2pwr` returns the next power of two for any ratio; it returned
    non-powers of two once the ceiling ratio needed more than 64 increments
    (ratios above about 128), and returns 1 for a ratio of 1 or less;
  - `f_smallest(t_natural_arr)` returns the smallest element instead of
    always 0, and `natural'high` for an empty array;
  - `f_is_power_of_two` returns `false` for 0 and negative inputs instead of
    failing;
  - `f_string_substr` no longer reports an error for valid substrings (the
    bounds check was inverted);
  - `f_string_format` follows a stated rounding contract: the exact binary
    value of the real is rounded to `precision` digits, exact halves away
    from zero. A literal is first the nearest real, so `9.9995` with
    precision 3 gives `"9.999"` (the real is 9.99949999999999938893...); it
    gave `"10.000"` by rounding the scaled product a second time. With
    precision 0 the result has no decimal point (`"3"` for 2.5); it was the
    truncated integer part followed by a rounding digit (`"2.1"` for 2.7).
    An integer part above `integer'high` or a precision above 9 stops with
    a failure instead of returning a wrong string; a magnitude of `2**31` or
    more is rejected before any intermediate computation. The exact rounding
    assumes IEEE 754 binary64 reals with every operation rounded on its own
    (verified with GHDL 6.0.0 LLVM).

### Fixed

- `lm_util_clock_measure`: the toggle synchronizer third stage sampled the
  first (possibly metastable) stage and the edge detector compared against it;
  the reported frequency missed the window-closing cycle (off by one). A
  reset no longer publishes a stale value: a measurement pending at the
  reset, the ready transition forced by the measured-domain reset (also when
  it arrives after the release because the measured clock is slow or
  stopped) and pre-reset values still in the synchronizer stages are ignored
  until the stages have been reloaded after the release. The synchronizer
  stages carry no reset logic, so synthesis tools see (and time) the whole
  chain.
- `lm_util_delay_var`: `dv_o` is now driven for `g_delay_max = 1` and in the
  pulse architecture (where it pulses with the delayed output); a runtime
  delay of 1 is supported in pulse mode.
- `lm_util_pkg`: `f_div_ceil(time, time)` no longer truncates sub-ns
  remainders; `f_string_format` carries a rounded-up fraction into the
  integer part (0.9995 with precision 3 gives `"1.000"`, it gave
  `"0.1000"`), formats any integer part up to `integer'high` (the value is
  not scaled by `10**precision` as a whole) and no longer rounds twice when
  the scaled fraction lands on a decimal half (`0.0065` with precision 3
  gives `"0.006"`); the unsupported-operation
  guard in `f_vector_tree` can actually fire.
- `lm_util_ccd_sync_bus`: the request edge detector tracks the
  resynchronized request during reset. A request held asserted across the
  input-domain reset release is not detected as a new rising edge, and a
  request whose resynchronized rising edge arrives on the first cycle after
  the release is transferred (it was dropped, so `out_rdy_o` never pulsed).
- `lm_util_clock_measure` publishes the first value after a reset only when a
  complete window has been measured: the first 1 s tick after the reset opens
  the window and the second one closes it (about 2 s after the release). It
  published the partial first window, counted from the reset release, at the
  first tick.
- Constraint examples: the Quartus and Lattice examples of `lm_util_ccd_resync`
  were not valid Tcl (`[0]` outside braces is a command substitution).

### Changed

- CRC checkers compare against the computed residue for transmitted CRC fields
  that include `xorout`.
- The parallel CRC reflected-input mode now reflects bits within each byte
  rather than reversing the whole input word.
- CRC engines support 4- to 64-bit polynomials.
- Synchronizer chains (`lm_util_ccd_resync`, `lm_util_ccd_sync_pulse`,
  `lm_util_async_reset`, `lm_util_clock_measure`, `lm_util_clock_mux`) carry
  synthesis attributes for all supported vendors so the flops stay discrete:
  `async_reg`/`shreg_extract` (Vivado), `syn_preserve`/`syn_srlstyle`
  (Synplify/LSE), and `altera_attribute` synchronizer identification
  (Quartus). The `lm_util_clock_mux` anti-glitch keep intent is expressed per
  tool (`keep` string for Vivado, `syn_keep` for Synplify/LSE and Quartus,
  which turns it into `IGNORE_LCELL_BUFFERS` and
  `REMOVE_REDUNDANT_LOGIC_CELLS` off). The Vivado and Quartus attributes are verified by vendor
  synthesis (Vivado 2023.1, Quartus Prime Lite 23.1std on MAX 10); the
  Synplify Pro / Lattice LSE attributes follow the vendor documentation but
  have not been verified with those tools, nor with Synplify Pro for
  Microchip Libero.
- CDC constraint examples: every CDC module header lists Vivado (XDC) and
  Quartus (SDC) constraints that select registers and pins by internal
  signal names only, so they apply to every instance and survive a library
  or entity rename. The user guide adds an example, the behavior of these
  constraints under asynchronous clock groups as observed with Vivado
  2023.1, and the verification status per tool.
- Vendor synthesis runner (`tools/synth/run_vendor_synth.py`): structural
  checks on the Vivado netlist (each synchronizer stage an `FD*` cell with
  `ASYNC_REG`, no SRL) and on the Quartus reports (chain identified as a
  user-specified synchronizer, no shift-register inference); negative cases
  that must fail each check; loading of the published constraint examples
  with a check for empty collections and ignored exceptions; a clear error
  when the configured Quartus family or device, or the Vivado part, is not
  installed. Report hints no longer scan the generated scripts, and a failed
  check always fails the run. A check that passes when something is absent
  (no SRL, no shift-register packing, no invalid or ignored exception) first
  requires an open, non-empty Vivado netlist or a complete and recognized
  Quartus report; otherwise it fails with an `LM_ERROR`, as does a check
  missing from the check report. A Quartus table panel that a check reads
  (register packing, exceptions summary, chain statistics, synthesis
  summary) must be complete when present: column header, data rows and
  closing border, with whole-line borders aligned with the rows. Only the
  register packing panel may be absent. Negative cases that empty or truncate a report, or gut
  the register packing panel, show it.
- Simulation: the reference simulator is GHDL 6.0.0 (LLVM backend), pinned
  in CI with `ghdl/setup-ghdl`; `vunit_hdl` is pinned to 4.7.1;
  `sim/scripts/check_elab_failures.py` checks that invalid generics and
  inputs that `f_string_format` cannot format stop elaboration with the
  intended message.
- Test coverage: counter down/load modes, pulse_stretch active-low output and
  unit lengths, delay_pulse multi-cycle pulses, delay_var unit delay max and
  pulse delay 1 (also in pulse mode with `g_delay_max = 1`, both pulse
  levels, and inputs held longer than the delay), bitsum power-of-two widths,
  clock_measure steady-state window and reset behavior (reset length and
  phase, slow and stopped measured clock), `f_string_format` (large values,
  carry, sign, precision 0, and exact reference vectors: 1500 in the fast
  and 20000 in the full regression), and a new `lm_util_ccd_sync_bus`
  testbench are now exercised; previously disabled failing configurations
  are re-enabled.
