{{ config(tags=["quality_mart"]) }}

with direct as (
    select
        service_type,
        count() as trip_count,
        countIf(passenger_count_is_reported) as passenger_count_recorded_count,
        sumIf(toInt64(passenger_count), passenger_count_is_reported) as passenger_count_sum,
        countIf(distance_is_valid) as distance_valid_count,
        sumIf(trip_distance_miles, distance_is_valid) as distance_sum_miles,
        countIf(duration_is_valid) as duration_valid_count,
        sumIf(trip_duration_seconds, duration_is_valid) as duration_sum_seconds
    from {{ ref('int_trips_conformed') }}
    where source_year = toUInt16({{ var('year') | int }})
      and source_month = toUInt8({{ var('month') | int }})
      and pickup_datetime_is_reported
    group by service_type
),

aggregated as (
    select
        service_type,
        sum(trip_count) as trip_count,
        sum(passenger_count_recorded_count) as passenger_count_recorded_count,
        sum(ifNull(passenger_count_sum, 0)) as passenger_count_sum,
        sum(distance_valid_count) as distance_valid_count,
        sum(ifNull(distance_sum_miles, toDecimal64(0, 3))) as distance_sum_miles,
        sum(duration_valid_count) as duration_valid_count,
        sum(ifNull(duration_sum_seconds, 0)) as duration_sum_seconds
    from {{ ref('agg_trip_daily_by_source') }}
    where source_year = toUInt16({{ var('year') | int }})
      and source_month = toUInt8({{ var('month') | int }})
    group by service_type
)

select
    coalesce(direct.service_type, aggregated.service_type) as service_type
from direct
full outer join aggregated
    on direct.service_type = aggregated.service_type
where direct.trip_count != aggregated.trip_count
   or direct.passenger_count_recorded_count != aggregated.passenger_count_recorded_count
   or ifNull(direct.passenger_count_sum, 0) != aggregated.passenger_count_sum
   or direct.distance_valid_count != aggregated.distance_valid_count
   or ifNull(direct.distance_sum_miles, toDecimal64(0, 3)) != aggregated.distance_sum_miles
   or direct.duration_valid_count != aggregated.duration_valid_count
   or ifNull(direct.duration_sum_seconds, 0) != aggregated.duration_sum_seconds
   or direct.service_type is null
   or aggregated.service_type is null
