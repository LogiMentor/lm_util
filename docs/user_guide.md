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

The reference targets are `vivado-artix7` (Vivado 2023.1, `xc7a35tcsg324-1`)
and `quartus-max10` (Quartus Prime Lite 23.1std, MAX 10 `10M08SAE144C8G`) of
`tools/synth/local.example.toml`. Run the CDC structural and constraint
checks, then the negative cases, on both:

```powershell
python tools\synth\run_vendor_synth.py --config tools\synth\local.toml --target vivado-artix7 --target quartus-max10 --tag cdc --tag negative
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
| `lm_util_lfsr` | Fibonacci LFSR pseudo-random sequence generator. | `g_data_w` (3 to 168) |
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

`lm_util_lfsr` is a Fibonacci linear feedback shift register with XOR
feedback, for `g_data_w` from 3 to 168 bits (other values stop elaboration
with a failure). `rng_o` is the state register itself: on every rising edge of
`clk_i` it shifts towards the MSB and the new bit 0 is the XOR of the taps;
there is no enable. The taps come from Xilinx XAPP052, Table 3, except width
102: the table row `102, 101, 36, 35` is not a primitive polynomial (it
factors into degrees 3, 34 and 65, and some seeds repeat every 7 steps), so
the unit uses `102, 99, 97, 96` from the table of R. Ward and T. Molteno
("Table of Linear Feedback Shift Registers", University of Otago, Electronics
Technical Report 2012-1). Every tap set is primitive, which
`tools/check_lfsr_taps.py` verifies in CI: from any nonzero state the
sequence runs through all `2**g_data_w - 1` nonzero values.

Reset (`rst_n_i`, synchronous, active low) and `load_i` both load the
effective seed, which `rng_o` shows after that edge; while reset is held,
`rng_o` follows `seed_i` one clock cycle later. The first edge without reset
or load gives the next value of the sequence. All zeros is the lock-up state
of the XOR feedback, so a zero `seed_i` loads all ones instead. Until the
first edge with reset or load the register is not initialized: in simulation
`rng_o` is `'U'`.

```vhdl
inst_lfsr : entity lm_util_lib.lm_util_lfsr
  generic map(
    g_data_w => 32
  )
  port map(
    clk_i   => clk_i,
    rst_n_i => rst_n_i,
    load_i  => s_seed_load,
    seed_i  => s_seed,
    rng_o   => s_rng
  );
```

`lm_util_pkg` contains shared constants, types, and utility functions. Common
configuration constants include:

| Constant | Use |
| --- | --- |
| `C_LM_COMB`, `C_LM_SYNC` | Combinational or registered architecture selection. |
| `C_LM_SRL`, `C_LM_MEM`, `C_LM_PULSE` | Delay architecture selection. |
| `C_LM_ADD`, `C_LM_SUB`, `C_LM_ADDSUB` | Arithmetic mode selection. |
| `C_LM_AND`, `C_LM_OR`, `C_LM_XOR` | Logical operation selection. |
| `C_RISING_EDGE`, `C_FALLING_EDGE` | Edge detector selection. |

`f_string_format(value, precision)` formats a real with `precision` fraction
digits (`0` to `9`; `0` gives no decimal point) for reports and messages. It
rounds the exact binary value of the real to the nearest multiple of
`10**-precision`, and an exact half away from zero: `2.5` gives `"3"`,
`0.125` with precision 2 gives `"0.13"`, where C `printf` rounds both to
even. A decimal literal such as `9.9995` is not representable: it is the
nearest real, `9.99949999999999938893...`, so precision 3 gives `"9.999"`,
which can differ from rounding the literal by eye. A rounded integer part
above `integer'high`, or a precision above 9, stops elaboration or
simulation with a failure; a magnitude of `2**31` or more is rejected
before any intermediate computation. The exact rounding assumes that `real`
is IEEE 754 binary64 with round to nearest and that every intermediate
operation is rounded on its own (no fused multiply-add, no reassociation,
no extended precision); the VHDL standard does not require binary64 in
every case. It is verified with GHDL 6.0.0 (LLVM backend), not with Vivado
Simulator or Questa/ModelSim. The testbench compares the function with exact
reference vectors generated by `sim/scripts/string_format_vectors.py`
(Python `decimal`, fixed seed).

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
| CDC modules (`lm_util_ccd_resync`, `lm_util_ccd_sync_bus`, `lm_util_ccd_sync_pulse`, `lm_util_async_reset`, `lm_util_clock_measure`, `lm_util_clock_mux`) | Synchronizer chains stay discrete flip-flops recognized as synchronizers, and the published constraint examples match and apply; checked by the `cdc` cases. |
| `lm_util_clock_mux` | Clock mux and keep/preserve handling on each target family. |
| `lm_util_lfsr` | One `g_data_w`-bit register and no tool warning on the source; checked by the `lfsr` cases. |

Use `tools/synth/cases.toml` to add or tune cases when a module is sensitive to
a specific vendor or family.

## CDC Attributes and Timing Constraints

The synchronizer chains (`lm_util_ccd_resync`, `lm_util_ccd_sync_pulse`,
`lm_util_async_reset`, `lm_util_clock_measure`, `lm_util_clock_mux`) carry
vendor-specific HDL attributes side by side; each synthesis tool applies its
own and ignores the rest:

| Tool | Attributes used | Verified |
| --- | --- | --- |
| Xilinx Vivado | `async_reg = "true"`, `shreg_extract = "no"`, `keep = "true"` | Vivado 2023.1, `xc7a35tcsg324-1` |
| Intel Quartus | `altera_attribute` with `SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS`, `AUTO_SHIFT_REGISTER_RECOGNITION OFF`; keep through `syn_keep` | Quartus Prime Lite 23.1std, MAX 10 `10M08SAE144C8G` |
| Synplify Pro / Lattice LSE | `syn_preserve = true`, `syn_srlstyle = "registers"`, `syn_keep = true` | Not verified |
| Synplify Pro for Microchip Libero | same as Synplify Pro | Not verified |

"Verified" means that `tools/synth/run_vendor_synth.py` synthesizes every
synchronizer of the modules above with that tool and device and checks the
result structurally (see `tools/synth/README.md`): with Vivado each stage is
an `FD*` flip-flop with `ASYNC_REG = TRUE` and no SRL is inferred; with
Quartus the Timing Analyzer metastability report lists every stage as a
user-specified synchronizer and no shift register is inferred. Negative
cases show that the checks fail on a chain without attributes and on a
renamed chain. A check that concludes an absence (no SRL, no shift
register, no invalid or ignored exception) first requires a complete
netlist or report: an empty, truncated or gutted report fails the run with
`LM_ERROR`. This detects damaged or unrecognized reports, not a report
edited so that it stays well formed; `tools/synth/README.md` lists exactly
what is checked. The Synplify Pro / Lattice LSE attributes follow the vendor
documentation; no licensed Lattice or Microchip tool was available to verify
them, and the Lattice constraint examples are not verified either.

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

`lm_util_async_reset` and `lm_util_clock_measure` cut the asynchronous clear
pins of their reset synchronizer (`CLR` in Vivado, `clrn` in Quartus; see
their headers). The false path removes the asynchronous reset on those pins
from timing analysis, release included: no recovery/removal check is made on
them. The integrator remains responsible for the synchronized release and for
verifying how the synchronized reset is used downstream.

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
