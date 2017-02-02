-- Get the MRR for every subscription that exists.
-- This will only be used for the in-between time period:
-- recent enough that we have a subscription to join to,
-- but not so recent that we actually have mrr data already.
DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_sub_price ;
CREATE TABLE tmp_data_dm.coe_jrr_sub_price AS
SELECT DISTINCT
   subscription_id
  ,full_price
FROM   (
       SELECT 
          subscription_id 
         ,ROUND(CAST(unit_price AS DECIMAL(20,2)) * block_count / 100, 2) AS full_price
         ,RANK() OVER(PARTITION BY subscription_id
                          ORDER BY start_datetime DESC
                     ) seq 
       FROM dm.subscription_price_dimension
       -- WHERE unit_price <> 0
       ) AS spd_curr 
WHERE seq = 1 ;

-- Prior to 201409, we cannot join to subscription dimension,
-- so we just have to take what we can get from olaf.
-- And comment from Jane:
-- There was a billing system update in Aug 2014. Before that, the 
-- begin_use_date for all orders is always the first day of the month 
-- regardless of whether the order actually started from the middle 
-- of the month.  Therefore we can’t get full price based on the 
-- already prorated net amount and the begin_use_date, so I threw 
-- in the logic to check next month’s net amount in the hope that 
-- the next month’s net amount is a good estimation of the 
-- unprorated amount of the current month.

-- Subtle difference at a monthly level between is_active_eom, which means
-- were they active as of the end of the month, and is_active_during_month,
-- meaning were they active on at least one day (and therefore should be 
-- included in chains).
--   has_ads_during_month:    was billed in the month for an ad product.
--   has_ads_eom:             was billed in the month for an ad product which expires after EoM.
--   potential_mrr:           (potential) mrr for all subscriptions 
--                            they were billed for in the month.
--                            Pretty sure I do not need to carry this through farther than cust_months.
--   mrr:                     mrr for all subscriptions they were 
--                            billed for in the month which expire
--                            after EoM.
-- At customer level only:
--   is_active_during_month:  has ads during the month and has non-zero potential MRR (does not have to be the same sub)
--   is_active_eom:           has ads as of EoM and has non-zero MRR (does not have to be the same sub)


-- This is where we go get MRR from different places based on
-- what we have in history.
DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_sub_bills ;
CREATE TABLE tmp_data_dm.coe_jrr_sub_bills AS
SELECT
   uns.customer_id
  ,uns.year_month
  ,uns.year_month_begin_date
  ,uns.mrr_method
  ,uns.product_subscription_id AS subscription_id
  ,uns.product_line_id
  ,CASE WHEN uns.product_line_id = 2 THEN 'Display'
        WHEN uns.product_line_id = 7 THEN 'Sponsored Listing'
        WHEN uns.product_line_id = 4 THEN 'Pro'
        WHEN uns.product_line_id IN (10, 11) THEN 'Ignite'
        WHEN uns.product_line_id IN (12, 15) THEN 'Website'
        WHEN uns.product_line_id = 17  THEN 'Misc'
        WHEN uns.order_line_number < 0 THEN 'Misc'
        WHEN uns.product_line_id = 18 THEN 'Ad Placement'
        WHEN IFNULL(uns.product_subscription_id, -1) <> -1 THEN 'Other Subscription'
        ELSE 'Other'
   END AS                                                                      product_type
  ,CASE WHEN uns.product_line_id IN (2, 7) THEN 'Y' ELSE 'N' END AS            has_ads_during_month
  ,CASE WHEN uns.product_line_id IN (2, 7) AND
             IFNULL(uns.max_expired_date, '2999-01-01') > uns.year_month_end_date THEN 'Y' ELSE 'N' END AS has_ads_eom
  -- Note: the only orders I see with non-zero revenue and no payment are refunds.
  ,CASE WHEN uns.order_line_payment_date NOT IN ('1900-01-01', '-1') 
         AND uns.order_line_net_price_amount_usd > 0 THEN 'Y' ELSE 'N' END AS  had_payment
  ,SUM(uns.full_price) AS                                                      potential_mrr
  ,CAST(SUM(CASE WHEN IFNULL(uns.max_expired_date, '2999-01-01') > uns.year_month_end_date THEN uns.full_price
              ELSE 0 END) AS DECIMAL(20,2)) AS                                 mrr
  ,MAX(CASE WHEN IFNULL(uns.max_expired_date, '2999-01-01') > uns.year_month_end_date THEN 'Y' 
            ELSE 'N' END) AS                                                   sub_continues_past_month
  ,SUM(uns.block_count) AS                                                     block_count
  ,CAST(SUM(CASE WHEN uns.order_line_payment_date NOT IN ('1900-01-01', '-1') THEN uns.order_line_net_price_amount_usd 
              ELSE 0 END) AS DECIMAL(20,2)) AS                                 revenue
  -- ,SUM(uns.order_line_net_price_amount_usd) AS revenue
  ,MAX(uns.order_line_begin_date) AS                                           max_bill_date_in_month
  ,MAX(uns.had_cc_failure) AS                                                  had_cc_failure
  -- ,MAX(uns.promo_flag)  AS                                                     promo_flag
  ,MAX(CAST(NULL AS STRING))  AS                                               promo_flag
  -- ,MAX(uns.max_expired_date) AS       max_expired_date
FROM
  (
      SELECT
         olaf.*
        ,'MRR with phase 2 base code' AS mrr_method
        ,dt.year_month
        ,dt.month_begin_date AS year_month_begin_date
        ,dt.month_end_date AS year_month_end_date
        -- ,IFNULL(mrr.mrr, 0) AS full_price                  LOOK
        ,IFNULL(mrr.mrr_actual, 0) AS full_price
        ,GREATEST(CASE WHEN olaf.order_line_cancelled_date = '-1' THEN NULL ELSE olaf.order_line_cancelled_date END
                 ,mrr.expired_date) AS max_expired_date
        ,CASE WHEN LOWER(mrr.expired_reason) = 'failed cc' THEN 'Y' ELSE 'N' END AS had_cc_failure
      FROM         dm.order_line_accumulation_fact olaf
        INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
        LEFT OUTER JOIN dm.mrr_subscription_all_products mrr
                ON olaf.product_subscription_id = mrr.subscription_id
               AND olaf.product_subscription_id <> -1
               AND dt.year_month = mrr.yearmonth
      WHERE olaf.order_line_begin_date >= '2015-10-01'
  UNION ALL
      SELECT
         olaf.*
        ,'Subscription Price' AS mrr_method
        ,dt.year_month
        ,dt.month_begin_date AS year_month_begin_date
        ,dt.month_end_date AS year_month_end_date
        ,IFNULL(mrr.full_price, 0) AS full_price
        ,GREATEST(CASE WHEN olaf.order_line_cancelled_date = '-1' THEN NULL ELSE olaf.order_line_cancelled_date END
                 ,CASE WHEN sub.expire_datetime = '1900-01-01'  THEN NULL ELSE sub.expire_datetime END) AS max_expired_date
        ,CASE WHEN LOWER(sub.expired_reason) = 'failed cc' THEN 'Y' ELSE 'N' END AS had_cc_failure
      FROM         dm.order_line_accumulation_fact olaf
        INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
        LEFT OUTER JOIN dm.subscription_dimension sub
                ON olaf.product_subscription_id = sub.subscription_id
        LEFT OUTER JOIN tmp_data_dm.coe_jrr_sub_price mrr
                ON olaf.product_subscription_id = mrr.subscription_id
      WHERE olaf.order_line_begin_date BETWEEN '2014-09-01' AND '2015-09-30'
  UNION ALL
      SELECT
         olaf.*
        ,'Order Line' AS mrr_method   
        ,dt.year_month
        ,dt.month_begin_date AS year_month_begin_date
        ,dt.month_end_date AS year_month_end_date
        -- Un-prorate if we can, but this will not do anything for older orders.
        -- Have to address them later at the customer level.
        ,CASE WHEN olaf.order_line_payment_date = '-1' 
                THEN 0
              WHEN olaf.order_line_net_price_amount_usd < 0
                THEN 0
              WHEN DAY(olaf.order_line_begin_date) = 1 
                THEN olaf.order_line_net_price_amount_usd
              WHEN DAY(olaf.order_line_begin_date) = mth.day_in_month_count 
                THEN olaf.order_line_net_price_amount_usd * mth.day_in_month_count
                ELSE olaf.order_line_net_price_amount_usd * mth.day_in_month_count
                     /
                     (mth.day_in_month_count - DAY(olaf.order_line_begin_date))
         END AS full_price      
        ,CASE WHEN olaf.order_line_cancelled_date = '-1' THEN NULL ELSE olaf.order_line_cancelled_date END AS max_expired_date
        ,NULL AS had_cc_failure
      FROM         dm.order_line_accumulation_fact olaf
        INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
        INNER JOIN dm.month_dim mth ON dt.year_month = mth.year_month
      WHERE olaf.order_line_begin_date BETWEEN '2013-01-01' AND '2014-08-31'  -- LOOK
      -- WHERE olaf.order_line_begin_date >= '2013-01-01'
  ) uns
