{{
    config(
        materialized='table',
        schema='core',
        alias='dim_trip_type',
        engine='MergeTree()',
        order_by=['trip_type_id'],
        tags=['core', 'dimension', 'trip_type']
    )
}}

select toInt16(0) as trip_type_id, 'Unknown' as trip_type_name, 'Green Taxi trip type was not reported.' as description
union all
select toInt16(1), 'Street-hail', 'Passenger hailed the taxi on the street.'
union all
select toInt16(2), 'Dispatch', 'Trip was arranged through a dispatch.'
