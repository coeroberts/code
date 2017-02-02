------------- Updated query with remnant ad experiment
------------- Updated query with DA blocks

WITH 
TMP_CUSTOMER_PURCHASE_PRICE  AS 
(
    SELECT olaf.professional_id
      , olaf.customer_id
      , OLAMF.ad_market_id
      -- ,AD.AD_ID
      , PLD.product_line_item_name as PRODUCT_LN_ITM_NAME
      , cast(
                   concat(
                     cast(year(OLAF.ORDER_LINE_BEGIN_DATE) as string)
                     , lpad(cast(month(OLAF.ORDER_LINE_BEGIN_DATE) as string),2,'0')
                 ) 
                 as int) as year_month
      , case when olaf.remnant_flag is null then 'N' else olaf.remnant_flag end as remnant_flag
      , SUM(OLAF.order_line_net_price_amount_usd) AS ad_spend
      , sum(OLAF.block_count) as blocks_purchased
    FROM DM.order_line_accumulation_fact OLAF 
    left JOIN DM.order_line_ad_market_fact OLAMF ON OLAF.order_line_number = OLAMF.order_line_number 
    left join dm.ad_market_dimension amd on amd.ad_market_id = OLAMF.ad_market_id
    
    left JOIN DM.product_line_dimension PLD ON OLAF.product_line_id = PLD.product_line_id 
      -- AND PLD.product_line_item_name IN ('Display Medium Rectangle','Sponsored Listing') 
    -- left JOIN DM.AD_DIM ad on ad.ad_key = olamf.ad_key
    where olaf.order_line_payment_date!='1900-01-01'
      and olaf.order_line_payment_date!='-1'
      and olaf.product_line_id in (2,7) 
      -- and olaf.customer_id=4220
      and year(OLAF.ORDER_LINE_BEGIN_DATE) >= extract(now()- interval 3 month, "year") 
      and month(OLAF.ORDER_LINE_BEGIN_DATE) >= extract(now()- interval 3 month, "month") 
      and OLAF.ORDER_LINE_BEGIN_DATE <= now()
    GROUP BY 1,2,3,4,5,6
)

, start_month as
(
  select olaf.professional_id
    , olaf.customer_id
    , min(dm.year_month) as start_month
  from DM.order_line_accumulation_fact OLAF 
  JOIN DM.DATE_DIM DM ON DM.actual_date = OLAF.order_line_begin_date
  where olaf.order_line_payment_date!='1900-01-01'
    and olaf.order_line_payment_date!='-1'
    and olaf.product_line_id in (2,7) 
  group by 1,2
)

---------- price for exclusive markets
, TMP_MARKET_PRICE  AS 
(
  SELECT APF.ad_mkt_id as AD_MARKET_ID
    , APF.sponsored_listing_price as price
    , 'Sponsored Listing' as ad_type
    , md.year_month
  FROM DM.AD_PRICING_SNAPSHOT_FACT APF 
  JOIN DM.MONTH_DIM MD ON APF.PRICNG_MONTH_KEY = MD.MONTH_KEY 
  join 
  (
     select distinct d.year_month     
     from DM.DATE_DIM d
     where d.actual_date >= to_date(now()- interval 3 month)
    and d.actual_date <= now()
  ) dt on dt.year_month = md.year_month
  
  union all
  
  SELECT APF.ad_mkt_id as AD_MARKET_ID
    , APF.display_ad_price as price
    , 'Display Medium Rectangle' as ad_type
    , md.year_month
  FROM DM.AD_PRICING_SNAPSHOT_FACT APF 
  JOIN DM.MONTH_DIM MD ON APF.PRICNG_MONTH_KEY = MD.MONTH_KEY 
  join 
  (
     select distinct d.year_month     
     from DM.DATE_DIM d
     where d.actual_date >= to_date(now()- interval 3 month)
    and d.actual_date <= now()
  ) dt on dt.year_month = md.year_month
)

