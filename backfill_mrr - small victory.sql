-- This is where we go get MRR from different places based on
-- what we have in history.
DROP TABLE tmp_data_dm.coe_jrr_sub_bills;
CREATE TABLE tmp_data_dm.coe_jrr_sub_bills AS
SELECT
   ord.customer_id
  ,ord.year_month
  ,ord.year_month_begin_date
  ,ord.product_subscription_id
  ,ord.product_line_id
  ,ord.product_type
  ,ord.has_ads
  ,ord.has_payment
  ,SUM(ord.mrr) AS mrr
  ,SUM(ord.block_count) AS block_count
  ,SUM(ord.revenue) AS revenue
FROM
(
    SELECT
       olaf.customer_id
      ,dt.year_month
      -- ,cast(olaf.yearmonth as int) AS year_month  -- LOOK
      ,dt.month_begin_date AS year_month_begin_date
      ,olaf.product_subscription_id
      ,olaf.product_line_id
      ,CASE WHEN olaf.product_line_id = 2 THEN 'Display'
            WHEN olaf.product_line_id = 7 THEN 'Sponsored Listing'
            WHEN olaf.product_line_id = 4 THEN 'Pro'
            WHEN olaf.product_line_id IN (10, 11) THEN 'Ignite'
            WHEN olaf.product_line_id IN (12, 15) THEN 'Website'
            WHEN olaf.product_line_id = 17  THEN 'Misc'
            WHEN olaf.order_line_number < 0 THEN 'Misc'
            WHEN olaf.product_line_id = 18 THEN 'Ad Placement'
            WHEN IFNULL(olaf.product_subscription_id, -1) <> -1 THEN 'Other Subscription'
            ELSE 'Other'
       END AS product_type
      ,CASE WHEN olaf.product_line_id IN (2, 7) THEN 'Y' ELSE 'N' END AS has_ads
      ,CASE WHEN olaf.order_line_payment_date NOT IN ('1900-01-01', '-1') THEN 'Y' ELSE 'N' END AS has_payment
      ,SUM(COALESCE(mrr.mrr_actual_value,0)) AS mrr
      ,SUM(olaf.block_count) AS block_count
      ,SUM(olaf.order_line_net_price_amount_usd) AS revenue
    FROM         dm.order_line_accumulation_fact olaf
      INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
    LEFT JOIN dm.mrr_subscription mrr ON mrr.subscription_id = olaf.product_subscription_id 
          AND mrr.yearmonth = CAST(from_unixtime(unix_timestamp(CAST(olaf.order_line_begin_date AS TIMESTAMP)), 'yyyyMM') AS INT)
    WHERE olaf.order_line_begin_date >= '2015-10-01'
      GROUP BY 1,2,3,4,5,6,7,8
UNION ALL
    SELECT
       olaf.customer_id
      ,dt.year_month
      -- ,cast(olaf.yearmonth as int) AS year_month  -- LOOK
      ,dt.month_begin_date AS year_month_begin_date
      ,olaf.product_subscription_id
      ,olaf.product_line_id
      ,CASE WHEN olaf.product_line_id = 2 THEN 'Display'
            WHEN olaf.product_line_id = 7 THEN 'Sponsored Listing'
            WHEN olaf.product_line_id = 4 THEN 'Pro'
            WHEN olaf.product_line_id IN (10, 11) THEN 'Ignite'
            WHEN olaf.product_line_id IN (12, 15) THEN 'Website'
            WHEN olaf.product_line_id = 17  THEN 'Misc'
            WHEN olaf.order_line_number < 0 THEN 'Misc'
            WHEN olaf.product_line_id = 18 THEN 'Ad Placement'
            WHEN IFNULL(olaf.product_subscription_id, -1) <> -1 THEN 'Other Subscription'
            ELSE 'Other'
       END AS product_type
      ,CASE WHEN olaf.product_line_id IN (2, 7) THEN 'Y' ELSE 'N' END AS has_ads
      ,CASE WHEN olaf.order_line_payment_date NOT IN ('1900-01-01', '-1') THEN 'Y' ELSE 'N' END AS has_payment
      ,SUM(100) as mrr  -- LOOK obviously wrong.
      ,SUM(olaf.block_count) AS block_count
      ,SUM(olaf.order_line_net_price_amount_usd) AS revenue
    FROM         dm.order_line_accumulation_fact olaf
      INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
    -- left join dm.mrr_subscription mrr on mrr.subscription_id = o.product_subscription_id 
    --       and mrr.yearmonth=cast(concat(cast(year(o.order_line_begin_date) as string), lpad(cast(month(o.order_line_begin_date) as string),2,'0')) as int)
    WHERE olaf.order_line_begin_date BETWEEN '2014-09-01' AND '2015-09-30'
      GROUP BY 1,2,3,4,5,6,7,8
UNION ALL
    SELECT
       olaf.customer_id
      ,dt.year_month
      -- ,cast(olaf.yearmonth as int) AS year_month  -- LOOK
      ,dt.month_begin_date AS year_month_begin_date
      ,olaf.product_subscription_id
      ,olaf.product_line_id
      ,CASE WHEN olaf.product_line_id = 2 THEN 'Display'
            WHEN olaf.product_line_id = 7 THEN 'Sponsored Listing'
            WHEN olaf.product_line_id = 4 THEN 'Pro'
            WHEN olaf.product_line_id IN (10, 11) THEN 'Ignite'
            WHEN olaf.product_line_id IN (12, 15) THEN 'Website'
            WHEN olaf.product_line_id = 17  THEN 'Misc'
            WHEN olaf.order_line_number < 0 THEN 'Misc'
            WHEN olaf.product_line_id = 18 THEN 'Ad Placement'
            WHEN IFNULL(olaf.product_subscription_id, -1) <> -1 THEN 'Other Subscription'
            ELSE 'Other'
       END AS product_type
      ,CASE WHEN olaf.product_line_id IN (2, 7) THEN 'Y' ELSE 'N' END AS has_ads
      ,CASE WHEN olaf.order_line_payment_date NOT IN ('1900-01-01', '-1') THEN 'Y' ELSE 'N' END AS has_payment
      ,SUM(100) as mrr  -- LOOK obviously wrong.
      ,SUM(olaf.block_count) AS block_count
      ,SUM(olaf.order_line_net_price_amount_usd) AS revenue
    FROM         dm.order_line_accumulation_fact olaf
      INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
    -- left join dm.mrr_subscription mrr on mrr.subscription_id = o.product_subscription_id 
    --       and mrr.yearmonth=cast(concat(cast(year(o.order_line_begin_date) as string), lpad(cast(month(o.order_line_begin_date) as string),2,'0')) as int)
    WHERE olaf.order_line_begin_date BETWEEN '2013-01-01' AND '2014-08-31'
      GROUP BY 1,2,3,4,5,6,7,8
) ord
GROUP BY 1,2,3,4,5,6,7,8

