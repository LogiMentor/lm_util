# lm_util User Guide

`lm_util` is a VHDL utility library. The synthesizable sources are compiled
into the `lm_util_lib` library and are intended to be instantiated directly from
user designs.

## Library Use

Add the package and the library before instantiating modules:

```vhdl
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
```

Instantiate modules by entity name:

```vhdl
inst_delay : entity lm_util_lib.lm_util_delay
  generic map (
    g_delay  => 8,
    g_data_w => 16
  )
  port map (
    clk_i  => clk_i,
    ce_i   => '1',
    din_i  => data_i,
    dout_o => data_dly_o
  );
```

Most modules intentionally do not provide default values for required generics.
Set them explicitly at each instantiation so the intended width, depth,
architecture, or reset behavior is visible in the design.

## Compile Order

Compile `lm_util_pkg.vhd` first, then the remaining files in `src/`.

With GHDL:

```sh
ghdl -a --std=08 --work=lm_util_lib src/lm_util_pkg.vhd
for f in src/*.vhd; do
  [ "$f" = "src/lm_util_pkg.vhd" ] || ghdl -a --std=08 --work=lm_util_lib "$f"
done
```

With Vivado Tcl:

```tcl
set_property target_language VHDL [current_project]
read_vhdl -library lm_util_lib -vhdl2008 src/lm_util_pkg.vhd
foreach f [lsort [glob src/*.vhd]] {
  if {[file tail $f] ne "lm_util_pkg.vhd"} {
    read_vhdl -library lm_util_lib -vhdl2008 $f
  }
}
```

With Quartus Tcl:

```tcl
set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
set_global_assignment -name VHDL_FILE src/lm_util_pkg.vhd -library lm_util_lib
foreach f [lsort [glob src/*.vhd]] {
  if {[file tail $f] ne "lm_util_pkg.vhd"} {
    set_global_assignment -name VHDL_FILE $f -library lm_util_lib
  }
}
```

The exact project commands for vendor tools depend on device family and local
installation. The local synthesis runner in `tools/synth/` generates Vivado,
Quartus, and Diamond smoke-test scripts from versioned cases.

## Simulation

Install the Python dependencies and run the VUnit regression:

```sh
python -m pip install -r requirements.txt
VUNIT_SIMULATOR=ghdl python sim/scripts/run.py --level fast --clean --output-path vunit_out
```

Use `--level full` for broader parameter sweeps:

```sh
VUNIT_SIMULATOR=ghdl python sim/scripts/run.py --level full --clean --output-path vunit_out
```

On Windows PowerShell, set the simulator variable before invoking the runner:

```powershell
$env:VUNIT_SIMULATOR = "ghdl"
python sim\scripts\run.py --level fast --clean --output-path vunit_out
```

The reference simulator is GHDL 6.0.0 with the LLVM backend, VHDL-2008
(`--std=08`); CI installs the same version. The Python dependencies, VUnit
included, are pinned in `requirements.txt`.

On Windows, keep the VUnit output directory short: the default `vunit_out`
at the repository root is fine. VUnit nests long per-test directory names
below it, and when a path exceeds 260 characters GHDL fails every test with
`cannot open ... .lst` followed by `compilation error`.

## Local Vendor Synthesis

Copy and edit the local tool configuration:

```powershell
Copy-Item tools\synth\local.example.toml tools\synth\local.toml
```

Enable the targets available on the machine and set executable paths, parts,
families, and devices. Then list selected targets and cases:

```powershell
python tools\synth\run_vendor_synth.py --config tools\synth\local.toml --list
```

Run a single vendor-sensitive case:

```powershell
python tools\synth\run_vendor_synth.py --config tools\synth\local.toml --target vivado-artix7 --case delay_srl_32x8_depth32_boundary
```

By default reports are written under the `output_dir` configured in
`tools/synth/local.toml`, usually `vendor_synth_out/<timestamp>/`. Passing
`--out` overrides that location for one run.

The generated `summary.md` links each result row to a target/case directory.
When synthesis completes, Vivado reports include:

- `reports/utilization_hier.rpt`
- `reports/timing_summary.rpt`
- `reports/synth.dcp`

## Module Reference

