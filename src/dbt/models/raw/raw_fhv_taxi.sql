{{ 
    table_configuration(
        materialized='view',
        schema='raw',
        alias='ext_fhv_trips',
        tags=['raw', 'external', 'fhv_taxi_trips']
    )
}}

{% set year = var('year') | int %}
{% set month = var('month') | int %}
{% set object_key = construct_object_key('fhv', year, month, 'parquet') %}


select
    *,
    _path as source_path,
    _file as source_file,
    toUInt16({{ year }}) as source_year,
    toUInt8({{ month }}) as source_month
    _etag as source_etag,
    rowNumberInAllBlocks() as row_number,
    lower(hex(SHA256(concatWithSeparator('||', _path, _etag)))) as source_file_id,
from {{ s3_source(object_key) }}      