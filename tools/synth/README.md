# Vendor Synthesis Smoke Tests

This directory contains a local-only synthesis campaign runner for FPGA vendor
tools. The goal is to verify that selected `lm_util` modules are accepted by
vendor synthesis and that sensitive structures are inferred as intended.

The campaign is not part of GitHub Actions because Vivado, Quartus, and Diamond
are machine-specific and often licensed. The repo stores the test cases and the
runner; each developer or CI machine provides its local tool configuration.

## Files

| Path | Purpose |
| --- | --- |
| `run_vendor_synth.py` | Python runner, standard library only. |
| `cases.toml` | Versioned synthesis cases, structural checks and report hints. |
| `negative/` | Test-only entities for the negative cases; not part of the library. |
| `local.example.toml` | Example local tool/part configuration. |

## Quick Start

Copy the example config, edit tool paths and devices, then enable the targets
that exist on the local machine.

```sh
cp tools/synth/local.example.toml tools/synth/local.toml
python tools/synth/run_vendor_synth.py --config tools/synth/local.toml --list
python tools/synth/run_vendor_synth.py --config tools/synth/local.toml --dry-run
python tools/synth/run_vendor_synth.py --config tools/synth/local.toml
```

On Windows PowerShell:

```powershell
Copy-Item tools\synth\local.example.toml tools\synth\local.toml
python tools\synth\run_vendor_synth.py --config tools\synth\local.toml --list
python tools\synth\run_vendor_synth.py --config tools\synth\local.toml --dry-run
python tools\synth\run_vendor_synth.py --config tools\synth\local.toml
```

Results are written below `vendor_synth_out/<timestamp>/` unless overridden by
`--out`. Each target/case directory contains generated vendor scripts, logs,
reports, and a `case.json` descriptor. The top-level `summary.json` and
`summary.md` collect the run status, result directory, and a short failure note
when the vendor tool exits before reports are produced.

`vendor_synth_out/` is intentionally ignored by Git. These reports are local
evidence for the machine, tool version, license setup, and device family used
for the run. A failed tool startup or synthesis command may only produce
`stdout.log`, `stderr.log`, and vendor logs; utilization, timing, or inferred
resource reports appear only after the corresponding vendor flow completes.

Each case also generates a small VHDL wrapper with fixed generic values and
concrete top-level ports. This avoids relying on different vendor command-line
syntaxes for VHDL generics and prevents the logic from being optimized away as a
no-port design.

## Status Meaning

| Status | Meaning |
| --- | --- |
| `passed` | Tool returned success, every structural check passed and every report hint matched. For a negative case: every check listed in `expect_failed_checks` failed. |
| `review` | Structural checks passed (or the case has none) but a report hint regex was not found. Inspect reports manually. |
| `failed` | Tool returned a non-zero exit code, a structural check failed, the check report is missing, or a negative case did not fail as expected. |
| `error` | Script generation failed (for example a missing extra file). |
| `skipped` | Tool executable was not found. |
| `planned` | Generated in `--dry-run` mode. |

The run exits with a non-zero code when any case is `failed` or `error`.

Vivado intermittently fails on some Windows machines while reading its own
Tcl scripts or `.Xil` scratch files (`couldn't read file ...: No error`).
A case that fails this way is run once more, and the first failure is kept
under `retries` in `summary.json`.

## Structural Checks

Cases may declare synchronizer `chains` and `no_shift_register = true`.
These checks never look at the generated scripts or at the generic tool log:

- Vivado: after `synth_design`, a Tcl query on the netlist writes
  `reports/lm_checks.txt`. For each chain, the cells whose leaf name is
  `<signal>_reg`, `<signal>_reg[n]` or a packed `<signal>_reg[n]_srl<k>`
  must match the expected count (`chain:<label>:count`), be `FD*` cells
  (`chain:<label>:cell_type`) and carry `ASYNC_REG = TRUE`
  (`chain:<label>:async_reg`). `no_shift_register` requires no `SRL*` cell.
- Quartus: the flow runs Analysis & Synthesis, the Fitter and
  `report_metastability` in the Timing Analyzer, with the case `clocks`
  declared in a generated SDC (several clocks are asynchronous groups). For
  each chain, the registers listed as synchronization registers must match
  the expected count (`chain:<label>:count`) and be identified as
  `User Specified` (`chain:<label>:synchronizer`), that is through the
  `SYNCHRONIZER_IDENTIFICATION` attribute. `no_shift_register` requires no
  `SHIFT_TAPS` row in the "Registers Packed Into Inferred Megafunctions"
  panel of the Analysis & Synthesis report.

Negative cases (`tags = ["negative"]`) list the checks they must fail in
`expect_failed_checks`. They use test-only entities under `negative/`,
compiled only for their own case through `extra_files`. To see the checks
fail as regular cases:

```powershell
python tools\synth\run_vendor_synth.py --config tools\synth\local.toml --tag negative --ignore-expected-failures
```

A Quartus target whose family or device is not installed stops with an
`LM_ERROR` message naming the missing family or device; a missing Vivado part
is reported the same way.

The regex fields (`expect_*_regex`) are hints on the vendor `.rpt`/`.srr`
reports only. They can turn a passing case into `review`, never into
`passed`, and are not a substitute for the structural checks.

## Sensitive Cases

The initial campaign focuses on modules where vendor behavior matters:

- `lm_util_delay` and `lm_util_delay_srl`: shift-register/SRL inference.
- `lm_util_delay_var`: SRL and pulse/counter architectures.
- CDC synchronizers (`lm_util_ccd_resync`, `lm_util_ccd_sync_bus`,
  `lm_util_ccd_sync_pulse`, `lm_util_async_reset`, `lm_util_clock_measure`,
  `lm_util_clock_mux`): structural chain checks, tag `cdc`.
- Negative cases for each kind of check, tag `negative`.

Add new cases to `cases.toml` when a module gains a vendor-sensitive
implementation or when a bug is found in a specific family/tool combination.
