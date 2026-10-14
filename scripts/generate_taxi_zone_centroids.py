#!/usr/bin/env python3
"""Generate a deterministic WGS84 point for every official TLC taxi zone.

Run with:
    uv run --no-project --with pyshp scripts/generate_taxi_zone_centroids.py \
        --output /tmp/taxi_zone_centroids.csv
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import math
import tempfile
import urllib.request
import zipfile
from pathlib import Path

import shapefile

SOURCE_URL = "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zones.zip"
SOURCE_SHA256 = "f6d711917bb4340f8f644d5366c51665489eb2d426dd1a4a55677721ae5adf17"

# EPSG:2263, NAD83 / New York Long Island (ftUS).
SEMI_MAJOR_AXIS = 6_378_137.0
INVERSE_FLATTENING = 298.257222101
FALSE_EASTING_METERS = 300_000.0
FALSE_NORTHING_METERS = 0.0
CENTRAL_MERIDIAN = math.radians(-74.0)
LATITUDE_OF_ORIGIN = math.radians(40.1666666666667)
STANDARD_PARALLEL_1 = math.radians(40.6666666666667)
STANDARD_PARALLEL_2 = math.radians(41.0333333333333)
US_SURVEY_FOOT_TO_METERS = 1200.0 / 3937.0


def _ring_area(points: list[tuple[float, float]]) -> float:
    return 0.5 * sum(
        x1 * y2 - x2 * y1
        for (x1, y1), (x2, y2) in zip(points, points[1:] + points[:1], strict=True)
    )


def _point_in_ring(point: tuple[float, float], ring: list[tuple[float, float]]) -> bool:
    x, y = point
    inside = False
    previous_x, previous_y = ring[-1]
    for current_x, current_y in ring:
        crosses = (current_y > y) != (previous_y > y)
        if crosses:
            intersection_x = (previous_x - current_x) * (y - current_y) / (
                previous_y - current_y
            ) + current_x
            if x < intersection_x:
                inside = not inside
        previous_x, previous_y = current_x, current_y
    return inside


def _polygon_centroid(ring: list[tuple[float, float]]) -> tuple[float, float]:
    cross_products = [
        x1 * y2 - x2 * y1
        for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1], strict=True)
    ]
    area_factor = sum(cross_products)
    if abs(area_factor) < 1e-12:
        xs, ys = zip(*ring, strict=True)
        return sum(xs) / len(xs), sum(ys) / len(ys)
    centroid_x = sum(
        (x1 + x2) * cross
        for ((x1, _), (x2, _)), cross in zip(
            zip(ring, ring[1:] + ring[:1], strict=True),
            cross_products,
            strict=True,
        )
    ) / (3.0 * area_factor)
    centroid_y = sum(
        (y1 + y2) * cross
        for ((_, y1), (_, y2)), cross in zip(
            zip(ring, ring[1:] + ring[:1], strict=True),
            cross_products,
            strict=True,
        )
    ) / (3.0 * area_factor)
    return centroid_x, centroid_y


def _representative_point(shape: shapefile.Shape) -> tuple[float, float]:
    boundaries = list(shape.parts) + [len(shape.points)]
    rings = [
        [(float(x), float(y)) for x, y in shape.points[start:end]]
        for start, end in zip(boundaries, boundaries[1:], strict=True)
        if end - start >= 3
    ]
    ring = max(rings, key=lambda candidate: abs(_ring_area(candidate)))
    centroid = _polygon_centroid(ring)
    if _point_in_ring(centroid, ring):
        return centroid

    min_x = min(point[0] for point in ring)
    max_x = max(point[0] for point in ring)
    min_y = min(point[1] for point in ring)
    max_y = max(point[1] for point in ring)
    target_y = centroid[1]
    for offset_fraction in (0.0, 0.1, -0.1, 0.2, -0.2, 0.3, -0.3):
        y = min(max(target_y + offset_fraction * (max_y - min_y), min_y), max_y)
        intersections: list[float] = []
        previous_x, previous_y = ring[-1]
        for current_x, current_y in ring:
            if (current_y > y) != (previous_y > y):
                intersections.append(
                    current_x
                    + (y - current_y)
                    * (previous_x - current_x)
                    / (previous_y - current_y)
                )
            previous_x, previous_y = current_x, current_y
        intersections.sort()
        segments = list(zip(intersections[::2], intersections[1::2], strict=True))
        if segments:
            left, right = max(segments, key=lambda segment: segment[1] - segment[0])
            candidate = ((left + right) / 2.0, y)
            if _point_in_ring(candidate, ring):
                return candidate
    return (min_x + max_x) / 2.0, (min_y + max_y) / 2.0


def _m(phi: float, eccentricity_squared: float) -> float:
    return math.cos(phi) / math.sqrt(1.0 - eccentricity_squared * math.sin(phi) ** 2)


def _t(phi: float, eccentricity: float) -> float:
    eccentric_sine = eccentricity * math.sin(phi)
    return math.tan(math.pi / 4.0 - phi / 2.0) / (
        (1.0 - eccentric_sine) / (1.0 + eccentric_sine)
    ) ** (eccentricity / 2.0)


def _epsg2263_to_wgs84(x_feet: float, y_feet: float) -> tuple[float, float]:
    flattening = 1.0 / INVERSE_FLATTENING
    eccentricity_squared = 2.0 * flattening - flattening**2
    eccentricity = math.sqrt(eccentricity_squared)
    m1 = _m(STANDARD_PARALLEL_1, eccentricity_squared)
    m2 = _m(STANDARD_PARALLEL_2, eccentricity_squared)
    t1 = _t(STANDARD_PARALLEL_1, eccentricity)
    t2 = _t(STANDARD_PARALLEL_2, eccentricity)
    t0 = _t(LATITUDE_OF_ORIGIN, eccentricity)
    n = (math.log(m1) - math.log(m2)) / (math.log(t1) - math.log(t2))
    factor = m1 / (n * t1**n)
    rho0 = SEMI_MAJOR_AXIS * factor * t0**n

    x = x_feet * US_SURVEY_FOOT_TO_METERS - FALSE_EASTING_METERS
    y = y_feet * US_SURVEY_FOOT_TO_METERS - FALSE_NORTHING_METERS
    rho = math.copysign(math.hypot(x, rho0 - y), n)
    theta = math.atan2(x, rho0 - y)
    target_t = (rho / (SEMI_MAJOR_AXIS * factor)) ** (1.0 / n)
    latitude = math.pi / 2.0 - 2.0 * math.atan(target_t)
    for _ in range(10):
        eccentric_sine = eccentricity * math.sin(latitude)
        next_latitude = math.pi / 2.0 - 2.0 * math.atan(
            target_t
            * ((1.0 - eccentric_sine) / (1.0 + eccentric_sine)) ** (eccentricity / 2.0)
        )
        if abs(next_latitude - latitude) < 1e-13:
            latitude = next_latitude
            break
        latitude = next_latitude
    longitude = CENTRAL_MERIDIAN + theta / n
    return math.degrees(latitude), math.degrees(longitude)


def generate(output_path: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="nyc-taxi-zones-") as temporary_dir:
        archive_path = Path(temporary_dir) / "taxi_zones.zip"
        urllib.request.urlretrieve(SOURCE_URL, archive_path)
        actual_checksum = hashlib.sha256(archive_path.read_bytes()).hexdigest()
        if actual_checksum != SOURCE_SHA256:
            raise RuntimeError(
                "Official taxi-zone archive changed; review it before updating "
                f"the snapshot. Expected {SOURCE_SHA256}, got {actual_checksum}."
            )
        with zipfile.ZipFile(archive_path) as archive:
            archive.extractall(temporary_dir)
        reader = shapefile.Reader(str(Path(temporary_dir) / "taxi_zones/taxi_zones"))
        field_names = [field[0] for field in reader.fields[1:]]
        location_index = field_names.index("LocationID")
        rows = []
        for shape_record in reader.iterShapeRecords():
            location_id = int(shape_record.record[location_index])
            x, y = _representative_point(shape_record.shape)
            latitude, longitude = _epsg2263_to_wgs84(x, y)
            rows.append((location_id, latitude, longitude))

    rows.sort(key=lambda row: row[0])
    expected_location_ids = set(range(1, 264))
    actual_location_ids = {row[0] for row in rows}
    if actual_location_ids != expected_location_ids:
        raise RuntimeError("Expected official shapefile LocationIDs 1 through 263.")
    if any(not 40.0 <= row[1] <= 42.0 or not -75.0 <= row[2] <= -72.0 for row in rows):
        raise RuntimeError(
            "Generated representative point falls outside the NYC region."
        )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as output_file:
        writer = csv.writer(output_file, lineterminator="\n")
        writer.writerow(["LocationID", "latitude", "longitude"])
        for location_id, latitude, longitude in rows:
            writer.writerow([location_id, f"{latitude:.6f}", f"{longitude:.6f}"])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    generate(args.output)


if __name__ == "__main__":
    main()
