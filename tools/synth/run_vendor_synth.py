# SPDX-License-Identifier: Apache-2.0

"""Run local vendor synthesis smoke tests and collect reports.

The runner is intentionally local-only: FPGA vendor tools are large,
licensed, and machine-specific. This script keeps the campaign definition in
the repository while leaving tool paths, parts, and enabled targets to a local
configuration file.

Cases may declare structural checks (synchronizer chains, no shift-register
inference). Vivado checks query the synthesized netlist from Tcl; Quartus
checks read the Analysis & Synthesis report and the Timing Analyzer
metastability report. Each check writes one line to reports/lm_checks.txt and
any failing check fails the case.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import tomllib
except ModuleNotFoundError as exc:  # pragma: no cover - Python < 3.11 helper
    raise SystemExit("Python 3.11 or newer is required for TOML support.") from exc


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CASES = Path(__file__).with_name("cases.toml")
DEFAULT_CONFIG = Path(__file__).with_name("local.example.toml")
CHECKS_FILE = Path("reports") / "lm_checks.txt"
QUARTUS_PROJECT = "project"
# Tool failures that are not caused by the design and go away on a rerun:
# Vivado intermittently fails to read its own Tcl scripts or its .Xil scratch
# files on some Windows machines ("couldn't read file ...: No error").
TRANSIENT_FAILURES = [re.compile(r"^couldn't read file ")]
ATTEMPTS = 2
CASE_KEYS = {"name", "entity", "category", "generics", "ports", "tags", "description"}


@dataclass(frozen=True)
class Target:
    name: str
    tool: str
    executable: str
    enabled: bool
    options: dict[str, Any]


@dataclass(frozen=True)
class SynthCase:
    name: str
    entity: str
    category: str
    generics: dict[str, Any]
    ports: list[str]
    tags: list[str]
    description: str
    options: dict[str, Any]

    @property
    def chains(self) -> list[dict[str, Any]]:
        return list(self.options.get("chains", []))

    @property
    def no_shift_register(self) -> bool:
        return bool(self.options.get("no_shift_register", False))

    @property
    def has_checks(self) -> bool:
        return bool(self.chains) or self.no_shift_register

    def expected_failures(self, tool: str) -> list[str]:
        return list(self.options.get("expect_failed_checks", {}).get(tool, []))


def load_toml(path: Path) -> dict[str, Any]:
    try:
        with path.open("rb") as fh:
            return tomllib.load(fh)
    except FileNotFoundError as exc:
        raise SystemExit(f"TOML file not found: {path}") from exc
    except tomllib.TOMLDecodeError as exc:
        raise SystemExit(f"Invalid TOML in {path}: {exc}") from exc


def rel_to_repo(path: str | Path) -> Path:
    p = Path(path)
    return p if p.is_absolute() else (REPO_ROOT / p)


def tcl(value: str | Path) -> str:
    return "{" + str(value).replace("\\", "/") + "}"


def tcl_list(values: list[str]) -> str:
    return "{" + " ".join(tcl(value) for value in values) + "}"


def sdc_port(name: str) -> str:
    """Port pattern for get_ports; braced, so a bus index stays literal."""
    return "{" + name + "}"


def format_generic(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def source_files(cases_data: dict[str, Any]) -> list[Path]:
    source_cfg = cases_data.get("sources", {})
    patterns = source_cfg.get("files", ["src/lm_util_pkg.vhd", "src/*.vhd"])
    files: list[Path] = []

    for pattern in patterns:
        matches = sorted(REPO_ROOT.glob(pattern))
        if not matches:
            raise SystemExit(f"No files matched source pattern: {pattern}")
        files.extend(path.resolve() for path in matches if path.is_file())

    seen: set[Path] = set()
    ordered: list[Path] = []
    for path in files:
        if path not in seen:
            seen.add(path)
            ordered.append(path)
    return ordered


def load_targets(config: dict[str, Any]) -> list[Target]:
    targets: list[Target] = []
    for raw in config.get("targets", []):
        name = raw["name"]
        tool = raw["tool"].lower()
        executable = raw.get("executable", tool)
        enabled = bool(raw.get("enabled", False))
        options = {key: value for key, value in raw.items() if key not in {"name", "tool", "executable", "enabled"}}
        targets.append(Target(name=name, tool=tool, executable=executable, enabled=enabled, options=options))
    return targets


def load_cases(cases_data: dict[str, Any]) -> list[SynthCase]:
    cases: list[SynthCase] = []
    for raw in cases_data.get("cases", []):
        cases.append(
            SynthCase(
                name=raw["name"],
                entity=raw["entity"],
                category=raw.get("category", "generic"),
                generics=dict(raw.get("generics", {})),
                ports=list(raw.get("ports", [])),
                tags=list(raw.get("tags", [])),
                description=raw.get("description", ""),
                options={key: value for key, value in raw.items() if key not in CASE_KEYS},
            )
        )
    return cases


def case_sources(case: SynthCase, sources: list[Path]) -> list[Path]:
    extra = [rel_to_repo(path).resolve() for path in case.options.get("extra_files", [])]
    for path in extra:
        if not path.is_file():
            raise ValueError(f"Case {case.name}: extra file not found: {path}")
    return sources + extra


def port_name(port_decl: str) -> str:
    return port_decl.split(":", 1)[0].strip()


def wrapper_name() -> str:
    return "lm_synth_top"


def write_wrapper(case: SynthCase, case_dir: Path) -> tuple[str, Path]:
    if not case.ports:
        raise ValueError(f"Case {case.name} requires concrete wrapper ports.")

    top = wrapper_name()
    wrapper = case_dir / f"{top}.vhd"
    lines = [
        "-- SPDX-License-Identifier: Apache-2.0",
        "",
        "library ieee;",
        "use ieee.std_logic_1164.all;",
        "use ieee.numeric_std.all;",
        "",
        "library lm_util_lib;",
        "use lm_util_lib.lm_util_pkg.all;",
        "",
        f"entity {top} is",
        "  port (",
    ]
    for index, port in enumerate(case.ports):
        suffix = ";" if index < len(case.ports) - 1 else ""
        lines.append(f"    {port}{suffix}")
    lines.extend(
        [
            "  );",
            f"end entity {top};",
            "",
            f"architecture a_wrap of {top} is",
            "begin",
            f"  inst_dut : entity lm_util_lib.{case.entity}",
        ]
    )
    if case.generics:
        lines.append("    generic map (")
        items = list(case.generics.items())
        for index, (key, value) in enumerate(items):
            suffix = "," if index < len(items) - 1 else ""
            lines.append(f"      {key} => {format_generic(value)}{suffix}")
        lines.append("    )")
    lines.append("    port map (")
    names = [port_name(port) for port in case.ports]
    for index, name in enumerate(names):
        suffix = "," if index < len(names) - 1 else ""
        lines.append(f"      {name} => {name}{suffix}")
    lines.extend(
        [
            "    );",
            "end architecture a_wrap;",
            "",
        ]
    )
    wrapper.write_text("\n".join(lines), encoding="utf-8")
    return top, wrapper


# Netlist checks run inside Vivado after synth_design. A chain cell is a
# primitive whose leaf name is <signal>_reg, <signal>_reg[n] or, once packed
# into a shift register, <signal>_reg[n]_srl<k>; registers in a generate
# block carry a "<label>[i]." prefix in the same leaf name.
VIVADO_CHECK_PROCS = r"""
set lm_fh [open [file join $script_dir reports lm_checks.txt] w]
proc lm_check {name ok detail} {
  global lm_fh
  puts $lm_fh "LM_CHECK [expr {$ok ? {PASS} : {FAIL}}] $name $detail"
}
proc lm_chain_cells {signals} {
  set found {}
  foreach c [get_cells -hier -quiet -filter {IS_PRIMITIVE}] {
    set leaf [lindex [split [get_property NAME $c] /] end]
    if {[regexp {^(?:.*\.)?([^.]*)_reg(\[[0-9]+\])?(_srl[0-9]+)?$} $leaf -> base] && [lsearch -exact $signals $base] >= 0} {
      lappend found $c
    }
  }
  return $found
}
proc lm_check_chain {label signals expected} {
  set cells [lm_chain_cells $signals]
  set n [llength $cells]
  lm_check "chain:$label:count" [expr {$n == $expected}] "expected=$expected found=$n"
  set bad_type {}
  set bad_async {}
  foreach c $cells {
    if {![string match FD* [get_property REF_NAME $c]]} { lappend bad_type "[get_property NAME $c]([get_property REF_NAME $c])" }
    if {![string is true -strict [get_property ASYNC_REG $c]]} { lappend bad_async [get_property NAME $c] }
  }
  lm_check "chain:$label:cell_type" [expr {$n > 0 && [llength $bad_type] == 0}] "not_fd=[join $bad_type ,]"
  lm_check "chain:$label:async_reg" [expr {$n > 0 && [llength $bad_async] == 0}] "missing=[join $bad_async ,]"
}
"""


def vivado_checks(case: SynthCase) -> list[str]:
    if not case.has_checks:
        return []
    lines = VIVADO_CHECK_PROCS.strip().splitlines()
    for chain in case.chains:
        lines.append(f"lm_check_chain {tcl(chain['label'])} {tcl_list(chain['signals'])} {int(chain['registers'])}")
    if case.no_shift_register:
        lines.extend(
            [
                "set lm_srl [get_cells -hier -quiet -filter {REF_NAME =~ SRL*}]",
                "lm_check no_shift_register [expr {[llength $lm_srl] == 0}] \"srl_cells=[llength $lm_srl]\"",
            ]
        )
    lines.append("close $lm_fh")
    return lines


def write_vivado_script(path: Path, target: Target, case: SynthCase, top: str, sources: list[Path]) -> list[list[str]]:
    part = target.options.get("part")
    if not part:
        raise ValueError(f"Vivado target {target.name} requires a 'part' option.")
    script_dir = path.parent.resolve().as_posix()
    lines = [
        "# SPDX-License-Identifier: Apache-2.0",
        f"set script_dir {tcl(script_dir)}",
        "file mkdir [file join $script_dir reports]",
        f"if {{[llength [get_parts -quiet {tcl(part)}]] == 0}} {{",
        f"  puts \"LM_ERROR: Vivado part {part} is not installed\"",
        "  exit 2",
        "}",
        f"create_project -force {tcl(top)} [file join $script_dir project] -part {tcl(part)}",
        "set_param general.maxThreads 1",
        "set_property target_language VHDL [current_project]",
    ]
    lines.extend(f"read_vhdl -library lm_util_lib -vhdl2008 {tcl(src)}" for src in sources)
    lines.extend(
        [
            f"synth_design -top {tcl(top)} -part {tcl(part)}",
            "report_utilization -hierarchical -file [file join $script_dir reports utilization_hier.rpt]",
            "report_timing_summary -file [file join $script_dir reports timing_summary.rpt]",
            "write_checkpoint -force [file join $script_dir reports synth.dcp]",
        ]
    )
    lines.extend(vivado_checks(case))
    lines.extend(["exit", ""])
    path.write_text("\n".join(lines), encoding="utf-8")
    return [[target.executable, "-mode", "batch", "-source", path.as_posix()]]


def write_quartus_sdc(path: Path, case: SynthCase) -> None:
    clocks: dict[str, float] = dict(case.options.get("clocks", {}))
    lines = ["# SPDX-License-Identifier: Apache-2.0"]
    names: list[str] = []
    for port, period in clocks.items():
        name = "clk_" + re.sub(r"[^A-Za-z0-9]+", "_", port).strip("_")
        names.append(name)
        lines.append(f"create_clock -name {name} -period {float(period):.3f} [get_ports {sdc_port(port)}]")
    if len(names) > 1:
        groups = " ".join(f"-group [get_clocks {name}]" for name in names)
        lines.append(f"set_clock_groups -asynchronous {groups}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def quartus_sibling(executable: str, tool: str) -> str:
    """Path of another Quartus executable next to quartus_sh."""
    path = Path(executable)
    if path.parent == Path("."):
        return tool
    return str(path.with_name(tool + path.suffix))


def write_quartus_script(path: Path, target: Target, case: SynthCase, top: str, sources: list[Path]) -> list[list[str]]:
    family = target.options.get("family")
    device = target.options.get("device")
    if not family or not device:
        raise ValueError(f"Quartus target {target.name} requires 'family' and 'device' options.")
    sdc = path.with_name(f"{top}.sdc")
    write_quartus_sdc(sdc, case)
    lines = [
        "# SPDX-License-Identifier: Apache-2.0",
        "load_package device",
        "set lm_families [get_family_list]",
        f"if {{[lsearch -exact $lm_families {tcl(family)}] < 0}} {{",
        f"  puts \"LM_ERROR: Quartus device family '{family}' is not installed (installed: [join $lm_families {{, }}])\"",
        "  exit 2",
        "}",
        f"if {{[lsearch -exact [get_part_list -family {tcl(family)}] {tcl(device)}] < 0}} {{",
        f"  puts \"LM_ERROR: Quartus device '{device}' is not available in family '{family}'\"",
        "  exit 2",
        "}",
        "load_package flow",
        f"project_new {QUARTUS_PROJECT} -overwrite",
        f"set_global_assignment -name FAMILY {tcl(family)}",
        f"set_global_assignment -name DEVICE {tcl(device)}",
        f"set_global_assignment -name TOP_LEVEL_ENTITY {tcl(top)}",
        "set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008",
        f"set_global_assignment -name SDC_FILE {tcl(sdc.resolve())}",
    ]
    lines.extend(f"set_global_assignment -name VHDL_FILE {tcl(src)} -library lm_util_lib" for src in sources)
    lines.append("execute_module -tool map")
    if case.chains:
        # synchronizer identification and MTBF need the fitted netlist
        lines.append("execute_module -tool fit")
    lines.extend(["project_close", ""])
    path.write_text("\n".join(lines), encoding="utf-8")
    commands = [[target.executable, "-t", path.as_posix()]]

    if case.chains:
        sta = path.with_name("run_quartus_sta.tcl")
        sta.write_text(
            "\n".join(
                [
                    "# SPDX-License-Identifier: Apache-2.0",
                    f"project_open {QUARTUS_PROJECT}",
                    "create_timing_netlist",
                    "read_sdc",
                    "update_timing_netlist",
                    "file mkdir reports",
                    "report_metastability -file reports/metastability.rpt -nchains 1000",
                    "delete_timing_netlist",
                    "project_close",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        commands.append([quartus_sibling(target.executable, "quartus_sta"), "-t", sta.as_posix()])
    return commands


def write_diamond_script(path: Path, target: Target, top: str, sources: list[Path]) -> list[list[str]]:
    device = target.options.get("device")
    if not device:
        raise ValueError(f"Diamond target {target.name} requires a 'device' option.")
    impl = target.options.get("implementation", "synth")
    synthesis = target.options.get("synthesis", "synplify")
    lines = [
        "# SPDX-License-Identifier: Apache-2.0",
        "# Diamond TCL command names vary across versions; verify this template",
        "# with the local Diamond installation before relying on pass/fail status.",
        f"prj_project new -name {top} -impl {impl} -dev {device} -synthesis {synthesis}",
    ]
    lines.extend(f"prj_src add {tcl(src)}" for src in sources)
    lines.extend(
        [
            f"prj_impl option top {top}",
            "prj_run Synthesis",
            "prj_project save",
            "prj_project close",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")
    return [[target.executable, *target.options.get("arguments", []), path.as_posix()]]


def write_script(target: Target, case: SynthCase, case_dir: Path, sources: list[Path]) -> list[list[str]]:
    top, wrapper = write_wrapper(case, case_dir)
    all_sources = case_sources(case, sources) + [wrapper.resolve()]
    if target.tool == "vivado":
        return write_vivado_script(case_dir / "run_vivado.tcl", target, case, top, all_sources)
    if target.tool == "quartus":
        return write_quartus_script(case_dir / "run_quartus.tcl", target, case, top, all_sources)
    if target.tool == "diamond":
        if case.has_checks:
            raise ValueError("Structural checks are not implemented for Diamond.")
        return write_diamond_script(case_dir / "run_diamond.tcl", target, top, all_sources)
    raise ValueError(f"Unsupported tool kind: {target.tool}")


def resolve_executable(command: str) -> str | None:
    if Path(command).exists():
        return command
    return shutil.which(command)


def expectation_patterns(target: Target, case: SynthCase) -> list[str]:
    patterns: list[str] = []
    patterns.extend(case.options.get("expect_regex", []))
    patterns.extend(case.options.get(f"expect_{target.tool}_regex", []))
    patterns.extend(target.options.get("expect_regex", []))
    return patterns


def collect_report_text(case_dir: Path) -> str:
    """Text of the vendor reports only; generated scripts and logs are excluded."""
    chunks: list[str] = []
    for path in sorted(case_dir.rglob("*")):
        if path.is_file() and path.suffix.lower() in {".rpt", ".srr"}:
            try:
                chunks.append(f"\n--- {path.relative_to(case_dir)} ---\n")
                chunks.append(path.read_text(encoding="utf-8", errors="ignore"))
            except OSError:
                pass
    return "".join(chunks)


def first_failure_message(case_dir: Path) -> str:
    log_paths = [case_dir / "stdout.log", case_dir / "stderr.log"]
    log_paths.extend(sorted(path for path in case_dir.glob("*.log") if path.name not in {"stdout.log", "stderr.log"}))
    patterns = [
        # anchored: Vivado echoes the sourced script, including the check itself
        r"^LM_ERROR:.*",
        r"couldn't read file.*",
        r"can't create directory.*",
        r"package .*isn't loaded.*",
        r"invalid part.*",
        r"No parts matched.*",
        r"ERROR:.*",
        r"Error \(.*",
        r"Command failed.*",
    ]

    for pattern in patterns:
        regex = re.compile(pattern, flags=re.IGNORECASE)
        for path in log_paths:
            if not path.exists():
                continue
            try:
                for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
                    match = regex.search(line.strip())
                    if match:
                        return match.group(0)[:180]
            except OSError:
                continue
    return ""


# --- Quartus report parsing -------------------------------------------------


def rpt_rows(lines: list[str]) -> list[list[str]]:
    """Cells of the ';'-delimited table rows in a Quartus report fragment."""
    rows: list[list[str]] = []
    for line in lines:
        if line.startswith(";") and line.rstrip().endswith(";"):
            rows.append([cell for cell in line.rstrip()[1:-1].split(";")])
    return rows


def rpt_panel(text: str, title: str) -> list[list[str]] | None:
    """Rows of the first panel whose title row matches, None if absent."""
    lines = text.splitlines()
    for index, line in enumerate(lines):
        cells = rpt_rows([line])
        if cells and len(cells[0]) == 1 and cells[0][0].strip() == title:
            body: list[str] = []
            for follow in lines[index + 1 :]:
                if not follow.strip():
                    break
                body.append(follow)
            return rpt_rows(body)
    return None


def leaf_matches(register: str, signals: list[str]) -> bool:
    leaf = register.split("|")[-1].strip()
    base = re.sub(r"\[\d+\]$", "", leaf)
    return base in signals


def parse_metastability(text: str) -> list[dict[str, Any]]:
    """Synchronizer chains of a report_metastability file."""
    chains: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    in_registers = False
    for line in text.splitlines():
        if line.startswith("Synchronizer Chain #"):
            current = {"method": "", "registers": []}
            chains.append(current)
            in_registers = False
            continue
        if current is None:
            continue
        cells = rpt_rows([line])
        if not cells:
            continue
        first = cells[0][0]
        if first.startswith("  "):
            if in_registers:
                current["registers"].append(first.strip())
            continue
        key = first.strip()
        in_registers = key == "Synchronization Registers"
        if key == "Method of Synchronizer Identification" and len(cells[0]) > 1:
            current["method"] = cells[0][1].strip()
    return chains


def quartus_checks(case: SynthCase, case_dir: Path) -> list[str]:
    lines: list[str] = []

    def check(name: str, ok: bool, detail: str) -> None:
        lines.append(f"LM_CHECK {'PASS' if ok else 'FAIL'} {name} {detail}")

    if case.chains:
        meta_path = case_dir / "reports" / "metastability.rpt"
        chains = parse_metastability(meta_path.read_text(encoding="utf-8", errors="ignore")) if meta_path.exists() else None
        for chain in case.chains:
            label, signals, expected = chain["label"], list(chain["signals"]), int(chain["registers"])
            if chains is None:
                check(f"chain:{label}:count", False, "metastability report missing")
                check(f"chain:{label}:synchronizer", False, "metastability report missing")
                continue
            found = [(reg, item["method"]) for item in chains for reg in item["registers"] if leaf_matches(reg, signals)]
            check(f"chain:{label}:count", len(found) == expected, f"expected={expected} found={len(found)}")
            not_user = [reg for reg, method in found if method != "User Specified"]
            check(
                f"chain:{label}:synchronizer",
                bool(found) and not not_user,
                f"identified={len(found)} not_user_specified={','.join(not_user)}",
            )

    if case.no_shift_register:
        map_path = case_dir / f"{QUARTUS_PROJECT}.map.rpt"
        if not map_path.exists():
            check("no_shift_register", False, "Analysis & Synthesis report missing")
        else:
            panel = rpt_panel(map_path.read_text(encoding="utf-8", errors="ignore"), "Registers Packed Into Inferred Megafunctions")
            packed = [row[0].strip() for row in (panel or []) if len(row) >= 3 and row[2].strip() == "SHIFT_TAPS"]
            check("no_shift_register", not packed, f"shift_taps_registers={len(packed)}")
    return lines


# --- Result evaluation ------------------------------------------------------


def read_checks(path: Path) -> list[tuple[str, str, str]]:
    checks: list[tuple[str, str, str]] = []
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        parts = line.split(" ", 3)
        if len(parts) >= 3 and parts[0] == "LM_CHECK":
            checks.append((parts[1], parts[2], parts[3] if len(parts) > 3 else ""))
    return checks


def evaluate_checks(target: Target, case: SynthCase, case_dir: Path, ignore_expected: bool) -> tuple[str, str, list[dict[str, str]]]:
    checks_path = case_dir / CHECKS_FILE
    if target.tool == "quartus":
        checks_path.parent.mkdir(parents=True, exist_ok=True)
        checks_path.write_text("\n".join(quartus_checks(case, case_dir)) + "\n", encoding="utf-8")
    if not checks_path.exists():
        return "failed", f"structural check report missing: {CHECKS_FILE.as_posix()}", []

    checks = read_checks(checks_path)
    details = [{"status": status, "name": name, "detail": detail} for status, name, detail in checks]
    if not checks:
        return "failed", "structural check report is empty", details
    failed = [name for status, name, _ in checks if status != "PASS"]
    expected = [] if ignore_expected else case.expected_failures(target.tool)

    if expected:
        not_failing = [name for name in expected if name not in failed]
        if not_failing:
            return "failed", "negative case: expected failing checks passed: " + ", ".join(not_failing), details
        return "passed", "negative case: failed as expected: " + ", ".join(failed), details
    if failed:
        return "failed", "failed checks: " + ", ".join(failed), details
    return "passed", f"{len(checks)} structural checks passed", details


def run_one(target: Target, case: SynthCase, out_root: Path, sources: list[Path], dry_run: bool, ignore_expected: bool) -> dict[str, Any]:
    case_dir = out_root / target.name / case.name
    case_dir.mkdir(parents=True, exist_ok=True)
    (case_dir / "case.json").write_text(
        json.dumps(
            {
                "target": target.name,
                "tool": target.tool,
                "case": case.name,
                "entity": case.entity,
                "category": case.category,
                "generics": case.generics,
                "tags": case.tags,
                "description": case.description,
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    result: dict[str, Any] = {
        "target": target.name,
        "tool": target.tool,
        "case": case.name,
        "entity": case.entity,
        "category": case.category,
        "status": "planned" if dry_run else "unknown",
        "returncode": None,
        "seconds": 0.0,
        "directory": str(case_dir),
        "message": "",
        "checks": [],
        "missing_expectations": [],
    }

    try:
        commands = write_script(target, case, case_dir, sources)
    except Exception as exc:  # noqa: BLE001 - report generation errors cleanly
        result.update(status="error", error=str(exc), message=str(exc))
        return result

    result["command"] = commands

    if dry_run:
        return result

    for command in commands:
        executable = resolve_executable(command[0])
        if executable is None:
            message = f"Tool executable not found: {command[0]}"
            result.update(status="skipped", error=message, message=message)
            return result
        command[0] = executable

    started = time.monotonic()
    for attempt in range(1, ATTEMPTS + 1):
        with (case_dir / "stdout.log").open("w", encoding="utf-8") as stdout, (case_dir / "stderr.log").open("w", encoding="utf-8") as stderr:
            for command in commands:
                proc = subprocess.run(command, cwd=case_dir, stdout=stdout, stderr=stderr, text=True, check=False)
                result["returncode"] = proc.returncode
                if proc.returncode != 0:
                    break
        message = first_failure_message(case_dir) if result["returncode"] != 0 else ""
        if not any(pattern.search(message) for pattern in TRANSIENT_FAILURES) or attempt == ATTEMPTS:
            break
        result.setdefault("retries", []).append(message)
        print(f"  retrying after a transient tool failure: {message}")
    result["seconds"] = round(time.monotonic() - started, 3)

    if result["returncode"] != 0:
        result.update(status="failed", message=first_failure_message(case_dir))
        return result

    if case.has_checks:
        status, message, details = evaluate_checks(target, case, case_dir, ignore_expected)
        result.update(status=status, message=message, checks=details)
        if status != "passed":
            return result

    # regex expectations are hints on the vendor reports; they never pass a
    # structural check and they cannot hide a failing one
    text = collect_report_text(case_dir)
    missing = [pattern for pattern in expectation_patterns(target, case) if not re.search(pattern, text, flags=re.MULTILINE)]
    result["missing_expectations"] = missing
    if missing:
        hint = "Missing report hints: " + ", ".join(missing)
        result.update(status="review", message=f"{result['message']}; {hint}" if result["message"] else hint)
    else:
        result["status"] = "passed"
    return result


def markdown_cell(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def write_summary(out_root: Path, results: list[dict[str, Any]]) -> None:
    out_root.mkdir(parents=True, exist_ok=True)
    (out_root / "summary.json").write_text(json.dumps(results, indent=2), encoding="utf-8")

    lines = [
        "# Vendor Synthesis Summary",
        "",
        "| Target | Tool | Case | Entity | Status | Seconds | Directory | Notes |",
        "| --- | --- | --- | --- | --- | ---: | --- | --- |",
    ]
    for item in results:
        directory = Path(item["directory"])
        try:
            display_dir = directory.relative_to(out_root).as_posix()
        except ValueError:
            display_dir = str(directory)
        lines.append(
            f"| {item['target']} | {item['tool']} | {item['case']} | {item['entity']} | "
            f"{item['status']} | {item.get('seconds', 0.0)} | `{display_dir}` | "
            f"{markdown_cell(item.get('message', ''))} |"
        )
    lines.append("")
    lines.append(
        "Statuses: `passed` means the tool returned success and every structural check passed "
        "(for a negative case: every expected check failed) and the report hints matched; "
        "`review` means the checks passed but a report hint was not found; "
        "`failed` means the tool failed or a structural check failed."
    )
    checked = [item for item in results if item.get("checks")]
    if checked:
        lines.extend(["", "## Structural checks", ""])
        for item in checked:
            lines.append(f"### {item['target']} / {item['case']}")
            lines.append("")
            for check in item["checks"]:
                lines.append(f"- {check['status']} `{check['name']}` {markdown_cell(check['detail'])}")
            lines.append("")
    (out_root / "summary.md").write_text("\n".join(lines), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cases", type=Path, default=DEFAULT_CASES)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--target", action="append", default=[], help="Run only the named target; can be repeated.")
    parser.add_argument("--tool", action="append", default=[], help="Run only targets of this tool kind; can be repeated.")
    parser.add_argument("--case", action="append", default=[], help="Run only the named case; can be repeated.")
    parser.add_argument("--tag", action="append", default=[], help="Run only cases carrying this tag; can be repeated.")
    parser.add_argument("--list", action="store_true", help="List selected targets and cases without generating scripts.")
    parser.add_argument("--dry-run", action="store_true", help="Generate scripts and summary without launching vendor tools.")
    parser.add_argument("--include-disabled", action="store_true", help="Include disabled targets from the local configuration.")
    parser.add_argument(
        "--ignore-expected-failures",
        action="store_true",
        help="Evaluate negative cases like regular ones, so their failing checks fail the run.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    cases_data = load_toml(rel_to_repo(args.cases))
    config = load_toml(rel_to_repo(args.config))
    targets = load_targets(config)
    cases = load_cases(cases_data)

    if not args.include_disabled:
        targets = [target for target in targets if target.enabled]
    if args.target:
        wanted = set(args.target)
        targets = [target for target in targets if target.name in wanted]
    if args.tool:
        wanted_tools = {tool.lower() for tool in args.tool}
        targets = [target for target in targets if target.tool in wanted_tools]
    if args.case:
        wanted_cases = set(args.case)
        cases = [case for case in cases if case.name in wanted_cases]
    if args.tag:
        wanted_tags = set(args.tag)
        cases = [case for case in cases if wanted_tags.intersection(case.tags)]

    if args.list:
        print("Targets:")
        for target in targets:
            print(f"  - {target.name} ({target.tool})")
        print("Cases:")
        for case in cases:
            print(f"  - {case.name} ({case.entity}) [{', '.join(case.tags)}]")
        return 0

    if not targets:
        raise SystemExit("No targets selected. Enable targets in local config or use --include-disabled.")
    if not cases:
        raise SystemExit("No cases selected.")

    timestamp = dt.datetime.now(tz=dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_cfg = config.get("run", {})
    out_root = rel_to_repo(args.out or run_cfg.get("output_dir", "vendor_synth_out")) / timestamp
    sources = source_files(cases_data)

    results: list[dict[str, Any]] = []
    for target in targets:
        for case in cases:
            if target.tool == "diamond" and case.has_checks:
                continue
            print(f"[{target.name}] {case.name}")
            result = run_one(target, case, out_root, sources, dry_run=args.dry_run, ignore_expected=args.ignore_expected_failures)
            print(f"  -> {result['status']} {result['message']}")
            results.append(result)

    write_summary(out_root, results)
    print(f"Summary: {out_root / 'summary.md'}")
    return 0 if all(item["status"] in {"passed", "planned", "skipped", "review"} for item in results) else 1


if __name__ == "__main__":
    sys.exit(main())
