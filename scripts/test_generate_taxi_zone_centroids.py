"""Offline regression checks for taxi-zone representative points."""

from __future__ import annotations

import unittest

import shapefile
from generate_taxi_zone_centroids import _representative_point


class RepresentativePointTest(unittest.TestCase):
    def test_point_in_largest_ring(self) -> None:
        small = [(0, 0), (1, 0), (1, 1), (0, 1), (0, 0)]
        large = [(2, 2), (4, 2), (4, 4), (2, 4), (2, 2)]
        for parts, points, expected in [
            ([0], small, (0.5, 0.5)),
            ([0, len(small)], small + large, (3.0, 3.0)),
        ]:
            with self.subTest(parts=parts):
                shape = shapefile.Shape(shapefile.POLYGON, points=points, parts=parts)
                self.assertEqual(_representative_point(shape), expected)


if __name__ == "__main__":
    unittest.main()