, TMP_IMPRESSIONS  AS
(  
    select amd.ad_market_id
          , cust.customer_id
            , p.professional_id
      , cast(
                   concat(
                     cast(year(imp.event_date) as string)
                     , lpad(cast(month(imp.event_date) as string),2,'0')
                 ) 
                 as int) as YEAR_MONTH
     
      , case when req.ad_type in ('sponsored_listing_ad','sponsored_listing') then 'Sponsored Listing' else 'Display Medium Rectangle' end as PRODUCT_LN_ITM_NAME 
      , count(*) as ad_impression_cnt
    from src.ad_impression imp
      JOIN src.ad_request req ON req.ad_request_guid = imp.ad_request_guid and imp.event_date = req.event_date
      join dm.specialty_dimension sd on req.specialty_id = sd.specialty_id 
      join dm.ad_region_dimension ard on req.sales_region_id = ard.ad_region_id
      join dm.ad_market_dimension amd on amd.specialty_id = sd.specialty_id and amd.ad_region_id = ard.ad_region_id and amd.ad_market_active_flag = 'Y'
      JOIN dm.historical_ad_customer_professional_map mp ON mp.ad_id = imp.ad_id
        AND imp.event_date >= mp.etl_effective_begin_date
        AND imp.event_date < mp.etl_effective_end_date
      LEFT JOIN dm.professional_dimension p ON p.professional_id = mp.professional_id
        AND p.professional_delete_indicator = 'Not Deleted'
      LEFT JOIN dm.customer_dimension cust ON cust.customer_id = mp.customer_id
      --join dm.date_dim dt on dt.actual_date = imp.event_date    
    where 
        year(imp.event_date) >= extract(now()- interval 3 month, "year") 
        and month(imp.event_date) >= extract(now()- interval 3 month, "month") 
        and imp.event_date <= now()
      and  
        year(req.event_date) >= extract(now()- interval 3 month, "year") 
        and month(req.event_date) >= extract(now()- interval 3 month, "month") 
        and req.event_date <= now()
      and
        req.ad_type in ('sponsored_listing_ad','sponsored_listing','display_ad','display_medium_rectangle')
    group by 1,2,3,4,5  
)

---- blocks sold
, TMP_ORDER_LN_BLOCK_CNT_TOTAL AS 
(
    select tcpp.AD_MARKET_ID
    , tcpp.PRODUCT_LN_ITM_NAME
      , tcpp.year_month
      , sum(tcpp.blocks_purchased) as blocks_purchased
    from TMP_CUSTOMER_PURCHASE_PRICE tcpp
    join dm.ad_market_dimension am on am.AD_MARKET_ID = tcpp.AD_MARKET_ID
    where am.ad_market_block_flag = 'Y'   
        --and tcpp.PRODUCT_LN_ITM_NAME = 'Sponsored Listing'
    group by 1,2,3
)

, TMP_BLOCKPRICE AS
(
  select *
  from
  (
    select apfb.ad_market_id 
      , md.year_month
      , case when apfb.ad_type='Display' then 'Display Medium Rectangle' else apfb.ad_type end as ad_type
      , apfb.list_price_usd as block_price
      , apfb.sellable_count as block_inventory
      , ROW_NUMBER() OVER(partition by md.MONTH_KEY, apfb.ad_market_id, apfb.ad_type order by apfb.end_date desc) rt
    from DM.MONTH_DIM md
    join DM.block_price_history apfb on md.MONTH_BEGIN_DATE < apfb.end_date and md.MONTH_END_DATE >= apfb.pricing_date
    join 
    (
       select distinct d.year_month     
       from DM.DATE_DIM d
       where d.actual_date >= to_date(now()- interval 3 month)
      and d.actual_date <= now()
    ) dt on dt.year_month = md.year_month
    -- where apfb.ad_market_id = 208931
  ) a
  where a.rt = 1
)

