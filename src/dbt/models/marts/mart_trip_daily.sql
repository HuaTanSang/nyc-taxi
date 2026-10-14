{{
    config(
        materialized='view',
        schema='marts',
        alias='mart_trip_daily',
        tags=['serving', 'mart', 'daily']
    )
}}

with reaggregated as (
    select
        source.pickup_date_id,
        source.pickup_date,
        source.service_type,
        sum(source.trip_count) as trip_count,
        sum(source.passenger_count_recorded_count) as passenger_count_recorded_count,
        if(
            sum(source.passenger_count_recorded_count) = 0,
            cast(null as Nullable(Int64)),
            sum(ifNull(source.passenger_count_sum, 0))
        ) as passenger_count_sum,
        sum(source.distance_valid_count) as distance_valid_count,
        if(
            sum(source.distance_valid_count) = 0,
            cast(null as Nullable(Decimal64(3))),
            sum(ifNull(source.distance_sum_miles, toDecimal64(0, 3)))
        ) as distance_sum_miles,
        sum(source.duration_valid_count) as duration_valid_count,
        if(
            sum(source.duration_valid_count) = 0,
            cast(null as Nullable(Int64)),
            sum(ifNull(source.duration_sum_seconds, 0))
        ) as duration_sum_seconds
    from {{ ref('agg_trip_daily_by_source') }} as source
    group by source.pickup_date_id, source.pickup_date, source.service_type
)

select
    reaggregated.pickup_date_id,
    reaggregated.pickup_date,
    dates.year as pickup_year,
    dates.quarter as pickup_quarter,
    dates.month as pickup_month,
    dates.month_name as pickup_month_name,
    dates.day_of_week as pickup_day_of_week,
    dates.day_name as pickup_day_name,
    dates.week_of_year as pickup_week_of_year,
    dates.is_weekend as pickup_is_weekend,
    dates.is_holiday as pickup_is_holiday,
    dates.holiday_name as pickup_holiday_name,
    reaggregated.service_type,
    reaggregated.trip_count,
    reaggregated.passenger_count_recorded_count,
    reaggregated.passenger_count_sum,
    reaggregated.distance_valid_count,
    reaggregated.distance_sum_miles,
    reaggregated.duration_valid_count,
    reaggregated.duration_sum_seconds
from reaggregated
left join {{ ref('dim_date') }} as dates
    on reaggregated.pickup_date_id = dates.date_id
