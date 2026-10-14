#!/usr/bin/env python3
"""Validate and sanitize a Superset dashboard export before committing it."""

from __future__ import annotations

import argparse
import re
import stat
from pathlib import Path, PurePosixPath
from uuid import UUID
from zipfile import ZIP_DEFLATED, ZipFile

BOOTSTRAP_ROOT = Path(__file__).resolve().parent
DATABASE_TEMPLATE = BOOTSTRAP_ROOT / "clickhouse/databases/nyc_taxi_clickhouse.yaml"
DEFAULT_OUTPUT = BOOTSTRAP_ROOT / "dashboard/nyc_taxi_overview.zip"
BUNDLE_ROOT = "nyc-taxi-dashboard"
DATABASE_UUID = "b6585150-07d0-51e1-b45f-e8ca1c87af6e"
EXPECTED_DATASETS = {
    "mart_trip_daily",
    "mart_trip_hourly",
    "mart_pickup_zone_daily",
    "mart_data_quality_monthly",
}
MAX_FILE_SIZE = 2 * 1024 * 1024
MAX_BUNDLE_SIZE = 20 * 1024 * 1024
SECRET_KEY_PATTERN = re.compile(
    r"(?im)^\s*(?:password|secret(?:_key)?|access_key|api_key|token|"
    r"encrypted_extra|masked_encrypted_extra|ssh_tunnel)\s*:"
)
CREDENTIAL_URI_PATTERN = re.compile(r"://[^\s/@]+:[^\s/@]+@")


def scalar(document: str, key: str) -> str:
    match = re.search(rf"(?m)^{re.escape(key)}:\s*([^\n#]+)", document)
    if match is None:
        raise ValueError(f"Missing top-level {key} field in Superset export")
    return match.group(1).strip().strip("\"'")


def checked_uuid(value: str) -> str:
    try:
        return str(UUID(value))
    except ValueError as exc:
        raise ValueError(f"Invalid UUID in Superset export: {value}") from exc


def read_export_files(bundle_path: Path) -> dict[str, str]:
    """Read one-root, YAML-only Superset ZIP without extracting paths to disk."""
    files: dict[str, str] = {}
    roots: set[str] = set()
    total_size = 0

    with ZipFile(bundle_path) as bundle:
        for info in bundle.infolist():
            if info.is_dir():
                continue
            path = PurePosixPath(info.filename)
            if (
                path.is_absolute()
                or len(path.parts) < 2
                or any(part in ("", ".", "..") for part in path.parts)
                or stat.S_ISLNK(info.external_attr >> 16)
            ):
                raise ValueError(f"Unsafe ZIP path: {info.filename}")
            roots.add(path.parts[0])
            relative = PurePosixPath(*path.parts[1:]).as_posix()
            if relative in files:
                raise ValueError(f"Duplicate ZIP member: {relative}")
            if not (
                relative == "metadata.yaml"
                or relative == "tags.yaml"
                or relative.startswith(
                    ("databases/", "datasets/", "charts/", "dashboards/", "themes/")
                )
            ) or not relative.endswith((".yaml", ".yml")):
                raise ValueError(f"Unexpected Superset export member: {relative}")
            if info.file_size > MAX_FILE_SIZE:
                raise ValueError(f"Oversized Superset export member: {relative}")
            total_size += info.file_size
            if total_size > MAX_BUNDLE_SIZE:
                raise ValueError("Superset export exceeds the size limit")
            files[relative] = bundle.read(info).decode("utf-8")

    if len(roots) != 1:
        raise ValueError("Superset export must have exactly one root directory")
    return files


