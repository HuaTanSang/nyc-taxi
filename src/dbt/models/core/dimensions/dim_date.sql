{{
    config(
        materialized='table',
        schema='core',
        alias='dim_date',
        engine='MergeTree()',
        order_by=['date_id'],
        tags=['core', 'dimension', 'date']
    )
}}

{% set calendar_start_date = var('calendar_start_date', '2009-01-01') %}
{% set calendar_end_date = var('calendar_end_date', '2030-12-31') %}

with calendar as (
    select
        addDays(toDate('{{ calendar_start_date }}'), number) as full_date
    from numbers(
        toUInt64(
            dateDiff(
                'day',
                toDate('{{ calendar_start_date }}'),
                toDate('{{ calendar_end_date }}')
            ) + 1
        )
    )
),

holidays as (
    select
        full_date,
        multiIf(
            toMonth(full_date) = 1 and toDayOfMonth(full_date) = 1,
            'New Year''s Day',
            toMonth(full_date) = 1
                and toDayOfWeek(full_date) = 1
                and toDayOfMonth(full_date) between 15 and 21,
            'Martin Luther King Jr. Day',
            toMonth(full_date) = 2
                and toDayOfWeek(full_date) = 1
                and toDayOfMonth(full_date) between 15 and 21,
            'Presidents'' Day',
            toMonth(full_date) = 5
                and toDayOfWeek(full_date) = 1
                and toDayOfMonth(full_date) >= 25,
            'Memorial Day',
            toYear(full_date) >= 2021
                and toMonth(full_date) = 6
                and toDayOfMonth(full_date) = 19,
            'Juneteenth National Independence Day',
            toMonth(full_date) = 7 and toDayOfMonth(full_date) = 4,
            'Independence Day',
            toMonth(full_date) = 9
                and toDayOfWeek(full_date) = 1
                and toDayOfMonth(full_date) <= 7,
            'Labor Day',
            toMonth(full_date) = 10
                and toDayOfWeek(full_date) = 1
                and toDayOfMonth(full_date) between 8 and 14,
            'Columbus Day',
            toMonth(full_date) = 11 and toDayOfMonth(full_date) = 11,
            'Veterans Day',
            toMonth(full_date) = 11
                and toDayOfWeek(full_date) = 4
                and toDayOfMonth(full_date) between 22 and 28,
            'Thanksgiving Day',
            toMonth(full_date) = 12 and toDayOfMonth(full_date) = 25,
            'Christmas Day',
            cast(null as Nullable(String))
        ) as holiday_name
    from calendar
)

select
    toYYYYMMDD(full_date) as date_id,
    full_date,
    toUInt16(toYear(full_date)) as year,
    toUInt8(toQuarter(full_date)) as quarter,
    toUInt8(toMonth(full_date)) as month,
    dateName('month', full_date) as month_name,
    toUInt8(toDayOfMonth(full_date)) as day_of_month,
    toUInt8(toDayOfWeek(full_date)) as day_of_week,
    dateName('weekday', full_date) as day_name,
    toUInt8(toISOWeek(full_date)) as week_of_year,
    toDayOfWeek(full_date) in (6, 7) as is_weekend,
    holiday_name is not null as is_holiday,
    holiday_name
from holidays
