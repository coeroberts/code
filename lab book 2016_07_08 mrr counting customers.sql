----
Nadine''s suggestion for scorecard:

SELECT 
dm.year_month,
count (distinct olaf.cust_ID) as customer_id
FROM DM.ORDER_LN_ACCUM_FACT OLAF 
left JOIN DM.order_line_ad_market_fact OLAMF ON OLAF.ORDER_LN_NBR = OLAMF.order_line_number 
JOIN DM.DATE_DIM DM ON DM.actual_date = OLAF.ORDER_LN_BEGIN_USE_DATE
left JOIN DM.PRODUCT_LN_DIM PLD ON OLAF.PRODUCT_LN_KEY = PLD.PRODUCT_LN_KEY 
left join dm.ad_market_dimension amd on amd.ad_market_id = olamf.ad_market_id
  -- AND PLD.PRODUCT_LN_ITM_NAME IN ('Display Medium Rectangle','Sponsored Listing') 
-- left JOIN DM.AD_DIM ad on ad.ad_key = olamf.ad_key
where olaf.order_paymnt_date not like '1900-%'
and dm.year_month >= 201301
group by 1


----
-- First let''s try to replicate the numbers I currently see in the scorecard.
SELECT 
   dm.year_month
  ,COUNT(DISTINCT olaf.customer_id) AS customers
FROM dm.order_line_accumulation_fact olaf 
  LEFT OUTER JOIN dm.order_line_ad_market_fact olamf
          ON olaf.order_line_number = olamf.order_line_number 
  INNER JOIN dm.date_dim dm
          ON dm.actual_date = olaf.order_line_begin_date
  LEFT OUTER JOIN dm.product_line_dimension pld
          ON olaf.product_line_id = pld.product_line_id
  LEFT OUTER JOIN dm.ad_market_dimension amd
          ON amd.ad_market_id = olamf.ad_market_id
WHERE olaf.order_line_payment_date NOT LIKE '1900-%'
  AND dm.year_month >= 201601
  AND olaf.product_line_id IN (2,7)  -- Advertisers, whether paying or not.
GROUP BY 1
ORDER BY 1

OK since this is EOP, I wonder if I need a filter to make sure they were a customer at EOM?
I don''t think the current scorecard has that.
Something like order_line_end_date > EoM?

SELECT
   SUM(order_line_package_price_amount_usd) AS    order_line_package_price_amount_usd  -- MSRP but it''s lower than I expect
  ,SUM(order_line_price_adjusted_amount_usd) AS   order_line_price_adjusted_amount_usd
  ,SUM(order_line_purchase_price_amount_usd) AS   order_line_purchase_price_amount_usd
  ,SUM(order_line_fee_amount_usd) AS              order_line_fee_amount_usd
  ,SUM(order_line_cancelled_price_amount_usd) AS  order_line_cancelled_price_amount_usd
  ,SUM(order_line_net_price_amount_usd) AS        order_line_net_price_amount_usd
FROM dm.order_line_accumulation_fact olaf
WHERE olaf.order_line_begin_date BETWEEN '2016-06-01' AND '2016-06-30'

SELECT 
   cust.year_month
  ,cust.has_ads
  ,cust.is_purch_paying
  ,cust.is_net_paying
  ,cust.had_payment
  ,cust.had_1900_payment
  ,cust.had_minus_1_payment
  ,COUNT(*) AS potential_customers
  ,COUNT(CASE WHEN has_ads LIKE 'Y%' THEN customer_id ELSE NULL END) AS ad_customers
  ,COUNT(CASE WHEN has_ads LIKE 'Y%' OR is_purch_paying LIKE 'Y%' THEN customer_id ELSE NULL END) AS customers
FROM
  (
  SELECT
   dm.year_month
  ,olaf.customer_id
  -- ,MAX(CASE WHEN olaf.product_line_id IN (2,7) THEN 'Y' ELSE 'N' END) AS has_ads
  -- ,MAX(CASE WHEN olaf.order_line_purchase_price_amount_usd > 0 THEN 'Y' ELSE 'N' END) AS is_paying
  -- ,MAX(CASE WHEN olaf.order_line_payment_date NOT LIKE '1900-%' THEN 'Y' ELSE 'N' END) AS had_payment
  ,MAX(CASE WHEN olaf.product_line_id IN (2,7) THEN 'Yes has ads' ELSE 'No ads' END) AS has_ads
  ,MAX(CASE WHEN olaf.order_line_purchase_price_amount_usd > 0 THEN 'Yes purch paying' ELSE 'Not purch paying' END) AS is_purch_paying
  ,MAX(CASE WHEN olaf.order_line_net_price_amount_usd > 0 THEN 'Yes net paying' ELSE 'Not net paying' END) AS is_net_paying
  ,MAX(CASE WHEN olaf.order_line_payment_date NOT LIKE '1900-%' AND olaf.order_line_payment_date NOT LIKE '-1%' THEN 'Yes had payment' ELSE 'No payment' END) AS had_payment
  ,MAX(CASE WHEN olaf.order_line_payment_date LIKE '1900-%' THEN 'Yes had 1900 payment' ELSE 'No 1900 payment' END) AS had_1900_payment
  ,MAX(CASE WHEN olaf.order_line_payment_date LIKE '-1%' THEN 'Yes had minus 1 payment' ELSE 'No minus 1 payment' END) AS had_minus_1_payment
  ,COUNT(*) AS order_lines
  FROM         dm.order_line_accumulation_fact olaf 
    LEFT OUTER JOIN dm.order_line_ad_market_fact olamf
            ON olaf.order_line_number = olamf.order_line_number 
    INNER JOIN dm.date_dim dm
            ON dm.actual_date = olaf.order_line_begin_date
    LEFT OUTER JOIN dm.product_line_dimension pld
            ON olaf.product_line_id = pld.product_line_id
    LEFT OUTER JOIN dm.ad_market_dimension amd
            ON amd.ad_market_id = olamf.ad_market_id
  -- WHERE olaf.order_line_payment_date NOT LIKE '1900-%'
  WHERE dm.year_month >= 201601
  GROUP BY 1,2
  ) cust
