with

source AS (

    select * from {{ ref('stg_stripe__payment') }}

),

aggregated as (
    
    select sum(payment_amount) as total_revenue

    from source

    where payment_status <> 'fail'
)

select * from aggregated