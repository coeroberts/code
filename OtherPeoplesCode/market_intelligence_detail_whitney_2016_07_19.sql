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
                                  
                                   -- ! this block_count will include remnant ads - remove that flag if don't want remnant ads in sold count
                                 
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
--  and admkt.ad_market_id = 746707
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
                                             INNER JOIN DM.MONTH_DIM md ON md.year_month >= 201512
                                                            AND md.year_month <= (extract(year FROM now()) * 100) + extract(month FROM now())
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

,ad_market_detail as (
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
               )

-- the next several subqueries are used to determine claim rates, counts, and value by claimed lawyer

-- lawyer_county_psp: by professional ID, what is the parent specialty and claim status
-- where at least 10% of practice is that specialty
-- also checks that lawyers are practicing, alive, not retired, etc.

, lawyer_county_psp as
(
              select *
              from
              (
                             select p.professional_id PROFNL_ID
                                           , lower(p.professional_state_name_1) as state
                                           , lower(p.professional_county_name_1) as county
                                           , case when p.professional_claim_date is null then 'not-claimed' else 'claimed' end as is_claim
                                           , case when p.professional_email_address_name is null then 'no-email' else 'has-email' end as has_email
                                           , case when p.PROFNL_PHON_NBR_1 is null then 'no-phone' else 'has-phone' end as has_phone
                                           , case when sp.PARNT_SPECLTY_NAME is null then 'Unknown' else sp.PARNT_SPECLTY_NAME end as parent_sp
                                           , SUM(pfsp.SPECLTY_PCT) as parent_sp_pct
                             from DM.professional_dimension p
                             join src.barrister_professional_status pst on pst.PROFESSIONAL_ID = p.profnl_id
                             left join DM.PROFNL_SPECLTY_BRDG pfsp on pfsp.PROFNL_KEY = p.PROFNL_KEY
                             left join DM.SPECLTY_DIM sp on sp.SPECLTY_KEY = pfsp.SPECLTY_KEY
                             where p.PROFNL_DEL_IND = 'Not Deleted'
                                           AND p.PROFNL_PRCTC_IND = 'Practicing'
                                           AND p.PROFN_NAME = 'lawyer'
                                           AND p.INDSTRY_NAME = 'Legal'
                                           AND p.PROFNL_CNTRY_NAME_1 = 'UNITED STATES'
                                           AND pst.DECEASED = 'N'
                                           AND pst.JUDGE = 'N'
                                           AND pst.RETIRED = 'N'
                                           AND pst.OFFICIAL = 'N'
                                           AND pst.UNVERIFIED = 'N'
                                           AND pst.SANCTIONED = 'N'
                                           AND (p.profnl_email_addr is null or (p.PROFNL_EMAIL_ADDR not like '%.edu%' and p.PROFNL_EMAIL_ADDR not like '%.gov'))                   
                             group by 1,2,3,4,5,6,7
              ) a
              where a.parent_sp_pct > 10
)

-- lawyer c: by county and professional id, gets count of claim and contact method status
,lawyer_c as (select lcpsp.state
                             , lcpsp.county
                             , lcpsp.profnl_id
                             , case when lcpsp.is_claim='claimed' then lcpsp.profnl_id else NULL end as lawyer_claimed_cnt
                             ,  case when lcpsp.is_claim='not-claimed' then lcpsp.profnl_id else NULL end as lawyer_unclaimed_cnt
                             ,  case when lcpsp.is_claim='claimed' then lcpsp.profnl_id else NULL end as claimed_lawyer                         
                             ,  case when lcpsp.is_claim='claimed' and lcpsp.has_phone='has-phone' then lcpsp.profnl_id else NULL end as lawyer_claimed_has_phone_cnt
                             ,  case when lcpsp.is_claim='claimed' and lcpsp.has_email='has-email' then lcpsp.profnl_id else NULL end as lawyer_claimed_has_email_cnt
                             ,  case when lcpsp.is_claim='not-claimed' and lcpsp.has_phone='has-phone' then lcpsp.profnl_id else NULL end as lawyer_unclaimed_has_phone_cnt
                             ,  case when lcpsp.is_claim='not-claimed' and lcpsp.has_email='has-email' then lcpsp.profnl_id else NULL end as lawyer_unclaimed_has_email_cnt
              from lawyer_county_psp lcpsp)
    