GROUP BY 1,2,3,4,5,6,7

Weird.  Only 1 line in 2016 where olaf.order_line_payment_date  LIKE '1900-%'
Ah, that was replaced by -1.

OK.  Going to order data to count customers is a mess (as the above illustrates).
Go to MRR table for customer counts.

OLAF changes

----

mrr_customer_category_all_products
  ,customer_id
  ,mrr_customer_category
  ,mrr_current_advertisement
  ,mrr_current_avvopro
  ,mrr_current_ignite
  ,mrr_current_website
  ,mrr_current_adplacement
  ,mrr_current_total
  ,mrr_prior_advertisement
  ,mrr_prior_avvopro
  ,mrr_prior_ignite
  ,mrr_prior_website
  ,mrr_prior_adplacement
  ,mrr_prior_total
  ,revenue_current_advertisement
  ,revenue_current_avvopro
  ,revenue_current_ignite
  ,revenue_current_website
  ,revenue_current_misc
  ,revenue_current_adplacement
  ,revenue_current_total
  ,revenue_prior_advertisement
  ,revenue_prior_avvopro
  ,revenue_prior_ignite
  ,revenue_prior_website
  ,revenue_prior_misc
  ,revenue_prior_adplacement
  ,revenue_prior_total
  ,mrr_acquired
  ,mrr_penetrated
  ,mrr_downsized
  ,mrr_churned
  ,mrr_retained
  ,mrr_returned
  ,expired_date
  ,expired_reason
  ,block_conversion_flag
  ,refund_current_month_flag
  ,customer_prev_billed_date
  ,customer_billed_current_month_flag
  ,yearmonth

SELECT
   yearmonth
  ,mrr_customer_category
  ,customer_billed_current_month_flag
  ,COUNT(*) AS potential_customers
FROM dm.mrr_customer_category_all_products
GROUP BY 1,2,3

OK cancel_date is the thing we look at to see if sub was active as of EoM.
And MRR category is for the customer, while the expired_date is probably
populated if any of their subscriptions expired, so that''s why I see customers
with expired_date populated but MRR category is RETAINED, for example.

Take bills during the month.  Use them to categorize kidney.
Join to MRR table for that month and pull appropriate categories
because that indicates EoM state.

customer_billed_current_month_flag seems to correspond directly to 'NOT BILLED' category
(and not to maybe category where they had an order but at $0)
By billed, this means order actually.

Can join to mrr_customer_classification and if they are there then they had ads.

Thinking about the kidney:
Paying vs. Free and Advertisers vs. Other
PA, FA, PO, FO

mrr = mrr_customer_category_all_products
mca = mrr_customer_classification (current advertisers only)

Paying Advertisers:
                 (    mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
                  AND mrr.mrr_current_advertisement > 0)
Free Advertisers:(    mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
                  AND mrr.mrr_current_total = 0
                  AND mca.customer_id IS NOT NULL)
Paying Other:    (    mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
                  AND mrr.mrr_current_advertisement = 0
                  AND mrr.mrr_current_total > 0)
Free Other:      (    mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
                  AND mrr.mrr_current_total = 0
                  AND mca.customer_id IS NULL)
Kidney:          (    mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
                  AND (   mrr.mrr_current_total > 0
                       OR mca.customer_id IS NOT NULL) )

'ACQUIRED', 
'DOWNSIZED', 
'NO ACTIVITY', 
'PENETRATED', 
'RETAINED', 
'RETURNED', 

'CHURNED', 
'NOT BILLED', 

SELECT
   mrr.yearmonth
  ,COUNT(*) AS advertisers  -- mostly
FROM dm.mrr_customer_category_all_products mrr
  INNER JOIN dm.mrr_customer_classification mca
          ON mrr.customer_id = mca.customer_id
         AND mrr.yearmonth = mca.yearmonth
GROUP BY 1
ORDER BY 1

Check: If counting customers as of EoM, do we count people who churned in the month?
No.

  ,SUM(CASE WHEN (    mrr.mrr_current_advertisement > 0 )
                THEN 1 ELSE 0 END) AS paying_advertisers
  ,SUM(CASE WHEN (    mrr.mrr_current_total = 0
                  AND mca.customer_id IS NOT NULL )
                THEN 1 ELSE 0 END) AS free_advertisers
  ,SUM(CASE WHEN (    mrr.mrr_current_advertisement = 0
                  AND mrr.mrr_current_total > 0 )
                THEN 1 ELSE 0 END) AS paying_other
  ,SUM(CASE WHEN (    mrr.mrr_current_total = 0
                  AND mca.customer_id IS NULL )
                THEN 1 ELSE 0 END) AS free_other
  ,SUM(CASE WHEN (    mca.customer_id IS NOT NULL )
                THEN 1 ELSE 0 END) AS advertisers
  ,SUM(CASE WHEN (    (   mrr.mrr_current_total > 0
                       OR mca.customer_id IS NOT NULL) )
                THEN 1 ELSE 0 END) AS customers

SELECT
   yearmonth
  -- ,customer_id
  ,has_ads
  ,paying_ads
  ,paying_total
  ,expire_cat
  ,paying_advertisers
  ,free_advertisers
  ,paying_other
  ,free_other
  ,advertisers
  ,paying_advertisers + free_advertisers AS advertisers_calc
  ,advertisers - (paying_advertisers + free_advertisers) AS advertisers_diff
  ,customers
  ,paying_advertisers + free_advertisers + paying_other AS customers_calc
  ,customers - (paying_advertisers + free_advertisers + paying_other) AS customers_diff
  ,num_rows