-- One row per (customer, billed month)
-- This is before the chain logic.
DROP TABLE tmp_data_dm.coe_jrr_cust_active_months;
CREATE TABLE tmp_data_dm.coe_jrr_cust_active_months AS
SELECT * FROM
  (
  SELECT
     bls.customer_id
    ,bls.year_month
    ,bls.year_month_begin_date
    ,MAX(bls.has_ads) AS     has_ads
    ,MAX(bls.has_payment) AS has_payment
    ,SUM(CASE WHEN bls.product_type IN ('Display', 'Sponsored Listing') THEN bls.revenue ELSE 0 END) AS revenue_current_advertisement
    ,SUM(CASE WHEN bls.product_type = 'Pro'                             THEN bls.revenue ELSE 0 END) AS revenue_current_avvopro
    ,SUM(CASE WHEN bls.product_type = 'Ignite'                          THEN bls.revenue ELSE 0 END) AS revenue_current_ignite
    ,SUM(CASE WHEN bls.product_type = 'Website'                         THEN bls.revenue ELSE 0 END) AS revenue_current_website
    ,SUM(CASE WHEN bls.product_type = 'Ad Placement'                    THEN bls.revenue ELSE 0 END) AS revenue_current_adplacement
    ,SUM(CASE WHEN bls.product_type = 'Misc'                            THEN bls.revenue ELSE 0 END) AS revenue_current_misc
    ,SUM(CASE WHEN bls.product_type = 'Other Subscription'              THEN bls.revenue ELSE 0 END) AS revenue_current_other_sub
    ,SUM(CASE WHEN bls.product_type = 'Other'                           THEN bls.revenue ELSE 0 END) AS revenue_current_other
    ,SUM(CASE WHEN bls.product_type NOT LIKE 'Other%'                   THEN bls.revenue ELSE 0 END) AS revenue_current_total
    ,SUM(CASE WHEN bls.product_type IN ('Display', 'Sponsored Listing') THEN bls.mrr     ELSE 0 END) AS mrr_current_advertisement
    ,SUM(CASE WHEN bls.product_type = 'Pro'                             THEN bls.mrr     ELSE 0 END) AS mrr_current_avvopro
    ,SUM(CASE WHEN bls.product_type = 'Ignite'                          THEN bls.mrr     ELSE 0 END) AS mrr_current_ignite
    ,SUM(CASE WHEN bls.product_type = 'Website'                         THEN bls.mrr     ELSE 0 END) AS mrr_current_website
    ,SUM(CASE WHEN bls.product_type = 'Ad Placement'                    THEN bls.mrr     ELSE 0 END) AS mrr_current_adplacement
    ,SUM(CASE WHEN bls.product_type = 'Other Subscription'              THEN bls.mrr     ELSE 0 END) AS mrr_current_other_sub
    ,SUM(CASE WHEN bls.product_type NOT LIKE 'Other%'                   THEN bls.mrr     ELSE 0 END) AS mrr_current_total
  -- LOOK probably need to add a third set of fields for potential churned mrr?  Or maybe that is not at this level.
  FROM tmp_data_dm.coe_jrr_sub_bills bls
  GROUP BY 1,2,3
  ) mth
