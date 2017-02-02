How much unsold inventory is < $1 price or low-value practice areas?

subscription_pricing for inventory.
Exclusive and block
Order table says what''s sold
Existing report: AMM - Market Intelligence Report
Ad Market Size tab
DA price and SL price
Don''t run the full query because too big.
This shows a snapshot which is what I want.

----

Revenue

How constrained is inventory?
How viable is the unsold amount?

< $1
the rest, top 10 of rest or 20

April
Exclusive, display, block
< $1, <= 250, > 250
 market + pa combo
of > 250, top 15 practice areas (lumped together)
and then all other.
should total 11M
For metrics, want to see unsold $ value.  nice to have sold too.
----
eMonetization, eSellThrough, ad revenue, ad sold value, ad unsold value, ad value (this is essentially value of the market)

ad_type (Sponsored Listing / Display Ad)
ad_inventory_type (Exclusive / Block)

<= $1 Markets (will be exclusive only, and calc as ad_value / 3)
<= $250
 > $250

ad_value, ad_sold_value, ad_unsold_value
monetization = ad_revenue / ad_value = what & of the potential are we collecting (net of discounts and presumably proration)
sell_through = ad_sold_value / ad_value = what % of the potential have we sold?

OK so first just dup the thing I downloaded, but at the market level (this is rolled up)

From Charlie: Yes, the list_price in the inventory table is per unit. 
The revenue potential should always be sellable_count * list_price.  
On exclusive markets, the sellable count is 3 for sponsored listings.
Display ads behave the same as sponsored listings, but they typically 
only have 1 sellable count


Relevant part of the ad_market_detail data source query.
OK I would really like it to have DA and SL as an attribute rather than splitting out the metrics.
Eh forget it.  Maybe wrap in another query if it really needs to be that way.  Too messy to change the guts.
Or keep them separate.

