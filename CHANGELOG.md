# Changelog

## Unreleased

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
  from their leading edge; reset drives the output to the inactive level of
  the configured polarity.

### Fixed

- `lm_util_clock_measure`: the toggle synchronizer third stage sampled the
  first (possibly metastable) stage and the edge detector compared against it;
  the reported frequency missed the window-closing cycle (off by one); the
  ready synchronizer chain is now cleared by reset so a reset can no longer
  produce a spurious output update.
- `lm_util_delay_var`: `dv_o` is now driven for `g_delay_max = 1` and in the
  pulse architecture; a runtime delay of 1 is supported in pulse mode;
  unsupported `g_arch_type` values (including the never-implemented "mem"
  architecture) are rejected at elaboration.
- `lm_util_pkg`: `f_smallest(t_natural_arr)` no longer always returns 0;
  `f_div_ceil_2pwr` rounds correctly to the next power of two for any ratio;
  `f_div_ceil(time, time)` no longer truncates sub-ns remainders;
  `f_is_power_of_two` no longer fails on 0 and needs no vector conversion;
  `f_string_format` carries a rounded-up fraction into the integer part;
  `f_string_substr` bounds check no longer reports valid substrings as errors;
  the unsupported-operation guard in `f_vector_tree` can actually fire.
- `lm_util_ccd_sync_bus`: a request held asserted across an input-domain reset
  release is no longer detected as a new rising edge.

### Changed

- CRC checkers compare against the computed residue for transmitted CRC fields
  that include `xorout`.
- The parallel CRC reflected-input mode now reflects bits within each byte
  rather than reversing the whole input word.
- CRC engines support 4- to 64-bit polynomials.
- Synchronizer chains (`lm_util_ccd_resync`, `lm_util_ccd_sync_pulse`,
  `lm_util_async_reset`, `lm_util_clock_measure`, `lm_util_clock_mux`) carry
  `async_reg`/`shreg_extract` attributes so synthesis keeps the flops discrete;
  the `lm_util_clock_mux` anti-glitch `keep` attribute is now string-typed as
  Vivado expects.
- Test coverage: counter down/load modes, pulse_stretch active-low output and
  unit lengths, delay_pulse multi-cycle pulses, delay_var unit delay max and
  pulse delay 1, bitsum power-of-two widths, and clock_measure steady-state
  window are now exercised; previously disabled failing configurations are
  re-enabled.
