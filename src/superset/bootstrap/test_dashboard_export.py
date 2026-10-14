"""Local tests for the portable Superset dashboard bundle."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from zipfile import ZIP_DEFLATED, ZipFile

import bootstrap_clickhouse
from prepare_dashboard_export import (
    DATABASE_UUID,
    EXPECTED_DATASETS,
    prepare,
    read_export_files,
)


class DashboardExportTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.input_path = self.root / "source.zip"
        self.output_path = self.root / "prepared.zip"

    def source_files(self) -> dict[str, str]:
        files = {
            "metadata.yaml": "version: 1.0.0\ntype: Dashboard\n",
            "databases/source.yaml": (
                "database_name: NYC Taxi ClickHouse\n"
                f"uuid: {DATABASE_UUID}\n"
                "sqlalchemy_uri: 'clickhousedb://alice:secret@clickhouse:8123/taxi'\n"
            ),
            "charts/trips.yaml": (
                "uuid: 96221850-1472-45ba-9530-36dd2889acec\n"
                "dataset_uuid: 45bcb364-8348-4b94-8378-d450386b5910\n"
            ),
            "dashboards/overview.yaml": (
                "uuid: 0454336a-b39b-484a-a97d-58db807301db\n"
                "dashboard_title: NYC Taxi | Mobility Insights\n"
            ),
        }
        for index, name in enumerate(sorted(EXPECTED_DATASETS)):
            uuid = (
                "45bcb364-8348-4b94-8378-d450386b5910"
                if index == 0
                else f"45bcb364-8348-4b94-8378-d450386b591{index}"
            )
            files[f"datasets/{name}.yaml"] = (
                f"uuid: {uuid}\n"
                f"database_uuid: {DATABASE_UUID}\n"
                "schema: marts\n"
                f"table_name: {name}\n"
            )
        return files

    def write_source(self, files: dict[str, str]) -> None:
        with ZipFile(self.input_path, "w", ZIP_DEFLATED) as bundle:
            for name, body in files.items():
                bundle.writestr(f"dashboard_export/{name}", body)

    def test_prepare_removes_exported_database_credentials(self) -> None:
        self.write_source(self.source_files())
        prepare(self.input_path, self.output_path)

        files = read_export_files(self.output_path)
        self.assertEqual(len(files), 8)
        self.assertIn(
            "__CLICKHOUSE_SQLALCHEMY_URI__",
            files["databases/nyc_taxi_clickhouse.yaml"],
        )
        self.assertNotIn("alice:secret", "\n".join(files.values()))

    def test_rejects_wrong_database_uuid(self) -> None:
        files = self.source_files()
        files["databases/source.yaml"] = files["databases/source.yaml"].replace(
            DATABASE_UUID, "11111111-1111-4111-8111-111111111111"
        )
        self.write_source(files)
        with self.assertRaisesRegex(ValueError, "ClickHouse connection"):
            prepare(self.input_path, self.output_path)
        self.assertFalse(self.output_path.exists())

    def test_rejects_credentials_outside_database_config(self) -> None:
        files = self.source_files()
        files["charts/trips.yaml"] += "token: leaked-value\n"
        self.write_source(files)
        with self.assertRaisesRegex(ValueError, "Potential credential"):
            prepare(self.input_path, self.output_path)

    def test_rejects_path_traversal(self) -> None:
        files = self.source_files()
        files["../outside.yaml"] = "value: unsafe\n"
        self.write_source(files)
        with self.assertRaisesRegex(ValueError, "Unsafe ZIP path"):
            prepare(self.input_path, self.output_path)

    def test_bootstrap_renders_local_uri_into_prepared_bundle(self) -> None:
        self.write_source(self.source_files())
        prepare(self.input_path, self.output_path)
        rendered_path = self.root / "rendered.zip"
        uri = "clickhousedb://local:password@clickhouse:8123/taxi"

        with (
            patch.object(bootstrap_clickhouse, "DASHBOARD_SOURCE", self.output_path),
            patch.object(bootstrap_clickhouse, "DASHBOARD_RENDERED", rendered_path),
        ):
            self.assertEqual(
                bootstrap_clickhouse.render_dashboard_bundle(uri), rendered_path
            )

        files = read_export_files(rendered_path)
        self.assertIn(uri, files["databases/nyc_taxi_clickhouse.yaml"])
        self.assertNotIn(
            "__CLICKHOUSE_SQLALCHEMY_URI__", files["databases/nyc_taxi_clickhouse.yaml"]
        )


if __name__ == "__main__":
    unittest.main()