| Module | Purpose | Key Generics |
| --- | --- | --- |
| `lm_util_async_reset` | Asynchronous reset assertion and synchronous reset release. | `g_delay_len`, `g_rst_lvl` |
| `lm_util_barrel_shifter` | Combinational barrel shifter/rotator. | `g_data_w` |
| `lm_util_bitsum` | Registered population count. | `g_din_w`, `g_nof_first_stage_chunk` |
| `lm_util_ccd_resync` | Multi-stage single-bit CDC synchronizer. | `g_meta_levels` |
| `lm_util_ccd_switch` | Clock-domain level switch controlled by set/clear pulses. | `g_priority_lo`, `g_or_high`, `g_and_low` |
| `lm_util_ccd_sync_bus` | Request/ready bus transfer across clock domains. | `g_bus_width`, `g_meta_levels` |
| `lm_util_ccd_sync_pulse` | Pulse transfer across clock domains with busy feedback. | `g_delay_len` |
| `lm_util_clock_gen` | Clock divider/pulse generator for simulation and simple derived clocks. | `g_clock_div`, `g_clock_phase`, `g_pos_duty_cycle` |
| `lm_util_clock_measure` | Counts an unknown clock against a reference clock window. | `g_ref_clock_freq`, `g_clock_width` |
| `lm_util_clock_mux` | Clock mux using gated-clock style logic. | `g_num_clocks` |
| `lm_util_counter` | Configurable counter with load and watchdog timer output. | `g_data_w`, `g_wd_timer`, `g_dir` |
| `lm_util_crc_par` | Parallel CRC engine. | `g_polynomial`, `g_init_value`, `g_data_w`, `g_flip_data_in`, `g_flip_out`, `g_xor_out` |
| `lm_util_crc_ser` | Serial CRC engine. | `g_polynomial`, `g_init_value`, `g_flip_out`, `g_xor_out` |
| `lm_util_debouncer` | Debounces one input at a selected level. | `g_debounce_length`, `g_debounce_lvl` |
| `lm_util_delay` | Generic fixed delay line. | `g_delay`, `g_data_w` |
| `lm_util_delay_pulse` | Delays a single-bit pulse or level event. | `g_delay`, `g_pulse_level` |
| `lm_util_delay_srl` | Fixed delay line written for SRL/shift-register inference. | `g_delay`, `g_data_w`, `g_srl_depth` |
| `lm_util_delay_var` | Variable delay line with SRL or pulse/counter architecture. | `g_delay_max`, `g_data_w`, `g_arch_type`, `g_pulse_level` |
| `lm_util_edge_detector` | Single-clock edge detector. | `g_event_edge` |
| `lm_util_encoder` | Registered one-hot to binary encoder. | `g_data_w` |
| `lm_util_lfsr` | LFSR/xorshift pseudo-random sequence generator. | `g_data_w` |
| `lm_util_mux` | Combinational or registered generic multiplexer. | `g_data_w`, `g_arch_type`, `g_nof_inputs` |
| `lm_util_mux_or` | OR-combines data, valid, start-of-frame, and end-of-frame inputs. | `g_num_inputs`, `g_data_width` |
| `lm_util_pri_arbiter` | Fixed-priority request arbiter. | `g_units` |
| `lm_util_pulse_stretch` | Pulse stretcher with optional input resynchronizer. | `g_has_fixed_length`, `g_pulse_length`, `g_pulse_overlength`, `g_has_resync_stage`, `g_out_level` |
| `lm_util_rr_arbiter` | Round-robin request arbiter. | `g_units` |
| `lm_util_tick_gen` | Periodic one-cycle tick generator. | `g_clock_div` |

CRC engines support polynomial widths from 4 to 64 bits. `init_i` reloads
`g_init_value` synchronously between messages and clears `match_o`; reset keeps
the same behavior. `init_i` has priority over `dv_i`, so callers must not assert
it on the same cycle as a data word they intend to keep. For the parallel
engine, `g_flip_data_in` reflects bits within each input byte, so reflected wide
buses keep byte order intact and require `g_data_w` to be a multiple of 8.
`match_o` compares against the CRC residue derived from `g_xor_out`/`g_flip_out`,
which allows checking streams that include the transmitted CRC field rather than
the internal un-xored CRC register value. `match_o` is a level that is held
until reset, `init_i`, or the next checked data update; qualify it with the
protocol boundary that marks the end of the CRC field. In the serial engine,
`flush_i` shifts the CRC register for output serialization and does not update
`match_o`.

`lm_util_pkg` contains shared constants, types, and utility functions. Common
configuration constants include:

| Constant | Use |
| --- | --- |
| `C_LM_COMB`, `C_LM_SYNC` | Combinational or registered architecture selection. |
| `C_LM_SRL`, `C_LM_MEM`, `C_LM_PULSE` | Delay architecture selection. |
| `C_LM_ADD`, `C_LM_SUB`, `C_LM_ADDSUB` | Arithmetic mode selection. |
| `C_LM_AND`, `C_LM_OR`, `C_LM_XOR` | Logical operation selection. |
| `C_RISING_EDGE`, `C_FALLING_EDGE` | Edge detector selection. |

## Generic Configuration Notes

- Width generics drive port widths and must match the connected signals.
- Delay generics are expressed in destination clock cycles.
- CDC synchronizer depth generics should be at least `2` unless a design
  review justifies a different value.
- `lm_util_delay_srl.g_srl_depth` should match the target family inference
  depth, for example `32` for Xilinx SRLC32-style inference.
- Architecture selector generics use constants from `lm_util_pkg`; prefer
  named constants over raw integers in user designs.
- CRC polynomial, init, and XOR generics must all have matching CRC width.

## Sensitive Synthesis Cases

Some modules need vendor report review even when simulation passes:

