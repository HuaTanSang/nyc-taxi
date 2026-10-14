#!/usr/bin/env python3

import os
import shutil
from pathlib import Path
from urllib.parse import quote
from zipfile import ZIP_DEFLATED, ZipFile

from prepare_dashboard_export import (
    DATABASE_UUID,
    read_export_files,
    scalar,
    validate_and_sanitize,
    write_bundle,
)

TEMPLATE_ROOT = Path("/app/bootstrap/clickhouse")
RENDER_ROOT = Path("/tmp/nyc-taxi-superset")
BUNDLE_PATH = Path("/tmp/nyc-taxi-clickhouse.zip")
DATABASE_TEMPLATE = Path("databases/nyc_taxi_clickhouse.yaml")
URI_PLACEHOLDER = "__CLICKHOUSE_SQLALCHEMY_URI__"
DASHBOARD_SOURCE = Path("/app/bootstrap/dashboard/nyc_taxi_overview.zip")
DASHBOARD_RENDERED = Path("/tmp/nyc-taxi-dashboard.zip")


def required_environment(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Required environment variable is missing: {name}")
    return value


def clickhouse_uri() -> str:
    user = quote(required_environment("CLICKHOUSE_USER"), safe="")
    password = quote(required_environment("CLICKHOUSE_PASSWORD"), safe="")
    database = quote(required_environment("CLICKHOUSE_DB"), safe="")
    return f"clickhousedb://{user}:{password}@clickhouse:8123/{database}"


def render_bundle(sqlalchemy_uri: str) -> Path:
    shutil.rmtree(RENDER_ROOT, ignore_errors=True)
    shutil.copytree(TEMPLATE_ROOT, RENDER_ROOT)

    database_file = RENDER_ROOT / DATABASE_TEMPLATE
    template = database_file.read_text(encoding="utf-8")
    if template.count(URI_PLACEHOLDER) != 1:
        raise RuntimeError(
            "ClickHouse template must contain exactly one URI placeholder"
        )
    database_file.write_text(
        template.replace(URI_PLACEHOLDER, sqlalchemy_uri),
        encoding="utf-8",
    )

    BUNDLE_PATH.unlink(missing_ok=True)
    with ZipFile(BUNDLE_PATH, "w", ZIP_DEFLATED) as bundle:
        for path in sorted(RENDER_ROOT.rglob("*")):
            if path.is_file():
                bundle.write(path, path.relative_to(RENDER_ROOT.parent))
    return BUNDLE_PATH


def import_database(bundle_path: Path) -> None:
    from superset import security_manager
    from superset.commands.database.importers.dispatcher import ImportDatabasesCommand
    from superset.commands.importers.v1.utils import get_contents_from_bundle
    from superset.utils.core import override_user

    username = required_environment("SUPERSET_ADMIN_USERNAME")
    user = security_manager.find_user(username=username)
    if user is None:
        raise RuntimeError(f"Superset admin does not exist: {username}")

    with ZipFile(bundle_path) as bundle:
        contents = get_contents_from_bundle(bundle)

    with override_user(user=user):
        ImportDatabasesCommand(contents, overwrite=True).run()


def render_dashboard_bundle(sqlalchemy_uri: str) -> Path | None:
    if not DASHBOARD_SOURCE.exists():
        return None

    files = validate_and_sanitize(read_export_files(DASHBOARD_SOURCE))
    database_file = "databases/nyc_taxi_clickhouse.yaml"
    template = files[database_file]
    if scalar(template, "uuid") != DATABASE_UUID:
        raise RuntimeError(
            "Dashboard export references a different ClickHouse database"
        )
    files[database_file] = template.replace(URI_PLACEHOLDER, sqlalchemy_uri)
    write_bundle(files, DASHBOARD_RENDERED, replace=True)
    return DASHBOARD_RENDERED


def import_dashboard_assets(bundle_path: Path) -> None:
    from superset import security_manager
    from superset.commands.chart.importers.v1 import ImportChartsCommand
    from superset.commands.dashboard.importers.dispatcher import ImportDashboardsCommand
    from superset.commands.dataset.importers.v1 import ImportDatasetsCommand
    from superset.commands.importers.v1.utils import get_contents_from_bundle
    from superset.utils.core import override_user

    username = required_environment("SUPERSET_ADMIN_USERNAME")
    user = security_manager.find_user(username=username)
    if user is None:
        raise RuntimeError(f"Superset admin does not exist: {username}")

    with ZipFile(bundle_path) as bundle:
        contents = get_contents_from_bundle(bundle)

    def selected(*prefixes: str) -> dict[str, str]:
        # Superset 6 accepts version-only metadata for each asset type.
        return {
            "metadata.yaml": "version: 1.0.0\n",
            **{
                name: body
                for name, body in contents.items()
                if name.startswith(prefixes)
            },
        }

    with override_user(user=user):
        ImportDatasetsCommand(selected("databases/", "datasets/"), overwrite=True).run()
        ImportChartsCommand(
            selected("databases/", "datasets/", "charts/"), overwrite=True
        ).run()
        ImportDashboardsCommand(contents, overwrite=True).run()


def main() -> None:
    from superset.app import create_app

    app = create_app()
    with app.app_context():
        sqlalchemy_uri = clickhouse_uri()
        import_database(render_bundle(sqlalchemy_uri))
        dashboard_bundle = render_dashboard_bundle(sqlalchemy_uri)
        if dashboard_bundle is not None:
            import_dashboard_assets(dashboard_bundle)
            print("Imported Superset datasets, charts, and NYC Taxi dashboard")
        else:
            print(
                "No dashboard export committed yet; "
                "create and prepare it using the guide"
            )

    print("Imported Superset database: NYC Taxi ClickHouse")


if __name__ == "__main__":
    main()
