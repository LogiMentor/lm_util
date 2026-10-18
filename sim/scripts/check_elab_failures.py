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
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[2]
SRC_DIR = ROOT_DIR / "src"
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


def check(ghdl: str, workdir: Path, case: Case) -> bool:
    generics = [f"-g{key}={value}" for key, value in case.generics.items()]
    result = run([ghdl, "--elab-run", *GHDL_FLAGS, case.entity, *generics, "--stop-time=1ns"], workdir)
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
    return ok


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--ghdl", default="ghdl", help="GHDL executable")
    parser.add_argument("--workdir", type=Path, default=None, help="GHDL work directory (default: temporary)")
    args = parser.parse_args()

    ghdl = shutil.which(args.ghdl)
    if ghdl is None:
        print(f"GHDL executable not found: {args.ghdl}")
        return 1

    with tempfile.TemporaryDirectory(prefix="lm_elab_") as tmp:
        workdir = args.workdir.resolve() if args.workdir else Path(tmp)
        workdir.mkdir(parents=True, exist_ok=True)
        analyze(ghdl, workdir, sorted({case.entity for case in CASES}))
        results = [check(ghdl, workdir, case) for case in CASES]

    failed = results.count(False)
    print(f"{len(results) - failed}/{len(results)} elaboration checks passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
