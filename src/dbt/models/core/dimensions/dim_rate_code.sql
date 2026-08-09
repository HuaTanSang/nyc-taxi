{{
    config(
        materialized='table',
        schema='core',
        alias='dim_rate_code',
        engine='MergeTree()',
        order_by=['rate_code_id'],
        tags=['core', 'dimension', 'rate_code']
    )
}}

select toInt16(0) as rate_code_id, 'Unknown' as rate_code_name, 'Rate code was not reported.' as description
union all
select toInt16(1), 'Standard rate', 'Standard metered taxi rate.'
union all
select toInt16(2), 'JFK', 'Flat or special rate for John F. Kennedy International Airport.'
union all
select toInt16(3), 'Newark', 'Rate code for Newark Liberty International Airport.'
union all
select toInt16(4), 'Nassau or Westchester', 'Rate code for Nassau or Westchester counties.'
union all
select toInt16(5), 'Negotiated fare', 'Fare negotiated before the trip.'
union all
select toInt16(6), 'Group ride', 'Group ride rate.'
union all
select toInt16(99), 'Unknown', 'TLC null or unknown rate code.'