-- using lawyer_c above, claims and contact methods summed by county
, lawyer_county_cnt as

  (select c1.state
  ,c1.county
  ,c1.lawyer_cnt
  ,c2.lawyer_claimed_cnt as lawyer_claimed_cnt
  ,c3.lawyer_unclaimed_cnt as lawyer_unclaimed_cnt
  ,c4.claimed_lawyer/cast(c1.lawyer_cnt as double) as claim_rate
  ,c5.lawyer_claimed_has_phone_cnt
  ,c6.lawyer_claimed_has_email_cnt
  ,c7.lawyer_unclaimed_has_phone_cnt
  ,c8.lawyer_unclaimed_has_email_cnt

  from
  (select b.state
  ,b.county

  ,count(distinct b.profnl_id) as lawyer_cnt      
  from lawyer_c b
  group by state,county) c1
   
         join (select b.state
  ,b.county
  ,count(distinct b.lawyer_claimed_cnt) as lawyer_claimed_cnt      
  from lawyer_c b
  group by state,county) c2 on c1.state=c2.state and c1.county=c2.county

         join (select b.state
  ,b.county
  ,count(distinct b.lawyer_unclaimed_cnt) as lawyer_unclaimed_cnt       
  from lawyer_c b
  group by state,county) c3 on c1.state=c3.state and c1.county=c3.county

         join (select b.state
  ,b.county
  ,cast(count(distinct b.claimed_lawyer) as double) as claimed_lawyer      
  from lawyer_c b
  group by state,county) c4 on c1.state=c4.state and c1.county=c4.county

         join (select b.state
  ,b.county
  ,count(distinct b.lawyer_claimed_has_phone_cnt) as lawyer_claimed_has_phone_cnt      
  from lawyer_c b
  group by state,county) c5 on c1.state=c5.state and c1.county=c5.county
  
                 join (select b.state
  ,b.county
  ,count(distinct b.lawyer_claimed_has_email_cnt) as lawyer_claimed_has_email_cnt     
  from lawyer_c b
  group by state,county) c6 on c1.state=c6.state and c1.county=c6.county
  
                          join (select b.state
  ,b.county
  ,count(distinct b.lawyer_unclaimed_has_phone_cnt) as lawyer_unclaimed_has_phone_cnt    
  from lawyer_c b
  group by state,county) c7 on c1.state=c7.state and c1.county=c7.county
                                   join (select b.state
  ,b.county
  ,count(distinct b.lawyer_unclaimed_has_email_cnt) as lawyer_unclaimed_has_email_cnt    
  from lawyer_c b
  group by state,county) c8 on c1.state=c8.state and c1.county=c8.county
)


-- lawyer_county_c: using lawyer_county_psp above (line 231), claim counts by county, parent specialty, and professional

,lawyer_county_c as (select lcpsp.state
                             , lcpsp.county
                             , lcpsp.parent_sp
                             , lcpsp.profnl_id
                             , case when lcpsp.is_claim='claimed' then lcpsp.profnl_id else NULL end as lawyer_claimed_cnt
                             , case when lcpsp.is_claim='not-claimed' then lcpsp.profnl_id else NULL end as lawyer_unclaimed_cnt
                             , case when lcpsp.is_claim='claimed' then lcpsp.profnl_id else NULL end as claimed_lawyer                   
                             , case when lcpsp.is_claim='claimed' and lcpsp.has_phone='has-phone' then lcpsp.profnl_id else NULL end as lawyer_claimed_has_phone_cnt
                             , case when lcpsp.is_claim='claimed' and lcpsp.has_email='has-email' then lcpsp.profnl_id else NULL end as lawyer_claimed_has_email_cnt
                             , case when lcpsp.is_claim='not-claimed' and lcpsp.has_phone='has-phone' then lcpsp.profnl_id else NULL end as lawyer_unclaimed_has_phone_cnt
                             , case when lcpsp.is_claim='not-claimed' and lcpsp.has_email='has-email' then lcpsp.profnl_id else NULL end as lawyer_unclaimed_has_email_cnt
              from lawyer_county_psp lcpsp)
    
