# SPDX-License-Identifier: Apache-2.0

"""Check that the RTL in src/ is valid VHDL-93 and VHDL-2008.

For each standard (--std=93 and --std=08) the script analyzes every file of
src/ with GHDL into a temporary library lm_util_lib, without -fsynopsys or
-frelaxed, and then runs "ghdl --synth" on every entity with the generics of
tools/check_vhdl_std_generics.toml. Any analysis diagnostic (warning or
error) and any synthesis error is a failure; synthesis warnings (unsupported
vendor attributes, for example) are allowed. The script stops at the first
failure and prints the standard, the step and the GHDL message with file and
line.

Compile order: sim/scripts/run.py adds all of src/ to lm_util_lib and lets
VUnit order the files from their dependencies. This script does the
equivalent scan itself: every file declares one design unit ("entity <name>
is" or "package <name> is") and depends on the units it names as
"lm_util_lib.<unit>" (use clauses and entity instantiations). Files are
analyzed in topological order, ties broken by file name. A reference to a
unit that src/ does not declare, or a dependency cycle, is an error.

Only the Python standard library is used (tomllib needs Python 3.11).
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_SRC = ROOT_DIR / "src"
DEFAULT_GENERICS = Path(__file__).resolve().with_name("check_vhdl_std_generics.toml")
LIBRARY = "lm_util_lib"
STANDARDS = ("93", "08")

# comments, string literals and the character literal '"'
RE_NOT_CODE = re.compile(r"--[^\n]*|\"[^\"\n]*\"|'\"'")
RE_UNIT = re.compile(r"^\s*(entity|package)\s+(\w+)\s+is\b", re.IGNORECASE | re.MULTILINE)
RE_DEPENDENCY = re.compile(rf"\b{LIBRARY}\s*\.\s*(\w+)", re.IGNORECASE)


class CheckError(Exception):
    """Malformed source tree or data file, or a GHDL failure."""


def strip_non_code(text: str) -> str:
    return RE_NOT_CODE.sub(" ", text)


def scan_sources(src_dir: Path) -> tuple[list[Path], list[str]]:
    """Return the files of src_dir in compile order and the entity names."""
    files = sorted(src_dir.glob("*.vhd"))
    if not files:
        raise CheckError(f"no .vhd files in {src_dir}")

    unit_file: dict[str, Path] = {}
    entities: list[str] = []
    for path in files:
        units = RE_UNIT.findall(strip_non_code(path.read_text(encoding="utf-8")))
        if len(units) != 1:
            raise CheckError(f"{path}: expected one entity or package declaration, found {len(units)}")
        kind, name = units[0][0].lower(), units[0][1].lower()
        if name in unit_file:
            raise CheckError(f"{path}: unit {name} also declared in {unit_file[name]}")
        unit_file[name] = path
        if kind == "entity":
            entities.append(name)

    depends: dict[Path, set[Path]] = {}
    for path in files:
        deps = set()
        for unit in RE_DEPENDENCY.findall(strip_non_code(path.read_text(encoding="utf-8"))):
            unit = unit.lower()
            if unit not in unit_file:
                raise CheckError(f"{path}: {LIBRARY}.{unit} is not declared in {src_dir}")
            if unit_file[unit] != path:
                deps.add(unit_file[unit])
        depends[path] = deps

    order: list[Path] = []
    pending = list(files)
    while pending:
        ready = [path for path in pending if depends[path] <= set(order)]
        if not ready:
            raise CheckError("dependency cycle among " + ", ".join(path.name for path in pending))
        order.append(ready[0])
        pending.remove(ready[0])
    return order, sorted(entities)


def load_generics(path: Path, entities: list[str]) -> dict[str, dict[str, str]]:
    with path.open("rb") as handle:
        data = tomllib.load(handle)
    missing = sorted(set(entities) - set(data))
    unknown = sorted(set(data) - set(entities))
    if missing:
        raise CheckError(f"{path}: no table for {', '.join(missing)}")
    if unknown:
        raise CheckError(f"{path}: no entity in src/ for {', '.join(unknown)}")
    for entity, generics in data.items():
        if not isinstance(generics, dict) or not all(isinstance(v, str) for v in generics.values()):
            raise CheckError(f"{path}: [{entity}] values must be strings")
    return data


def display_path(path: Path) -> str:
    try:
        return os.path.relpath(path)
    except ValueError:  # another drive on Windows
        return str(path)


def run_ghdl(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, capture_output=True, text=True, stdin=subprocess.DEVNULL, check=False)


def first_lines(text: str, count: int = 5) -> str:
    lines = [line for line in text.strip().splitlines() if line.strip()]
    return "\n".join(lines[:count])


def check_standard(ghdl: str, std: str, order: list[Path], generics: dict[str, dict[str, str]]) -> None:
    with tempfile.TemporaryDirectory(prefix=f"lm_util_vhdl{std}_") as workdir:
        common = [f"--std={std}", f"--work={LIBRARY}", f"--workdir={workdir}"]

        for path in order:
            result = run_ghdl([ghdl, "-a", *common, display_path(path)])
            diagnostics = (result.stderr + result.stdout).strip()
            if result.returncode != 0 or diagnostics:
                raise CheckError(f"--std={std} analysis of {display_path(path)}:\n{first_lines(diagnostics)}")
        print(f"--std={std}: analyzed {len(order)} files, no diagnostics")

        for entity, values in generics.items():
            flags = [f"-g{name}={value}" for name, value in values.items()]
            result = run_ghdl([ghdl, "--synth", *common, *flags, entity])
            if result.returncode != 0:
                errors = [line for line in result.stderr.splitlines() if "error" in line.lower()]
                detail = "\n".join(errors[:5]) or first_lines(result.stderr)
                raise CheckError(f"--std={std} ghdl --synth {entity} {' '.join(flags)}:\n{detail}")
        print(f"--std={std}: ghdl --synth passed for {len(generics)} entities")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--src", type=Path, default=DEFAULT_SRC, help="RTL directory (default: src/)")
    parser.add_argument("--generics", type=Path, default=DEFAULT_GENERICS, help="generics data file")
    parser.add_argument("--ghdl", default=None, help="GHDL executable (default: ghdl from PATH)")
    parser.add_argument("--std", choices=STANDARDS, action="append", help="check only this standard (repeatable)")
    args = parser.parse_args()

    ghdl = args.ghdl or shutil.which("ghdl")
    if not ghdl:
        print("ERROR: ghdl not found in PATH (use --ghdl)")
        return 1
    version = run_ghdl([ghdl, "--version"]).stdout.splitlines()
    print(f"GHDL: {version[0] if version else 'unknown version'}")

    start = time.monotonic()
    try:
        order, entities = scan_sources(args.src.resolve())
        generics = load_generics(args.generics, entities)
        print("compile order: " + " ".join(path.stem for path in order))
        for std in args.std or STANDARDS:
            check_standard(ghdl, std, order, generics)
    except CheckError as exc:
        print(f"FAIL {exc}")
        return 1
    names = " and ".join(f"VHDL-{'19' if std == '93' else '20'}{std}" for std in args.std or STANDARDS)
    print(f"{display_path(args.src)} is valid {names} ({time.monotonic() - start:.1f} s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
