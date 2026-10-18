# SPDX-License-Identifier: Apache-2.0

"""Check that invalid generics stop GHDL elaboration with the intended message.

VUnit cannot express an expected elaboration failure, so each case analyzes
the library with GHDL and elaborates one entity with explicit generics. A
negative case passes only if elaboration fails and the output contains the
expected assertion text; a positive control with valid generics must
elaborate, so a failure is attributable to the generic under test.
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[2]
SRC_DIR = ROOT_DIR / "src"
# per-case logs, ignored by git (sim/work/)
LOG_ROOT = ROOT_DIR / "sim" / "work" / "elab_checks"
# test-only entities that call library functions at elaboration
ELAB_DIR = ROOT_DIR / "sim" / "elab"
LIBRARY = "lm_util_lib"
GHDL_FLAGS = ["--std=08", "-fsynopsys", "-frelaxed", f"--work={LIBRARY}"]


@dataclass
class Case:
    entity: str
    generics: dict[str, int] = field(default_factory=dict)
    # None means the elaboration must succeed (positive control)
    expect: str | None = None

    @property
    def name(self) -> str:
        values = ",".join(f"{key}={value}" for key, value in self.generics.items())
        return f"{self.entity}({values})"


ARCH_MSG = "g_arch_type must be C_LM_SRL or C_LM_PULSE"
WD_MSG = "g_wd_timer must be in range"
FORMAT_RANGE_MSG = "f_string_format: integer part out of the integer range"
FORMAT_PREC_MSG = "f_string_format: precision above 9"

CASES = [
    # lm_util_delay_var: unsupported architectures for every g_delay_max
    Case("lm_util_delay_var", {"g_delay_max": 1, "g_data_w": 1, "g_arch_type": 0, "g_pulse_level": 1}),
    Case("lm_util_delay_var", {"g_delay_max": 1, "g_data_w": 1, "g_arch_type": 2, "g_pulse_level": 1}),
    Case("lm_util_delay_var", {"g_delay_max": 1, "g_data_w": 1, "g_arch_type": 1, "g_pulse_level": 1}, ARCH_MSG),
    Case("lm_util_delay_var", {"g_delay_max": 1, "g_data_w": 1, "g_arch_type": 7, "g_pulse_level": 1}, ARCH_MSG),
    Case("lm_util_delay_var", {"g_delay_max": 4, "g_data_w": 1, "g_arch_type": 1, "g_pulse_level": 1}, ARCH_MSG),
    Case("lm_util_delay_var", {"g_delay_max": 4, "g_data_w": 1, "g_arch_type": 7, "g_pulse_level": 1}, ARCH_MSG),
    # lm_util_counter: the watchdog range check must not call f_ceil_log2(<1)
    Case("lm_util_counter", {"g_data_w": 8, "g_wd_timer": 5, "g_dir": 0}),
    Case("lm_util_counter", {"g_data_w": 8, "g_wd_timer": 0, "g_dir": 0}, WD_MSG),
    Case("lm_util_counter", {"g_data_w": 8, "g_wd_timer": -1, "g_dir": 0}, WD_MSG),
    # synchronizer depth guards
    Case("lm_util_ccd_resync", {"g_meta_levels": 2}),
    Case("lm_util_ccd_resync", {"g_meta_levels": 1}, "g_meta_levels must be at least 2"),
    Case("lm_util_ccd_sync_pulse", {"g_delay_len": 2}),
    Case("lm_util_ccd_sync_pulse", {"g_delay_len": 1}, "g_delay_len must be at least 2"),
    # f_string_format: inputs that cannot be formatted (see lm_elab_string_format)
    Case("lm_elab_string_format", {"g_case": 0}),
    Case("lm_elab_string_format", {"g_case": 1}, FORMAT_RANGE_MSG),
    Case("lm_elab_string_format", {"g_case": 2}, FORMAT_RANGE_MSG),
    Case("lm_elab_string_format", {"g_case": 3}, FORMAT_RANGE_MSG),
    Case("lm_elab_string_format", {"g_case": 4}, FORMAT_PREC_MSG),
]


def run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False)


def analyze(ghdl: str, workdir: Path, entities: list[str]) -> None:
    # import every source, then let GHDL analyze each entity under test with
    # its dependencies in the right order
    sources = sorted(str(path) for path in [*SRC_DIR.glob("*.vhd"), *ELAB_DIR.glob("*.vhd")])
    commands = [[ghdl, "-i", *GHDL_FLAGS, *sources]]
    commands += [[ghdl, "-m", *GHDL_FLAGS, entity] for entity in entities]
    for cmd in commands:
        result = run(cmd, workdir)
        if result.returncode != 0:
            print(result.stdout)
            raise SystemExit("GHDL analysis failed")


def check(ghdl: str, workdir: Path, case: Case, log_dir: Path, index: int) -> bool:
    generics = [f"-g{key}={value}" for key, value in case.generics.items()]
    # one executable per case: by default GHDL links <entity>.exe, and the
    # next case of the same entity relinked a file that could still be held
    # open after the previous run on Windows (ld exit status 1 or 5)
    exe = f"elab_case_{index:02d}"
    cmd = [ghdl, "--elab-run", *GHDL_FLAGS, "-o", exe, case.entity, *generics, "--stop-time=1ns"]
    started = dt.datetime.now()
    result = run(cmd, workdir)
    seconds = (dt.datetime.now() - started).total_seconds()
    if case.expect is None:
        ok = result.returncode == 0
        detail = "elaborated" if ok else "unexpected failure"
    else:
        ok = result.returncode != 0 and case.expect in result.stdout
        if ok:
            detail = "failed as expected"
        elif result.returncode == 0:
            detail = "elaborated, failure expected"
        else:
            detail = f"failed without '{case.expect}'"
    print(f"{'pass' if ok else 'FAIL'} {case.name}: {detail}")
    if not ok:
        print("  " + result.stdout.strip().replace("\n", "\n  "))
    log_name = f"{index:02d}_" + re.sub(r"[^A-Za-z0-9_=.-]+", "_", case.name).strip("_") + ".txt"
    (log_dir / log_name).write_text(
        "\n".join(
            [
                f"case: {case.name}",
                f"verdict: {'pass' if ok else 'FAIL'} ({detail})",
                f"expected: {case.expect or 'elaboration succeeds'}",
                f"returncode: {result.returncode}",
                f"started: {started.isoformat(timespec='milliseconds')}",
                f"seconds: {seconds:.3f}",
                f"workdir: {workdir}",
                f"command: {' '.join(cmd)}",
                "output:",
                result.stdout,
            ]
        ),
        encoding="utf-8",
    )
    return ok


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--ghdl", default="ghdl", help="GHDL executable")
    parser.add_argument("--workdir", type=Path, default=None, help="GHDL work directory (default: temporary)")
    parser.add_argument(
        "--log-dir",
        type=Path,
        default=None,
        help="directory for one log per case (default: sim/work/elab_checks/<timestamp>)",
    )
    args = parser.parse_args()

    ghdl = shutil.which(args.ghdl)
    if ghdl is None:
        print(f"GHDL executable not found: {args.ghdl}")
        return 1

    with tempfile.TemporaryDirectory(prefix="lm_elab_") as tmp:
        workdir = args.workdir.resolve() if args.workdir else Path(tmp)
        workdir.mkdir(parents=True, exist_ok=True)
        analyze(ghdl, workdir, sorted({case.entity for case in CASES}))
        log_dir = args.log_dir or LOG_ROOT / dt.datetime.now(tz=dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        log_dir.mkdir(parents=True, exist_ok=True)
        results = [check(ghdl, workdir, case, log_dir, index) for index, case in enumerate(CASES, start=1)]

    failed = results.count(False)
    summary = f"{len(results) - failed}/{len(results)} elaboration checks passed"
    lines = [f"{'pass' if ok else 'FAIL'} {case.name}" for case, ok in zip(CASES, results)]
    (log_dir / "summary.txt").write_text("\n".join([*lines, summary, ""]), encoding="utf-8")
    print(summary)
    print(f"Logs: {log_dir}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
