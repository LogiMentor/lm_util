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
| `cases.toml` | Versioned synthesis cases and report expectations. |
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
`summary.md` collect the run status.

Each case also generates a small VHDL wrapper with fixed generic values and
concrete top-level ports. This avoids relying on different vendor command-line
syntaxes for VHDL generics and prevents the logic from being optimized away as a
no-port design.

## Status Meaning

| Status | Meaning |
| --- | --- |
| `passed` | Tool returned success and all configured regex expectations matched. |
| `review` | Tool returned success but at least one expected report pattern was missing. Inspect reports manually. |
| `failed` | Tool returned a non-zero exit code. |
| `skipped` | Tool executable was not found. |
| `planned` | Generated in `--dry-run` mode. |

The regex checks are intentionally hints, not proof of quality. For example,
SRL inference in Vivado should still be reviewed in the generated utilization
and synthesis reports.

## Sensitive Cases

The initial campaign focuses on modules where vendor behavior matters:

- `lm_util_delay` and `lm_util_delay_srl`: shift-register/SRL inference.
- `lm_util_delay_var`: SRL and pulse/counter architectures.
- `lm_util_ccd_resync` and `lm_util_async_reset`: synchronizer flip-flop chains.
- `lm_util_clock_mux`: gated clock mux implementation and `keep` handling.

Add new cases to `cases.toml` when a module gains a vendor-sensitive
implementation or when a bug is found in a specific family/tool combination.
