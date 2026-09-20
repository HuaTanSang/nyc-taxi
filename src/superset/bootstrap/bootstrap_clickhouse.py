#!/usr/bin/env python3

import os
import shutil
from pathlib import Path
from urllib.parse import quote
from zipfile import ZIP_DEFLATED, ZipFile

TEMPLATE_ROOT = Path("/app/bootstrap/clickhouse")
RENDER_ROOT = Path("/tmp/nyc-taxi-superset")
BUNDLE_PATH = Path("/tmp/nyc-taxi-clickhouse.zip")
DATABASE_TEMPLATE = Path("databases/nyc_taxi_clickhouse.yaml")
URI_PLACEHOLDER = "__CLICKHOUSE_SQLALCHEMY_URI__"


def required_environment(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Required environment variable is missing: {name}")
    return value


def render_bundle() -> Path:
    user = quote(required_environment("CLICKHOUSE_USER"), safe="")
    password = quote(required_environment("CLICKHOUSE_PASSWORD"), safe="")
    database = quote(required_environment("CLICKHOUSE_DB"), safe="")
    sqlalchemy_uri = f"clickhousedb://{user}:{password}@clickhouse:8123/{database}"

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
    from superset.commands.database.importers.dispatcher import (
        ImportDatabasesCommand,
    )
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


def main() -> None:
    from superset.app import create_app

    app = create_app()
    with app.app_context():
        import_database(render_bundle())

    print("Imported Superset database: NYC Taxi ClickHouse")


if __name__ == "__main__":
    main()
