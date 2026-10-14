{{
    config(
        materialized='view',
        schema='intermediate',
        alias='int_trips_conformed',
        tags=['intermediate', 'trip_metrics']
    )
}}

with unioned as (
    select
        'yellow' as service_type,
        source_year,
        source_month,
        source_file_id,
        pickup_datetime,
        dropoff_datetime,
        pickup_location_id,
        dropoff_location_id,
        passenger_count,
        trip_distance_miles,
        trip_duration_seconds,
        true as passenger_count_is_applicable,
        true as distance_is_applicable
    from {{ ref('fct_yellow_taxi') }}

    union all

    select
        'green' as service_type,
        source_year,
        source_month,
        source_file_id,
        pickup_datetime,
        dropoff_datetime,
        pickup_location_id,
        dropoff_location_id,
        passenger_count,
        trip_distance_miles,
        trip_duration_seconds,
        true as passenger_count_is_applicable,
        true as distance_is_applicable
    from {{ ref('fct_green_taxi') }}

    union all

    select
        'fhv' as service_type,
        source_year,
        source_month,
        source_file_id,
        pickup_datetime,
        dropoff_datetime,
        pickup_location_id,
        dropoff_location_id,
        cast(null as Nullable(Int16)) as passenger_count,
        cast(null as Nullable(Decimal64(3))) as trip_distance_miles,
        trip_duration_seconds,
        false as passenger_count_is_applicable,
        false as distance_is_applicable
    from {{ ref('fct_fhv_taxi') }}

    union all

    select
        'fhvhv' as service_type,
        source_year,
        source_month,
        source_file_id,
        pickup_datetime,
        dropoff_datetime,
        pickup_location_id,
        dropoff_location_id,
        cast(null as Nullable(Int16)) as passenger_count,
        trip_miles as trip_distance_miles,
        calculated_trip_duration_seconds as trip_duration_seconds,
        false as passenger_count_is_applicable,
        true as distance_is_applicable
    from {{ ref('fct_fhvhv_taxi') }}
)

select
    service_type,
    source_year,
    source_month,
    source_file_id,
    pickup_datetime,
    dropoff_datetime,
    toYYYYMMDD(pickup_datetime) as pickup_date_id,
    toDate(pickup_datetime) as pickup_date,
    toUInt8(toHour(pickup_datetime)) as pickup_hour,
    pickup_location_id,
    dropoff_location_id,
    passenger_count,
    trip_distance_miles,
    trip_duration_seconds,
    pickup_datetime is not null as pickup_datetime_is_reported,
    dropoff_datetime is not null as dropoff_datetime_is_reported,
    pickup_location_id is not null as pickup_zone_is_reported,
    dropoff_location_id is not null as dropoff_zone_is_reported,
    passenger_count_is_applicable,
    passenger_count is not null as passenger_count_is_reported,
    distance_is_applicable,
    trip_distance_miles is not null as distance_is_reported,
    trip_distance_miles is not null and trip_distance_miles >= 0 as distance_is_valid,
    trip_duration_seconds is not null as duration_is_reported,
    trip_duration_seconds is not null and trip_duration_seconds >= 0 as duration_is_valid,
    pickup_datetime is not null
        and (
            toYear(pickup_datetime) != source_year
            or toMonth(pickup_datetime) != source_month
        ) as event_outside_source_month
from unioned