def validate_and_sanitize(files: dict[str, str]) -> dict[str, str]:
    metadata = files.get("metadata.yaml")
    if metadata is None or scalar(metadata, "version") != "1.0.0":
        raise ValueError("Expected a versioned Superset 6 dashboard export")
    if scalar(metadata, "type") != "Dashboard":
        raise ValueError("Use Export Dashboard, not an example or dataset export")

    groups = {
        prefix: [
            (path, body) for path, body in files.items() if path.startswith(prefix)
        ]
        for prefix in ("databases/", "datasets/", "charts/", "dashboards/")
    }
    if len(groups["databases/"]) != 1:
        raise ValueError("Dashboard export must include exactly one database")
    if checked_uuid(scalar(groups["databases/"][0][1], "uuid")) != DATABASE_UUID:
        raise ValueError(
            "Dashboard datasets must use the repo's NYC Taxi ClickHouse connection"
        )
    if len(groups["dashboards/"]) != 1 or not groups["charts/"]:
        raise ValueError("Export must contain one dashboard and at least one chart")

    dataset_names: set[str] = set()
    dataset_uuids: set[str] = set()
    for _, body in groups["datasets/"]:
        if checked_uuid(scalar(body, "database_uuid")) != DATABASE_UUID:
            raise ValueError("A dataset refers to a different database")
        if scalar(body, "schema") != "marts":
            raise ValueError("Dashboard datasets must come from the marts schema")
        dataset_names.add(scalar(body, "table_name"))
        dataset_uuids.add(checked_uuid(scalar(body, "uuid")))
    if dataset_names != EXPECTED_DATASETS or len(dataset_uuids) != len(
        EXPECTED_DATASETS
    ):
        raise ValueError(
            f"Expected exactly these four marts datasets: {sorted(EXPECTED_DATASETS)}"
        )

    seen_uuids = set(dataset_uuids)
    for _, body in groups["charts/"]:
        if checked_uuid(scalar(body, "dataset_uuid")) not in dataset_uuids:
            raise ValueError("A chart refers to a dataset outside the export")
        chart_uuid = checked_uuid(scalar(body, "uuid"))
        if chart_uuid in seen_uuids:
            raise ValueError("Duplicate asset UUID in dashboard export")
        seen_uuids.add(chart_uuid)
    dashboard_uuid = checked_uuid(scalar(groups["dashboards/"][0][1], "uuid"))
    if dashboard_uuid in seen_uuids:
        raise ValueError("Duplicate asset UUID in dashboard export")

    sanitized = {
        path: body for path, body in files.items() if not path.startswith("databases/")
    }
    for path, body in sanitized.items():
        if SECRET_KEY_PATTERN.search(body) or CREDENTIAL_URI_PATTERN.search(body):
            raise ValueError(
                f"Potential credential in {path}; review the export before committing"
            )

    template = DATABASE_TEMPLATE.read_text(encoding="utf-8")
    if checked_uuid(scalar(template, "uuid")) != DATABASE_UUID:
        raise ValueError("Committed ClickHouse database template UUID has changed")
    if template.count("__CLICKHOUSE_SQLALCHEMY_URI__") != 1:
        raise ValueError(
            "Committed ClickHouse database template is missing its URI placeholder"
        )
    sanitized["databases/nyc_taxi_clickhouse.yaml"] = template
    return sanitized


def write_bundle(
    files: dict[str, str], output_path: Path, *, replace: bool = False
) -> None:
    if output_path.exists() and not replace:
        raise FileExistsError(f"{output_path} exists; use --replace to update it")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = output_path.with_suffix(".zip.tmp")
    try:
        with ZipFile(temporary_path, "w", ZIP_DEFLATED) as bundle:
            for relative, body in sorted(files.items()):
                bundle.writestr(f"{BUNDLE_ROOT}/{relative}", body)
        temporary_path.replace(output_path)
    finally:
        temporary_path.unlink(missing_ok=True)


def prepare(input_path: Path, output_path: Path, *, replace: bool = False) -> None:
    sanitized = validate_and_sanitize(read_export_files(input_path))
    write_bundle(sanitized, output_path, replace=replace)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "export_zip", type=Path, help="ZIP downloaded using Export Dashboard"
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--replace", action="store_true", help="Replace an existing prepared bundle"
    )
    args = parser.parse_args()
    prepare(args.export_zip, args.output, replace=args.replace)
    print(f"Prepared credential-free dashboard bundle: {args.output}")


if __name__ == "__main__":
    main()
