{{
    table_configuration(
        materialized='view',
        schema='raw',
        alias='ext_zone_centroids',
        tags=['raw', 'external', 'location']
    )
}}

{% set object_key = 'nyc-taxi-raw/zone/taxi_zone_centroids.csv' %}

select
    *,
    _path as source_path,
    _file as source_file
from {{ s3_source(
    object_key,
    'CSVWithNames',
    'LocationID UInt32, latitude Float64, longitude Float64'
) }}
