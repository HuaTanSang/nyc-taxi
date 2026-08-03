from common.constants import TLC_TRIP_DATA_BASE_URL


def _build_filename(taxi_type: str, year: int, month: int) -> str:
    return f"{taxi_type}_tripdata_{year}-{month:02d}.parquet"


def build_source_url(taxi_type: str, year: int, month: int) -> str:
    filename = _build_filename(taxi_type, year, month)
    return f"{TLC_TRIP_DATA_BASE_URL}/{filename}"
