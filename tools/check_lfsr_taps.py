# SPDX-License-Identifier: Apache-2.0

"""Check that every lm_util_lfsr tap set is a primitive polynomial over GF(2).

The taps are read from f_lfsr in src/lm_util_lfsr.vhd. Bit i of the register
(i = 0 .. N-1) holds the feedback bit computed i + 1 clock cycles earlier, so
a tap set T gives the characteristic polynomial

    P(x) = x^N + sum(x^(N-1-i) for i in T)

and the register runs through all 2^N - 1 nonzero states if and only if P is
primitive: irreducible (Rabin test) and of order 2^N - 1, i.e.
x^((2^N - 1) / r) != 1 mod P for every prime r dividing 2^N - 1.

The prime factors of 2^N - 1 come from tools/check_lfsr_taps_factors.txt.
That file is checked too: the product of the factors must be 2^N - 1 and
every factor must be prime. Primality uses a deterministic Miller-Rabin test
(bases 2 .. 41) below 3.3 * 10^24 and the Baillie-PSW test above, which is a
strong probable-prime test with no known counterexample.

Only the Python standard library is used.
"""

from __future__ import annotations

import argparse
import re
import sys
import time
from math import gcd, isqrt
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT_DIR / "src" / "lm_util_lfsr.vhd"
DEFAULT_FACTORS = Path(__file__).resolve().with_name("check_lfsr_taps_factors.txt")
WIDTH_MIN = 3
WIDTH_MAX = 168

SMALL_PRIMES = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41)
# Miller-Rabin with SMALL_PRIMES as bases is deterministic below this bound
MR_DETERMINISTIC_BOUND = 3_317_044_064_679_887_385_961_981


class CheckError(Exception):
    """Malformed source or data file."""


# ---------------------------------------------------------------------------
# Primality
# ---------------------------------------------------------------------------

def miller_rabin(n: int, base: int) -> bool:
    """Strong probable-prime test of odd n > 2 to the given base."""
    d, s = n - 1, 0
    while d % 2 == 0:
        d //= 2
        s += 1
    x = pow(base, d, n)
    if x in (1, n - 1):
        return True
    for _ in range(s - 1):
        x = x * x % n
        if x == n - 1:
            return True
    return False


def jacobi(a: int, n: int) -> int:
    """Jacobi symbol (a/n) for odd n > 0."""
    a %= n
    result = 1
    while a:
        while a % 2 == 0:
            a //= 2
            if n % 8 in (3, 5):
                result = -result
        a, n = n, a
        if a % 4 == 3 and n % 4 == 3:
            result = -result
        a %= n
    return result if n == 1 else 0


def strong_lucas(n: int) -> bool:
    """Strong Lucas probable-prime test with Selfridge parameters (odd n, not a square)."""
    d_param = 5
    while True:
        j = jacobi(d_param, n)
        if j == -1:
            break
        if j == 0 and abs(d_param) != n:
            return False
        d_param = -d_param - 2 if d_param > 0 else -d_param + 2
    p_param, q_param = 1, (1 - d_param) // 4

    def half(value: int) -> int:
        # value / 2 mod n, n odd
        return (value + n if value % 2 else value) // 2 % n

    d, s = n + 1, 0
    while d % 2 == 0:
        d //= 2
        s += 1
    u, v, qk = 1, p_param, q_param % n
    for bit in bin(d)[3:]:
        u, v = u * v % n, (v * v - 2 * qk) % n
        qk = qk * qk % n
        if bit == "1":
            u, v = half(p_param * u + v), half(d_param * u + p_param * v)
            qk = qk * q_param % n
    if u == 0 or v == 0:
        return True
    for _ in range(s - 1):
        v = (v * v - 2 * qk) % n
        qk = qk * qk % n
        if v == 0:
            return True
    return False


def is_prime(n: int) -> bool:
    if n < 2:
        return False
    for p in SMALL_PRIMES:
        if n % p == 0:
            return n == p
    if n < MR_DETERMINISTIC_BOUND:
        return all(miller_rabin(n, p) for p in SMALL_PRIMES)
    if isqrt(n) ** 2 == n:
        return False
    return miller_rabin(n, 2) and strong_lucas(n)


# ---------------------------------------------------------------------------
# Polynomials over GF(2), as integers (bit k is the coefficient of x^k)
# ---------------------------------------------------------------------------

def poly_mulmod(a: int, b: int, mod: int, degree: int) -> int:
    result = 0
    while b:
        if b & 1:
            result ^= a
        b >>= 1
        a <<= 1
        if (a >> degree) & 1:
            a ^= mod
    return result


def poly_powmod_x(exponent: int, mod: int, degree: int) -> int:
    """x^exponent mod `mod` (degree >= 2)."""
    result, base = 1, 0b10
    while exponent:
        if exponent & 1:
            result = poly_mulmod(result, base, mod, degree)
        base = poly_mulmod(base, base, mod, degree)
        exponent >>= 1
    return result


def poly_gcd(a: int, b: int) -> int:
    while b:
        while a and a.bit_length() >= b.bit_length():
            a ^= b << (a.bit_length() - b.bit_length())
        a, b = b, a
    return a


