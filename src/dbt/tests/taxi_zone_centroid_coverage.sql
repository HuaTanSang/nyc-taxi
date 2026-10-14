{{ config(tags=["quality_core"]) }}

select location_id, latitude, longitude
from {{ ref('dim_taxi_zone') }}
where (
        location_id between 1 and 263
        and (latitude is null or longitude is null)
    )
   or latitude not between 40.0 and 42.0
   or longitude not between -75.0 and -72.0
