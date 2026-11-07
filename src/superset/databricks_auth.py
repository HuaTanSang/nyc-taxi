"""Attach the reader principal's refreshing OAuth provider to Databricks engines."""

import os
from functools import lru_cache
from urllib.parse import urlsplit

from databricks.sdk.core import Config, oauth_service_principal


@lru_cache(maxsize=1)
def credentials_provider():
    return oauth_service_principal(
        Config(
            host=os.environ["DATABRICKS_HOST"],
            client_id=os.environ["DATABRICKS_SUPERSET_CLIENT_ID"],
            client_secret=os.environ["DATABRICKS_SUPERSET_CLIENT_SECRET"],
            auth_type="oauth-m2m",
        )
    )


def configure_databricks(uri, params, username, security_manager, source):
    if uri.get_backend_name() != "databricks":
        return uri, params

    host = urlsplit(os.environ["DATABRICKS_HOST"])
    if host.scheme != "https" or uri.host != host.hostname:
        raise ValueError(
            "Databricks connection must use the configured HTTPS workspace"
        )

    connect_args = params.setdefault("connect_args", {})
    if uri.password or "access_token" in uri.query or "access_token" in connect_args:
        raise ValueError("Databricks uses OAuth M2M; remove static connection tokens")
    connect_args.pop("auth_type", None)
    connect_args["credentials_provider"] = credentials_provider
    return uri, params
