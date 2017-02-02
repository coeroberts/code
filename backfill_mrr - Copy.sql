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
         ,ROUND(CAST(unit_price AS DOUBLE) * block_count / 100, 2) AS full_price
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
   END AS product_type
  ,CASE WHEN uns.product_line_id IN (2, 7) THEN 'Y' ELSE 'N' END AS            has_ads
  ,CASE WHEN uns.order_line_payment_date NOT IN ('1900-01-01', '-1') 
         AND uns.order_line_net_price_amount_usd > 0 THEN 'Y' ELSE 'N' END AS  has_payment
  ,SUM(CASE WHEN IFNULL(uns.max_expired_date, '2999-01-01') > uns.year_month_end_date THEN uns.full_price   -- LOOK
            ELSE 0 END) AS            mrr
  -- ,SUM(uns.full_price) AS            mrr
  ,MAX(CASE WHEN IFNULL(uns.max_expired_date, '2999-01-01') > uns.year_month_end_date THEN 'Y' 
            ELSE 'N' END) AS          sub_continues_past_month
  ,SUM(uns.block_count) AS            block_count
  ,SUM(CASE WHEN uns.order_line_payment_date NOT IN ('1900-01-01', '-1') THEN uns.order_line_net_price_amount_usd 
            ELSE 0 END) AS            revenue
  -- ,SUM(uns.order_line_net_price_amount_usd) AS revenue
  ,MAX(uns.order_line_begin_date) AS  max_bill_date_in_month
  -- ,MAX(uns.max_expired_date) AS       max_expired_date
FROM
  (
      SELECT
         olaf.*
        ,'MRR' AS mrr_method
        ,dt.year_month
        ,dt.month_begin_date AS year_month_begin_date
        ,dt.month_end_date AS year_month_end_date
        ,IFNULL(mrr.mrr, 0) AS full_price
        ,GREATEST(CASE WHEN olaf.order_line_cancelled_date = '-1' THEN NULL ELSE olaf.order_line_cancelled_date END
                 ,mrr.cancelled_date
                 ,mrr.expired_date) AS max_expired_date
      FROM         dm.order_line_accumulation_fact olaf
        INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
        LEFT OUTER JOIN dm.mrr_subscription_all_products mrr
                ON olaf.product_subscription_id = mrr.subscription_id
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
      FROM         dm.order_line_accumulation_fact olaf
        INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
        INNER JOIN dm.month_dim mth ON dt.year_month = mth.year_month
      WHERE olaf.order_line_begin_date BETWEEN '2013-01-01' AND '2014-08-31'  -- LOOK
      -- WHERE olaf.order_line_begin_date >= '2013-01-01'
  ) uns
GROUP BY 1,2,3,4,5,6,7,8,9 ;

-- One row per (customer, billed month)
-- This is before the chain logic.
DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_active_months ;
CREATE TABLE tmp_data_dm.coe_jrr_cust_active_months AS
SELECT *
FROM
  (
  SELECT
     bls.customer_id
    ,bls.year_month
    ,bls.year_month_begin_date
    ,bls.mrr_method
    ,MAX(bls.has_ads) AS                   has_ads
    ,MAX(bls.has_payment) AS               has_payment
    ,MAX(bls.max_bill_date_in_month) AS    max_bill_date_in_month
    ,MAX(bls.sub_continues_past_month) AS  customer_continues_past_month
    -- Note: we have things that look like ads prior to 2015-10 but
    -- product_line_id = -1.  I am going to call that MRR, but leave
    -- has_ads = 'N' because legacy code excluded them.
    ,SUM(CASE WHEN bls.product_type IN ('Display', 'Sponsored Listing') THEN bls.revenue ELSE 0 END) AS revenue_current_advertisement
    ,SUM(CASE WHEN bls.product_type = 'Pro'                             THEN bls.revenue ELSE 0 END) AS revenue_current_avvopro
    ,SUM(CASE WHEN bls.product_type = 'Ignite'                          THEN bls.revenue ELSE 0 END) AS revenue_current_ignite
    ,SUM(CASE WHEN bls.product_type = 'Website'                         THEN bls.revenue ELSE 0 END) AS revenue_current_website
    ,SUM(CASE WHEN bls.product_type = 'Ad Placement'                    THEN bls.revenue ELSE 0 END) AS revenue_current_adplacement
    ,SUM(CASE WHEN bls.product_type = 'Misc'                            THEN bls.revenue ELSE 0 END) AS revenue_current_misc
    ,SUM(CASE WHEN bls.product_type = 'Other Subscription'              THEN bls.revenue ELSE 0 END) AS revenue_current_other_sub
    ,SUM(CASE WHEN bls.product_type = 'Other'                           THEN bls.revenue ELSE 0 END) AS revenue_current_other
    ,SUM(CASE WHEN bls.product_type NOT IN ('Misc', 'Other')            THEN bls.revenue ELSE 0 END) AS revenue_current_total
    ,SUM(CASE WHEN bls.product_type IN ('Display', 'Sponsored Listing') THEN bls.mrr     ELSE 0 END) AS mrr_current_advertisement
    ,SUM(CASE WHEN bls.product_type = 'Pro'                             THEN bls.mrr     ELSE 0 END) AS mrr_current_avvopro
    ,SUM(CASE WHEN bls.product_type = 'Ignite'                          THEN bls.mrr     ELSE 0 END) AS mrr_current_ignite
    ,SUM(CASE WHEN bls.product_type = 'Website'                         THEN bls.mrr     ELSE 0 END) AS mrr_current_website
    ,SUM(CASE WHEN bls.product_type = 'Ad Placement'                    THEN bls.mrr     ELSE 0 END) AS mrr_current_adplacement
    ,SUM(CASE WHEN bls.product_type = 'Other Subscription'              THEN bls.mrr     ELSE 0 END) AS mrr_current_other_sub
    ,SUM(CASE WHEN bls.product_type NOT IN ('Misc', 'Other')            THEN bls.mrr     ELSE 0 END) AS mrr_current_total
  FROM tmp_data_dm.coe_jrr_sub_bills bls
  GROUP BY 1,2,3,4
  ) mth
