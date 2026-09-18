with 

-- Import CTEs
customers as (
    select * from {{ source('jaffle_shop', 'customers') }}
),

orders as (
    select * from {{ source('jaffle_shop', 'orders') }}
),

payments as (
    select * from {{ source('stripe', 'payment') }}
),

-- Logical CTEs
payments_aggregated as (
    select 
        orderid as order_id,
        max(created) as payment_finalized_date,
        sum(amount) / 100.0 as total_amount_paid
    from payments
    where status <> 'fail'
    group by 1
),

paid_orders as (
    select 
        orders.id as order_id,
        orders.user_id as customer_id,
        orders.order_date as order_placed_at,
        orders.status as order_status,
        p.total_amount_paid,
        p.payment_finalized_date,
        c.first_name as customer_first_name,
        c.last_name as customer_last_name
    from orders
    left join payments_aggregated p on orders.id = p.order_id
    left join customers c on orders.user_id = c.id
),

-- Final CTE
final as (
    select
        order_id,
        customer_id,
        order_placed_at,
        order_status,
        total_amount_paid,
        payment_finalized_date,
        customer_first_name,
        customer_last_name,

        -- Transaction sequence across all orders
        row_number() over (
            order by order_placed_at, order_id
        ) as transaction_seq,

        -- Customer order sequence
        row_number() over (
            partition by customer_id 
            order by order_placed_at, order_id
        ) as customer_sales_seq,

        -- New vs. returning customer status
        case 
            when row_number() over (
                partition by customer_id 
                order by order_placed_at, order_id
            ) = 1 then 'new'
            else 'return'
        end as nvsr,

        -- Customer lifetime value (CLV) using window sum
        sum(total_amount_paid) over (
            partition by customer_id
            order by order_placed_at, order_id
            rows between unbounded preceding and current row
        ) as customer_lifetime_value,

        -- First order date per customer using first_value window function
        first_value(order_placed_at) over (
            partition by customer_id
            order by order_placed_at, order_id
            rows between unbounded preceding and unbounded following
        ) as fdos

    from paid_orders
)

-- Simple select statement
select * from final