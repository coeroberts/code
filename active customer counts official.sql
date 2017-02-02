-- This query returns the active customer counts and advertiser
-- counts from December 2014 on.  There are two sections because 
-- we need to use a different method prior to November 2015.
-- Active customers for a month are defined as all customers 
-- who have at least one subscription as of the end of the month 
-- that is either an advertising subscription or a paying 
-- subscription (or both).
-- If you need the data at an individual level, just add customer_id 
-- to both parts.
-- If you are just running to get recent data, you can use the part 
-- before the UNION.
SELECT
   mrr.yearmonth AS year_month
  ,SUM(CASE WHEN (mca.customer_id IS NOT NULL) THEN 1 ELSE 0 END) AS advertisers
  ,SUM(CASE WHEN (mrr.mrr_current_total <> 0 OR mca.customer_id IS NOT NULL) THEN 1 ELSE 0 END) AS active_customers
FROM dm.mrr_customer_category_all_products mrr
  LEFT OUTER JOIN dm.mrr_customer_classification mca
          ON mrr.customer_id = mca.customer_id
         AND mrr.yearmonth = mca.yearmonth
WHERE mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
  AND mrr.yearmonth >= 201511
GROUP BY 1
  UNION ALL
SELECT
   ord.year_month
  ,SUM(CASE WHEN ord.max_expire_year_month > ord.year_month AND  ord.has_ads LIKE 'Y%' THEN 1 ELSE 0 END) AS                             advertisers
  ,SUM(CASE WHEN ord.max_expire_year_month > ord.year_month AND (ord.has_ads LIKE 'Y%' OR ord.is_paying LIKE 'Y%') THEN 1 ELSE 0 END) AS active_customers
FROM
  (
  SELECT
     dt.year_month
    ,olaf.customer_id
    ,MAX(CASE WHEN sub.expire_year_month > dt.year_month AND olaf.product_line_id IN (2,7) THEN 'Yes has ads' ELSE 'No ads' END) AS                has_ads
    ,MAX(CASE WHEN sub.expire_year_month > dt.year_month AND olaf.order_line_net_price_amount_usd > 0 THEN 'Yes paying' ELSE 'Not paying' END) AS  is_paying
    ,MAX(sub.expire_year_month) AS                                                                       max_expire_year_month
  FROM         dm.order_line_accumulation_fact olaf 
    INNER JOIN dm.date_dim dt
            ON olaf.order_line_begin_date = dt.actual_date
    LEFT OUTER JOIN dm.product_line_dimension pld
            ON olaf.product_line_id = pld.product_line_id
    LEFT OUTER JOIN
               (
               SELECT
                  subscription_id
                 ,CASE WHEN IFNULL(expire_datetime, '1900-01-01') LIKE '1900-%' THEN 299901
                       ELSE CAST(CONCAT(CAST(YEAR(TO_DATE(expire_datetime)) AS STRING), 
                                        LPAD(CAST(MONTH(TO_DATE(expire_datetime)) AS STRING), 2, '0')) AS INTEGER)
                  END AS expire_year_month
               FROM dm.subscription_dimension
               WHERE subscription_id <> -1
               ) sub
            ON olaf.product_subscription_id = sub.subscription_id
  WHERE dt.year_month BETWEEN 201412 AND 201510
  GROUP BY 1,2
  ) ord
GROUP BY 1
