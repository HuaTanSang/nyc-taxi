{{
    config(
        materialized='table',
        schema='core',
        alias='dim_hvfhv_provider',
        engine='MergeTree()',
        order_by=['hvfhs_license_number'],
        tags=['core', 'dimension', 'fhvhv_provider']
    )
}}

select
    'HV0002' as hvfhs_license_number,
    'Juno' as provider_name,
    'TLC High Volume For-Hire Service license HV0002.' as description

union all

select
    'HV0003',
    'Uber',
    'TLC High Volume For-Hire Service license HV0003.'

union all

select
    'HV0004',
    'Via',
    'TLC High Volume For-Hire Service license HV0004.'

union all

select
    'HV0005',
    'Lyft',
    'TLC High Volume For-Hire Service license HV0005.'
