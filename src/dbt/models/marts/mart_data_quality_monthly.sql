{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        schema='marts',
        alias='mart_data_quality_monthly',
        engine='MergeTree()',
        partition_by=['source_year', 'source_month'],
        order_by=['source_year', 'source_month', 'service_type', 'metric_name'],
        settings={'allow_nullable_key': 1},
        tags=['serving', 'mart', 'data_quality']
    )
}}

{{ reject_full_refresh() }}

with summary as (
    select
        source_year,
        source_month,
        service_type,
        count() as total_records,
        countIf(pickup_datetime_is_reported) as pickup_datetime_reported,
        countIf(pickup_zone_is_reported) as pickup_zone_reported,
        countIf(dropoff_zone_is_reported) as dropoff_zone_reported,
        countIf(duration_is_valid) as duration_valid,
        countIf(distance_is_applicable) as distance_eligible,
        countIf(distance_is_valid) as distance_valid,
        countIf(passenger_count_is_applicable) as passenger_count_eligible,
        countIf(passenger_count_is_reported) as passenger_count_reported,
        countIf(event_outside_source_month) as outside_source_month
    from {{ ref('int_trips_conformed') }}
    where source_year = toUInt16({{ var('year') | int }})
      and source_month = toUInt8({{ var('month') | int }})
    group by source_year, source_month, service_type
),

long_metrics as (
    select
        source_year,
        source_month,
        service_type,
        arrayJoin([
            tuple(
                'pickup_datetime',
                'measured',
                pickup_datetime_reported,
                total_records,
                'Trips with a reported pickup timestamp.'
            ),
            tuple(
                'pickup_zone',
                'measured',
                pickup_zone_reported,
                total_records,
                'Trips with a reported TLC pickup zone.'
            ),
            tuple(
                'dropoff_zone',
                'measured',
                dropoff_zone_reported,
                total_records,
                'Trips with a reported TLC drop-off zone.'
            ),
            tuple(
                'duration',
                'measured',
                duration_valid,
                total_records,
                'Trips with a non-negative pickup-to-drop-off duration.'
            ),
            tuple(
                'distance',
                if(distance_eligible = 0, 'not_applicable', 'measured'),
                distance_valid,
                distance_eligible,
                if(
                    distance_eligible = 0,
                    'Distance is not supplied by this TLC dataset.',
                    'Trips with a reported non-negative distance.'
                )
            ),
            tuple(
                'passenger_count',
                if(passenger_count_eligible = 0, 'not_applicable', 'measured'),
                passenger_count_reported,
                passenger_count_eligible,
                if(
                    passenger_count_eligible = 0,
                    'Passenger count is not supplied by this TLC dataset.',
                    'Trips with a reported passenger count.'
                )
            ),
            tuple(
                'event_outside_source_month',
                'anomaly_rate',
                outside_source_month,
                pickup_datetime_reported,
                'Share of reported pickup timestamps outside the source file month; lower is better.'
            )
        ]) as metric
    from summary
)

select
    source_year,
    source_month,
    toDate(
        concat(
            toString(source_year),
            '-',
            leftPad(toString(source_month), 2, '0'),
            '-01'
        )
    ) as source_period,
    service_type,
    tupleElement(metric, 1) as metric_name,
    tupleElement(metric, 2) as coverage_status,
    tupleElement(metric, 3) as reported_count,
    tupleElement(metric, 4) as eligible_count,
    if(
        tupleElement(metric, 4) = 0,
        cast(null as Nullable(Float64)),
        100.0 * tupleElement(metric, 3) / tupleElement(metric, 4)
    ) as coverage_percent,
    tupleElement(metric, 5) as note
from long_metrics
