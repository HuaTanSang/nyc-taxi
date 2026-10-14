{{
    table_configuration(
        materialized='view',
        schema='staging',
        alias='stg_zone_centroids',
        tags=['staging', 'view', 'location']
    )
}}

select
    toInt32OrNull(toString(LocationID)) as location_id,
    toFloat64OrNull(toString(latitude)) as latitude,
    toFloat64OrNull(toString(longitude)) as longitude,
    nullIf(trim(toString(source_path)), '') as source_path,
    nullIf(trim(toString(source_file)), '') as source_file
from {{ ref('raw_zone_centroids') }}
