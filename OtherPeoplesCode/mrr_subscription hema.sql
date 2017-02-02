with order_revenue as
(
	select olaf.yearmonth,product_subscription_id,ad_market_id,customer_id,(case when order_line_cancelled_date='-1' then null else order_line_cancelled_date end) as cancelled_date,
	sum(case when order_line_payment_date = '-1' then 0 else order_line_net_price_amount_usd end) as revenue,count(ad_id) as count_ad_id
	from order_line_accumulation_fact olaf left join order_line_ad_market_fact olamf
	on olaf.order_line_number=olamf.order_line_number
	-- where olaf.yearmonth=cast(concat(year(add_months(date_sub(current_date,1), -1)), lpad(month(add_months(date_sub(current_date,1), -1)),2,0)) as int)
        where olaf.yearmonth=cast(concat(year(add_months(current_date, -1)), lpad(month(add_months(current_date, -1)),2,0)) as int)
	and product_subscription_id <> -1
	and product_line_id in (2,7)
	group by olaf.yearmonth,product_subscription_id,ad_market_id,customer_id,order_line_cancelled_date
),
order_data_prev as 
(
select product_subscription_id,customer_id,ad_market_id,count(ad_id) as count_ad_id
from order_line_accumulation_fact olaf left join order_line_ad_market_fact olamf
on olaf.order_line_number=olamf.order_line_number
-- where olaf.yearmonth=cast(concat(year(add_months(date_sub(current_date,1), -2)), lpad(month(add_months(date_sub(current_date,1), -2)),2,0)) as int)
where olaf.yearmonth=cast(concat(year(add_months(current_date, -2)), lpad(month(add_months(current_date, -2)),2,0)) as int)
-- and order_line_payment_date <> '-1'
and product_subscription_id <> -1
and product_line_id in (2,7)
group by product_subscription_id,customer_id,ad_market_id
),
subscription_price as
(
select subscription_id,mrr from (
select subscription_id,round(cast(unit_price as double)*block_count/100,2) mrr,
rank() over(partition by subscription_id order by start_datetime desc, source_system_update_datetime desc) seq
from subscription_price_dimension
-- where source_system_update_datetime <= last_day(add_months(date_sub(current_date,1), -1))
where source_system_update_datetime <= concat(last_day(add_months(current_date, -1)),' ','23:59:59')
) as spd_curr
where seq=1
),
cust_created as
(
select id,max(created_at) as cust_create_date
from ${srcDatabase}.nrt_customer nc
group by id
)
select ore.product_subscription_id as subscription_id, 
ore.ad_market_id, 
ore.customer_id, 
ore.revenue,
coalesce(sp.mrr,0) as mrr_actual_value,
case when ((concat(year(ore.cancelled_date),lpad(month(ore.cancelled_date),2,0))=ore.yearmonth) OR (concat(year(to_date(ns.expire_datetime)),lpad(month(to_date(ns.expire_datetime)),2,0))=ore.yearmonth) OR ((concat(year(to_date(ns.expire_datetime)),lpad(month(to_date(ns.expire_datetime)),2,0))=ore.yearmonth) and lower(ns.expired_reason)='failed cc' and ore.revenue=0)) then 0 else coalesce(sp.mrr,0) end as mrr,
concat(year(cust_create_date),lpad(month(cust_create_date),2,0)) as customer_created_date,
case when concat(year(ore.cancelled_date),lpad(month(ore.cancelled_date),2,0))=ore.yearmonth then ore.cancelled_date end as cancelled_date,
case when concat(year(to_date(ns.expire_datetime)),lpad(month(to_date(ns.expire_datetime)),2,0))=ore.yearmonth then to_date(ns.expire_datetime) end as expired_date,
case when concat(year(to_date(ns.expire_datetime)),lpad(month(to_date(ns.expire_datetime)),2,0))=ore.yearmonth then ns.expired_reason end as expired_reason,
case when odps.product_subscription_id is null then 'N' else 'Y' end as subscription_billed_prior_month,
case when odpm.ad_market_id is null then 'N' else 'Y' end as market_billed_prior_month,
case when odpc.customer_id is null then 'N' else 'Y' end as customer_billed_prior_month,
ore.count_ad_id as ad_count,
ore.yearmonth
from order_revenue ore
left join subscription_price sp on sp.subscription_id=ore.product_subscription_id
left join cust_created cc on cc.id=ore.customer_id
left join order_data_prev odps on odps.customer_id=ore.customer_id
and odps.product_subscription_id=ore.product_subscription_id
left join (select customer_id,ad_market_id, count(1) from order_data_prev 
group by customer_id,ad_market_id) odpm 
on odpm.customer_id=ore.customer_id
and odpm.ad_market_id=ore.ad_market_id
left join (select customer_id,count(1) from order_data_prev 
group by customer_id) odpc
on odpc.customer_id=ore.customer_id
left join subscription_dimension ns on ore.product_subscription_id=ns.subscription_id;

