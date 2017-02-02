WITH
TMP_CUSTOMER_PURCHASE_PRICE  AS
(
        SELECT olaf.professional_id
            , olaf.customer_id
            , OLAMF.ad_market_id
            , amd.ad_mkt_key
            -- ,AD.AD_ID
            , PLD.product_line_item_name as PRODUCT_LN_ITM_NAME
            , dm.year_month
            --, case when olaf.remnant_flag is null then 'N' else olaf.remnant_flag end as remnant_flag
            , SUM(OLAF.order_line_net_price_amount_usd) AS ad_spend
            , sum(OLAF.block_count) as blocks_purchased
        FROM DM.order_line_accumulation_fact OLAF 
        left JOIN DM.order_line_ad_market_fact OLAMF ON OLAF.order_line_number = OLAMF.order_line_number 
        left join dm.ad_market_dimension amd1 on amd1.ad_market_id = OLAMF.ad_market_id
        left join dm.ad_mkt_dim amd on amd.ad_mkt_id = amd1.ad_market_id
        JOIN DM.DATE_DIM DM ON DM.actual_date = OLAF.order_line_begin_date
        join
        (
           select distinct d.year_month     
           from DM.DATE_DIM d
           where d.actual_date = to_date(now()- interval 1 month)
        ) dt on dt.year_month = dm.year_month
        left JOIN DM.product_line_dimension PLD ON OLAF.product_line_id = PLD.product_line_id 
          -- AND PLD.product_line_item_name IN ('Display Medium Rectangle','Sponsored Listing') 
        -- left JOIN DM.AD_DIM ad on ad.ad_key = olamf.ad_key
        where olaf.order_line_payment_date!='1900-01-01'
            and olaf.order_line_payment_date!='-1'
            and olaf.product_line_id in (2,7) 
            and amd1.ad_market_block_flag='Y'
            -- and olaf.customer_id=4220
            and olaf.remnant_flag!='Y'
        GROUP BY 1,2,3,4,5,6
)
 
-- delivered impressions by professional id, ad market and ad type in previous month
, TMP_IMPRESSIONS  AS
(   
    select ip.ad_market_id
        , ip.customer_id
        , ip.professional_id
        , ip.year_month
        , ip.PRODUCT_LN_ITM_NAME 
        , sum(ip.ad_impression_cnt) as ad_impression_cnt
    from
    (
        select imp.ad_id
            , case when req.ad_type in ('sponsored_listing_ad','sponsored_listing') then 'Sponsored Listing' else 'Display Medium Rectangle' end as PRODUCT_LN_ITM_NAME 
          , amd.ad_market_id
          , dt.year_month
          , p.professional_id
          , cust.customer_id
          , count(*) as ad_impression_cnt
        from src.ad_impression imp
        JOIN src.ad_request req ON req.ad_request_guid = imp.ad_request_guid
        join dm.specialty_dimension sd on req.specialty_id = sd.specialty_id 
        join dm.ad_region_dimension ard on req.sales_region_id = ard.ad_region_id
        join dm.ad_market_dimension amd on amd.specialty_id = sd.specialty_id and amd.ad_region_id = ard.ad_region_id and amd.ad_market_block_flag = 'Y'
        JOIN dm.etldm_ad_cust_profnl_map mp ON mp.ad_id = imp.ad_id
            AND imp.event_date >= mp.row_eff_begin_date
            AND imp.event_date < mp.row_eff_end_date
        LEFT JOIN dm.professional_dimension p ON p.professional_id = mp.profnl_id
        AND p.professional_delete_indicator = 'Not Deleted'
        LEFT JOIN dm.customer_dimension cust ON cust.customer_id = mp.cust_id
        join dm.date_dim dt on dt.actual_date = imp.event_date
        join
        (
            select distinct d.year_month     
            from DM.DATE_DIM d
            where d.actual_date = to_date(now()- interval 1 month)
        ) dt1 on dt1.year_month = dt.year_month
        where req.ad_type in ('sponsored_listing_ad','sponsored_listing','display_ad','display_medium_rectangle')
        group by 1,2,3,4,5,6
    ) ip
    group by 1,2,3,4,5   
)
     
 
-- get the order begin date to calculate the target impressions in next temp table TMP_TARGET_IMP
, TMP_BLOCK_BEGIN_DATE as
(
    SELECT olaf.professional_id
       , olaf.customer_id
       , OLAMF.ad_market_id
       -- ,AD.AD_ID
       , PLD.product_line_item_name as PRODUCT_LN_ITM_NAME 
       , OLAF.order_line_begin_date as begin_date
       , case when olaf.order_line_cancelled_date >'1900-01-01' then olaf.order_line_cancelled_date else null end as cancel_date
       , dm.year_month
       ,sum(OLAF.block_count) as blocks_purchased
    FROM DM.order_line_accumulation_fact OLAF 
    left JOIN DM.order_line_ad_market_fact OLAMF ON OLAF.order_line_number = OLAMF.order_line_number 
    left join dm.ad_market_dimension amd on amd.ad_market_id = OLAMF.ad_market_id
    JOIN DM.DATE_DIM DM ON DM.actual_date = OLAF.order_line_begin_date
    join
    (
       select distinct d.year_month     
       from DM.DATE_DIM d
       where d.actual_date = to_date(now()- interval 1 month)
    ) dt on dt.year_month = dm.year_month
    left JOIN DM.product_line_dimension PLD ON OLAF.product_line_id = PLD.product_line_id 
      -- AND PLD.PRODUCT_LN_ITM_NAME IN ('Display Medium Rectangle','Sponsored Listing') 
    -- left JOIN DM.AD_DIM ad on ad.ad_key = olamf.ad_key
    where olaf.order_line_payment_date!='1900-01-01'
        and olaf.order_line_payment_date!='-1'
        and olaf.product_line_id in (2,7) 
        and amd.ad_market_block_flag='Y'
        and olaf.remnant_flag!='Y'
    group by 1,2,3,4,5,6,7
)
 