WHERE mth.has_ads = 'Y' OR mth.mrr_current_total > 0 ; -- LOOK return to this
-- WHERE mth.has_ads = 'Y' ;

DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_lifetime_start ;
-- Note: we are NOT going to change lifetime start to has to have
-- a payment.  I am going to provide a flag in the final data pull,
-- because we kinda want to know how much it happens.
CREATE TABLE tmp_data_dm.coe_jrr_cust_lifetime_start AS
SELECT
   bls.customer_id
  ,MIN(bls.year_month) AS             start_month
  ,MIN(bls.year_month_begin_date) AS  start_month_begin_date
  ,MIN(CASE WHEN bls.has_payment = 'Y' THEN bls.year_month ELSE NULL END) AS first_payment_month
  -- ,MIN(CASE WHEN bls.has_payment = 'Y' THEN bls.year_month_begin_date ELSE NULL END) AS  first_payment_month_begin_date
FROM tmp_data_dm.coe_jrr_cust_active_months bls
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
  ,has_ads                        STRING
  ,has_payment                    STRING
  ,mrr_method                     STRING
  ,max_bill_date_in_month         STRING
  ,customer_continues_past_month  STRING
  ,revenue_current_advertisement  DECIMAL(38,2)
  ,revenue_current_avvopro        DECIMAL(38,2)
  ,revenue_current_ignite         DECIMAL(38,2)
  ,revenue_current_website        DECIMAL(38,2)
  ,revenue_current_adplacement    DECIMAL(38,2)
  ,revenue_current_misc           DECIMAL(38,2)
  ,revenue_current_other_sub      DECIMAL(38,2)
  ,revenue_current_other          DECIMAL(38,2)
  ,revenue_current_total          DECIMAL(38,2)
  ,mrr_current_advertisement      DOUBLE
  ,mrr_current_avvopro            DOUBLE
  ,mrr_current_ignite             DOUBLE
  ,mrr_current_website            DOUBLE
  ,mrr_current_adplacement        DOUBLE
  ,mrr_current_other_sub          DOUBLE
  ,mrr_current_total              DOUBLE
)
PARTITIONED BY (year_month INT)
STORED AS PARQUET ;
WITH table_src AS
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
  ,future.mrr_method
  ,future.max_bill_date_in_month
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
  LEFT JOIN tmp_data_dm.coe_jrr_cust_active_months future 
         ON nc.customer_id = future.customer_id 
        AND nc.start_month <= future.year_month 
        AND future.year_month <= 201610
)
INSERT OVERWRITE TABLE tmp_data_dm.coe_jrr_cust_chains_raw1 PARTITION(year_month)
SELECT
   customer_id
  ,start_month
  ,start_month_begin_date
  ,tenure_month
  ,year_month_begin_date
  ,has_ads
  ,has_payment
  ,mrr_method
  ,max_bill_date_in_month
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
  ,has_ads                        STRING
  ,has_payment                    STRING
  ,mrr_method                     STRING
  ,max_bill_date_in_month         STRING
  ,customer_continues_past_month  STRING
  ,revenue_current_advertisement  DECIMAL(38,2)
  ,revenue_current_avvopro        DECIMAL(38,2)
  ,revenue_current_ignite         DECIMAL(38,2)
  ,revenue_current_website        DECIMAL(38,2)
  ,revenue_current_adplacement    DECIMAL(38,2)
  ,revenue_current_misc           DECIMAL(38,2)
  ,revenue_current_other_sub      DECIMAL(38,2)
  ,revenue_current_other          DECIMAL(38,2)
  ,revenue_current_total          DECIMAL(38,2)
  ,mrr_current_advertisement      DOUBLE
  ,mrr_current_avvopro            DOUBLE
  ,mrr_current_ignite             DOUBLE
  ,mrr_current_website            DOUBLE
  ,mrr_current_adplacement        DOUBLE
  ,mrr_current_other_sub          DOUBLE
  ,mrr_current_total              DOUBLE
  -- ,year_month                     INT
  ,chain_id_raw                     BIGINT
  ,rnk                              BIGINT
  ,active_months_to_date            BIGINT
  ,tenure_month_prior               BIGINT
  ,has_ads_prior                    STRING
  ,has_payment_prior                STRING
  ,customer_continues_past_month_prior STRING
  ,customer_prev_billed_date        STRING
  ,revenue_prior_advertisement      DECIMAL(38,2)
  ,revenue_prior_avvopro            DECIMAL(38,2)
  ,revenue_prior_ignite             DECIMAL(38,2)
  ,revenue_prior_website            DECIMAL(38,2)
  ,revenue_prior_adplacement        DECIMAL(38,2)
  ,revenue_prior_misc               DECIMAL(38,2)
  ,revenue_prior_other_sub          DECIMAL(38,2)
  ,revenue_prior_other              DECIMAL(38,2)
  ,revenue_prior_total              DECIMAL(38,2)
  ,mrr_prior_advertisement          DOUBLE
  ,mrr_prior_avvopro                DOUBLE
  ,mrr_prior_ignite                 DOUBLE
  ,mrr_prior_website                DOUBLE
  ,mrr_prior_adplacement            DOUBLE
  ,mrr_prior_other_sub              DOUBLE
  ,mrr_prior_total                  DOUBLE
  ,mrr_next_advertisement           DOUBLE
  ,mrr_next_avvopro                 DOUBLE
  ,mrr_next_ignite                  DOUBLE
  ,mrr_next_website                 DOUBLE
  ,mrr_next_adplacement             DOUBLE
  ,mrr_next_other_sub               DOUBLE
  ,mrr_next_total                   DOUBLE
)
PARTITIONED BY (year_month INT)
STORED AS PARQUET ;
WITH table_src AS
(
SELECT
   mth.*
  ,DENSE_RANK()    OVER(PARTITION BY mth.customer_id
                            ORDER BY mth.tenure_month) - mth.tenure_month AS chain_id_raw
  ,DENSE_RANK()    OVER(PARTITION BY mth.customer_id
                            ORDER BY mth.tenure_month) AS rnk
  ,ROW_NUMBER()    OVER(PARTITION BY mth.customer_id
                            ORDER BY mth.tenure_month) AS active_months_to_date
  ,LAG(mth.tenure_month)                  OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS tenure_month_prior
  ,LAG(mth.has_ads)                       OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS has_ads_prior
  ,LAG(mth.has_payment)                   OVER(PARTITION BY mth.customer_id
                                                   ORDER BY mth.tenure_month) AS has_payment_prior
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
  ,has_ads
  ,has_payment
  ,mrr_method
  ,max_bill_date_in_month
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
  ,has_ads_prior
  ,has_payment_prior
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
  ,has_ads                          STRING
  ,has_payment                      STRING
  ,customer_active_current_month    STRING
  ,customer_active_prior_month      STRING
  ,customer_exists_prior_month      STRING
  ,mrr_method                       STRING
  ,max_bill_date_in_month           STRING
  -- ,customer_continues_past_month    STRING
  ,revenue_current_advertisement    DECIMAL(38,2)
  ,revenue_current_avvopro          DECIMAL(38,2)
  ,revenue_current_ignite           DECIMAL(38,2)
  ,revenue_current_website          DECIMAL(38,2)
  ,revenue_current_adplacement      DECIMAL(38,2)
  ,revenue_current_misc             DECIMAL(38,2)
  ,revenue_current_other_sub        DECIMAL(38,2)
  ,revenue_current_other            DECIMAL(38,2)
  ,revenue_current_total            DECIMAL(38,2)
  ,mrr_current_advertisement        DOUBLE
  ,mrr_current_avvopro              DOUBLE
  ,mrr_current_ignite               DOUBLE
  ,mrr_current_website              DOUBLE
  ,mrr_current_adplacement          DOUBLE
  ,mrr_current_other_sub            DOUBLE
  ,mrr_current_total                DOUBLE
  ,tenure_month_prev                BIGINT
  ,has_ads_prior                    STRING
  ,has_payment_prior                STRING
  ,revenue_prior_advertisement      DECIMAL(38,2)
  ,revenue_prior_avvopro            DECIMAL(38,2)
  ,revenue_prior_ignite             DECIMAL(38,2)
  ,revenue_prior_website            DECIMAL(38,2)
  ,revenue_prior_adplacement        DECIMAL(38,2)
  ,revenue_prior_misc               DECIMAL(38,2)
  ,revenue_prior_other_sub          DECIMAL(38,2)
  ,revenue_prior_other              DECIMAL(38,2)
  ,revenue_prior_total              DECIMAL(38,2)
  ,mrr_prior_advertisement          DOUBLE
  ,mrr_prior_avvopro                DOUBLE
  ,mrr_prior_ignite                 DOUBLE
  ,mrr_prior_website                DOUBLE
  ,mrr_prior_adplacement            DOUBLE
  ,mrr_prior_other_sub              DOUBLE
  ,mrr_prior_total                  DOUBLE
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
   ,adj.has_ads
   ,adj.has_payment
   -- ,'Y' AS                                                           customer_billed_current_month
   -- ,CASE WHEN adj.tenure_month_chain    = 0 THEN 'N' ELSE 'Y' END AS customer_billed_prior_month
   ,CASE WHEN adj.has_ads     = 'Y' AND adj.customer_continues_past_month = 'Y' THEN 'Y'
         WHEN adj.has_payment = 'Y' AND adj.customer_continues_past_month = 'Y' THEN 'Y'
         ELSE 'N' END AS                                             customer_active_current_month
   ,CASE WHEN adj.tenure_month_chain = 0 THEN 'N'
         WHEN adj.has_ads_prior     = 'Y' AND adj.customer_continues_past_month_prior = 'Y' THEN 'Y'
         WHEN adj.has_payment_prior = 'Y' AND adj.customer_continues_past_month_prior = 'Y' THEN 'Y'
         ELSE 'N' END AS                                             customer_active_prior_month
   ,CASE WHEN adj.tenure_month_lifetime = 0 THEN 'N' ELSE 'Y' END AS customer_exists_prior_month
   ,adj.mrr_method
   ,adj.max_bill_date_in_month
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
    -- all of next month's values for this month's MRR.
    ,CASE WHEN adj.tenure_month_chain = 0 AND adj.year_month <= 201407 AND IFNULL(adj.mrr_next_total, 0) > 0
          THEN adj.mrr_next_advertisement
          ELSE adj.mrr_current_advertisement END AS  mrr_current_advertisement
    ,CASE WHEN adj.tenure_month_chain = 0 AND adj.year_month <= 201407 AND IFNULL(adj.mrr_next_total, 0) > 0
          THEN adj.mrr_next_avvopro
          ELSE adj.mrr_current_avvopro END AS        mrr_current_avvopro
    ,CASE WHEN adj.tenure_month_chain = 0 AND adj.year_month <= 201407 AND IFNULL(adj.mrr_next_total, 0) > 0
          THEN adj.mrr_next_ignite
          ELSE adj.mrr_current_ignite END AS         mrr_current_ignite
    ,CASE WHEN adj.tenure_month_chain = 0 AND adj.year_month <= 201407 AND IFNULL(adj.mrr_next_total, 0) > 0
          THEN adj.mrr_next_website
          ELSE adj.mrr_current_website END AS        mrr_current_website
    ,CASE WHEN adj.tenure_month_chain = 0 AND adj.year_month <= 201407 AND IFNULL(adj.mrr_next_total, 0) > 0
          THEN adj.mrr_next_adplacement
          ELSE adj.mrr_current_adplacement END AS    mrr_current_adplacement
    ,CASE WHEN adj.tenure_month_chain = 0 AND adj.year_month <= 201407 AND IFNULL(adj.mrr_next_total, 0) > 0
          THEN adj.mrr_next_other_sub
          ELSE adj.mrr_current_other_sub END AS      mrr_current_other_sub
    ,CASE WHEN adj.tenure_month_chain = 0 AND adj.year_month <= 201407 AND IFNULL(adj.mrr_next_total, 0) > 0
          THEN adj.mrr_next_total
          ELSE adj.mrr_current_total END AS          mrr_current_total
    ,adj.tenure_month_prev
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 'N' ELSE adj.has_ads_prior END AS              has_ads_prior
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 'N' ELSE adj.has_payment_prior END AS          has_payment_prior
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.revenue_prior_advertisement END AS  revenue_prior_advertisement
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.revenue_prior_avvopro END AS        revenue_prior_avvopro
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.revenue_prior_ignite END AS         revenue_prior_ignite
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.revenue_prior_website END AS        revenue_prior_website
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.revenue_prior_adplacement END AS    revenue_prior_adplacement
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.revenue_prior_misc END AS           revenue_prior_misc
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.revenue_prior_other_sub END AS      revenue_prior_other_sub
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.revenue_prior_other END AS          revenue_prior_other
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.revenue_prior_total END AS          revenue_prior_total
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.mrr_prior_advertisement END AS      mrr_prior_advertisement
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.mrr_prior_avvopro END AS            mrr_prior_avvopro
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.mrr_prior_ignite END AS             mrr_prior_ignite
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.mrr_prior_website END AS            mrr_prior_website
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.mrr_prior_adplacement END AS        mrr_prior_adplacement
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.mrr_prior_other_sub END AS          mrr_prior_other_sub
    ,CASE WHEN adj.tenure_month_chain = 0 THEN 0 ELSE adj.mrr_prior_total END AS              mrr_prior_total
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
                                          ORDER BY chn.tenure_month) - 1 AS tenure_month_chain
    ,chn.tenure_month AS tenure_month_lifetime
    ,chn.active_months_to_date
    ,MIN(chn.year_month)            OVER(PARTITION BY chn.customer_id, chn.chain_id_raw
                                             ORDER BY chn.tenure_month) AS start_month_chain
    ,MIN(chn.year_month_begin_date) OVER(PARTITION BY chn.customer_id, chn.chain_id_raw
                                             ORDER BY chn.tenure_month) AS start_month_begin_date_chain
    ,chn.start_month AS start_month_lifetime
    ,chn.start_month_begin_date AS start_month_begin_date_lifetime
    ,chn.has_ads
    ,chn.has_payment
    ,chn.mrr_method
    ,chn.max_bill_date_in_month
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
    ,chn.has_ads_prior
    ,chn.has_payment_prior
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
  ,has_ads
  ,has_payment
  ,customer_active_current_month
  ,customer_active_prior_month
  ,customer_exists_prior_month
  ,mrr_method
  ,max_bill_date_in_month
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
  ,has_ads_prior
  ,has_payment_prior
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

