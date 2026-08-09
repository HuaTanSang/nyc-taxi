{{
    table_configuration(
        materialized='view',
        schema='staging',
        alias='stg_locations',
        tags=['staging', 'view', 'location']
    )
}}

with source as (
    select *
    from {{ ref('raw_location') }}
)

select
    toUInt32OrNull(toString(LocationID)) as location_id,
    nullIf(trim(toString(Borough)), '') as borough,
    nullIf(trim(toString(Zone)), '') as zone,
    nullIf(trim(toString(service_zone)), '') as service_zone,
    nullIf(trim(toString(source_path)), '') as source_path,
    nullIf(trim(toString(source_file)), '') as source_file
from source
