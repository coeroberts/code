Note about long-term MRR categories:
Probably should only count as Acquired if active after EoM as well.

Finance Dash Visual
  FinanceDashboard.Contacts.MonthlyContacts radio buttons Advertiser?
  - getting rid of the filter. - done.
  FinanceDashboard.Claims&Adv.TotalAdvertisers - done.
  FinanceDashboard.Claims&Adv.TotalCustomers - done.
  btw, FinanceDashboard.Review&Endorse.MonthlyEndorsements not updated since Jan.  - done.
  Same w/ cumulative. - done.

Finance Dash Tabular - done.
  FinanceDashboard_Tabular_data.ContactsData radio buttons Advertiser?
  - getting rid of the filter. done.
  FinanceDashboard_Tabular_data.AdvertisersData appears to be empty? - done.
  FinanceDashboard_Tabular_data.AdvertisersxMarketData appears to be empty? - hiding it until/unless someone complains.

CompanyKPI Dash
  LawyerEngagement.Advertisers and New Advertisers.  Nadine is currently modifying the report.
  BUT there is YoY data and the new source will not show that for 2015.

----
-- data_source_advertisers_and_customers_by_ad_market.sql

SELECT distinct olaf.professional_id
  , olaf.customer_id
  , olamf.ad_market_id
  , pd.product_line_item_name 
  , dm.year_month
  , amd.ad_region_id
  , amd.ad_market_region_name
  , amd.ad_market_state_name
  , amd.ad_market_county_name
  , amd.ad_market_specialty_name
FROM dm.order_line_accumulation_fact olaf 
left JOIN dm.order_line_ad_market_fact olamf ON olaf.order_line_number = olamf.order_line_number 
JOIN dm.date_dim dm ON dm.actual_date = olaf.order_line_begin_date
left JOIN dm.product_line_dimension pd ON olaf.product_line_id = pd.product_line_id
left join dm.ad_market_dimension amd on amd.ad_market_id = olamf.ad_market_id
  -- AND PLD.product_line_item_name IN ('Display Medium Rectangle','Sponsored Listing') 
where olaf.product_line_id in (2,7) 
  and olaf.order_line_payment_date not like '1900-%'
  and dm.year_month >= 201301

OK so since this includes the ad market attributes, we do need to go
to the olaf level (while my sample customer counting query does not 
need to).

Aha! The only use of the market-level data is a tab I just hid 
(AdvertisersxMarketData).  So don''t need that.
Can change the source to just counts by month, and reinstate the
AdvertisersData tab so I can use that for scorecard.

-- SELECT
-- year_month
-- ,COUNT(advertiser_id) AS advertisers
-- ,COUNT(customer_id) AS   customers
-- FROM
-- (

SELECT DISTINCT
-- Note: This data source has been majorly gutted to:
-- 1) Support the new definition of Customers and Advertisers
--    (Looks like Advertisers used to count professionals 
--     with ads, and Customers counted customers with ads.)
-- 2) Look very much like the old data source (so I don't
--    have to change existing reports).
-- 3) Get rid of the market-level attributes (because they are not
--    currently used, they make the data source big, and getting
--    them with the new counting definitions is not simple.)
-- Active customers for a month are defined as all customers 
-- who have at least one subscription as of the end of the month 
-- that is either an advertising subscription or a paying 
-- subscription (or both).
   mrr.yearmonth AS year_month
  ,CAST(NULL AS INTEGER) AS professional_id  -- LOOK hack; use advertiser_id instead
  ,mca.customer_id AS advertiser_id
  ,CASE WHEN (mrr.mrr_current_total <> 0 OR mca.customer_id IS NOT NULL) THEN mrr.customer_id ELSE NULL END AS customer_id
  ,CAST(NULL AS INTEGER) AS ad_market_id
  ,CAST(NULL AS STRING) AS  product_line_item_name 
  ,CAST(NULL AS INTEGER) AS ad_region_id
  ,CAST(NULL AS STRING) AS  ad_market_region_name
  ,CAST(NULL AS STRING) AS  ad_market_state_name
  ,CAST(NULL AS STRING) AS  ad_market_county_name
  ,CAST(NULL AS STRING) AS  ad_market_specialty_name
  -- ,SUM(CASE WHEN (mca.customer_id IS NOT NULL) THEN 1 ELSE 0 END) AS advertisers
  -- ,SUM(CASE WHEN (mrr.mrr_current_total <> 0 OR mca.customer_id IS NOT NULL) THEN 1 ELSE 0 END) AS active_customers
