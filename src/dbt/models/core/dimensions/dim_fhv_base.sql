{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        unique_key='base_number',
        schema='core',
        alias='dim_fhv_base',
        engine='MergeTree()',
        order_by=['base_number'],
        tags=['core', 'dimension', 'fhv_base']
    )
}}

with base_numbers as (
    select dispatching_base_num as base_number
    from {{ ref('stg_fhv_trips') }}

    union all

    select affiliated_base_number
    from {{ ref('stg_fhv_trips') }}

    union all

    select dispatching_base_num
    from {{ ref('stg_fhvhv_trips') }}

    union all

    select originating_base_num
    from {{ ref('stg_fhvhv_trips') }}
),

distinct_bases as (
    select distinct base_number
    from base_numbers
    where base_number is not null
        and trim(base_number) != ''
)

select
    assumeNotNull(base_number) as base_number,
    cast(null as Nullable(String)) as base_name,
    cast(null as Nullable(String)) as base_type,
    cast(null as Nullable(String)) as address,
    cast(null as Nullable(String)) as city,
    cast(null as Nullable(String)) as state,
    cast(null as Nullable(String)) as postal_code,
    true as active_flag
from distinct_bases

{% if is_incremental() %}
where base_number not in (
    select base_number
    from {{ this }}
)
{% endif %}