create table tmp_data_dm.coe_ad_market_detail_2016_08_25 as
-- ad_inventory: by month and market id, which are exclusive vs. block, what the inventory is, and what the price is for DA and SL
with ad_inventory as
(
  -- prior to 2016, both exclusive and block markets could be found in ad_pricing_snapshot_fact
               select md.year_month 
                              , adp.AD_MKT_ID
                              , case when block.AD_MKT_KEY is NULL then 'Exclusive' else 'Block' end as sl_inventory_type
                              , case when block.AD_MKT_KEY is NULL then 3 else block.sl_block_inventory end as sl_inventory
                              , case when block.AD_MKT_KEY is NULL then adp.PKG_PRICE_AMT_USD else block.sl_block_price end as sl_price
                              , adp.PKG_PRICE_AMT_USD as sl_subscription_price
                              , 'Exclusive' as da_inventory_type
                              , 1 as da_inventory 
                              , adp.PKG_PRICE_AMT_USD as da_price
               from dm.ad_pricing_snapshot_fact adp
               join DM.month_dim md on md.MONTH_KEY = adp.PRICNG_MONTH_KEY and md.year_month >= (extract(year from now()-interval 4 months))*100 +extract(month from now() - interval 4 months) 
  and md.year_month <= (extract(year from now())*100)+extract(month from now())
               join dm.ad_market_dimension adm on adm.ad_market_id = adp.AD_MKT_ID
               left join
               (
                              select *
                              from
                              (
                                             select md.year_month
                                                            , apfb.AD_MKT_KEY 
                                                            , apfb.ROW_EFF_BEGIN_DATE
                                                            , apfb.ROW_EFF_END_DATE
                                                            , apfb.SELLBL_CNT as sl_block_inventory
                                                            , PKG_PRICE_AMT_USD as sl_block_price
                                                            , ROW_NUMBER() OVER(partition by md.MONTH_KEY, apfb.AD_MKT_KEY order by apfb.ROW_EFF_END_DATE desc) rt
                                             from DM.MONTH_DIM md
                                             join DM.V_AD_PRICING_FACT_BLOCK apfb on md.MONTH_BEGIN_DATE < apfb.ROW_EFF_END_DATE and md.MONTH_END_DATE >= apfb.ROW_EFF_BEGIN_DATE
                                             where md.year_month >= (extract(year from now()-interval 4 months))*100 +extract(month from now() - interval 4 months) 
          and md.year_month <= (extract(year from now())*100)+extract(month from now())
                              ) a
                              where a.rt = 1
               ) block on block.year_month = md.year_month and block.AD_MKT_KEY = adp.AD_MKT_KEY
               where adm.ad_market_active_flag = 'Y' and md.year_month <= 201512
  
  union

 -- starting in 2016, need to use src.hist_nrt_ad_inventory.
  -- can't use block_price_history because we're looking at both block and exclusive
  -- can't use nrt_ad_inventory because we need past months
  
select t3.year_month, t3.ad_market_id, t3.sl_inventory_type, sum(t3.sl_inventory) sl_inventory, sum(t3.sl_price) sl_price, sum(t3.sl_subscription_price) sl_subscription_price,
  t3.da_inventory_type, sum(t3.da_inventory) da_inventory, sum(t3.da_price) da_price
from
(select t2.year_month, t2.ad_market_id,
  case when t2.insertion_ad = 1 then 'Exclusive' else 'Block' end sl_inventory_type,
  case when t2.insertion_ad = 1 and t2.ad_inventory_type = 'Sponsored Listing' then 3 when t2.insertion_ad = 0 and t2.ad_inventory_type = 'Sponsored Listing'
     then t2.sellable_count else 0 end sl_inventory,
  case when t2.ad_inventory_type = 'Sponsored Listing' then t2.list_price/100 else 0 end sl_price,
  case when t2.ad_inventory_type = 'Sponsored Listing' then t2.list_price/100 else 0 end sl_subscription_price,
  case when t2.insertion_ad = 1 then 'Exclusive' else 'Block' end da_inventory_type,
  case when t2.insertion_ad = 1 and t2.ad_inventory_type = 'Display' then 1 when t2.insertion_ad = 0 and t2.ad_inventory_type = 'Display'
    then t2.sellable_count else 0 end da_inventory,
  case when t2.ad_inventory_type = 'Display' then t2.list_price/100 else 0 end da_price
from
(select distinct amd.ad_market_id, t.year_month, h.ad_inventory_type, h.insertion_ad, h.list_price, h.sellable_count
from src.hist_nrt_ad_inventory h
join (
select year_month, ad_inventory_type, sales_region_id, specialty_id, max(max_update) mdate
from (
select md.year_month, hai.ad_inventory_type, hai.sales_region_id, hai.specialty_id, hai.max_update
from dm.month_dim md
  join (select ad_inventory_type, sales_region_id, specialty_id, extract(month from updated_at) month, extract(year from updated_at) year, max(updated_at) max_update
  from src.hist_nrt_ad_inventory
  group by 1, 2, 3, 4, 5) hai on hai.max_update <= md.month_end_date
  where md.year_month >= (extract(year from now()-interval 2 years))*100 +extract(month from now())
  and md.year_month <= (extract(year from now()))*100 +extract(month from now()) ) mu
group by 1,2,3,4
) t on t.ad_inventory_type = h.ad_inventory_type and t.sales_region_id = h.sales_region_id and t.specialty_id = h.specialty_id and t.mdate = h.updated_at
join dm.ad_market_dimension amd on amd.ad_region_id = h.sales_region_id and amd.specialty_id = h.specialty_id
where amd.ad_market_active_flag = 'Y'
)t2
where t2.year_month >= 201601
) t3
group by t3.year_month, t3.ad_market_id, t3.sl_inventory_type, t3.da_inventory_type
)