FROM dm.mrr_customer_category_all_products mrr
  LEFT OUTER JOIN dm.mrr_customer_classification mca
          ON mrr.customer_id = mca.customer_id
         AND mrr.yearmonth = mca.yearmonth
WHERE mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
  AND mrr.yearmonth >= 201511
UNION ALL
SELECT DISTINCT
   ord.year_month
  ,CAST(NULL AS INTEGER) AS professional_id  -- LOOK hack; use advertiser_id instead
  ,CASE WHEN ord.max_expire_year_month > ord.year_month AND  ord.has_ads LIKE 'Y%' THEN ord.customer_id ELSE NULL END AS advertiser_id
  ,CASE WHEN ord.max_expire_year_month > ord.year_month AND (ord.has_ads LIKE 'Y%' OR ord.is_paying LIKE 'Y%') THEN ord.customer_id ELSE NULL END AS customer_id
  ,CAST(NULL AS INTEGER) AS ad_market_id
  ,CAST(NULL AS STRING) AS  product_line_item_name 
  ,CAST(NULL AS INTEGER) AS ad_region_id
  ,CAST(NULL AS STRING) AS  ad_market_region_name
  ,CAST(NULL AS STRING) AS  ad_market_state_name
  ,CAST(NULL AS STRING) AS  ad_market_county_name
  ,CAST(NULL AS STRING) AS  ad_market_specialty_name
  -- ,SUM(CASE WHEN ord.max_expire_year_month > ord.year_month AND  ord.has_ads LIKE 'Y%' THEN 1 ELSE 0 END) AS                             advertisers
  -- ,SUM(CASE WHEN ord.max_expire_year_month > ord.year_month AND (ord.has_ads LIKE 'Y%' OR ord.is_paying LIKE 'Y%') THEN 1 ELSE 0 END) AS active_customers
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

-- ) qry
-- GROUP BY 1 ORDER BY 1

----
data_source_CompanyKPI.advertisers.sql
SELECT
   dm.year_month
   , dm.month_begin_date
   , count(distinct( olaf.professional_id)) as cnt_professional_id
FROM DM.ORDER_LINE_ACCUMULATION_FACT OLAF 
left JOIN DM.order_line_ad_market_fact OLAMF ON OLAF.order_line_number = OLAMF.order_line_number 
JOIN DM.DATE_DIM DM ON DM.actual_date = OLAF.ORDER_LINE_BEGIN_DATE
left JOIN DM.PRODUCT_LINE_DIMENSION PLD ON OLAF.PRODUCT_LINE_ID = PLD.PRODUCT_LINE_ID 
where olaf.PRODUCT_LINE_ID in (2,7) 
  and olaf.order_line_payment_date not like '1900-%'
  and dm.year_month >= 201401
Group by 1,2

SELECT
-- Note: This data source has been changed to:
-- 1) Support the new definition of Customers and Advertisers
--    (Looks like Advertisers used to count professionals 
--     with ads, and Customers counted customers with ads.)
-- 2) Look very much like the old data source (so I don't
--    have to change existing reports).
-- Active customers for a month are defined as all customers 
-- who have at least one subscription as of the end of the month 
-- that is either an advertising subscription or a paying 
-- subscription (or both).
   mrr.yearmonth AS year_month
  ,mth.month_begin_date
  ,SUM(CASE WHEN (mca.customer_id IS NOT NULL) THEN 1 ELSE 0 END) AS advertisers
  -- ,SUM(CASE WHEN (mca.customer_id IS NOT NULL) THEN 1 ELSE 0 END) AS cnt_professional_id
FROM dm.mrr_customer_category_all_products mrr
  INNER JOIN dm.month_dim mth
          ON mrr.yearmonth = mth.year_month
  LEFT OUTER JOIN dm.mrr_customer_classification mca
          ON mrr.customer_id = mca.customer_id
         AND mrr.yearmonth = mca.yearmonth
