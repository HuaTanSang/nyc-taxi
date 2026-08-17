import os
from urllib.parse import quote_plus

SECRET_KEY = os.environ["SUPERSET_SECRET_KEY"]

postgres_user = quote_plus(os.environ["POSTGRES_USER"])
postgres_password = quote_plus(os.environ["POSTGRES_PASSWORD"])
postgres_database = os.environ["POSTGRES_DB"]

SQLALCHEMY_DATABASE_URI = (
    f"postgresql+psycopg2://{postgres_user}:"
    f"{postgres_password}@superset-db:5432/{postgres_database}"
)

WTF_CSRF_ENABLED = True

ROW_LIMIT = 5000

SUPERSET_WEBSERVER_PORT = 8088

ENABLE_PROXY_FIX = False

SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"