-- ad_revenue: by month and market id, what is the sold revenue and inventory for DA and SL
, ad_revenue as
(
select dto.YEAR_MONTH
     , coalesce(admkt.ad_market_id, 0) ad_mkt_id
     , SUM(case when pln.PRODUCT_LINE_ITEM_NAME = 'Sponsored Listing' and -- olaf.order_line_indicator_id  in (1,2,3) /*purchased*/ and
           olaf.BLOCK_COUNT = 0 and (dc.month_end_ind = 'Month End Date' or dc.month_end_ind is null) then 1
                                  when pln.PRODUCT_LINE_ITEM_NAME = 'Sponsored Listing' and -- olaf.order_line_indicator_id in (1,2,3) and 
           olaf.BLOCK_COUNT > 0 and (dc.month_end_ind = 'Month End Date' or dc.month_end_ind is null) then olaf.BLOCK_COUNT 
                                  else 0 end) as sl_sold_inventory
     , SUM(case when pln.PRODUCT_LINE_ITEM_NAME = 'Sponsored Listing' then olaf.order_line_net_price_amount_usd else 0 end) as sl_revenue
     , SUM(case when pln.PRODUCT_LINE_ITEM_NAME = 'Display Medium Rectangle' and -- olaf.order_line_indicator_id in (1,2,3) and 
           olaf.block_count = 0 and (dc.month_end_ind = 'Month End Date' or dc.month_end_ind is null) then 1
           when pln.PRODUCT_LINE_ITEM_NAME = 'Display Medium Rectangle' and -- olaf.order_line_indicator_id in (1,2,3) and 
           olaf.block_count > 0 and (dc.month_end_ind = 'Month End Date' or dc.month_end_ind is null) then olaf.block_count 
           else 0 end) as da_sold_inventory
     , SUM(case when pln.PRODUCT_LINE_ITEM_NAME = 'Display Medium Rectangle' then olaf.order_line_net_price_amount_usd else 0 end) as da_revenue
  from DM.order_line_accumulation_fact  olaf    
  join DM.DATE_DIM dto on dto.actual_date = olaf.ORDER_LINE_BEGIN_DATE
  left join dm.date_dim dc on dc.actual_date = olaf.order_line_cancelled_date
-- dc.month_end_ind = 'Month End Date' or dc.month_end_ind is null above means either there is no cancelled date (-1) or order was canceled on the month end date
  left join DM.product_line_dimension  pln on pln.product_line_id = olaf.product_line_id
  left join DM.order_line_ad_market_fact  oladmkt on oladmkt.order_line_number  = olaf.order_line_number
  left join DM.ad_market_dimension  admkt on admkt.ad_market_id = oladmkt.ad_market_id 
 where dto.YEAR_MONTH >=  (extract(year from now()-interval 4 months))*100 +extract(month from now() - interval 4 months)
                -- and olaf.order_line_payment_date  <> '-1' -- orders that do not have payment
                and pln.product_line_item_name  in ('Sponsored Listing', 'Display Medium Rectangle')
  group by 1,2
)