-- -- Get the beginning values (counts and mrr) for each cohort
-- DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cohort_start_values ;
-- CREATE TABLE tmp_data_dm.coe_jrr_cohort_start_values AS
-- SELECT
--    srt.start_month_chain
--   ,srt.start_month_begin_date_chain
--   ,SUM(srt.mrr_current_advertisement) AS mrr
--   ,COUNT(DISTINCT srt.customer_id) AS customers
--   ,SUM(srt.revenue_current_advertisement) AS revenue
-- FROM tmp_data_dm.coe_jrr_cust_chains srt
-- WHERE srt.has_ads = 'Y'
--   AND srt.chain_number = 1
--   AND srt.tenure_month_chain = 0
--   AND srt.customer_continues_past_month = 'Y'
-- GROUP BY 1,2 ;
-- -- SELECT  -- LOOK
-- --    srt.start_month_chain
-- --   ,srt.start_month_begin_date_chain
-- --   ,SUM(srt.mrr_current_total) AS mrr
-- --   ,COUNT(DISTINCT srt.customer_id) AS customers
-- --   ,SUM(srt.revenue_current_total) AS revenue
-- -- FROM tmp_data_dm.coe_jrr_cust_chains srt
-- -- WHERE srt.chain_number = 1
-- --   AND srt.tenure_month_chain = 0
-- -- GROUP BY 1,2 ;

