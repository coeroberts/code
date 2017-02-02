select
   msap.subscription_id
  ,msap.customer_id
  ,msap.revenue
  ,msap.mrr
  ,msap.mrr - msap.revenue as MRR_Variance
  ,msap.expired_date
  ,msap.promo_flag
  ,msap.yearmonth
  ,msap.block_conversion_date
  ,ms.subscription_billed_prior_month
  ,ms.market_billed_prior_month
  ,ms.customer_billed_prior_month 
  ,ms.cancelled_date
  ,ms.market_id
  ,mi.market_type 
  ,mi.sl_price
  ,round(msap.revenue / olaf.block_count) as Block_Price_Paid
  ,case when mi.market_type = 'Exclusive' then round(mi.sl_price) else round(mi.sl_price * olaf.block_count) end as 'Value of Customer Ads'
  ,case when mi.market_type = 'Exclusive' then round(mi.sl_price - msap.revenue) else round(mi.sl_price * olaf.block_count - msap.revenue) end as 'Breakage Amount'
  ,mi.ad_revenue 
  ,mi.ad_value
  ,mi.ad_sold_value 
  ,mi.ad_unsold_value 
  ,mi.ad_sell_through 
  ,mi.ad_monetization
  ,olaf.block_count
  ,olaf.order_line_purchase_date
  ,dt.year_month as purchase_month
  ,case when ms.cancelled_date <> 'NULL' then 'Cancel'
        when msap.promo_flag = 'Y' then 'Promo'
        -- when olaf.order_line_purchase_date between '2016-10-31' and '2016-12-01' then 'Prorate' 
        when msap.yearmonth = dt.year_month then 'Prorate' 
        when round(mi.sl_price) = round(msap.revenue) then 'Full Price'
        when (round(mi.sl_price) = round(msap.revenue / olaf.block_count)) then 'Full Price'
        when msap.revenue = 0 then 'Free Ad'
        when mi.market_type = 'Exclusive' and round(msap.revenue) <> round(mi.sl_price) then 'Price Change'
        when round(msap.revenue) < round(mi.sl_price) then 'Discount'
        when round(msap.revenue / olaf.block_count)<round(mi.sl_price) then 'Discount'
        when round(msap.revenue / olaf.block_count)>round(mi.sl_price) and msap.block_conversion_date <> 'NULL' then 'Price Change'
        else 'N/A' end as 'breakage_type'
from dm.mrr_subscription_all_products msap

inner join dm.order_line_accumulation_fact olaf
  on olaf.product_subscription_id = msap.subscription_id 
  and olaf.yearmonth = msap.yearmonth
inner join dm.date_dim dt
  on olaf.order_line_purchase_date = dt.actual_date

inner join 
    (
    select distinct subscription_id
      , yearmonth
      , market_id
      , subscription_billed_prior_month
      , market_billed_prior_month
      , customer_billed_prior_month 
      , cancelled_date
      
      from dm.mrr_subscription
    ) ms
  
  on ms.subscription_id = msap.subscription_id
  and ms.yearmonth = msap.yearmonth
  
inner join dm.market_intelligence_detail mi
  on ms.market_id = mi.ad_market_id
  and msap.yearmonth = mi.year_month
  and mi.market_type <> 'NULL'  -- figure this out

  where
    msap.yearmonth >= 201601
    and msap.subscription_id <> -1
    and msap.customer_id <> 6841
