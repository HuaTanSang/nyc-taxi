{{ config(tags=["quality_core"]) }}

with staging as (
    select
        countIf(passenger_count is null) as passenger_null_count,
        countIf(rate_code_id is null) as rate_null_count,
        countIf(congestion_surcharge is null) as surcharge_null_count
    from {{ ref('stg_yellow_trips') }}
    where payment_type_id = 0
),

fact as (
    select
        countIf(passenger_count is null) as passenger_null_count,
        countIf(rate_code_id is null) as rate_null_count,
        countIf(congestion_surcharge is null) as surcharge_null_count
    from {{ ref('fct_yellow_taxi') }}
    where source_year = toUInt16({{ var('year') | int }})
      and source_month = toUInt8({{ var('month') | int }})
      and is_flex_fare_trip
)

select 1
from staging
cross join fact
where staging.passenger_null_count != fact.passenger_null_count
   or staging.rate_null_count != fact.rate_null_count
   or staging.surcharge_null_count != fact.surcharge_null_count
