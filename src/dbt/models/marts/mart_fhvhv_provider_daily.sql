{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        unique_key=['source_year', 'source_month', 'pickup_date_id', 'hvfhs_license_number'],
        schema='serving',
        alias='mart_fhvhv_provider_daily',
        engine='MergeTree()',
        order_by=[
            'source_year',
            'source_month',
            'ifNull(pickup_date_id, 0)',
            "ifNull(hvfhs_license_number, '')"
        ],
        partition_by=['source_year', 'source_month'],
        tags=['serving', 'mart', 'daily', 'fhvhv_provider']
    )
}}

with trips as (
    select
        *,
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
        ) as passenger_charge_amount
    from {{ ref('fct_fhvhv_taxi') }}

    {% if is_incremental() %}
    where source_year = toUInt16({{ var('year') | int }})
        and source_month = toUInt8({{ var('month') | int }})
    {% endif %}
),

aggregated as (
    select
        source_year,
        source_month,
        pickup_date_id,
        toDate(pickup_datetime) as pickup_date,
        hvfhs_license_number,

        count() as trip_count,
        sum(ifNull(trip_miles, toDecimal64(0, 3))) as total_trip_miles,
        sum(ifNull(base_passenger_fare, toDecimal64(0, 2))) as total_base_passenger_fare,
        sum(ifNull(passenger_charge_amount, toDecimal64(0, 2))) as total_passenger_charge_amount,
        sum(ifNull(tips, toDecimal64(0, 2))) as total_tips,
        sum(ifNull(driver_pay, toDecimal64(0, 2))) as total_driver_pay,

        avgOrNull(toFloat64(reported_trip_time_seconds)) as average_reported_trip_time_seconds,
        avgOrNull(toFloat64(calculated_trip_duration_seconds)) as average_calculated_trip_duration_seconds,
        avgOrNull(toFloat64(request_to_pickup_seconds)) as average_request_to_pickup_seconds,
        avgOrNull(toFloat64(on_scene_to_pickup_seconds)) as average_on_scene_to_pickup_seconds,
        avgOrNull(toFloat64(driver_pay)) as average_driver_pay,

        countIf(shared_request_flag) as shared_request_count,
        countIf(shared_match_flag) as shared_match_count,
        if(
            countIf(shared_request_flag) = 0,
            cast(null as Nullable(Float64)),
            100.0 * countIf(shared_match_flag) / countIf(shared_request_flag)
        ) as shared_match_rate_percent,

        countIf(wav_request_flag) as wav_request_count,
        countIf(wav_match_flag) as wav_match_count,
        if(
            countIf(wav_request_flag) = 0,
            cast(null as Nullable(Float64)),
            100.0 * countIf(wav_match_flag) / countIf(wav_request_flag)
        ) as wav_match_rate_percent,

        countIf(access_a_ride_flag) as access_a_ride_trip_count
    from trips
    group by
        source_year,
        source_month,
        pickup_date_id,
        pickup_date,
        hvfhs_license_number
)

select
    aggregated.source_year,
    aggregated.source_month,
    aggregated.pickup_date_id,
    aggregated.pickup_date,
    aggregated.hvfhs_license_number,
    providers.provider_name,
    aggregated.trip_count,
    aggregated.total_trip_miles,
    aggregated.total_base_passenger_fare,
    aggregated.total_passenger_charge_amount,
    aggregated.total_tips,
    aggregated.total_driver_pay,
    aggregated.average_reported_trip_time_seconds,
    aggregated.average_calculated_trip_duration_seconds,
    aggregated.average_request_to_pickup_seconds,
    aggregated.average_on_scene_to_pickup_seconds,
    aggregated.average_driver_pay,
    aggregated.shared_request_count,
    aggregated.shared_match_count,
    aggregated.shared_match_rate_percent,
    aggregated.wav_request_count,
    aggregated.wav_match_count,
    aggregated.wav_match_rate_percent,
    aggregated.access_a_ride_trip_count
from aggregated
left join {{ ref('dim_hvfhv_provider') }} as providers
    on aggregated.hvfhs_license_number = providers.hvfhs_license_number
