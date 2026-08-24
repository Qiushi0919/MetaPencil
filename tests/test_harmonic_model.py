#!/usr/bin/env python3
"""Small dependency-free checks for the documented ideal harmonic model."""

from __future__ import annotations

import cmath
import math
import unittest


STATES = tuple(cmath.exp(1j * k * math.pi / 2) for k in range(4))
EDGES = tuple(k * math.pi / 2 for k in range(5))
DELAYS = (0.0, 0.1, 5.0 / 6.0, 14.0 / 15.0)


def stepped_coefficient(order: int) -> complex:
    if order == 0:
        return sum(STATES) / len(STATES)
    coefficient = 0j
    for state, left, right in zip(STATES, EDGES[:-1], EDGES[1:]):
        integral = (
            cmath.exp(-1j * order * right)
            - cmath.exp(-1j * order * left)
        ) / (-1j * order)
        coefficient += state * integral / (2 * math.pi)
    return coefficient


def partition_factor(order: int) -> complex:
    return sum(cmath.exp(-1j * 2 * math.pi * order * d) for d in DELAYS) / len(DELAYS)


class HarmonicModelTest(unittest.TestCase):
    def test_balanced_2bit_plus_one(self) -> None:
        self.assertAlmostEqual(abs(stepped_coefficient(1)), 2 * math.sqrt(2) / math.pi, places=12)

    def test_four_delay_nulls(self) -> None:
        self.assertLess(abs(partition_factor(-3)), 1e-12)
        self.assertLess(abs(partition_factor(5)), 1e-12)

    def test_retained_plus_one_and_2d_amplitude(self) -> None:
        c1 = abs(stepped_coefficient(1))
        s1 = abs(partition_factor(1))
        self.assertAlmostEqual(s1, 0.823639103546332, places=12)
        self.assertAlmostEqual((c1 * s1) ** 2, 0.549875229298, places=12)

    def test_balanced_two_channel_area(self) -> None:
        tile_map = (
            (1, 2, 1, 2),
            (2, 1, 2, 1),
            (1, 2, 1, 2),
            (2, 1, 2, 1),
        )
        flat = sum(tile_map, ())
        self.assertEqual(flat.count(1), 8)
        self.assertEqual(flat.count(2), 8)


if __name__ == "__main__":
    unittest.main()

