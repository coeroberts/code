with product_data_ad as
(
select customer_id,sum(revenue) as ad_revenue, sum(mrr) as ad_mrr
from mrr_subscription_daily_all_products
where etl_load_date=date_sub(current_date, 1)
and product_line_id in (2,7)
group by customer_id
),
product_data_other as
(
select customer_id,
max(case when product_line_id =4 then mrr else 0 end) as mrr_avvopro,
max(case when product_line_id =10 then mrr else 0 end) as mrr_ignite,
max(case when product_line_id =15 then mrr else 0 end) as mrr_website,
max(case when product_line_id =18 then mrr else 0 end) as mrr_adplacement,
max(case when product_line_id =4 then  revenue else 0 end) as revenue_avvopro,
max(case when product_line_id =10 then  revenue else 0 end) as revenue_ignite,
max(case when product_line_id =15 then  revenue else 0 end )as revenue_website,
max(case when product_line_id =18 then  revenue else 0 end )as revenue_adplacement
from
(
select customer_id, product_line_id, sum(revenue) as revenue, sum(mrr) as mrr
from mrr_subscription_daily_all_products
where etl_load_date=date_sub(current_date, 1)
and product_line_id not in (2,7,-1)
group by customer_id,product_line_id) as a
group by customer_id
),
misc_data as
(
select customer_id,sum(revenue) as misc_revenue
from mrr_subscription_daily_all_products
where etl_load_date=date_sub(current_date, 1)
and subscription_id=-1
and product_line_id=-1
group by customer_id
),
exp_data as 
(
select customer_id, max(expired_date) as expired_date, concat_ws('|',collect_set( expired_reason)) as expired_reason,
max(block_conversion_date) as block_conversion_date, max(refund_current_month_flag) as refund_current_month_flag, 
max(payment_failure_flag) as payment_failure_flag , max(promo_flag) as promo_flag
from mrr_subscription_daily_all_products
where etl_load_date=date_sub(current_date, 1)
group by customer_id
),
final_data as 
(
select 
cd.customer_id,
coalesce(ad_mrr,0) as mrr_advertisement,
coalesce(mrr_avvopro,0) as mrr_avvopro,
coalesce(mrr_ignite,0) as mrr_ignite,
coalesce(mrr_website,0) as mrr_website,
coalesce(mrr_adplacement,0) as mrr_adplacement,
coalesce(ad_revenue,0) as revenue_advertisement,
coalesce(revenue_avvopro,0) as revenue_avvopro,
coalesce(revenue_ignite,0) as revenue_ignite,
coalesce(revenue_website,0) as revenue_website,
coalesce(misc_revenue,0) as revenue_misc,
coalesce(revenue_adplacement,0) as revenue_adplacement,
expired_date,
expired_reason,
case when cast(concat(year(block_conversion_date),lpad(month(block_conversion_date),2,0)) as int)= cast(concat(year(add_months(current_date, -1)), lpad(month(add_months(current_date, -1)),2,0)) as int) then 'Yes' else 'No' end as block_conversion_flag,
case when ed.customer_id is null then 'N' else 'Y' end as customer_billed_current_month,
coalesce(refund_current_month_flag,'N') as refund_current_month_flag,
coalesce(payment_failure_flag,'N') as payment_failure_flag,
date_sub(current_date, 1) as etl_load_date,
promo_flag
from customer_dimension cd
join ${srcDatabase}.nrt_customer nc
on cd.customer_id=nc.id
and to_date(created_at) <= date_sub(current_date, 1)
left join product_data_ad pda
on cd.customer_id=pda.customer_id
left join product_data_other pdo
on cd.customer_id=pdo.customer_id
left join misc_data md
on cd.customer_id=md.customer_id
left join exp_data ed
on cd.customer_id=ed.customer_id
)
INSERT OVERWRITE TABLE mrr_customer_daily_all_products partition (etl_load_date)
select
customer_id,
mrr_advertisement,
mrr_avvopro,
mrr_ignite,
mrr_website,
mrr_adplacement,
(mrr_advertisement+mrr_avvopro+mrr_ignite+mrr_website+mrr_adplacement) as mrr_total,
revenue_advertisement,
revenue_avvopro,
revenue_ignite,
revenue_website,
revenue_misc,
revenue_adplacement,
(revenue_advertisement+revenue_avvopro+revenue_ignite+revenue_website+revenue_misc+revenue_adplacement) as revenue_total,
expired_date,
expired_reason,
block_conversion_flag,
customer_billed_current_month,
refund_current_month_flag,
payment_failure_flag,
promo_flag,
etl_load_date
from final_data;