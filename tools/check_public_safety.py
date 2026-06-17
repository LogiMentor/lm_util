# SPDX-License-Identifier: Apache-2.0

"""Check tracked files for content that should not enter the public repo."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


MAX_FILE_SIZE = 1_000_000

FORBIDDEN_PATHS = (
    ".venv/",
    "sim/work/",
    "vendor_synth_out/",
    "vunit_out/",
    "tools/synth/local.toml",
)

FORBIDDEN_BASENAMES = {
    "modelsim.ini",
    "transcript",
}

FORBIDDEN_SUFFIXES = (
    ".jou",
    ".log",
    ".vcd",
    ".wlf",
)

OLD_PREFIX_PATTERN = r"\bC_" + "CES" + r"_|" + "CES" + r"_|\b" + "ces" + r"_"
OLD_DOC_PATTERN = "--" + "`protect|--" + r"\*|--" + "!|" + "@" + "brief"
LEGACY_CI_PATTERN = "git" + "lab"
ATTRIBUTION_PATTERN = r"(?i)\bco-authored-by\b|\b" + "co" + "dex" + r"\b"

TEXT_PATTERNS = (
    ("private key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("credential assignment", re.compile(r"(?i)\b(password|passwd|secret|api[_-]?key|access[_-]?token)\b\s*[:=]")),
    ("private IPv4 address", re.compile(r"\b(?:10|192\.168|172\.(?:1[6-9]|2\d|3[0-1]))\.\d{1,3}\.\d{1,3}\b")),
    ("old constant prefix", re.compile(OLD_PREFIX_PATTERN)),
    ("old documentation marker", re.compile(OLD_DOC_PATTERN)),
    ("legacy CI reference", re.compile(r"(?i)\b" + LEGACY_CI_PATTERN + r"\b")),
    ("generated attribution", re.compile(ATTRIBUTION_PATTERN)),
    ("machine-local Windows path", re.compile(r"[A-Za-z]:\\(?:Users|tmp|Xilinx|intelFPGA|lscc)\\")),
)


def tracked_files() -> list[Path]:
    result = subprocess.run(["git", "ls-files", "-z"], stdout=subprocess.PIPE, check=True)
    return [Path(item) for item in result.stdout.decode("utf-8").split("\0") if item]


def is_forbidden_path(path: Path) -> str | None:
    normalized = path.as_posix()
    for prefix in FORBIDDEN_PATHS:
        if normalized == prefix.rstrip("/") or normalized.startswith(prefix):
            return f"generated/local path is tracked: {normalized}"
    if path.name in FORBIDDEN_BASENAMES:
        return f"generated/local file is tracked: {normalized}"
    if path.suffix.lower() in FORBIDDEN_SUFFIXES:
        return f"generated log/waveform file is tracked: {normalized}"
    return None


def scan_file(path: Path) -> list[str]:
    errors: list[str] = []
    path_error = is_forbidden_path(path)
    if path_error:
        errors.append(path_error)

    try:
        size = path.stat().st_size
    except OSError as exc:
        return [f"cannot stat {path}: {exc}"]
    if size > MAX_FILE_SIZE:
        errors.append(f"large tracked file: {path} ({size} bytes)")

    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return errors
    except OSError as exc:
        errors.append(f"cannot read {path}: {exc}")
        return errors

    for label, pattern in TEXT_PATTERNS:
        for match in pattern.finditer(text):
            line_no = text.count("\n", 0, match.start()) + 1
            errors.append(f"{path}:{line_no}: {label}: {match.group(0)[:80]}")
    return errors


def main() -> int:
    errors: list[str] = []
    for path in tracked_files():
        errors.extend(scan_file(path))

    if errors:
        print("Public safety check failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print("Public safety check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
