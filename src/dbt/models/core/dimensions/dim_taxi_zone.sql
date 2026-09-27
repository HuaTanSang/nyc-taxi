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
    toInt32(assumeNotNull(locations.location_id)) as location_id,
    locations.borough,
    locations.zone,
    locations.service_zone,
    centroids.latitude,
    centroids.longitude
from {{ ref('stg_locations') }} as locations
left join {{ ref('stg_zone_centroids') }} as centroids
    on locations.location_id = centroids.location_id
where locations.location_id is not null
