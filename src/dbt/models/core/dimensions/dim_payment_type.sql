{{
    config(
        materialized='table',
        schema='core',
        alias='dim_payment_type',
        engine='MergeTree()',
        order_by=['payment_type_id'],
        tags=['core', 'dimension', 'payment_type']
    )
}}

select toInt16(0) as payment_type_id, 'Flex Fare trip' as payment_type_name, 'Trip paid through the Flex Fare program.' as description
union all
select toInt16(1), 'Credit card', 'Passenger paid by credit card.'
union all
select toInt16(2), 'Cash', 'Passenger paid in cash; cash tips are not recorded.'
union all
select toInt16(3), 'No charge', 'No passenger charge was collected.'
union all
select toInt16(4), 'Dispute', 'The charge was disputed.'
union all
select toInt16(5), 'Unknown', 'Payment type is unknown.'
union all
select toInt16(6), 'Voided trip', 'The trip transaction was voided.'