def prime_divisors(n: int) -> list[int]:
    return [p for p in range(2, n + 1) if n % p == 0 and all(p % q for q in range(2, isqrt(p) + 1))]


def primitivity_error(poly: int, degree: int, order_primes: list[int]) -> str | None:
    """None if poly is primitive, otherwise the reason."""
    if poly_powmod_x(1 << degree, poly, degree) != 0b10:
        return "reducible (x^(2^N) != x mod P)"
    for q in prime_divisors(degree):
        if poly_gcd(poly_powmod_x(1 << (degree // q), poly, degree) ^ 0b10, poly) != 1:
            return f"reducible (P has a factor of degree dividing N/{q})"
    order = (1 << degree) - 1
    for r in order_primes:
        if poly_powmod_x(order // r, poly, degree) == 1:
            return f"irreducible but not primitive (order divides (2^N - 1)/{r})"
    return None


# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------

def read_taps(source: Path) -> dict[int, list[int]]:
    """Tap indices per width, from the f_lfsr if/elsif chain."""
    text = source.read_text(encoding="utf-8")
    match = re.search(r"function\s+f_lfsr\b(.*?)end\s+(?:function\s+)?f_lfsr\s*;", text, re.S | re.I)
    if match is None:
        raise CheckError(f"{source.name}: function f_lfsr not found")
    body = re.sub(r"--[^\n]*", "", match.group(1))
    taps: dict[int, list[int]] = {}
    pattern = r"'length\s*=\s*(\d+)\s*\)\s*then\s*\w+\s*:=\s*([^;]+);"
    for width_text, expr in re.findall(pattern, body, re.I):
        width = int(width_text)
        if width in taps:
            raise CheckError(f"{source.name}: width {width} defined twice in f_lfsr")
        taps[width] = [int(index) for index in re.findall(r"\w+\s*\(\s*(\d+)\s*\)", expr)]
    if not taps:
        raise CheckError(f"{source.name}: no tap set found in f_lfsr")
    return taps


def read_factors(path: Path) -> dict[int, dict[int, int]]:
    factors: dict[int, dict[int, int]] = {}
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        match = re.fullmatch(r"(\d+):((?:\s+\d+(?:\^\d+)?)+)", line)
        if match is None:
            raise CheckError(f"{path.name}:{number}: malformed line")
        width = int(match.group(1))
        entry: dict[int, int] = {}
        for item in match.group(2).split():
            prime, _, exponent = item.partition("^")
            entry[int(prime)] = int(exponent or 1)
        factors[width] = entry
    return factors


def check_factors(width: int, entry: dict[int, int]) -> str | None:
    product = 1
    for prime, exponent in entry.items():
        if not is_prime(prime):
            return f"factor {prime} of 2^{width} - 1 is not prime"
        product *= prime**exponent
    if product != (1 << width) - 1:
        return f"factors do not multiply to 2^{width} - 1"
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE, help="VHDL source with f_lfsr")
    parser.add_argument("--factors", type=Path, default=DEFAULT_FACTORS, help="factorization data file")
    parser.add_argument("-v", "--verbose", action="store_true", help="print every width")
    args = parser.parse_args()

    started = time.perf_counter()
    try:
        taps = read_taps(args.source)
        factors = read_factors(args.factors)
    except (CheckError, OSError) as exc:
        print(f"ERROR: {exc}")
        return 2

    errors: list[str] = []
    widths = range(WIDTH_MIN, WIDTH_MAX + 1)
    extra = sorted(set(taps) - set(widths))
    if extra:
        errors.append(f"f_lfsr defines widths outside {WIDTH_MIN}..{WIDTH_MAX}: {extra}")
    for width in widths:
        if width not in taps:
            errors.append(f"width {width}: no tap set in f_lfsr")
            continue
        if width not in factors:
            errors.append(f"width {width}: no factorization of 2^{width} - 1 in {args.factors.name}")
            continue
        factor_error = check_factors(width, factors[width])
        if factor_error:
            errors.append(f"width {width}: {factor_error}")
            continue
        indices = taps[width]
        if any(index >= width for index in indices) or len(set(indices)) != len(indices):
            errors.append(f"width {width}: invalid tap indices {indices}")
            continue
        poly = 1 << width
        for index in indices:
            poly ^= 1 << (width - 1 - index)
        reason = primitivity_error(poly, width, sorted(factors[width]))
        label = ", ".join(str(index) for index in indices)
        if reason:
            errors.append(f"width {width}: taps ({label}) are not a primitive polynomial: {reason}")
        elif args.verbose:
            print(f"width {width}: taps ({label}) primitive")

    seconds = time.perf_counter() - started
    for error in errors:
        print(f"FAIL {error}")
    checked = len(widths)
    if errors:
        print(f"{len(errors)} of {checked} widths failed ({seconds:.2f} s)")
        return 1
    print(f"all {checked} tap sets ({WIDTH_MIN}..{WIDTH_MAX}) are primitive polynomials ({seconds:.2f} s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
