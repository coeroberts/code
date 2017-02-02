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

CREATE EXTERNAL TABLE IF NOT EXISTS mrr_customer_all_products
(
customer_id int,
mrr_current_advertisement decimal(20,2),
mrr_current_avvopro decimal(20,2),
mrr_current_ignite decimal(20,2),
mrr_current_website decimal(20,2),
mrr_current_adplacement decimal(20,2),
mrr_current_total decimal(20,2),
mrr_prior_advertisement decimal(20,2),
mrr_prior_avvopro decimal(20,2),
mrr_prior_ignite decimal(20,2),
mrr_prior_website decimal(20,2),
mrr_prior_adplacement decimal(20,2),
mrr_prior_total decimal(20,2),
revenue_current_advertisement decimal(20,2),
revenue_current_avvopro decimal(20,2),
revenue_current_ignite decimal(20,2),
revenue_current_website decimal(20,2),
revenue_current_misc decimal(20,2),
revenue_current_adplacement decimal(20,2),
revenue_current_total decimal(20,2),
revenue_prior_advertisement decimal(20,2),
revenue_prior_avvopro decimal(20,2),
revenue_prior_ignite decimal(20,2),
revenue_prior_website decimal(20,2),
revenue_prior_misc decimal(20,2),
revenue_prior_adplacement decimal(20,2),
revenue_prior_total decimal(20,2),
expired_date string,
expired_reason string,
block_conversion_flag string,
customer_billed_prior_month string,
customer_billed_current_month string,
customer_exists_prior_month string,
ad_current_count int,
ad_prior_count int,
refund_current_month_flag string,
customer_last_billed_date string,
promo_flag string
) partitioned by(yearmonth int)
STORED as PARQUET;

