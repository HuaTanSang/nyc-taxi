with counts as (
    select
        (select count() from {{ ref('raw_fhv_taxi') }}) as raw_count,
        (select count() from {{ ref('stg_fhv_trips') }}) as staging_count,
        (
            select count()
            from {{ ref('fct_fhv_taxi') }}
            where source_year = toUInt16({{ var('year') | int }})
              and source_month = toUInt8({{ var('month') | int }})
        ) as fact_count
)

select *
from counts
where raw_count != staging_count
   or staging_count != fact_count