{{
    config(
        materialized='table',
        schema='core',
        alias='dim_vendor',
        engine='MergeTree()',
        order_by=['vendor_id'],
        tags=['core', 'dimension', 'vendor']
    )
}}

select
    toInt16(0) as vendor_id,
    'Unknown' as vendor_name,
    'Vendor was missing or not recognized.' as description

union all

select
    toInt16(1),
    'Creative Mobile Technologies, LLC',
    'TPEP/LPEP technology provider code 1.'

union all

select
    toInt16(2),
    'Curb Mobility, LLC',
    'TPEP/LPEP technology provider code 2.'

union all

select
    toInt16(6),
    'Myle Technologies Inc',
    'TPEP technology provider code 6.'

union all

select
    toInt16(7),
    'Helix',
    'TPEP technology provider code 7.'