-- -- Join from cohort start table to every month that the customer got billed in.
-- -- This is the main query for spreadsheet.
-- DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cohort_months ;
-- CREATE TABLE tmp_data_dm.coe_jrr_cohort_months AS
-- SELECT
--    x.start_month
--   ,CONCAT('M',LPAD(CAST(x.tenure_month AS string),2,'0')) AS tenure_month  -- M1, M2, ...
--   ,x.year_month
--   ,x.new_customers
--   ,x.new_mrr
--   ,x.new_revenue
--   ,x.retained_customers
--   ,x.retained_mrr
--   ,x.retained_revenue
-- FROM
--   (
--     SELECT
--        chn.start_month_chain AS             start_month
--       ,chn.start_month_begin_date_chain AS  start_month_begin_date
--       ,chn.tenure_month_chain AS            tenure_month
--       ,chn.year_month
--       ,chn.year_month_begin_date
--       -- maybe don''t have to do these because I have them in cac - then i could just union?  think I am ok.
--       -- only reason for max is they are always same value and we want to just grab 1.
--       -- Could make these attributes and group by them instead if that is easier to grasp.
--       ,MAX(cac.customers) AS                       new_customers
--       ,MAX(cac.mrr) AS                             new_mrr
--       ,MAX(cac.revenue) AS                         new_revenue
--       ,COUNT(DISTINCT chn.customer_id) AS          retained_customers
--       ,SUM(chn.mrr_current_advertisement) AS       retained_mrr
--       ,SUM(chn.revenue_current_advertisement) AS   retained_revenue
--       -- ,SUM(chn.mrr_current_total) AS               retained_mrr  -- LOOK
--       -- ,SUM(chn.revenue_current_total) AS           retained_revenue
--     FROM tmp_data_dm.coe_jrr_cust_chains chn
--     LEFT JOIN tmp_data_dm.coe_jrr_cohort_start_values cac 
--            ON chn.start_month_chain = cac.start_month_chain
--     WHERE chn.chain_number = 1
--       AND chn.tenure_month_chain IS NOT NULL
--       AND chn.has_ads = 'Y'  -- LOOK
--       AND chn.customer_continues_past_month = 'Y'
--     GROUP BY 1,2,3,4,5
--   ) x ;