FROM (
SELECT
   mrr.yearmonth
  -- ,mrr.customer_id
  ,CASE WHEN mca.customer_id IS NOT NULL        THEN 'Yes has ads' ELSE 'No ads'                     END AS has_ads
  ,CASE WHEN mrr.mrr_current_advertisement <> 0 THEN 'Yes paying for ads' ELSE 'Not paying for ads'  END AS paying_ads
  ,CASE WHEN mrr.mrr_current_total <> 0         THEN 'Yes paying total' ELSE 'Not paying total'      END AS paying_total
  ,CASE WHEN mrr.expired_date IS NULL THEN '1. No Sub Expire'
        WHEN mrr.expired_date < mth.month_begin_date THEN '2. Sub Expire Before Month'
        WHEN mrr.expired_date BETWEEN mth.month_begin_date AND mth.month_end_date THEN '3. Sub Expire During Month'
        WHEN mrr.expired_date > mth.month_end_date THEN '4. Sub Expire After Month'
   END AS expire_cat
  ,SUM(CASE WHEN (mrr.mrr_current_advertisement <> 0 )                              THEN 1 ELSE 0 END) AS paying_advertisers
  ,SUM(CASE WHEN (mrr.mrr_current_total = 0 AND mca.customer_id IS NOT NULL )       THEN 1 ELSE 0 END) AS free_advertisers
  ,SUM(CASE WHEN (mrr.mrr_current_advertisement = 0 AND mrr.mrr_current_total > 0 ) THEN 1 ELSE 0 END) AS paying_other
  ,SUM(CASE WHEN (mrr.mrr_current_total = 0 AND mca.customer_id IS NULL )           THEN 1 ELSE 0 END) AS free_other
  ,SUM(CASE WHEN (mca.customer_id IS NOT NULL )                                     THEN 1 ELSE 0 END) AS advertisers  -- MUST calc this.
  ,SUM(CASE WHEN (mrr.mrr_current_total <> 0 OR mca.customer_id IS NOT NULL)        THEN 1 ELSE 0 END) AS customers
  ,SUM(1) AS num_rows
FROM dm.mrr_customer_category_all_products mrr
  INNER JOIN dm.month_dim mth
          ON mrr.yearmonth = mth.year_month
  LEFT OUTER JOIN dm.mrr_customer_classification mca
          ON mrr.customer_id = mca.customer_id
         AND mrr.yearmonth = mca.yearmonth
WHERE mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
GROUP BY 1,2,3,4,5
) qry
-- WHERE has_ads LIKE 'Y%'
--   AND paying_ads LIKE 'N%'
--   AND paying_total LIKE 'Y%'
ORDER BY 1

SELECT
   mrr.yearmonth
  ,SUM(CASE WHEN (mrr.mrr_current_total <> 0 OR mca.customer_id IS NOT NULL)        THEN 1 ELSE 0 END) AS customers
FROM dm.mrr_customer_category_all_products mrr
  INNER JOIN dm.month_dim mth
          ON mrr.yearmonth = mth.year_month
  LEFT OUTER JOIN dm.mrr_customer_classification mca
          ON mrr.customer_id = mca.customer_id
         AND mrr.yearmonth = mca.yearmonth
WHERE mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
GROUP BY 1
ORDER BY 1


The MRR table only goes back through Nov 2015 so we need a way to 
approximate before then.  Or backfill.

OK total number of advertisers is higher than paying ads + free ads.
Should get advertiser or not always from mca,
and paying or not from mrr.

SELECT *, STRLEFT(olaf.order_line_begin_date, 7) AS year_month
FROM
             dm.order_line_accumulation_fact olaf
  LEFT OUTER JOIN dm.product_line_dimension pd
          ON olaf.product_line_id = pd.product_line_id
