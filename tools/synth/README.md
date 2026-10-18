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
| `failed` | Tool returned a non-zero exit code, a structural check failed, a report could not be evaluated (`LM_ERROR`), the check report is missing or incomplete, or a negative case did not fail as expected. |
| `error` | Script generation failed (for example a missing extra file). |
| `skipped` | Tool executable was not found. |
| `planned` | Generated in `--dry-run` mode. |

The run exits with a non-zero code when any case is `failed` or `error`.

Vivado intermittently fails on some Windows machines while reading its own
Tcl scripts or `.Xil` scratch files (`couldn't read file ...: No error`, or
`invalid command name "rt-undefined"` inside them). A case that fails this
way is run once more, and the first failure is kept under `retries` in
`summary.json`.

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

### Report completeness

Some checks pass when something is absent: no SRL cell, no `SHIFT_TAPS`
row, no register identified other than `User Specified`, no invalid or
ignored exception. Before such a conclusion the runner shows that the
netlist or the report is complete; otherwise the check fails with an
`LM_ERROR` detail and the case fails, a negative case included:

| Check | Evidence required |
| --- | --- |
| Vivado `chain:*`, `no_shift_register`, constraint checks | A synthesized design is open and has primitive cells. |
| Vivado `constraints:listed`, `constraints:not_ignored` | The `report_exceptions` strings are not empty and carry the `Exceptions Report` heading; with no ignored rows, the ignored report states `No ignored timing exceptions found.` |
| Quartus `no_shift_register` | The Analysis & Synthesis report starts with its title, lists the summary and messages panels in the table of contents, contains every panel of the table of contents, has a complete summary panel with a successful status, and ends with the end of processing. If the "Registers Packed Into Inferred Megafunctions" panel is present it must be a complete table (see below); a valid report without that panel, and without it in the table of contents, passes. |
| Quartus `chain:*` | The metastability report has the MTBF summary, as many chains as `Number of Synchronizer Chains Found`, a complete `Statistics` table for each chain, and each chain has its identification method and as many registers as its chain length. |
| Quartus `constraints:listed`, `constraints:valid` | The exceptions report states that no exceptions were found, or has a complete `Report Exceptions Summary` table. |
| Quartus `constraints:not_ignored` | The ignored-constraints report states `No constraints were ignored.` (pass) or lists SDC commands (fail). |
| Every case | `reports/lm_checks.txt` reports every check the case defines; a missing check is an `LM_ERROR`. |

A complete table panel is what Quartus Prime Lite 23.1std writes: a border,
the expected column header, a border, at least one data row with as many
cells as the header, and a closing border (the summary panel is a two-column
property table without a header). Quartus omits a table panel that has no
rows, so a present panel without rows is incomplete. A panel that keeps its
title but lost its rows, its header or its closing border fails with
`LM_ERROR` (cases `neg_report_panel_empty`, `neg_report_panel_header_only`,
`neg_report_panel_unclosed`).

What the completeness check guarantees: a check that concludes an absence
reads a netlist or report that has the structure of a complete, successful
run as Vivado 2023.1 and Quartus Prime Lite 23.1std write it. An empty,
truncated or gutted report, a report in a format the runner does not
recognize, or a check missing from the check report fails the case instead
of passing it.

What it does not guarantee: that the content is the one the tool produced.
A report edited so that it stays structurally complete (for example a
`SHIFT_TAPS` row removed while other rows remain, or the packing panel
removed together with its table-of-contents entry) passes. The check
detects incomplete or damaged reports, not deliberate edits. Other tool
versions may write another format: the runner then reports `LM_ERROR`
rather than a result, and the format has to be checked before it is
accepted. The structural checks do not prove the synthesized function
either; they only show the inference of the checked structures.

### Negative cases

Negative cases (`tags = ["negative"]`) list the checks they must fail in
`expect_failed_checks`. They use test-only entities under `negative/`,
compiled only for their own case through `extra_files`. To see the checks
fail as regular cases:

```powershell
python tools\synth\run_vendor_synth.py --config tools\synth\local.toml --tag negative --ignore-expected-failures
```

The `neg_report_*` cases check the report completeness. They synthesize a
real design, then `test_corrupt` empties or truncates one report (Quartus,
after the tool run: a file of the case directory) or runs the checks without
a design or with an empty ignored-exceptions report (Vivado, inside the
script). They pass only if the run fails with the `expect_error` message.
`test_corrupt` is meant for negative cases only.

A Quartus target whose family or device is not installed stops with an
`LM_ERROR` message naming the missing family or device; a missing Vivado part
is reported the same way.

## Constraint Example Checks

A case can list published constraint examples in `constraints`: a module
header (`"src/<module>.vhd"`, the commands under its `Vivado (XDC):` and
`Quartus (SDC):` headings) or a user guide block (`"docs/user_guide.md#name"`,
the fenced block after a `<!-- constraints: name -->` marker). The runner
applies them on a timing netlist that defines only the case clocks (and
asynchronous clock groups when `constraint_clock_groups = true`), then
checks:

- `constraint:<source>:<n>:objects`: every `get_*` collection of the command
  is non-empty, so a renamed signal is reported instead of silently matching
  nothing;
- `constraint:<source>:<n>:applied`: the command runs without a Tcl error;
- `constraints:listed`: `report_exceptions` lists one exception per
  `set_false_path`/`set_max_delay`/`set_min_delay`/`set_multicycle_path`;
- `constraints:not_ignored`: no exception is ignored or overridden
  (Vivado `report_exceptions -ignored`, Quartus `report_sdc -ignored`);
- `constraints:valid` (Quartus): no exception has status `Invalid`;
- `constraints:bus_skew_reported` (Vivado, examples with `set_bus_skew`):
  `report_bus_skew` lists the constraint.

Cases can also restrict themselves to some tools with `tools`, and an
observation case can list checks that must pass in `expect_passed_checks`
next to the ones that must fail.

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
