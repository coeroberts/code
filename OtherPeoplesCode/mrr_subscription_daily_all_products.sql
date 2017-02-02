set hive.exec.compress.intermediate=true;
set hive.exec.compress.output=true;
set mapred.output.compression.type=BLOCK;
set mapred.output.compression.codec=org.apache.hadoop.io.compress.SnappyCodec;
set hive.parquet.compression=SNAPPY;

set hive.exec.dynamic.partition=true;
set hive.exec.dynamic.partition.mode=nonstrict;
set hive.exec.max.dynamic.partitions = 10000;
set hive.exec.max.dynamic.partitions.pernode=10000;
set hive.support.quoted.identifiers=none;

use ${dmDatabase};

CREATE EXTERNAL TABLE IF NOT EXISTS mrr_subscription_daily_all_products
(
subscription_id int,
customer_id int,
product_line_id int,
revenue decimal(20,2),
mrr_actual decimal(20,2),
mrr decimal(20,2),
expired_date string,
expired_reason string,
block_conversion_date string,
refund_current_month_flag string,
payment_failure_flag string,
promo_flag string
) partitioned by(etl_load_date string)
STORED as PARQUET;


-- For historical processing or reprocessing previous month data refer to historical_subscription_price_dimension table
with order_revenue_ad as
(
select olaf.yearmonth,product_subscription_id,ad_market_id,customer_id,product_line_id,(case when order_line_cancelled_date='-1' then null else order_line_cancelled_date end) as cancelled_date,
sum(case when order_line_payment_date = '-1' then 0 else order_line_net_price_amount_usd end) as revenue,count(ad_id) as count_ad_id,sum(order_line_cancelled_price_amount_usd) as cancelled_amount,
max(case when order_line_payment_date = '-1' then 'Y' else 'N' end) as payment_failure_flag,
max(order_line_payment_date) as order_line_payment_date,
max(case when promo_id <> -1 then 'Y' else null end) as promo_flag
from order_line_accumulation_fact olaf left join order_line_ad_market_fact olamf
on olaf.order_line_number=olamf.order_line_number
where olaf.yearmonth=cast(concat(year(date_sub(current_date,1)), lpad(month(date_sub(current_date, 1)),2,0)) as int)
group by olaf.yearmonth,product_subscription_id,ad_market_id,customer_id,product_line_id,order_line_cancelled_date
),
subscription_price as
(
select distinct subscription_id,mrr from (
select subscription_id,round(cast(unit_price as double)*block_count/100,2) mrr,
rank() over(partition by subscription_id order by start_datetime desc, source_system_update_datetime desc) seq
from subscription_price_dimension
where to_date(source_system_update_datetime) <= date_sub(current_date, 1)
and (to_date(deleted_datetime) is null or to_date(deleted_datetime) > date_sub(current_date,1))
) as spd_curr
where seq=1
),
block_date as 
(
select ad_market_id,min(pricing_date) as pricing_date
from block_price_history
where to_date(pricing_date) <=date_sub(current_date, 1)
group by ad_market_id
)
INSERT OVERWRITE TABLE mrr_subscription_daily_all_products partition (etl_load_date)
select ore.product_subscription_id as subscription_id,
ore.customer_id,
ore.product_line_id,
ore.revenue,
coalesce(sp.mrr,0) as mrr_actual,
case when ((concat(year(ore.cancelled_date),lpad(month(ore.cancelled_date),2,0))=ore.yearmonth) OR (concat(year(to_date(ns.expire_datetime)),lpad(month(to_date(ns.expire_datetime)),2,0))=ore.yearmonth) OR ((concat(year(to_date(ns.expire_datetime)),lpad(month(to_date(ns.expire_datetime)),2,0))=ore.yearmonth) and lower(ns.expired_reason)='failed cc' and ore.revenue=0)) then 0 else coalesce(sp.mrr,0) end as mrr,
case when concat(year(to_date(ns.expire_datetime)),lpad(month(to_date(ns.expire_datetime)),2,0))=ore.yearmonth then to_date(ns.expire_datetime) end as expired_date,
case when concat(year(to_date(ns.expire_datetime)),lpad(month(to_date(ns.expire_datetime)),2,0))=ore.yearmonth then ns.expired_reason end as expired_reason,
pricing_date as block_conversion_date,
case when cancelled_amount =0 then 'N' else 'Y' end as refund_current_month_flag,
payment_failure_flag,
promo_flag,
date_sub(current_date,1) as etl_load_date
from order_revenue_ad ore
left join subscription_price sp on sp.subscription_id=ore.product_subscription_id
left join subscription_dimension ns on ore.product_subscription_id=ns.subscription_id
left join block_date bd on ore.ad_market_id=bd.ad_market_id;