WHERE olaf.order_line_begin_date >= '2015-11-01'
  AND CONCAT(CAST(olaf.customer_id AS STRING), ' - ', STRLEFT(olaf.order_line_begin_date, 7)) IN (
'16217 - 2015-11', '7829 - 2015-11', '37910 - 2015-11', '21156 - 2015-11', '31938 - 2015-11', '37440 - 2015-11', '42506 - 2015-11',
'836 - 2015-11', '10392 - 2015-11', '41736 - 2015-11', '16468 - 2015-11', '41931 - 2015-11', '16583 - 2015-11', '39343 - 2015-11',
'21654 - 2015-11', '32521 - 2015-11', '26932 - 2015-11', '39560 - 2015-11', '41641 - 2015-11', '34194 - 2015-11', '25732 - 2015-11',
'34462 - 2015-11', '27109 - 2015-11', '42339 - 2015-12', '836 - 2015-12', '37709 - 2015-12', '14814 - 2015-12', '33490 - 2015-12',
'170 - 2015-12', '27664 - 2015-12', '38410 - 2015-12', '43521 - 2015-12', '18939 - 2015-12', '27574 - 2015-12', '11550 - 2015-12',
'37910 - 2015-12', '16217 - 2015-12', '7829 - 2015-12', '12917 - 2015-12', '34449 - 2015-12', '26932 - 2015-12', '44609 - 2015-12',
'38685 - 2015-12', '42813 - 2015-12', '49105 - 2015-12', '25732 - 2015-12', '43126 - 2016-01', '32976 - 2016-01', '42295 - 2016-01',
'26932 - 2016-01', '7844 - 2016-01', '41664 - 2016-01', '35885 - 2016-01', '24012 - 2016-01', '13722 - 2016-01', '27033 - 2016-01',
'26833 - 2016-01', '49705 - 2016-01', '42465 - 2016-01', '37936 - 2016-01', '43860 - 2016-01', '40646 - 2016-01', '7557 - 2016-01',
'336 - 2016-01', '41235 - 2016-01', '47476 - 2016-01', '43946 - 2016-01', '16217 - 2016-01', '14921 - 2016-01', '35135 - 2016-01',
'7829 - 2016-01', '39450 - 2016-01', '45605 - 2016-02', '8417 - 2016-02', '41251 - 2016-02', '20047 - 2016-02', '42072 - 2016-02',
'7829 - 2016-02', '26932 - 2016-02', '44614 - 2016-02', '16217 - 2016-02', '32164 - 2016-02', '13773 - 2016-02', '17086 - 2016-02',
'18503 - 2016-02', '43962 - 2016-02', '22166 - 2016-02', '38450 - 2016-03', '38893 - 2016-03', '16825 - 2016-03', '39781 - 2016-03',
'27648 - 2016-03', '16217 - 2016-03', '15026 - 2016-03', '43452 - 2016-03', '36379 - 2016-03', '27203 - 2016-03', '23581 - 2016-03',
'32359 - 2016-03', '35829 - 2016-03', '7829 - 2016-03', '26932 - 2016-03', '25746 - 2016-03', '26780 - 2016-03', '21233 - 2016-04',
'7829 - 2016-04', '16217 - 2016-04', '7835 - 2016-04', '46885 - 2016-04', '24570 - 2016-04', '47103 - 2016-04', '41370 - 2016-04',
'38087 - 2016-04', '19326 - 2016-04', '49569 - 2016-04', '48154 - 2016-04', '49094 - 2016-04', '49411 - 2016-04', '26326 - 2016-04',
'27843 - 2016-04', '14588 - 2016-04', '38573 - 2016-04', '342 - 2016-04', '46243 - 2016-05', '23595 - 2016-05', '1831 - 2016-05',
'20318 - 2016-05', '49005 - 2016-05', '16515 - 2016-05', '32440 - 2016-05', '49434 - 2016-05', '16217 - 2016-05', '18247 - 2016-05',
'49155 - 2016-05', '7085 - 2016-05', '38573 - 2016-05', '38940 - 2016-05', '7829 - 2016-05', '37008 - 2016-05', '50172 - 2016-05',
'2385 - 2016-05', '37752 - 2016-05', '3543 - 2016-05', '8786 - 2016-05', '4212 - 2016-06', '36006 - 2016-06', '6493 - 2016-06',
'37598 - 2016-06', '25108 - 2016-06', '19964 - 2016-06', '49532 - 2016-06', '7206 - 2016-06', '16217 - 2016-06', '14428 - 2016-06',
'43514 - 2016-06', '7829 - 2016-06')

SELECT *
FROM dm.mrr_customer_category_all_products
WHERE customer_id IN (16217)

OK yeah, their net price on the ads part of the order is 0.



  AND customer_id IN (170, 336, 342, 836, 1831, 2385, 3543, 4212,
6493, 7085, 7206, 7557, 7829, 7835, 7844, 8417, 8786, 10392, 11550,
12917, 13722, 13773, 14428, 14588, 14814, 14921, 15026, 16217,
16468, 16515, 16583, 16825, 17086, 18247, 18503, 18939, 19326,
19964, 20047, 20318, 21156, 21233, 21654, 22166, 23581, 23595,
24012, 24570, 25108, 25732, 25746, 26326, 26780, 26833, 26932,
27033, 27109, 27203, 27574, 27648, 27664, 27843, 31938, 32164,
32359, 32440, 32521, 32976, 33490, 34194, 34449, 34462, 35135,
35829, 35885, 36006, 36379, 37008, 37440, 37598, 37709, 37752,
37910, 37936, 38087, 38410, 38450, 38573, 38685, 38893, 38940,
39343, 39450, 39560, 39781, 40646, 41235, 41251, 41370, 41641,
41664, 41736, 41931, 42072, 42295, 42339, 42465, 42506, 42813, 
43126, 43452, 43514, 43521, 43860, 43946, 43962, 44609, 44614,
45605, 46243, 46885, 47103, 47476, 48154, 49005, 49094, 49105,
49155, 49411, 49434, 49532, 49569, 49705, 50172)

John Musca is 6841.

The weird category is Has Ads, Not Paying for Ads, and Paying for Something.

Maybe I should go to olaf myself.  Will have to for daily anyway.
Hema says should not happen.

SELECT *
FROM dm.mrr_customer_category_all_products mrr
  LEFT OUTER JOIN dm.mrr_customer_classification mca
          ON mrr.customer_id = mca.customer_id
         AND mrr.yearmonth = mca.yearmonth
WHERE mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
  AND CONCAT(CAST(mrr.customer_id AS STRING), ' - ', CAST(mrr.yearmonth AS STRING)) IN (
'4212 - 201606', '6493 - 201606', '7206 - 201606', '7829 - 201606', '14428 - 201606', '16217 - 201606',
'19964 - 201606', '25108 - 201606', '36006 - 201606', '37598 - 201606', '43514 - 201606', '49532 - 201606')

OK, many of these had ads in the month but had expired as of EoM.
They should count as Paying Other.
That means that I can''t just use presence in the ad mrr table as EoM
advertiser.

OK how about the other ones?
SELECT *
FROM dm.mrr_customer_classification
WHERE yearmonth = 201606
  AND customer_id IN (7829, 43514, 16217)