GROUP BY 1,2,3,4,5,6,7,8,9,10 ;

-- One row per (customer, billed month)
-- This is before the chain logic.
-- It also includes some rows with only revenue, which get filtered
-- out when creating chains.
DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_months ;
CREATE TABLE tmp_data_dm.coe_jrr_cust_months AS
SELECT
   CASE WHEN mth.has_ads_during_month = 'Y' OR mth.potential_mrr_total > 0 THEN 'Y' ELSE 'N' END AS is_active_during_month
  ,CASE WHEN mth.has_ads_eom = 'Y'          OR mth.mrr_current_total > 0   THEN 'Y' ELSE 'N' END AS is_active_eom
  ,*
FROM
  (
  SELECT
     bls.customer_id
    ,bls.year_month
    ,bls.year_month_begin_date
    ,bls.mrr_method
    ,MAX(bls.has_ads_during_month) AS      has_ads_during_month
    ,MAX(bls.has_ads_eom) AS               has_ads_eom
    ,MAX(bls.had_payment) AS               had_payment
    ,MAX(bls.max_bill_date_in_month) AS    max_bill_date_in_month
    ,MAX(bls.had_cc_failure) AS            had_cc_failure
    ,MAX(bls.promo_flag) AS                promo_flag
    ,MAX(bls.sub_continues_past_month) AS  customer_continues_past_month
    -- Note: we have things that look like ads prior to 2015-10 but
    -- product_line_id = -1.  I am going to call that MRR, but leave
    -- has_ads = 'N' because legacy code excluded them.
    ,CAST(SUM(CASE WHEN bls.product_type IN ('Display', 'Sponsored Listing') THEN bls.revenue ELSE 0 END) AS DECIMAL(20,2)) AS revenue_current_advertisement
    ,CAST(SUM(CASE WHEN bls.product_type = 'Pro'                             THEN bls.revenue ELSE 0 END) AS DECIMAL(20,2)) AS revenue_current_avvopro
    ,CAST(SUM(CASE WHEN bls.product_type = 'Ignite'                          THEN bls.revenue ELSE 0 END) AS DECIMAL(20,2)) AS revenue_current_ignite
    ,CAST(SUM(CASE WHEN bls.product_type = 'Website'                         THEN bls.revenue ELSE 0 END) AS DECIMAL(20,2)) AS revenue_current_website
    ,CAST(SUM(CASE WHEN bls.product_type = 'Ad Placement'                    THEN bls.revenue ELSE 0 END) AS DECIMAL(20,2)) AS revenue_current_adplacement
    ,CAST(SUM(CASE WHEN bls.product_type = 'Misc'                            THEN bls.revenue ELSE 0 END) AS DECIMAL(20,2)) AS revenue_current_misc
    ,CAST(SUM(CASE WHEN bls.product_type = 'Other Subscription'              THEN bls.revenue ELSE 0 END) AS DECIMAL(20,2)) AS revenue_current_other_sub
    ,CAST(SUM(CASE WHEN bls.product_type = 'Other'                           THEN bls.revenue ELSE 0 END) AS DECIMAL(20,2)) AS revenue_current_other
    ,CAST(SUM(                                                                    bls.revenue           ) AS DECIMAL(20,2)) AS revenue_current_total
    ,CAST(SUM(CASE WHEN bls.product_type IN ('Display', 'Sponsored Listing') THEN bls.mrr     ELSE 0 END) AS DECIMAL(20,2)) AS mrr_current_advertisement
    ,CAST(SUM(CASE WHEN bls.product_type = 'Pro'                             THEN bls.mrr     ELSE 0 END) AS DECIMAL(20,2)) AS mrr_current_avvopro
    ,CAST(SUM(CASE WHEN bls.product_type = 'Ignite'                          THEN bls.mrr     ELSE 0 END) AS DECIMAL(20,2)) AS mrr_current_ignite
    ,CAST(SUM(CASE WHEN bls.product_type = 'Website'                         THEN bls.mrr     ELSE 0 END) AS DECIMAL(20,2)) AS mrr_current_website
    ,CAST(SUM(CASE WHEN bls.product_type = 'Ad Placement'                    THEN bls.mrr     ELSE 0 END) AS DECIMAL(20,2)) AS mrr_current_adplacement
    ,CAST(SUM(CASE WHEN bls.product_type = 'Other Subscription'              THEN bls.mrr     ELSE 0 END) AS DECIMAL(20,2)) AS mrr_current_other_sub
    ,CAST(SUM(CASE WHEN bls.product_type NOT IN ('Misc', 'Other')            THEN bls.mrr     ELSE 0 END) AS DECIMAL(20,2)) AS mrr_current_total
    ,CAST(SUM(CASE WHEN bls.product_type NOT IN ('Misc', 'Other')      THEN bls.potential_mrr ELSE 0 END) AS DECIMAL(20,2)) AS potential_mrr_total
  FROM tmp_data_dm.coe_jrr_sub_bills bls
  GROUP BY 1,2,3,4
  ) mth
WHERE mth.has_ads_during_month = 'Y' OR mth.potential_mrr_total > 0 OR mth.revenue_current_total <> 0 ;

DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_lifetime_start ;
-- Note: we are NOT going to change lifetime start to has to have
-- a payment.  I am going to provide a flag in the final data pull,
-- because we kinda want to know how much it happens.
CREATE TABLE tmp_data_dm.coe_jrr_cust_lifetime_start AS
SELECT
   bls.customer_id
  ,MIN(bls.year_month) AS             start_month
  ,MIN(bls.year_month_begin_date) AS  start_month_begin_date
  ,MIN(CASE WHEN bls.had_payment = 'Y' THEN bls.year_month ELSE NULL END) AS first_payment_month
  -- ,MIN(CASE WHEN bls.had_payment = 'Y' THEN bls.year_month_begin_date ELSE NULL END) AS  first_payment_month_begin_date
FROM tmp_data_dm.coe_jrr_cust_months bls
WHERE bls.is_active_during_month = 'Y'
GROUP BY 1 ;

-- Note: nested queries with complicated window functions started
-- arbitrarily failing so I split this into chunks.

DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_chains_raw1 ;
CREATE TABLE tmp_data_dm.coe_jrr_cust_chains_raw1
(
   customer_id                    INT
  ,start_month                    INT
  ,start_month_begin_date         STRING
  ,tenure_month                   BIGINT
  -- ,year_month                     INT
  ,year_month_begin_date          STRING
  ,is_active_during_month         STRING
  ,is_active_eom                  STRING
  ,had_payment                    STRING
  ,has_ads_during_month           STRING
  ,has_ads_eom                    STRING
  ,mrr_method                     STRING
  ,max_bill_date_in_month         STRING
  ,had_cc_failure                 STRING
  ,promo_flag                     STRING
  ,customer_continues_past_month  STRING
  ,revenue_current_advertisement  DECIMAL(20,2)
  ,revenue_current_avvopro        DECIMAL(20,2)
  ,revenue_current_ignite         DECIMAL(20,2)
  ,revenue_current_website        DECIMAL(20,2)
  ,revenue_current_adplacement    DECIMAL(20,2)
  ,revenue_current_misc           DECIMAL(20,2)
  ,revenue_current_other_sub      DECIMAL(20,2)
  ,revenue_current_other          DECIMAL(20,2)
  ,revenue_current_total          DECIMAL(20,2)
  ,mrr_current_advertisement      DECIMAL(20,2)
  ,mrr_current_avvopro            DECIMAL(20,2)
  ,mrr_current_ignite             DECIMAL(20,2)
  ,mrr_current_website            DECIMAL(20,2)
  ,mrr_current_adplacement        DECIMAL(20,2)
  ,mrr_current_other_sub          DECIMAL(20,2)
  ,mrr_current_total              DECIMAL(20,2)
)
PARTITIONED BY (year_month INT)
STORED AS PARQUET ;
WITH table_src AS
(
SELECT
   nc.customer_id
  ,nc.start_month
  ,nc.start_month_begin_date
  ,1+(FLOOR(future.year_month/100)-FLOOR(nc.start_month/100)) * 12 +
           (future.year_month%100-       nc.start_month%100) AS tenure_month  -- LOOK tenure_month done
  ,future.year_month
  ,future.year_month_begin_date
  ,future.is_active_during_month
  ,future.is_active_eom
  ,future.had_payment
  ,future.has_ads_during_month
  ,future.has_ads_eom
  ,future.mrr_method
  ,future.max_bill_date_in_month
  ,future.had_cc_failure
  ,future.promo_flag
  ,future.customer_continues_past_month
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
FROM        tmp_data_dm.coe_jrr_cust_lifetime_start nc
  LEFT JOIN tmp_data_dm.coe_jrr_cust_months future 
         ON nc.customer_id = future.customer_id 
        AND nc.start_month <= future.year_month 
        AND future.year_month <= 201610
WHERE future.is_active_during_month = 'Y'
)
INSERT OVERWRITE TABLE tmp_data_dm.coe_jrr_cust_chains_raw1 PARTITION(year_month)
SELECT
   customer_id
  ,start_month
  ,start_month_begin_date
  ,tenure_month
  ,year_month_begin_date
  ,is_active_during_month
  ,is_active_eom
  ,had_payment
  ,has_ads_during_month
  ,has_ads_eom
  ,mrr_method
  ,max_bill_date_in_month
  ,had_cc_failure
  ,promo_flag
  ,customer_continues_past_month
  ,revenue_current_advertisement
  ,revenue_current_avvopro
  ,revenue_current_ignite
  ,revenue_current_website
  ,revenue_current_adplacement
  ,revenue_current_misc
  ,revenue_current_other_sub
  ,revenue_current_other
  ,revenue_current_total
  ,mrr_current_advertisement
  ,mrr_current_avvopro
  ,mrr_current_ignite
  ,mrr_current_website
  ,mrr_current_adplacement
  ,mrr_current_other_sub
  ,mrr_current_total
  ,year_month
FROM table_src ;
COMPUTE INCREMENTAL STATS tmp_data_dm.coe_jrr_cust_chains_raw1 ;


DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_chains_raw2 ;
CREATE TABLE tmp_data_dm.coe_jrr_cust_chains_raw2
(
   customer_id                    INT
  ,start_month                    INT
  ,start_month_begin_date         STRING
  ,tenure_month                   BIGINT
  ,year_month_begin_date          STRING
  ,is_active_during_month         STRING
  ,is_active_eom                  STRING
  ,had_payment                    STRING
  ,has_ads_during_month           STRING
  ,has_ads_eom                    STRING
  ,mrr_method                     STRING
  ,max_bill_date_in_month         STRING
  ,had_cc_failure                 STRING
  ,promo_flag                     STRING
  ,customer_continues_past_month  STRING
  ,revenue_current_advertisement  DECIMAL(20,2)
  ,revenue_current_avvopro        DECIMAL(20,2)
  ,revenue_current_ignite         DECIMAL(20,2)
  ,revenue_current_website        DECIMAL(20,2)
  ,revenue_current_adplacement    DECIMAL(20,2)
  ,revenue_current_misc           DECIMAL(20,2)
  ,revenue_current_other_sub      DECIMAL(20,2)
  ,revenue_current_other          DECIMAL(20,2)
  ,revenue_current_total          DECIMAL(20,2)
  ,mrr_current_advertisement      DECIMAL(20,2)
  ,mrr_current_avvopro            DECIMAL(20,2)
  ,mrr_current_ignite             DECIMAL(20,2)
  ,mrr_current_website            DECIMAL(20,2)
  ,mrr_current_adplacement        DECIMAL(20,2)
  ,mrr_current_other_sub          DECIMAL(20,2)
  ,mrr_current_total              DECIMAL(20,2)
  -- ,year_month                     INT
  ,chain_id_raw                     BIGINT
  ,rnk                              BIGINT
  ,active_months_to_date            BIGINT
  ,tenure_month_prior               BIGINT
  ,is_active_during_month_prior     STRING  -- LOOK strongly suspect I do not need all of these.
  ,is_active_eom_prior              STRING
  ,had_payment_prior                STRING
  ,has_ads_during_month_prior       STRING
  ,has_ads_eom_prior                STRING
  ,customer_continues_past_month_prior STRING
  ,customer_prev_billed_date        STRING
  ,revenue_prior_advertisement      DECIMAL(20,2)
  ,revenue_prior_avvopro            DECIMAL(20,2)
  ,revenue_prior_ignite             DECIMAL(20,2)
  ,revenue_prior_website            DECIMAL(20,2)
  ,revenue_prior_adplacement        DECIMAL(20,2)
  ,revenue_prior_misc               DECIMAL(20,2)
  ,revenue_prior_other_sub          DECIMAL(20,2)
  ,revenue_prior_other              DECIMAL(20,2)
  ,revenue_prior_total              DECIMAL(20,2)
  ,mrr_prior_advertisement          DECIMAL(20,2)
  ,mrr_prior_avvopro                DECIMAL(20,2)
  ,mrr_prior_ignite                 DECIMAL(20,2)
  ,mrr_prior_website                DECIMAL(20,2)
  ,mrr_prior_adplacement            DECIMAL(20,2)
  ,mrr_prior_other_sub              DECIMAL(20,2)
  ,mrr_prior_total                  DECIMAL(20,2)
  ,mrr_next_advertisement           DECIMAL(20,2)
  ,mrr_next_avvopro                 DECIMAL(20,2)
  ,mrr_next_ignite                  DECIMAL(20,2)
  ,mrr_next_website                 DECIMAL(20,2)
  ,mrr_next_adplacement             DECIMAL(20,2)
  ,mrr_next_other_sub               DECIMAL(20,2)
  ,mrr_next_total                   DECIMAL(20,2)
)
PARTITIONED BY (year_month INT)
STORED AS PARQUET ;
WITH table_src AS
(
SELECT
   mth.*
  ,DENSE_RANK()    OVER(PARTITION BY mth.customer_id
                            ORDER BY mth.tenure_month) - mth.tenure_month AS chain_id_raw  -- LOOK tenure_month ok
  ,DENSE_RANK()    OVER(PARTITION BY mth.customer_id
                            ORDER BY mth.tenure_month) AS rnk
  -- Note that this active months count is imperfect.  Same-month signup and cancel will count,
  -- while technically it shouldn't.
  -- I should probably solve this.
  ,ROW_NUMBER()    OVER(PARTITION BY mth.customer_id
                            ORDER BY mth.tenure_month) AS active_months_to_date
  ,LAG(mth.tenure_month)                  OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS tenure_month_prior
  ,LAG(mth.is_active_during_month)        OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS is_active_during_month_prior
  ,LAG(mth.is_active_eom)                 OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS is_active_eom_prior
  ,LAG(mth.had_payment)                   OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS had_payment_prior
  ,LAG(mth.has_ads_during_month)          OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS has_ads_during_month_prior
  ,LAG(mth.has_ads_eom)                   OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS has_ads_eom_prior
  ,LAG(mth.customer_continues_past_month) OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS customer_continues_past_month_prior
  ,LAG(mth.max_bill_date_in_month)        OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS customer_prev_billed_date
  ,LAG(mth.revenue_current_advertisement) OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS revenue_prior_advertisement
  ,LAG(mth.revenue_current_avvopro)       OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS revenue_prior_avvopro
  ,LAG(mth.revenue_current_ignite)        OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS revenue_prior_ignite
  ,LAG(mth.revenue_current_website)       OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS revenue_prior_website
  ,LAG(mth.revenue_current_adplacement)   OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS revenue_prior_adplacement
  ,LAG(mth.revenue_current_misc)          OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS revenue_prior_misc
  ,LAG(mth.revenue_current_other_sub)     OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS revenue_prior_other_sub
  ,LAG(mth.revenue_current_other)         OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS revenue_prior_other
  ,LAG(mth.revenue_current_total)         OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS revenue_prior_total
  ,LAG(mth.mrr_current_advertisement)     OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS mrr_prior_advertisement
  ,LAG(mth.mrr_current_avvopro)           OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS mrr_prior_avvopro
  ,LAG(mth.mrr_current_ignite)            OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS mrr_prior_ignite
  ,LAG(mth.mrr_current_website)           OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS mrr_prior_website
  ,LAG(mth.mrr_current_adplacement)       OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS mrr_prior_adplacement
  ,LAG(mth.mrr_current_other_sub)         OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS mrr_prior_other_sub
  ,LAG(mth.mrr_current_total)             OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS mrr_prior_total
  ,LEAD(mth.mrr_current_advertisement)    OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS mrr_next_advertisement
  ,LEAD(mth.mrr_current_avvopro)          OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS mrr_next_avvopro
  ,LEAD(mth.mrr_current_ignite)           OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS mrr_next_ignite
  ,LEAD(mth.mrr_current_website)          OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS mrr_next_website
  ,LEAD(mth.mrr_current_adplacement)      OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS mrr_next_adplacement
  ,LEAD(mth.mrr_current_other_sub)        OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS mrr_next_other_sub
  ,LEAD(mth.mrr_current_total)            OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS mrr_next_total
FROM tmp_data_dm.coe_jrr_cust_chains_raw1 mth
)
INSERT OVERWRITE TABLE tmp_data_dm.coe_jrr_cust_chains_raw2 PARTITION(year_month)
SELECT
   customer_id
  ,start_month
  ,start_month_begin_date
  ,tenure_month
  ,year_month_begin_date
  ,is_active_during_month
  ,is_active_eom
  ,had_payment
  ,has_ads_during_month
  ,has_ads_eom
  ,mrr_method
  ,max_bill_date_in_month
  ,had_cc_failure
  ,promo_flag
  ,customer_continues_past_month
  ,revenue_current_advertisement
  ,revenue_current_avvopro
  ,revenue_current_ignite
  ,revenue_current_website
  ,revenue_current_adplacement
  ,revenue_current_misc
  ,revenue_current_other_sub
  ,revenue_current_other
  ,revenue_current_total
  ,mrr_current_advertisement
  ,mrr_current_avvopro
  ,mrr_current_ignite
  ,mrr_current_website
  ,mrr_current_adplacement
  ,mrr_current_other_sub
  ,mrr_current_total
  ,chain_id_raw
  ,rnk
  ,active_months_to_date
  ,tenure_month_prior
  ,is_active_during_month_prior
  ,is_active_eom_prior
  ,had_payment_prior
  ,has_ads_during_month_prior
  ,has_ads_eom_prior
  ,customer_continues_past_month_prior
  ,customer_prev_billed_date
  ,revenue_prior_advertisement
  ,revenue_prior_avvopro
  ,revenue_prior_ignite
  ,revenue_prior_website
  ,revenue_prior_adplacement
  ,revenue_prior_misc
  ,revenue_prior_other_sub
  ,revenue_prior_other
  ,revenue_prior_total
  ,mrr_prior_advertisement
  ,mrr_prior_avvopro
  ,mrr_prior_ignite
  ,mrr_prior_website
  ,mrr_prior_adplacement
  ,mrr_prior_other_sub
  ,mrr_prior_total
  ,mrr_next_advertisement
  ,mrr_next_avvopro
  ,mrr_next_ignite
  ,mrr_next_website
  ,mrr_next_adplacement
  ,mrr_next_other_sub
  ,mrr_next_total
  ,year_month