WHERE mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
  AND mrr.yearmonth >= 201511
GROUP BY 1,2
UNION ALL
SELECT
   ord.year_month
  ,ord.month_begin_date
  ,SUM(CASE WHEN ord.max_expire_year_month > ord.year_month AND  ord.has_ads LIKE 'Y%' THEN 1 ELSE 0 END) AS advertisers
  -- ,SUM(CASE WHEN ord.max_expire_year_month > ord.year_month AND  ord.has_ads LIKE 'Y%' THEN 1 ELSE 0 END) AS cnt_professional_id
FROM
  (
  SELECT
     dt.year_month
    ,dt.month_begin_date
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
  WHERE dt.year_month BETWEEN 201501 AND 201510
  GROUP BY 1,2,3
  ) ord
GROUP BY 1,2

----

data_source_CompanyKPI.new_advertisers.sql
SELECT
   olaf.professional_id
   , min(dm.month_begin_date) as first_admonth
FROM DM.order_line_accumulation_fact OLAF 
left JOIN DM.order_line_ad_market_fact OLAMF ON OLAF.order_line_number = OLAMF.order_line_number 
JOIN DM.DATE_DIM DM ON DM.actual_date = OLAF.order_line_begin_date
left JOIN DM.product_line_dimension PLD ON OLAF.product_line_id = PLD.product_line_id
where olaf.product_line_id in (2,7) 
  and olaf.order_line_payment_date not like '1900-%'
group by olaf.professional_id


-- SELECT
-- year_month
-- ,COUNT(advertiser_id) AS advertisers
-- ,COUNT(customer_id) AS   customers
-- FROM
-- (

-- SELECT DISTINCT
-- -- Note: This data source has been majorly gutted to:
-- -- 1) Support the new definition of Customers and Advertisers
-- --    (Looks like Advertisers used to count professionals 
-- --     with ads, and Customers counted customers with ads.)
-- -- 2) Look very much like the old data source (so I don't
-- --    have to change existing reports).
-- -- 3) Get rid of the market-level attributes (because they are not
-- --    currently used, they make the data source big, and getting
-- --    them with the new counting definitions is not simple.)
-- -- Active customers for a month are defined as all customers 
-- -- who have at least one subscription as of the end of the month 
-- -- that is either an advertising subscription or a paying 
-- -- subscription (or both).
--    mrr.yearmonth AS year_month
--   ,mrr.customer_id  -- LOOK remove
--   ,mca.customer_id AS professional_id  -- LOOK hack; use advertiser_id instead
--   ,mca.customer_id AS advertiser_id
-- FROM dm.mrr_customer_category_all_products mrr
--   LEFT OUTER JOIN dm.mrr_customer_classification mca
--           ON mrr.customer_id = mca.customer_id
--          AND mrr.yearmonth = mca.yearmonth
-- WHERE mrr.mrr_customer_category IN ('ACQUIRED')
--   AND mrr.yearmonth >= 201511
-- UNION ALL
-- SELECT DISTINCT
--    ord.year_month
--   ,ord.customer_id
--   ,CASE WHEN ord.max_expire_year_month > ord.year_month AND  ord.has_ads LIKE 'Y%' THEN ord.customer_id ELSE NULL END AS professional_id  -- LOOK hack; use advertiser_id instead
--   ,CASE WHEN ord.max_expire_year_month > ord.year_month AND  ord.has_ads LIKE 'Y%' THEN ord.customer_id ELSE NULL END AS advertiser_id
-- FROM
--   (
--   SELECT
--      dt.year_month
--     ,olaf.customer_id
--     ,MAX(CASE WHEN sub.expire_year_month > dt.year_month AND olaf.product_line_id IN (2,7) THEN 'Yes has ads' ELSE 'No ads' END) AS                has_ads
--     ,MAX(CASE WHEN sub.expire_year_month > dt.year_month AND olaf.order_line_net_price_amount_usd > 0 THEN 'Yes paying' ELSE 'Not paying' END) AS  is_paying
--     ,MAX(sub.expire_year_month) AS                                                                       max_expire_year_month
--   FROM         dm.order_line_accumulation_fact olaf 
--     INNER JOIN dm.date_dim dt
--             ON olaf.order_line_begin_date = dt.actual_date
--   WHERE dt.year_month BETWEEN 201412 AND 201510
--   GROUP BY 1,2
--   ) ord

