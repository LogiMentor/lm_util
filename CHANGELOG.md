# Changelog

## v0.1.0 - unreleased

First tagged version. The tag is created when this section is merged; until
then the date is not set.

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
    bounds check was inverted).

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
  integer part; the unsupported-operation guard in `f_vector_tree` can
  actually fire.
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
  check always fails the run.
- Simulation: the reference simulator is GHDL 6.0.0 (LLVM backend), pinned
  in CI with `ghdl/setup-ghdl`; `vunit_hdl` is pinned to 4.7.1;
  `sim/scripts/check_elab_failures.py` checks that invalid generics stop
  elaboration with the intended message.
- Test coverage: counter down/load modes, pulse_stretch active-low output and
  unit lengths, delay_pulse multi-cycle pulses, delay_var unit delay max and
  pulse delay 1 (also in pulse mode with `g_delay_max = 1`, both pulse
  levels, and inputs held longer than the delay), bitsum power-of-two widths,
  clock_measure steady-state window and reset behavior (reset length and
  phase, slow and stopped measured clock), and a new `lm_util_ccd_sync_bus`
  testbench are now exercised; previously disabled failing configurations
  are re-enabled.
