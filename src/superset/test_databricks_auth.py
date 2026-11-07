"""Run inside the Superset image without credentials or network access."""

import os
import runpy
import unittest
from pathlib import Path
from unittest.mock import patch

import databricks_auth
from sqlalchemy.engine import make_url


class DatabricksAuthTest(unittest.TestCase):
    def setUp(self):
        env = {
            "DATABRICKS_HOST": "https://workspace.invalid",
            "DATABRICKS_SUPERSET_CLIENT_ID": "reader",
            "DATABRICKS_SUPERSET_CLIENT_SECRET": "test-secret",
        }
        self.env = patch.dict(os.environ, env)
        self.env.start()
        self.addCleanup(self.env.stop)
        databricks_auth.credentials_provider.cache_clear()
        self.addCleanup(databricks_auth.credentials_provider.cache_clear)

    def configure(self, url, params=None):
        return databricks_auth.configure_databricks(
            make_url(url), {} if params is None else params, None, None, None
        )

    def test_other_databases_are_unchanged(self):
        params = {"connect_args": {"test": True}}
        uri, result = self.configure("postgresql://localhost/test", params)
        self.assertEqual(uri.get_backend_name(), "postgresql")
        self.assertIs(result, params)
        self.assertEqual(result, {"connect_args": {"test": True}})

    def test_rejects_other_workspace_and_static_tokens(self):
        for uri, params in [
            ("databricks://other.invalid", {}),
            ("databricks://token:secret@workspace.invalid", {}),
            ("databricks://workspace.invalid?access_token=secret", {}),
            ("databricks://workspace.invalid", {"connect_args": {"access_token": "x"}}),
        ]:
            with self.subTest(uri=uri), self.assertRaises(ValueError):
                self.configure(uri, params)

    def test_oauth_is_lazy_and_uses_reader_credentials(self):
        with (
            patch.object(databricks_auth, "Config") as config,
            patch.object(databricks_auth, "oauth_service_principal") as oauth,
        ):
            _, params = self.configure("databricks://workspace.invalid")
            oauth.assert_not_called()
            provider = params["connect_args"]["credentials_provider"]
            self.assertIs(provider(), oauth.return_value)
            self.assertIs(provider(), oauth.return_value)
            oauth.assert_called_once_with(config.return_value)
            config.assert_called_once_with(
                host="https://workspace.invalid",
                client_id="reader",
                client_secret="test-secret",
                auth_type="oauth-m2m",
            )

    def test_superset_and_dialect_imports(self):
        from sqlalchemy.dialects import registry
        from superset.app import create_app

        self.assertTrue(callable(create_app))
        self.assertEqual(registry.load("databricks").name, "databricks")

    def test_image_configuration_loads_hook_and_postgres_driver(self):
        import psycopg2

        self.assertTrue(callable(psycopg2.connect))
        with patch.dict(
            os.environ,
            {
                "SUPERSET_SECRET_KEY": "test-only",
                "SUPERSET_POSTGRES_USER": "superset",
                "SUPERSET_POSTGRES_PASSWORD": "password/@",
                "SUPERSET_POSTGRES_DB": "superset",
            },
        ):
            config = runpy.run_path(
                str(Path(databricks_auth.__file__).with_name("superset_config.py"))
            )
        self.assertIs(
            config["DB_CONNECTION_MUTATOR"], databricks_auth.configure_databricks
        )
        self.assertEqual(
            make_url(config["SQLALCHEMY_DATABASE_URI"]).password, "password/@"
        )


if __name__ == "__main__":
    unittest.main()
