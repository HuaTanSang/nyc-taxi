# NYC Taxi zone lookup

- Source: `https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv`
- Repository snapshot added: 2026-09-19
- Upstream version: not published; this snapshot is identified by its SHA-256
- SHA-256: `1a99e105092230f8620f301edcca7f80d3080642ff404d28ed957d3fa222c8ed`

The file is stored in the repository so local bootstrap is deterministic. Its
SHA-256 checksum is recorded in `taxi_zone_lookup.csv.sha256` and verified before
the object is uploaded to MinIO.

## Taxi zone representative points

- Source: `https://d37ci6vzurychx.cloudfront.net/misc/taxi_zones.zip`
- Source archive SHA-256: `f6d711917bb4340f8f644d5366c51665489eb2d426dd1a4a55677721ae5adf17`
- Repository snapshot: `taxi_zone_centroids.csv`
- Snapshot SHA-256: `74801379f5ef04d02374cb65acecd48fdf8d54514c8fe2835c3def253c46cb55`

The snapshot contains one WGS84 representative point per TLC `LocationID`.
Regenerate it with `scripts/generate_taxi_zone_centroids.py`; the runtime
pipeline reads only the committed CSV and does not require GIS dependencies.