FROM table_src ;
COMPUTE INCREMENTAL STATS tmp_data_dm.coe_jrr_cust_chains_raw2 ;


DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_chains ;
CREATE TABLE tmp_data_dm.coe_jrr_cust_chains
(
   customer_id                      INT
  ,year_month                       INT
  ,year_month_begin_date            STRING
  ,chain_id_raw                     BIGINT
  ,chain_number                     BIGINT
  ,tenure_month_chain               BIGINT
  ,tenure_month_lifetime            BIGINT
  ,active_months_to_date            BIGINT
  -- ,start_month_chain                INT
  ,start_month_begin_date_chain     STRING
  ,start_month_lifetime             INT
  ,start_month_begin_date_lifetime  STRING
  ,is_active_during_month           STRING
  ,is_active_eom                    STRING
  ,had_payment                      STRING
  ,has_ads_during_month             STRING
  ,has_ads_eom                      STRING
  ,customer_exists_prior_month      STRING
  ,mrr_method                       STRING
  ,max_bill_date_in_month           STRING
  ,had_cc_failure                   STRING
  ,promo_flag                       STRING
  -- ,customer_continues_past_month    STRING
  ,revenue_current_advertisement    DECIMAL(20,2)
  ,revenue_current_avvopro          DECIMAL(20,2)
  ,revenue_current_ignite           DECIMAL(20,2)
  ,revenue_current_website          DECIMAL(20,2)
  ,revenue_current_adplacement      DECIMAL(20,2)
  ,revenue_current_misc             DECIMAL(20,2)
  ,revenue_current_other_sub        DECIMAL(20,2)
  ,revenue_current_other            DECIMAL(20,2)
  ,revenue_current_total            DECIMAL(20,2)
  ,mrr_current_advertisement        DECIMAL(20,2)
  ,mrr_current_avvopro              DECIMAL(20,2)
  ,mrr_current_ignite               DECIMAL(20,2)
  ,mrr_current_website              DECIMAL(20,2)
  ,mrr_current_adplacement          DECIMAL(20,2)
  ,mrr_current_other_sub            DECIMAL(20,2)
  ,mrr_current_total                DECIMAL(20,2)
  ,tenure_month_prev                BIGINT
  ,is_active_during_month_prior     STRING  -- LOOK strongly suspect I do not need all of these.
  ,is_active_eom_prior              STRING
  ,had_payment_prior                STRING
  ,has_ads_during_month_prior       STRING
  ,has_ads_eom_prior                STRING
  ,revenue_prior_advertisement      DECIMAL(20,2)
  ,revenue_prior_avvopro            DECIMAL(20,2)
  ,revenue_prior_ignite             DECIMAL(20,2)
  ,revenue_prior_website            DECIMAL(20,2)
  ,revenue_prior_adplacement        DECIMAL(20,2)
  ,revenue_prior_misc               DECIMAL(20,2)
  ,revenue_prior_other_sub          DECIMAL(20,2)
  ,revenue_prior_other              DECIMAL(20,2)
  ,revenue_prior_total              DECIMAL(20,2)
  ,mrr_prior_advertisement          DECIMAL(20,2)
  ,mrr_prior_avvopro                DECIMAL(20,2)
  ,mrr_prior_ignite                 DECIMAL(20,2)
  ,mrr_prior_website                DECIMAL(20,2)
  ,mrr_prior_adplacement            DECIMAL(20,2)
  ,mrr_prior_other_sub              DECIMAL(20,2)
  ,mrr_prior_total                  DECIMAL(20,2)
)
PARTITIONED BY (start_month_chain INT)
STORED AS PARQUET ;
WITH table_src AS
(
SELECT
    adj.customer_id
   ,adj.year_month
   ,adj.year_month_begin_date
   ,adj.chain_id_raw
   ,adj.chain_number
   ,adj.tenure_month_chain
   ,adj.tenure_month_lifetime
   ,adj.active_months_to_date
   ,adj.start_month_chain
   ,adj.start_month_begin_date_chain
   ,adj.start_month_lifetime
   ,adj.start_month_begin_date_lifetime
   ,adj.is_active_during_month
   ,adj.is_active_eom
   ,adj.had_payment
   ,adj.has_ads_during_month
   ,adj.has_ads_eom
   ,CASE WHEN adj.tenure_month_lifetime = 1 THEN 'N' ELSE 'Y' END AS customer_exists_prior_month  -- LOOK tenure_month done
   ,adj.mrr_method
   ,adj.max_bill_date_in_month
   ,adj.had_cc_failure
   ,adj.promo_flag
   -- ,adj.customer_continues_past_month
   ,adj.revenue_current_advertisement
   ,adj.revenue_current_avvopro
   ,adj.revenue_current_ignite
   ,adj.revenue_current_website
   ,adj.revenue_current_adplacement
   ,adj.revenue_current_misc
   ,adj.revenue_current_other_sub
   ,adj.revenue_current_other
   ,adj.revenue_current_total
    -- Prior to 201408, we could not prorate because begin date is always
    -- first of the month.  So if it is the first month in a chain,
    -- and we see non-zero revenue for the customer next month, take
    -- all of next month's values for this month's MRR.  -- LOOK tenure_month done
    ,CASE WHEN adj.tenure_month_chain = 1 AND adj.year_month <= 201407 AND adj.is_active_eom = 'Y' AND IFNULL(adj.mrr_next_total, 0) > 0
          THEN adj.mrr_next_advertisement
          ELSE adj.mrr_current_advertisement END AS  mrr_current_advertisement
    ,CASE WHEN adj.tenure_month_chain = 1 AND adj.year_month <= 201407 AND adj.is_active_eom = 'Y' AND IFNULL(adj.mrr_next_total, 0) > 0
          THEN adj.mrr_next_avvopro
          ELSE adj.mrr_current_avvopro END AS        mrr_current_avvopro
    ,CASE WHEN adj.tenure_month_chain = 1 AND adj.year_month <= 201407 AND adj.is_active_eom = 'Y' AND IFNULL(adj.mrr_next_total, 0) > 0
          THEN adj.mrr_next_ignite
          ELSE adj.mrr_current_ignite END AS         mrr_current_ignite
    ,CASE WHEN adj.tenure_month_chain = 1 AND adj.year_month <= 201407 AND adj.is_active_eom = 'Y' AND IFNULL(adj.mrr_next_total, 0) > 0
          THEN adj.mrr_next_website
          ELSE adj.mrr_current_website END AS        mrr_current_website
    ,CASE WHEN adj.tenure_month_chain = 1 AND adj.year_month <= 201407 AND adj.is_active_eom = 'Y' AND IFNULL(adj.mrr_next_total, 0) > 0
          THEN adj.mrr_next_adplacement
          ELSE adj.mrr_current_adplacement END AS    mrr_current_adplacement
    ,CASE WHEN adj.tenure_month_chain = 1 AND adj.year_month <= 201407 AND adj.is_active_eom = 'Y' AND IFNULL(adj.mrr_next_total, 0) > 0
          THEN adj.mrr_next_other_sub
          ELSE adj.mrr_current_other_sub END AS      mrr_current_other_sub
    ,CASE WHEN adj.tenure_month_chain = 1 AND adj.year_month <= 201407 AND adj.is_active_eom = 'Y' AND IFNULL(adj.mrr_next_total, 0) > 0
          THEN adj.mrr_next_total
          ELSE adj.mrr_current_total END AS          mrr_current_total
    ,adj.tenure_month_prev
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 'N' ELSE adj.is_active_during_month_prior END AS  is_active_during_month_prior
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 'N' ELSE adj.is_active_eom_prior END AS           is_active_eom_prior
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 'N' ELSE adj.had_payment_prior END AS             had_payment_prior
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 'N' ELSE adj.has_ads_during_month_prior END AS    has_ads_during_month_prior
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 'N' ELSE adj.has_ads_eom_prior END AS             has_ads_eom_prior
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.revenue_prior_advertisement END AS  revenue_prior_advertisement
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.revenue_prior_avvopro END AS        revenue_prior_avvopro
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.revenue_prior_ignite END AS         revenue_prior_ignite
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.revenue_prior_website END AS        revenue_prior_website
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.revenue_prior_adplacement END AS    revenue_prior_adplacement
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.revenue_prior_misc END AS           revenue_prior_misc
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.revenue_prior_other_sub END AS      revenue_prior_other_sub
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.revenue_prior_other END AS          revenue_prior_other
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.revenue_prior_total END AS          revenue_prior_total
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.mrr_prior_advertisement END AS      mrr_prior_advertisement
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.mrr_prior_avvopro END AS            mrr_prior_avvopro
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.mrr_prior_ignite END AS             mrr_prior_ignite
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.mrr_prior_website END AS            mrr_prior_website
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.mrr_prior_adplacement END AS        mrr_prior_adplacement
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.mrr_prior_other_sub END AS          mrr_prior_other_sub
    ,CASE WHEN adj.tenure_month_chain = 1 THEN 0 ELSE adj.mrr_prior_total END AS              mrr_prior_total
FROM
  (
  SELECT
     chn.customer_id
    ,chn.year_month
    ,chn.year_month_begin_date
    ,chn.chain_id_raw
    ,DENSE_RANK() OVER(PARTITION BY chn.customer_id
                           ORDER BY chn.chain_id_raw DESC) AS chain_number
    ,ROW_NUMBER()                   OVER(PARTITION BY chn.customer_id, chn.chain_id_raw
                                          ORDER BY chn.tenure_month) AS    tenure_month_chain  -- LOOK tenure_month done
    ,chn.tenure_month AS tenure_month_lifetime
    ,chn.active_months_to_date
    ,MIN(chn.year_month)            OVER(PARTITION BY chn.customer_id, chn.chain_id_raw
                                             ORDER BY chn.tenure_month) AS start_month_chain
    ,MIN(chn.year_month_begin_date) OVER(PARTITION BY chn.customer_id, chn.chain_id_raw
                                             ORDER BY chn.tenure_month) AS start_month_begin_date_chain
    ,chn.start_month AS start_month_lifetime
    ,chn.start_month_begin_date AS start_month_begin_date_lifetime
    ,chn.is_active_during_month
    ,chn.is_active_eom
    ,chn.had_payment
    ,chn.has_ads_during_month
    ,chn.has_ads_eom
    ,chn.mrr_method
    ,chn.max_bill_date_in_month
    ,chn.had_cc_failure
    ,chn.promo_flag
    ,chn.customer_continues_past_month
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
    ,chn.mrr_next_advertisement
    ,chn.mrr_next_avvopro
    ,chn.mrr_next_ignite
    ,chn.mrr_next_website
    ,chn.mrr_next_adplacement
    ,chn.mrr_next_other_sub
    ,chn.mrr_next_total
    -- probably way-too-subtle naming thing: I try to use prior as always referring to the
    -- prior calendar month, while prev means the most recent one I see even if it's
    -- a while ago.
    ,chn.tenure_month_prior AS  tenure_month_prev
    ,chn.is_active_during_month_prior
    ,chn.is_active_eom_prior
    ,chn.had_payment_prior
    ,chn.has_ads_during_month_prior
    ,chn.has_ads_eom_prior
    ,chn.customer_continues_past_month_prior
    ,chn.revenue_prior_advertisement
    ,chn.revenue_prior_avvopro
    ,chn.revenue_prior_ignite
    ,chn.revenue_prior_website
    ,chn.revenue_prior_adplacement
    ,chn.revenue_prior_misc
    ,chn.revenue_prior_other_sub
    ,chn.revenue_prior_other
    ,chn.revenue_prior_total
    ,chn.mrr_prior_advertisement
    ,chn.mrr_prior_avvopro
    ,chn.mrr_prior_ignite
    ,chn.mrr_prior_website
    ,chn.mrr_prior_adplacement
    ,chn.mrr_prior_other_sub
    ,chn.mrr_prior_total
  FROM tmp_data_dm.coe_jrr_cust_chains_raw2 chn
  ) adj
)
INSERT OVERWRITE TABLE tmp_data_dm.coe_jrr_cust_chains PARTITION(start_month_chain)
SELECT
   customer_id
  ,year_month
  ,year_month_begin_date
  ,chain_id_raw
  ,chain_number
  ,tenure_month_chain
  ,tenure_month_lifetime
  ,active_months_to_date
  ,start_month_begin_date_chain
  ,start_month_lifetime
  ,start_month_begin_date_lifetime
  ,is_active_during_month
  ,is_active_eom
  ,had_payment
  ,has_ads_during_month
  ,has_ads_eom
  ,customer_exists_prior_month
  ,mrr_method
  ,max_bill_date_in_month
  ,had_cc_failure
  ,promo_flag
  ,revenue_current_advertisement
  ,revenue_current_avvopro
  ,revenue_current_ignite
  ,revenue_current_website
  ,revenue_current_adplacement
  ,revenue_current_misc
  ,revenue_current_other_sub
  ,revenue_current_other
  ,revenue_current_total
  ,mrr_current_advertisement
  ,mrr_current_avvopro
  ,mrr_current_ignite
  ,mrr_current_website
  ,mrr_current_adplacement
  ,mrr_current_other_sub
  ,mrr_current_total
  ,tenure_month_prev
  ,is_active_during_month_prior
  ,is_active_eom_prior
  ,had_payment_prior
  ,has_ads_during_month_prior
  ,has_ads_eom_prior
  ,revenue_prior_advertisement
  ,revenue_prior_avvopro
  ,revenue_prior_ignite
  ,revenue_prior_website
  ,revenue_prior_adplacement
  ,revenue_prior_misc
  ,revenue_prior_other_sub
  ,revenue_prior_other
  ,revenue_prior_total
  ,mrr_prior_advertisement
  ,mrr_prior_avvopro
  ,mrr_prior_ignite
  ,mrr_prior_website
  ,mrr_prior_adplacement
  ,mrr_prior_other_sub
  ,mrr_prior_total
  ,start_month_chain