-- ) qry
-- GROUP BY 1 ORDER BY 1

-- SELECT
-- year_month
-- ,COUNT(advertiser_id) AS new_advertisers
-- ,COUNT(customer_id) AS   new_customers
-- FROM
-- (

-- SELECT DISTINCT
--    mrr.yearmonth AS year_month
--   ,mrr.customer_id  -- LOOK just here for checking
--   ,mca.customer_id AS professional_id  -- LOOK hack; use advertiser_id instead
--   ,mca.customer_id AS advertiser_id
-- FROM dm.mrr_customer_category_all_products mrr
--   LEFT OUTER JOIN dm.mrr_customer_classification mca
--           ON mrr.customer_id = mca.customer_id
--          AND mrr.yearmonth = mca.yearmonth
-- WHERE mrr.mrr_customer_category IN ('ACQUIRED')
--   AND mrr.yearmonth >= 201511

-- ) qry
-- GROUP BY 1 ORDER BY 1

From olaf, get custid, min(order_line_begin_date) (or min month start)
where either has ads or is paying.  nope, don''t care if they are paying
because i only want advertisers.

-- SELECT
-- year_month
-- ,COUNT(advertiser_id) AS new_advertisers
-- ,COUNT(customer_id) AS   new_customers
-- FROM
-- (

-- SELECT DISTINCT
--    ord.acquisition_month_start AS year_month
--   ,NULL AS customer_id  -- leaving this out of here even for checking because not all customers.
--   ,ord.customer_id AS professional_id  -- LOOK hack; use advertiser_id instead
--   ,ord.customer_id AS             advertiser_id
-- FROM
--   (
--   SELECT
--      olaf.customer_id
--     ,MIN(dt.month_begin_date) AS acquisition_month_start
--   FROM         dm.order_line_accumulation_fact olaf 
--     INNER JOIN dm.date_dim dt
--             ON olaf.order_line_begin_date = dt.actual_date
--   -- WHERE dt.year_month BETWEEN 201412 AND 201510
--   WHERE dt.year_month >= 201501  -- LOOK
--     AND olaf.product_line_id IN (2,7)
--     AND olaf.order_line_payment_date NOT LIKE '1900-%'
--     AND olaf.order_line_payment_date <> '-1'
--   GROUP BY 1
--   ) ord

-- ) qry
-- GROUP BY 1 ORDER BY 1

-- SELECT order_line_begin_date, order_line_payment_date, COUNT(*) AS num_rows
-- FROM dm.order_line_accumulation_fact
-- WHERE order_line_payment_date IN ('-1', '1900-01-01')
--   AND order_line_begin_date LIKE '2015%'
-- GROUP BY 1,2
-- ORDER BY 1



-- SELECT
--  year_month
-- ,COUNT(advertiser_id) AS new_advertisers
-- FROM
-- (

SELECT DISTINCT
   ord.first_admonth
  ,NULL AS customer_id  -- leaving this out of here even for checking because not all customers.
  ,ord.customer_id AS professional_id  -- LOOK hack; use advertiser_id instead
  ,ord.customer_id AS             advertiser_id
FROM
  (
  SELECT
     olaf.customer_id
    ,MIN(dt.month_begin_date) AS first_admonth
  FROM         dm.order_line_accumulation_fact olaf 
    INNER JOIN dm.date_dim dt
            ON olaf.order_line_begin_date = dt.actual_date
  WHERE olaf.product_line_id IN (2,7)
    AND olaf.order_line_payment_date NOT LIKE '1900-%'
    AND olaf.order_line_payment_date <> '-1'
  GROUP BY 1
  ) ord
WHERE ord.first_admonth >= '2014-01-01'

-- ) qry
-- GROUP BY 1 ORDER BY 1

Oh.  Filter on ad product can''t be in the inner query either.
Need to get first month, then get whether or not they had
ads in that month.
Ugh.

OK.  MRR version grabs their first month, and only counts them if
they were an advertiser in that month.
olaf version grabs the first month in which they were an advertiser,
ignoring any earlier months in which they might not have been an 
advertiser.
I think I prefer the olaf way?  Yes.
