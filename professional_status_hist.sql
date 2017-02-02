-- Structure of result table:
-- customer_id
-- professional_id
-- year_month
-- year_month_begin_date
-- order_line_begin_date:       Date on which the subscription goes into effect (which is often not the purchase date)
-- subscription_id
-- product_line_id
-- product_type:                'Display', 'Sponsored Listing', 'Pro', 'Ignite', 'Website', 'Misc',
--                              'Ad Placement', 'Other Subscription', 'Other'
-- has_ads_during_month:        This is an ads subscription and it was running on at least one day in the month
-- has_ads_eom:                 This is an ads subscription that extends beyond the last day in the month
-- has_non_ads_during_month:    This is a non-ads subscription and it was running on at least one day in the month
-- has_non_ads_eom:             This is a non-ads subscription that extends beyond the last day in the month
-- has_payment_during_month:    There was at least one payment in the month
-- sub_continues_past_month:    This is a subscription (of any type) that extends beyond the last day in the month
-- revenue:                     Actual billed amount in the month
-- has_cc_failure_during_month: There was at least one cc failure in the month

-- Get the MRR for every subscription that exists.
-- This will only be used for the in-between time period:
-- recent enough that we have a subscription to join to,
-- but not so recent that we actually have mrr data already.
-- I tested to see if we need to use the hist_ version of
-- this table, and concluded that it reconciles fine without that.
DROP TABLE IF EXISTS tmp_data_dm.coe_prr_sub_price ;
CREATE TABLE tmp_data_dm.coe_prr_sub_price AS
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
       WHERE TO_DATE(deleted_datetime) IS NULL
       ) AS spd_curr 
WHERE seq = 1 ;

-- NOTE: This does does not, and should not, return the MRR values,
-- because in some cases MRR is not prorated correctly.  But we can use
-- the amounts in the logic, because all the logic wants to know is if
-- it's zero or non-zero.
DROP TABLE IF EXISTS tmp_data_dm.coe_prr_sub_bills ;
CREATE TABLE tmp_data_dm.coe_prr_sub_bills AS
SELECT
   uns.customer_id
  ,uns.professional_id
  ,uns.year_month
  ,uns.year_month_begin_date
  ,uns.order_line_begin_date
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
  ,CASE WHEN uns.product_line_id IN (2, 7, 18) THEN 'Y' ELSE 'N' END AS        has_ads_during_month
  ,CASE WHEN uns.product_line_id IN (2, 7, 18) AND
             IFNULL(uns.max_expired_date, '2999-01-01') > uns.year_month_end_date THEN 'Y' ELSE 'N' END AS has_ads_eom
  ,CASE WHEN uns.product_line_id NOT IN (2, 7, 18) THEN 'Y' ELSE 'N' END AS        has_non_ads_during_month
  ,CASE WHEN uns.product_line_id NOT IN (2, 7, 18) AND
             IFNULL(uns.max_expired_date, '2999-01-01') > uns.year_month_end_date THEN 'Y' ELSE 'N' END AS has_non_ads_eom
  -- Note: the only orders I see with non-zero revenue and no payment are refunds.
  ,CASE WHEN uns.order_line_payment_date NOT IN ('1900-01-01', '-1') 
         AND uns.order_line_net_price_amount_usd > 0 THEN 'Y' ELSE 'N' END AS  has_payment_during_month
  ,MAX(CASE WHEN IFNULL(uns.max_expired_date, '2999-01-01') > uns.year_month_end_date THEN 'Y' 
            ELSE 'N' END) AS                                                   sub_continues_past_month
  ,CAST(SUM(CASE WHEN uns.order_line_payment_date NOT IN ('1900-01-01', '-1') THEN uns.order_line_net_price_amount_usd 
              ELSE 0 END) AS DECIMAL(20,2)) AS                                 revenue
  ,MAX(uns.has_cc_failure_during_month) AS                                     has_cc_failure_during_month
FROM
  (
      SELECT
         olaf.*
        ,'MRR with phase 2 base code' AS mrr_method
        ,dt.year_month
        ,dt.month_begin_date AS year_month_begin_date
        ,dt.month_end_date AS year_month_end_date
        ,IFNULL(mrr.mrr_actual, 0) AS full_price
        ,CASE WHEN olaf.order_line_cancelled_date = '-1' THEN mrr.expired_date
              WHEN olaf.order_line_cancelled_date > mrr.expired_date THEN olaf.order_line_cancelled_date
              ELSE mrr.expired_date
         END AS max_expired_date
        ,CASE WHEN LOWER(mrr.expired_reason) = 'failed cc' THEN 'Y' ELSE 'N' END AS has_cc_failure_during_month
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
        ,CASE WHEN olaf.order_line_cancelled_date = '-1' AND from_unixtime(unix_timestamp(sub.expire_datetime), 'yyyy-MM-dd') = '1900-01-01' THEN NULL
              WHEN olaf.order_line_cancelled_date = '-1'                                                                                     THEN from_unixtime(unix_timestamp(sub.expire_datetime), 'yyyy-MM-dd')
              WHEN                                           from_unixtime(unix_timestamp(sub.expire_datetime), 'yyyy-MM-dd') = '1900-01-01' THEN olaf.order_line_cancelled_date
              WHEN olaf.order_line_cancelled_date > from_unixtime(unix_timestamp(sub.expire_datetime), 'yyyy-MM-dd')                         THEN olaf.order_line_cancelled_date
              ELSE from_unixtime(unix_timestamp(sub.expire_datetime), 'yyyy-MM-dd')
         END AS max_expired_date
        ,CASE WHEN LOWER(sub.expired_reason) = 'failed cc' THEN 'Y' ELSE 'N' END AS has_cc_failure_during_month
      FROM         dm.order_line_accumulation_fact olaf
        INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
        LEFT OUTER JOIN dm.subscription_dimension sub
                ON olaf.product_subscription_id = sub.subscription_id
        LEFT OUTER JOIN tmp_data_dm.coe_prr_sub_price mrr
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
        -- IMPORTANT: this means the the mrr amount is incorrect at the 
        -- subscription and professional level for very old data.  In
        -- the actual backfill code, it gets adjusted in a later query.
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
        ,NULL AS has_cc_failure_during_month
      FROM         dm.order_line_accumulation_fact olaf
        INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
        INNER JOIN dm.month_dim mth ON dt.year_month = mth.year_month
      WHERE olaf.order_line_begin_date BETWEEN '2010-01-01' AND '2014-08-31'
  ) uns
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13 ;