, TMP_ATTRIBUTION  AS
(
  select ARVSF.professional_id
    , ARVSF.AD_MARKET_ID
    , ad.ad_detail_type as ad_detail_typ
    , ARVSF.customer_id
    , cast(
                   concat(
                     cast(year(ARVSF.attribution_date) as string)
                     , lpad(cast(month(ARVSF.attribution_date) as string),2,'0')
                 ) 
                 as int) as YEAR_MONTH
    , SUM(ARVSF.adjusted_attribution_value) AS ADJ_ATTRIB_VALUE
    , SUM(ARVSF.ad_click_count) AS AD_CLICK_ATTRIB_CNT
    , SUM(ARVSF.email_attributed_count) AS EMAIL_ATTRIB_CNT
    , SUM(ARVSF.phone_attributed_count) AS PHON_ATTRIB_CNT
    , SUM(ARVSF.website_attributed_count) AS WEBSITE_ATTRIB_CNT
    , SUM(ARVSF.total_attributed_value) AS TOTL_ATTRIB_VALUE
  from DM.webanalytics_ad_attribution_v0 ARVSF 
         join dm.ad_dimension ad on ad.ad_id = arvsf.ad_id
    where ARVSF.attribution_date <= now()
          and year(ARVSF.attribution_date) >= extract(now()- interval 3 month, "year")
          and month(ARVSF.attribution_date) >= extract(now()- interval 3 month, "month")
  --where arvsf.customer_id=2
  --and dm.year_month=201507
  GROUP BY 1,2,3,4,5
)

, avg_roi as
(
  select cpp.customer_id
    --, cpp.professional_id
/*     , cpp.ad_market_id
    , cpp.ad_market_id
    -- ,AD.AD_ID
    , cpp.PRODUCT_LN_ITM_NAME */
    , sum(arvsf.ADJ_ATTRIB_VALUE)
    , sum(cpp.ad_spend)
    , sum(arvsf.ADJ_ATTRIB_VALUE)/sum(cpp.ad_spend)-1 as avg_roi
  from TMP_CUSTOMER_PURCHASE_PRICE cpp
  left join TMP_ATTRIBUTION ARVSF on CPP.customer_id = ARVSF.customer_id
    and CPP.professional_id = ARVSF.professional_id 
    AND CPP.AD_MARKET_ID = ARVSF.AD_MARKET_ID
    AND CPP.YEAR_MONTH = ARVSF.YEAR_MONTH
    and cpp.PRODUCT_LN_ITM_NAME  = arvsf.ad_detail_typ 
  group by 1
)

, current_roi as 
(
  select cpp.customer_id
    --, cpp.professional_id
/*     , cpp.ad_market_id
    , cpp.ad_market_id
    -- ,AD.AD_ID
    , cpp.PRODUCT_LN_ITM_NAME */
    , sum(arvsf.ADJ_ATTRIB_VALUE)/sum(cpp.ad_spend)-1 as currentmonth_roi
  from TMP_CUSTOMER_PURCHASE_PRICE cpp
  join dm.date_dim dd on dd.year_month=cpp.year_month
  left join TMP_ATTRIBUTION ARVSF on CPP.customer_id = ARVSF.customer_id
    and CPP.professional_id = ARVSF.professional_id 
    AND CPP.AD_MARKET_ID = ARVSF.AD_MARKET_ID
    AND CPP.YEAR_MONTH = ARVSF.YEAR_MONTH
    and cpp.PRODUCT_LN_ITM_NAME  = arvsf.ad_detail_typ
  where dd.actual_Date=to_date(now())
  group by 1
)