SELECT *, STRLEFT(olaf.order_line_begin_date, 7) AS year_month
FROM
             dm.order_line_accumulation_fact olaf
  LEFT OUTER JOIN dm.product_line_dimension pd
          ON olaf.product_line_id = pd.product_line_id
WHERE olaf.order_line_begin_date >= '2015-11-01'
  AND customer_id IN (7829, 43514, 16217)

Yup they''re for real.  I would like to call them Paying Advertisers.
How can I tell them apart from the other ones?
OH they have both expired_date and cancelled_date set to EoM.
I should incorporate that, not just for those but for other advertisers too.
Maybe for everybody.

Wait no there is a problem with that.  expired_date is set if ANY subscription expires in the month.
There is some subtlety here about definition of churn.
I might want to do something special about expired in month ONLY
in the situation where I saw these exceptions: 
Has Ads, Not Paying for Ads, and Paying for Something
OK.  this edge case only affects advertiser or not.  It does not
affect top-line customer counts.
Since I will likely have to roll my own logic for better than
monthly granularity, maybe I table this edge case for now.

----
Trying to nail down customer counts...

From Jake: 
When I take the MRR report and simply filter for any customer 
who had a “MRR_Current_Total” >$0 for 201606, I get 21,493 vs. 
the 22,486 here (and the 23,322 in the scorecard).
He actually got 21,492.


SELECT
   yearmonth
  ,customer_id
  ,mrr_customer_category
  ,mrr_current_total
  ,has_ads
  ,paying_ads
  ,paying_total
  ,expire_cat
  ,paying_advertisers
  ,free_advertisers
  ,paying_other
  ,free_other
  ,advertisers
  ,paying_advertisers + free_advertisers AS advertisers_calc
  ,advertisers - (paying_advertisers + free_advertisers) AS advertisers_diff
  ,customers
  ,paying_advertisers + free_advertisers + paying_other AS customers_calc
  ,customers - (paying_advertisers + free_advertisers + paying_other) AS customers_diff
  ,num_rows
FROM (
SELECT
   mrr.yearmonth
  ,mrr.customer_id
  ,mrr.mrr_customer_category
  ,mrr.mrr_current_total
  ,CASE WHEN mca.customer_id IS NOT NULL        THEN 'Yes has ads' ELSE 'No ads'                     END AS has_ads
  ,CASE WHEN mrr.mrr_current_advertisement <> 0 THEN 'Yes paying for ads' ELSE 'Not paying for ads'  END AS paying_ads
  ,CASE WHEN mrr.mrr_current_total <> 0         THEN 'Yes paying total' ELSE 'Not paying total'      END AS paying_total
  ,CASE WHEN mrr.expired_date IS NULL THEN '1. No Sub Expire'
        WHEN mrr.expired_date < mth.month_begin_date THEN '2. Sub Expire Before Month'
        WHEN mrr.expired_date BETWEEN mth.month_begin_date AND mth.month_end_date THEN '3. Sub Expire During Month'
        WHEN mrr.expired_date > mth.month_end_date THEN '4. Sub Expire After Month'
   END AS expire_cat
  ,SUM(CASE WHEN (mrr.mrr_current_advertisement <> 0 )                              THEN 1 ELSE 0 END) AS paying_advertisers
  ,SUM(CASE WHEN (mrr.mrr_current_total = 0 AND mca.customer_id IS NOT NULL )       THEN 1 ELSE 0 END) AS free_advertisers
  ,SUM(CASE WHEN (mrr.mrr_current_advertisement = 0 AND mrr.mrr_current_total > 0 ) THEN 1 ELSE 0 END) AS paying_other
  ,SUM(CASE WHEN (mrr.mrr_current_total = 0 AND mca.customer_id IS NULL )           THEN 1 ELSE 0 END) AS free_other
  ,SUM(CASE WHEN (mca.customer_id IS NOT NULL )                                     THEN 1 ELSE 0 END) AS advertisers  -- MUST calc this.
  ,SUM(CASE WHEN (mrr.mrr_current_total <> 0 OR mca.customer_id IS NOT NULL)        THEN 1 ELSE 0 END) AS customers
  ,SUM(1) AS num_rows
FROM dm.mrr_customer_category_all_products mrr
  INNER JOIN dm.month_dim mth
          ON mrr.yearmonth = mth.year_month
  LEFT OUTER JOIN dm.mrr_customer_classification mca
          ON mrr.customer_id = mca.customer_id
         AND mrr.yearmonth = mca.yearmonth
WHERE mrr.yearmonth = 201606
GROUP BY 1,2,3,4,5,6,7,8
) qry
ORDER BY 1

My numbers come from this:
1. Exclude categories CHURNED and NO ACTIVITY
2. Sum customers.

Jakes numbers come from this:
1. Take anyone where mrr_current_total > 0

----

-- Code to hand off to Jake...  (old)
SELECT
   mrr.yearmonth
  ,SUM(CASE WHEN (mca.customer_id IS NOT NULL) THEN 1 ELSE 0 END) AS advertisers
  ,SUM(CASE WHEN (mrr.mrr_current_total <> 0 OR mca.customer_id IS NOT NULL) THEN 1 ELSE 0 END) AS customers
FROM dm.mrr_customer_category_all_products mrr
  LEFT OUTER JOIN dm.mrr_customer_classification mca
          ON mrr.customer_id = mca.customer_id
         AND mrr.yearmonth = mca.yearmonth
WHERE mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
GROUP BY 1
ORDER BY 1

Categorization...
DROP TABLE tmp_data_dm.coe_counting_new;
CREATE TABLE tmp_data_dm.coe_counting_new AS
SELECT
   mrr.yearmonth