-- -- This reshapes things,
-- -- and fills in months if the prior query has lost all the customers
-- -- as of a certain month, but we still want 0 rows in the results so 
-- -- it looks right (and rolls up right).
-- -- Probably don''t even need this if I am producing output for every customer.
-- -- This just shows new and retained.
-- -- She calculates churned in tableau.
-- DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_final ;
-- CREATE TABLE tmp_data_dm.coe_jrr_final AS
-- SELECT zz.* 
-- FROM
-- (
--   SELECT z.start_month
--     , z.tenure_month
--     , z.year_month
--     , FIRST_VALUE(z.new_customers)      OVER (PARTITION BY z.start_month ORDER BY z.tenure_month) AS new_customers
--     , z.retained_customers
--     , FIRST_VALUE(z.new_mrr)            OVER (PARTITION BY z.start_month ORDER BY z.tenure_month) AS new_mrr
--     , z.retained_mrr
--     , FIRST_VALUE(z.new_revenue)        OVER (PARTITION BY z.start_month ORDER BY z.tenure_month) AS new_revenue
--     , z.retained_revenue
--   FROM
--   (
--     SELECT y.start_month
--       , y.tenure_month
--       , y.year_month
--       , SUM(y.new_customers) AS new_customers
--       , SUM(y.retained_customers) AS retained_customers
--       , SUM(y.new_mrr) AS new_mrr
--       , SUM(y.retained_mrr) AS retained_mrr
--       , SUM(y.new_revenue) AS new_revenue
--       , SUM(y.retained_revenue) AS retained_revenue
--     FROM
--     (
--       -- This part just gets you zero-billed months rows 
--       SELECT DISTINCT start_month
--         , tenure_month 
--         , year_month
--         , 0 AS new_customers
--         , 0 AS retained_customers
--         , 0 AS new_mrr
--         , 0 AS retained_mrr
--         , 0 AS new_revenue
--         , 0 AS retained_revenue
--       FROM 
--       (
--         SELECT DISTINCT ym.start_month
--           ,  CONCAT('M',LPAD(CAST(ym.tenure_month AS STRING),2,'0')) AS tenure_month
--           , ym.year_month
--         FROM
--         (
--           SELECT DISTINCT x1.year_month AS start_month
--             , x2.year_month
--             , (cast(substring(cast(x2.year_month as string), 1,4) as int)-cast(substring(cast(x1.year_month as string), 1,4) as int))*12
--                   + (cast(substring(cast(x2.year_month as string), 5,2) as int)-cast(substring(cast(x1.year_month as string), 5,2) as int)) as tenure_month
--           FROM dm.date_dim x1
--           JOIN dm.date_dim x2 ON x1.year_month<=x2.year_month  
--           WHERE x1.year_month BETWEEN 201303 AND 201610
--             AND x2.year_month BETWEEN 201303 AND 201610
--         ) ym
--       ) x

--       UNION ALL

--       SELECT start_month
--         , tenure_month
--         , year_month
--         , new_customers
--         , retained_customers 
--         , new_mrr
--         , retained_mrr
--         , new_revenue
--         , retained_revenue
--       FROM tmp_data_dm.coe_jrr_cohort_months
--     ) y
--     GROUP BY 1,2,3
--   ) z
-- ) zz
-- WHERE zz.new_customers > 0
--   AND zz.start_month <= 201610 ;


