{{
    table_configuration(
        materialized='view',
        schema='raw',
        alias='ext_location',
        tags=['raw', 'external', 'location']
    )
}}


{% set object_key = 'nyc-taxi-raw/zone/taxi_zone_lookup.csv' %}

select
    *,
    _path as source_path,
    _file as source_file
from {{ s3_source(
    object_key,
    'CSV',
    'LocationID UInt32, Borough String, Zone String, service_zone String'
) }}