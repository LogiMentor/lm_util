# SPDX-License-Identifier: Apache-2.0

"""Run local vendor synthesis smoke tests and collect reports.

The runner is intentionally local-only: FPGA vendor tools are large,
licensed, and machine-specific. This script keeps the campaign definition in
the repository while leaving tool paths, parts, and enabled targets to a local
configuration file.
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
                options={key: value for key, value in raw.items() if key not in {"name", "entity", "category", "generics", "ports", "tags", "description"}},
            )
        )
    return cases


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


def write_vivado_script(path: Path, target: Target, top: str, sources: list[Path]) -> list[str]:
    part = target.options.get("part")
    if not part:
        raise ValueError(f"Vivado target {target.name} requires a 'part' option.")
    script_dir = path.parent.resolve().as_posix()
    lines = [
        "# SPDX-License-Identifier: Apache-2.0",
        f"set script_dir {tcl(script_dir)}",
        "file mkdir [file join $script_dir reports]",
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
            "exit",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")
    return [target.executable, "-mode", "batch", "-source", path.as_posix()]


def write_quartus_script(path: Path, target: Target, top: str, sources: list[Path]) -> list[str]:
    family = target.options.get("family")
    device = target.options.get("device")
    if not family or not device:
        raise ValueError(f"Quartus target {target.name} requires 'family' and 'device' options.")
    lines = [
        "# SPDX-License-Identifier: Apache-2.0",
        "load_package flow",
        "project_new project -overwrite",
        f"set_global_assignment -name FAMILY {tcl(family)}",
        f"set_global_assignment -name DEVICE {tcl(device)}",
        f"set_global_assignment -name TOP_LEVEL_ENTITY {tcl(top)}",
        "set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008",
    ]
    lines.extend(f"set_global_assignment -name VHDL_FILE {tcl(src)} -library lm_util_lib" for src in sources)
    lines.extend(
        [
            "execute_flow -compile",
            "project_close",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")
    return [target.executable, "-t", path.as_posix()]


def write_diamond_script(path: Path, target: Target, top: str, sources: list[Path]) -> list[str]:
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
    return [target.executable, *target.options.get("arguments", []), path.as_posix()]


def write_script(target: Target, case: SynthCase, case_dir: Path, sources: list[Path]) -> list[str]:
    top, wrapper = write_wrapper(case, case_dir)
    case_sources = sources + [wrapper.resolve()]
    if target.tool == "vivado":
        return write_vivado_script(case_dir / "run_vivado.tcl", target, top, case_sources)
    if target.tool == "quartus":
        return write_quartus_script(case_dir / "run_quartus.tcl", target, top, case_sources)
    if target.tool == "diamond":
        return write_diamond_script(case_dir / "run_diamond.tcl", target, top, case_sources)
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


def collect_text(case_dir: Path) -> str:
    chunks: list[str] = []
    for path in case_dir.rglob("*"):
        if path.is_file() and path.suffix.lower() in {".log", ".rpt", ".txt", ".tcl", ".qsf", ".srr"}:
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


def run_one(target: Target, case: SynthCase, out_root: Path, sources: list[Path], dry_run: bool) -> dict[str, Any]:
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
        "missing_expectations": [],
    }

    try:
        command = write_script(target, case, case_dir, sources)
    except Exception as exc:  # noqa: BLE001 - report generation errors cleanly
        result.update(status="error", error=str(exc), message=str(exc))
        return result

    result["command"] = command

    if dry_run:
        return result

    executable = resolve_executable(command[0])
    if executable is None:
        message = f"Tool executable not found: {command[0]}"
        result.update(status="skipped", error=message, message=message)
        return result
    command[0] = executable
    result["command"] = command

    started = time.monotonic()
    with (case_dir / "stdout.log").open("w", encoding="utf-8") as stdout, (case_dir / "stderr.log").open("w", encoding="utf-8") as stderr:
        proc = subprocess.run(command, cwd=case_dir, stdout=stdout, stderr=stderr, text=True, check=False)
    result["seconds"] = round(time.monotonic() - started, 3)
    result["returncode"] = proc.returncode

    if proc.returncode != 0:
        result.update(status="failed", message=first_failure_message(case_dir))
        return result

    text = collect_text(case_dir)
    missing = [pattern for pattern in expectation_patterns(target, case) if not re.search(pattern, text, flags=re.MULTILINE)]
    result["missing_expectations"] = missing
    if missing:
        result.update(status="review", message="Missing expectations: " + ", ".join(missing))
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
    lines.append("Statuses: `passed` means the tool returned success and configured regex expectations matched; `review` means synthesis succeeded but one or more report patterns were not found.")
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
            print(f"[{target.name}] {case.name}")
            results.append(run_one(target, case, out_root, sources, dry_run=args.dry_run))

    write_summary(out_root, results)
    print(f"Summary: {out_root / 'summary.md'}")
    return 0 if all(item["status"] in {"passed", "planned", "skipped", "review"} for item in results) else 1


if __name__ == "__main__":
    sys.exit(main())