-- lawyer_county_psp_cnt: using lawyer_county_cnt above (line 279), claim counts by county and parent specialty
,lawyer_county_psp_cnt as
(
              select c1.state
  ,c1.county
  ,c1.lawyer_cnt
,c1. parent_sp
  ,c2.lawyer_claimed_cnt as lawyer_claimed_cnt
  ,c3.lawyer_unclaimed_cnt as lawyer_unclaimed_cnt
  ,c4.claimed_lawyer/cast(c1.lawyer_cnt as double) as claim_rate
  ,c5.lawyer_claimed_has_phone_cnt
  ,c6.lawyer_claimed_has_email_cnt
  ,c7.lawyer_unclaimed_has_phone_cnt
  ,c8.lawyer_unclaimed_has_email_cnt

  from
  (select b.state
  ,b.county
  ,b.parent_sp
  ,count(distinct b.profnl_id) as lawyer_cnt      
  from lawyer_county_c b
  group by state,county,parent_sp) c1
   
         join (select b.state
  ,b.county
  ,b.parent_sp
  ,count(distinct b.lawyer_claimed_cnt) as lawyer_claimed_cnt      
  from lawyer_county_c b
  group by state,county,parent_sp) c2 on c1.state=c2.state and c1.county=c2.county and c1.parent_sp=c2.parent_sp

         join (select b.state
  ,b.county
  ,b.parent_sp
  ,count(distinct b.lawyer_unclaimed_cnt) as lawyer_unclaimed_cnt      
  from lawyer_county_c b
  group by state,county,parent_sp) c3 on c1.state=c3.state and c1.county=c3.county and c1.parent_sp=c3.parent_sp

         join (select b.state
  ,b.county
  ,b.parent_sp
  ,cast(count(distinct b.claimed_lawyer) as double) as claimed_lawyer      
  from lawyer_county_c b
  group by state,county,parent_sp) c4 on c1.state=c4.state and c1.county=c4.county and c1.parent_sp=c4.parent_sp

         join (select b.state
  ,b.county
  ,b.parent_sp
  ,count(distinct b.lawyer_claimed_has_phone_cnt) as lawyer_claimed_has_phone_cnt      
  from lawyer_county_c b
  group by state,county,parent_sp) c5 on c1.state=c5.state and c1.county=c5.county and c1.parent_sp=c5.parent_sp

                 join (select b.state
  ,b.county
  ,b.parent_sp
  ,count(distinct b.lawyer_claimed_has_email_cnt) as lawyer_claimed_has_email_cnt     
  from lawyer_county_c b
  group by state,county,parent_sp) c6 on c1.state=c6.state and c1.county=c6.county and c1.parent_sp=c6.parent_sp

                          join (select b.state
  ,b.county
  ,b.parent_sp
  ,count(distinct b.lawyer_unclaimed_has_phone_cnt) as lawyer_unclaimed_has_phone_cnt    
  from lawyer_county_c b
  group by state,county,parent_sp) c7 on c1.state=c7.state and c1.county=c7.county and c1.parent_sp=c7.parent_sp
                                   join (select b.state
  ,b.county
  ,b.parent_sp
  ,count(distinct b.lawyer_unclaimed_has_email_cnt) as lawyer_unclaimed_has_email_cnt    
  from lawyer_county_c b
  group by state,county,parent_sp) c8 on c1.state=c8.state and c1.county=c8.county and c1.parent_sp=c8.parent_sp
)

 
-- market_county: pulls value, revenue, monetization from ad_market_detail (which pulls from temp1,2,3; ad_revenue; ad_inventory)
-- combines that with claim counts by county and calculates ad value by claimed lawyer
, market_county as
(
              select a.*
                             , concat(a.county , '-' , a.state) as county_state
                            
                             -- claim rate
                             , coalesce(b.lawyer_cnt, 0) as lawyer_cnt
                             , coalesce(b.lawyer_claimed_cnt, 0) as lawyer_claimed_cnt
                             , coalesce(b.claim_rate, 0) as claim_rate
                            
                             -- value per claim attorney
                             , case when b.lawyer_claimed_cnt is NULL or  b.lawyer_claimed_cnt = 0 then 0 else a.sl_value / b.lawyer_cnt end as sl_value_per_claim_lawyer
                             , case when b.lawyer_claimed_cnt is NULL or  b.lawyer_claimed_cnt = 0 then 0 else a.da_value / b.lawyer_cnt end as da_value_per_claim_lawyer
                             , case when b.lawyer_claimed_cnt is NULL or  b.lawyer_claimed_cnt = 0 then 0 else a.ad_value / b.lawyer_cnt end as ad_value_per_claim_lawyer
              from
              (
                             select amd.state
                                           , amd.county
                                           -- Sponsored Listing
                                           , SUM(amd.sl_value) as sl_value
                                           , SUM(amd.sl_revenue) as sl_revenue
                                           , SUM(amd.sl_sold_value) as sl_sold_value
                                           , SUM(amd.sl_unsold_value) as sl_unsold_value
                                           , SUM(amd.sl_revenue_opportunity) as sl_revenue_opportunity
                                           , SUM(amd.sl_revenue)/SUM(amd.sl_value) as sl_monetization                                          
 
                                           -- Display Ad
                                           , SUM(amd.da_value) as da_value
                                           , SUM(amd.da_revenue) as da_revenue
                                           , SUM(amd.da_sold_value) as da_sold_value
                                           , SUM(amd.da_unsold_value) as da_unsold_value
                                           , SUM(amd.da_revenue_opportunity) as da_revenue_opportunity
                                           , SUM(amd.da_revenue)/SUM(amd.da_value) as da_monetization
                                          
                                           -- Total Ad
                                           , SUM(amd.ad_value) as ad_value
                                           , SUM(amd.ad_revenue) as ad_revenue
                                           , SUM(amd.ad_sold_value) as ad_sold_value
                                           , SUM(amd.ad_unsold_value) as ad_unsold_value
                                           , SUM(amd.ad_revenue_opportunity) as ad_revenue_opportunity
                                           , SUM(amd.ad_revenue)/SUM(amd.ad_value) as ad_monetization
                                           from ad_market_detail amd
                                           group by 1,2
              ) a
              left join lawyer_county_cnt b on b.state = a.state and b.county = a.county
)