with product_data_ad as
(
select customer_id,sum(revenue) as ad_revenue, sum(mrr) as ad_mrr
from mrr_subscription_all_products
where yearmonth=cast(concat(year(add_months(current_date, -1)), lpad(month(add_months(current_date, -1)),2,0)) as int)
and product_line_id in (2,7)
group by customer_id
),
product_data_ad_prior as
(
select customer_id,sum(revenue) as ad_revenue_prior, sum(mrr) as ad_mrr_prior
from mrr_subscription_all_products
where yearmonth=cast(concat(year(add_months(current_date, -2)), lpad(month(add_months(current_date, -2)),2,0)) as int)
and product_line_id in (2,7)
group by customer_id
),
product_data_other as
(
select customer_id,
max(case when product_line_id =4 then mrr else 0 end) as mrr_current_avvopro,
max(case when product_line_id =10 then mrr else 0 end) as mrr_current_ignite,
max(case when product_line_id =15 then mrr else 0 end) as mrr_current_website,
max(case when product_line_id =18 then mrr else 0 end) as mrr_current_adplacement,
max(case when product_line_id =4 then  revenue else 0 end) as revenue_current_avvopro,
max(case when product_line_id =10 then  revenue else 0 end) as revenue_current_ignite,
max(case when product_line_id =15 then  revenue else 0 end )as revenue_current_website,
max(case when product_line_id =18 then  revenue else 0 end )as revenue_current_adplacement
from
(
select customer_id, product_line_id, sum(revenue) as revenue, sum(mrr) as mrr
from mrr_subscription_all_products
where yearmonth=cast(concat(year(add_months(current_date, -1)), lpad(month(add_months(current_date, -1)),2,0)) as int)
and product_line_id not in (2,7,-1)
group by customer_id,product_line_id) as a
group by customer_id
),
product_data_other_prior as
(
select customer_id,
max(case when product_line_id =4 then  mrr_prior else 0 end) as mrr_prior_avvopro,
max(case when product_line_id =10 then  mrr_prior else 0 end)as mrr_prior_ignite,
max(case when product_line_id =15 then  mrr_prior else 0 end)as mrr_prior_website,
max(case when product_line_id =18 then  mrr_prior else 0 end)as mrr_prior_adplacement,
max(case when product_line_id =4 then  revenue_prior else 0 end) as revenue_prior_avvopro,
max(case when product_line_id =10 then  revenue_prior else 0 end) as revenue_prior_ignite,
max(case when product_line_id =15 then  revenue_prior else 0 end) as revenue_prior_website,
max(case when product_line_id =18 then  revenue_prior else 0 end) as revenue_prior_adplacement
from (
select customer_id, product_line_id, sum(revenue) as revenue_prior, sum(mrr) as mrr_prior
from mrr_subscription_all_products
where yearmonth=cast(concat(year(add_months(current_date, -2)), lpad(month(add_months(current_date, -2)),2,0)) as int)
and product_line_id not in (2,7,-1)
group by customer_id,product_line_id) as a
group by customer_id
),
misc_data as
(
select customer_id,sum(revenue) as misc_revenue
from mrr_subscription_all_products
where yearmonth=cast(concat(year(add_months(current_date, -1)), lpad(month(add_months(current_date, -1)),2,0)) as int)
and subscription_id=-1
and product_line_id=-1
group by customer_id
),
misc_data_prior as
(
select customer_id,sum(revenue) as misc_revenue_prior
from mrr_subscription_all_products
where yearmonth=cast(concat(year(add_months(current_date, -2)), lpad(month(add_months(current_date, -2)),2,0)) as int)
and subscription_id=-1
and product_line_id=-1
group by customer_id
),
exp_data as 
(
select customer_id, max(expired_date) as expired_date, concat_ws('|',collect_set( expired_reason)) as expired_reason, count(ad_current_count) as ad_current_count, 
count(ad_prior_count) as ad_prior_count,max(block_conversion_date) as block_conversion_date, max(refund_current_month_flag) as refund_current_month_flag,
max(promo_flag) as promo_flag
from mrr_subscription_all_products
where yearmonth=cast(concat(year(add_months(current_date, -1)), lpad(month(add_months(current_date, -1)),2,0)) as int)
group by customer_id
),
customer_exists_prior as
(
select customer_id,
max(last_billed_date) as last_billed_date
from customer_professional_purchase_map
where yearmonth=cast(concat(year(add_months(current_date, -2)), lpad(month(add_months(current_date, -2)),2,0)) as int)
group by customer_id
),
final_data as 
(
select 
cd.customer_id,
coalesce(ad_mrr,0) as mrr_current_advertisement,
coalesce(mrr_current_avvopro,0) as mrr_current_avvopro,
coalesce(mrr_current_ignite,0) as mrr_current_ignite,
coalesce(mrr_current_website,0) as mrr_current_website,
coalesce(mrr_current_adplacement,0) as mrr_current_adplacement,
coalesce(ad_mrr_prior,0) as mrr_prior_advertisement,
coalesce(mrr_prior_avvopro,0) as mrr_prior_avvopro,
coalesce(mrr_prior_ignite,0) as mrr_prior_ignite,
coalesce(mrr_prior_website,0) as mrr_prior_website,
coalesce(mrr_prior_adplacement,0) as mrr_prior_adplacement,
coalesce(ad_revenue,0) as revenue_current_advertisement,
coalesce(revenue_current_avvopro,0) as revenue_current_avvopro,
coalesce(revenue_current_ignite,0) as revenue_current_ignite,
coalesce(revenue_current_website,0) as revenue_current_website,
coalesce(misc_revenue,0) as revenue_current_misc,
coalesce(revenue_current_adplacement,0) as revenue_current_adplacement,
coalesce(ad_revenue_prior,0) as revenue_prior_advertisement,
coalesce(revenue_prior_avvopro,0) as revenue_prior_avvopro,
coalesce(revenue_prior_ignite,0) as revenue_prior_ignite,
coalesce(revenue_prior_website,0) as revenue_prior_website,
coalesce(misc_revenue_prior,0) as revenue_prior_misc,
coalesce(revenue_prior_adplacement,0) as revenue_prior_adplacement,
expired_date,
expired_reason,
case when cast(concat(year(block_conversion_date),lpad(month(block_conversion_date),2,0)) as int)= cast(concat(year(add_months(current_date, -1)), lpad(month(add_months(current_date, -1)),2,0)) as int) then 'Yes' else 'No' end as block_conversion_flag,
case when ed.customer_id is null then 'N' else 'Y' end as customer_billed_current_month,
case when (cep.customer_id is not null and cast(concat(year(last_billed_date),lpad(month(last_billed_date),2,0)) as int)= cast(concat(year(add_months(current_date, -2)), lpad(month(add_months(current_date, -2)),2,0)) as int))
then 'Y' else 'N' end as customer_billed_prior_month,
case when (cep.customer_id is not null and cast(concat(year(last_billed_date),lpad(month(last_billed_date),2,0)) as int) < cast(concat(year(add_months(current_date, -1)), lpad(month(add_months(current_date, -1)),2,0)) as int)) then 'Y' else 'N' end as customer_exists_prior_month,
coalesce(ad_current_count,0) as ad_current_count,
coalesce(ad_prior_count,0) as ad_prior_count,
coalesce(refund_current_month_flag,'N') as refund_current_month_flag,
cep.last_billed_date as customer_last_billed_date,
promo_flag,
cast(concat(year(add_months(current_date, -1)), lpad(month(add_months(current_date, -1)),2,0)) as int) as yearmonth
from customer_dimension cd
join ${srcDatabase}.nrt_customer nc
on cd.customer_id=nc.id
and to_date(created_at) <= last_day(add_months(current_date, -1))
left join product_data_ad pda
on cd.customer_id=pda.customer_id
left join product_data_ad_prior pdap
on cd.customer_id=pdap.customer_id
left join product_data_other pdo
on cd.customer_id=pdo.customer_id
left join product_data_other_prior pdop
on cd.customer_id=pdop.customer_id
left join misc_data md
on cd.customer_id=md.customer_id
left join misc_data_prior mdp
on cd.customer_id=mdp.customer_id
left join exp_data ed
on cd.customer_id=ed.customer_id
left join customer_exists_prior cep on cep.customer_id=cd.customer_id
)
INSERT OVERWRITE TABLE mrr_customer_all_products partition (yearmonth)
select
customer_id,
mrr_current_advertisement,
mrr_current_avvopro,
mrr_current_ignite,
mrr_current_website,
mrr_current_adplacement,
(mrr_current_advertisement+mrr_current_avvopro+mrr_current_ignite+mrr_current_website+mrr_current_adplacement) as mrr_current_total,
mrr_prior_advertisement,
mrr_prior_avvopro,
mrr_prior_ignite,
mrr_prior_website,
mrr_prior_adplacement,
(mrr_prior_advertisement+mrr_prior_avvopro+mrr_prior_ignite+mrr_prior_website+mrr_prior_adplacement) as mrr_prior_total,
revenue_current_advertisement,
revenue_current_avvopro,
revenue_current_ignite,
revenue_current_website,
revenue_current_misc,
revenue_current_adplacement,
(revenue_current_advertisement+revenue_current_avvopro+revenue_current_ignite+revenue_current_website+revenue_current_misc+revenue_current_adplacement) as revenue_current_total,
revenue_prior_advertisement,
revenue_prior_avvopro,
revenue_prior_ignite,
revenue_prior_website,
revenue_prior_misc,
revenue_prior_adplacement,
(revenue_prior_advertisement+revenue_prior_avvopro+revenue_prior_ignite+revenue_prior_website+revenue_prior_misc+revenue_prior_adplacement) as revenue_prior_total,
expired_date,
expired_reason,
block_conversion_flag,
customer_billed_prior_month,
customer_billed_current_month,
customer_exists_prior_month,
ad_current_count,
ad_prior_count,
refund_current_month_flag,
customer_last_billed_date,
promo_flag,
yearmonth
from final_data;