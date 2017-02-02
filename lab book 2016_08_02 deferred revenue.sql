This does not have to be fixed for the June dataset, but we do
need to figure it out at some point:
One operational/business issue, also in red: sometimes, a credit 
card change or some other circumstance means that a $0 invoice 
is run with the subscription details, but a second invoice is 
manually entered for the value of the ads. The instance I found 
was Musca Law, so it’s the largest single time we’d see it, but 
it may be what is going on with times when we see target and 
delivered impressions but no price. We currently exclude these 
from the deferral calculations and I can’t think of a systematic 
way to know why with any certainty.

This is the correct customer-level one:

OK just changed this so it assumes it is running for last month
because I keep missing things to update.

-- To change every month: Table name in 3 places.

-- DROP TABLE IF EXISTS tmp_data_dm.coe_deferred_revenue_dataset_2016_12;
CREATE TABLE tmp_data_dm.coe_deferred_revenue_dataset_2016_12 AS
SELECT
   ad_mkt_key
  ,ad_market_id
  ,professional_id
  ,customer_id
  ,CONCAT(ad_type, ' - '
         ,CAST(professional_id AS STRING), ' - '
         ,CAST(ad_market_id AS STRING), ' - '
         ,CAST(customer_id AS STRING)) AS processing_id
  ,ad_type
  ,CASE WHEN latest_month_with_data = last_month THEN 'Y' ELSE 'N' END AS active_in_latest_month
  ,cancelled_in_current_month
  ,cancelled_in_latest_month
  ,CASE WHEN latest_month_with_data = last_month AND cancelled_in_latest_month = 'N' THEN 'Y' ELSE 'N' END AS include_in_latest_month_data
  ,latest_month_with_data
  ,year_month_num
  ,ad_impressions
  ,target_impressions 
  ,ad_sold_price
  ,over_under
  ,IFNULL(prev_month_over_under, 0) AS prev_month_over_under
  ,trailing_3mo_over_under
FROM
  (
  SELECT
     ad_mkt_key
    ,ad_market_id
    ,professional_id
    ,customer_id
    ,ad_type
    ,cancelled_in_current_month
    ,ad_impressions
    ,target_impressions
    ,ad_sold_price
    ,year_month_num
    ,last_month
    ,over_under
    ,FIRST_VALUE(year_month_num) OVER (PARTITION BY professional_id, ad_market_id, customer_id, ad_type
                               ORDER BY year_month_num DESC) AS                 latest_month_with_data
    ,MAX(CASE WHEN year_month_num = last_month THEN cancelled_in_current_month ELSE 'N' END) 
                               OVER (PARTITION BY professional_id, ad_market_id, customer_id, ad_type
                               ORDER BY year_month_num DESC) AS                 cancelled_in_latest_month
    ,LEAD(over_under, 1) OVER (PARTITION BY professional_id, ad_market_id, customer_id, ad_type
                               ORDER BY year_month_num DESC) AS                 prev_month_over_under
    ,SUM(over_under) OVER (PARTITION BY professional_id, ad_market_id, customer_id, ad_type
                               ORDER BY year_month_num DESC
                           ROWS BETWEEN CURRENT ROW AND 2 FOLLOWING) AS         trailing_3mo_over_under
    -- ,ROW_NUMBER() OVER (PARTITION BY professional_id, ad_market_id, customer_id, ad_type
    --                            ORDER BY year_month_num DESC) - 1 AS             relative_months_back
  FROM
    (
    SELECT
       amd.ad_mkt_key
      ,dr.ad_market_id
      ,dr.professional_id
      ,dr.customer_id
      ,CASE WHEN dr.ad_type LIKE 'Display%' THEN 'Display' ELSE dr.ad_type END AS ad_type
      ,dr.block_cancel_flag AS        cancelled_in_current_month
      ,dr.ad_impression_count AS      ad_impressions
      ,dr.target_impression_count AS  target_impressions
      ,dr.ad_sold_price
      ,dr.yearmonth AS year_month_num
      ,lm.last_month
      ,IFNULL(dr.ad_impression_count, 0) - IFNULL(dr.target_impression_count, 0) AS over_under
    FROM dm.deferred_revenue dr
    CROSS JOIN (SELECT CAST(from_unixtime(unix_timestamp(now() - interval 1 months), 'yyyyMM') AS INT) AS last_month) lm
    LEFT JOIN dm.ad_mkt_dim amd 
      ON amd.ad_mkt_id = dr.ad_market_id
      -- Jan for SL; Feb for Display
WHERE (   (dr.ad_type NOT LIKE 'Display%') AND (dr.yearmonth BETWEEN 201501 AND lm.last_month)
       OR (dr.ad_type     LIKE 'Display%') AND (dr.yearmonth BETWEEN 201602 AND lm.last_month))
--   AND dr.professional_id IN (806966, 820246, 82670, 950486)
--   AND amd.ad_mkt_key IN (178129, 184721, 433944, 434562, 
--                          436744, 440081, 440082, 440141)
  -- AND CONCAT(ad_type, ' - ', CAST(dr.professional_id AS STRING), ' - ', CAST(dr.ad_market_id AS STRING)) IN (
  --              'Sponsored Listing - 301440 - 749686',
  --              'Sponsored Listing - 2793674 - 745315',
  --              'Sponsored Listing - 506995 - 867',
  --              'Sponsored Listing - 4219850 - 8264'
  --           )
    ) drv
  ) hist
  
SELECT * FROM tmp_data_dm.coe_deferred_revenue_dataset_2016_12

--   WHERE CONCAT(ad_type, ' - ', CAST(dr.professional_id AS STRING), ' - ', CAST(dr.ad_market_id AS STRING)) IN (
--                'Sponsored Listing - 301440 - 749686',
--                'Sponsored Listing - 2793674 - 745315',
--                'Sponsored Listing - 506995 - 867',
--                'Sponsored Listing - 4219850 - 8264'
--             )

-- Excel logic:
-- -- =COUNTIFS(F:F,F2, K:K,$A$2, H:H,"Y")
-- -- =COUNTIFS(
-- --   F:F,F2,    -- What that row has in column F (processing_id) has what I have in column F.
-- --   K:K,$A$2,  -- What that row has in column K (year_month_num) has what''s in static cell $A$2.
-- --   H:H,"Y")   -- What that row has in column H (active_in_latest_month) is a "Y".  Oops.

-- OK first criteria needs work.
-- Maybe I just do not need it at all.
-- Want to say Find a row with same processing_id as me and a year_month_num value that matches the parameter.
-- Oh!  And in that row, they can''t have canceled in that month.

-- =COUNTIFS(F:F,F2,K:K,$A$2,I:I,"N")
-- =COUNTIFS(
--   F:F,F2,    -- What that row has in column F (processing_id) has what I have in column F.
--   K:K,$A$2,  -- What that row has in column K (year_month_num) has what''s in static cell $A$2.
--   I:I,"N")   -- What that row has in column I (cancelled_in_current_month) is a "N".

-- In the real output spreadhseet, it''s this:
-- =COUNTIFS(T:T,T2, W:W,$A$2, I:I,"N")
-- =COUNTIFS(
--   T:T,T2,    -- What that row has in column T (processing_id) has what I have in column T.
--   W:W,$A$2,  -- What that row has in column W (year_month_num) has what''s in static cell $A$2.
--   I:I,"N")   -- What that row has in column I (cancelled_in_current_month) is a "N".

-- After adding a column:
-- =COUNTIFS(V:V,V2,Y:Y,$A$2,I:I,"N")