, TMP_BLOCK_BEGIN_DATE as
(
  SELECT olaf.professional_id
     , olaf.customer_id
     , OLAMF.ad_market_id
     -- ,AD.AD_ID
     , PLD.product_line_item_name as PRODUCT_LN_ITM_NAME 
     , OLAF.order_line_begin_date as begin_date
     , case when olaf.order_line_cancelled_date >'1900-01-01' then olaf.order_line_cancelled_date else null end as cancel_date
     , cast(
                   concat(
                     cast(year(OLAF.ORDER_LINE_BEGIN_DATE) as string)
                     , lpad(cast(month(OLAF.ORDER_LINE_BEGIN_DATE) as string),2,'0')
                 ) 
                 as int) as year_month
     ,sum(OLAF.block_count) as blocks_purchased
  FROM DM.order_line_accumulation_fact OLAF 
  left JOIN DM.order_line_ad_market_fact OLAMF ON OLAF.order_line_number = OLAMF.order_line_number 
  left join dm.ad_market_dimension amd on amd.ad_market_id = OLAMF.ad_market_id
  left JOIN DM.product_line_dimension PLD ON OLAF.product_line_id = PLD.product_line_id 
    -- AND PLD.PRODUCT_LN_ITM_NAME IN ('Display Medium Rectangle','Sponsored Listing') 
  -- left JOIN DM.AD_DIM ad on ad.ad_key = olamf.ad_key
  where olaf.order_line_payment_date!='1900-01-01'
    and olaf.order_line_payment_date!='-1'
    and olaf.product_line_id in (2,7) 
    and year(OLAF.ORDER_LINE_BEGIN_DATE) >= extract(now()- interval 3 month, "year") 
    and month(OLAF.ORDER_LINE_BEGIN_DATE) >= extract(now()- interval 3 month, "month") 
    and OLAF.ORDER_LINE_BEGIN_DATE <= now()
  group by 1,2,3,4,5,6,7
)

, TMP_TARGET_ACV as
(
  select x.professional_id
    , x.customer_id
    , x.ad_market_id
    , x.year_month
    , x.PRODUCT_LN_ITM_NAME
    , sum(x.target_acv) as target_acv
  from
  (
    select bp.professional_id
      , bp.customer_id
      , bp.ad_market_id
      , bp.year_month
      , bp.PRODUCT_LN_ITM_NAME
      , bp.begin_date
      , bp.cancel_date
      , case when bp.cancel_date is not null then (day(bp.cancel_date)-day(bp.begin_date))*bp.dailyvalue
        else
        (  
          case when month(bp.begin_date) in (1,3,5,7,8,10,12) 
            then (31-day(bp.begin_date)+1)*bp.dailyvalue
            when month(bp.begin_date)=2
            then (28-day(bp.begin_date)+1)*bp.dailyvalue
            else (30-day(bp.begin_date)+1)*bp.dailyvalue
          end
        ) end as target_acv
    from
    (
      select b.professional_id
        , b.customer_id
        , b.ad_market_id
        , b.PRODUCT_LN_ITM_NAME
        , b.begin_date
        , b.cancel_date
        , b.year_month
        , coalesce(a.block_price,0)*b.blocks_purchased as monthlyvalue
        , case when month(b.begin_date) in (1,3,5,7,8,10,12) 
          then coalesce(a.block_price,0)*b.blocks_purchased/31 
          when month(b.begin_date)=2
          then coalesce(a.block_price,0)*b.blocks_purchased/28
          else coalesce(a.block_price,0)*b.blocks_purchased/30 
         end as dailyvalue
      from TMP_BLOCK_BEGIN_DATE b 
      left join TMP_BLOCKPRICE a on a.year_month = b.year_month and a.ad_market_id = b.ad_market_id and a.ad_type=b.PRODUCT_LN_ITM_NAME
      --where b.customer_id=36488
    ) bp
  ) x
  group by 1,2,3,4,5
)

, TMP_TARGET_IMP as
(
  select y.professional_id
    , y.customer_id
    , y.ad_market_id
    , y.year_month
    , y.PRODUCT_LN_ITM_NAME
    , sum(y.target_impression_cnt) as target_impression_cnt
  from
  (
    select imp.professional_id
      , imp.customer_id
      , imp.ad_market_id
      , imp.year_month
      , imp.PRODUCT_LN_ITM_NAME
      , imp.begin_date
      , imp.cancel_date
      , case when imp.cancel_date is not null then (day(imp.cancel_date)-day(imp.begin_date))*imp.dailyimp
        else
        (  
          case when month(imp.begin_date) in (1,3,5,7,8,10,12) 
            then (31-day(imp.begin_date)+1)*imp.dailyimp
            when month(imp.begin_date)=2
            then (28-day(imp.begin_date)+1)*imp.dailyimp
            else (30-day(imp.begin_date)+1)*imp.dailyimp
          end
        ) end as target_impression_cnt
    from
    (
      select *
        , case when month(begin_date) in (1,3,5,7,8,10,12) 
          then blocks_purchased*100/31 
          when month(begin_date)=2
          then blocks_purchased*100/28
          else blocks_purchased*100/30 
         end as dailyimp
      from TMP_BLOCK_BEGIN_DATE 
      where blocks_purchased>0
    ) imp
  ) y
  group by 1,2,3,4,5
)