-- target impressions by professional, ad market and ad type
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
 
-- flag if the purchased blocks were cancelled
, cancel as
(
    select cc.professional_id
        , cc.customer_id
        , cc.ad_market_id
        , cc.PRODUCT_LN_ITM_NAME
        , cc.year_month
        , case when cc.blocks_purchased-cc.blocks_cancelled<=0 then 'Y' else 'N' end as cancel_flag
    from
    (
        select x.professional_id
            , x.customer_id
            , x.ad_market_id
            , x.PRODUCT_LN_ITM_NAME 
            , x.year_month
            , sum(x.blocks_purchased) as blocks_purchased
            , sum(case when x.cancel_date is not null then x.blocks_purchased end) as blocks_cancelled
        from TMP_BLOCK_BEGIN_DATE x
        group by 1,2,3,4,5
    ) cc    
) 
 
-- add block launch month using dm.block_price_history
 
, launch as
(
    select ad_market_id
        , case when ad_type='Display' then 'Display Medium Rectangle' else ad_type end as ad_type
        , min(pricing_date) as blocklaunch
    from dm.block_price_history
    group by 1,2
)
 
-- need to join on temp table launch
SELECT cpp.year_month
    , cpp.ad_mkt_key
    , cpp.ad_market_id
    , case when blk.ad_market_id is null then 'Exclusive' else 'Block' end as market_type
    , case when ccl.cancel_flag is null then 'N/A' else ccl.cancel_flag end as block_cancel_flag
    , la.blocklaunch 
    --       ,CPP.PROFNL_KEY
    , cpp.professional_id
    , cpp.customer_id
    --       ,max(MP.AD_MKT_key) as ad_mkt_key
--      , ard.ad_regn_id as ad_regn_id
    , AMD.ad_market_region_name AS Ad_Region
    , AMD.ad_market_state_name AS Ad_State
    --       ,MAX(AMD.AD_MKT_CNTY_NAME) AS AD_MKT_CNTY_NAME
    , AMD.ad_market_specialty_name AS Practice_Area
    , CPP.PRODUCT_LN_ITM_NAME AS Ad_Type 
    --       ,CPP.AD_ID
    --       ,CPP.CUST_KEY
    , concat(pd.professional_first_name,' ',pd.professional_last_name) as Lawyer
    -- ,pd.PROFNL_FRST_NAME||' '||pd.PROFNL_LAST_NAME as Lawyer
    , pd.professional_avvo_rating as Avvo_Rating
    , CD.customer_name as CUST_NAME
    , coalesce(TI.AD_IMPRESSION_CNT,0) as AD_IMPRESSION_CNT
    , coalesce(tmm.target_impression_cnt,0) as target_impression_cnt
    , CPP.ad_spend AS Ad_Sold_Price
    , CPP.blocks_purchased AS BLOCKS_PURCH_CNT
    -- , coalesce(ORDER_LN_BLOCK_CNT_TOTAL,0) AS ORDER_LN_BLOCK_CNT_TOTAL
FROM TMP_CUSTOMER_PURCHASE_PRICE CPP 
left join dm.ad_market_dimension amd on amd.ad_market_id = cpp.ad_market_id
left join cancel ccl on ccl.ad_market_id = cpp.ad_market_id
    and ccl.professional_id = cpp.professional_id
    and ccl.customer_id = cpp.customer_id
    and ccl.PRODUCT_LN_ITM_NAME = cpp.PRODUCT_LN_ITM_NAME
    and ccl.year_month = cpp.year_month
left JOIN DM.customer_dimension CD ON CPP.customer_id = CD.customer_id
left JOIN DM.professional_dimension PD ON CPP.professional_id = PD.professional_id
join
(
    select *
    from
    (
        select md.year_month
            , apfb.ad_market_id 
            , case when apfb.ad_type='Display' then 'Display Medium Rectangle' else apfb.ad_type end as ad_type
            , apfb.pricing_date
            , apfb.end_date
            , ROW_NUMBER() OVER(partition by md.MONTH_KEY, apfb.ad_market_id, apfb.ad_type order by apfb.end_date desc) rt
        from dm.MONTH_DIM md
        join DM.block_price_history apfb on md.MONTH_BEGIN_DATE < apfb.end_date and md.MONTH_END_DATE >= apfb.pricing_date
    ) a
    where a.rt = 1
) blk on blk.year_month = cpp.year_month and blk.ad_market_id = cpp.ad_market_id and blk.ad_type = cpp.PRODUCT_LN_ITM_NAME
left JOIN TMP_IMPRESSIONS TI ON TI.YEAR_MONTH = CPP.YEAR_MONTH 
    AND TI.ad_market_id = CPP.ad_market_id
    and ti.professional_id = cpp.professional_id 
    AND ti.customer_id = cpp.customer_id
    and ti.PRODUCT_LN_ITM_NAME = cpp.PRODUCT_LN_ITM_NAME
left join TMP_TARGET_IMP tmm on tmm.professional_id = cpp.professional_id and tmm.customer_id = cpp.customer_id 
                    and tmm.year_month = cpp.year_month and tmm.ad_market_id = cpp.ad_market_id and tmm.PRODUCT_LN_ITM_NAME = cpp.PRODUCT_LN_ITM_NAME
left join launch la on la.ad_market_id = cpp.ad_market_id and la.ad_type = cpp.PRODUCT_LN_ITM_NAME
