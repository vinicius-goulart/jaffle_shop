{% set old_query %}
    select
        order_id,
        customer_id,
        order_placed_at as order_date,
        total_amount_paid
    from {{ ref('customer_orders_legacy') }}
{% endset %}

{% set new_query %}
    select
        order_id,
        customer_id,
        order_date,
        total_amount_paid
    from {{ ref('fct_customer_orders') }}
{% endset %}

{{ audit_helper.compare_queries(
    a_query = old_query,
    b_query = new_query,
    primary_key = "order_id"
) }}