-- temp1: combines market and specialty dimensions with above ad_revenue and ad_inventory
-- calculates value and sold_value for SL and DA separately
, temp1 as (
SELECT md.year_month
          ,adm.ad_market_id
          ,admm.ad_mkt_key
              ,lower(adm.ad_market_state_name) AS STATE
              ,lower(adm.ad_market_county_name) AS county
              ,lower(adm.ad_market_region_name) AS ad_region
              ,sp.parent_specialty_name AS parent_sp
              ,adm.ad_market_specialty_name AS specialty
              ,CASE 
                             WHEN adm.ad_market_block_flag = 'Y'
                                            THEN 'Block'
                             ELSE 'Exclusive'
                             END AS market_type
              -- Sponsored Listing
              ,ai.sl_inventory_type
              ,ai.sl_inventory
              ,ai.sl_price
              ,ai.sl_subscription_price
              ,ai.sl_inventory * ai.sl_price AS sl_value
              ,coalesce(ar.sl_sold_inventory, 0) AS sl_sold_inventory
              ,coalesce(ar.sl_sold_inventory, 0) * ai.sl_price AS sl_sold_value
              ,coalesce(ar.sl_revenue, 0) AS sl_revenue
              -- Display Ad
              ,ai.da_inventory_type
              ,ai.da_inventory
              ,ai.da_price
              ,ai.da_inventory * ai.da_price AS da_value
              ,coalesce(ar.da_sold_inventory, 0) AS da_sold_inventory
              --                          , ai.da_inventory - coalesce(ar.da_sold_inventory, 0) as da_unsold_inventory
              ,coalesce(ar.da_sold_inventory, 0) * ai.da_price AS da_sold_value
              ,coalesce(ar.da_revenue, 0) AS da_revenue
              -- Total Ad
              ,coalesce(ar.sl_revenue, 0) + coalesce(ar.da_revenue, 0) AS ad_revenue
FROM DM.ad_market_dimension adm
INNER JOIN DM.specialty_dimension sp ON sp.specialty_id = adm.specialty_id
-- INNER JOIN DM.MONTH_DIM md ON md.year_month = 201605
--               AND md.year_month <= (extract(year FROM now()) * 100) + extract(month FROM now())
INNER JOIN DM.MONTH_DIM md ON md.year_month <= (extract(year FROM now()) * 100) + extract(month FROM now())
LEFT JOIN ad_inventory ai ON ai.AD_MKT_ID = adm.AD_MarkeT_ID
              AND ai.year_month = md.year_month
LEFT JOIN ad_revenue ar ON ar.AD_MKT_ID = adm.AD_MarkeT_ID
              AND ar.year_month = md.year_month
LEFT JOIN DM.ad_mkt_dim admm on adm.ad_market_id = admm.ad_mkt_id
                     WHERE adm.ad_market_active_flag = 'Y'
                                    AND sp.specialty_id >= 1
                                    AND sp.specialty_id <= 131
                                    )

-- temp2: includes everything from temp1
-- then calculates unsold_inventory and _value, revenue_opportunity, and monetization for SL and DA separately
,temp2 as (
select temp1.*
   ,sl_inventory - coalesce(sl_sold_inventory, 0) AS sl_unsold_inventory
   ,(sl_inventory - coalesce(sl_sold_inventory, 0)) * sl_price AS sl_unsold_value
   ,sl_sold_value / sl_value AS sl_sell_through
   ,sl_value - coalesce(sl_revenue, 0) AS sl_revenue_opportunity
   ,coalesce(sl_revenue, 0) / sl_value AS sl_monetization
   ,CASE 
                  WHEN (coalesce(sl_revenue, 0) / sl_value) >= 0.8
                                 THEN 'High'
                  WHEN (coalesce(sl_revenue, 0) / sl_value) >= 0.5
                                 THEN 'Medium'
                  ELSE 'Low'
                  END AS sl_monetization_status
   ,da_inventory - coalesce(da_sold_inventory, 0) AS da_unsold_inventory
   ,(da_inventory - coalesce(da_sold_inventory, 0)) * da_price AS da_unsold_value
   ,da_sold_value / da_value AS da_sell_through
   ,da_value - coalesce(da_revenue, 0) AS da_revenue_opportunity
   ,coalesce(da_revenue, 0) / da_value AS da_monetization
   ,CASE 
                  WHEN (coalesce(da_revenue, 0) / da_value) >= 0.8
                                 THEN 'High'
                  WHEN (coalesce(da_revenue, 0) / da_value) >= 0.5
                                 THEN 'Medium'
                  ELSE 'Low'
                  END AS da_monetization_status
                              FROM temp1
                              )

-- temp3: pulls in everything from temp2 (and therefore also temp1)
-- calculates total ad values and revenue opportunity
,temp3 as (
select temp2.*
  ,sl_value + da_value AS ad_value
  ,sl_sold_value + da_sold_value AS ad_sold_value
  ,sl_unsold_value + da_unsold_value AS ad_unsold_value
  ,sl_revenue_opportunity + da_revenue_opportunity AS ad_revenue_opportunity
from temp2
)

