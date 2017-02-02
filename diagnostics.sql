-- order_line_accumulation_fact
SELECT
   olaf.*
  ,STRLEFT(olaf.order_line_begin_date, 7) AS year_month
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
FROM
             dm.order_line_accumulation_fact olaf
  LEFT OUTER JOIN dm.product_line_dimension pld
          ON olaf.product_line_id = pld.product_line_id
WHERE
   olaf.customer_id = 13737
   -- AND olaf.order_line_begin_date BETWEEN '2015-11-01' AND '2015-11-30'
ORDER BY olaf.order_line_begin_date, olaf.product_subscription_id

-- mrr_customer_category_all_products
SELECT *
FROM dm.mrr_customer_category_all_products
WHERE customer_id IN (24586)
order by yearmonth

-- mrr_subscription_all_products
SELECT *
FROM dm.mrr_subscription_all_products
WHERE customer_id IN (24586)
order by yearmonth, subscription_id

SELECT sp.block_count * sp.unit_price AS total_price, sp.*
FROM dm.historical_subscription_price_dimension sp
WHERE sp.subscription_id IN (
10012137, 10065457, 10097623, 10177475, 10177476, 10177477,
10177478, 10177479, 10177480, 10198194, 10234116, 10234117,
10336290, 10362135, 9287880, 9287881, 9287882, 9287883,
9287884, 9287885, 9367002, 9367003)
ORDER BY etl_effective_begin_date, start_datetime



John Musca is 6841.

----

-- SELECT * FROM tmp_data_dm.coe_mbf_sub_mrr
-- WHERE customer_id = 2377

-- SELECT * FROM tmp_data_dm.coe_mbf_cust_mrr
-- WHERE customer_id = 15672
-- ORDER BY year_month

-- SELECT * FROM tmp_data_dm.coe_mbf_sub_mrr mrr
-- inner join tmp_data_dm.coe_mbf_sub_mrr1 mrr1
-- on mrr.subscription_id = mrr1.subscription_id
-- WHERE mrr.customer_id = 2377
----

SELECT
   dt.year_month
  ,dt.month_begin_date AS year_month_begin_date
  ,dt.month_end_date AS year_month_end_date
  ,IFNULL(mrr.mrr_actual, 0) AS full_price
  ,GREATEST(CASE WHEN olaf.order_line_cancelled_date = '-1' THEN NULL ELSE olaf.order_line_cancelled_date END
           ,mrr.expired_date) AS max_expired_date
  ,CASE WHEN LOWER(mrr.expired_reason) = 'failed cc' THEN 'Y' ELSE 'N' END AS has_cc_failure_during_month
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
  ,olaf.*
FROM         dm.order_line_accumulation_fact olaf
  INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
  LEFT OUTER JOIN dm.mrr_subscription_all_products mrr
          ON olaf.product_subscription_id = mrr.subscription_id
         AND olaf.product_subscription_id <> -1
         AND dt.year_month = mrr.yearmonth
  LEFT OUTER JOIN dm.product_line_dimension pld
          ON olaf.product_line_id = pld.product_line_id
WHERE olaf.order_line_begin_date BETWEEN '2016-09-01' AND '2016-09-30'
and olaf.customer_id = 54324

SELECT * FROM dm.mrr_customer_all_products
WHERE yearmonth = 201609
AND customer_id = 54324

SELECT * FROM dm.mrr_customer_category_all_products
WHERE yearmonth = 201609
AND customer_id = 20

SELECT * FROM dm.mrr_subscription_all_products
WHERE yearmonth = 201609
AND customer_id = 54324