-- top_lawyer_county_psp: for top counties (meeting specified value, monetization, claim rate, and lawyer count criteria)
-- by parent specialty: lawyer counts, claim rate, and value per claimed lawyer
, top_lawyer_county_psp as
(

              select lcpsp.parent_sp

                             , SUM(lcpsp.lawyer_cnt) as lawyer_cnt

                             , SUM(lcpsp.lawyer_claimed_cnt) as lawyer_claimed_cnt

                             , SUM(lcpsp.lawyer_claimed_cnt) / SUM(lcpsp.lawyer_cnt) as claim_rate

                             , SUM(lcpsp.lawyer_cnt) / SUM(top_county.lawyer_cnt) as lawyer_psp_pct

                             , SUM(top_psp.sl_value) / SUM(lcpsp.lawyer_claimed_cnt) as sl_value_per_claim_lawyer

                             , SUM(top_psp.da_value) / SUM(lcpsp.lawyer_claimed_cnt) as da_value_per_claim_lawyer

                             , SUM(top_psp.ad_value) / SUM(lcpsp.lawyer_claimed_cnt) as ad_value_per_claim_lawyer

              from

              (            

                             select mc.state

                                           , mc.county

                                           , mc.lawyer_cnt

                                           , mc.sl_value

                                           , mc.da_value

                                           , mc.ad_value                               

                             from market_county mc

                             where mc.sl_value > 10000

                                          and mc.sl_monetization > 0.5

                                           and mc.claim_rate > 0.3

                                           and mc.lawyer_cnt > 1000

--                                        and mc.state = 'washington' and mc.county = 'king'

                             order by mc.sl_value desc

                             limit 10

              ) top_county

              join lawyer_county_psp_cnt lcpsp on lcpsp.state = top_county.state and lcpsp.county = top_county.county

              left join

              (

                             select amd.state

                                           , amd.county

                                           , amd.parent_sp

                                           -- Sponsored Listing

                                           , SUM(amd.sl_value) as sl_value

                                           , SUM(amd.sl_revenue) as sl_revenue

                                           , SUM(amd.sl_sold_value) as sl_sold_value

                                           , SUM(amd.sl_unsold_value) as sl_unsold_value

                                           , SUM(amd.sl_revenue_opportunity) as sl_revenue_opportunity

                                           , SUM(amd.sl_revenue)/SUM(amd.sl_value) as sl_monetization                                          

                            

                                           -- Display Ad

                                           , SUM(amd.da_value) as da_value

                                           , SUM(amd.da_revenue) as da_revenue

                                           , SUM(amd.da_sold_value) as da_sold_value

                                           , SUM(amd.da_unsold_value) as da_unsold_value

                                           , SUM(amd.da_revenue_opportunity) as da_revenue_opportunity

                                           , SUM(amd.da_revenue)/SUM(amd.da_value) as da_monetization

                                          

                                           -- Total Ad

                                           , SUM(amd.ad_value) as ad_value

                                           , SUM(amd.ad_revenue) as ad_revenue

                                           , SUM(amd.ad_sold_value) as ad_sold_value

                                           , SUM(amd.ad_unsold_value) as ad_unsold_value

                                           , SUM(amd.ad_revenue_opportunity) as ad_revenue_opportunity
                                           , SUM(amd.ad_revenue)/SUM(amd.ad_value) as ad_monetization
                                           from ad_market_detail amd
                                           group by 1,2,3                
              ) top_psp on top_psp.state = lcpsp.state and top_psp.county = lcpsp.county and top_psp.parent_sp = lcpsp.parent_sp
              group by 1
)