| Module | What to Check |
| --- | --- |
| `lm_util_delay_srl` | SRL/shift-register inference and boundary delays such as 31/32/33 on Xilinx. |
| `lm_util_delay_var` | SRL versus pulse/counter implementation. |
| `lm_util_ccd_resync`, `lm_util_async_reset` | Flip-flop chains must not be converted into SRLs. |
| `lm_util_clock_mux` | Clock mux and keep/preserve handling on each target family. |

Use `tools/synth/cases.toml` to add or tune cases when a module is sensitive to
a specific vendor or family.

## CDC Attributes and Timing Constraints

The synchronizer chains (`lm_util_ccd_resync`, `lm_util_ccd_sync_pulse`,
`lm_util_async_reset`, `lm_util_clock_measure`, `lm_util_clock_mux`) carry
vendor-specific HDL attributes side by side; each synthesis tool applies its
own and ignores the rest:

| Tool | Attributes used |
| --- | --- |
| Xilinx Vivado | `async_reg = "true"`, `shreg_extract = "no"`, `keep = "true"` |
| Synplify Pro / Lattice LSE | `syn_preserve = true`, `syn_srlstyle = "registers"`, `syn_keep = true` |
| Intel Quartus | `altera_attribute` with `SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS`, `AUTO_SHIFT_REGISTER_RECOGNITION OFF`; keep through `syn_keep` |

The attributes only prevent structural mangling (SRL packing, register
merging) and help MTBF analysis. The crossing paths themselves must be
constrained in the project timing constraints.

### Constraint examples

Each CDC module header lists project-level constraints for Vivado (XDC) and
Quartus (SDC). The examples select registers and pins only by the internal
signal names of the module (`s_din_meta`, `s_meta_level`, `s_resync_reg`,
...). They contain no library, entity, instance or hierarchy name, so they
apply to every instance of the module and are not affected when the sources
are copied into another library or the entity is renamed. They stop matching
if an internal signal is renamed, which `tools/synth/run_vendor_synth.py`
detects (see the `neg_chain_renamed` case): it loads
every Vivado and Quartus example of the CDC modules and of this guide, fails
when a collection is empty, and fails when the tool does not list the
resulting exception or ignores it.

For `lm_util_ccd_resync`, which the other modules reuse:

<!-- constraints: lm_util_ccd_resync -->
```tcl
# Vivado (XDC)
set_false_path -to [get_cells -hier -filter {NAME =~ */s_din_meta_reg[0]}]

# Quartus (SDC)
set_false_path -to [get_registers {*s_din_meta[0]}]

# Lattice Diamond/LSE (LDC), not verified
set_false_path -to [get_cells {*/s_din_meta[0]}]
```

Keep the bus index inside a braced pattern: unbraced, `[0]` is a Tcl
command substitution; braced, Vivado and Quartus Prime 23.1 match it
literally (an escaped `\[0\]` matches nothing in Quartus).

To bound the crossing latency instead of cutting it, use `set_max_delay` on
the same targets (Vivado: `-datapath_only`). The `lm_util_ccd_sync_bus` data
bus uses `set_max_delay -datapath_only` and `set_bus_skew` (Quartus:
`set_max_delay` and `set_max_skew`), see its header. For `lm_util_clock_mux`,
also declare the input clocks as `set_clock_groups -logically_exclusive`.

### Alternative: asynchronous clock groups

When the clocks of the two domains are unrelated, the integrator can declare
them with `set_clock_groups -asynchronous` instead of the per-path
exceptions above. This removes every timing check between the groups, which
is what the single-bit synchronizers need, but it also overrides the
exceptions that bound the multi-bit crossings.

Observed with Vivado 2023.1 on the synthesized `lm_util_ccd_sync_bus`
(`g_bus_width = 8`, input clock 10 ns, output clock 7 ns), with the header
constraints `set_max_delay -datapath_only 7.0` and `set_bus_skew 7.0` on the
data bus:

| Constraints | `set_max_delay -datapath_only` | `set_bus_skew` |
| --- | --- | --- |
| Header constraints only | Applied (`max_dpo=7`) | Reported: 8 endpoints, skew 0.687 ns, slack 6.313 ns |
| Header constraints and `set_clock_groups -asynchronous` | Ignored: "Totally overridden path by CG" | Reported unchanged: 8 endpoints, skew 0.687 ns, slack 6.313 ns |

With clock groups the data path delay is therefore no longer bounded, while
the skew between the bus bits is still checked. If the integrator uses clock
groups, keep `set_bus_skew` on the `lm_util_ccd_sync_bus` data bus, and do
not rely on `set_max_delay -datapath_only` for any path between the grouped
clocks. The synthesis case `ccd_sync_bus_8_clock_groups` repeats this
observation on every run.

## Adding a Module

When adding a new utility block:

1. Add the synthesizable VHDL file under `src/`.
2. Add or update a self-checking VUnit testbench under `sim/tb/`.
3. Register VUnit configurations in `sim/scripts/run.py`.
4. Add a vendor synthesis case in `tools/synth/cases.toml` when inference or
   family-specific behavior matters.
5. Update this guide and the README module table.

Follow the repository coding standard in `docs/LM_VHDL_coding_standard.md`.
