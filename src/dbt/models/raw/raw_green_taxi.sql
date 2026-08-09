{{ 
    table_configuration(
        materialized='view',
        schema='raw',
        alias='ext_green_trips',
        tags=['raw', 'external', 'green_taxi_trips']
    )
}}

{% set year = var('year') | int %}
{% set month = var('month') | int %}
{% set object_key = construct_object_key('green', year, month, 'parquet') %}


select
    *,
    _path as source_path,
    _file as source_file,
    toUInt16({{ year }}) as source_year,
    toUInt8({{ month }}) as source_month
from {{ s3_source(object_key) }}     