-- market_county_psp: by county and parent specialty, what are claim counts/rates AND potential counts/rates
-- see below for potential claim rate explanation
, market_county_psp as
(
               select a.*
                              , concat(a.county,'-',a.state,a.parent_sp) as county_state_psp
                              
                              -- claim data
                              , coalesce(b.lawyer_cnt, 0) as lawyer_cnt
                              , coalesce(b.lawyer_claimed_cnt, 0) as lawyer_claimed_cnt
                              , coalesce(b.claim_rate, 0) as claim_rate
                              , coalesce(b.county_claim_rate, 0) as county_claim_rate
                              , coalesce(b.potential_lawyer_cnt, 0) as potential_lawyer_cnt
                              , coalesce(b.potential_claim_rate, 0) as potential_claim_rate

                              -- top 10 psp-county claim data
                              , coalesce(b.top_claim_rate, 0) as top_claim_rate
                              , coalesce(b.top_sl_value_per_claim_lawyer, 0) as top_sl_value_per_claim_lawyer
                              , coalesce(b.top_da_value_per_claim_lawyer, 0) as top_ad_value_per_claim_lawyer
                              , coalesce(b.top_ad_value_per_claim_lawyer, 0) as top_da_value_per_claim_lawyer

                              -- value per claim attorney
                              , case when b.lawyer_claimed_cnt is NULL or  b.lawyer_claimed_cnt = 0 then 0 else a.sl_value / b.lawyer_cnt end as sl_value_per_claim_lawyer
                              , case when b.lawyer_claimed_cnt is NULL or  b.lawyer_claimed_cnt = 0 then 0 else a.da_value / b.lawyer_cnt end as da_value_per_claim_lawyer
                              , case when b.lawyer_claimed_cnt is NULL or  b.lawyer_claimed_cnt = 0 then 0 else a.ad_value / b.lawyer_cnt end as ad_value_per_claim_lawyer
               from
               (
                              select amd.state
                                             , amd.county
                                             , amd.parent_sp
                                             -- Sponsored Listing
                                             , SUM(amd.sl_value) as sl_value
                                             , SUM(amd.sl_revenue) as sl_revenue
                                             , SUM(amd.sl_sold_value) as sl_sold_value
                                             , SUM(amd.sl_unsold_value) as sl_unsold_value
                                             , SUM(amd.sl_revenue_opportunity) as sl_revenue_opportunity
                                             , SUM(amd.sl_revenue)/SUM(amd.sl_value) as sl_monetization                                   
                              
                                             -- Display Ad
                                             , SUM(amd.da_value) as da_value
                                             , SUM(amd.da_revenue) as da_revenue
                                             , SUM(amd.da_sold_value) as da_sold_value
                                             , SUM(amd.da_unsold_value) as da_unsold_value
                                             , SUM(amd.da_revenue_opportunity) as da_revenue_opportunity
                                             , SUM(amd.da_revenue)/SUM(amd.da_value) as da_monetization
                                             
                                             -- Total Ad
                                             , SUM(amd.ad_value) as ad_value
                                             , SUM(amd.ad_revenue) as ad_revenue
                                             , SUM(amd.ad_sold_value) as ad_sold_value
                                             , SUM(amd.ad_unsold_value) as ad_unsold_value
                                             , SUM(amd.ad_revenue_opportunity) as ad_revenue_opportunity
                                             , SUM(amd.ad_revenue)/SUM(amd.ad_value) as ad_monetization
                                             from ad_market_detail amd
                                             group by 1,2,3                   
               ) a
               left join
               (
                              select lcpsp.state
                                             , lcpsp.county
                                             , lcpsp.parent_sp
                                             , lcpsp.lawyer_cnt
                                             , lcpsp.lawyer_claimed_cnt
                                             , lcpsp.lawyer_unclaimed_cnt
                                             , lcpsp.claim_rate
                                             , lcc.claim_rate as county_claim_rate
                                             , tlcp.lawyer_psp_pct * lcc.lawyer_cnt as psp_lawyer_cnt
/* potential count and claim rate: in many counties, there are lawyers whose specialty breakdowns are unknown, which can make claim
      rates appear better or worse than they really are. use the distribution of top 10 counties' specialties to determine what the
      overall specialty breakdown in other counties is likely to be, then use this to determine a more accurate claim count/rate.
      potential count is whatever is greater: the actual count of attys in a specialty for that county or the expected count
      based on the top 10 counties */
                                             , case when lcpsp.lawyer_cnt > (tlcp.lawyer_psp_pct * lcc.lawyer_cnt) then lcpsp.lawyer_cnt else (tlcp.lawyer_psp_pct * lcc.lawyer_cnt) end as potential_lawyer_cnt
                                             , cast(lcpsp.lawyer_claimed_cnt as float) /(case when lcpsp.lawyer_cnt > (tlcp.lawyer_psp_pct * lcc.lawyer_cnt) then lcpsp.lawyer_cnt else (tlcp.lawyer_psp_pct * lcc.lawyer_cnt) end) as potential_claim_rate

                                             -- top market data
                                             , tlcp.claim_rate as top_claim_rate
                                             , tlcp.sl_value_per_claim_lawyer as top_sl_value_per_claim_lawyer
                                             , tlcp.da_value_per_claim_lawyer as top_da_value_per_claim_lawyer
                                             , tlcp.ad_value_per_claim_lawyer as top_ad_value_per_claim_lawyer
                              from lawyer_county_psp_cnt lcpsp
                              join lawyer_county_cnt lcc on lcc.state = lcpsp.state and lcc.county = lcpsp.county
                              join top_lawyer_county_psp tlcp on tlcp.parent_sp = lcpsp.parent_sp
               ) b on b.state = a.state and b.county = a.county and b.parent_sp = a.parent_sp
)

