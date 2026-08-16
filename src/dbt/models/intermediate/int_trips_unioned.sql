{{
    config(
        materialized='view',
        schema='intermediate',
        alias='int_trips_unioned',
        tags=['intermediate', 'trip_metrics']
    )
}}

select
    'yellow' as service_type,
    source_year,
    source_month,
    pickup_date_id,
    pickup_datetime,
    dropoff_datetime,
    pickup_location_id,
    dropoff_location_id,
    passenger_count,
    trip_distance_miles,
    trip_duration_seconds,
    total_amount as passenger_charge_amount,
    tip_amount
from {{ ref('fct_yellow_taxi') }}

union all

select
    'green' as service_type,
    source_year,
    source_month,
    pickup_date_id,
    pickup_datetime,
    dropoff_datetime,
    pickup_location_id,
    dropoff_location_id,
    passenger_count,
    trip_distance_miles,
    trip_duration_seconds,
    total_amount as passenger_charge_amount,
    tip_amount
from {{ ref('fct_green_taxi') }}

union all

select
    'fhv' as service_type,
    source_year,
    source_month,
    pickup_date_id,
    pickup_datetime,
    dropoff_datetime,
    pickup_location_id,
    dropoff_location_id,
    cast(null as Nullable(Int16)) as passenger_count,
    cast(null as Nullable(Decimal64(3))) as trip_distance_miles,
    trip_duration_seconds,
    cast(null as Nullable(Decimal64(2))) as passenger_charge_amount,
    cast(null as Nullable(Decimal64(2))) as tip_amount
from {{ ref('fct_fhv_taxi') }}

union all

select
    'fhvhv' as service_type,
    source_year,
    source_month,
    pickup_date_id,
    pickup_datetime,
    dropoff_datetime,
    pickup_location_id,
    dropoff_location_id,
    cast(null as Nullable(Int16)) as passenger_count,
    trip_miles as trip_distance_miles,
    calculated_trip_duration_seconds as trip_duration_seconds,
    if(
        base_passenger_fare is null
            and tolls is null
            and bcf is null
            and sales_tax is null
            and congestion_surcharge is null
            and airport_fee is null
            and cbd_congestion_fee is null
            and tips is null,
        cast(null as Nullable(Decimal64(2))),
        cast(
            ifNull(base_passenger_fare, toDecimal64(0, 2))
                + ifNull(tolls, toDecimal64(0, 2))
                + ifNull(bcf, toDecimal64(0, 2))
                + ifNull(sales_tax, toDecimal64(0, 2))
                + ifNull(congestion_surcharge, toDecimal64(0, 2))
                + ifNull(airport_fee, toDecimal64(0, 2))
                + ifNull(cbd_congestion_fee, toDecimal64(0, 2))
                + ifNull(tips, toDecimal64(0, 2))
            as Nullable(Decimal64(2))
        )
    ) as passenger_charge_amount,
    tips as tip_amount
from {{ ref('fct_fhvhv_taxi') }}
