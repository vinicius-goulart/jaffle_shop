with 

-- Import CTEs
customers as (
    select * from {{ ref('stg_jaffle_shop__customers') }}
),

orders as (
    select * from {{ ref('stg_jaffle_shop__orders') }}
),

payments as (
    select * from {{ ref('stg_stripe__payment') }}
),

-- Logical CTEs
payments_aggregated as (
    select 
        order_id,
        max(payment_created) as payment_finalized_date,
        sum(payment_amount) / 100.0 as total_amount_paid
    from payments
    where payment_status <> 'fail'
    group by 1
),

paid_orders as (
    select 
        orders.order_id,
        orders.customer_id,
        orders.order_date,
        orders.order_status,

        payments_aggregated.total_amount_paid,
        payments_aggregated.payment_finalized_date,

        customers.first_name,
        customers.last_name
    from orders
    left join payments_aggregated  on orders.order_id = payments_aggregated.order_id
    left join customers  on orders.customer_id = customers.customer_id
),

-- Final CTE
final as (
    select
        order_id,
        customer_id,
        order_date,
        order_status,
        total_amount_paid,
        payment_finalized_date,
        first_name,
        last_name,

        -- Transaction sequence across all orders
        row_number() over (
            order by order_date, order_id
        ) as transaction_seq,

        -- Customer order sequence
        row_number() over (
            partition by customer_id 
            order by order_date, order_id
        ) as customer_sales_seq,

        -- New vs. returning customer status
        case 
            when row_number() over (
                partition by customer_id 
                order by order_date, order_id
            ) = 1 then 'new'
            else 'return'
        end as nvsr,

        -- Customer lifetime value (CLV) using window sum
        sum(total_amount_paid) over (
            partition by customer_id
            order by order_date, order_id
            rows between unbounded preceding and current row
        ) as customer_lifetime_value,

        -- First order date per customer using first_value window function
        first_value(order_date) over (
            partition by customer_id
            order by order_date, order_id
            rows between unbounded preceding and unbounded following
        ) as fdos

    from paid_orders
)

-- Simple select statement
select * from final
order by order_id