-- below is the main final query, which pulls in everything above and adds in the quadrant (/market segment) definitions
-- output is by year, market, specialty, and market type 
select amd.*
               
               -- county parent specialty data
               , mcpsp.county_state_psp
               , mcpsp.lawyer_cnt 
               , mcpsp.potential_lawyer_cnt
               , mcpsp.lawyer_claimed_cnt
               , mcpsp.claim_rate
               , mcpsp.potential_claim_rate
               , mcpsp.county_claim_rate
               , mcpsp.sl_value_per_claim_lawyer
               , mcpsp.da_value_per_claim_lawyer
               , mcpsp.ad_value_per_claim_lawyer
               
               -- top market data
               , mcpsp.top_claim_rate
               , mcpsp.top_sl_value_per_claim_lawyer
               , mcpsp.top_da_value_per_claim_lawyer
               , mcpsp.top_ad_value_per_claim_lawyer
               
               -- market segment
               , case when mcpsp.potential_claim_rate < 0.3 and amd.sl_sell_through < .8 then 'I'
                              when amd.sl_sell_through >= .8 then 'IV'
                              when amd.sl_sell_through >= .5 then 'III'
                              else 'II' end as sl_market_segment
               , case when mcpsp.potential_claim_rate < 0.3 and amd.da_sell_through < .8 then 'I'
                              when amd.da_sell_through >= .8 then 'IV'
                              when amd.da_sell_through >= .5 then 'III'
                              else 'II' end as da_market_segment
               , case when mcpsp.potential_claim_rate < 0.3 and amd.ad_sell_through < .8 then 'I'
                              when amd.ad_sell_through >= .8 then 'IV'
                              when amd.ad_sell_through >= .5 then 'III'
                              else 'II' end as ad_market_segment
from ad_market_detail amd
left join market_county_psp mcpsp on mcpsp.state = amd.state and mcpsp.county = amd.county and mcpsp.parent_sp = amd.parent_sp
