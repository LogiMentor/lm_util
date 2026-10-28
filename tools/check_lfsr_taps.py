# SPDX-License-Identifier: Apache-2.0

"""Check that every lm_util_lfsr tap set is a primitive polynomial over GF(2).

The taps are read from f_lfsr in src/lm_util_lfsr.vhd. f_lfsr_next shifts the
state towards the MSB and puts the XOR of the taps into bit 0, so bit i of the
register (i = 0 .. N-1) holds the feedback bit computed i + 1 clock cycles
earlier, and a tap set T gives the characteristic polynomial

    P(x) = x^N + sum(x^(N-1-i) for i in T)

and the register runs through all 2^N - 1 nonzero states if and only if P is
primitive: irreducible (Rabin test) and of order 2^N - 1, i.e.
x^((2^N - 1) / r) != 1 mod P for every prime r dividing 2^N - 1.

That convention holds only for the exact form of f_lfsr and f_lfsr_next, so
the script accepts only that form (comments, spacing and case aside): the
if/elsif chain over widths 3 .. 168 in order, each branch a single XOR of
v_rand bits, and the shift in f_lfsr_next as listed in F_LFSR_NEXT. Any other
expression, operator, vector name or structure is an error, not something to
interpret.

The prime factors of 2^N - 1 come from tools/check_lfsr_taps_factors.txt.
That file is checked too: the product of the factors must be 2^N - 1 and
every factor must be prime, each width and each prime appears once, and
exponents are at least 1. Primality uses a deterministic Miller-Rabin test
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

# Expected form of f_lfsr around the tap chain, and of f_lfsr_next, compared
# after vhdl_tokens()
F_LFSR_HEAD = (
    "function f_lfsr(random : std_logic_vector) return std_logic is",
    "alias v_rand : std_logic_vector(random'length - 1 downto 0) is random;",
    "variable v_xor_out : std_logic;",
    "begin",
    "v_xor_out := '0';",
)
F_LFSR_TAIL = (
    "end if;",
    "return v_xor_out;",
    "end f_lfsr;",
)
F_LFSR_NEXT = (
    "function f_lfsr_next(state : std_logic_vector) return std_logic_vector is",
    "alias v_state : std_logic_vector(state'length - 1 downto 0) is state;",
    "begin",
    "return v_state(v_state'high - 1 downto 0) & f_lfsr(v_state);",
    "end f_lfsr_next;",
)
# the only use of f_lfsr_next: the register update
NEXT_STATE = "s_state <= f_lfsr_next(s_state);"
BRANCH_RE = re.compile(r"(if|elsif) \( v_rand'length = (\d+) \) then")
ASSIGN_RE = re.compile(r"v_xor_out := v_rand \( \d+ \)(?: xor v_rand \( \d+ \))* ;")


def vhdl_tokens(line: str) -> str:
    """Code of one line without comment, in lower case, tokens joined by single spaces."""
    code = line.split("--", 1)[0].lower()
    return " ".join(re.findall(r"'.'|:=|<=|[a-z_]\w*(?:'[a-z_]\w*)?|\d+|\S", code))


def read_taps(source: Path) -> dict[int, list[int]]:
    """Tap indices per width, from the f_lfsr if/elsif chain."""
    name = source.name
    lines = source.read_text(encoding="utf-8").splitlines()
    tokenized = ((number, vhdl_tokens(line)) for number, line in enumerate(lines, start=1))
    code = [(number, tokens) for number, tokens in tokenized if tokens]

    def shown(number: int) -> str:
        """Source line `number` as written, without comment."""
        return lines[number - 1].split("--", 1)[0].strip()

    def find(start: str) -> int:
        """Index in code of the single line that starts with `start`."""
        hits = [k for k, (_, tokens) in enumerate(code) if tokens.startswith(vhdl_tokens(start))]
        if len(hits) != 1:
            raise CheckError(f"{name}: expected one line starting '{start}', found {len(hits)}")
        return hits[0]

    def line_at(index: int) -> tuple[int, str]:
        if index >= len(code):
            raise CheckError(f"{name}: unexpected end of file")
        return code[index]

    def expect(index: int, expected: tuple[str, ...]) -> None:
        for offset, text in enumerate(expected):
            number, tokens = line_at(index + offset)
            if tokens != vhdl_tokens(text):
                raise CheckError(f"{name}:{number}: expected '{text}', found '{shown(number)}'")

    # f_lfsr_next: shift towards the MSB, f_lfsr into bit 0, used once
    expect(find("function f_lfsr_next("), F_LFSR_NEXT)
    uses = [number for number, tokens in code if tokens == vhdl_tokens(NEXT_STATE)]
    if len(uses) != 1:
        raise CheckError(f"{name}: expected one '{NEXT_STATE}', found {len(uses)}")
    for function in ("f_lfsr", "f_lfsr_next"):
        # declaration, end and the single call
        found = sum(tokens.split().count(function) for _, tokens in code)
        if found != 3:
            raise CheckError(f"{name}: {function} appears {found} times, expected 3")

    # f_lfsr: fixed head, one branch per width in order, fixed tail
    index = find("function f_lfsr(")
    expect(index, F_LFSR_HEAD)
    index += len(F_LFSR_HEAD)
    taps: dict[int, list[int]] = {}
    for width in range(WIDTH_MIN, WIDTH_MAX + 1):
        keyword = "if" if width == WIDTH_MIN else "elsif"
        number, tokens = line_at(index)
        branch = BRANCH_RE.fullmatch(tokens)
        if branch is None or branch.group(1) != keyword or int(branch.group(2)) != width:
            raise CheckError(f"{name}:{number}: width {width}: expected '{keyword}(v_rand'length = {width}) then' "
                             f"(widths {WIDTH_MIN}..{WIDTH_MAX} in order), found '{shown(number)}'")
        number, tokens = line_at(index + 1)
        if ASSIGN_RE.fullmatch(tokens) is None:
            raise CheckError(f"{name}:{number}: width {width}: expected "
                             f"'v_xor_out := v_rand(i) xor v_rand(j) ...;', found '{shown(number)}'")
        indices = [int(text) for text in re.findall(r"\d+", tokens)]
        if len(set(indices)) != len(indices):
            raise CheckError(f"{name}:{number}: width {width}: repeated tap index in {indices}")
        if max(indices) >= width:
            raise CheckError(f"{name}:{number}: width {width}: tap index above {width - 1} in {indices}")
        taps[width] = indices
        index += 2
    expect(index, F_LFSR_TAIL)
    return taps


def read_factors(path: Path) -> dict[int, dict[int, int]]:
    factors: dict[int, dict[int, int]] = {}
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        match = re.fullmatch(r"(\d+):((?:\s+\d+(?:\^-?\d+)?)+)", line)
        if match is None:
            raise CheckError(f"{path.name}:{number}: malformed line")
        width = int(match.group(1))
        if width in factors:
            raise CheckError(f"{path.name}:{number}: width {width} listed twice")
        entry: dict[int, int] = {}
        for item in match.group(2).split():
            prime, _, exponent = item.partition("^")
            if int(prime) in entry:
                raise CheckError(f"{path.name}:{number}: width {width}: factor {prime} listed twice "
                                 f"(write it once as {prime}^<exponent>)")
            if int(exponent or 1) < 1:
                raise CheckError(f"{path.name}:{number}: width {width}: exponent {exponent} of {prime}, "
                                 f"must be at least 1")
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
    for width in widths:
        if width not in factors:
            errors.append(f"width {width}: no factorization of 2^{width} - 1 in {args.factors.name}")
            continue
        factor_error = check_factors(width, factors[width])
        if factor_error:
            errors.append(f"width {width}: {factor_error}")
            continue
        indices = taps[width]
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
