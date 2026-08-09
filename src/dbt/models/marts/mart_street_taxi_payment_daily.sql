{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        unique_key=['source_year', 'source_month', 'pickup_date_id', 'service_type', 'payment_type_id'],
        schema='serving',
        alias='mart_street_taxi_payment_daily',
        engine='MergeTree()',
        order_by=[
            'source_year',
            'source_month',
            'service_type',
            'ifNull(pickup_date_id, 0)',
            'ifNull(payment_type_id, 0)'
        ],
        partition_by=['source_year', 'source_month'],
        tags=['serving', 'mart', 'daily', 'payment']
    )
}}

with street_taxi_trips as (
    select
        'yellow' as service_type,
        source_year,
        source_month,
        pickup_date_id,
        pickup_datetime,
        payment_type_id,
        fare_amount,
        tip_amount,
        total_amount
    from {{ ref('fct_yellow_taxi') }}

    {% if is_incremental() %}
    where source_year = toUInt16({{ var('year') | int }})
        and source_month = toUInt8({{ var('month') | int }})
    {% endif %}

    union all

    select
        'green' as service_type,
        source_year,
        source_month,
        pickup_date_id,
        pickup_datetime,
        payment_type_id,
        fare_amount,
        tip_amount,
        total_amount
    from {{ ref('fct_green_taxi') }}

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
        service_type,
        payment_type_id,
        count() as trip_count,
        sum(ifNull(fare_amount, toDecimal64(0, 2))) as total_fare_amount,
        sum(ifNull(tip_amount, toDecimal64(0, 2))) as total_tip_amount,
        sum(ifNull(total_amount, toDecimal64(0, 2))) as total_passenger_charge_amount,
        avgOrNull(toFloat64(fare_amount)) as average_fare_amount,
        avgOrNull(toFloat64(tip_amount)) as average_tip_amount,
        avgOrNull(toFloat64(total_amount)) as average_passenger_charge_amount,
        if(
            sum(ifNull(fare_amount, toDecimal64(0, 2))) <= 0,
            cast(null as Nullable(Float64)),
            100.0 * toFloat64(sum(ifNull(tip_amount, toDecimal64(0, 2))))
                / toFloat64(sum(ifNull(fare_amount, toDecimal64(0, 2))))
        ) as tip_to_fare_percent
    from street_taxi_trips
    group by
        source_year,
        source_month,
        pickup_date_id,
        pickup_date,
        service_type,
        payment_type_id
)

select
    aggregated.source_year,
    aggregated.source_month,
    aggregated.pickup_date_id,
    aggregated.pickup_date,
    aggregated.service_type,
    aggregated.payment_type_id,
    payment_types.payment_type_name,
    aggregated.trip_count,
    aggregated.total_fare_amount,
    aggregated.total_tip_amount,
    aggregated.total_passenger_charge_amount,
    aggregated.average_fare_amount,
    aggregated.average_tip_amount,
    aggregated.average_passenger_charge_amount,
    aggregated.tip_to_fare_percent
from aggregated
left join {{ ref('dim_payment_type') }} as payment_types
    on aggregated.payment_type_id = payment_types.payment_type_id
