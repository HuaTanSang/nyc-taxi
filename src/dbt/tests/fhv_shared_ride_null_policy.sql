{{ config(tags=["quality_core"]) }}

select shared_ride_flag
from {{ ref('fct_fhv_taxi') }}
where source_year = toUInt16({{ var('year') | int }})
  and source_month = toUInt8({{ var('month') | int }})
  and shared_ride_flag is null