-- SELECT * FROM tmp_data_dm.coe_jrr_final
-- WHERE start_month >= 201304 ;


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
  ,has_ads                          STRING
  ,has_payment                      STRING
  ,mrr_method                       STRING
  ,max_bill_date_in_month           STRING
  ,revenue_current_advertisement    DECIMAL(38,2)
  ,revenue_current_avvopro          DECIMAL(38,2)
  ,revenue_current_ignite           DECIMAL(38,2)
  ,revenue_current_website          DECIMAL(38,2)
  ,revenue_current_adplacement      DECIMAL(38,2)
  ,revenue_current_misc             DECIMAL(38,2)
  ,revenue_current_other_sub        DECIMAL(38,2)
  ,revenue_current_other            DECIMAL(38,2)
  ,revenue_current_total            DECIMAL(38,2)
  ,mrr_current_advertisement        DOUBLE
  ,mrr_current_avvopro              DOUBLE
  ,mrr_current_ignite               DOUBLE
  ,mrr_current_website              DOUBLE
  ,mrr_current_adplacement          DOUBLE
  ,mrr_current_other_sub            DOUBLE
  ,mrr_current_total                DOUBLE
  ,tenure_month_prev                BIGINT
  ,has_ads_prior                    STRING
  ,has_payment_prior                STRING
  ,revenue_prior_advertisement      DECIMAL(38,2)
  ,revenue_prior_avvopro            DECIMAL(38,2)
  ,revenue_prior_ignite             DECIMAL(38,2)
  ,revenue_prior_website            DECIMAL(38,2)
  ,revenue_prior_adplacement        DECIMAL(38,2)
  ,revenue_prior_misc               DECIMAL(38,2)
  ,revenue_prior_other_sub          DECIMAL(38,2)
  ,revenue_prior_other              DECIMAL(38,2)
  ,revenue_prior_total              DECIMAL(38,2)
  ,mrr_prior_advertisement          DOUBLE
  ,mrr_prior_avvopro                DOUBLE
  ,mrr_prior_ignite                 DOUBLE
  ,mrr_prior_website                DOUBLE
  ,mrr_prior_adplacement            DOUBLE
  ,mrr_prior_other_sub              DOUBLE
  ,mrr_prior_total                  DOUBLE
  ,mrr_customer_category            STRING
  ,mrr_acquired                     DOUBLE
  ,mrr_penetrated                   DOUBLE
  ,mrr_downsized                    DOUBLE
  ,mrr_churned                      DOUBLE
  ,mrr_retained                     DOUBLE
  ,mrr_returned                     DOUBLE
  ,mrr_retained_subset_flat_customers   DOUBLE
  ,mrr_retained_subset_delta_customers  DOUBLE
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
  ,chn.has_ads
  ,chn.has_payment
  ,chn.customer_active_current_month
  ,chn.customer_active_prior_month
  ,chn.customer_exists_prior_month
  ,chn.mrr_method
  ,chn.max_bill_date_in_month
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
  ,chn.has_ads_prior
  ,chn.has_payment_prior
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

  ,CASE WHEN chn.customer_active_current_month = 'Y' AND
             chn.customer_exists_prior_month = 'N' THEN         'ACQUIRED'

        WHEN chn.customer_active_current_month = 'Y' AND
             chn.customer_active_prior_month = 'N' AND
             chn.customer_exists_prior_month = 'Y' THEN         'RETURNED'
             
        WHEN chn.customer_active_current_month = 'Y' AND
             chn.customer_active_prior_month = 'Y' AND
             chn.mrr_current_total > chn.mrr_prior_total THEN   'PENETRATED'

        WHEN chn.customer_active_current_month = 'Y' AND
             chn.customer_active_prior_month = 'Y' AND
             chn.mrr_current_total > 0 AND
             chn.mrr_current_total  =  chn.mrr_prior_total THEN 'RETAINED'

        WHEN chn.customer_active_current_month = 'Y' AND
             chn.customer_active_prior_month = 'Y' AND
             chn.mrr_current_total < chn.mrr_prior_total THEN   'DOWNSIZED'

        WHEN chn.customer_active_current_month = 'N' AND
             chn.customer_active_prior_month   = 'Y' THEN       'CHURNED'

        WHEN chn.customer_active_current_month = 'Y' AND
             chn.customer_active_prior_month   = 'Y' AND
             chn.mrr_current_total = 0 AND
             chn.mrr_prior_total = 0 THEN                       'NO ACTIVITY'
        ELSE 'NOT BILLED' END AS                              mrr_customer_category

  ,CASE WHEN chn.customer_active_current_month = 'Y' AND
             chn.customer_exists_prior_month = 'N' THEN           chn.mrr_current_total
              ELSE 0 END AS                                   mrr_acquired
  ,CASE WHEN chn.customer_active_current_month = 'Y' AND
             chn.customer_active_prior_month = 'N' AND
             chn.customer_exists_prior_month = 'Y' THEN           chn.mrr_current_total
              ELSE 0 END AS                                   mrr_returned
  ,CASE WHEN chn.customer_active_current_month = 'Y' AND
             chn.customer_active_prior_month = 'Y' AND
             chn.mrr_current_total > chn.mrr_prior_total THEN     (chn.mrr_current_total - chn.mrr_prior_total)
              ELSE 0 END AS                                   mrr_penetrated
  ,CASE WHEN -- RETAINED
             chn.customer_active_current_month = 'Y' AND
             chn.customer_active_prior_month = 'Y' AND
             chn.mrr_current_total > 0 AND
             chn.mrr_current_total  =  chn.mrr_prior_total THEN   chn.mrr_current_total
        WHEN -- DOWNSIZED
             chn.customer_active_current_month = 'Y' AND
             chn.customer_active_prior_month = 'Y' AND
             chn.mrr_current_total < chn.mrr_prior_total THEN     chn.mrr_current_total
        WHEN -- PENETRATED
             chn.customer_active_current_month = 'Y' AND
             chn.customer_active_prior_month = 'Y' AND
             chn.mrr_current_total > chn.mrr_prior_total THEN     chn.mrr_prior_total
              ELSE 0 END AS                                   mrr_retained
  ,CASE WHEN chn.customer_active_current_month = 'Y' AND
             chn.customer_active_prior_month = 'Y' AND
             chn.mrr_current_total < chn.mrr_prior_total THEN     (chn.mrr_current_total - chn.mrr_prior_total) 
              ELSE 0 END AS                                   mrr_downsized
  ,CASE WHEN chn.customer_active_current_month = 'N' AND
             chn.customer_active_prior_month   = 'Y' THEN         chn.mrr_prior_total
              ELSE 0 END AS                                   mrr_churned

  -- This is the portion of mrr_retained for customers in the RETAINED category.
  ,CASE WHEN chn.customer_active_current_month = 'Y' AND
             chn.customer_active_prior_month = 'Y' AND
             chn.mrr_current_total > 0 AND
             chn.mrr_current_total  =  chn.mrr_prior_total THEN   chn.mrr_current_total 
              ELSE 0 END AS                                   mrr_retained_subset_flat_customers
  -- This is the portion of mrr_retained for customers in the PENETRATED and DOWNSIZED categories.
  ,CASE WHEN -- DOWNSIZED
             chn.customer_active_current_month = 'Y' AND
             chn.customer_active_prior_month = 'Y' AND
             chn.mrr_current_total < chn.mrr_prior_total THEN     chn.mrr_current_total
        WHEN -- PENETRATED
             chn.customer_active_current_month = 'Y' AND
             chn.customer_active_prior_month = 'Y' AND
             chn.mrr_current_total > chn.mrr_prior_total THEN     chn.mrr_prior_total
              ELSE 0 END AS                                   mrr_retained_subset_delta_customers
  ,CASE WHEN srt.first_payment_month <= chn.year_month THEN 'Y' ELSE 'N' END AS has_had_payment_lifetime
  -- ,CASE WHEN something <= chn.year_month THEN 'Y' ELSE 'N' END AS has_had_payment_chain
