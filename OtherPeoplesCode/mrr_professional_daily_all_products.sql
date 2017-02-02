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

CREATE EXTERNAL TABLE IF NOT EXISTS mrr_professional_daily_all_products
(
professional_id int,
subscription_id int,
customer_id int,
product_line_id int,
ad_id int,
ad_type string,
market_type string,
revenue_mtd decimal(20,2),
revenue_prior_month decimal(20,2),
ad_revenue_mtd decimal(20,2),
ad_revenue_prior_month decimal(20,2),
mrr_ad decimal(20,2),
mrr_ad_prior_month decimal(20,2),
mrr_block_ad decimal(20,2),
mrr decimal(20,2),
mrr_prior_month decimal(20,2),
ad_mrr_on_promotion decimal(20,2),
promo_flag string,
is_active string
) partitioned by(etl_load_date string)
STORED as PARQUET;

-- For professional data
with professional_data as
(select distinct professional_id, olamf.ad_market_id, amd.ad_market_block_flag
,case when ad_market_block_flag='Y' then 'Block' else 'Exclusive' end as market_type
from order_line_ad_market_fact olamf
join ad_market_dimension amd
on olamf.ad_market_id=amd.ad_market_id
where amd.ad_market_id <> -1
and professional_id <> -1
),
subscription_data as
(
select
msdp.subscription_id,
msdp.customer_id,
msdp.product_line_id,
revenue as revenue_mtd,
revenue_prior_month,
mrr,
mrr_prior_month,
case when ad_type in ('SponsoredListingAd','DisplayAd') then mrr else 0 end as mrr_ad,
-- case when expired_date>etl_load_date and (ad_type in ('SponsoredListingAd','DisplayAd') or mrr>0) then 'Y' else 'N' end as is_active,
case when ad_type in ('SponsoredListingAd','DisplayAd') or mrr>0 then 'Y' else 'N' end as is_active,
promo_flag,
ad_id,
ad_type,
case when promo_flag='Y' then mrr else 0 end as ad_mrr_on_promotion
from mrr_subscription_daily_all_products msdp
left join subscription_dimension sd
on msdp.subscription_id=sd.subscription_id
and msdp.customer_id=sd.customer_id
left join (select subscription_id, customer_id, product_line_id , max(revenue) as revenue_prior_month, max(mrr) as mrr_prior_month
			 from mrr_subscription_daily_all_products
			 where etl_load_date=date_sub(from_unixtime(unix_timestamp(), 'yyyy-MM-dd'),31)
			 -- date_add(from_unixtime(unix_timestamp(), 'yyyy-MM-dd'), -1-cast(from_unixtime(unix_timestamp(), 'd') as int))
			 group by subscription_id, customer_id, product_line_id )mspm on 
msdp.subscription_id=mspm.subscription_id
and msdp.customer_id=mspm.customer_id
and msdp.product_line_id=mspm.product_line_id
where etl_load_date=date_sub(current_date,1)
),
order_revenue_ad as
(
select olaf.yearmonth,olaf.professional_id,product_subscription_id,ad_market_id,customer_id,product_line_id,
sum(case when order_line_payment_date = '-1' then 0 else order_line_net_price_amount_usd end) as ad_revenue_mtd
from order_line_accumulation_fact olaf left join order_line_ad_market_fact olamf
on olaf.order_line_number=olamf.order_line_number
where olaf.yearmonth=cast(concat(year(date_sub(current_date,1)), lpad(month(date_sub(current_date, 1)),2,0)) as int)
and product_line_id in (2,7,18)
group by olaf.yearmonth,product_subscription_id,ad_market_id,customer_id,product_line_id,olaf.professional_id
)
INSERT OVERWRITE TABLE mrr_professional_daily_all_products partition (etl_load_date)
select distinct
ore.professional_id,
ore.product_subscription_id as subscription_id,
ore.customer_id,
ore.product_line_id,
sd.ad_id,
sd.ad_type,
pd.market_type,
sd.revenue_mtd,
sd.revenue_prior_month,
ore.ad_revenue_mtd,
mpdp.ad_revenue_prior_month,
sd.mrr_ad,
mpdp.mrr_ad_prior_month,
case when market_type='Block' then mrr else 0 end as mrr_block_ad,
sd.mrr,
sd.mrr_prior_month,
sd.ad_mrr_on_promotion,
sd.promo_flag,
sd.is_active,
date_sub(current_date,1) as etl_load_date
from order_revenue_ad ore
left join professional_data pd on ore.professional_id=pd.professional_id
left join subscription_data sd on sd.subscription_id=ore.product_subscription_id
left join (select subscription_id, professional_id, customer_id, product_line_id, max(ad_revenue_mtd) as ad_revenue_prior_month, max(mrr_ad) as mrr_ad_prior_month
from mrr_professional_daily_all_products
where etl_load_date=date_sub(from_unixtime(unix_timestamp(), 'yyyy-MM-dd'),31)
group by subscription_id,customer_id,product_line_id,professional_id ) mpdp
on ore.professional_id=mpdp.professional_id;