SELECT cpp.year_month
  --, cpp.ad_market_id
  , cpp.ad_market_id
  --       ,CPP.PROFNL_KEY
  , cpp.professional_id
  , cpp.customer_id
  --       ,max(MP.ad_market_id) as ad_market_id
  , cpp.remnant_flag
  , sm.start_month
  , ard.ad_region_id as ad_regn_id
  , AMD.ad_market_region_name AS Ad_Region
  , AMD.ad_market_state_name AS Ad_State
  , AMD.ad_market_specialty_name AS Practice_Area
  , CPP.PRODUCT_LN_ITM_NAME AS Ad_Type 
  --       ,CPP.AD_ID
  --       ,CPP.CUST_KEY
  , concat(pd.professional_first_name,' ',pd.professional_last_name) as Lawyer
  , pd.professional_avvo_rating as Avvo_Rating
  , CD.customer_name as CUST_NAME
  , case when ambp.ad_market_id is null then 'Exclusive' else "Block" end as BlockMarket
  , aroi.avg_roi
  , croi.currentmonth_roi
  --     , coalesce(ctt.website_visits,0) as website_visits
  , coalesce(ctt.email_contacts,0) as email_contacts
  , coalesce(ctt.phone_contacts,0) as phone_contacts
  , coalesce(TI.AD_IMPRESSION_CNT,0) as AD_IMPRESSION_CNT
  , coalesce(tmm.target_impression_cnt,0) as target_impression_cnt
  , coalesce(ambp.block_inventory,0) as block_inventory
  , coalesce(ambp.BLOCK_PRICE,0) as BLOCK_PRICE 
  , coalesce(ARVSF.EMAIL_ATTRIB_CNT,0) AS EMAIL_ATTRIB_CNT
  , coalesce(ARVSF.WEBSITE_ATTRIB_CNT,0) AS WEBSITE_ATTRIB_CNT
  , coalesce(ARVSF.AD_CLICK_ATTRIB_CNT,0) AS AD_CLICK_ATTRIB_CNT
  , coalesce(ARVSF.PHON_ATTRIB_CNT,0) AS PHON_ATTRIB_CNT
  , coalesce(ARVSF.TOTL_ATTRIB_VALUE,0) AS TOTL_ATTRIB_VALUE
  , coalesce(ARVSF.ADJ_ATTRIB_VALUE,0) AS ADJ_ATTRIB_VALUE
  , coalesce(taa.target_acv,0) as target_acv
  , CPP.ad_spend AS Ad_Sold_Price
  , CPP.blocks_purchased AS BLOCKS_PURCH_CNT
  -- , coalesce(ORDER_LN_BLOCK_CNT_TOTAL,0) AS ORDER_LN_BLOCK_CNT_TOTAL
  , case when cpp.PRODUCT_LN_ITM_NAME = 'Sponsored Listing'
      then (case when released.block_inventory/3-sold_cust.blocks_purchased<0 then 0 else released.block_inventory/3-sold_cust.blocks_purchased end)
      else released.block_inventory-sold.blocks_purchased 
      end as block_avail_adv
  , case when cpp.PRODUCT_LN_ITM_NAME = 'Sponsored Listing'
      then (case when released.block_inventory/3-sold_cust.blocks_purchased<0 then 0 else released.block_inventory/3-sold_cust.blocks_purchased end) * released.block_price
      else (released.block_inventory-sold.blocks_purchased)*released.block_price
      end as block_inventory_avail_adv
  , case when coalesce(ambp.block_inventory,0) > 0
    then coalesce(ambp.BLOCK_PRICE,0) * CPP.blocks_purchased
    else MP.price
    end as MSRP