FROM
             tmp_data_dm.coe_jrr_cust_chains chn
  INNER JOIN tmp_data_dm.coe_jrr_cust_lifetime_start srt
          ON chn.customer_id = srt.customer_id
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
  ,has_ads
  ,has_payment
  ,mrr_method
  ,max_bill_date_in_month
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
  ,has_ads_prior
  ,has_payment_prior
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
  ,CASE WHEN mrr_customer_category = 'NO ACTIVITY' THEN 'No Activity'
        WHEN mrr_customer_category = 'PENETRATED' AND
             mrr_prior_total = 0 THEN                   'Upsold from 0'
        WHEN mrr_customer_category = 'DOWNSIZED' AND
             mrr_current_total = 0 THEN                 'Downsized to 0'
        WHEN mrr_customer_category = 'DOWNSIZED' AND
             mrr_current_total = 0 THEN                 'Downsized to 0'
        WHEN has_payment = 'N' AND
             mrr_current_total = 0 AND
             customer_active_current_month = 'Y' THEN    'No payment, 0 MRR, but active'
        ELSE 'OK'
   END AS                                                     mrr_customer_exception
  ,year_month
FROM table_src ;
COMPUTE INCREMENTAL STATS tmp_data_dm.coe_jrr_backfill_customer_mrr ;