-- WHERE mth.has_ads = 'Y' OR mth.mrr_current_total > 0  -- LOOK return to this
WHERE mth.has_ads = 'Y'

DROP TABLE tmp_data_dm.coe_jrr_cust_lifetime_start;
CREATE TABLE tmp_data_dm.coe_jrr_cust_lifetime_start AS
SELECT
   bls.customer_id
  ,MIN(bls.year_month) AS             start_month
  ,MIN(bls.year_month_begin_date) AS  start_month_begin_date
FROM tmp_data_dm.coe_jrr_cust_active_months bls
GROUP BY 1

-- Identify cohort for each customer
-- One row per customer per product_line_id.
-- This puts the first-billed month rows into their own table.
-- LOOK may not work to do this any more - think I need every chain start.
-- Leaving this for now so I can sanity-check.
DROP TABLE tmp_data_dm.coe_jrr_cust_start_month;
CREATE TABLE tmp_data_dm.coe_jrr_cust_start_month AS
SELECT
   cm.customer_id
  ,sm.start_month
  ,sm.start_month_begin_date
  ,cm.has_ads
  ,cm.has_payment
  ,cm.revenue_current_advertisement
  ,cm.revenue_current_avvopro
  ,cm.revenue_current_ignite
  ,cm.revenue_current_website
  ,cm.revenue_current_adplacement
  ,cm.revenue_current_misc
  ,cm.revenue_current_other_sub
  ,cm.revenue_current_other
  ,cm.revenue_current_total
  ,cm.mrr_current_advertisement
  ,cm.mrr_current_avvopro
  ,cm.mrr_current_ignite
  ,cm.mrr_current_website
  ,cm.mrr_current_adplacement
  ,cm.mrr_current_other_sub
  ,cm.mrr_current_total
FROM       tmp_data_dm.coe_jrr_cust_active_months cm
INNER JOIN tmp_data_dm.coe_jrr_cust_lifetime_start sm
  ON sm.start_month = cm.year_month 
 AND sm.customer_id = cm.customer_id 

-- Get the beginning values (counts and mrr) for each cohort
DROP TABLE tmp_data_dm.coe_jrr_cohort_active_customer;
CREATE TABLE tmp_data_dm.coe_jrr_cohort_active_customer AS
SELECT
   srt.start_month
  ,srt.start_month_begin_date
  ,SUM(srt.mrr_current_advertisement) AS mrr
  ,COUNT(DISTINCT srt.customer_id) AS customers
  ,SUM(srt.revenue_current_advertisement) AS revenue
