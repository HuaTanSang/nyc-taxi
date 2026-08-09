{{
    config(
        materialized='table',
        schema='core',
        alias='dim_taxi_zone',
        engine='MergeTree()',
        order_by=['location_id'],
        tags=['core', 'dimension', 'taxi_zone']
    )
}}

select
    toInt32(assumeNotNull(location_id)) as location_id,
    borough,
    zone,
    service_zone
from {{ ref('stg_locations') }}
where location_id is not null
