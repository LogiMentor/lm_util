# LogiMentor VHDL Utility Library

[![CI](https://github.com/LogiMentor/lm_util/actions/workflows/ci.yml/badge.svg)](https://github.com/LogiMentor/lm_util/actions/workflows/ci.yml)

Reusable, vendor-independent VHDL utility blocks used across LogiMentor FPGA
designs.

The library is intentionally small and practical: common counters, delays,
clock-domain-crossing helpers, CRC engines, encoders, multiplexers, arbiters,
and package-level helper functions live together in one `lm_util_lib` VHDL
library.

## Repository Layout

| Path | Contents |
| --- | --- |
| `src/` | Synthesizable VHDL sources and `lm_util_pkg.vhd`. |
| `sim/tb/` | VUnit self-checking testbenches. |
| `sim/scripts/run.py` | VUnit regression runner. |
| `docs/user_guide.md` | Module reference, instantiation examples, generic configuration, and compile flows. |
| `docs/LM_VHDL_coding_standard.md` | LogiMentor VHDL coding standard. |
| `tools/synth/` | Local vendor synthesis smoke-test runner. |
| `.github/workflows/ci.yml` | GitHub Actions regression using GHDL and VUnit. |

## Documentation

- [User guide](docs/user_guide.md): module functionality, instantiation
  template, generic configuration notes, simulation flow, synthesis compile
  examples, and local vendor synthesis report generation.
- [Vendor synthesis smoke tests](tools/synth/README.md): local Vivado, Quartus,
  and Diamond campaign runner.
- [VHDL coding standard](docs/LM_VHDL_coding_standard.md): style rules used by
  this repository.

## Modules

| Module | Description |
| --- | --- |
| `lm_util_async_reset` | Asynchronous reset assertion with synchronous release. |
| `lm_util_barrel_shifter` | Configurable barrel shifter / rotator. |
| `lm_util_bitsum` | Population count helper. |
| `lm_util_ccd_resync` | Multi-stage clock-domain resynchronizer. |
| `lm_util_ccd_switch` | Cross-clock-domain level switch helper. |
| `lm_util_ccd_sync_bus` | Handshaked bus transfer across clock domains. |
| `lm_util_ccd_sync_pulse` | Pulse transfer across clock domains. |
| `lm_util_clock_gen` | Simulation-oriented clock divider/generator. |
| `lm_util_clock_measure` | Frequency measurement helper. |
| `lm_util_clock_mux` | Clock mux using clock-gating style logic. |
| `lm_util_counter` | Configurable counter/watchdog helper. |
| `lm_util_crc_par` | Parallel CRC engine. |
| `lm_util_crc_ser` | Serial CRC engine. |
| `lm_util_debouncer` | Input debouncer. |
| `lm_util_delay` | Fixed delay line. |
| `lm_util_delay_pulse` | Delayed pulse generator. |
| `lm_util_delay_srl` | SRL-style fixed delay line. |
| `lm_util_delay_var` | Variable delay line. |
| `lm_util_edge_detector` | Rising/falling edge detector. |
| `lm_util_encoder` | One-hot to binary encoder. |
| `lm_util_lfsr` | LFSR/xorshift random sequence generator. |
| `lm_util_mux` | Generic multiplexer. |
| `lm_util_mux_or` | OR-combining multiplexer. |
| `lm_util_pri_arbiter` | Fixed-priority arbiter. |
| `lm_util_pulse_stretch` | Pulse stretcher. |
| `lm_util_rr_arbiter` | Round-robin arbiter. |
| `lm_util_tick_gen` | Periodic tick generator. |
| `lm_util_pkg` | Shared constants, types, and utility functions. |

## Verification

The regression is based on VUnit and self-checking testbenches. The default
`fast` level is intended for CI; `full` enables broader parameter sweeps.

```sh
python -m pip install -r requirements.txt
VUNIT_SIMULATOR=ghdl python sim/scripts/run.py --level fast --clean --output-path vunit_out
```

To run the extended sweep:

```sh
VUNIT_SIMULATOR=ghdl python sim/scripts/run.py --level full --clean --output-path vunit_out
```

The GitHub Actions workflow runs the fast regression with GHDL and uploads the
VUnit output as an artifact.

Vendor synthesis smoke tests for Vivado, Quartus, and Diamond are defined under
`tools/synth/`. They run locally only, using a machine-specific tool/device
configuration, and collect synthesis reports for SRL, CDC, and clocking-sensitive
modules.

## VHDL Standard

The synthesizable sources avoid vendor primitives and use standard IEEE
libraries. The VUnit testbenches use VHDL-2008 constructs such as context
clauses; the GHDL CI flow compiles with VHDL-2008 enabled.

Some modules rely on portable inference patterns for shift registers, CDC
register chains, or clocking structures. Use the local vendor synthesis smoke
tests to confirm the intended implementation on each FPGA family and tool
version.

## Reset Strategy

Most utility cores use active-low synchronous reset. `lm_util_async_reset` is
the exception: it accepts an asynchronous reset input and releases reset
synchronously in the target clock domain.

## License

Licensed under the Apache License, Version 2.0. See `LICENSE`.

Maintained by [LogiMentor](https://www.logimentor.com/).