FROM tmp_data_dm.coe_jrr_cust_start_month srt
WHERE srt.has_ads = 'Y'
GROUP BY 1,2

-- Strange characteristic of this table is that a customer's first
-- unbroken chain of months will always have chain_id = 1.
-- Other chain_ids are sortable (DESC), but they are not consecutive.
-- Probably eventually want to nest this to provide that.
DROP TABLE tmp_data_dm.coe_jrr_cust_chains;
CREATE TABLE tmp_data_dm.coe_jrr_cust_chains AS
SELECT
   chn.customer_id
  ,chn.start_month
  ,chn.start_month_begin_date
  ,CONCAT('M',LPAD(CAST(chn.tenure_month AS string),2,'0')) AS tenure_period
  ,chn.tenure_month
  ,chn.year_month
  ,chn.year_month_begin_date
  ,chn.has_ads
  ,chn.has_payment
  ,chn.revenue_current_advertisement
  ,chn.revenue_current_avvopro
  ,chn.revenue_current_ignite
  ,chn.revenue_current_website
  ,chn.revenue_current_adplacement
  ,chn.revenue_current_misc
  ,chn.revenue_current_other_sub
  ,chn.revenue_current_other
  ,chn.revenue_current_total
  ,chn.mrr_current_advertisement
  ,chn.mrr_current_avvopro
  ,chn.mrr_current_ignite
  ,chn.mrr_current_website
  ,chn.mrr_current_adplacement
  ,chn.mrr_current_other_sub
  ,chn.mrr_current_total
  ,DENSE_RANK() OVER(PARTITION BY chn.customer_id
                         ORDER BY chn.tenure_month) AS rnk  -- LOOK lose this later.
  ,DENSE_RANK() OVER(PARTITION BY chn.customer_id
                         ORDER BY chn.tenure_month) - chn.tenure_month AS chain_id
FROM
  (
  SELECT
     nc.customer_id
    ,nc.start_month
    ,nc.start_month_begin_date
    ,(FLOOR(future.year_month/100)-FLOOR(nc.start_month/100)) * 12 +
           (future.year_month%100-       nc.start_month%100) AS tenure_month
    ,future.year_month
    ,future.year_month_begin_date
    ,future.has_ads
    ,future.has_payment
    ,future.revenue_current_advertisement
    ,future.revenue_current_avvopro
    ,future.revenue_current_ignite
    ,future.revenue_current_website
    ,future.revenue_current_adplacement
    ,future.revenue_current_misc
    ,future.revenue_current_other_sub
    ,future.revenue_current_other
    ,future.revenue_current_total
    ,future.mrr_current_advertisement
    ,future.mrr_current_avvopro
    ,future.mrr_current_ignite
    ,future.mrr_current_website
    ,future.mrr_current_adplacement
    ,future.mrr_current_other_sub
    ,future.mrr_current_total
  FROM        tmp_data_dm.coe_jrr_cust_start_month nc
    LEFT JOIN tmp_data_dm.coe_jrr_cust_active_months future 
           ON nc.customer_id = future.customer_id 
          AND nc.start_month <= future.year_month 
          AND future.year_month < 201610
  ) chn


-- Join from cohort start table to every month that the customer got billed in.
-- This is the main query.
-- I will have to change this a bunch because I want customer_id.
DROP TABLE tmp_data_dm.coe_jrr_cohort_months;
CREATE TABLE tmp_data_dm.coe_jrr_cohort_months AS
SELECT
   x.start_month
  ,CONCAT('M',LPAD(CAST(x.tenure_month AS string),2,'0')) AS tenure_month  -- M1, M2, ...
  ,x.year_month
  ,x.new_customers
  ,x.new_mrr
  ,x.new_revenue
  ,x.retained_customers
  ,x.retained_mrr
  ,x.retained_revenue