FROM TMP_CUSTOMER_PURCHASE_PRICE CPP 
left join avg_roi aroi on CPP.customer_id = aroi.customer_id
  --AND CPP.professional_id = aroi.professional_id 
  /* AND CPP.ad_market_id = aroi.ad_market_id
  and cpp.PRODUCT_LN_ITM_NAME  = aroi.PRODUCT_LN_ITM_NAME */
left join current_roi croi on CPP.customer_id = croi.customer_id
  --AND CPP.professional_id = croi.professional_id 
  /* AND CPP.ad_market_id = croi.ad_market_id
  and cpp.PRODUCT_LN_ITM_NAME  = croi.PRODUCT_LN_ITM_NAME */
left join start_month sm on sm.professional_id = cpp.professional_id and sm.customer_id = cpp.customer_id
left JOIN DM.customer_dimension CD ON CPP.customer_id = CD.customer_id
left JOIN DM.professional_dimension PD ON CPP.professional_id = PD.professional_id
JOIN DM.ad_market_dimension AMD ON AMD.ad_market_id= CPP.ad_market_id
left join TMP_ATTRIBUTION ARVSF on CPP.professional_id = ARVSF.professional_id 
  AND CPP.customer_id = ARVSF.customer_id
  AND CPP.ad_market_id = ARVSF.ad_market_id
  AND CPP.YEAR_MONTH = ARVSF.YEAR_MONTH
  and cpp.PRODUCT_LN_ITM_NAME  = arvsf.ad_detail_typ
left JOIN TMP_MARKET_PRICE MP ON CPP.ad_market_id = MP.ad_market_id AND CPP.YEAR_MONTH = MP.YEAR_MONTH and mp.ad_type = cpp.PRODUCT_LN_ITM_NAME
left JOIN TMP_IMPRESSIONS TI ON TI.YEAR_MONTH = CPP.YEAR_MONTH 
  AND TI.ad_market_id = CPP.ad_market_id
  and ti.professional_id = cpp.professional_id 
  AND ti.customer_id = cpp.customer_id
  and ti.PRODUCT_LN_ITM_NAME = cpp.PRODUCT_LN_ITM_NAME
-- left join TMP_ORDER_LN_BLOCK_CNT_TOTAL olbc on olbc.ad_market_id = CPP.ad_market_id and olbc.year_month = cpp.year_month
left join TMP_BLOCKPRICE ambp on ambp.ad_market_id = CPP.ad_market_id AND AMBP.YEAR_MONTH = CPP.YEAR_MONTH and ambp.ad_type = cpp.PRODUCT_LN_ITM_NAME
left join dm.ad_region_dimension ard on ard.ad_region_id = amd.ad_region_id
left join
(
  select tpb.ad_market_id
    , tpb.ad_type
    , tpb.year_month
    , tpb.block_price
    , tpb.block_inventory
  from 
  (
    select tb.ad_market_id
      , tb.ad_type
      , tb.year_month
      , tb.block_price
      , tb.block_inventory
      , ROW_NUMBER() OVER(partition by tb.ad_market_id, tb.ad_type order by tb.year_month desc) rn
    from TMP_BLOCKPRICE tb
  ) tpb 
  where tpb.rn=1
) released on released.ad_market_id = cpp.ad_market_id and released.ad_type = cpp.PRODUCT_LN_ITM_NAME
left join
(
  select xx.ad_market_id
    , xx.year_month
    , xx.PRODUCT_LN_ITM_NAME
    , xx.blocks_purchased
  from
  (
    select x.ad_market_id
      , x.year_month
      , x.PRODUCT_LN_ITM_NAME
      , x.blocks_purchased
      , ROW_NUMBER() OVER(partition by x.ad_market_id, x.PRODUCT_LN_ITM_NAME order by x.year_month desc) rn
    from TMP_ORDER_LN_BLOCK_CNT_TOTAL x
  ) xx
  where xx.rn=1
) sold on sold.ad_market_id = cpp.ad_market_id and sold.PRODUCT_LN_ITM_NAME = cpp.PRODUCT_LN_ITM_NAME
left join
(
  select yy.ad_market_id
    , yy.professional_id
    , yy.customer_id
    , yy.year_month
    , yy.PRODUCT_LN_ITM_NAME
    , yy.blocks_purchased 
  from
  (
    select y.ad_market_id
      , y.professional_id
      , y.customer_id
      , y.year_month
      , y.PRODUCT_LN_ITM_NAME
      , y.blocks_purchased
      , ROW_NUMBER() OVER(partition by y.ad_market_id, y.customer_id, y.professional_id, y.PRODUCT_LN_ITM_NAME order by y.year_month desc) rn
    from TMP_CUSTOMER_PURCHASE_PRICE y
    --where y.PRODUCT_LN_ITM_NAME = 'Sponsored Listing' 
  ) yy
  where yy.rn=1
) sold_cust on sold_cust.ad_market_id = cpp.ad_market_id and sold_cust.professional_id = cpp.professional_id 
            and sold_cust.customer_id = cpp.customer_id and sold_cust.PRODUCT_LN_ITM_NAME = cpp.PRODUCT_LN_ITM_NAME