,mrr.customer_id
  ,mrr.mrr_customer_category
  ,CASE WHEN mca.customer_id IS NOT NULL        THEN 'Yes has ads' ELSE 'No ads'                     END AS has_ads
  ,CASE WHEN mrr.mrr_current_advertisement <> 0 THEN 'Yes paying for ads' ELSE 'Not paying for ads'  END AS paying_ads
  ,CASE WHEN mrr.mrr_current_total <> 0         THEN 'Yes paying total' ELSE 'Not paying total'      END AS paying_total
  ,SUM(CASE WHEN (mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')) AND (mca.customer_id IS NOT NULL) THEN 1 ELSE 0 END) AS advertisers
  ,SUM(CASE WHEN (mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')) AND (mrr.mrr_current_total <> 0 OR mca.customer_id IS NOT NULL) THEN 1 ELSE 0 END) AS customers
  ,SUM(CASE WHEN (mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')) AND (mrr.mrr_current_total <> 0 OR mca.customer_id IS NOT NULL) THEN mrr_current_total ELSE 0 END) AS mrr
  ,SUM(CASE WHEN                                                                  (mrr.mrr_current_total <> 0 OR mca.customer_id IS NOT NULL) THEN mrr_current_total ELSE 0 END) AS mrr_unfiltered
  ,SUM(1) AS num_rows
FROM dm.mrr_customer_category_all_products mrr
  INNER JOIN dm.month_dim mth
          ON mrr.yearmonth = mth.year_month
  LEFT OUTER JOIN dm.mrr_customer_classification mca
          ON mrr.customer_id = mca.customer_id
         AND mrr.yearmonth = mca.yearmonth
GROUP BY 1,2,3,4,5,6

So, abstracting the logic to hit base data for < Nov 2015:
- As of EoM, customer must still be active.
- Either has ads or is paying (in that month - I don''t enforce that 
  the ad-specific subscription needs to be the one still in effect as of EoM).
So is it this simple?
Go get all subs w/ an order in the month.
Keep only those with either ad product or non-zero MRR.
(How do I define non-zero MRR?  This is where I need Hema''s code.)
Keep only those w/ end date > EoM.

Note that this reveals some edge cases of my current logic:
MRR checks to make sure they don''t expire in the month.
But it is not enforcing that it should be specifically the
qualifying subscription (either ads or paying) that extends
beyond the end of the month.

So there could be customers who had ads during the month, and stopped ads and
stopped paying... crap there could be a lot of these.

Don''t think this handles expire date right still.
-- DROP TABLE tmp_data_dm.coe_counting_hist;
-- CREATE TABLE tmp_data_dm.coe_counting_hist AS
-- SELECT
--    ord.year_month_str
-- ,ord.customer_id
-- ,ord.has_ads
-- ,ord.is_paying
-- ,ord.has_payment
-- ,ord.max_expire_year_month
-- ,CASE WHEN ord.max_expire_year_month IS NULL OR (ord.max_expire_year_month > ord.year_month_str) THEN 'Yes can count' ELSE 'No does not count' END AS                               customer_qual
--   ,SUM(CASE WHEN IFNULL(ord.max_expire_year_month, '299901') > ord.year_month_str AND  ord.has_ads LIKE 'Y%' THEN 1 ELSE 0 END) AS                             advertisers
--   ,SUM(CASE WHEN IFNULL(ord.max_expire_year_month, '299901') > ord.year_month_str AND (ord.has_ads LIKE 'Y%' OR ord.is_paying LIKE 'Y%') THEN 1 ELSE 0 END) AS customers
--   ,COUNT(*) AS num_rows
-- FROM
--   (
--   SELECT
--      CAST(dt.year_month AS STRING) AS                                                                    year_month_str
--     ,olaf.customer_id
--     ,MAX(CASE WHEN olaf.product_line_id IN (2,7) THEN 'Yes has ads' ELSE 'No ads' END) AS                has_ads
--     ,MAX(CASE WHEN olaf.order_line_net_price_amount_usd > 0 THEN 'Yes paying' ELSE 'Not paying' END) AS  is_paying
--     ,MAX(CASE WHEN IFNULL(olaf.order_line_payment_date, '1900-01-01') NOT LIKE '1900-%'
--                AND IFNULL(olaf.order_line_payment_date, '-1') <> '-1'
--                 THEN 'Yes had payment' ELSE 'No payment' END) AS  has_payment
--     ,MAX(sub.expire_year_month) AS                                                                       max_expire_year_month
--   FROM         dm.order_line_accumulation_fact olaf 
--     INNER JOIN dm.date_dim dt
--             ON olaf.order_line_begin_date = dt.actual_date
--     LEFT OUTER JOIN dm.product_line_dimension pld
--             ON olaf.product_line_id = pld.product_line_id
--     LEFT OUTER JOIN
--                (
--                SELECT
--                   subscription_id
--                  ,CASE WHEN IFNULL(expire_datetime, '1900-01-01') LIKE '1900-%' THEN '299901'
--                        ELSE CONCAT(CAST(YEAR(TO_DATE(expire_datetime)) AS STRING), 
--                                    LPAD(CAST(MONTH(TO_DATE(expire_datetime)) AS STRING), 2, '0'))
--                   END AS expire_year_month
--                FROM dm.subscription_dimension
--                ) sub
--             ON olaf.product_subscription_id = sub.subscription_id
--   -- WHERE olaf.order_line_payment_date NOT LIKE '1900-%'  Wait.  We want 0-billed.
--   WHERE dt.year_month BETWEEN 201412 AND 201607
--   GROUP BY 1,2
--   ) ord
-- GROUP BY 1,2,3,4,5,6

Keep only those w/ end date > EoM.

CONCAT(YEAR(TO_DATE(sub.expire_datetime)), LPAD(MONTH(TO_DATE(sub.expire_datetime)), 2, 0)) = ore.yearmonth
OK some dates are NULL and some are 1900-01-01.  Both mean not expired.
Fixed.

OK my numbers are lower than scorecard; much more up til Nov, then closer.
Ah the diffs are because it is the very old calc method before, including
expired subs and stuff like that.  So those differences are already
accounted for.

DROP TABLE tmp_data_dm.coe_counting_hist;
CREATE TABLE tmp_data_dm.coe_counting_hist AS
SELECT
   ord.year_month
,ord.customer_id
,ord.has_ads
,ord.is_paying
,ord.has_payment
,ord.max_expire_year_month
,CASE WHEN ord.max_expire_year_month > ord.year_month THEN 'Yes can count' ELSE 'No does not count' END AS                               customer_qual
  ,SUM(CASE WHEN ord.max_expire_year_month > ord.year_month AND  ord.has_ads LIKE 'Y%' THEN 1 ELSE 0 END) AS                             advertisers
  ,SUM(CASE WHEN ord.max_expire_year_month > ord.year_month AND (ord.has_ads LIKE 'Y%' OR ord.is_paying LIKE 'Y%') THEN 1 ELSE 0 END) AS customers
  ,COUNT(*) AS num_rows
FROM
  (
  SELECT
     dt.year_month
    ,olaf.customer_id
    ,MAX(CASE WHEN sub.expire_year_month > dt.year_month AND olaf.product_line_id IN (2,7) THEN 'Yes has ads' ELSE 'No ads' END) AS                has_ads
    ,MAX(CASE WHEN sub.expire_year_month > dt.year_month AND olaf.order_line_net_price_amount_usd > 0 THEN 'Yes paying' ELSE 'Not paying' END) AS  is_paying
    ,MAX(CASE WHEN sub.expire_year_month > dt.year_month
               AND IFNULL(olaf.order_line_payment_date, '1900-01-01') NOT LIKE '1900-%'
               AND IFNULL(olaf.order_line_payment_date, '-1') <> '-1'
                THEN 'Yes had payment' ELSE 'No payment' END) AS  has_payment
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
           -- AND (sub.expire_year_month IS NULL OR sub.expire_year_month > dt.year_month)
  -- WHERE olaf.order_line_payment_date NOT LIKE '1900-%'  Wait.  We want 0-billed.
  WHERE dt.year_month BETWEEN 201412 AND 201607
  GROUP BY 1,2
  ) ord
GROUP BY 1,2,3,4,5,6

SELECT
CONCAT(in_hist, ' | ', in_curr, ' | ', cust_in_hist, ' | ', cust_in_curr) AS summary
,*
FROM (
SELECT
   IFNULL(hist.year_month, curr.yearmonth) AS year_month
  ,CASE WHEN hist.customer_id IS NULL THEN 'Not in hist' ELSE 'Yes in hist' END AS in_hist
  ,CASE WHEN curr.customer_id IS NULL THEN 'Not in curr' ELSE 'Yes in curr' END AS in_curr
  ,CASE WHEN hist.customers = 1 THEN 'Yes cust in hist' ELSE 'Not cust in hist' END AS cust_in_hist
  ,CASE WHEN curr.customers = 1 THEN 'Yes cust in curr' ELSE 'Not cust in curr' END AS cust_in_curr
  -- ,hist.year_month_str AS         hist_year_month_str
  -- ,hist.customer_id AS            hist_customer_id
  ,hist.has_ads AS                hist_has_ads
  ,hist.is_paying AS              hist_is_paying
  ,hist.has_payment AS            hist_has_payment
  ,hist.max_expire_year_month AS  hist_max_expire_year_month
  ,hist.customer_qual AS          hist_customer_qual
  -- ,curr.yearmonth AS              curr_yearmonth
  -- ,curr.customer_id AS            curr_customer_id
  ,curr.mrr_customer_category AS  curr_mrr_customer_category
  ,curr.has_ads AS                curr_has_ads
  ,curr.paying_ads AS             curr_paying_ads
  ,curr.paying_total AS           curr_paying_total
  ,SUM(hist.advertisers) AS       hist_advertisers
  ,SUM(hist.customers) AS         hist_customers
  ,SUM(curr.advertisers) AS       curr_advertisers
  ,SUM(curr.customers) AS         curr_customers
  ,SUM(curr.mrr) AS               curr_mrr
  ,SUM(curr.mrr_unfiltered) AS    curr_mrr_unfiltered
  ,COUNT(*) AS                    num_rows
FROM              tmp_data_dm.coe_counting_hist hist
  FULL OUTER JOIN tmp_data_dm.coe_counting_new curr
          ON hist.year_month = curr.yearmonth
         AND hist.customer_id = curr.customer_id
WHERE curr.mrr_customer_category <> 'NOT BILLED'
  AND (   hist.year_month BETWEEN 201501 AND 201607
       OR curr.yearmonth                       BETWEEN 201501 AND 201607)
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14
) qry

SELECT * FROM (
SELECT
   IFNULL(hist.year_month, curr.yearmonth) AS  year_month
  ,IFNULL(hist.customer_id, curr.customer_id) AS                    customer_id
  ,CASE WHEN hist.customer_id IS NULL THEN 'Not in hist' ELSE 'Yes in hist' END AS in_hist
  ,CASE WHEN curr.customer_id IS NULL THEN 'Not in curr' ELSE 'Yes in curr' END AS in_curr
  ,CASE WHEN hist.customers = 1 THEN 'Yes cust in hist' ELSE 'Not cust in hist' END AS cust_in_hist
  ,CASE WHEN curr.customers = 1 THEN 'Yes cust in curr' ELSE 'Not cust in curr' END AS cust_in_curr
  -- ,hist.year_month_str AS         hist_year_month_str
  -- ,hist.customer_id AS            hist_customer_id
  ,hist.has_ads AS                hist_has_ads
  ,hist.is_paying AS              hist_is_paying
  ,hist.has_payment AS            hist_has_payment
  ,hist.max_expire_year_month AS  hist_max_expire_year_month
  ,hist.customer_qual AS          hist_customer_qual
  -- ,curr.yearmonth AS              curr_yearmonth
  -- ,curr.customer_id AS            curr_customer_id
  ,curr.mrr_customer_category AS  curr_mrr_customer_category
  ,curr.has_ads AS                curr_has_ads
  ,curr.paying_ads AS             curr_paying_ads
  ,curr.paying_total AS           curr_paying_total
  ,SUM(hist.advertisers) AS       hist_advertisers
  ,SUM(hist.customers) AS         hist_customers
  ,SUM(curr.advertisers) AS       curr_advertisers
  ,SUM(curr.customers) AS         curr_customers
  ,SUM(curr.mrr) AS               curr_mrr
  ,SUM(curr.mrr_unfiltered) AS    curr_mrr_unfiltered
  ,COUNT(*) AS                    num_rows
FROM              tmp_data_dm.coe_counting_hist hist
  FULL OUTER JOIN tmp_data_dm.coe_counting_new curr
          ON hist.year_month = curr.yearmonth
         AND hist.customer_id = curr.customer_id
WHERE curr.mrr_customer_category <> 'NOT BILLED'
  AND (   hist.year_month BETWEEN 201501 AND 201607
       OR curr.yearmonth                       BETWEEN 201501 AND 201607)
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
) qry
WHERE (year_month = 201606)
  AND (cust_in_hist LIKE 'Y%' AND cust_in_curr LIKE 'N%')

SELECT
   olaf.*
  ,pld.product_line_item_name
  ,sub.*
FROM         dm.order_line_accumulation_fact olaf 
  INNER JOIN dm.date_dim dt
          ON olaf.order_line_begin_date = dt.actual_date
  LEFT OUTER JOIN dm.product_line_dimension pld
          ON olaf.product_line_id = pld.product_line_id
  LEFT OUTER JOIN
             (
             SELECT
                *
             FROM dm.subscription_dimension
             ) sub
          ON olaf.product_subscription_id = sub.subscription_id
WHERE dt.year_month = 201606
  AND olaf.customer_id = 32040



handling null expire dates wrong - if many are null but one is populated,
must say not expired.

14444 had 2 subs.
One paid but expired in the month.
The other was free and did not expire.
So is_paid must be based on a sub that has not expired.

OK also there must be a subscription. (subscription_id <> -1).
If no sub it''s a fee and will not have an expire date.

SELECT
   year_month
  ,SUM(customers) AS customers
FROM tmp_data_dm.coe_counting_hist
GROUP BY 1
ORDER BY 1
Yippee!  Average of 26 fewer with historical method compared with
current method for Nov 2015 on.

SELECT
   ord.year_month
  ,SUM(CASE WHEN ord.max_expire_year_month > ord.year_month AND  ord.has_ads LIKE 'Y%' THEN 1 ELSE 0 END) AS                             advertisers
  ,SUM(CASE WHEN ord.max_expire_year_month > ord.year_month AND (ord.has_ads LIKE 'Y%' OR ord.is_paying LIKE 'Y%') THEN 1 ELSE 0 END) AS customers
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
  WHERE dt.year_month BETWEEN 201412 AND 201607
  GROUP BY 1,2
  ) ord
GROUP BY 1
ORDER BY 1


Code to hand off to Jake...
-- SELECT
--    mrr.yearmonth AS year_month
--   ,SUM(CASE WHEN (mca.customer_id IS NOT NULL) THEN 1 ELSE 0 END) AS advertisers
--   ,SUM(CASE WHEN (mrr.mrr_current_total <> 0 OR mca.customer_id IS NOT NULL) THEN 1 ELSE 0 END) AS customers
-- FROM dm.mrr_customer_category_all_products mrr
--   LEFT OUTER JOIN dm.mrr_customer_classification mca
--           ON mrr.customer_id = mca.customer_id
--          AND mrr.yearmonth = mca.yearmonth
-- WHERE mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
--   AND mrr.yearmonth >= 201511
-- GROUP BY 1
--   UNION ALL
-- SELECT
--    ord.year_month
--   ,SUM(CASE WHEN ord.max_expire_year_month > ord.year_month AND  ord.has_ads LIKE 'Y%' THEN 1 ELSE 0 END) AS                             advertisers
--   ,SUM(CASE WHEN ord.max_expire_year_month > ord.year_month AND (ord.has_ads LIKE 'Y%' OR ord.is_paying LIKE 'Y%') THEN 1 ELSE 0 END) AS customers
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
--     LEFT OUTER JOIN dm.product_line_dimension pld
--             ON olaf.product_line_id = pld.product_line_id
--     LEFT OUTER JOIN
--                (
--                SELECT
--                   subscription_id
--                  ,CASE WHEN IFNULL(expire_datetime, '1900-01-01') LIKE '1900-%' THEN 299901
--                        ELSE CAST(CONCAT(CAST(YEAR(TO_DATE(expire_datetime)) AS STRING), 
--                                         LPAD(CAST(MONTH(TO_DATE(expire_datetime)) AS STRING), 2, '0')) AS INTEGER)
--                   END AS expire_year_month
--                FROM dm.subscription_dimension
--                WHERE subscription_id <> -1
--                ) sub
--             ON olaf.product_subscription_id = sub.subscription_id
--   WHERE dt.year_month BETWEEN 201412 AND 201510
--   GROUP BY 1,2
--   ) ord
-- GROUP BY 1
