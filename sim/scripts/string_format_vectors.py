# SPDX-License-Identifier: Apache-2.0

"""Reference vectors for lm_util_pkg.f_string_format.

The expected string is the exact binary value of the 64-bit real, rounded
to the precision with ties away from zero (decimal.ROUND_HALF_UP on the
exact Decimal of the float). Each value is written as sign, 53-bit integer
mantissa (split in two parts that fit a VHDL integer) and binary exponent,
so the testbench rebuilds the same real exactly, without parsing a decimal
literal.

Usage: python string_format_vectors.py <output file> [--count N] [--seed S]
"""

from __future__ import annotations

import argparse
import math
import random
from decimal import ROUND_HALF_UP, Decimal, localcontext
from pathlib import Path

INT_MAX = 2**31 - 1
PREC_MAX = 9

# reviewed cases: near-half literals, exact ties, carries that add a digit,
# integer limits and tiny values
FIXED = [
    (9.9995, 3), (-9.9995, 3), (0.9995, 3), (9.9999, 2), (0.99996, 4),
    (0.125, 2), (-0.125, 2), (9.5, 0), (2.5, 0), (-2.5, 0), (0.5, 0),
    (1.5, 0), (9.96875, 1), (-9.96875, 1), (999.9996, 3), (0.96, 1),
    (0.0, 0), (0.0, 3), (0.0, 9), (0.05, 3), (1e-12, 9), (-1e-12, 3),
    (2147483647.0, 0), (2147483647.0, 3), (2147483647.4, 3),
    (2147483647.25, 2), (-2147483647.25, 2), (2147483646.9996, 3),
    (2147483646.5, 0), (3000000.0, 3), (1000000.5, 6), (123456789.125, 3),
    (0.000000001, 9), (0.0000000005, 9), (0.0000000015, 9),
    # the real is below the decimal half, the rounded product lands on it
    (0.0065, 3), (0.35, 1), (-0.015, 2), (1.5e-09, 9), (-1.5385, 3),
]


def expected(value: float, precision: int) -> str:
    with localcontext() as ctx:
        ctx.prec = 200
        quantum = Decimal(1).scaleb(-precision)
        return format(Decimal(value).quantize(quantum, rounding=ROUND_HALF_UP), "f")


def representable(value: float, precision: int) -> bool:
    """Accepted by f_string_format: rounded integer part fits an integer."""
    if value != value or math.isinf(value) or (value == 0.0 and math.copysign(1.0, value) < 0.0):
        return False
    text = expected(value, precision).lstrip("-")
    return int(text.split(".")[0]) <= INT_MAX and 0 <= precision <= PREC_MAX


def encode(value: float) -> tuple[int, int, int, int]:
    """(sign, high, low, exponent) with |value| = (high * 2**26 + low) * 2**exponent."""
    sign = 1 if value < 0.0 else 0
    mantissa, exponent = math.frexp(abs(value))
    integer = int(mantissa * 2**53)
    exponent -= 53
    if integer == 0:
        exponent = 0
    return sign, integer >> 26, integer & (2**26 - 1), exponent


def random_value(rng: random.Random) -> float:
    return rng.choice((-1.0, 1.0)) * 10.0 ** rng.uniform(-10.0, math.log10(INT_MAX))


def near_half(rng: random.Random, precision: int) -> list[float]:
    """The double nearest to a decimal half at the precision, and its neighbours."""
    whole = int(10 ** rng.uniform(0.0, math.log10(INT_MAX * 10**precision)))
    center = (whole * 10 + 5) / 10 ** (precision + 1)
    up = down = center
    result = [center]
    for _ in range(3):
        up = math.nextafter(up, math.inf)
        down = math.nextafter(down, -math.inf)
        result += [up, down]
    sign = rng.choice((-1.0, 1.0))
    return [sign * value for value in result]


def exact_tie(rng: random.Random, precision: int) -> float:
    """odd / 2**(precision + 1) is exactly half a unit of the last digit."""
    limit = min(2**52, (INT_MAX + 1) * 2 ** (precision + 1))
    odd = rng.randrange(1, limit, 2)
    return rng.choice((-1.0, 1.0)) * odd / 2 ** (precision + 1)


def carry(rng: random.Random, precision: int) -> float:
    """Just below a power of ten: rounding up adds an integer digit."""
    power = 10 ** rng.randint(0, 9)
    step = 10.0**-precision
    return rng.choice((-1.0, 1.0)) * (power - step * rng.uniform(0.01, 0.6))


def generate(count: int, seed: int) -> list[tuple[float, int]]:
    rng = random.Random(seed)
    vectors = list(FIXED)
    while len(vectors) < count:
        precision = rng.randint(0, PREC_MAX)
        kind = rng.random()
        if kind < 0.35:
            candidates = near_half(rng, precision)
        elif kind < 0.50:
            candidates = [exact_tie(rng, precision)]
        elif kind < 0.60:
            candidates = [carry(rng, precision)]
        else:
            candidates = [random_value(rng)]
        vectors += [(value, precision) for value in candidates if representable(value, precision)]
    return vectors[:count]


def write(path: Path, count: int, seed: int) -> int:
    vectors = generate(count, seed)
    lines = []
    for value, precision in vectors:
        sign, high, low, exponent = encode(value)
        text = expected(value, precision)
        literal = repr(value)
        lines.append(f"{sign} {high} {low} {exponent} {precision} {len(text)} {text} {literal}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="ascii")
    return len(vectors)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("output", type=Path)
    parser.add_argument("--count", type=int, default=1500)
    parser.add_argument("--seed", type=int, default=20261018)
    args = parser.parse_args()
    print(f"{write(args.output, args.count, args.seed)} vectors written to {args.output}")


if __name__ == "__main__":
    main()