left join TMP_TARGET_IMP tmm on tmm.professional_id = cpp.professional_id and tmm.customer_id = cpp.customer_id 
          and tmm.year_month = cpp.year_month and tmm.ad_market_id = cpp.ad_market_id and tmm.PRODUCT_LN_ITM_NAME = cpp.PRODUCT_LN_ITM_NAME
left join TMP_TARGET_ACV taa on taa.professional_id = cpp.professional_id and taa.customer_id = cpp.customer_id 
          and taa.year_month = cpp.year_month and taa.ad_market_id = cpp.ad_market_id and taa.PRODUCT_LN_ITM_NAME = cpp.PRODUCT_LN_ITM_NAME
left join
(
  select ct.year_month
    , ct.professional_id
--       , sum(ct.website_visits) as website_visits
    , sum(ct.phone_contacts) as phone_contacts
    , sum(ct.email_contacts) as email_contacts
  from
  (
--         select dt.year_month
--           , ci.professional_id
--           , count(*) as website_visits
--           , 0 as phone_contacts
--           , 0 as email_contacts
--         from src.contact_impression ci
--         join DM.DATE_DIM d on d.actual_date = ci.event_date
--         join     
--         (
--              select distinct d.year_month     
--              from DM.DATE_DIM d
--              where d.actual_date >= to_date(now()- interval 3 month)
--               and d.actual_date <= now()
--           ) dt on dt.year_month = d.year_month
--         where ci.contact_type = 'website'
--         group by 1,2

--         union

      select dt.year_month
        , ci.professional_id
        , 0 as website_visits
        , count(*) as phone_contacts
        , 0 as email_contacts
      from src.contact_impression ci
      join DM.DATE_DIM d on d.actual_date = ci.event_date
      join     
      (
           select distinct d.year_month     
           from DM.DATE_DIM d
           where d.actual_date >= to_date(now()- interval 3 month)
          and d.actual_date <= now()
        ) dt on dt.year_month = d.year_month
      where ci.contact_type = 'phone'
      group by 1,2

      union

      select dt.year_month
        , ci.professional_id
        , 0 as website_visits
        , 0 as phone_contacts
        , count(*) as email_contacts
      from src.contact_impression ci
      join DM.DATE_DIM d on d.actual_date = ci.event_date
      join     
      (
           select distinct d.year_month     
           from DM.DATE_DIM d
           where d.actual_date >= to_date(now()- interval 3 month)
          and d.actual_date <= now()
        ) dt on dt.year_month = d.year_month
      where ci.contact_type = 'email'
      group by 1,2
  ) ct
  group by 1,2
) ctt on ctt.professional_id = cpp.professional_id and ctt.year_month = cpp.year_month