FROM
  (
    SELECT
       chn.start_month
      ,chn.start_month_begin_date
      ,chn.tenure_month
      ,chn.year_month
      ,chn.year_month_begin_date
      -- maybe don''t have to do these because I have them in cac - then i could just union?  think I am ok.
      -- only reason for max is they are always same value and we want to just grab 1.
      ,MAX(cac.customers) AS                       new_customers
      ,MAX(cac.mrr) AS                             new_mrr
      ,MAX(cac.revenue) AS                         new_revenue
      ,COUNT(DISTINCT chn.customer_id) AS          retained_customers
      ,SUM(chn.mrr_current_advertisement) AS       retained_mrr
      ,SUM(chn.revenue_current_advertisement) AS   retained_revenue
    FROM tmp_data_dm.coe_jrr_cust_chains chn
    LEFT JOIN tmp_data_dm.coe_jrr_cohort_active_customer cac 
           ON chn.start_month = cac.start_month 
    WHERE chn.chain_id = 1
      AND chn.tenure_month IS NOT NULL
      AND chn.has_ads = 'Y'
    GROUP BY 1,2,3,4,5
  ) x

-- This reshapes things,
-- and fills in months if the prior query has lost all the customers
-- as of a certain month, but we still want 0 rows in the results so 
-- it looks right (and rolls up right).
-- Probably don''t even need this if I am producing output for every customer.
-- This just shows new and retained.
-- She calculates churned in tableau.
DROP TABLE tmp_data_dm.coe_jrr_final;
CREATE TABLE tmp_data_dm.coe_jrr_final AS
SELECT zz.* 
FROM
(
  SELECT z.start_month
    , z.tenure_month
    , z.year_month
    , FIRST_VALUE(z.new_customers)      OVER (PARTITION BY z.start_month ORDER BY z.tenure_month) AS new_customers
    , z.retained_customers
    , FIRST_VALUE(z.new_mrr)            OVER (PARTITION BY z.start_month ORDER BY z.tenure_month) AS new_mrr
    , z.retained_mrr
    , FIRST_VALUE(z.new_revenue)        OVER (PARTITION BY z.start_month ORDER BY z.tenure_month) AS new_revenue
    , z.retained_revenue
  FROM
  (
    SELECT y.start_month
      , y.tenure_month
      , y.year_month
      , SUM(y.new_customers) AS new_customers
      , SUM(y.retained_customers) AS retained_customers
      , SUM(y.new_mrr) AS new_mrr
      , SUM(y.retained_mrr) AS retained_mrr
      , SUM(y.new_revenue) AS new_revenue
      , SUM(y.retained_revenue) AS retained_revenue
    FROM
    (
      -- This part just gets you zero-billed months rows 
      SELECT DISTINCT start_month
        , tenure_month 
        , year_month
        , 0 AS new_customers
        , 0 AS retained_customers
        , 0 AS new_mrr
        , 0 AS retained_mrr
        , 0 AS new_revenue
        , 0 AS retained_revenue
      FROM 
      (
        SELECT DISTINCT ym.start_month
          ,  CONCAT('M',LPAD(CAST(ym.tenure_month AS STRING),2,'0')) AS tenure_month
          , ym.year_month
        FROM
        (
          SELECT DISTINCT x1.year_month AS start_month
            , x2.year_month
            , (cast(substring(cast(x2.year_month as string), 1,4) as int)-cast(substring(cast(x1.year_month as string), 1,4) as int))*12
                  + (cast(substring(cast(x2.year_month as string), 5,2) as int)-cast(substring(cast(x1.year_month as string), 5,2) as int)) as tenure_month
          FROM dm.date_dim x1
          JOIN dm.date_dim x2 ON x1.year_month<=x2.year_month  
          WHERE x1.year_month BETWEEN 201303 AND 201610
            AND x2.year_month BETWEEN 201303 AND 201610
        ) ym
      ) x

      UNION ALL

      SELECT start_month
        , tenure_month
        , year_month
        , new_customers
        , retained_customers 
        , new_mrr
        , retained_mrr
        , new_revenue
        , retained_revenue
      FROM tmp_data_dm.coe_jrr_cohort_months
    ) y
    GROUP BY 1,2,3
  ) z
) zz
WHERE zz.new_customers > 0
  AND zz.start_month < 201610


SELECT * FROM tmp_data_dm.coe_jrr_final
WHERE start_month >= 201304