-- ad_market_detail: includes everything in temp3
-- calculates total sell-through and monetization
-- adds monetization status and market size buckets


SELECT temp3.*
,ad_sold_value / ad_value AS ad_sell_through
,ad_revenue / ad_value AS ad_monetization
,CASE 
   WHEN (ad_revenue / ad_value) >= 0.8
                  THEN 'High'
   WHEN (ad_revenue / ad_value) >= 0.5
                  THEN 'Medium'
   ELSE 'Low'
   END AS ad_monetization_status
,CASE 
   WHEN ad_value >= 5000
                  THEN 'Huge'
   WHEN ad_value >= 1500
                  THEN 'Big'
   WHEN ad_value >= 300
                  THEN 'Medium'
   WHEN ad_value >= 25
                  THEN 'Small'
   ELSE 'Tiny'
   END AS market_size
FROM temp3

----
CREATE TABLE tmp_data_dm.coe_ad_market_detail_rows AS
SELECT
   year_month
  ,ad_market_id
  ,ad_mkt_key
  ,state
  ,county
  ,ad_region
  ,parent_sp
  ,specialty
  ,market_size
  ,'Sponsored Listing' AS      ad_type
  ,sl_inventory_type AS        ad_inventory_type
  ,sl_inventory AS             ad_inventory_units
  ,sl_price AS                 ad_price
  ,sl_subscription_price AS    ad_subscription_price
  ,sl_value AS                 ad_value
  ,sl_sold_inventory AS        ad_sold_units
  ,sl_sold_value AS            ad_sold_value
  ,sl_revenue AS               ad_revenue
  ,sl_unsold_inventory AS      ad_unsold_units
  ,sl_unsold_value AS          ad_unsold_value
  ,sl_sell_through AS          ad_sell_through
  ,sl_revenue_opportunity AS   ad_revenue_opportunity
  ,sl_monetization AS          ad_monetization
  ,sl_monetization_status AS   ad_monetization_status
FROM tmp_data_dm.coe_ad_market_detail
UNION
SELECT
   year_month
  ,ad_market_id
  ,ad_mkt_key
  ,state
  ,county
  ,ad_region
  ,parent_sp
  ,specialty
  ,market_size
  ,'Display Ad' AS             ad_type
  ,da_inventory_type AS        ad_inventory_type
  ,da_inventory AS             ad_inventory_units
  ,da_price AS                 ad_price
  ,NULL AS                     ad_subscription_price
  ,da_value AS                 ad_value
  ,da_sold_inventory AS        ad_sold_units
  ,da_sold_value AS            ad_sold_value
  ,da_revenue AS               ad_revenue
  ,da_unsold_inventory AS      ad_unsold_units
  ,da_unsold_value AS          ad_unsold_value
  ,da_sell_through AS          ad_sell_through
  ,da_revenue_opportunity AS   ad_revenue_opportunity
  ,da_monetization AS          ad_monetization
  ,da_monetization_status AS   ad_monetization_status
FROM tmp_data_dm.coe_ad_market_detail

Look at diff between sell-through and monetization
Figure out $ breakpoint on Ad Sold Value
Aiming for least number of groups that give us the amount of inventory and revenue.
Lot of inventory and not a lot of revenue.
Low monetization; small size; as a proxy for 'Sahara'.
'topography'

Get same data for April 2015.

SELECT
   year_month
  ,SUM(ad_inventory_units) AS  ad_inventory_units
  ,SUM(ad_value) AS            ad_value
  ,SUM(ad_sold_value) AS       ad_sold_value
  ,SUM(ad_revenue) AS          ad_revenue
FROM tmp_data_dm.coe_ad_market_detail_rows
WHERE year_month >= 201602
GROUP BY 1 ORDER BY 1