FROM table_src ;

COMPUTE INCREMENTAL STATS tmp_data_dm.coe_jrr_cust_chains ;

-- Clean up temp tables because they are big and their only 
-- purpose is to optimize the queries.
DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_chains_raw1 ;
DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_chains_raw2 ;

DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_backfill_customer_mrr ;
CREATE TABLE tmp_data_dm.coe_jrr_backfill_customer_mrr
(
   customer_id                      INT
  -- ,year_month                       INT
  ,year_month_begin_date            STRING
  ,chain_number                     BIGINT
  ,tenure_month_chain               BIGINT
  ,tenure_month_lifetime            BIGINT
  ,active_months_to_date            BIGINT
  ,start_month_chain                INT
  ,start_month_begin_date_chain     STRING
  ,start_month_lifetime             INT
  ,start_month_begin_date_lifetime  STRING
  ,first_payment_month              INT
  ,is_active_during_month           STRING
  ,is_active_eom                    STRING
  ,had_payment                      STRING
  ,has_ads_during_month             STRING
  ,has_ads_eom                      STRING
  ,customer_exists_prior_month      STRING
  ,mrr_method                       STRING
  ,max_bill_date_in_month           STRING
  ,had_cc_failure                   STRING
  ,promo_flag                       STRING
  ,revenue_current_advertisement    DECIMAL(20,2)
  ,revenue_current_avvopro          DECIMAL(20,2)
  ,revenue_current_ignite           DECIMAL(20,2)
  ,revenue_current_website          DECIMAL(20,2)
  ,revenue_current_adplacement      DECIMAL(20,2)
  ,revenue_current_misc             DECIMAL(20,2)
  ,revenue_current_other_sub        DECIMAL(20,2)
  ,revenue_current_other            DECIMAL(20,2)
  ,revenue_current_total            DECIMAL(20,2)
  ,mrr_current_advertisement        DECIMAL(20,2)
  ,mrr_current_avvopro              DECIMAL(20,2)
  ,mrr_current_ignite               DECIMAL(20,2)
  ,mrr_current_website              DECIMAL(20,2)
  ,mrr_current_adplacement          DECIMAL(20,2)
  ,mrr_current_other_sub            DECIMAL(20,2)
  ,mrr_current_total                DECIMAL(20,2)
  ,tenure_month_prev                BIGINT
  ,is_active_during_month_prior     STRING  -- LOOK strongly suspect I do not need all of these.
  ,is_active_eom_prior              STRING
  ,had_payment_prior                STRING
  ,has_ads_during_month_prior       STRING
  ,has_ads_eom_prior                STRING
  ,revenue_prior_advertisement      DECIMAL(20,2)
  ,revenue_prior_avvopro            DECIMAL(20,2)
  ,revenue_prior_ignite             DECIMAL(20,2)
  ,revenue_prior_website            DECIMAL(20,2)
  ,revenue_prior_adplacement        DECIMAL(20,2)
  ,revenue_prior_misc               DECIMAL(20,2)
  ,revenue_prior_other_sub          DECIMAL(20,2)
  ,revenue_prior_other              DECIMAL(20,2)
  ,revenue_prior_total              DECIMAL(20,2)
  ,mrr_prior_advertisement          DECIMAL(20,2)
  ,mrr_prior_avvopro                DECIMAL(20,2)
  ,mrr_prior_ignite                 DECIMAL(20,2)
  ,mrr_prior_website                DECIMAL(20,2)
  ,mrr_prior_adplacement            DECIMAL(20,2)
  ,mrr_prior_other_sub              DECIMAL(20,2)
  ,mrr_prior_total                  DECIMAL(20,2)
  ,mrr_customer_category            STRING
  ,mrr_acquired                     DECIMAL(20,2)
  ,mrr_penetrated                   DECIMAL(20,2)
  ,mrr_downsized                    DECIMAL(20,2)
  ,mrr_churned                      DECIMAL(20,2)
  ,mrr_retained                     DECIMAL(20,2)
  ,mrr_returned                     DECIMAL(20,2)
  ,mrr_retained_subset_flat_customers   DECIMAL(20,2)
  ,mrr_retained_subset_delta_customers  DECIMAL(20,2)
  ,has_had_payment_lifetime         STRING
  ,mrr_customer_exception           STRING
)
PARTITIONED BY (year_month INT)
STORED AS PARQUET ;
WITH table_src AS
(
SELECT
   chn.customer_id
  ,chn.year_month
  ,chn.year_month_begin_date
  ,chn.chain_number
  ,chn.tenure_month_chain
  ,chn.tenure_month_lifetime
  ,chn.active_months_to_date
  ,chn.start_month_chain
  ,chn.start_month_begin_date_chain
  ,chn.start_month_lifetime
  ,chn.start_month_begin_date_lifetime
  ,srt.first_payment_month
  ,chn.is_active_during_month
  ,chn.is_active_eom
  ,chn.had_payment
  ,chn.has_ads_during_month
  ,chn.has_ads_eom
  ,chn.customer_exists_prior_month
  ,chn.mrr_method
  ,chn.max_bill_date_in_month
  ,chn.had_cc_failure
  ,chn.promo_flag
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
  ,chn.tenure_month_prev
  ,chn.is_active_during_month_prior
  ,chn.is_active_eom_prior
  ,chn.had_payment_prior
  ,chn.has_ads_during_month_prior
  ,chn.has_ads_eom_prior
  ,chn.revenue_prior_advertisement
  ,chn.revenue_prior_avvopro
  ,chn.revenue_prior_ignite
  ,chn.revenue_prior_website
  ,chn.revenue_prior_adplacement
  ,chn.revenue_prior_misc
  ,chn.revenue_prior_other_sub
  ,chn.revenue_prior_other
  ,chn.revenue_prior_total
  ,chn.mrr_prior_advertisement
  ,chn.mrr_prior_avvopro
  ,chn.mrr_prior_ignite
  ,chn.mrr_prior_website
  ,chn.mrr_prior_adplacement
  ,chn.mrr_prior_other_sub
  ,chn.mrr_prior_total
  -- Logic changes:
  -- Old logic does not count acquired if MRR is 0.  New logic does.
  -- New logic allows downsize to 0 and upsell from 0.

  ,CASE WHEN chn.is_active_eom = 'Y' AND
             chn.customer_exists_prior_month = 'N' THEN         'ACQUIRED'

        WHEN chn.is_active_eom = 'Y' AND
             chn.is_active_eom_prior = 'N' AND
             chn.customer_exists_prior_month = 'Y' THEN         'RETURNED'
             
        WHEN chn.is_active_eom = 'Y' AND
             chn.is_active_eom_prior = 'Y' AND
             chn.mrr_current_total > chn.mrr_prior_total THEN   'PENETRATED'

        WHEN chn.is_active_eom = 'Y' AND
             chn.is_active_eom_prior = 'Y' AND
             chn.mrr_current_total > 0 AND
             chn.mrr_current_total  =  chn.mrr_prior_total THEN 'RETAINED'

        WHEN chn.is_active_eom = 'Y' AND
             chn.is_active_eom_prior = 'Y' AND
             chn.mrr_current_total < chn.mrr_prior_total THEN   'DOWNSIZED'

        WHEN chn.is_active_eom = 'N' AND
             chn.is_active_eom_prior   = 'Y' THEN               'CHURNED'

        WHEN chn.is_active_eom = 'Y' AND
             chn.is_active_eom_prior   = 'Y' AND
             chn.mrr_current_total = 0 AND
             chn.mrr_prior_total = 0 THEN                       'NO ACTIVITY'
        ELSE 'NOT BILLED' END AS                              mrr_customer_category

  ,CASE WHEN chn.is_active_eom = 'Y' AND
             chn.customer_exists_prior_month = 'N' THEN           CAST(chn.mrr_current_total AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_acquired
  ,CASE WHEN chn.is_active_eom = 'Y' AND
             chn.is_active_eom_prior = 'N' AND
             chn.customer_exists_prior_month = 'Y' THEN           CAST(chn.mrr_current_total AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_returned
  ,CASE WHEN chn.is_active_eom = 'Y' AND
             chn.is_active_eom_prior = 'Y' AND
             chn.mrr_current_total > chn.mrr_prior_total THEN     CAST((chn.mrr_current_total - chn.mrr_prior_total) AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_penetrated
  ,CASE WHEN -- RETAINED
             chn.is_active_eom = 'Y' AND
             chn.is_active_eom_prior = 'Y' AND
             chn.mrr_current_total > 0 AND
             chn.mrr_current_total  =  chn.mrr_prior_total THEN   CAST(chn.mrr_current_total AS DECIMAL(20,2))
        WHEN -- DOWNSIZED
             chn.is_active_eom = 'Y' AND
             chn.is_active_eom_prior = 'Y' AND
             chn.mrr_current_total < chn.mrr_prior_total THEN     CAST(chn.mrr_current_total AS DECIMAL(20,2))
        WHEN -- PENETRATED
             chn.is_active_eom = 'Y' AND
             chn.is_active_eom_prior = 'Y' AND
             chn.mrr_current_total > chn.mrr_prior_total THEN     CAST(chn.mrr_prior_total AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_retained
  ,CASE WHEN chn.is_active_eom = 'Y' AND
             chn.is_active_eom_prior = 'Y' AND
             chn.mrr_current_total < chn.mrr_prior_total THEN     CAST((chn.mrr_current_total - chn.mrr_prior_total)  AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_downsized
  ,CASE WHEN chn.is_active_eom = 'N' AND
             chn.is_active_eom_prior   = 'Y' THEN         CAST((chn.mrr_current_total - chn.mrr_prior_total) AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_churned

  -- This is the portion of mrr_retained for customers in the RETAINED category.
  ,CASE WHEN chn.is_active_eom = 'Y' AND
             chn.is_active_eom_prior = 'Y' AND
             chn.mrr_current_total > 0 AND
             chn.mrr_current_total  =  chn.mrr_prior_total THEN   CAST(chn.mrr_current_total  AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_retained_subset_flat_customers
  -- This is the portion of mrr_retained for customers in the PENETRATED and DOWNSIZED categories.
  ,CASE WHEN -- DOWNSIZED
             chn.is_active_eom = 'Y' AND
             chn.is_active_eom_prior = 'Y' AND
             chn.mrr_current_total < chn.mrr_prior_total THEN     CAST(chn.mrr_current_total AS DECIMAL(20,2))
        WHEN -- PENETRATED
             chn.is_active_eom = 'Y' AND
             chn.is_active_eom_prior = 'Y' AND
             chn.mrr_current_total > chn.mrr_prior_total THEN     CAST(chn.mrr_prior_total AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_retained_subset_delta_customers
  ,CASE WHEN srt.first_payment_month <= chn.year_month THEN 'Y' ELSE 'N' END AS has_had_payment_lifetime
  -- ,CASE WHEN something <= chn.year_month THEN 'Y' ELSE 'N' END AS has_had_payment_chain
FROM
             tmp_data_dm.coe_jrr_cust_chains chn
  INNER JOIN tmp_data_dm.coe_jrr_cust_lifetime_start srt
          ON chn.customer_id = srt.customer_id
WHERE chn.year_month BETWEEN 201304 AND 201610
)
INSERT OVERWRITE TABLE tmp_data_dm.coe_jrr_backfill_customer_mrr PARTITION(year_month)
SELECT
   customer_id
  ,year_month_begin_date
  ,chain_number
  ,tenure_month_chain
  ,tenure_month_lifetime
  ,active_months_to_date
  ,start_month_chain
  ,start_month_begin_date_chain
  ,start_month_lifetime
  ,start_month_begin_date_lifetime
  ,first_payment_month
  ,is_active_during_month
  ,is_active_eom
  ,had_payment
  ,has_ads_during_month
  ,has_ads_eom
  ,customer_exists_prior_month
  ,mrr_method
  ,max_bill_date_in_month
  ,had_cc_failure
  ,promo_flag
  ,revenue_current_advertisement
  ,revenue_current_avvopro
  ,revenue_current_ignite
  ,revenue_current_website
  ,revenue_current_adplacement
  ,revenue_current_misc
  ,revenue_current_other_sub
  ,revenue_current_other
  ,revenue_current_total
  ,mrr_current_advertisement
  ,mrr_current_avvopro
  ,mrr_current_ignite
  ,mrr_current_website
  ,mrr_current_adplacement
  ,mrr_current_other_sub
  ,mrr_current_total
  ,tenure_month_prev
  ,is_active_during_month_prior
  ,is_active_eom_prior
  ,had_payment_prior
  ,has_ads_during_month_prior
  ,has_ads_eom_prior
  ,revenue_prior_advertisement
  ,revenue_prior_avvopro
  ,revenue_prior_ignite
  ,revenue_prior_website
  ,revenue_prior_adplacement
  ,revenue_prior_misc
  ,revenue_prior_other_sub
  ,revenue_prior_other
  ,revenue_prior_total
  ,mrr_prior_advertisement
  ,mrr_prior_avvopro
  ,mrr_prior_ignite
  ,mrr_prior_website
  ,mrr_prior_adplacement
  ,mrr_prior_other_sub
  ,mrr_prior_total
  ,mrr_customer_category
  ,mrr_acquired
  ,mrr_penetrated
  ,mrr_downsized
  ,mrr_churned
  ,mrr_retained
  ,mrr_returned
  ,mrr_retained_subset_flat_customers
  ,mrr_retained_subset_delta_customers
  ,has_had_payment_lifetime
  ,CASE WHEN mrr_customer_category = 'NO ACTIVITY' THEN 'Has ads but 0 current and prior MRR'
        WHEN is_active_during_month = 'N' AND
             revenue_current_total <> 0 THEN            'Not active during month but revenue'
        WHEN mrr_customer_category = 'PENETRATED' AND
             mrr_prior_total = 0 THEN                   'Upsold from 0 MRR'
        WHEN mrr_customer_category = 'DOWNSIZED' AND
             mrr_current_total = 0 THEN                 'Downsized to 0 MRR'
        WHEN mrr_customer_category = 'DOWNSIZED' AND
             mrr_current_total = 0 THEN                 'Downsized to 0 MRR'
        WHEN mrr_customer_category = 'ACQUIRED' AND
             mrr_current_total = 0 THEN                   'Acquired to 0 MRR'
        WHEN had_payment = 'N' AND
             mrr_current_total = 0 AND
             is_active_eom = 'Y' THEN                   'No payment, 0 MRR, but active'
        ELSE 'OK'
   END AS mrr_customer_exception
  ,year_month
FROM table_src ;

-- Revenue plug
-- There are some cases where there was revenue but customer was
-- not active at any point in the month.  I have not brought those
-- records through because they should not be part of the chains.
-- But now I need to drop their revenue back in.
INSERT INTO TABLE tmp_data_dm.coe_jrr_backfill_customer_mrr PARTITION(year_month)
SELECT
   mth.customer_id
  ,mth.year_month_begin_date
  ,NULL AS                        chain_number
  ,NULL AS                        tenure_month_chain
  ,1+(FLOOR(mth.year_month/100)-FLOOR(srt.start_month/100)) * 12 +
           (mth.year_month%100-       srt.start_month%100) AS tenure_month_lifetime  -- LOOK tenure_month
  ,NULL AS                        active_months_to_date
  ,NULL AS                        start_month_chain
  ,NULL AS                        start_month_begin_date_chain
  ,srt.start_month AS             start_month_lifetime
  ,srt.start_month_begin_date AS  start_month_begin_date_lifetime
  ,srt.first_payment_month
  ,'N' AS                         is_active_during_month
  ,'N' AS                         is_active_eom
  ,mth.had_payment
  ,mth.has_ads_during_month
  ,mth.has_ads_eom
  ,NULL AS                        customer_exists_prior_month
  ,mth.mrr_method
  ,mth.max_bill_date_in_month
  ,mth.had_cc_failure
  ,mth.promo_flag
  ,mth.revenue_current_advertisement
  ,mth.revenue_current_avvopro
  ,mth.revenue_current_ignite
  ,mth.revenue_current_website
  ,mth.revenue_current_adplacement
  ,mth.revenue_current_misc
  ,mth.revenue_current_other_sub
  ,mth.revenue_current_other
  ,mth.revenue_current_total
  ,0 AS                          mrr_current_advertisement
  ,0 AS                          mrr_current_avvopro
  ,0 AS                          mrr_current_ignite
  ,0 AS                          mrr_current_website
  ,0 AS                          mrr_current_adplacement
  ,0 AS                          mrr_current_other_sub
  ,0 AS                          mrr_current_total
  ,NULL AS                       tenure_month_prev
  ,NULL AS                       is_active_during_month_prior
  ,NULL AS                       is_active_eom_prior
  ,NULL AS                       had_payment_prior
  ,NULL AS                       has_ads_during_month_prior
  ,NULL AS                       has_ads_eom_prior
  ,NULL AS                       revenue_prior_advertisement
  ,NULL AS                       revenue_prior_avvopro
  ,NULL AS                       revenue_prior_ignite
  ,NULL AS                       revenue_prior_website
  ,NULL AS                       revenue_prior_adplacement
  ,NULL AS                       revenue_prior_misc
  ,NULL AS                       revenue_prior_other_sub
  ,NULL AS                       revenue_prior_other
  ,NULL AS                       revenue_prior_total
  ,NULL AS                       mrr_prior_advertisement
  ,NULL AS                       mrr_prior_avvopro
  ,NULL AS                       mrr_prior_ignite
  ,NULL AS                       mrr_prior_website
  ,NULL AS                       mrr_prior_adplacement
  ,NULL AS                       mrr_prior_other_sub
  ,NULL AS                       mrr_prior_total
  ,'NOT BILLED' AS mrr_customer_category
  ,0 AS mrr_acquired
  ,0 AS mrr_penetrated
  ,0 AS mrr_downsized
  ,0 AS mrr_churned
  ,0 AS mrr_retained
  ,0 AS mrr_returned
  ,0 AS mrr_retained_subset_flat_customers
  ,0 AS mrr_retained_subset_delta_customers
  ,CASE WHEN srt.first_payment_month <= mth.year_month THEN 'Y' ELSE 'N' END AS has_had_payment_lifetime
  ,'Revenue only; no MRR implications' AS mrr_customer_exception
  ,mth.year_month
FROM        tmp_data_dm.coe_jrr_cust_months mth
  LEFT JOIN tmp_data_dm.coe_jrr_cust_lifetime_start srt
         ON mth.customer_id = srt.customer_id 
        AND mth.year_month BETWEEN 201304 AND 201610
WHERE mth.is_active_during_month = 'N' AND mth.revenue_current_total <> 0 ;

-- Truly not billed plug  LOOK needs change.
INSERT INTO TABLE tmp_data_dm.coe_jrr_backfill_customer_mrr PARTITION(year_month)
SELECT
   srt.customer_id
  ,mth.month_begin_date AS        year_month_begin_date
  ,NULL AS                        chain_number
  ,NULL AS                        tenure_month_chain
  ,1+(FLOOR(mth.year_month/100)-FLOOR(srt.start_month/100)) * 12 +
           (mth.year_month%100-       srt.start_month%100) AS tenure_month_lifetime  -- LOOK tenure_month
  ,NULL AS                        active_months_to_date
  ,NULL AS                        start_month_chain
  ,NULL AS                        start_month_begin_date_chain
  ,srt.start_month AS             start_month_lifetime
  ,srt.start_month_begin_date AS  start_month_begin_date_lifetime
  ,srt.first_payment_month
  ,'N' AS                         is_active_during_month
  ,'N' AS                         is_active_eom
  ,'N' AS                         had_payment
  ,'N' AS                         has_ads_during_month
  ,'N' AS                         has_ads_eom
  ,NULL AS                        customer_exists_prior_month
  ,'n/a' AS                      mrr_method
  ,NULL AS                       max_bill_date_in_month
  ,NULL AS                       had_cc_failure
  ,NULL AS                       promo_flag
  ,0 AS                          revenue_current_advertisement
  ,0 AS                          revenue_current_avvopro
  ,0 AS                          revenue_current_ignite
  ,0 AS                          revenue_current_website
  ,0 AS                          revenue_current_adplacement
  ,0 AS                          revenue_current_misc
  ,0 AS                          revenue_current_other_sub
  ,0 AS                          revenue_current_other
  ,0 AS                          revenue_current_total
  ,0 AS                          mrr_current_advertisement
  ,0 AS                          mrr_current_avvopro
  ,0 AS                          mrr_current_ignite
  ,0 AS                          mrr_current_website
  ,0 AS                          mrr_current_adplacement
  ,0 AS                          mrr_current_other_sub
  ,0 AS                          mrr_current_total
  ,NULL AS                       tenure_month_prev
  ,NULL AS                       is_active_during_month_prior
  ,NULL AS                       is_active_eom_prior
  ,NULL AS                       had_payment_prior
  ,NULL AS                       has_ads_during_month_prior
  ,NULL AS                       has_ads_eom_prior
  ,NULL AS                       revenue_prior_advertisement
  ,NULL AS                       revenue_prior_avvopro
  ,NULL AS                       revenue_prior_ignite
  ,NULL AS                       revenue_prior_website
  ,NULL AS                       revenue_prior_adplacement
  ,NULL AS                       revenue_prior_misc
  ,NULL AS                       revenue_prior_other_sub
  ,NULL AS                       revenue_prior_other
  ,NULL AS                       revenue_prior_total
  ,NULL AS                       mrr_prior_advertisement
  ,NULL AS                       mrr_prior_avvopro
  ,NULL AS                       mrr_prior_ignite
  ,NULL AS                       mrr_prior_website
  ,NULL AS                       mrr_prior_adplacement
  ,NULL AS                       mrr_prior_other_sub
  ,NULL AS                       mrr_prior_total
  ,'NOT BILLED' AS mrr_customer_category
  ,0 AS mrr_acquired
  ,0 AS mrr_penetrated
  ,0 AS mrr_downsized
  ,0 AS mrr_churned
  ,0 AS mrr_retained
  ,0 AS mrr_returned
  ,0 AS mrr_retained_subset_flat_customers
  ,0 AS mrr_retained_subset_delta_customers
  ,CASE WHEN srt.first_payment_month <= mth.year_month THEN 'Y' ELSE 'N' END AS has_had_payment_lifetime
  ,'OK' AS mrr_customer_exception
  ,mth.year_month
FROM         tmp_data_dm.coe_jrr_cust_lifetime_start srt
  INNER JOIN dm.month_dim mth
          ON srt.start_month <= mth.year_month
         AND mth.year_month BETWEEN 201304 AND 201610
  LEFT OUTER JOIN tmp_data_dm.coe_jrr_backfill_customer_mrr mrr
          ON srt.customer_id = mrr.customer_id
         AND mth.year_month = mrr.year_month
WHERE mrr.customer_id IS NULL ;

COMPUTE INCREMENTAL STATS tmp_data_dm.coe_jrr_backfill_customer_mrr ;
