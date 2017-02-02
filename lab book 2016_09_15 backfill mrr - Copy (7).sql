Backfilling MRR data

Customer-level MRR by month as far back as we can go.

Jake: If we are basing it on billings, MRR looks weird.

Interestingly, since it''s only history, we don''t have to worry
about it''s the first month for a sub so billings is not the 
final price.

We do have # of blocks and block price - that should be MRR.

Exclusive: what was the price in the market at the time they
first purchased in the market?

Could do max amount billed for each sub ever.

Jake needs:
    CalendarMonth
    Customer
    MRR
    Tenure Month since their first sub.

We want to go back as far back as Jane''s churn report.
201304

Would want to take miscellaneous payments and manually adjust that.

2015Q4

For each subscription, get the highest ever billed amount.
  Ah I can see how much block count varies by sub in olaf.
Separate query gets first bill date by customer.  Actually want
it to be first advertiser olaf (which i think is just where subscriber_id
is populated).
Then get every month that sub was billed in, and apply the highest
amount as MRR amount.

Want to keep stuff as dates (not months) as far as possible because
then tenure_month calc is easy.

-- Questions:
-- - Do I need where payment date is valid?
-- - Should I have where professional_id is not null?  No, it will not be populated if not ads.

----
Nadine conversation:
Coe:question from before: how do i get from olaf to whether it''s block or exclusive?
is it as simple as block_count=0 means exclusive?
Nadine:
you should join by ad market ID to the dimension to get block or exclusive.  just to be sure.
so, ad market dimension
Coe:
but that changes over time, right?
(this is for the hist MRR data)
Nadine:
yes, sorry.  i was just thinking that.
so, i guess you could use that ..it should be ok.
there''s also a bock price table where the first date is when it 
converted to blocks.
Nadine:
but i think for your purpose it''s probably ok to just use the 
block count.


Coe:
another question: it''s easy to get to subscription cancel date, but 
where do we find the actual end date?
Nadine:
actual end date - meaning when the ad actually came down?
or when that price ended?
i think the best we have is cancel date.
Coe:
when the ad came down
Nadine:
so, i think that is the cancel date - I think that''s the field that 
comes from banana stand which is what triggers the ad to come down.
Coe:
i guess it''s reasonable, because what i want to use it for is if the 
subscription is active after EoM.  I thought cancel date was when 
they *requested* the cancel.  But very likely a sub won''t extend 
beyond the end of nthe month when cancel was requested.
Nadine:
or is there an expiration date?  let me dig for one minute.
no, that''s what we don;t have ...
we don''t have requested date.

----

Snippets:
STRLEFT(olaf.order_line_begin_date, 7) AS year_month
WHERE olaf.order_line_begin_date BETWEEN '2015-10-01' AND '2015-12-31'

SELECT
   block_counts_per_sub
  ,COUNT(*) AS subs
FROM
  (
  SELECT
     product_subscription_id AS subscription_id
    ,COUNT(DISTINCT olaf.block_count) AS block_counts_per_sub
  FROM dm.order_line_accumulation_fact olaf
  WHERE olaf.order_line_begin_date BETWEEN '2015-09-01' AND '2016-08-31'
  GROUP BY 1
  ) qry
GROUP BY 1
ORDER BY 1
OK in that data there are 14 w/ > 1 value for block_count.
In every case, it''s the last order line, and the price is negative
and block count is lower. 
Taking max block count and max price will solve this.  Since there 
are only 14, I am not worried about their incorrect MRR in that last 
month.
  SELECT
     *
  FROM dm.order_line_accumulation_fact olaf
  WHERE olaf.order_line_begin_date BETWEEN '2015-09-01' AND '2016-08-31'
    AND olaf.product_subscription_id IN (
      9158189, 10296881, 10390023, 10180331, 10389287, 9160537,
      10111614, 10398788, 10093950, 10152108, 10366953, 10394581,
      10421938, 10284270
      )

AH if we want to do MRR categories, have to figure out if sub was
active after EoM.

SELECT * FROM dm.subscription_dimension
WHERE subscription_id IN (
      9158189, 10296881, 10390023, 10180331, 10389287, 9160537,
      10111614, 10398788, 10093950, 10152108, 10366953, 10394581,
      10421938, 10284270
      )
Weird and all of the weird block counts were 8/1/16.
Feels weird.  Moving on for now.

-- OK:
-- - How much do I want to do new MRR definition vs. old?
-- - If a cust is not active as of EoM, do I include the customer
--   with 0 MRR ir not include them at all?



-- DROP TABLE IF EXISTS tmp_data_dm.coe_mbf_subs;
-- CREATE TABLE tmp_data_dm.coe_mbf_subs AS
-- SELECT
--    olaf.subscription_id
--   ,olaf.customer_id
--   ,IFNULL(STRLEFT(sub.expire_datetime, 10), '2999-12-31') AS expire_date
--   ,MAX(olaf.block_count) AS blocks
--   -- ,MAX(olaf.revenue) AS mrr_unused
--   ,MAX(sub.ad_type) AS ad_type
--   ,MIN(olaf.order_line_begin_date) AS min_order_line_begin_date
--   ,MAX(olaf.order_line_begin_date) AS max_order_line_begin_date
--   ,MAX(olaf.order_line_cancelled_date) AS order_line_cancelled_date
-- FROM
--     (
--     SELECT
--        product_subscription_id AS subscription_id
--       ,customer_id
--       ,block_count
--       ,order_line_begin_date
--       ,order_line_cancelled_date
--       ,CASE 
--          WHEN order_line_payment_date = '-1' THEN 0 
--          WHEN order_line_payment_date = '1900-01-01' THEN 0 
--          ELSE order_line_net_price_amount_usd 
--        END AS revenue
--     FROM dm.order_line_accumulation_fact
--     WHERE product_subscription_id IS NOT NULL
--       AND ((order_line_net_price_amount_usd > 0) OR (product_line_id IN (2, 7)))
--     ) olaf
--   INNER JOIN dm.subscription_dimension sub
--           ON olaf.subscription_id = sub.subscription_id
-- GROUP BY 1,2,3


-- DROP TABLE IF EXISTS tmp_data_dm.coe_mbf_sub_mrr1;
-- CREATE TABLE tmp_data_dm.coe_mbf_sub_mrr1 AS
-- SELECT DISTINCT
--    subscription_id
--   ,mrr
-- FROM   (
--        SELECT 
--           subscription_id 
--          ,ROUND(CAST(unit_price AS DOUBLE) * block_count / 100, 2) AS mrr
--          ,RANK() OVER(PARTITION BY subscription_id
--                           ORDER BY start_datetime DESC
--                      ) seq 
--        FROM dm.subscription_price_dimension
--        -- WHERE unit_price <> 0
--        ) AS spd_curr 
-- WHERE  seq = 1


-- DROP TABLE IF EXISTS tmp_data_dm.coe_mbf_customer;
-- CREATE TABLE tmp_data_dm.coe_mbf_customer AS
-- SELECT
--    olaf.customer_id
--   ,MIN(CASE WHEN ((olaf.order_line_net_price_amount_usd > 0) OR (olaf.product_line_id IN (2, 7)))
--               THEN olaf.order_line_begin_date
--               ELSE NULL END) AS first_active_date
--   ,COUNT(DISTINCT olaf.yearmonth) AS customer_total_billed_months  -- LOOK might also want customer_total_billed_months.
-- FROM  dm.order_line_accumulation_fact olaf
-- WHERE olaf.product_subscription_id IS NOT NULL
--   AND ((olaf.order_line_net_price_amount_usd > 0) OR (olaf.product_line_id IN (2, 7)))  -- LOOK
-- GROUP BY 1

-- DROP TABLE IF EXISTS tmp_data_dm.coe_mbf_sub_bills;
-- CREATE TABLE tmp_data_dm.coe_mbf_sub_bills AS
-- SELECT
--    olaf.product_subscription_id AS subscription_id
--   ,olaf.customer_id
--   ,olaf.yearmonth AS year_month
--   ,MIN(olaf.order_line_begin_date) AS bill_date
-- FROM
--              dm.order_line_accumulation_fact olaf
-- WHERE olaf.product_subscription_id IS NOT NULL
--   AND ((olaf.order_line_net_price_amount_usd > 0) OR (olaf.product_line_id IN (2, 7))) -- LOOK
--   -- AND olaf.order_line_begin_date BETWEEN '2014-12-01' AND '2016-09-30'
--   AND olaf.order_line_begin_date BETWEEN '2016-08-01' AND '2016-08-31'
-- GROUP BY 1,2,3

-- DROP TABLE IF EXISTS tmp_data_dm.coe_mbf_cust_mrr;
-- CREATE TABLE tmp_data_dm.coe_mbf_cust_mrr AS
-- SELECT
--    bls.customer_id
--   ,bls.year_month
--   ,cust.first_active_date
--    -- If tenure date is null, they had non-ads and we never billed them a non-zero amount.
--    -- If negative, they got free pro for X time before ads.
--   ,((CAST(STRLEFT(bls.bill_date, 4) AS INTEGER) - CAST(STRLEFT(cust.first_active_date, 4) AS INTEGER)) * 12) +
--     (CAST(SUBSTR(bls.bill_date, 6, 2) AS INTEGER) - CAST(SUBSTR(cust.first_active_date, 6, 2) AS INTEGER)) + 1 AS tenure_month
--   ,SUM(IFNULL(mrr1.mrr, 0)) AS mrr
--   ,COUNT(*) AS subscriptions
--   ,SUM(CASE WHEN IFNULL(mrr1.mrr, 0) = 0 THEN 1 ELSE 0 END) AS zero_dollar_subscriptions
-- FROM
--              tmp_data_dm.coe_mbf_sub_bills bls
--   INNER JOIN tmp_data_dm.coe_mbf_subs sub
--           ON bls.subscription_id = sub.subscription_id
--   INNER JOIN dm.date_dim dt
--           ON bls.bill_date = dt.actual_date
--   INNER JOIN tmp_data_dm.coe_mbf_customer cust
--           ON bls.customer_id = cust.customer_id
--   LEFT OUTER JOIN tmp_data_dm.coe_mbf_sub_mrr1 mrr1
--           ON bls.subscription_id = mrr1.subscription_id
--   -- Only call it MRR if there is a subscription that expires after
--   -- end of bill month and is either paying or has ads.  (Think that last part is red herring given that it is for old data)
-- WHERE dt.month_end_date < sub.expire_date
-- GROUP BY 1,2,3,4

-- SELECT
--    CASE WHEN new.customer_id IS NULL THEN 'Not in New' ELSE 'Yes in New' END AS in_new
--   ,CASE WHEN old.customer_id IS NULL THEN 'Not in Old' ELSE 'Yes in Old' END AS in_old
--   ,CASE WHEN new.mrr = old.mrr_current_total THEN 'Match'
--         WHEN old.mrr_current_total = 0 THEN 'Does Not Match'
--         WHEN (new.mrr / old.mrr_current_total) - 1 BETWEEN -0.01 AND 0.01 THEN 'Is Pretty Darned Close' 
--         ELSE 'Does Not Match'
--    END AS is_match
--   ,(new.mrr / old.mrr_current_total) - 1 AS   var
--   ,new.customer_id AS                         n_customer_id
--   ,new.year_month AS                          n_year_month
--   ,new.first_active_date AS                   n_first_active_date
--   ,new.tenure_month AS                        n_tenure_month
--   ,new.mrr AS                                 n_mrr
--   ,new.subscriptions AS                       n_subscriptions
--   ,new.zero_dollar_subscriptions AS           n_zero_dollar_subscriptions
--   ,old.customer_id AS                         o_customer_id
--   ,old.mrr_customer_category AS               o_mrr_customer_category
--   ,old.mrr_current_advertisement AS           o_mrr_current_advertisement
--   ,old.mrr_current_avvopro + old.mrr_current_ignite + old.mrr_current_website + old.mrr_current_adplacement AS o_mrr_non_ad
--   ,old.mrr_current_total AS                   o_mrr_current_total
--   ,old.mrr_acquired AS                        o_mrr_acquired
--   ,old.mrr_penetrated AS                      o_mrr_penetrated
--   ,old.mrr_downsized AS                       o_mrr_downsized
--   ,old.mrr_churned AS                         o_mrr_churned
--   ,old.mrr_retained AS                        o_mrr_retained
--   ,old.mrr_returned AS                        o_mrr_returned
--   ,old.block_conversion_flag AS               o_block_conversion_flag
--   ,old.customer_billed_current_month_flag AS  o_customer_billed_current_month_flag
--   ,old.yearmonth AS                           o_year_month
--   ,1 AS num_rows
-- FROM
--   (
--   SELECT *
--   FROM tmp_data_dm.coe_mbf_cust_mrr
--   WHERE year_month = 201512
--   -- WHERE year_month = 201608
--   ) new
-- FULL OUTER JOIN
--   (
--   SELECT *
--   FROM dm.mrr_customer_category_all_products
--   WHERE yearmonth = 201512
--   -- WHERE yearmonth = 201608
--     AND mrr_customer_category <> 'NOT BILLED'
--   ) old
--         ON new.customer_id = old.customer_id
--        AND new.year_month = old.yearmonth



OK so the NO ACTIVITY ones...
This I am being too liberal on which bills to count, or something 
like that.
Or the logic about whether they are active as of EoM.

To check (note from earlier work):
So there could be customers who had ads during the month, and stopped ads and
stopped paying... crap there could be a lot of these.
Also: (don''t know which month)
14444 had 2 subs.
One paid but expired in the month.
The other was free and did not expire.
So is_paid must be based on a sub that has not expired.

customer_id = 5650 is free pro as of 201512,
So they should not count as having MRR.
Because they are neither paying nor advertiser.

Still want to count their bill month?
But MRR during that month is 0?
But those are the ones we do not want to count.

customer_id = 4524
OK this is a casualty of us taking the max price ever charged.
This subscription was pulled at $10 in the past, but by 201512
the subscription price had been set to 0.

Well ok.  Might want to do a test where I just take the last active
price of the sub, knowing I can''t get history, and see how it 
compares.
Yep.  Much closer than taking max billed.  At least for Dec 2015.

-- Compare last sub price to max sub price.
-- DROP TABLE IF EXISTS tmp_data_dm.coe_temp_compare_price;
-- CREATE TABLE tmp_data_dm.coe_temp_compare_price AS
-- SELECT DISTINCT
--    subscription_id
--   ,max_mrr
--   ,row_mrr AS last_mrr
--   ,GREATEST(row_mrr, max_mrr) AS mrr
-- FROM   (
--        SELECT 
--           subscription_id 
--          ,ROUND(CAST(unit_price AS DOUBLE) * block_count / 100, 2) AS row_mrr
--          ,MAX(ROUND(CAST(unit_price AS DOUBLE) * block_count / 100, 2))
--                  OVER(PARTITION BY subscription_id
--                      ) max_mrr
--          ,RANK() OVER(PARTITION BY subscription_id
--                           ORDER BY start_datetime DESC
--                      ) seq 
--        FROM   subscription_price_dimension 
--        ) AS spd_curr 
-- WHERE  seq = 1

OK doing that overestimates way too many.  (8% over)

----
Want the start of the most recent acquisition or return.
And of course we don''t already have MRR category available, since
what I''m trying to do is backfill history.

OK wait.  Maybe this code was to dedup chat messages.  Yep think so.
But if I make the test for gap just > 1 (months diff) then maybe it
does what I want.

Sample query for gap:
SELECT person, period
     , MIN(eventdate) AS startdate
     , MAX(eventdate) AS enddate
     , COUNT(*)       AS days
     , MIN(type)      AS type
FROM  (
   SELECT person, eventdate, type
        , COUNT(gap) OVER (PARTITION BY person ORDER BY eventdate) AS period
   FROM  (
      SELECT person, eventdate, type
           , CASE WHEN lag(eventdate) OVER (PARTITION BY person ORDER BY eventdate)
                     > eventdate - 6  -- within 5 days
                  THEN NULL           -- same period
                  ELSE TRUE           -- next period
             END AS gap
      FROM   tbl
      ) sub
   ) sub
GROUP BY person, period
ORDER BY person, period

----

Have customer_total_billed_months but that is not very picky.
Might count where active.
And while I am at it, why can''t tenure work correctly with active?
Part of it is this: By definition, if they had a $0 month for a sub
(whether ads or not), that should count as a month to generate MRR 
for.  (right?)

OK moving on from that because I have no idea what I was thinking.

Next steps:
1. Include data for customers who churned in the month.  Should add
   in mrr category, and churned_in_month flag separately for 
   convenience.
   And make the fields show current and prior month values.
   Oh.  Don''t have MRR category.
   OK added a status field.  I think I do not need to show current 
   and prior months to give Jake what he needs; the MRR amount looks
   right.
2. Add in tenure months since most recent ACQUIRED or RETURNED.


-- Get every subscription for this customer,
-- with start and end dates
DROP TABLE IF EXISTS tmp_data_dm.coe_mbf_subs;
CREATE TABLE tmp_data_dm.coe_mbf_subs AS
SELECT
   olaf.subscription_id
  ,olaf.customer_id
  ,IFNULL(STRLEFT(sub.expire_datetime, 10), '2999-12-31') AS expire_date
  ,MAX(olaf.block_count) AS blocks
  -- ,MAX(olaf.revenue) AS mrr_unused
  ,MAX(sub.ad_type) AS ad_type
  ,MIN(olaf.order_line_begin_date) AS min_order_line_begin_date
  ,MAX(olaf.order_line_begin_date) AS max_order_line_begin_date
  ,MAX(olaf.order_line_cancelled_date) AS order_line_cancelled_date
FROM
    (
    SELECT
       product_subscription_id AS subscription_id
      ,customer_id
      ,block_count
      ,order_line_begin_date
      ,order_line_cancelled_date
      ,CASE 
         WHEN order_line_payment_date = '-1' THEN 0 
         WHEN order_line_payment_date = '1900-01-01' THEN 0 
         ELSE order_line_net_price_amount_usd 
       END AS revenue
    FROM dm.order_line_accumulation_fact
    WHERE product_subscription_id IS NOT NULL
      AND ((order_line_net_price_amount_usd > 0) OR (product_line_id IN (2, 7)))
    ) olaf
  INNER JOIN dm.subscription_dimension sub
          ON olaf.subscription_id = sub.subscription_id
GROUP BY 1,2,3


-- Get the MRR for every subscription that exists.
DROP TABLE IF EXISTS tmp_data_dm.coe_mbf_sub_mrr1;
CREATE TABLE tmp_data_dm.coe_mbf_sub_mrr1 AS
SELECT DISTINCT
   subscription_id
  ,mrr
FROM   (
       SELECT 
          subscription_id 
         ,ROUND(CAST(unit_price AS DOUBLE) * block_count / 100, 2) AS mrr
         ,RANK() OVER(PARTITION BY subscription_id
                          ORDER BY start_datetime DESC
                     ) seq 
       FROM dm.subscription_price_dimension
       -- WHERE unit_price <> 0
       ) AS spd_curr 
WHERE seq = 1


-- -- Get customer-level data.  LOOK should this come from sub_bills?
-- DROP TABLE IF EXISTS tmp_data_dm.coe_mbf_customer;
-- CREATE TABLE tmp_data_dm.coe_mbf_customer AS
-- SELECT
--    olaf.customer_id
--   ,MIN(CASE WHEN ((olaf.order_line_net_price_amount_usd > 0) OR (olaf.product_line_id IN (2, 7)))
--               THEN olaf.order_line_begin_date
--               ELSE NULL END) AS first_active_date
--   ,COUNT(DISTINCT olaf.yearmonth) AS customer_total_billed_months  -- LOOK might also want customer_total_active_months.
-- FROM  dm.order_line_accumulation_fact olaf
-- WHERE olaf.product_subscription_id IS NOT NULL
--   AND ((olaf.order_line_net_price_amount_usd > 0) OR (olaf.product_line_id IN (2, 7)))
-- GROUP BY 1


-- Get every subscription that was billed in the month
-- for this customer.
-- DROP TABLE IF EXISTS tmp_data_dm.coe_mbf_sub_bills;
-- CREATE TABLE tmp_data_dm.coe_mbf_sub_bills AS
-- SELECT
--    olaf.product_subscription_id AS subscription_id
--   ,olaf.customer_id
--   ,olaf.yearmonth AS year_month
--   ,MIN(olaf.order_line_begin_date) AS bill_date
-- FROM
--              dm.order_line_accumulation_fact olaf
-- WHERE olaf.product_subscription_id IS NOT NULL
--   AND ((olaf.order_line_net_price_amount_usd > 0) OR (olaf.product_line_id IN (2, 7)))
--   -- AND olaf.order_line_begin_date BETWEEN '2014-12-01' AND '2016-09-30'
--   AND olaf.order_line_begin_date BETWEEN '2015-12-01' AND '2015-12-31'
-- GROUP BY 1,2,3

-- This is what needs to change.  Maybe query outside this that checks
-- whether prior month is in the dataset?

-- DROP TABLE IF EXISTS tmp_data_dm.coe_mbf_sub_bills;
-- CREATE TABLE tmp_data_dm.coe_mbf_sub_bills AS
-- SELECT
--    sb.subscription_id
--   ,sb.customer_id
--   ,sb.year_month
--   ,sb.bill_date
--   ,sb.month_begin_date
--   ,CASE WHEN max_preceding_bill_month IS NULL THEN 

-- maybe I could do it all in one: get min date where diff between
-- this month and prev month = 1?
-- Or is that even 2 window functions?

-- FROM
--   (
--   SELECT
--      bls.subscription_id
--     ,bls.customer_id
--     ,bls.year_month
--     -- ,bls.bill_date
--     ,mth.month_begin_date
--     ,mth.month_end_date
--     ,LAG(mth.month_begin_date) OVER(PARTITION BY bls.subscription_id
--                                         ORDER BY bls.year_month) AS max_preceding_bill_month
--   FROM
--     (
--     SELECT
--        olaf.product_subscription_id AS subscription_id
--       ,olaf.customer_id
--       ,olaf.yearmonth AS year_month
--       -- ,MIN(olaf.order_line_begin_date) AS bill_date
--     FROM
--                  dm.order_line_accumulation_fact olaf
--     WHERE olaf.product_subscription_id IS NOT NULL
--       AND ((olaf.order_line_net_price_amount_usd > 0) OR (olaf.product_line_id IN (2, 7)))
--       AND olaf.order_line_begin_date BETWEEN '2014-12-01' AND '2016-09-30'
--       -- AND olaf.order_line_begin_date BETWEEN '2015-12-01' AND '2015-12-31'
-- -- AND customer_id = 136
--     GROUP BY 1,2,3
--     ) bls
--     INNER JOIN dm.month_dim mth
--             ON bls.year_month = mth.year_month
--   ) sb
-- OK I have a mismatch on sub vs. customer.
-- Ultimately I want customer.
-- I only want to count subscriptions, and therefore bills,
-- if not expired.
-- Gap in service has to be determined at customer level (and so maybe
-- not in coe_mbf_sub_bills).
-- I think all I need to know from the bills table is that customer was
-- billed in the month?
-- Do I need to know that for every sub?
-- Ah, yeah I do.  For each sub I need to compare its expire date
-- with end of bill month.  If I did max expire date for cust and each
-- bill month, I may not be hooking up to the right sub?
-- For every sub THAT WAS BILLED IN THE MONTH, does that sub extend
-- past the end of the month?
-- If not careful, then I could look at a bill month where every sub
-- expired during that month, but since the customer came back later,
-- I do see a sub for that customer overall with a later expire date
-- than EoM.
-- Tell if churned or not at cust level.
-- And then MRR is for those subs that go past EoM.
-- But MRR for churned: that''s either for all subs in month
-- or I need to go get prior MRR.
-- It should be for all the subs billed in the month.
-- OK so part of this is that churned_mrr is not the same field as mrr.
-- Can I make this table pull at the sub level but result in cust level?


-- Record each month that each subscription was billed in.
DROP TABLE IF EXISTS tmp_data_dm.coe_mbf_sub_bills;
CREATE TABLE tmp_data_dm.coe_mbf_sub_bills AS
SELECT
   olaf.product_subscription_id AS subscription_id
  ,olaf.customer_id
  ,olaf.yearmonth AS year_month
  ,mth.month_begin_date
  ,mth.month_end_date
  ,MIN(olaf.order_line_begin_date) AS bill_date
FROM dm.order_line_accumulation_fact olaf
  INNER JOIN dm.month_dim mth
          ON olaf.yearmonth = mth.year_month
WHERE olaf.product_subscription_id IS NOT NULL
  AND ((olaf.order_line_net_price_amount_usd > 0) OR (olaf.product_line_id IN (2, 7)))
  AND olaf.order_line_begin_date BETWEEN '2014-12-01' AND '2016-09-30'
  -- AND olaf.order_line_begin_date BETWEEN '2015-12-01' AND '2015-12-31'
GROUP BY 1,2,3,4,5


-- Roll up subscription months to customer months.
DROP TABLE IF EXISTS tmp_data_dm.coe_mbf_cust_bills;
CREATE TABLE tmp_data_dm.coe_mbf_cust_bills AS
SELECT
   bls.customer_id
  ,bls.year_month
  ,bls.month_begin_date
  ,bls.month_end_date
  ,MIN(bls.bill_date) AS first_bill_date_in_month
  ,MAX(CASE WHEN bls.month_end_date < sub.expire_date THEN 1 ELSE 0 END) AS active_in_month
  -- Only call it MRR if the subscription expires after end of bill month.
  ,SUM(CASE WHEN bls.month_end_date < sub.expire_date THEN IFNULL(mrr.mrr, 0) ELSE 0 END) AS mrr
  -- This one is weird.  If it turns out that the customer churned 
  -- in the month, then churned_mrr is the mrr for every sub they 
  -- had in the month, by definition not just those that extend past
  -- the end of the month.
  ,SUM(IFNULL(mrr.mrr, 0)) AS potential_churned_mrr
  ,COUNT(*) AS subscriptions
  ,SUM(CASE WHEN IFNULL(mrr.mrr, 0) = 0 THEN 1 ELSE 0 END) AS zero_dollar_subscriptions
FROM
             tmp_data_dm.coe_mbf_sub_bills bls
  INNER JOIN tmp_data_dm.coe_mbf_subs sub
          ON bls.subscription_id = sub.subscription_id
  LEFT OUTER JOIN tmp_data_dm.coe_mbf_sub_mrr1 mrr
          ON bls.subscription_id = mrr.subscription_id
GROUP BY 1,2,3,4

-- Roll up customer months to customer overall.
DROP TABLE IF EXISTS tmp_data_dm.coe_mbf_customer;
CREATE TABLE tmp_data_dm.coe_mbf_customer AS
SELECT
   bls.customer_id
  ,MIN(bls.first_bill_date_in_month) AS  first_active_date
  ,SUM(bls.active_in_month) AS           customer_total_active_months
FROM  tmp_data_dm.coe_mbf_cust_bills bls
GROUP BY 1


OK so now we have the overall customer attributes and the billed months,
with a flag saying if they counted as active as of the end of the bill month.

- If configured MRR is > 0 but have never billed > 0 for that sub, 
  for non-ads, do not want to count the MRR.
  Actually, for history, we want to do this both for ads and non-ads.
- tenure_month needs to be based on the most recent chain, not from
  first bill date.

LOOK Where we are: have to come back to this, but first I need to 
get the 2014 data.
Next step here is: how much does it happen that we start someone
at $0 revenue when MRR is > 0?
Then after that do chain logic based on definition of how we should
identify the chain.

   -- If tenure date is null, they had non-ads and we never billed them a non-zero amount.
   -- If negative, they got free pro for X time before ads.
  ,((CAST(STRLEFT(bls.month_begin_date, 4) AS INTEGER) - CAST(STRLEFT(cust.first_active_date, 4) AS INTEGER)) * 12) +
    (CAST(SUBSTR(bls.month_begin_date, 6, 2) AS INTEGER) - CAST(SUBSTR(cust.first_active_date, 6, 2) AS INTEGER)) + 1 AS tenure_month

  ,CASE WHEN max_preceding_bill_month IS NULL THEN 

-- This is the output MRR table.
DROP TABLE IF EXISTS tmp_data_dm.coe_mbf_cust_mrr;
CREATE TABLE tmp_data_dm.coe_mbf_cust_mrr AS
SELECT
   bls.customer_id
  ,bls.year_month
  ,cust.first_active_date
  ,cust.customer_total_active_months AS total_active_months
  -- LOOK also want recent_active_months which is start of last chain to this month
  ,CASE WHEN bls.active_in_month = 1 THEN 'Continued' ELSE 'Churned' END AS status_in_month
  ,bls.mrr
  ,CASE WHEN bls.active_in_month = 0 THEN IFNULL(bls.potential_churned_mrr, 0) ELSE 0 END AS churned_mrr
  ,bls.zero_dollar_subscriptions
FROM
             tmp_data_dm.coe_mbf_cust_bills bls
  INNER JOIN tmp_data_dm.coe_mbf_customer cust
          ON bls.customer_id = cust.customer_id



SELECT
   CASE WHEN new.customer_id IS NULL THEN 'Not in New' ELSE 'Yes in New' END AS in_new
  ,CASE WHEN old.customer_id IS NULL THEN 'Not in Old' ELSE 'Yes in Old' END AS in_old
  ,CASE WHEN new.mrr = old.mrr_current_total THEN 'Match'
        WHEN old.mrr_current_total = 0 THEN 'Does Not Match'
        WHEN (new.mrr / old.mrr_current_total) - 1 BETWEEN -0.01 AND 0.01 THEN 'Is Pretty Darned Close' 
        ELSE 'Does Not Match'
   END AS is_match
  ,(new.mrr / old.mrr_current_total) - 1 AS   var
  ,new.customer_id AS                         n_customer_id
  ,new.year_month AS                          n_year_month
  ,new.status_in_month AS                     n_status_in_month
  ,new.first_active_date AS                   n_first_active_date
  ,new.tenure_month AS                        n_tenure_month
  ,new.total_active_months AS                 n_total_active_months
  ,new.mrr AS                                 n_mrr
  ,new.churned_mrr AS                         n_churned_mrr
  ,new.zero_dollar_subscriptions AS           n_zero_dollar_subscriptions
  ,old.customer_id AS                         o_customer_id
  ,old.mrr_customer_category AS               o_mrr_customer_category
  ,old.mrr_current_advertisement AS           o_mrr_current_advertisement
  ,old.mrr_current_avvopro + old.mrr_current_ignite + old.mrr_current_website + old.mrr_current_adplacement AS o_mrr_non_ad
  ,old.mrr_current_total AS                   o_mrr_current_total
  ,old.mrr_acquired AS                        o_mrr_acquired
  ,old.mrr_penetrated AS                      o_mrr_penetrated
  ,old.mrr_downsized AS                       o_mrr_downsized
  ,old.mrr_churned AS                         o_mrr_churned
  ,old.mrr_retained AS                        o_mrr_retained
  ,old.mrr_returned AS                        o_mrr_returned
  ,old.block_conversion_flag AS               o_block_conversion_flag
  ,old.customer_billed_current_month_flag AS  o_customer_billed_current_month_flag
  ,old.yearmonth AS                           o_year_month
  ,1 AS num_rows
FROM
  (
  SELECT *
  FROM tmp_data_dm.coe_mbf_cust_mrr
  WHERE year_month = 201512
  -- WHERE year_month = 201608
  ) new
FULL OUTER JOIN
  (
  SELECT *
  FROM dm.mrr_customer_category_all_products
  WHERE yearmonth = 201512
  -- WHERE yearmonth = 201608
    AND mrr_customer_category <> 'NOT BILLED'
  ) old
        ON new.customer_id = old.customer_id
       AND new.year_month = old.yearmonth

----

OK.  2014.

Ugh.

What do we need to end up with?

    customer_id
    year_month
    first_active_date
    total_active_months
    status_in_month
    mrr
    churned_mrr
    zero_dollar_subscriptions

Jane''s code:
Her new (promo) query sill uses the subscription config data, so does not go back further than  Oct 2014.  actually 2015.
And actually, it also uses mrr_subscription, so only works with newest.

Older churn spreadsheet does not use sub config data.

Old logic: if order started on 1st, it’s net price of the order.
If 0, take next month’s net price as mrr.
If mid-month, it un-prorates.

That far back in time, that logic is probably fine because we did not start doing actual promos until oct of 2015.

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

  ,SUM(CASE WHEN product_type IN ('Display', 'Sponsored Listing') THEN revenue ELSE 0 END) AS  revenue_current_advertisement
  ,SUM(CASE WHEN product_type = 'Pro' THEN revenue ELSE 0 END) AS                              revenue_current_avvopro
  ,SUM(CASE WHEN product_type = 'Ignite' THEN revenue ELSE 0 END) AS                           revenue_current_ignite
  ,SUM(CASE WHEN product_type = 'Website' THEN revenue ELSE 0 END) AS                          revenue_current_website
  ,SUM(CASE WHEN product_type = 'Ad Placement' THEN revenue ELSE 0 END) AS                     revenue_current_adplacement
  ,SUM(CASE WHEN product_type = 'Misc' THEN revenue ELSE 0 END) AS                             revenue_current_misc
  ,SUM(CASE WHEN product_type = 'Other Subscription' THEN revenue ELSE 0 END) AS               revenue_current_other_sub
  ,SUM(CASE WHEN product_type = 'Other' THEN revenue ELSE 0 END) AS                            revenue_current_other
  ,SUM(CASE WHEN product_type NOT LIKE 'Other%' THEN revenue ELSE 0 END) AS                    revenue_current_total
  ,SUM(CASE WHEN product_type IN ('Display', 'Sponsored Listing') THEN mrr ELSE 0 END) AS      mrr_current_advertisement
  ,SUM(CASE WHEN product_type = 'Pro' THEN mrr ELSE 0 END) AS                                  mrr_current_avvopro
  ,SUM(CASE WHEN product_type = 'Ignite' THEN mrr ELSE 0 END) AS                               mrr_current_ignite
  ,SUM(CASE WHEN product_type = 'Website' THEN mrr ELSE 0 END) AS                              mrr_current_website
  ,SUM(CASE WHEN product_type = 'Ad Placement' THEN mrr ELSE 0 END) AS                         mrr_current_adplacement
  ,SUM(CASE WHEN product_type = 'Other Subscription' THEN mrr ELSE 0 END) AS                   mrr_current_other_sub
  ,SUM(CASE WHEN product_type NOT LIKE 'Other%' THEN mrr ELSE 0 END) AS                        mrr_current_total

  ,CASE WHEN olaf.order_line_number < 0 THEN 'Negative'
        WHEN olaf.order_line_number = 0 THEN 'Positive'
        ELSE 'Zero'
   END AS chk_order_line_number

SELECT
   STRLEFT(olaf.order_line_begin_date, 7) AS year_month
  ,olaf.product_line_id
  ,pld.product_line_name
  ,pld.product_line_item_name
  ,pld.product_line_class_name
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
  ,CASE WHEN olaf.product_subscription_id = -1 
          THEN 'sub_id is -1'
        WHEN olaf.product_subscription_id IS NOT NULL 
          THEN 'sub_id looks ok?'
        ELSE 'sub_id not found'
   END AS chk_sub_id
  ,CASE WHEN sub.subscription_id IS NOT NULL THEN 'Found sub' ELSE 'Sub not found' END AS chk_sub_join
  ,SUM(olaf.order_line_net_price_amount_usd) AS revenue
  ,COUNT(*) AS num_rows
FROM
             dm.order_line_accumulation_fact olaf
  LEFT OUTER JOIN dm.product_line_dimension pld
          ON olaf.product_line_id = pld.product_line_id
  LEFT OUTER JOIN dm.subscription_dimension sub
          ON olaf.product_subscription_id = sub.subscription_id
WHERE olaf.order_line_begin_date >= '2013-01-01'
GROUP BY 1,2,3,4,5,6,7,8

Way back in history, Misc payments have product_line_id = 17.
More recently, they have product_line_id = -1 and order_line_number < 0.
2014-09 is first month that we can reliably link to subs.

select customer_id,sum(revenue) as misc_revenue
from mrr_subscription_daily_all_products
where etl_load_date=date_sub(current_date, 1)
and subscription_id=-1
and product_line_id=-1
group by customer_id

select customer_id,sum(revenue) as ad_revenue, sum(mrr) as ad_mrr
and product_line_id in (2,7)

3 timeframes:
>= 201511 do not generate anything, we have data.
   (201510 is present in new MRR table but suspect. maybe.)
BETWEEN 201409 AND 201510 use logic that joins to subscription_dimension.
BETWEEN 201304 AND 201408 use old churn spreadsheet logic.

Not doing these:
-- expired_reason  -- This is the reason corresponding to the last expired subscription. Currently this shows Failed CC only for Ads.  (probably optional)
-- block_conversion_flag  -- Yes/No: Was the market converted to blocks in the current month? (pretty sure optional)
-- refund_current_month_flag  -- Y/N: Did the customer receive a refund in the current month? (pretty sure optional)
-- promo_flag  -- Not needed for history because even in current table it is not populated before July 2016.

mrr_customer_category
The MRR category that this customer falls into in the current month.
Note: We will be re-working MRR at some point. These definitions show 
how it currently works. 
Values are ('ACQUIRED', 'RETURNED', 'PENETRATED', 'RETAINED', 'DOWNSIZED', 'CHURNED', 'NO ACTIVITY', 'NOT BILLED')
ACQUIRED:    The customer was acquired for the first time in the current month.
CHURNED:     The customer churned (across all subscriptions) in the current month.
DOWNSIZED:   The customer''s MRR went down from the prior month to the current month.
NO ACTIVITY: The customer was not billed (or had a $0 bill) in the current month, 
              but they did receive some subscription service from Avvo.
NOT BILLED:  The customer was not billed and received no service.
PENETRATED:  The customer''s MRR went up from the prior month to the current month.
RETAINED:    The customer''s MRR did not change from the prior month to the current month.
RETURNED:    The customer previously received service, then lapsed, and returned in the current month.

mrr_customer_category_all_products
    year_month
    customer_id
    mrr_customer_category
    mrr_current_advertisement
    mrr_current_avvopro
    mrr_current_ignite
    mrr_current_website
    mrr_current_adplacement
    mrr_current_total
    mrr_prior_advertisement
    mrr_prior_avvopro
    mrr_prior_ignite
    mrr_prior_website
    mrr_prior_adplacement
    mrr_prior_total
    revenue_current_advertisement
    revenue_current_avvopro
    revenue_current_ignite
    revenue_current_website
    revenue_current_misc
    revenue_current_adplacement
    revenue_current_total
    revenue_prior_advertisement
    revenue_prior_avvopro
    revenue_prior_ignite
    revenue_prior_website
    revenue_prior_misc
    revenue_prior_adplacement
    revenue_prior_total
    mrr_acquired    -- MRR associated with customers acquired for the first time in the current month.
    mrr_penetrated  -- Change in MRR amount for customers whose MRR went up from the prior month to the current month.
    mrr_downsized   -- Change in MRR amount for customers whose MRR went down from the prior month to the current month.
    mrr_churned     -- MRR associated with customers who churned (across all subscriptions) in the current month.
    mrr_retained    -- MRR for customers whose MRR did not change from the prior month to the current month.
                    -- Retained includes the non-delta part of mrr for upsold or downsized.
    mrr_returned    -- MRR for customers who previously received service, then lapsed, and returned in the current month.
    expired_date    -- The latest (max) expired date for any of the products in the given month.
    customer_prev_billed_date  -- Most recent bill date prior to current month.
    customer_billed_current_month_flag  -- Y/N: Did the customer have a bill in the current month? Does not distinguish between 0 and non-0 bills, and does not look at whether the payment succeeded.
    -- New fields
    mrr_retained_same -- MRR for customers whose MRR is the same as the prior month.
    mrr_retained_different -- The non-delta part of MRR for customers who upsold or downsized.
    customer_misc_payment_current_month_flag
    -- mrr_no_activity  -- The reduction in MRR from customers who downsized to 0.
    has_ads
    successful_payment_in_month
    tenure_month_lifetime
    tenure_month_chain



-- Differences between old definitions and new:
-- - Use new definition of active.  This will affect all metrics, 
--   potentially even things like downsized.
-- - Only count as active if active beyond EoM.
--   I think this only affects things like active customers in month,
--   so not even part of the logic for this table.
-- - If acquired and churned in same month, should count in both
--   (currently only counts in churn)
--   (maybe add flag to identify that case)
--   OH this causes a problem for the customer category.  So really
--   we do need to create a new category to identify them.
--   OK this one too, going back on what we''d said before.
--   In this case, we can totally ignore the customer.
-- - If a customer adds a subscription in the same month they churn,
--   the added sub does not count as churned mrr.  Ah but maybe it 
--   should not anyway, because it also does not go into the penetrated 
--   bucket.  Ask Jake.  resolved.
--   Put the upsell amount into upsell and total subscription amount into
--   churned.  Customer only counts in churned.
--   We really only want to look at begin month and end month and the delta.
--   If it didn''t involve churn, then inter-month stuff doesn''t matter.
--   DIFFERERNT: if they upsold in the month and then churned, we can ignore the upsell.
-- - I would like to rename mrr_current_total because of churned MRR.
--   It is essentially the mrr if you counted all customers in the month.
--   Not even relevant because MRR is 0 for churned.
-- - mrr_month_end is:
--     retained + returned + acquired + penetrated + downsized.
-- - Month to month formula is:
--     current_month_end = prior_month_end + returned + acquired + penetrated + downsized + churned - prior month''s MRR for customers who are NO ACTIVITY this month.
--     (the reason those are all plusses is that churned and downsized are negative)
--     Something about last month''s No Activity.
--     Yep, we need to subtract out prior month''s MRR for customers
--     who were NO ACTIVITY this month.
--     I think that''s there because with the new definitions, we
--     should be calling those customers churned.  Or downsized.  
--     Or whatever.  If they went to $0 but with ads, they are downsize.
--     If they went to $0 with something besides ads, they are churn.
--     OK payment weirdness still means we have to do that plug, so I
--     want a no activity delta MRR field.
-- - If a subscription has not yet ever been billed for a non-zero
--   amount, we do not want to call it MRR (and the categories should
--   share that logic).  This applies to both ads and non-ads.
--   LOOK how much does this happen?  I am not writing code for it
--   if it is tiny.
-- - Currently, the product-specific metrics (such as 
--   mrr_current_advertisement) are slices of mrr_current_total.
--   I propose that instead, they be slices of mrr_month_end.
--   Nope it''s ok.
-- - Pretty sure I want non-delta MRR components separate for
--   upsell and downsize, because you can''t get average retained MRR
--   from the metrics we currently have.  Eh, maybe it is right as
--   (Retained MRR) /  (Retained Cust + Upsold Cust + Downsized Cust)
--   Yes.  Only want retained / retained.

-- Hey wait!  Looking at mrr_subscription_all_products.sql, they might
-- not count MRR after all if the subscription is canceled in the month
-- or expires in the month.  Contradicts what I have been told.
-- If that is correct, then in the categorization logic, they are
-- treated the same as a $0 sub.
-- OK LOOK this is another area where I need to look at some data.

-- Research items:
-- - How well does churn spreadsheet match churn in scorecard?
--   Ugh.  It doesn''t.  Eh.  we''re good.
-- - What does mrr_current_total look like for a churned customer? 0.
--   Oh!  mrr_current_total *is* 0, 
--   that is what the logic looks for.
--   We set the churned MRR to -1 * prior month MRR.
--   omg.  So the customer counts are only messed up (WRT EoM status)
--   in the report, not in the data source.  
-- - How much do we see subs starting off w/ $0 revenue but > 0 MRR?
--   (this may not be a special case if I write the code right)
--   Ah no it still is, because by definition mrr > 0, it''s just that
--   revenue has never yet been > 0.  
--   Not a problem.

From notes in the MRR all products report:
MRR Current Month = Acquired + Returned +  Retained + Penetrated
Current Month = Prior Month + Acquired + Returned + Penetrated + Downsized + Churned - Prior Month No Activity


DROP TABLE IF EXISTS tmp_data_dm.coe_temp_examine_mrr;
CREATE TABLE tmp_data_dm.coe_temp_examine_mrr AS
SELECT
   yearmonth AS year_month
  ,mrr_customer_category
  ,customer_billed_current_month_flag
  ,customer_prev_billed_date
  ,expired_date
  ,SUM(mrr_current_advertisement) AS      mrr_current_advertisement
  ,SUM(mrr_current_avvopro) AS            mrr_current_avvopro
  ,SUM(mrr_current_ignite) AS             mrr_current_ignite
  ,SUM(mrr_current_website) AS            mrr_current_website
  ,SUM(mrr_current_adplacement) AS        mrr_current_adplacement
  ,SUM(mrr_current_total) AS              mrr_current_total
  ,SUM(mrr_prior_advertisement) AS        mrr_prior_advertisement
  ,SUM(mrr_prior_avvopro) AS              mrr_prior_avvopro
  ,SUM(mrr_prior_ignite) AS               mrr_prior_ignite
  ,SUM(mrr_prior_website) AS              mrr_prior_website
  ,SUM(mrr_prior_adplacement) AS          mrr_prior_adplacement
  ,SUM(mrr_prior_total) AS                mrr_prior_total
  ,SUM(revenue_current_advertisement) AS  revenue_current_advertisement
  ,SUM(revenue_current_avvopro) AS        revenue_current_avvopro
  ,SUM(revenue_current_ignite) AS         revenue_current_ignite
  ,SUM(revenue_current_website) AS        revenue_current_website
  ,SUM(revenue_current_misc) AS           revenue_current_misc
  ,SUM(revenue_current_adplacement) AS    revenue_current_adplacement
  ,SUM(revenue_current_total) AS          revenue_current_total
  ,SUM(revenue_prior_advertisement) AS    revenue_prior_advertisement
  ,SUM(revenue_prior_avvopro) AS          revenue_prior_avvopro
  ,SUM(revenue_prior_ignite) AS           revenue_prior_ignite
  ,SUM(revenue_prior_website) AS          revenue_prior_website
  ,SUM(revenue_prior_misc) AS             revenue_prior_misc
  ,SUM(revenue_prior_adplacement) AS      revenue_prior_adplacement
  ,SUM(revenue_prior_total) AS            revenue_prior_total
  ,SUM(mrr_acquired) AS                   mrr_acquired
  ,SUM(mrr_penetrated) AS                 mrr_penetrated
  ,SUM(mrr_downsized) AS                  mrr_downsized
  ,SUM(mrr_churned) AS                    mrr_churned
  ,SUM(mrr_retained) AS                   mrr_retained
  ,SUM(mrr_returned) AS                   mrr_returned
  ,COUNT(CASE WHEN mrr_customer_category = 'ACQUIRED'    THEN customer_id ELSE NULL END) AS cust_acquired
  ,COUNT(CASE WHEN mrr_customer_category = 'PENETRATED'  THEN customer_id ELSE NULL END) AS cust_penetrated
  ,COUNT(CASE WHEN mrr_customer_category = 'DOWNSIZED'   THEN customer_id ELSE NULL END) AS cust_downsized
  ,COUNT(CASE WHEN mrr_customer_category = 'CHURNED'     THEN customer_id ELSE NULL END) AS cust_churned
  ,COUNT(CASE WHEN mrr_customer_category = 'RETAINED'    THEN customer_id ELSE NULL END) AS cust_retained
  ,COUNT(CASE WHEN mrr_customer_category = 'RETURNED'    THEN customer_id ELSE NULL END) AS cust_returned
  ,COUNT(CASE WHEN mrr_customer_category = 'NO ACTIVITY' THEN customer_id ELSE NULL END) AS cust_no_activity
  ,COUNT(*) AS num_rows
FROM dm.mrr_customer_category_all_products
-- WHERE mrr_customer_category <> 'NOT BILLED'
GROUP BY 1,2,3,4,5

Revised notes, with answers instead of questions...
Differences between old definitions and new:
- Use new definition of active.  This will affect all metrics, 
  potentially even things like downsized.
- Only count as active if active beyond EoM.
  I think this only affects things like active customers in month,
  so not even part of the logic for this table.
  Yep and it is only customer counts.
  mrr_current_total does NOT include the MRR from churned customers.
- If acquired and churned in same month, we can totally ignore the 
  customer and their revenue.
  This goes back on what we''d said before, because intra-month
  stuff opens up a lot of complexity and convoluted logic,
  and really if we lost a customer in the same month we got them,
  at a fundamental level that does not count in MRR.
  That person DOES contribute revenue, and frankly, it''s optional
  whether we do or don''t allow for that in this table.
  My sense is that without special handling, they will show up in
  NO ACTIVITY.
- We need a NO ACTIVITY MRR field, which will be -1 * prior month MRR
  for NO ACTIVITY customers.  nope.
- If a customer adds a subscription in the same month they churn,
  the added sub does not count as churned mrr.
  We ignore intra-month activity.
- mrr_current_total IS mrr_month_end.
- mrr_current_total =
    retained + returned + acquired + penetrated + downsized.
- Month to month formula is:
    current_month_end = prior_month_end + returned + acquired + penetrated + downsized + churned - prior month''s MRR for customers who are NO ACTIVITY this month.
    (the reason those are all plusses is that churned and downsized are negative)
    We need to subtract out prior month''s MRR for customers
    who were NO ACTIVITY this month.
    That''s there because with the new definitions, we should be 
    calling those customers churned.  Or downsized. Or whatever.  
    If they went to $0 but with ads, they are downsize.
    If they went to $0 with something besides ads, they are churn.
    But payment weirdness still means we have to do that plug, so I
    want a no activity delta MRR field.
- Add fields:
  - Split mrr_retained into retained when MRR did not change
    and separately the unchanged part of MRR for upsold or 
    downsized customers.
  - mrr_no_activity, which is a delta field, typically a small
    negative number to catch the reduction in MRR from customers who
    downsized to 0.  - nope, recategorizing them into downsize.
  - has_misc_payment flag.

Could look at all customers active in a given month, say Sept.
And signed up >= 201511.
Sum all of their revenue up to current month, and check if current
month MRR > 0.
If sum of revenue is 0 that''s who I am interested in.

DROP TABLE IF EXISTS tmp_data_dm.coe_temp_weird_use_case;
CREATE TABLE tmp_data_dm.coe_temp_weird_use_case AS
SELECT * FROM
  (
  SELECT
     mrr.yearmonth as year_month
    ,mrr.customer_id
    ,mrr.mrr_customer_category
    ,mrr.mrr_current_total
    ,SUM(mrr.revenue_current_total) OVER(PARTITION BY mrr.customer_id
                                             ORDER BY mrr.yearmonth
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS revenue_to_date
  FROM
      (SELECT DISTINCT customer_id
       FROM dm.mrr_customer_category_all_products
       WHERE yearmonth >= 201511
         AND mrr_customer_category = 'ACQUIRED') cust
    INNER JOIN dm.mrr_customer_category_all_products mrr
            ON cust.customer_id = mrr.customer_id
           AND mrr.yearmonth >= 201511
  WHERE mrr.mrr_current_total + mrr.mrr_churned <> 0
  ) qry
WHERE revenue_to_date = 0
OK that is basically only happening in the acquire month.
It happens if we give the first month free.
Should be counting their MRR.
So we''re good.  No special code to handle this case.

OK so back to Jane''s code.
She provides the logic to get sub-level MRR once we have MRR tables.
Her old code has the logic to back into mrr when no sub.

OK there are problems with M00.
- There is no M00 for last month (201609).
- Sometimes M00 < M01.

She does not have to look at any customers who started
< 201510.  The older customers are not showing up as retained
because we have no price.

SELECT
start_month
,COUNT(*) AS new_custs
FROM tmp_data_dm.coe_jrr_start_month
GROUP BY 1
ORDER BY 1

OK new customer count in coe_jrr_start_month ties with churn spreadsheet.

SELECT year_month, COUNT(DISTINCT customer_id) AS customers_billed_in_month
FROM tmp_data_dm.coe_jrr_customer_market
GROUP BY 1 ORDER  BY 1
My customers_billed_in_month:
- only exists since 201510.
- runs about 800 lower than churn spreadsheet.
  It''s probably excluding churned.  Yeah.  As it should - so is spreadsheet.
  And that leaves a remaining diff of about 120.  LOOK new query sees 120 fewer customers per month.

From here on out, until I get earlier mrr amounts,
customer counts should be good but mrr has zero chance of being right.

Interesting.  For BETWEEN '2013-01-01' AND '2015-09-30',
where I expect customer counts to be decent and MRR bad,
the customer counts are *closer*.  Very close to ending
customer counts.

So let''s play it through with counts, holding off on MRR.

SELECT
year_month
,COUNT(*) AS new_custs
FROM tmp_data_dm.coe_jrr_new_customer
GROUP BY 1
ORDER BY 1

Ugh.  After all that, same 2 problems (to start with):
- There is no M00 for last month (201609).
- Sometimes M00 < M01.
omg i think it is off by 1.
Nope need to use start month on rows of pivot not year_month.

My new customer count in a cohort is substantially > ss.
Maybe I am not deduping at the right place.
I do have ad type in the query that counts customers.
Pretty sure the reason that does not cause problems for Jane is 
in a given market, a prof only has one type of ad.
OK I probably fixed the deduping.

Now the early-on tenure months look ok, but further out gets bad.
Hard to tell if the error gets worse at a specific calendar month,
which likely means no.
Looks more like it is just the cumulative effect of errors.

My numbers are higher.

Ah, it may be that if someone leaves and comes back, my code shows 
them again but ss code does not?  Fixed (in theory).
Also fair number of cases where ss code does not have the last month
that mine does.  Maybe cancel vs. expire?
And I suspect that my code may think someone is new even if they had
a prior sub if that is earlier than the timeframe I am looking at.
Does not just work to start with everyone active on X date, because
a return looks like a new sub to me.  Fixed (in theory).

Very close on counts now.  Weirdly, in calendar month 201409, I
overstate cohorts up through 201404 by 2 to 8% (ave 3%).
Not going to chase that down for now.

Interestingly, from 201510, I understate by a couple percent sometimes.
That cohort, look at them in 201603.
I understate by 16.

- I often drop the final month (5623, 10023).
  Because I do not count if no payment.
- For some (46553, 46549), I think the start month is 1 month later than legacy.
  Same story, failed payment in first month, so I think their first 
  month is the following.
- For some, (45786, 45414), I cut them off way sooner than legacy.

----------------------------------------------------------------------
----------------------------------------------------------------------
New biz rule:
-- Legacy ss counts someone if we did not collect payment when expected, 
-- and calls their MRR 0.
-- Instead, we want to see if we collected even via a misc payment in 
-- the month.  If so, count them and their MRR.  If not, don''t.
-- Want a flag to tell that apart from actually expired.
-- So, failed payment but recovered, vs. failed payment then churned.
-- Probably do not even care if failed payment then recovered.
Nope.  They still count as 0.  I am inclined to stick with the logic
that sets MRR to 0 just for compatibility for that history.

Other new biz rule:
Count every chain.  So returns get lumped into acquisition (with a flag).
----------------------------------------------------------------------
----------------------------------------------------------------------

I might need to make the chain_ids consecutive?
They are at least sortable (reverse).

Add a has_ads flag.
Add a successful_payment_in_month flag.
Add a returned flag (for every chain where chain_id <> 1.)

Then also want tenure_month_lifetime vs. tenure_month_chain.


DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_sub_bills;
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

odear.
11,929,847 rows inserted.
12,007,092 huh this many rows in olaf.
ok then.

-- One row per (customer, billed month)
-- This is before the chain logic.
DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_active_months;
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

DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_customer_lifetime_start;
CREATE TABLE tmp_data_dm.coe_jrr_customer_lifetime_start AS
SELECT
   bls.customer_id
  ,MIN(bls.year_month) AS             start_month
  ,MIN(bls.year_month_begin_date) AS  start_month_begin_date
FROM tmp_data_dm.coe_jrr_cust_active_months bls
GROUP BY 1

-- LOOK may not work to do this any more - think I need every chain start.
-- Leaving this for now so I can sanity-check.
-- Identify cohort for each customer
-- One row per customer per product_line_id.
-- This puts the first-billed month rows into their own table.
-- LOOK may not work to do this any more - think I need every chain start.
-- Leaving this for now so I can sanity-check.
DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_start_month;
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
DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cohort_start_values;
CREATE TABLE tmp_data_dm.coe_jrr_cohort_start_values AS
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
DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_chains;
CREATE TABLE tmp_data_dm.coe_jrr_cust_chains AS
SELECT
   chn.customer_id
  ,chn.start_month
  ,chn.start_month_begin_date
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
                         ORDER BY chn.tenure_month) AS rnk
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
  FROM tmp_data_dm.coe_jrr_cust_start_month nc
  LEFT JOIN tmp_data_dm.coe_jrr_cust_active_months future 
         ON nc.customer_id = future.customer_id 
        AND nc.start_month <= future.year_month 
        AND future.year_month < 201610
WHERE future.has_ads = 'Y'  -- LOOK lose me later
  ) chn

-- Join from cohort start table to every month that the customer got billed in.
-- This is the main query.
-- I will have to change this a bunch because I want customer_id.
DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cohort_months;
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
    LEFT JOIN tmp_data_dm.coe_jrr_cohort_start_values cac 
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
DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_final;
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

I see some customers earlier than I should.
Looks like they had a canceled sub in that month.  Failed payment.

OK.  up to and including 2015-09, the yearmonth field if there was 
no payment is 1900001.
From 2015-10 on, it is the actual yearmonth from order_line_begin_date. (or maybe ppayment date)
Legacy churn spreadsheet uses that.
So in earlier months, it would not count a sub if no payment.
In later months, it would.
Trying to unfix the yearmonth field in my code did not fix it.  Way too many custs now.
Might have done it wrong.

select
   cast(yearmonth as int) as year_month_in_table       
  ,CAST(from_unixtime(unix_timestamp(CAST(order_line_begin_date AS TIMESTAMP)), 'yyyyMM') AS INT) AS    year_month_order_line_begin
  ,CAST(from_unixtime(unix_timestamp(CAST(order_line_payment_date AS TIMESTAMP)), 'yyyyMM') AS INT) AS  year_month_order_line_payment
  ,CAST(from_unixtime(unix_timestamp(CAST(order_line_purchase_date AS TIMESTAMP)), 'yyyyMM') AS INT) AS year_month_order_line_purchase
  ,count(*) as num_rows
from dm.order_line_accumulation_fact 
group by 1,2
order by 1,2
Yep can also tell it was based on payment date, not begin date.

OK:
- What does current MRR logic think at the sub level if no pmt in month?
- How about entire cust level?
Confirmed by Hema: at the subscription level, if there was a 
payment failure, revenue = 0 but MRR stays whatever it would have 
been.  And at the customer level, if there were no successful 
payments in the month, we still count the customer and their MRR, 
and their total revenue is 0. 

Currently trying to fix year_month in the legacy code and then compare
those results to my new counts.

OK.  Customer counts match perfectly now.  Tackling MRR and then
categories.
Remember that churned MRR has to be thought about differently.
Then later, I can add an option to include returned in the cohorts.

----

select
*
from tmp_data_dm.coe_jrr_cust_chains chn
where customer_id IN (
119, 333, 342, 434, 468, 549, 659, 717, 838, 923, 931, 1266, 1478,
1497, 1511, 1664, 2025, 2132, 2198, 2623, 2673, 2869, 2890, 2906,
2978, 3495, 3731, 3811, 4109, 4194, 4248, 4340, 4417, 4421, 4711,
4852, 4894, 5053, 5091, 5175, 5332, 5381, 5454, 5566, 5639, 5667,
5675, 5709, 5784, 6084, 6130, 6397, 6632, 6703, 6780, 6801, 6887,
6915, 6997, 7023, 7205, 7286, 7307, 7309, 7348, 7372, 7438, 7500,
7501, 7557, 7645, 7664, 7829, 7844, 7880, 7899, 7918, 7942, 7962,
7976, 8000, 8043, 8049, 8100, 8133, 8211, 8408, 8410, 8448, 8464,
8565, 8596, 8659, 8683, 8709, 8735, 8741, 8771, 8916, 9113, 9156,
9321, 9413, 9485, 9713, 9765, 9793, 9830, 9851, 10151, 10205, 10444,
10777, 11156, 11249, 11419, 11426, 11486, 11733, 11907, 12030,
12397, 12414, 12450, 12660, 12849, 12979, 13243, 13584, 13811,
13883, 14514, 14515, 14886, 15045, 16394, 16783, 17390, 18137,
18544, 18718, 18929, 18939, 19747, 19849, 20436, 21600, 21847,
22032, 22876, 23040, 23229, 25263, 25573, 28069, 32098 
)
order by chn.customer_id, chn.tenure_month

----

OK consider this.  Maybe in the main chain table I only bring through
the metrics that I am going to base decisions on.  Then in a
different table, I get all of the prev values that I am going to want 
to dump into the table at the end.  And the individual revenue and
mrr breakouts.
Naw.

Well damn.  Looks like customer_professional_purchase_map does not have every customer.
Build this myself.

So not using this version:
-- -- One row per (customer, billed month)
-- -- This is before the chain logic.
-- DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_active_months;
-- CREATE TABLE tmp_data_dm.coe_jrr_cust_active_months AS
-- SELECT
--    mth.customer_id
--   ,mth.year_month
--   ,mth.year_month_begin_date
--   ,mth.has_ads
--   ,mth.has_payment
--   ,mth.revenue_current_advertisement
--   ,mth.revenue_current_avvopro
--   ,mth.revenue_current_ignite
--   ,mth.revenue_current_website
--   ,mth.revenue_current_adplacement
--   ,mth.revenue_current_misc
--   ,mth.revenue_current_other_sub
--   ,mth.revenue_current_other
--   ,mth.revenue_current_total
--   ,mth.mrr_current_advertisement
--   ,mth.mrr_current_avvopro
--   ,mth.mrr_current_ignite
--   ,mth.mrr_current_website
--   ,mth.mrr_current_adplacement
--   ,mth.mrr_current_other_sub
--   ,mth.mrr_current_total
--   ,lbd.customer_prev_billed_date
-- FROM
--   (
--   SELECT
--      bls.customer_id
--     ,bls.year_month
--     ,bls.year_month_begin_date
--     ,MAX(bls.has_ads) AS     has_ads
--     ,MAX(bls.has_payment) AS has_payment
--     ,SUM(CASE WHEN bls.product_type IN ('Display', 'Sponsored Listing') THEN bls.revenue ELSE 0 END) AS revenue_current_advertisement
--     ,SUM(CASE WHEN bls.product_type = 'Pro'                             THEN bls.revenue ELSE 0 END) AS revenue_current_avvopro
--     ,SUM(CASE WHEN bls.product_type = 'Ignite'                          THEN bls.revenue ELSE 0 END) AS revenue_current_ignite
--     ,SUM(CASE WHEN bls.product_type = 'Website'                         THEN bls.revenue ELSE 0 END) AS revenue_current_website
--     ,SUM(CASE WHEN bls.product_type = 'Ad Placement'                    THEN bls.revenue ELSE 0 END) AS revenue_current_adplacement
--     ,SUM(CASE WHEN bls.product_type = 'Misc'                            THEN bls.revenue ELSE 0 END) AS revenue_current_misc
--     ,SUM(CASE WHEN bls.product_type = 'Other Subscription'              THEN bls.revenue ELSE 0 END) AS revenue_current_other_sub
--     ,SUM(CASE WHEN bls.product_type = 'Other'                           THEN bls.revenue ELSE 0 END) AS revenue_current_other
--     ,SUM(CASE WHEN bls.product_type NOT LIKE 'Other%'                   THEN bls.revenue ELSE 0 END) AS revenue_current_total
--     ,SUM(CASE WHEN bls.product_type IN ('Display', 'Sponsored Listing') THEN bls.mrr     ELSE 0 END) AS mrr_current_advertisement
--     ,SUM(CASE WHEN bls.product_type = 'Pro'                             THEN bls.mrr     ELSE 0 END) AS mrr_current_avvopro
--     ,SUM(CASE WHEN bls.product_type = 'Ignite'                          THEN bls.mrr     ELSE 0 END) AS mrr_current_ignite
--     ,SUM(CASE WHEN bls.product_type = 'Website'                         THEN bls.mrr     ELSE 0 END) AS mrr_current_website
--     ,SUM(CASE WHEN bls.product_type = 'Ad Placement'                    THEN bls.mrr     ELSE 0 END) AS mrr_current_adplacement
--     ,SUM(CASE WHEN bls.product_type = 'Other Subscription'              THEN bls.mrr     ELSE 0 END) AS mrr_current_other_sub
--     ,SUM(CASE WHEN bls.product_type NOT LIKE 'Other%'                   THEN bls.mrr     ELSE 0 END) AS mrr_current_total
--   FROM tmp_data_dm.coe_jrr_sub_bills bls
--   GROUP BY 1,2,3
--   ) mth
--     LEFT OUTER JOIN
--   (
--   SELECT cpp.customer_id, cpp.yearmonth AS year_month
--     ,MAX(CASE WHEN cpp.last_billed_date < mth.month_begin_date THEN cpp.last_billed_date ELSE NULL END) AS customer_prev_billed_date
--   FROM         dm.customer_professional_purchase_map cpp
--     INNER JOIN dm.month_dim mth ON cpp.yearmonth = mth.year_month
--   GROUP BY 1,2
--   ) lbd
--             ON mth.year_month = lbd.year_month
--            AND mth.customer_id = lbd.customer_id
-- -- WHERE mth.has_ads = 'Y' OR mth.mrr_current_total > 0  -- LOOK return to this
-- WHERE mth.has_ads = 'Y'

    mrr_customer_category
    mrr_acquired    -- MRR associated with customers acquired for the first time in the current month.
    mrr_penetrated  -- Change in MRR amount for customers whose MRR went up from the prior month to the current month.
    mrr_downsized   -- Change in MRR amount for customers whose MRR went down from the prior month to the current month.
    mrr_churned     -- MRR associated with customers who churned (across all subscriptions) in the current month.
    mrr_retained    -- MRR for customers whose (non-zero) MRR did not change from the prior month to the current month.
                    -- Retained includes the non-delta part of MRR for upsold or downsized.
    mrr_returned    -- MRR for customers who previously received service, then lapsed, and returned in the current month.
    expired_date    -- The latest (max) expired date for any of the products in the given month.  This is not populated if expired date is in the future.
    -- customer_prev_billed_date  -- Most recent bill date prior to current month.
    customer_billed_current_month_flag  -- Y/N: Did the customer have a bill in the current month? Does not distinguish between 0 and non-0 bills, and does not look at whether the payment succeeded.
    -- New fields
    mrr_retained_same -- MRR for customers whose MRR is the same as the prior month.
    mrr_retained_different -- The non-delta part of MRR for customers who upsold or downsized.
    customer_misc_payment_current_month_flag
    -- mrr_no_activity  -- The reduction in MRR from customers who downsized to 0.  Nope! Calling that downsize, so don''t need that.
    mrr_customer_exception_flag -- Y/N: Does this customer fit any of our weird exception cases?
                                -- Current cases:
                                --   All NO ACTIVITY
                                --   UPSOLD from 0
                                --   DOWNSIZED to 0
                                --   No payment in month and 0 MRR but active.

OK getting worried about the duplicated code in my unions:

-- SELECT
--    ord.year_month
--   ,ord.year_month_begin_date
--   ,ord.product_type
--   ,MAX(ord.max_bill_date_in_month) AS max_bill_date_in_month
--   ,SUM(ord.mrr) AS mrr
--   ,SUM(ord.block_count) AS block_count
--   ,SUM(ord.revenue) AS revenue
--   ,COUNT(*) AS num_rows
-- FROM
-- (
--     SELECT
--        olaf.customer_id
--       ,dt.year_month
--       ,dt.month_begin_date AS year_month_begin_date
--       ,olaf.product_subscription_id
--       ,olaf.product_line_id
--       ,CASE WHEN olaf.product_line_id = 2 THEN 'Display'
--             WHEN olaf.product_line_id = 7 THEN 'Sponsored Listing'
--             WHEN olaf.product_line_id = 4 THEN 'Pro'
--             WHEN olaf.product_line_id IN (10, 11) THEN 'Ignite'
--             WHEN olaf.product_line_id IN (12, 15) THEN 'Website'
--             WHEN olaf.product_line_id = 17  THEN 'Misc'
--             WHEN olaf.order_line_number < 0 THEN 'Misc'
--             WHEN olaf.product_line_id = 18 THEN 'Ad Placement'
--             WHEN IFNULL(olaf.product_subscription_id, -1) <> -1 THEN 'Other Subscription'
--             ELSE 'Other'
--        END AS product_type
--       ,CASE WHEN olaf.product_line_id IN (2, 7) THEN 'Y' ELSE 'N' END AS has_ads
--       ,CASE WHEN olaf.order_line_payment_date NOT IN ('1900-01-01', '-1') 
--              AND olaf.order_line_net_price_amount_usd > 0 THEN 'Y' ELSE 'N' END AS has_payment
--       ,SUM(COALESCE(mrr.mrr_actual_value,0)) AS mrr
--       ,SUM(olaf.block_count) AS block_count
--       ,SUM(olaf.order_line_net_price_amount_usd) AS revenue
--       ,MAX(olaf.order_line_begin_date) AS max_bill_date_in_month
--     FROM         dm.order_line_accumulation_fact olaf
--       INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
--     LEFT JOIN dm.mrr_subscription mrr ON mrr.subscription_id = olaf.product_subscription_id 
--           AND mrr.yearmonth = CAST(from_unixtime(unix_timestamp(CAST(olaf.order_line_begin_date AS TIMESTAMP)), 'yyyyMM') AS INT)
--     WHERE olaf.order_line_begin_date >= '2015-10-01'
--       GROUP BY 1,2,3,4,5,6,7,8
-- UNION ALL
--     SELECT
--        olaf.customer_id
--       ,dt.year_month
--       ,dt.month_begin_date AS year_month_begin_date
--       ,olaf.product_subscription_id
--       ,olaf.product_line_id
--       ,CASE WHEN olaf.product_line_id = 2 THEN 'Display'
--             WHEN olaf.product_line_id = 7 THEN 'Sponsored Listing'
--             WHEN olaf.product_line_id = 4 THEN 'Pro'
--             WHEN olaf.product_line_id IN (10, 11) THEN 'Ignite'
--             WHEN olaf.product_line_id IN (12, 15) THEN 'Website'
--             WHEN olaf.product_line_id = 17  THEN 'Misc'
--             WHEN olaf.order_line_number < 0 THEN 'Misc'
--             WHEN olaf.product_line_id = 18 THEN 'Ad Placement'
--             WHEN IFNULL(olaf.product_subscription_id, -1) <> -1 THEN 'Other Subscription'
--             ELSE 'Other'
--        END AS product_type
--       ,CASE WHEN olaf.product_line_id IN (2, 7) THEN 'Y' ELSE 'N' END AS has_ads
--       ,CASE WHEN olaf.order_line_payment_date NOT IN ('1900-01-01', '-1') 
--              AND olaf.order_line_net_price_amount_usd > 0 THEN 'Y' ELSE 'N' END AS has_payment
--       ,SUM(100) as mrr  -- LOOK obviously wrong.
--       ,SUM(olaf.block_count) AS block_count
--       ,SUM(olaf.order_line_net_price_amount_usd) AS revenue
--       ,MAX(olaf.order_line_begin_date) AS max_bill_date_in_month
--     FROM         dm.order_line_accumulation_fact olaf
--       INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
--     -- left join dm.mrr_subscription mrr on mrr.subscription_id = o.product_subscription_id 
--     --       and mrr.yearmonth=cast(concat(cast(year(o.order_line_begin_date) as string), lpad(cast(month(o.order_line_begin_date) as string),2,'0')) as int)
--     WHERE olaf.order_line_begin_date BETWEEN '2014-09-01' AND '2015-09-30'
--       GROUP BY 1,2,3,4,5,6,7,8
-- UNION ALL
--     SELECT
--        olaf.customer_id
--       ,dt.year_month
--       ,dt.month_begin_date AS year_month_begin_date
--       ,olaf.product_subscription_id
--       ,olaf.product_line_id
--       ,CASE WHEN olaf.product_line_id = 2 THEN 'Display'
--             WHEN olaf.product_line_id = 7 THEN 'Sponsored Listing'
--             WHEN olaf.product_line_id = 4 THEN 'Pro'
--             WHEN olaf.product_line_id IN (10, 11) THEN 'Ignite'
--             WHEN olaf.product_line_id IN (12, 15) THEN 'Website'
--             WHEN olaf.product_line_id = 17  THEN 'Misc'
--             WHEN olaf.order_line_number < 0 THEN 'Misc'
--             WHEN olaf.product_line_id = 18 THEN 'Ad Placement'
--             WHEN IFNULL(olaf.product_subscription_id, -1) <> -1 THEN 'Other Subscription'
--             ELSE 'Other'
--        END AS product_type
--       ,CASE WHEN olaf.product_line_id IN (2, 7) THEN 'Y' ELSE 'N' END AS has_ads
--       ,CASE WHEN olaf.order_line_payment_date NOT IN ('1900-01-01', '-1') 
--              AND olaf.order_line_net_price_amount_usd > 0 THEN 'Y' ELSE 'N' END AS has_payment
--       ,SUM(100) as mrr  -- LOOK obviously wrong.
--       ,SUM(olaf.block_count) AS block_count
--       ,SUM(olaf.order_line_net_price_amount_usd) AS revenue
--       ,MAX(olaf.order_line_begin_date) AS max_bill_date_in_month
--     FROM         dm.order_line_accumulation_fact olaf
--       INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
--     -- left join dm.mrr_subscription mrr on mrr.subscription_id = o.product_subscription_id 
--     --       and mrr.yearmonth=cast(concat(cast(year(o.order_line_begin_date) as string), lpad(cast(month(o.order_line_begin_date) as string),2,'0')) as int)
--     WHERE olaf.order_line_begin_date BETWEEN '2013-01-01' AND '2014-08-31'
--       GROUP BY 1,2,3,4,5,6,7,8
-- ) ord
-- GROUP BY 1,2,3


-- SELECT
--    ord.year_month
--   ,ord.year_month_begin_date
--   ,ord.product_type
--   ,MAX(ord.max_bill_date_in_month) AS max_bill_date_in_month
--   ,SUM(ord.mrr) AS mrr
--   ,SUM(ord.block_count) AS block_count
--   ,SUM(ord.revenue) AS revenue
--   ,COUNT(*) AS num_rows
-- FROM
--   (
--   SELECT
--      unn.customer_id
--     ,unn.year_month
--     ,unn.year_month_begin_date
--     ,unn.product_subscription_id
--     ,unn.product_line_id
--     ,CASE WHEN unn.product_line_id = 2 THEN 'Display'
--           WHEN unn.product_line_id = 7 THEN 'Sponsored Listing'
--           WHEN unn.product_line_id = 4 THEN 'Pro'
--           WHEN unn.product_line_id IN (10, 11) THEN 'Ignite'
--           WHEN unn.product_line_id IN (12, 15) THEN 'Website'
--           WHEN unn.product_line_id = 17  THEN 'Misc'
--           WHEN unn.order_line_number < 0 THEN 'Misc'
--           WHEN unn.product_line_id = 18 THEN 'Ad Placement'
--           WHEN IFNULL(unn.product_subscription_id, -1) <> -1 THEN 'Other Subscription'
--           ELSE 'Other'
--      END AS product_type
--     ,CASE WHEN unn.product_line_id IN (2, 7) THEN 'Y' ELSE 'N' END AS has_ads
--     ,CASE WHEN unn.order_line_payment_date NOT IN ('1900-01-01', '-1') 
--            AND unn.order_line_net_price_amount_usd > 0 THEN 'Y' ELSE 'N' END AS has_payment
--     ,SUM(unn.mrr) AS mrr
--     ,SUM(unn.block_count) AS block_count
--     ,SUM(unn.order_line_net_price_amount_usd) AS revenue
--     ,MAX(unn.order_line_begin_date) AS max_bill_date_in_month
--   FROM
--     (
--         SELECT
--            olaf.*
--           ,dt.year_month
--           ,dt.month_begin_date AS year_month_begin_date
--           ,mrr.mrr
--         FROM         dm.order_line_accumulation_fact olaf
--           INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
--           LEFT OUTER JOIN dm.mrr_subscription mrr
--                   ON olaf.product_subscription_id = mrr.subscription_id
--                  AND dt.year_month = mrr.yearmonth
--         WHERE olaf.order_line_begin_date >= '2015-10-01'
--     UNION ALL
--         SELECT
--            olaf.*
--           ,dt.year_month
--           ,dt.month_begin_date AS year_month_begin_date
--           -- ,mrr.mrr
--           ,100 AS mrr
--         FROM         dm.order_line_accumulation_fact olaf
--           INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
--           -- LEFT OUTER JOIN
--           --   (-- Some spiffy query here that cleverly gets mrr for the right point in time
--           --   SELECT
--           --      subscription_id
--           --     ,year_month
--           --     ,mrr
--           --   FROM -- who knows
--           --   ) mrr
--           --   ON olaf.product_subscription_id = mrr.subscription_id
--           --  AND dt.year_month = mrr.year_month
--         WHERE olaf.order_line_begin_date BETWEEN '2014-09-01' AND '2015-09-30'
--     UNION ALL
--         SELECT
--            olaf.*
--           ,dt.year_month
--           ,dt.month_begin_date AS year_month_begin_date
--           -- ,mrr.mrr
--           ,100 AS mrr
--         FROM         dm.order_line_accumulation_fact olaf
--           INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
--   ---- Yeah no clever joining here, olaf is all there is.
--         WHERE olaf.order_line_begin_date BETWEEN '2013-01-01' AND '2014-08-31'
--     ) unn
--   GROUP BY 1,2,3,4,5,6,7,8
--   ) ord
-- GROUP BY 1,2,3

Wahoo!  Did not completely fuck up the counts.

Next step go try to find mrr.

-- Get the MRR for every subscription that exists.
-- This will only be used for the in between time period:
-- recent enough that we have a subscription to join to,
-- but not so recent that we actually ahve mrr data already.

DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_sub_price_mrr;
CREATE TABLE tmp_data_dm.coe_jrr_sub_price_mrr AS
SELECT DISTINCT
   subscription_id
  ,mrr
FROM   (
       SELECT 
          subscription_id 
         ,ROUND(CAST(unit_price AS DOUBLE) * block_count / 100, 2) AS mrr
         ,RANK() OVER(PARTITION BY subscription_id
                          ORDER BY start_datetime DESC
                     ) seq 
       FROM dm.subscription_price_dimension
       -- WHERE unit_price <> 0
       ) AS spd_curr 
WHERE seq = 1

- Factor in expire date to decide if active and mrr.
  Get expire_datetime from subscription_dimension.
  Get order_line_cancelled_date from olaf.
  Get max of all of those, coalescing to 2999-01-01.
  (so if null we assume it is way in the future)
- Flow through mrr_unfiltered.  Or maybe it can come in later?
  Ah!  Maybe I can call it full_price.
-- - Factor in payment date to determine revenue
-- - Add a field mrr_method.

Note: could use historical subscription price table instead.
But I got pretty darned close using what I have, so not going
to try that unless I have solid evidence that it is needed.

-- -- This is where we go get MRR from different places based on
-- -- what we have in history.
-- DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_sub_bills;
-- CREATE TABLE tmp_data_dm.coe_jrr_sub_bills AS
-- SELECT
--    unn.customer_id
--   ,unn.year_month
--   ,unn.year_month_begin_date
--   ,unn.mrr_method
--   ,unn.product_subscription_id
--   ,unn.product_line_id
--   ,CASE WHEN unn.product_line_id = 2 THEN 'Display'
--         WHEN unn.product_line_id = 7 THEN 'Sponsored Listing'
--         WHEN unn.product_line_id = 4 THEN 'Pro'
--         WHEN unn.product_line_id IN (10, 11) THEN 'Ignite'
--         WHEN unn.product_line_id IN (12, 15) THEN 'Website'
--         WHEN unn.product_line_id = 17  THEN 'Misc'
--         WHEN unn.order_line_number < 0 THEN 'Misc'
--         WHEN unn.product_line_id = 18 THEN 'Ad Placement'
--         WHEN IFNULL(unn.product_subscription_id, -1) <> -1 THEN 'Other Subscription'
--         ELSE 'Other'
--    END AS product_type
--   ,CASE WHEN unn.product_line_id IN (2, 7) THEN 'Y' ELSE 'N' END AS has_ads
--   ,CASE WHEN unn.order_line_payment_date NOT IN ('1900-01-01', '-1') 
--          AND unn.order_line_net_price_amount_usd > 0 THEN 'Y' ELSE 'N' END AS has_payment
--   ,SUM(unn.mrr) AS mrr
--   ,SUM(unn.block_count) AS block_count
--   ,SUM(unn.order_line_net_price_amount_usd) AS revenue
--   ,MAX(unn.order_line_begin_date) AS max_bill_date_in_month
-- FROM
--   (
--       SELECT
--          olaf.*
--         ,'MRR' AS mrr_method
--         ,dt.year_month
--         ,dt.month_begin_date AS year_month_begin_date
--         ,IFNULL(mrr.mrr, 0) AS mrr
--       FROM         dm.order_line_accumulation_fact olaf
--         INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
--         LEFT OUTER JOIN dm.mrr_subscription mrr
--                 ON olaf.product_subscription_id = mrr.subscription_id
--                AND dt.year_month = mrr.yearmonth
--       WHERE olaf.order_line_begin_date >= '2015-10-01'
--   UNION ALL
--       SELECT
--          olaf.*
--         ,'Subscription Price' AS mrr_method
--         ,dt.year_month
--         ,dt.month_begin_date AS year_month_begin_date
--         ,IFNULL(mrr.mrr, 0) AS mrr
--       FROM         dm.order_line_accumulation_fact olaf
--         INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
--         LEFT OUTER JOIN tmp_data_dm.coe_jrr_sub_price_mrr mrr
--                 ON olaf.product_subscription_id = mrr.subscription_id
--       WHERE olaf.order_line_begin_date BETWEEN '2014-09-01' AND '2015-09-30'
--   UNION ALL
--       SELECT
--          olaf.*
--         ,'Order Line' AS mrr_method
--         ,dt.year_month
--         ,dt.month_begin_date AS year_month_begin_date
--         -- ,mrr.mrr
--         ,100 AS mrr
--       FROM         dm.order_line_accumulation_fact olaf
--         INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
-- ---- Yeah no clever joining here, olaf is all there is.
--       WHERE olaf.order_line_begin_date BETWEEN '2013-01-01' AND '2014-08-31'
--   ) unn
-- GROUP BY 1,2,3,4,5,6,7,8,9

-- DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_active_months;
-- CREATE TABLE tmp_data_dm.coe_jrr_cust_active_months AS
-- SELECT *
-- FROM
--   (
--   SELECT
--      bls.customer_id
--     ,bls.year_month
--     ,bls.year_month_begin_date
--     ,bls.mrr_method
--     ,MAX(bls.has_ads) AS                 has_ads
--     ,MAX(bls.has_payment) AS             has_payment
--     ,MAX(bls.max_bill_date_in_month) AS  max_bill_date_in_month
--     ,SUM(CASE WHEN bls.product_type IN ('Display', 'Sponsored Listing') THEN bls.revenue ELSE 0 END) AS revenue_current_advertisement
--     ,SUM(CASE WHEN bls.product_type = 'Pro'                             THEN bls.revenue ELSE 0 END) AS revenue_current_avvopro
--     ,SUM(CASE WHEN bls.product_type = 'Ignite'                          THEN bls.revenue ELSE 0 END) AS revenue_current_ignite
--     ,SUM(CASE WHEN bls.product_type = 'Website'                         THEN bls.revenue ELSE 0 END) AS revenue_current_website
--     ,SUM(CASE WHEN bls.product_type = 'Ad Placement'                    THEN bls.revenue ELSE 0 END) AS revenue_current_adplacement
--     ,SUM(CASE WHEN bls.product_type = 'Misc'                            THEN bls.revenue ELSE 0 END) AS revenue_current_misc
--     ,SUM(CASE WHEN bls.product_type = 'Other Subscription'              THEN bls.revenue ELSE 0 END) AS revenue_current_other_sub
--     ,SUM(CASE WHEN bls.product_type = 'Other'                           THEN bls.revenue ELSE 0 END) AS revenue_current_other
--     ,SUM(CASE WHEN bls.product_type NOT LIKE 'Other%'                   THEN bls.revenue ELSE 0 END) AS revenue_current_total
--     ,SUM(CASE WHEN bls.product_type IN ('Display', 'Sponsored Listing') THEN bls.mrr     ELSE 0 END) AS mrr_current_advertisement
--     ,SUM(CASE WHEN bls.product_type = 'Pro'                             THEN bls.mrr     ELSE 0 END) AS mrr_current_avvopro
--     ,SUM(CASE WHEN bls.product_type = 'Ignite'                          THEN bls.mrr     ELSE 0 END) AS mrr_current_ignite
--     ,SUM(CASE WHEN bls.product_type = 'Website'                         THEN bls.mrr     ELSE 0 END) AS mrr_current_website
--     ,SUM(CASE WHEN bls.product_type = 'Ad Placement'                    THEN bls.mrr     ELSE 0 END) AS mrr_current_adplacement
--     ,SUM(CASE WHEN bls.product_type = 'Other Subscription'              THEN bls.mrr     ELSE 0 END) AS mrr_current_other_sub
--     ,SUM(CASE WHEN bls.product_type NOT LIKE 'Other%'                   THEN bls.mrr     ELSE 0 END) AS mrr_current_total
--   FROM tmp_data_dm.coe_jrr_sub_bills bls
--   GROUP BY 1,2,3,4
--   ) mth
-- -- WHERE mth.has_ads = 'Y' OR mth.mrr_current_total > 0  -- LOOK return to this
-- WHERE mth.has_ads = 'Y'

      , CASE WHEN olaf.order_line_payment_date = '-1' THEN 0
             WHEN DAY(olaf.order_line_begin_date) = 1 THEN SUM(olaf.order_line_net_price_amount_usd)
             WHEN DAY(olaf.order_line_begin_date) = days_in_month THEN SUM(olaf.order_line_net_price_amount_usd)*days_in_month
             ELSE SUM(olaf.order_line_net_price_amount_usd)*days_in_month / (days_in_month - DAY(olaf.order_line_begin_date))
        END AS full_price              

3 timeframes:
>= 201510 do not generate anything, we have data.
   (201510 is present in new MRR table but suspect. maybe.)
BETWEEN 201409 AND 201509 use logic that joins to subscription_dimension.
BETWEEN 201304 AND 201408 use old churn spreadsheet logic.

  select y.cust_id                  
    , y.active_month                
    , y.month_number                
    , case when y.active_month<=201407                 
      then (              
             case when y.price_lastmonth=0 then           
             (          
               case when y.price_nextmonth=0 then y.final_price         
               else y.price_nextmonth end         
             )          
              else y.final_price end          
           )            
      else y.final_price end as revenue  ---prorated adjusted to full month price:MRR              
  from                  
  (                  
    select b1.*                
      , coalesce(b2.final_price,0) as price_lastmonth              
      , coalesce(b3.final_price,0) as price_nextmonth              
    from base b1                
    left join                
    base b2 on b1.month_number=b2.month_number+1 and b1.cust_id=b2.cust_id                
    left join base b3 on b1.month_number=b3.month_number-1 and b1.cust_id=b3.cust_id                
  ) y  
Ah we don''t ever use last month''s price as mrr, we just use it
to see if they went 0 to paying.
If they were billed a non-zero amount last month, then we know this
month is not a prorate month.

SELECT
   olaf.product_subscription_id AS subscription_id
  ,dt.year_month
  ,dt.month_begin_date AS year_month_begin_date
  ,dt.month_end_date AS year_month_end_date
  ,CASE WHEN olaf.order_line_payment_date = '-1' 
          THEN SUM(0)
        WHEN DAY(olaf.order_line_begin_date) = 1 
          THEN SUM(olaf.order_line_net_price_amount_usd)
        WHEN DAY(olaf.order_line_begin_date) = mth.day_in_month_count 
          THEN SUM(olaf.order_line_net_price_amount_usd) * mth.day_in_month_count
          ELSE SUM(olaf.order_line_net_price_amount_usd) * mth.day_in_month_count
                  /
                  (mth.day_in_month_count - DAY(olaf.order_line_begin_date))
   END AS full_price              
FROM         dm.order_line_accumulation_fact olaf
  INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
  INNER JOIN dm.month_dim mth ON dt.year_month = mth.year_month
-- Have to get one month before and after desired timeframe so I can
-- look at prior and next month.
WHERE olaf.order_line_begin_date BETWEEN '2012-12-01' AND '2014-09-30'
GROUP BY 1,2,3,4

ok that just doesn''t run.  restructure.

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
-- I know this is a redundant hit to olaf, but it keeps the main mrr
-- code simpler.
DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_olaf_price;
CREATE TABLE tmp_data_dm.coe_jrr_olaf_price AS
SELECT
   subscription_id
  ,year_month
  ,CASE WHEN year_month > 201407 THEN full_price_this_month
        -- This case means we are likely in the prorate month, and 
        -- <= 201407 we do not have enough info to prorate so grab
        -- next month''s price.
        WHEN full_price_last_month = 0 AND full_price_next_month > 0 THEN full_price_next_month
        ELSE full_price_this_month END AS full_price
,full_price_last_month_raw
,full_price_this_month
,full_price_next_month_raw
,full_price_last_month
,full_price_next_month
FROM
  (
  SELECT
     subscription_id
    ,year_month
    ,full_price_this_month
    ,IFNULL(LAG(full_price_this_month,1)  OVER(PARTITION BY subscription_id
                                                ORDER BY year_month), 0) AS full_price_last_month
    ,IFNULL(LEAD(full_price_this_month,1) OVER(PARTITION BY subscription_id
                                                ORDER BY year_month), 0) AS full_price_next_month
,LAG(full_price_this_month,1)         OVER(PARTITION BY subscription_id
                                               ORDER BY year_month) AS full_price_last_month_raw
,LEAD(full_price_this_month,1)        OVER(PARTITION BY subscription_id
                                               ORDER BY year_month) AS full_price_next_month_raw
  FROM
    (
    SELECT
       oln.subscription_id
      ,oln.year_month
      ,SUM(full_price) AS full_price_this_month
    FROM
      (
      SELECT
         -- Yeah I know this gets weird if mult orders for a sub in same month.
         -- Old code does not worry about that so neither will I.
         olaf.order_line_number
        ,olaf.product_subscription_id AS subscription_id
        ,olaf.order_line_begin_date
        ,dt.year_month
        ,CASE WHEN olaf.order_line_payment_date = '-1' 
                THEN 0
              WHEN DAY(olaf.order_line_begin_date) = 1 
                THEN olaf.order_line_net_price_amount_usd
              WHEN DAY(olaf.order_line_begin_date) = mth.day_in_month_count 
                THEN olaf.order_line_net_price_amount_usd * mth.day_in_month_count
                ELSE olaf.order_line_net_price_amount_usd * mth.day_in_month_count
                     /
                     (mth.day_in_month_count - DAY(olaf.order_line_begin_date))
         END AS full_price              
      FROM         dm.order_line_accumulation_fact olaf
        INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
        INNER JOIN dm.month_dim mth ON dt.year_month = mth.year_month
      -- Have to get one month before and after desired timeframe so I can
      -- look at prior and next month.
      WHERE olaf.order_line_begin_date BETWEEN '2012-12-01' AND '2014-09-30'
      ) oln
    GROUP BY 1,2
    ) sym
  ) sub
WHERE year_month BETWEEN 201301 AND 201408

SELECT
   year_month
  ,mrr_method
  ,product_type
  ,has_ads
  ,has_payment
  ,sub_continues_past_month
  ,SUM(mrr) AS mrr
  ,SUM(revenue) AS revenue
  ,COUNT(*) AS bills
FROM tmp_data_dm.coe_jrr_sub_bills
GROUP BY 1,2,3,4,5,6

tmp_data_dm.coe_jrr_olaf_price
    subscription_id
    year_month
    full_price_this_month
    full_price
    full_price_last_month_raw
    full_price_this_month
    full_price_next_month_raw
    full_price_last_month
    full_price_next_month

SELECT
   year_month
  ,SUM(full_price) AS full_price
  ,COUNT(*) AS subs
FROM tmp_data_dm.coe_jrr_olaf_price
GROUP BY 1
ORDER BY 1

SELECT
   bls.year_month
  ,bls.mrr_method
  ,bls.product_type
  ,bls.has_ads
  ,bls.has_payment
  ,bls.sub_continues_past_month
  ,SUM(bls.mrr) AS mrr
  ,SUM(bls.revenue) AS revenue
  ,COUNT(*) AS bills
  ,SUM(CASE WHEN prc.subscription_id IS NOT NULL THEN 1 ELSE 0 END) AS prices_found
  ,SUM(IFNULL(prc.full_price, 0)) AS full_price
FROM tmp_data_dm.coe_jrr_sub_bills bls
  LEFT OUTER JOIN tmp_data_dm.coe_jrr_olaf_price prc
          ON bls.year_month = prc.year_month
         AND bls.subscription_id = prc.subscription_id
WHERE bls.year_month BETWEEN 201301 AND 201408
GROUP BY 1,2,3,4,5,6

OK in older months, has_payment = 'N' and so does sub_continues_past_month.
Naw, has_payment is fine.
OK the problem is that for the majority, sub_continues_past_month = 'N'.
Let''s look at 201402.

SELECT
   dt.year_month
  ,dt.month_begin_date AS year_month_begin_date
  ,dt.month_end_date AS year_month_end_date
  ,olaf.order_line_cancelled_date
  ,TO_DATE(sub.expire_datetime) AS expire_date
  ,COUNT(*) AS num_rows
FROM         dm.order_line_accumulation_fact olaf
  INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
  LEFT OUTER JOIN dm.subscription_dimension sub
          ON olaf.product_subscription_id = sub.subscription_id
WHERE olaf.order_line_begin_date BETWEEN '2013-01-01' AND '2016-07-16'
GROUP BY 1,2,3,4,5
expire_date can be a date or 1/1/1900 or NULL.
order_line_cancelled_date can be a date or -1.
The dates in mrr_subscription are well-behaved.

        ,GREATEST(CASE WHEN olaf.order_line_cancelled_date = -1 THEN NULL ELSE olaf.order_line_cancelled_date END
                 ,mrr.cancelled_date
                 ,mrr.expired_date) AS max_expired_date

        ,GREATEST(CASE WHEN olaf.order_line_cancelled_date = -1 THEN NULL ELSE olaf.order_line_cancelled_date END
                 ,CASE WHEN sub.expire_datetime = '1900-01-01'  THEN NULL ELSE sub.expire_datetime END) AS max_expired_date

        ,CASE WHEN olaf.order_line_cancelled_date = -1 THEN NULL ELSE olaf.order_line_cancelled_date END AS max_expired_date


        ,CASE WHEN olf.order_line_cancelled_date = "-1" THEN NULL ELSE olf.order_line_cancelled_date END AS nice_cancelled_date

SELECT olf.*
,CASE WHEN olf.yearmonth = 201607 then 1 else 0 end as test_me
-- ,CASE WHEN olf.order_line_cancelled_date = -1 THEN CAST(NULL AS DATE) ELSE olf.order_line_cancelled_date END AS nice_cancelled_date
,CASE WHEN olf.order_line_cancelled_date = -1 THEN 1 ELSE 0 END AS nice_cancelled_date
FROM dm.order_line_accumulation_fact olf
WHERE olf.order_line_begin_date = '2016-07-01'

      FROM         (SELECT *
                      ,CASE WHEN order_line_cancelled_date = -1 THEN NULL ELSE order_line_cancelled_date END AS nice_cancelled_date
                    FROM dm.order_line_accumulation_fact) olaf

OK the initial MRR balues are way low in my data - maybe I am putting
a restriction that must be active after EoM in the wrong place?
Oh!  Revenue is also too low in the first month.  Which implies it is
not about the proration.
Customer count is still good.

Crap.  Seems like maybe subscription IDs were not as constant from
month to month as I would like.  Many subscription_ids are only
showing up for a single month.
In fact, for cust 16422 it looks like that happens up to the date when
billing system changed.
OK if that is related, how does it make the first month low but other
months ok?

This returns no records, and that doesn''t smell right.
SELECT olaf.*, dt.year_month, mrr.*
FROM         dm.order_line_accumulation_fact olaf
  INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
  LEFT OUTER JOIN tmp_data_dm.coe_jrr_olaf_price mrr
          ON olaf.product_subscription_id = mrr.subscription_id
         AND dt.year_month = mrr.year_month
-- WHERE olaf.order_line_begin_date = '2014-02-01'
WHERE olaf.order_line_begin_date BETWEEN '2014-02-02' AND '2014-02-28'
and olaf.order_line_net_price_amount_usd <> mrr.full_price
Oh wait first of month won''t ever be diff.

sub_id 7593682 is a case where this month is way more than next, but
we take the next month amount.
The difference accounts for about 15K in Feb 2014.

OK it looks like it is the difference between looking at next month''s
mrr at the sub level or the customer level, because many of the subs
do not stay from one month to the next (that far back in history).

Also looking into the off by 1 penny ones.
Yeah think it is the same deal.

  ,CASE WHEN year_month > 201407 THEN full_price_this_month
        -- This case means we are likely in the prorate month, and 
        -- <= 201407 we do not have enough info to prorate so grab
        -- next month''s price.
        WHEN full_price_last_month = 0 AND full_price_next_month > 0 THEN full_price_next_month
        ELSE full_price_this_month END AS full_price

      SELECT
         olaf.*
        ,'Order Line' AS mrr_method   
        ,dt.year_month
        ,dt.month_begin_date AS year_month_begin_date
        ,dt.month_end_date AS year_month_end_date
        -- ,100 AS full_price
        -- Unprorate if we can, but this will not do anything for older orders.
        ,CASE WHEN olaf.order_line_payment_date = '-1' 
                THEN 0
              WHEN DAY(olaf.order_line_begin_date) = 1 
                THEN olaf.order_line_net_price_amount_usd
              WHEN DAY(olaf.order_line_begin_date) = mth.day_in_month_count 
                THEN olaf.order_line_net_price_amount_usd * mth.day_in_month_count
                ELSE olaf.order_line_net_price_amount_usd * mth.day_in_month_count
                     /
                     (mth.day_in_month_count - DAY(olaf.order_line_begin_date))
         END AS full_price      
        -- ,olaf.order_line_cancelled_date AS max_expired_date
        ,CASE WHEN olaf.order_line_cancelled_date = '-1' THEN NULL ELSE olaf.order_line_cancelled_date END AS max_expired_date
      FROM         dm.order_line_accumulation_fact olaf
        INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
        INNER JOIN dm.month_dim mth ON dt.year_month = mth.year_month
      WHERE olaf.order_line_begin_date BETWEEN '2013-01-01' AND '2014-08-31'

----
-- One row per (customer, billed month)
-- This is before the chain logic.
DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_active_months;
CREATE TABLE tmp_data_dm.coe_jrr_cust_active_months AS
SELECT *
FROM
  (
  SELECT
     bls.customer_id
    ,bls.year_month
    ,bls.year_month_begin_date
    ,bls.mrr_method
    ,MAX(bls.has_ads) AS                 has_ads
    ,MAX(bls.has_payment) AS             has_payment
    ,MAX(bls.max_bill_date_in_month) AS  max_bill_date_in_month
    -- Note: we have things that look like ads prior to 2015-10 but
    -- product_line_id = -1.  I am going to call that MRR, but leave
    -- has-ads = 'N' because legacy code excluded them.
    ,SUM(CASE WHEN bls.product_type IN ('Display', 'Sponsored Listing') THEN bls.revenue ELSE 0 END) AS revenue_current_advertisement
    ,SUM(CASE WHEN bls.product_type = 'Pro'                             THEN bls.revenue ELSE 0 END) AS revenue_current_avvopro
    ,SUM(CASE WHEN bls.product_type = 'Ignite'                          THEN bls.revenue ELSE 0 END) AS revenue_current_ignite
    ,SUM(CASE WHEN bls.product_type = 'Website'                         THEN bls.revenue ELSE 0 END) AS revenue_current_website
    ,SUM(CASE WHEN bls.product_type = 'Ad Placement'                    THEN bls.revenue ELSE 0 END) AS revenue_current_adplacement
    ,SUM(CASE WHEN bls.product_type = 'Misc'                            THEN bls.revenue ELSE 0 END) AS revenue_current_misc
    ,SUM(CASE WHEN bls.product_type = 'Other Subscription'              THEN bls.revenue ELSE 0 END) AS revenue_current_other_sub
    ,SUM(CASE WHEN bls.product_type = 'Other'                           THEN bls.revenue ELSE 0 END) AS revenue_current_other
    ,SUM(CASE WHEN bls.product_type <> 'Other'                          THEN bls.revenue ELSE 0 END) AS revenue_current_total
    ,SUM(CASE WHEN bls.product_type IN ('Display', 'Sponsored Listing') THEN bls.mrr     ELSE 0 END) AS mrr_current_advertisement
    ,SUM(CASE WHEN bls.product_type = 'Pro'                             THEN bls.mrr     ELSE 0 END) AS mrr_current_avvopro
    ,SUM(CASE WHEN bls.product_type = 'Ignite'                          THEN bls.mrr     ELSE 0 END) AS mrr_current_ignite
    ,SUM(CASE WHEN bls.product_type = 'Website'                         THEN bls.mrr     ELSE 0 END) AS mrr_current_website
    ,SUM(CASE WHEN bls.product_type = 'Ad Placement'                    THEN bls.mrr     ELSE 0 END) AS mrr_current_adplacement
    ,SUM(CASE WHEN bls.product_type = 'Other Subscription'              THEN bls.mrr     ELSE 0 END) AS mrr_current_other_sub
    ,SUM(CASE WHEN bls.product_type <> 'Other'                          THEN bls.mrr     ELSE 0 END) AS mrr_current_total
  FROM tmp_data_dm.coe_jrr_sub_bills bls
  GROUP BY 1,2,3,4
  ) mth
-- WHERE mth.has_ads = 'Y' OR mth.mrr_current_total > 0  -- LOOK return to this
WHERE mth.has_ads = 'Y'

----
OK so I have confirmed that in old data, many of the subscriptions
are only there for 1 month and then for the next month it''s a 
whole new set of subscriptons, for the same stuff.  That is why
my starting MRR is low, because when I see that this is the first
month and I try to prorate, I do not see a next month price for
the same sub, so I assume the current month amount, which is
prorated and therefore too low.
So let''s tackle doing the look back / forward to fix MRR at a
customer level if needed for old data.
Pretty sure all I need to look at for prior month is total MRR;
then based on that I go get the needed values for all fields in
the next_month fields.
Could probably go on chain_id = 1.
For next month values, maybe do not need the revenue ones, just the
MRR ones.  Correct.
    mrr_next_advertisement
    mrr_next_avvopro
    mrr_next_ignite
    mrr_next_website
    mrr_next_adplacement
    mrr_next_other_sub
    mrr_next_total

Stats:
Issue the COMPUTE STATS table_name for a nonpartitioned table, 
or (in Impala 2.1.0 and higher) COMPUTE INCREMENTAL STATS table_name 
for a partitioned table, to collect the initial statistics at both 
the table and column levels, and to keep the statistics up to date 
after any substantial INSERT or LOAD DATA operations.
CREATE [EXTERNAL] TABLE [IF NOT EXISTS] [db_name.]table_name
  LIKE PARQUET 'hdfs_path_of_parquet_file'
  [COMMENT 'table_comment']
  [PARTITIONED BY (col_name data_type [COMMENT 'col_comment'], ...)]

----------------------------------------------------------------------
----------------------------------------------------------------------

-- -- Note: nested queries with complicated window functions started
-- -- arbitrarily failing so I split this into chunks.

-- DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_chains_raw1;
-- CREATE TABLE tmp_data_dm.coe_jrr_cust_chains_raw1
-- (
--    customer_id                    INT
--   ,start_month                    INT
--   ,start_month_begin_date         STRING
--   ,tenure_month                   BIGINT
--   -- ,year_month                     INT
--   ,year_month_begin_date          STRING
--   ,has_ads                        STRING
--   ,has_payment                    STRING
--   ,mrr_method                     STRING
--   ,max_bill_date_in_month         STRING
--   ,revenue_current_advertisement  DECIMAL(38,2)
--   ,revenue_current_avvopro        DECIMAL(38,2)
--   ,revenue_current_ignite         DECIMAL(38,2)
--   ,revenue_current_website        DECIMAL(38,2)
--   ,revenue_current_adplacement    DECIMAL(38,2)
--   ,revenue_current_misc           DECIMAL(38,2)
--   ,revenue_current_other_sub      DECIMAL(38,2)
--   ,revenue_current_other          DECIMAL(38,2)
--   ,revenue_current_total          DECIMAL(38,2)
--   ,mrr_current_advertisement      DOUBLE
--   ,mrr_current_avvopro            DOUBLE
--   ,mrr_current_ignite             DOUBLE
--   ,mrr_current_website            DOUBLE
--   ,mrr_current_adplacement        DOUBLE
--   ,mrr_current_other_sub          DOUBLE
--   ,mrr_current_total              DOUBLE
-- )
-- PARTITIONED BY (year_month INT)
-- STORED AS PARQUET;
-- WITH table_src AS
-- (
-- SELECT
--    nc.customer_id
--   ,nc.start_month
--   ,nc.start_month_begin_date
--   ,(FLOOR(future.year_month/100)-FLOOR(nc.start_month/100)) * 12 +
--          (future.year_month%100-       nc.start_month%100) AS tenure_month
--   ,future.year_month
--   ,future.year_month_begin_date
--   ,future.has_ads
--   ,future.has_payment
--   ,future.mrr_method
--   ,future.max_bill_date_in_month
--   ,future.revenue_current_advertisement
--   ,future.revenue_current_avvopro
--   ,future.revenue_current_ignite
--   ,future.revenue_current_website
--   ,future.revenue_current_adplacement
--   ,future.revenue_current_misc
--   ,future.revenue_current_other_sub
--   ,future.revenue_current_other
--   ,future.revenue_current_total
--   ,future.mrr_current_advertisement
--   ,future.mrr_current_avvopro
--   ,future.mrr_current_ignite
--   ,future.mrr_current_website
--   ,future.mrr_current_adplacement
--   ,future.mrr_current_other_sub
--   ,future.mrr_current_total
-- FROM        tmp_data_dm.coe_jrr_cust_lifetime_start nc
--   LEFT JOIN tmp_data_dm.coe_jrr_cust_active_months future 
--          ON nc.customer_id = future.customer_id 
--         AND nc.start_month <= future.year_month 
--         AND future.year_month < 201610
-- )
-- INSERT OVERWRITE TABLE tmp_data_dm.coe_jrr_cust_chains_raw1 PARTITION(year_month)
-- SELECT
--    customer_id
--   ,start_month
--   ,start_month_begin_date
--   ,tenure_month
--   ,year_month_begin_date
--   ,has_ads
--   ,has_payment
--   ,mrr_method
--   ,max_bill_date_in_month
--   ,revenue_current_advertisement
--   ,revenue_current_avvopro
--   ,revenue_current_ignite
--   ,revenue_current_website
--   ,revenue_current_adplacement
--   ,revenue_current_misc
--   ,revenue_current_other_sub
--   ,revenue_current_other
--   ,revenue_current_total
--   ,mrr_current_advertisement
--   ,mrr_current_avvopro
--   ,mrr_current_ignite
--   ,mrr_current_website
--   ,mrr_current_adplacement
--   ,mrr_current_other_sub
--   ,mrr_current_total
--   ,year_month
-- FROM table_src;
-- COMPUTE INCREMENTAL STATS tmp_data_dm.coe_jrr_cust_chains_raw1;


-- DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_chains_raw2;
-- CREATE TABLE tmp_data_dm.coe_jrr_cust_chains_raw2
-- (
--    customer_id                    INT
--   ,start_month                    INT
--   ,start_month_begin_date         STRING
--   ,tenure_month                   BIGINT
--   ,year_month_begin_date          STRING
--   ,has_ads                        STRING
--   ,has_payment                    STRING
--   ,mrr_method                     STRING
--   ,max_bill_date_in_month         STRING
--   ,revenue_current_advertisement  DECIMAL(38,2)
--   ,revenue_current_avvopro        DECIMAL(38,2)
--   ,revenue_current_ignite         DECIMAL(38,2)
--   ,revenue_current_website        DECIMAL(38,2)
--   ,revenue_current_adplacement    DECIMAL(38,2)
--   ,revenue_current_misc           DECIMAL(38,2)
--   ,revenue_current_other_sub      DECIMAL(38,2)
--   ,revenue_current_other          DECIMAL(38,2)
--   ,revenue_current_total          DECIMAL(38,2)
--   ,mrr_current_advertisement      DOUBLE
--   ,mrr_current_avvopro            DOUBLE
--   ,mrr_current_ignite             DOUBLE
--   ,mrr_current_website            DOUBLE
--   ,mrr_current_adplacement        DOUBLE
--   ,mrr_current_other_sub          DOUBLE
--   ,mrr_current_total              DOUBLE
--   -- ,year_month                     INT
--   ,chain_id_raw                     BIGINT
--   ,rnk                              BIGINT
--   ,active_months_to_date            BIGINT
--   ,tenure_month_prior               BIGINT
--   ,has_ads_prior                    STRING
--   ,has_payment_prior                STRING
--   ,customer_prev_billed_date        STRING
--   ,revenue_prior_advertisement      DECIMAL(38,2)
--   ,revenue_prior_avvopro            DECIMAL(38,2)
--   ,revenue_prior_ignite             DECIMAL(38,2)
--   ,revenue_prior_website            DECIMAL(38,2)
--   ,revenue_prior_adplacement        DECIMAL(38,2)
--   ,revenue_prior_misc               DECIMAL(38,2)
--   ,revenue_prior_other_sub          DECIMAL(38,2)
--   ,revenue_prior_other              DECIMAL(38,2)
--   ,revenue_prior_total              DECIMAL(38,2)
--   ,mrr_prior_advertisement          DOUBLE
--   ,mrr_prior_avvopro                DOUBLE
--   ,mrr_prior_ignite                 DOUBLE
--   ,mrr_prior_website                DOUBLE
--   ,mrr_prior_adplacement            DOUBLE
--   ,mrr_prior_other_sub              DOUBLE
--   ,mrr_prior_total                  DOUBLE
--   ,mrr_next_advertisement           DOUBLE
--   ,mrr_next_avvopro                 DOUBLE
--   ,mrr_next_ignite                  DOUBLE
--   ,mrr_next_website                 DOUBLE
--   ,mrr_next_adplacement             DOUBLE
--   ,mrr_next_other_sub               DOUBLE
--   ,mrr_next_total                   DOUBLE
-- )
-- PARTITIONED BY (year_month INT)
-- STORED AS PARQUET;
-- WITH table_src AS
-- (
-- SELECT
--    mth.*
--   ,DENSE_RANK()    OVER(PARTITION BY mth.customer_id
--                             ORDER BY mth.tenure_month) - mth.tenure_month AS chain_id_raw
--   ,DENSE_RANK()    OVER(PARTITION BY mth.customer_id
--                             ORDER BY mth.tenure_month) AS rnk
--   ,ROW_NUMBER()    OVER(PARTITION BY mth.customer_id
--                             ORDER BY mth.tenure_month) AS active_months_to_date
--   ,LAG(mth.tenure_month)                  OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS tenure_month_prior
--   ,LAG(mth.has_ads)                       OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS has_ads_prior
--   ,LAG(mth.has_payment)                   OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS has_payment_prior
--   ,LAG(mth.max_bill_date_in_month)        OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS customer_prev_billed_date
--   ,LAG(mth.revenue_current_advertisement) OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS revenue_prior_advertisement
--   ,LAG(mth.revenue_current_avvopro)       OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS revenue_prior_avvopro
--   ,LAG(mth.revenue_current_ignite)        OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS revenue_prior_ignite
--   ,LAG(mth.revenue_current_website)       OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS revenue_prior_website
--   ,LAG(mth.revenue_current_adplacement)   OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS revenue_prior_adplacement
--   ,LAG(mth.revenue_current_misc)          OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS revenue_prior_misc
--   ,LAG(mth.revenue_current_other_sub)     OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS revenue_prior_other_sub
--   ,LAG(mth.revenue_current_other)         OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS revenue_prior_other
--   ,LAG(mth.revenue_current_total)         OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS revenue_prior_total
--   ,LAG(mth.mrr_current_advertisement)     OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS mrr_prior_advertisement
--   ,LAG(mth.mrr_current_avvopro)           OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS mrr_prior_avvopro
--   ,LAG(mth.mrr_current_ignite)            OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS mrr_prior_ignite
--   ,LAG(mth.mrr_current_website)           OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS mrr_prior_website
--   ,LAG(mth.mrr_current_adplacement)       OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS mrr_prior_adplacement
--   ,LAG(mth.mrr_current_other_sub)         OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS mrr_prior_other_sub
--   ,LAG(mth.mrr_current_total)             OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS mrr_prior_total
--   ,LEAD(mth.mrr_current_advertisement)    OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS mrr_next_advertisement
--   ,LEAD(mth.mrr_current_avvopro)          OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS mrr_next_avvopro
--   ,LEAD(mth.mrr_current_ignite)           OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS mrr_next_ignite
--   ,LEAD(mth.mrr_current_website)          OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS mrr_next_website
--   ,LEAD(mth.mrr_current_adplacement)      OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS mrr_next_adplacement
--   ,LEAD(mth.mrr_current_other_sub)        OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS mrr_next_other_sub
--   ,LEAD(mth.mrr_current_total)            OVER(PARTITION BY mth.customer_id
--                                                    ORDER BY mth.tenure_month) AS mrr_next_total
-- FROM tmp_data_dm.coe_jrr_cust_chains_raw1 mth
-- )
-- INSERT OVERWRITE TABLE tmp_data_dm.coe_jrr_cust_chains_raw2 PARTITION(year_month)
-- SELECT
--    customer_id
--   ,start_month
--   ,start_month_begin_date
--   ,tenure_month
--   ,year_month_begin_date
--   ,has_ads
--   ,has_payment
--   ,mrr_method
--   ,max_bill_date_in_month
--   ,revenue_current_advertisement
--   ,revenue_current_avvopro
--   ,revenue_current_ignite
--   ,revenue_current_website
--   ,revenue_current_adplacement
--   ,revenue_current_misc
--   ,revenue_current_other_sub
--   ,revenue_current_other
--   ,revenue_current_total
--   ,mrr_current_advertisement
--   ,mrr_current_avvopro
--   ,mrr_current_ignite
--   ,mrr_current_website
--   ,mrr_current_adplacement
--   ,mrr_current_other_sub
--   ,mrr_current_total
--   ,chain_id_raw
--   ,rnk
--   ,active_months_to_date
--   ,tenure_month_prior
--   ,has_ads_prior
--   ,has_payment_prior
--   ,customer_prev_billed_date
--   ,revenue_prior_advertisement
--   ,revenue_prior_avvopro
--   ,revenue_prior_ignite
--   ,revenue_prior_website
--   ,revenue_prior_adplacement
--   ,revenue_prior_misc
--   ,revenue_prior_other_sub
--   ,revenue_prior_other
--   ,revenue_prior_total
--   ,mrr_prior_advertisement
--   ,mrr_prior_avvopro
--   ,mrr_prior_ignite
--   ,mrr_prior_website
--   ,mrr_prior_adplacement
--   ,mrr_prior_other_sub
--   ,mrr_prior_total
--   ,mrr_next_advertisement
--   ,mrr_next_avvopro
--   ,mrr_next_ignite
--   ,mrr_next_website
--   ,mrr_next_adplacement
--   ,mrr_next_other_sub
--   ,mrr_next_total
--   ,year_month
-- FROM table_src;
-- COMPUTE INCREMENTAL STATS tmp_data_dm.coe_jrr_cust_chains_raw2;


-- DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_chains;
-- CREATE TABLE tmp_data_dm.coe_jrr_cust_chains
-- (
--    customer_id                      INT
--   ,year_month                       INT
--   ,year_month_begin_date            STRING
--   ,chain_id_raw                     BIGINT
--   ,chain_number                     BIGINT
--   ,tenure_month_chain            BIGINT
--   ,tenure_month_lifetime         BIGINT
--   ,active_months_to_date            BIGINT
--   -- ,start_month_chain                INT
--   ,start_month_begin_date_chain     STRING
--   ,start_month_lifetime             INT
--   ,start_month_begin_date_lifetime  STRING
--   ,has_ads                          STRING
--   ,has_payment                      STRING
--   ,mrr_method                       STRING
--   ,max_bill_date_in_month           STRING
--   ,revenue_current_advertisement    DECIMAL(38,2)
--   ,revenue_current_avvopro          DECIMAL(38,2)
--   ,revenue_current_ignite           DECIMAL(38,2)
--   ,revenue_current_website          DECIMAL(38,2)
--   ,revenue_current_adplacement      DECIMAL(38,2)
--   ,revenue_current_misc             DECIMAL(38,2)
--   ,revenue_current_other_sub        DECIMAL(38,2)
--   ,revenue_current_other            DECIMAL(38,2)
--   ,revenue_current_total            DECIMAL(38,2)
--   ,mrr_current_advertisement        DOUBLE
--   ,mrr_current_avvopro              DOUBLE
--   ,mrr_current_ignite               DOUBLE
--   ,mrr_current_website              DOUBLE
--   ,mrr_current_adplacement          DOUBLE
--   ,mrr_current_other_sub            DOUBLE
--   ,mrr_current_total                DOUBLE
--   ,tenure_month_prev                BIGINT
--   ,has_ads_prior                    STRING
--   ,has_payment_prior                STRING
--   ,revenue_prior_advertisement      DECIMAL(38,2)
--   ,revenue_prior_avvopro            DECIMAL(38,2)
--   ,revenue_prior_ignite             DECIMAL(38,2)
--   ,revenue_prior_website            DECIMAL(38,2)
--   ,revenue_prior_adplacement        DECIMAL(38,2)
--   ,revenue_prior_misc               DECIMAL(38,2)
--   ,revenue_prior_other_sub          DECIMAL(38,2)
--   ,revenue_prior_other              DECIMAL(38,2)
--   ,revenue_prior_total              DECIMAL(38,2)
--   ,mrr_prior_advertisement          DOUBLE
--   ,mrr_prior_avvopro                DOUBLE
--   ,mrr_prior_ignite                 DOUBLE
--   ,mrr_prior_website                DOUBLE
--   ,mrr_prior_adplacement            DOUBLE
--   ,mrr_prior_other_sub              DOUBLE
--   ,mrr_prior_total                  DOUBLE
-- )
-- PARTITIONED BY (start_month_chain INT)
-- STORED AS PARQUET;
-- WITH table_src AS
-- (
-- SELECT
--    chn.customer_id
--   ,chn.year_month
--   ,chn.year_month_begin_date
--   ,chn.chain_id_raw  -- LOOK lose this later.
--   ,DENSE_RANK() OVER(PARTITION BY chn.customer_id
--                          ORDER BY chn.chain_id_raw DESC) AS chain_number
--   ,ROW_NUMBER()                   OVER(PARTITION BY chn.customer_id, chn.chain_id_raw
--                                         ORDER BY chn.tenure_month) - 1 AS tenure_month_chain
--   ,chn.tenure_month AS tenure_month_lifetime
--   ,chn.active_months_to_date
--   ,MIN(chn.year_month)            OVER(PARTITION BY chn.customer_id, chn.chain_id_raw
--                                            ORDER BY chn.tenure_month) AS start_month_chain
--   ,MIN(chn.year_month_begin_date) OVER(PARTITION BY chn.customer_id, chn.chain_id_raw
--                                            ORDER BY chn.tenure_month) AS start_month_begin_date_chain
--   ,chn.start_month AS start_month_lifetime
--   ,chn.start_month_begin_date AS start_month_begin_date_lifetime
--   ,chn.has_ads
--   ,chn.has_payment
--   ,chn.mrr_method
--   ,chn.max_bill_date_in_month
--   ,chn.revenue_current_advertisement
--   ,chn.revenue_current_avvopro
--   ,chn.revenue_current_ignite
--   ,chn.revenue_current_website
--   ,chn.revenue_current_adplacement
--   ,chn.revenue_current_misc
--   ,chn.revenue_current_other_sub
--   ,chn.revenue_current_other
--   ,chn.revenue_current_total
--   -- Prior to 201408, we could not prorate because begin date is always
--   -- first of the month.  So if it is the first month in a chain,
--   -- and we see non-zero revenue for the customer next month, take
--   -- all of next month's values for this month's MRR.
--   ,CASE WHEN chn.chain_id_raw = 1 AND chn.year_month <= 201407 AND IFNULL(chn.mrr_next_total, 0) > 0
--         THEN chn.mrr_next_advertisement
--         ELSE chn.mrr_current_advertisement END AS  mrr_current_advertisement
--   ,CASE WHEN chn.chain_id_raw = 1 AND chn.year_month <= 201407 AND IFNULL(chn.mrr_next_total, 0) > 0
--         THEN chn.mrr_next_avvopro
--         ELSE chn.mrr_current_avvopro END AS        mrr_current_avvopro
--   ,CASE WHEN chn.chain_id_raw = 1 AND chn.year_month <= 201407 AND IFNULL(chn.mrr_next_total, 0) > 0
--         THEN chn.mrr_next_ignite
--         ELSE chn.mrr_current_ignite END AS         mrr_current_ignite
--   ,CASE WHEN chn.chain_id_raw = 1 AND chn.year_month <= 201407 AND IFNULL(chn.mrr_next_total, 0) > 0
--         THEN chn.mrr_next_website
--         ELSE chn.mrr_current_website END AS        mrr_current_website
--   ,CASE WHEN chn.chain_id_raw = 1 AND chn.year_month <= 201407 AND IFNULL(chn.mrr_next_total, 0) > 0
--         THEN chn.mrr_next_adplacement
--         ELSE chn.mrr_current_adplacement END AS    mrr_current_adplacement
--   ,CASE WHEN chn.chain_id_raw = 1 AND chn.year_month <= 201407 AND IFNULL(chn.mrr_next_total, 0) > 0
--         THEN chn.mrr_next_other_sub
--         ELSE chn.mrr_current_other_sub END AS      mrr_current_other_sub
--   ,CASE WHEN chn.chain_id_raw = 1 AND chn.year_month <= 201407 AND IFNULL(chn.mrr_next_total, 0) > 0
--         THEN chn.mrr_next_total
--         ELSE chn.mrr_current_total END AS          mrr_current_total
--   -- probably way-too-subtle naming thing: I try to use prior as always referring to the
--   -- prior calendar month, while prev means the most recent one I see even if it's
--   -- a while ago.
--   ,chn.tenure_month_prior AS                                                          tenure_month_prev
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 'N' ELSE chn.has_ads_prior END AS              has_ads_prior
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 'N' ELSE chn.has_payment_prior END AS          has_payment_prior
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.revenue_prior_advertisement END AS  revenue_prior_advertisement
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.revenue_prior_avvopro END AS        revenue_prior_avvopro
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.revenue_prior_ignite END AS         revenue_prior_ignite
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.revenue_prior_website END AS        revenue_prior_website
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.revenue_prior_adplacement END AS    revenue_prior_adplacement
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.revenue_prior_misc END AS           revenue_prior_misc
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.revenue_prior_other_sub END AS      revenue_prior_other_sub
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.revenue_prior_other END AS          revenue_prior_other
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.revenue_prior_total END AS          revenue_prior_total
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.mrr_prior_advertisement END AS      mrr_prior_advertisement
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.mrr_prior_avvopro END AS            mrr_prior_avvopro
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.mrr_prior_ignite END AS             mrr_prior_ignite
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.mrr_prior_website END AS            mrr_prior_website
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.mrr_prior_adplacement END AS        mrr_prior_adplacement
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.mrr_prior_other_sub END AS          mrr_prior_other_sub
--   ,CASE WHEN chn.chain_id_raw = 1 THEN 0 ELSE chn.mrr_prior_total END AS              mrr_prior_total
-- FROM tmp_data_dm.coe_jrr_cust_chains_raw2 chn
-- )
-- INSERT OVERWRITE TABLE tmp_data_dm.coe_jrr_cust_chains PARTITION(start_month_chain)
-- SELECT
--    customer_id
--   ,year_month
--   ,year_month_begin_date
--   ,chain_id_raw
--   ,chain_number
--   ,tenure_month_chain
--   ,tenure_month_lifetime
--   ,active_months_to_date
--   ,start_month_begin_date_chain
--   ,start_month_lifetime
--   ,start_month_begin_date_lifetime
--   ,has_ads
--   ,has_payment
--   ,mrr_method
--   ,max_bill_date_in_month
--   ,revenue_current_advertisement
--   ,revenue_current_avvopro
--   ,revenue_current_ignite
--   ,revenue_current_website
--   ,revenue_current_adplacement
--   ,revenue_current_misc
--   ,revenue_current_other_sub
--   ,revenue_current_other
--   ,revenue_current_total
--   ,mrr_current_advertisement
--   ,mrr_current_avvopro
--   ,mrr_current_ignite
--   ,mrr_current_website
--   ,mrr_current_adplacement
--   ,mrr_current_other_sub
--   ,mrr_current_total
--   ,tenure_month_prev
--   ,has_ads_prior
--   ,has_payment_prior
--   ,revenue_prior_advertisement
--   ,revenue_prior_avvopro
--   ,revenue_prior_ignite
--   ,revenue_prior_website
--   ,revenue_prior_adplacement
--   ,revenue_prior_misc
--   ,revenue_prior_other_sub
--   ,revenue_prior_other
--   ,revenue_prior_total
--   ,mrr_prior_advertisement
--   ,mrr_prior_avvopro
--   ,mrr_prior_ignite
--   ,mrr_prior_website
--   ,mrr_prior_adplacement
--   ,mrr_prior_other_sub
--   ,mrr_prior_total
--   ,start_month_chain
-- FROM table_src;
-- COMPUTE INCREMENTAL STATS tmp_data_dm.coe_jrr_cust_chains;

-- -- Clean up temp tables because they are big and their only 
-- -- purpose is to make the queries run.
-- DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_chains_raw1;
-- DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_cust_chains_raw2;

----
OK darned thing runs again.

-- Now:
-- In chain table, I have start_month_begin_date_lifetime and start_month_begin_date.
-- And the chain one.
-- What up w/ that?
-- Well the good news is that they match (except for a few in Oct where
-- the lifetime one is NULL because I include different timeframes.)
-- OK so lose the calculated ones and just rename the main ones to _lifetime.

-- Also, since I moved things around, I need to fix the downstream tables.
-- Do I have to do a DISTINCT in the next step?
-- Maybe chain_id=1 and sequence_in_chain (whatever I called that) = 1.

Interesting.  Customer counts are still dead on.  MRR is kinda all over
the map, with some obvious but not yet understandable patterns.
I do think I got around the first-month-short problem that I had.

customer_id = 723
The prior fields are not working - all 0 although clearly there are prior months.
Prior fields working now.
I wonder if the first 3 months problem is about cancel date vs. expire date.
Maybe I am going on expire date while legacy code uses cancel?
201409 is the first month I use the subscription method for mrr.
I wonder what it would look like if I kept with the order line method
through 201412 and then switched.
OK for customer_id = 2924, I am convinced that I am right for 201409.
ss thinks 150; I think 219.  They switched to 219 in the month, so
from then on, MRR is 219, not the same as revenue in that month.
They added subscription_id = 10069196 on 9/30, so no revenue for it
in that month, but there was the next month.
Same cust, 201605, full price on all their subs in May is 0.
We did get $52 in revenue from them on a sub that was canceled on 5/31.
But full price on that sub is still 0 and it ended by EoM.
Expire date is also 5/31.

For customer_id = 1764:
In July 2014, I think no MRR but ss thinks 100.
In Oct 2014, I think 100 MRR but ss thinks no (whole thing shifted later in mine).
Mine matches sub full price.
They didn''t even have revenue in July, so not sure why ss even thinks 100.
Oh!  Basically they had billing problems for a while, so no revenue.
So ss logic looks at last month, sees 0 revenue, and decides this is a
prorate month so we need to take next month''s revenue as this month''s MRR.
In Oct billing problem again, so ss thinks 0 MRR but I see that they do 
still have a $100 sub.
Then they cancel in Nov.
----

Things to undo:
- check cancel date on sub before I count its MRR. done.
- Go back to the 3 MRR methods. done.

OK doing a run where I use order line method for all time.
Want to look at cohort 201503.
Starting with tenure month 3 (zero-based), my MRR is way under.
(56K out of 302K)
There is also a shelf in calendar 201411 (esp. cohort 201408).
Again, mine way under.
Customer counts are still fine.
Yep.  Gajillion cases cohort 201503 and year_month 201506 where I
think 0 MRR and ss thinks some.  Other cases where I am just lower.
customer_id = 34022 They canceled 6/30.
They did pay that month.
Yep but I consider them no MRR in June.
Legacy code just does not look at cancel date.

Okey let''s move on to calendar 201411 (esp. cohort 201408).
Hrm.  customer_id = 22101 had a couple of subs canceled in that month,
and some that extended.  They had revenue that month.  For the canceled ones.
Oh!  OK.  In my MRR logic, even when I am using order line method,
I only consider this month''s revenue as MRR if the sub extends
beyond EoM.
In this scenario, my sub price method would fare better because I would
see a sub price for the new subs that had 0 revenue.
OK trying a run where I do not require sub to extend beyond month.
Ugh.
OK! that brought it SUPER close.
Last weird one is both cohort and year_month 201602.
I am 11K under ss for MRR.

Hrm.  I should have a sanity-check that says mrr can''t be < 0. done.

So.  In customer''s first month.
It''s like ss code is unprorating wrong.
customer_id = 554 had a misc payment in the month.  irrelevant.
omg 2016 is a leap year so proration was wrong (in ss code).
So unproration was worse the closer customer got to EoM.

----

OK here are some of my diagnostic queries:

-- Check legacy quantities
DROP TABLE tmp_data_dm.coe_temp_ss;
CREATE TABLE tmp_data_dm.coe_temp_ss AS

--     RetainedMRR-LT0
with t1 as
(
  with base as                    
  (                    
    select x.cust_id                  
    --, a.PRODUCT_LN_KEY                   
      , x.year_month as active_month                
      , case when x.year_month between 201301 and 201312                 
       then (x.year_month-201300)                
       when x.year_month between 201401 and 201412                 
       then (x.year_month-201400+12)                 
       when x.year_month between 201501 and 201512                 
       then (x.year_month-201500+24)
       when x.year_month between 201601 and 201612                 
       then (x.year_month-201600+36)
      end as month_number                
    , sum(x.final_price) as final_price                  
    from                  
    (                  
      select xx.customer_id as cust_id                
        --, a.ORDER_NBR              
        --, a.INVC_ID              
        --, a.PRODUCT_LN_KEY               
        --, d.actual_date as purchase_date               
        , xx.year_month              
        , xx.order_line_payment_date as payment_date              
        , xx.order_line_begin_date as begin_use_date              
        --, d2.actual_date as cancel_date              
        --, sum(a.ORDER_LN_PKG_PRICE_AMT_USD) as MSRP              
        --, sum(a.ORDER_LN_PURCH_PRICE_AMT_USD) as purchase_price              
        , case when xx.order_line_payment_date='-1' then 0               
          else (            
              case when day(xx.order_line_begin_date)=1 then sum(xx.order_line_net_price_amount_usd)        
              else (        
                  case when month(xx.order_line_begin_date) in (1,3,5,7,8,10,12)     
                    then   
                    (  
                      case when day(xx.order_line_begin_date)=31 then sum(xx.order_line_net_price_amount_usd)*31
                       else sum(xx.order_line_net_price_amount_usd)*31/(31-day(xx.order_line_begin_date)) end
                    )  
                    when  month(xx.order_line_begin_date)=2  
                    then   
                    (  
                      case when day(xx.order_line_begin_date)=28 then sum(xx.order_line_net_price_amount_usd)*28
                       else sum(xx.order_line_net_price_amount_usd)*28/(28-day(xx.order_line_begin_date)) end
                    )  
                    else   
                    (  
                      case when day(xx.order_line_begin_date)=30 then sum(xx.order_line_net_price_amount_usd)*30
                       else sum(xx.order_line_net_price_amount_usd)*30/(30-day(xx.order_line_begin_date)) end
                    )  
                    end  
                ) end      
            )           
        end as final_price              
      from                 
      (                
        select *               
          -- , cast(yearmonth as int) as year_month            
          ,CAST(from_unixtime(unix_timestamp(CAST(order_line_begin_date AS TIMESTAMP)), 'yyyyMM') AS INT) AS year_month
        from dm.order_line_accumulation_fact               
      ) xx                
      where                 
      --c.cust_id in (100)                
      xx. product_line_id in (2,7)                
      and xx.order_line_begin_date>='2013-01-01'                 
      --and p.cust_id!='-1'                              
      group by 1,2,3,4                
    ) x                  
    group by 1,2,3                  
  )                    

  select y.cust_id                  
    , y.active_month                
    , y.month_number                
    , case when y.active_month<=201407                 
      then (              
          case when y.price_lastmonth=0 then           
          (          
            case when y.price_nextmonth=0 then y.final_price         
            else y.price_nextmonth end         
          )          
           else y.final_price end          
        )            
      else y.final_price end as revenue  ---prorated adjusted to full month price:MRR              
  from                  
  (                  
    select b1.*                
      , coalesce(b2.final_price,0) as price_lastmonth              
      , coalesce(b3.final_price,0) as price_nextmonth              
    from base b1                
    left join                
    base b2 on b1.month_number=b2.month_number+1 and b1.cust_id=b2.cust_id                
    left join base b3 on b1.month_number=b3.month_number-1 and b1.cust_id=b3.cust_id                
  ) y 
),

t2 as                    
(                    
  select a.cust_id                  
    , min(a.month_number) as Start_Month                
    , max(a.month_number) as End_Month                
  from                  
  (                  
    select t1.*                
      , dense_rank() over (partition by t1.cust_id order by t1.active_month) - month_number as gap              
    from t1                
  ) a                  
  group by a.gap, a.cust_id                  
  -- order by min(a.month_number)                  
),                    
                    
t3 as                    
(                    
  select a.*                  
    , b.active_month                
    , b.month_number                
    , b.revenue                
  from                  
  (                  
    select t2.cust_id                
      , case when t2.start_month<=12 then t2.start_month+201300               
        when t2.start_month between 13 and 24 then t2.start_month+201400-12            
        when t2.start_month between 25 and 36 then t2.start_month+201500-24 
        when t2.start_month between 37 and 48 then t2.start_month+201600-36
        end as startmonth            
      , case when t2.end_month<=12 then t2.end_month+201300               
        when t2.end_month between 13 and 24 then t2.end_month+201400-12            
        when t2.end_month between 25 and 36 then t2.end_month+201500-24 
        when t2.end_month between 37 and 48 then t2.end_month+201600-36          
        end as endmonth            
      , t2.start_month              
      , t2.end_month              
    from t2                
  ) a                  
  join                   
  (                  
    select t1.cust_id                
      , t1.active_month              
      , t1.month_number              
      , sum(t1.revenue) as revenue              
    from t1                
    group by 1,2,3                
  ) b on b.cust_id=a.cust_id                   
  where a.startmonth<=b.active_month                  
  and a.endmonth>=b.active_month                  
)           ,       

ms as
(
  select t3.cust_id
    , min(t3.start_month) as min_start_month
  from t3
  group by 1
)

  select t3.cust_id as customer_id
    , t3.startmonth as start_month
    , t3.active_month AS year_month
    , t3.revenue as mrr
  from t3, ms
  where t3.cust_id = ms.cust_id and t3.start_month = ms.min_start_month

----

  with base as                    
  (                    
    select x.cust_id                  
    --, a.PRODUCT_LN_KEY                   
      , x.year_month as active_month                
      , case when x.year_month between 201301 and 201312                 
       then (x.year_month-201300)                
       when x.year_month between 201401 and 201412                 
       then (x.year_month-201400+12)                 
       when x.year_month between 201501 and 201512                 
       then (x.year_month-201500+24)
       when x.year_month between 201601 and 201612                 
       then (x.year_month-201600+36)
      end as month_number                
    , sum(x.final_price) as final_price                  
    from                  
    (                  
      select xx.customer_id as cust_id                
        --, a.ORDER_NBR              
        --, a.INVC_ID              
        --, a.PRODUCT_LN_KEY               
        --, d.actual_date as purchase_date               
        , xx.year_month              
        , xx.order_line_payment_date as payment_date              
        , xx.order_line_begin_date as begin_use_date              
        --, d2.actual_date as cancel_date              
        --, sum(a.ORDER_LN_PKG_PRICE_AMT_USD) as MSRP              
        --, sum(a.ORDER_LN_PURCH_PRICE_AMT_USD) as purchase_price              
        , case when xx.order_line_payment_date='-1' then 0               
          else (            
              case when day(xx.order_line_begin_date)=1 then sum(xx.order_line_net_price_amount_usd)        
              else (        
                  case when month(xx.order_line_begin_date) in (1,3,5,7,8,10,12)     
                    then   
                    (  
                      case when day(xx.order_line_begin_date)=31 then sum(xx.order_line_net_price_amount_usd)*31
                       else sum(xx.order_line_net_price_amount_usd)*31/(31-day(xx.order_line_begin_date)) end
                    )  
                    when  month(xx.order_line_begin_date)=2  
                    then   
                    (  
                      case when day(xx.order_line_begin_date)=28 then sum(xx.order_line_net_price_amount_usd)*28
                       else sum(xx.order_line_net_price_amount_usd)*28/(28-day(xx.order_line_begin_date)) end
                    )  
                    else   
                    (  
                      case when day(xx.order_line_begin_date)=30 then sum(xx.order_line_net_price_amount_usd)*30
                       else sum(xx.order_line_net_price_amount_usd)*30/(30-day(xx.order_line_begin_date)) end
                    )  
                    end  
                ) end      
            )           
        end as final_price              
      from                 
      (                
        select *               
          -- , cast(yearmonth as int) as year_month            
          ,CAST(from_unixtime(unix_timestamp(CAST(order_line_begin_date AS TIMESTAMP)), 'yyyyMM') AS INT) AS year_month
        from dm.order_line_accumulation_fact               
      ) xx                
      where                 
      --c.cust_id in (100)                
      xx. product_line_id in (2,7)                
      and xx.order_line_begin_date>='2013-01-01'                 
      --and p.cust_id!='-1'                              
      group by 1,2,3,4                
    ) x                  
    group by 1,2,3                  
  )                    

  select y.cust_id                  
    , y.active_month             
    , y.month_number 
    ,y.final_price
    ,y.price_nextmonth
    ,y.price_lastmonth               
    , case when y.active_month<=201407                 
      then (              
          case when y.price_lastmonth=0 then           
          (          
            case when y.price_nextmonth=0 then y.final_price         
            else y.price_nextmonth end         
          )          
           else y.final_price end          
        )            
      else y.final_price end as revenue  ---prorated adjusted to full month price:MRR              
  from                  
  (                  
    select b1.*                
      , coalesce(b2.final_price,0) as price_lastmonth              
      , coalesce(b3.final_price,0) as price_nextmonth              
    from base b1                
    left join                
    base b2 on b1.month_number=b2.month_number+1 and b1.cust_id=b2.cust_id                
    left join base b3 on b1.month_number=b3.month_number-1 and b1.cust_id=b3.cust_id                
  ) y 
               
where y.cust_id = 34022
and y.active_month = 201506

----

-- Check new quantities
DROP TABLE tmp_data_dm.coe_temp_new;
CREATE TABLE tmp_data_dm.coe_temp_new AS
    SELECT chn.start_month_chain AS start_month
      , chn.customer_id
      , chn.year_month
      , chn.mrr_current_advertisement as mrr
      , chn.revenue_current_advertisement as revenue
    FROM tmp_data_dm.coe_jrr_cust_chains chn
    WHERE chn.chain_number = 1
      AND chn.tenure_month_chain IS NOT NULL
      AND chn.has_ads = 'Y'


SELECT
 new.customer_id AS  new_customer_id
,new.start_month AS  new_start_month
,new.year_month AS   new_year_month
,new.mrr AS          new_mrr
,new.revenue AS      new_revenue
,ss.customer_id AS   ss_customer_id
,ss.start_month AS   ss_start_month
,ss.year_month AS    ss_year_month
,ss.mrr AS           ss_mrr
,IFNULL(new.customer_id, ss.customer_id) AS  cons_customer_id
,IFNULL(new.start_month, ss.start_month) AS  cons_start_month
,IFNULL(new.year_month, ss.year_month) AS    cons_year_month
,CASE WHEN new.customer_id IS NULL OR ss.customer_id IS NULL THEN 'Customer mismatch' 
      WHEN (new.mrr <> ss.mrr) AND (ss.mrr <> 0) AND ((new.mrr / ss.mrr) - 1 BETWEEN -.01 AND .01) THEN 'MRR close but no cigar' 
      WHEN (new.mrr <> ss.mrr) THEN 'MRR mismatch' 
      ELSE 'OK' END AS is_exception
,1 AS customers
FROM 
                tmp_data_dm.coe_temp_new new
FULL OUTER JOIN tmp_data_dm.coe_temp_ss ss
        ON new.customer_id = ss.customer_id
       AND new.start_month = ss.start_month
       AND new.year_month = ss.year_month
WHERE IFNULL(new.year_month, ss.year_month) <= 201609

  AND 
  IFNULL(new.customer_id, ss.customer_id) IN
  (SELECT * FROM
    (
      SELECT customer_id FROM tmp_data_dm.coe_temp_new
                            WHERE start_month = 201602
     UNION
      SELECT customer_id FROM tmp_data_dm.coe_temp_ss
                            WHERE start_month = 201602
    ) cst
  )
ORDER BY 10,11,12

----

select * from tmp_data_dm.coe_jrr_cust_chains_raw1 where customer_id = 554;
select * from tmp_data_dm.coe_jrr_cust_chains_raw2 where customer_id = 554;
select * from tmp_data_dm.coe_jrr_cust_chains where customer_id = 554;

select *
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
        LEFT OUTER JOIN dm.mrr_subscription mrr
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
      WHERE olaf.order_line_begin_date BETWEEN '2013-01-01' AND '2014-08-31'
  ) uns
WHERE uns.customer_id = 554
ORDER BY uns.order_line_begin_date, uns.order_line_cancelled_date;

SELECT
 ss.start_month AS   ss_start_month
,ss.year_month AS    ss_year_month
,SUM(ss.mrr) AS      ss_mrr
,SUM(1) AS           customers
FROM tmp_data_dm.coe_temp_ss ss
WHERE ss.start_month BETWEEN 201304 AND 201610
  AND ss.year_month  BETWEEN 201304 AND 201610
GROUP BY 1,2
ORDER BY 1,2

----

OK now I want to temporarily keep ignoring cancel date, but put back
the 3 calc methods for MRR so I can quantify the difference of that.
And actually, also do a run with just the 1 calc method but look
at cancel date to quantify that.
6 datasets:
0. Baseline (legacy fixed)
1. Neither improvement, as close as I get to baseline.
2. One mrr method, pay attention to cancel date.
3. Three mrr methods, ignore cancel date.
4. Combined new.
5. All new, include non-ad MRR.
6. Don''t count someone until they have a payment.
7. Ads only, don''t count until payment.
8. Pay attention to cancel date for cust counts too.

Can work conceptually on the categorization.

Oh shit.  When I get MRR from MRR table, have to adjust for the fact
that MRR incorrectly counts some NO ACTIVITY customers?
(theory because sept and oct have much higher MRR w/ that method)
maybe that? maybe something else?
No I think I apply active customer and sub logic on top of that.

ok looking at start_month = 201604, ss against all products, why is
initial customer count less than ss for all products?
customer_id = 9936 was in ss but not run#5.  That''s because
prior to 201604, they had a pro subscription and then canceled.
So in run #5, I am still only pulling first chains, and they don''t 
show up because their first chain happened earlier (and was part of 
the + delta for that start_month).

- Update #5.
wait, why?
oh because I did not want to count misc revenue in total.
eh no diff in the stuff I am looking at.

OK why does 201609 and 201610 (and some of 201608) have such higher
MRR when I go to the 3 MRR methods?
Aw shoot, have to go back to calc method 4.
Maybe not.
Many many cases where I think there is mrr but ss does not.
Oh maybe promos.  First months free.
Yep.  Many of those cases.  Most are first 2 months, but I have seen
at least first 3 months as well (customer_id = 30335).
Now that there are so many of them, need to wrap back to question
of how do we think about customers who are receiving ads and haven''t
paid us yet (even for a couple months).

for now I am not going to put unbilled customers into table.
Could drop them into a second table and union if I want.

OK when we don''t count until payment, most of the remaining mrr
diffs are 50% deals.
So yeah.  Now we have to decide whether we keep the rule of don''t
count until payment.
Nope, lost it.  Just keep a flag.

I have to do a run where I only count if customer_continues_past_month.
There is a whole set of scenarios I need to think about.
What if someone upsells in a month, but sub then gets canceled, but
then they come back the next month.
Current logic:
M1: they count as churned.
M2: old logic would call them returned.
(which is fine, probably best)
Have to think about how chains change this.
Because chains are looking for continuous chains.
Maybe it is OK as long as churn checks customer_continues_past_month?
Returned looks at customer_billed_prior_month=N and that would be Y.
Is there something different that Returned could look at?
Old logic likely wouldn''t handle them right either.
Could check prior customer_continues_past_month?  ugh.
----

-- DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_backfill_customer_mrr ;
-- CREATE TABLE tmp_data_dm.coe_jrr_backfill_customer_mrr
-- (
--    customer_id                      INT
--   -- ,year_month                       INT
--   ,year_month_begin_date            STRING
--   ,chain_number                     BIGINT
--   ,tenure_month_chain               BIGINT
--   ,tenure_month_lifetime            BIGINT
--   ,active_months_to_date            BIGINT
--   ,start_month_chain                INT
--   ,start_month_begin_date_chain     STRING
--   ,start_month_lifetime             INT
--   ,start_month_begin_date_lifetime  STRING
--   ,first_payment_month              INT
--   ,has_ads                          STRING
--   ,has_payment                      STRING
--   ,mrr_method                       STRING
--   ,max_bill_date_in_month           STRING
--   ,revenue_current_advertisement    DECIMAL(38,2)
--   ,revenue_current_avvopro          DECIMAL(38,2)
--   ,revenue_current_ignite           DECIMAL(38,2)
--   ,revenue_current_website          DECIMAL(38,2)
--   ,revenue_current_adplacement      DECIMAL(38,2)
--   ,revenue_current_misc             DECIMAL(38,2)
--   ,revenue_current_other_sub        DECIMAL(38,2)
--   ,revenue_current_other            DECIMAL(38,2)
--   ,revenue_current_total            DECIMAL(38,2)
--   ,mrr_current_advertisement        DOUBLE
--   ,mrr_current_avvopro              DOUBLE
--   ,mrr_current_ignite               DOUBLE
--   ,mrr_current_website              DOUBLE
--   ,mrr_current_adplacement          DOUBLE
--   ,mrr_current_other_sub            DOUBLE
--   ,mrr_current_total                DOUBLE
--   ,tenure_month_prev                BIGINT
--   ,has_ads_prior                    STRING
--   ,has_payment_prior                STRING
--   ,revenue_prior_advertisement      DECIMAL(38,2)
--   ,revenue_prior_avvopro            DECIMAL(38,2)
--   ,revenue_prior_ignite             DECIMAL(38,2)
--   ,revenue_prior_website            DECIMAL(38,2)
--   ,revenue_prior_adplacement        DECIMAL(38,2)
--   ,revenue_prior_misc               DECIMAL(38,2)
--   ,revenue_prior_other_sub          DECIMAL(38,2)
--   ,revenue_prior_other              DECIMAL(38,2)
--   ,revenue_prior_total              DECIMAL(38,2)
--   ,mrr_prior_advertisement          DOUBLE
--   ,mrr_prior_avvopro                DOUBLE
--   ,mrr_prior_ignite                 DOUBLE
--   ,mrr_prior_website                DOUBLE
--   ,mrr_prior_adplacement            DOUBLE
--   ,mrr_prior_other_sub              DOUBLE
--   ,mrr_prior_total                  DOUBLE
--   ,mrr_customer_category            STRING
--   ,mrr_acquired                     DOUBLE
--   ,mrr_penetrated                   DOUBLE
--   ,mrr_downsized                    DOUBLE
--   ,mrr_churned                      DOUBLE
--   ,mrr_retained                     DOUBLE
--   ,mrr_returned                     DOUBLE
--   ,mrr_retained_subset_flat_customers   DOUBLE
--   ,mrr_retained_subset_delta_customers  DOUBLE
--   ,misc_payment_current_month       STRING
--   ,successful_payment_in_month      STRING
--   ,has_had_payment_lifetime         STRING
--   ,mrr_customer_exception           STRING
-- )
-- PARTITIONED BY (year_month INT)
-- STORED AS PARQUET ;
-- WITH table_src AS
-- (
-- SELECT
--    chn.customer_id
--   ,chn.year_month
--   ,chn.year_month_begin_date
--   ,chn.chain_number
--   ,chn.tenure_month_chain
--   ,chn.tenure_month_lifetime
--   ,chn.active_months_to_date
--   ,chn.start_month_chain
--   ,chn.start_month_begin_date_chain
--   ,chn.start_month_lifetime
--   ,chn.start_month_begin_date_lifetime
--   ,srt.first_payment_month
--   ,chn.has_ads
--   ,chn.has_payment
--   ,chn.mrr_method
--   ,chn.max_bill_date_in_month
--   ,chn.revenue_current_advertisement
--   ,chn.revenue_current_avvopro
--   ,chn.revenue_current_ignite
--   ,chn.revenue_current_website
--   ,chn.revenue_current_adplacement
--   ,chn.revenue_current_misc
--   ,chn.revenue_current_other_sub
--   ,chn.revenue_current_other
--   ,chn.revenue_current_total
--   ,chn.mrr_current_advertisement
--   ,chn.mrr_current_avvopro
--   ,chn.mrr_current_ignite
--   ,chn.mrr_current_website
--   ,chn.mrr_current_adplacement
--   ,chn.mrr_current_other_sub
--   ,chn.mrr_current_total
--   ,chn.tenure_month_prev
--   ,chn.has_ads_prior
--   ,chn.has_payment_prior
--   ,chn.revenue_prior_advertisement
--   ,chn.revenue_prior_avvopro
--   ,chn.revenue_prior_ignite
--   ,chn.revenue_prior_website
--   ,chn.revenue_prior_adplacement
--   ,chn.revenue_prior_misc
--   ,chn.revenue_prior_other_sub
--   ,chn.revenue_prior_other
--   ,chn.revenue_prior_total
--   ,chn.mrr_prior_advertisement
--   ,chn.mrr_prior_avvopro
--   ,chn.mrr_prior_ignite
--   ,chn.mrr_prior_website
--   ,chn.mrr_prior_adplacement
--   ,chn.mrr_prior_other_sub
--   ,chn.mrr_prior_total
--   -- Logic changes:
--   -- Old logic does not count acquired if MRR is 0.  New logic does.
--   -- New logic allows downsize to 0 and upsell from 0.

--   ,CASE WHEN chn.customer_active_current_month = 'Y' AND
--              chn.customer_exists_prior_month = 'N' THEN         'ACQUIRED'

--         WHEN chn.customer_active_current_month = 'Y' AND
--              chn.customer_active_prior_month = 'N' AND
--              chn.customer_exists_prior_month = 'Y' THEN         'RETURNED'
             
--         WHEN chn.customer_active_current_month = 'Y' AND
--              chn.customer_active_prior_month = 'Y' AND
--              chn.mrr_current_total > chn.mrr_prior_total THEN   'PENETRATED'

--         WHEN chn.customer_active_current_month = 'Y' AND
--              chn.customer_active_prior_month = 'Y' AND
--              chn.mrr_current_total > 0 AND
--              chn.mrr_current_total  =  chn.mrr_prior_total THEN 'RETAINED'

--         WHEN chn.customer_active_current_month = 'Y' AND
--              chn.customer_active_prior_month = 'Y' AND
--              chn.mrr_current_total < chn.mrr_prior_total THEN   'DOWNSIZED'

--         WHEN chn.customer_active_current_month = 'N' AND
--              chn.customer_active_prior_month   = 'Y' THEN       'CHURNED'

--         WHEN chn.customer_active_current_month = 'Y' AND
--              chn.customer_active_prior_month   = 'Y' AND
--              chn.mrr_current_total = 0 AND
--              chn.mrr_prior_total = 0 THEN                       'NO ACTIVITY'
--         ELSE 'NOT BILLED' END AS                              mrr_customer_category

--   ,CASE WHEN chn.customer_active_current_month = 'Y' AND
--              chn.customer_exists_prior_month = 'N' THEN           chn.mrr_current_total
--               ELSE 0 END AS                                   mrr_acquired
--   ,CASE WHEN chn.customer_active_current_month = 'Y' AND
--              chn.customer_active_prior_month = 'N' AND
--              chn.customer_exists_prior_month = 'Y' THEN           chn.mrr_current_total
--               ELSE 0 END AS                                   mrr_returned
--   ,CASE WHEN chn.customer_active_current_month = 'Y' AND
--              chn.customer_active_prior_month = 'Y' AND
--              chn.mrr_current_total > chn.mrr_prior_total THEN     (chn.mrr_current_total - chn.mrr_prior_total)
--               ELSE 0 END AS                                   mrr_penetrated
--   ,CASE WHEN -- RETAINED
--              chn.customer_active_current_month = 'Y' AND
--              chn.customer_active_prior_month = 'Y' AND
--              chn.mrr_current_total > 0 AND
--              chn.mrr_current_total  =  chn.mrr_prior_total THEN   chn.mrr_current_total
--         WHEN -- DOWNSIZED
--              chn.customer_active_current_month = 'Y' AND
--              chn.customer_active_prior_month = 'Y' AND
--              chn.mrr_current_total < chn.mrr_prior_total THEN     chn.mrr_current_total
--         WHEN -- PENETRATED
--              chn.customer_active_current_month = 'Y' AND
--              chn.customer_active_prior_month = 'Y' AND
--              chn.mrr_current_total > chn.mrr_prior_total THEN     chn.mrr_prior_total
--               ELSE 0 END AS                                   mrr_retained
--   ,CASE WHEN chn.customer_active_current_month = 'Y' AND
--              chn.customer_active_prior_month = 'Y' AND
--              chn.mrr_current_total < chn.mrr_prior_total THEN     (chn.mrr_current_total - chn.mrr_prior_total) 
--               ELSE 0 END AS                                   mrr_downsized
--   ,CASE WHEN chn.customer_active_current_month = 'N' AND
--              chn.customer_active_prior_month   = 'Y' THEN         chn.mrr_prior_total
--               ELSE 0 END AS                                   mrr_churned

--   -- This is the portion of mrr_retained for customers in the RETAINED category.
--   ,CASE WHEN chn.customer_active_current_month = 'Y' AND
--              chn.customer_active_prior_month = 'Y' AND
--              chn.mrr_current_total > 0 AND
--              chn.mrr_current_total  =  chn.mrr_prior_total THEN   chn.mrr_current_total 
--               ELSE 0 END AS                                   mrr_retained_subset_flat_customers
--   -- This is the portion of mrr_retained for customers in the PENETRATED and DOWNSIZED categories.
--   ,CASE WHEN -- DOWNSIZED
--              chn.customer_active_current_month = 'Y' AND
--              chn.customer_active_prior_month = 'Y' AND
--              chn.mrr_current_total < chn.mrr_prior_total THEN     chn.mrr_current_total
--         WHEN -- PENETRATED
--              chn.customer_active_current_month = 'Y' AND
--              chn.customer_active_prior_month = 'Y' AND
--              chn.mrr_current_total > chn.mrr_prior_total THEN     chn.mrr_prior_total
--               ELSE 0 END AS                                   mrr_retained_subset_delta_customers
--   ,chn.misc_payment_current_month
--   ,chn.successful_payment_in_month
--   ,CASE WHEN srt.first_payment_month <= chn.year_month THEN 'Y' ELSE 'N' END AS has_had_payment_lifetime
--   -- ,CASE WHEN something <= chn.year_month THEN 'Y' ELSE 'N' END AS has_had_payment_chain
-- FROM
--              tmp_data_dm.coe_jrr_cust_chains chn
--   INNER JOIN tmp_data_dm.coe_jrr_cust_lifetime_start srt
--           ON chn.customer_id = srt.customer_id
-- )
-- INSERT OVERWRITE TABLE tmp_data_dm.coe_jrr_backfill_customer_mrr PARTITION(year_month)
-- SELECT
--    customer_id
--   ,year_month_begin_date
--   ,chain_number
--   ,tenure_month_chain
--   ,tenure_month_lifetime
--   ,active_months_to_date
--   ,start_month_chain
--   ,start_month_begin_date_chain
--   ,start_month_lifetime
--   ,start_month_begin_date_lifetime
--   ,first_payment_month
--   ,has_ads
--   ,has_payment
--   ,mrr_method
--   ,max_bill_date_in_month
--   ,revenue_current_advertisement
--   ,revenue_current_avvopro
--   ,revenue_current_ignite
--   ,revenue_current_website
--   ,revenue_current_adplacement
--   ,revenue_current_misc
--   ,revenue_current_other_sub
--   ,revenue_current_other
--   ,revenue_current_total
--   ,mrr_current_advertisement
--   ,mrr_current_avvopro
--   ,mrr_current_ignite
--   ,mrr_current_website
--   ,mrr_current_adplacement
--   ,mrr_current_other_sub
--   ,mrr_current_total
--   ,tenure_month_prev
--   ,has_ads_prior
--   ,has_payment_prior
--   ,revenue_prior_advertisement
--   ,revenue_prior_avvopro
--   ,revenue_prior_ignite
--   ,revenue_prior_website
--   ,revenue_prior_adplacement
--   ,revenue_prior_misc
--   ,revenue_prior_other_sub
--   ,revenue_prior_other
--   ,revenue_prior_total
--   ,mrr_prior_advertisement
--   ,mrr_prior_avvopro
--   ,mrr_prior_ignite
--   ,mrr_prior_website
--   ,mrr_prior_adplacement
--   ,mrr_prior_other_sub
--   ,mrr_prior_total
--   ,mrr_customer_category
--   ,mrr_acquired
--   ,mrr_penetrated
--   ,mrr_downsized
--   ,mrr_churned
--   ,mrr_retained
--   ,mrr_returned
--   ,mrr_retained_subset_flat_customers
--   ,mrr_retained_subset_delta_customers
--   ,misc_payment_current_month
--   ,successful_payment_in_month
--   ,has_had_payment_lifetime
--   ,CASE WHEN mrr_customer_category = 'NO ACTIVITY' THEN 'No Activity'
--         WHEN mrr_customer_category = 'PENETRATED' AND
--              mrr_prior_total = 0 THEN                   'Upsold from 0'
--         WHEN mrr_customer_category = 'DOWNSIZED' AND
--              mrr_current_total = 0 THEN                 'Downsized to 0'
--         WHEN mrr_customer_category = 'DOWNSIZED' AND
--              mrr_current_total = 0 THEN                 'Downsized to 0'
--         WHEN successful_payment_in_month = 'N' AND
--              mrr_current_total = 0 AND
--              customer_active_current_month = 'Y' THEN    'No payment, 0 MRR, but active'
--         ELSE 'OK'
--    END AS                                                     mrr_customer_exception
--   ,year_month
-- FROM table_src ;
-- COMPUTE INCREMENTAL STATS tmp_data_dm.coe_jrr_backfill_customer_mrr ;

OK exploring data.
113 rows NOT BILLED and year_month is null.
Ah do a run later where it''s not just ads.

oh crap.  I think my official customer counting method does not
look at EoM status?  It thought that base code did?
wow.  time to go home.
Pretty sure it does, because it excludes CHURNED.  That should cover
it, right?

OK so.  Happy with customer counts.  Happy with my MRR higher in 
Sept-Oct, because of all the promos.
Want to wrap back to something like 201602 and check individual
customers.  I am about 20K lower MRR.
Also when I look at counts, my numbers are lower by about 500 than
scorecard (which is my own query).  Need to investigate that.

Hmmm looks like I looked at 201602 before.
Oh duh that is leap month.
OK, how about 201601?
Vast majority of lower MRR is in final month (where I count them as
0 MRR.)
I am over in many cases too: 50K vs. -70K.
In so many cases i am double the ss MRR, so strongly suspect it was
50% promos (even before promos became official).

Okey let''s look at customer counts vs. current official query.
201608.  I am 515 under.
SELECT
   mrr.yearmonth AS year_month
  ,mrr.mrr_customer_category
  ,SUM(CASE WHEN (mca.customer_id IS NOT NULL) THEN 1 ELSE 0 END) AS advertisers
  ,SUM(CASE WHEN (mrr.mrr_current_total <> 0 OR mca.customer_id IS NOT NULL) THEN 1 ELSE 0 END) AS active_customers
  ,SUM(mrr_current_total) AS mrr_current_total
  ,SUM(1) AS num_rows
FROM dm.mrr_customer_category_all_products mrr
  LEFT OUTER JOIN dm.mrr_customer_classification mca
          ON mrr.customer_id = mca.customer_id
         AND mrr.yearmonth = mca.yearmonth
-- WHERE mrr.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
WHERE mrr.yearmonth = 201608
GROUP BY 1,2

Oh duh.  Need to do a run with all products.
Wow!  When I check just Ad MRR, it''s awesome!

----
-- Check new quantities
DROP TABLE tmp_data_dm.coe_temp_new ;
CREATE TABLE tmp_data_dm.coe_temp_new AS
    SELECT chn.start_month_chain AS start_month
      , chn.customer_id
      , chn.year_month
      , chn.mrr_current_advertisement as mrr
      , chn.revenue_current_advertisement as revenue
    FROM tmp_data_dm.coe_jrr_cust_chains chn
    WHERE chn.chain_number = 1
      AND chn.tenure_month_chain IS NOT NULL
      AND chn.has_ads_during_month = 'Y' ;


SELECT
 new.customer_id AS  new_customer_id
,new.start_month AS  new_start_month
,new.year_month AS   new_year_month
,new.mrr AS          new_mrr
,new.revenue AS      new_revenue
,ss.customer_id AS   ss_customer_id
,ss.start_month AS   ss_start_month
,ss.year_month AS    ss_year_month
,ss.mrr AS           ss_mrr
,IFNULL(new.customer_id, ss.customer_id) AS  cons_customer_id
,IFNULL(new.start_month, ss.start_month) AS  cons_start_month
,IFNULL(new.year_month, ss.year_month) AS    cons_year_month
,CASE WHEN new.customer_id IS NULL OR ss.customer_id IS NULL THEN 'Customer mismatch' 
      WHEN (new.mrr <> ss.mrr) AND (ss.mrr <> 0) AND ((new.mrr / ss.mrr) - 1 BETWEEN -.01 AND .01) THEN 'MRR close but no cigar' 
      WHEN (new.mrr <> ss.mrr) THEN 'MRR mismatch' 
      ELSE 'OK' END AS is_exception
,1 AS customers
FROM 
                tmp_data_dm.coe_temp_new new
FULL OUTER JOIN tmp_data_dm.coe_temp_ss ss
        ON new.customer_id = ss.customer_id
       AND new.start_month = ss.start_month
       AND new.year_month = ss.year_month
WHERE IFNULL(new.year_month, ss.year_month) <= 201610

  AND 
  IFNULL(new.customer_id, ss.customer_id) IN
  (SELECT * FROM
    (
      SELECT customer_id FROM tmp_data_dm.coe_temp_new
                            WHERE start_month = 201601
     UNION
      SELECT customer_id FROM tmp_data_dm.coe_temp_ss
                            WHERE start_month = 201601
    ) cst
  )
ORDER BY 10,11,12

----
-- Compare to official MRR.

DROP TABLE tmp_data_dm.coe_temp_off ;
CREATE TABLE tmp_data_dm.coe_temp_off AS
SELECT
   mrr.customer_id
  ,mrr.yearmonth AS year_month
  ,CASE WHEN (mca.customer_id IS NOT NULL) THEN 'Y' ELSE 'N' END AS has_ads
  ,mrr.mrr_customer_category
  ,mrr.mrr_current_advertisement
  ,mrr.mrr_current_avvopro
  ,mrr.mrr_current_ignite
  ,mrr.mrr_current_website
  ,mrr.mrr_current_adplacement
  ,mrr.mrr_current_total
  ,mrr.mrr_prior_advertisement
  ,mrr.mrr_prior_avvopro
  ,mrr.mrr_prior_ignite
  ,mrr.mrr_prior_website
  ,mrr.mrr_prior_adplacement
  ,mrr.mrr_prior_total
  ,mrr.revenue_current_advertisement
  ,mrr.revenue_current_avvopro
  ,mrr.revenue_current_ignite
  ,mrr.revenue_current_website
  ,mrr.revenue_current_misc
  ,mrr.revenue_current_adplacement
  ,mrr.revenue_current_total
  ,mrr.revenue_prior_advertisement
  ,mrr.revenue_prior_avvopro
  ,mrr.revenue_prior_ignite
  ,mrr.revenue_prior_website
  ,mrr.revenue_prior_misc
  ,mrr.revenue_prior_adplacement
  ,mrr.revenue_prior_total
  ,mrr.mrr_acquired
  ,mrr.mrr_penetrated
  ,mrr.mrr_downsized
  ,mrr.mrr_churned
  ,mrr.mrr_retained
  ,mrr.mrr_returned
  ,mrr.expired_date
  ,mrr.expired_reason
  ,mrr.block_conversion_flag
  ,mrr.refund_current_month_flag
  ,mrr.customer_prev_billed_date
  ,mrr.customer_billed_current_month_flag
  ,mrr.promo_flag
FROM dm.mrr_customer_category_all_products mrr
  LEFT OUTER JOIN dm.mrr_customer_classification mca
          ON mrr.customer_id = mca.customer_id
         AND mrr.yearmonth = mca.yearmonth
-- WHERE mrr.mrr_customer_category NOT IN ('NOT BILLED')
  WHERE mrr.yearmonth = 201607
;

DROP TABLE tmp_data_dm.coe_temp_new ;
CREATE TABLE tmp_data_dm.coe_temp_new AS
SELECT *
FROM tmp_data_dm.coe_jrr_backfill_customer_mrr mrr
WHERE mrr.year_month = 201607
;

DROP TABLE tmp_data_dm.coe_jrr_compare ;
CREATE TABLE tmp_data_dm.coe_jrr_compare AS
SELECT
   IFNULL(new.customer_id, off.customer_id) AS  cons_customer_id
  ,IFNULL(new.year_month, off.year_month) AS    cons_year_month
  ,CASE WHEN new.customer_id IS NULL AND 
             off.mrr_customer_category IN ('ACQUIRED', 'CHURNED', 'NO ACTIVITY') AND
             off.mrr_current_total = 0 AND off.revenue_current_total = 0  THEN 'OK: Free non-ads'
        WHEN new.mrr_customer_category = 'DOWNSIZED' AND off.mrr_customer_category = 'NO ACTIVITY' AND
             new.mrr_current_total = 0 THEN 'OK: downsized to 0'
        WHEN new.customer_id IS NULL OR off.customer_id IS NULL THEN 'Customer mismatch'
        WHEN new.mrr_customer_category <> off.mrr_customer_category THEN 'Category mismatch'
        WHEN new.mrr_current_total = off.mrr_current_total THEN 'OK' 
        WHEN ((new.mrr_current_total / off.mrr_current_total) - 1 BETWEEN -.0001 AND .0001) THEN 'OK' 
        WHEN (new.mrr_current_total <> off.mrr_current_total) AND 
             (off.mrr_current_total <> 0) AND 
             ((new.mrr_current_total / off.mrr_current_total) - 1 BETWEEN -.01 AND .01) THEN 'MRR close but no cigar' 
        ELSE 'MRR mismatch' END AS is_exception
  ,'OK' AS chk_category
  ,(new.mrr_current_total / off.mrr_current_total) - 1 AS                          mrr_var
  ,IFNULL(new.mrr_current_total, 0) - IFNULL(off.mrr_current_total, 0) AS          mrr_diff
  ,IFNULL(new.revenue_current_total, 0) - IFNULL(off.revenue_current_total, 0) AS  revenue_diff
  ,IFNULL(new.mrr_churned, 0) - IFNULL(off.mrr_churned, 0) AS                      mrr_churned_diff
  ,new.mrr_current_total AS                    new_mrr_current_total
  ,new.revenue_current_total AS                new_revenue_current_total
  ,new.mrr_churned AS                          new_mrr_churned
  ,new.mrr_prior_total AS                      new_mrr_prior_total
  ,off.mrr_current_total AS                    off_mrr_current_total
  ,off.revenue_current_total AS                off_revenue_current_total
  ,off.mrr_churned AS                          off_mrr_churned
  ,new.mrr_customer_category AS                new_mrr_customer_category
  ,off.mrr_customer_category AS                off_mrr_customer_category
  ,new.mrr_customer_exception AS               new_mrr_customer_exception
  ,new.is_active_during_month AS               new_is_active_during_month
  ,new.is_active_eom AS                        new_is_active_eom
  ,new.has_ads_during_month AS                 new_has_ads_during_month
  ,new.has_ads_eom AS                          new_has_ads_eom
  ,new.customer_exists_prior_month AS          new_customer_exists_prior_month
  ,new.customer_id AS                          new_customer_id
  ,new.year_month AS                           new_year_month
  ,new.chain_number AS                         new_chain_number
  ,new.tenure_month_chain AS                   new_tenure_month_chain
  ,new.tenure_month_lifetime AS                new_tenure_month_lifetime
  ,new.active_months_to_date AS                new_active_months_to_date
  ,new.start_month_chain AS                    new_start_month_chain
  ,new.start_month_lifetime AS                 new_start_month_lifetime
  ,new.first_payment_month AS                  new_first_payment_month
  ,new.had_payment AS                          new_had_payment
  ,new.max_bill_date_in_month AS               new_max_bill_date_in_month
  ,new.revenue_current_advertisement AS        new_revenue_current_advertisement
  ,new.revenue_current_avvopro AS              new_revenue_current_avvopro
  ,new.revenue_current_ignite AS               new_revenue_current_ignite
  ,new.revenue_current_website AS              new_revenue_current_website
  ,new.revenue_current_adplacement AS          new_revenue_current_adplacement
  ,new.revenue_current_misc AS                 new_revenue_current_misc
  ,new.revenue_current_other_sub AS            new_revenue_current_other_sub
  ,new.revenue_current_other AS                new_revenue_current_other
  ,new.mrr_current_advertisement AS            new_mrr_current_advertisement
  ,new.mrr_current_avvopro AS                  new_mrr_current_avvopro
  ,new.mrr_current_ignite AS                   new_mrr_current_ignite
  ,new.mrr_current_website AS                  new_mrr_current_website
  ,new.mrr_current_adplacement AS              new_mrr_current_adplacement
  ,new.mrr_current_other_sub AS                new_mrr_current_other_sub
  ,new.tenure_month_prev AS                    new_tenure_month_prev
  ,new.is_active_during_month_prior AS         new_is_active_during_month_prior
  ,new.is_active_eom_prior AS                  new_is_active_eom_prior
  ,new.had_payment_prior AS                    new_had_payment_prior
  ,new.has_ads_during_month_prior AS           new_has_ads_during_month_prior
  ,new.has_ads_eom_prior AS                    new_has_ads_eom_prior
  ,new.revenue_prior_advertisement AS          new_revenue_prior_advertisement
  ,new.revenue_prior_avvopro AS                new_revenue_prior_avvopro
  ,new.revenue_prior_ignite AS                 new_revenue_prior_ignite
  ,new.revenue_prior_website AS                new_revenue_prior_website
  ,new.revenue_prior_adplacement AS            new_revenue_prior_adplacement
  ,new.revenue_prior_misc AS                   new_revenue_prior_misc
  ,new.revenue_prior_other_sub AS              new_revenue_prior_other_sub
  ,new.revenue_prior_other AS                  new_revenue_prior_other
  ,new.revenue_prior_total AS                  new_revenue_prior_total
  ,new.mrr_prior_advertisement AS              new_mrr_prior_advertisement
  ,new.mrr_prior_avvopro AS                    new_mrr_prior_avvopro
  ,new.mrr_prior_ignite AS                     new_mrr_prior_ignite
  ,new.mrr_prior_website AS                    new_mrr_prior_website
  ,new.mrr_prior_adplacement AS                new_mrr_prior_adplacement
  ,new.mrr_prior_other_sub AS                  new_mrr_prior_other_sub
  ,new.mrr_acquired AS                         new_mrr_acquired
  ,new.mrr_penetrated AS                       new_mrr_penetrated
  ,new.mrr_downsized AS                        new_mrr_downsized
  ,new.mrr_retained AS                         new_mrr_retained
  ,new.mrr_returned AS                         new_mrr_returned
  ,new.mrr_retained_subset_flat_customers AS   new_mrr_retained_subset_flat_customers
  ,new.mrr_retained_subset_delta_customers AS  new_mrr_retained_subset_delta_customers
  ,new.has_had_payment_lifetime AS             new_has_had_payment_lifetime
  ,off.customer_id AS                         off_customer_id
  ,off.year_month AS                          off_year_month
  ,off.has_ads AS                             off_has_ads
  ,off.mrr_current_advertisement AS           off_mrr_current_advertisement
  ,off.mrr_current_avvopro AS                 off_mrr_current_avvopro
  ,off.mrr_current_ignite AS                  off_mrr_current_ignite
  ,off.mrr_current_website AS                 off_mrr_current_website
  ,off.mrr_current_adplacement AS             off_mrr_current_adplacement
  ,off.mrr_prior_advertisement AS             off_mrr_prior_advertisement
  ,off.mrr_prior_avvopro AS                   off_mrr_prior_avvopro
  ,off.mrr_prior_ignite AS                    off_mrr_prior_ignite
  ,off.mrr_prior_website AS                   off_mrr_prior_website
  ,off.mrr_prior_adplacement AS               off_mrr_prior_adplacement
  ,off.mrr_prior_total AS                     off_mrr_prior_total
  ,off.revenue_current_advertisement AS       off_revenue_current_advertisement
  ,off.revenue_current_avvopro AS             off_revenue_current_avvopro
  ,off.revenue_current_ignite AS              off_revenue_current_ignite
  ,off.revenue_current_website AS             off_revenue_current_website
  ,off.revenue_current_misc AS                off_revenue_current_misc
  ,off.revenue_current_adplacement AS         off_revenue_current_adplacement
  ,off.revenue_prior_advertisement AS         off_revenue_prior_advertisement
  ,off.revenue_prior_avvopro AS               off_revenue_prior_avvopro
  ,off.revenue_prior_ignite AS                off_revenue_prior_ignite
  ,off.revenue_prior_website AS               off_revenue_prior_website
  ,off.revenue_prior_misc AS                  off_revenue_prior_misc
  ,off.revenue_prior_adplacement AS           off_revenue_prior_adplacement
  ,off.revenue_prior_total AS                 off_revenue_prior_total
  ,off.mrr_acquired AS                        off_mrr_acquired
  ,off.mrr_penetrated AS                      off_mrr_penetrated
  ,off.mrr_downsized AS                       off_mrr_downsized
  ,off.mrr_retained AS                        off_mrr_retained
  ,off.mrr_returned AS                        off_mrr_returned
  ,off.expired_date AS                        off_expired_date
  ,off.expired_reason AS                      off_expired_reason
  ,off.block_conversion_flag AS               off_block_conversion_flag
  ,off.refund_current_month_flag AS           off_refund_current_month_flag
  ,off.customer_prev_billed_date AS           off_customer_prev_billed_date
  ,off.customer_billed_current_month_flag AS  off_customer_billed_current_month_flag
  ,off.promo_flag AS                          off_promo_flag
  ,1 AS customers
FROM 
                tmp_data_dm.coe_temp_new new
FULL OUTER JOIN tmp_data_dm.coe_temp_off off
        ON new.customer_id = off.customer_id
       AND new.year_month = off.year_month
;

select * from tmp_data_dm.coe_jrr_compare
where chk_category NOT LIKE 'OK%' OR is_exception NOT LIKE 'OK%'
OR ABS(mrr_diff) > 0.01
OR ABS(revenue_diff) > 0.01
OR ABS(mrr_churned_diff) > 0.01
ORDER BY cons_customer_id, cons_year_month
;

2022 customers in official and not in mine.
849 w/ good mrr but category mismatch.
194 with both mrr and category mismatch.
1274 with good category but mrr mismatch.

Somewhere I am still filtering out customers if they do not have ads.

OK was using an ads-only MRR table.

1232 customers in official and not in mine.
987 w/ good mrr but category mismatch.
87 with both mrr and category mismatch.
678 with good category but mrr mismatch.

SELECT
   SUM(new.mrr_current_total) AS                    new_mrr_current_total
  ,SUM(off.mrr_current_total) AS                   off_mrr_current_total
  ,SUM(new.revenue_current_total) AS                new_revenue_current_total
  ,SUM(off.revenue_current_total) AS               off_revenue_current_total
  ,SUM(new.mrr_current_advertisement) AS            new_mrr_current_advertisement
  ,SUM(off.mrr_current_advertisement) AS           off_mrr_current_advertisement
  ,SUM(new.revenue_current_advertisement) AS        new_revenue_current_advertisement
  ,SUM(off.revenue_current_advertisement) AS       off_revenue_current_advertisement
FROM 
                tmp_data_dm.coe_temp_new new
FULL OUTER JOIN tmp_data_dm.coe_temp_off off
        ON new.customer_id = off.customer_id
       AND new.year_month = off.year_month

Whoa.  MRR matches perfectly (at a high level) now.
Revenue does not.

SELECT
   new.mrr_customer_category AS                new_mrr_customer_category
  ,off.mrr_customer_category AS               off_mrr_customer_category
  ,SUM(new.mrr_current_total) AS                    new_mrr_current_total
  ,SUM(off.mrr_current_total) AS                   off_mrr_current_total
  ,SUM(new.revenue_current_total) AS                new_revenue_current_total
  ,SUM(off.revenue_current_total) AS               off_revenue_current_total
  ,SUM(new.mrr_current_advertisement) AS            new_mrr_current_advertisement
  ,SUM(off.mrr_current_advertisement) AS           off_mrr_current_advertisement
  ,SUM(new.revenue_current_advertisement) AS        new_revenue_current_advertisement
  ,SUM(off.revenue_current_advertisement) AS       off_revenue_current_advertisement
FROM 
                tmp_data_dm.coe_temp_new new
FULL OUTER JOIN tmp_data_dm.coe_temp_off off
        ON new.customer_id = off.customer_id
       AND new.year_month = off.year_month
GROUP BY 1,2
ORDER BY 1,2

I think my NOT BILLED category is wrong - I have some ppl falling 
into there with both revenue and MRR.
Well actually I think they have mrr but do not see the revenue.
I am missing some revenue into NO ACTIVITY.

SELECT
   new.mrr_customer_category AS                new_mrr_customer_category
  ,off.mrr_customer_category AS                off_mrr_customer_category
  ,new.mrr_customer_exception AS               new_mrr_customer_exception
  ,SUM(new.mrr_current_total)  - SUM(off.mrr_current_total) AS                         diff_mrr
  ,SUM(new.revenue_current_total) - SUM(off.revenue_current_total) AS                  diff_revenue
  ,SUM(new.mrr_current_advertisement) - SUM(off.mrr_current_advertisement) AS          diff_mrr_ads
  ,SUM(new.revenue_current_advertisement) - SUM(off.revenue_current_advertisement) AS  diff_revenue_ads
  ,SUM(new.mrr_churned) - SUM(off.mrr_churned) AS                                      diff_mrr_churned
  ,SUM(new.mrr_current_total) AS                    new_mrr
  ,SUM(off.mrr_current_total) AS                    off_mrr
  ,SUM(new.revenue_current_total) AS                new_revenue
  ,SUM(off.revenue_current_total) AS                off_revenue
  ,SUM(new.mrr_current_advertisement) AS            new_mrr_ads
  ,SUM(off.mrr_current_advertisement) AS            off_mrr_ads
  ,SUM(new.revenue_current_advertisement) AS        new_revenue_ads
  ,SUM(off.revenue_current_advertisement) AS        off_revenue_ads
  ,SUM(new.mrr_churned) AS                          new_mrr_churned
  ,SUM(off.mrr_churned) AS                          off_mrr_churned
FROM 
                tmp_data_dm.coe_temp_new new
FULL OUTER JOIN tmp_data_dm.coe_temp_off off
        ON new.customer_id = off.customer_id
       AND new.year_month = off.year_month
GROUP BY 1,2,3
ORDER BY 1,2,3

Oops.
- I need to make MRR Churned negative.  done.



select *   FROM tmp_data_dm.coe_jrr_sub_bills
where customer_id = 1455
and year_month = 201608

select *   FROM tmp_data_dm.coe_jrr_cust_chains
where customer_id = 1455
and year_month = 201608

select * from dm.mrr_subscription_all_products
WHERE subscription_id = 10443131


select * from tmp_data_dm.coe_jrr_compare
where chk_category <> 'OK' OR is_exception <> 'OK'
OR ABS(mrr_diff) > 0.01
OR ABS(revenue_diff) > 0.01
OR ABS(mrr_churned_diff) > 0.01
ORDER BY cons_customer_id, cons_year_month

Ah well for one thing I think I am missing MISC payments if that is
all that happened for that cust in the month.
Except why does this show 4000 revenue when off shows 100?
select *   FROM tmp_data_dm.coe_jrr_sub_bills
where year_month = 201608
and customer_id = 38412
OK had to not join to mrr sub table if sub_id = -1.

Let''s go back and make it so if misc payment in month is only thing,
we still see it.
If someone only has a misc payment in the month, does that count as
part of a chain?
I am inclined to say yes, but my definition of active is all intermeshed
with that.
For example, active_months_to_date just counts the entries in the chain.
I filter coe_jrr_cust_active_months on:
WHERE mth.has_ads = 'Y' OR mth.mrr_current_total > 0
But they may have revenue but have that condition not met.
OK setting this aside for now.  I think I need to wrap back at the end
and gather the revenue from sub_bills for customer_id / year_month combos
that I did not get before.
Yep for customer_id = 7307 August is in bills but not in chains.

Oh looks like I may be dropping non-ads paid people on their last month,
because in that month mrr=0 and they do not have ads.
OK include bills where revenue_total <> 0 too.
Shoot that messed up my chains.
-- - Wrap back to that.

Chk Category  Is Exception  
OK  OK  21314
OK: downsized to 0  OK  1
See exception field  OK: Free non-ads  874
See exception field  Customer mismatch  340
Category mismatch  OK  1033

Oh crap.  Right now, has_ads does not look at exp date.

-- - Pretty sure revenue_current_total needs to include everything.

   ,CASE WHEN adj.has_ads     = 'Y' AND adj.customer_continues_past_month = 'Y' THEN 'Y'
         WHEN adj.has_payment = 'Y' AND adj.customer_continues_past_month = 'Y' THEN 'Y'
         ELSE 'N' END AS                                             customer_active_current_month

Aw man.  OK so if they had a payment in the month and some sub, even
if free, continues past month, I am calling them active.
Not right.

OK so things to change:
- Pretty sure revenue_current_total needs to include everything.  done.
- Fix is_active definition.
  - Same sub either MRR>0 or ads AND continues.
  - wtf was I thinking about payment?
- I now include bills where revenue_total <> 0, but that messed up my chains.
  (how much?)

SELECT
   year_month
  ,SUM(CASE WHEN revenue_current_total <> 0 AND
                 NOT (has_ads = 'Y' OR has_payment = 'Y') nope makes no sense w/ current defn.  Come back to this.
            THEN 1 ELSE 0 END) AS these_cust_months
  ,COUNT(*) AS cust_months
FROM tmp_data_dm.coe_jrr_cust_active_months
GROUP BY 1
ORDER BY 1

SELECT
   year_month
  ,CASE WHEN revenue > 0 THEN 'Yes Revenue Positive'
        WHEN revenue < 0 THEN 'Yes Revenue Negative'
        ELSE 'No revenue' END AS has_revenue
  ,CASE WHEN has_payment = 'Y' THEN 'Yes payment' ELSE 'No payment' END AS has_payment
  ,SUM(revenue) AS revenue
  ,COUNT(*) AS bills
FROM tmp_data_dm.coe_jrr_sub_bills
GROUP BY 1,2,3

OK the cases where I have revenue but no payment in a bill are all refunds.

Really I could either:
1. Apply the filter at active_months and then go get bills for 
   (customer, month) that dropped out.
   Appeal is filter only in 1 place.
2. Apply the filter both at start_months and raw1, and
   go get entries from active_months that dropped out.
   Appeal is that when I go back to get dropped out data, it is
   at the right level of granularity.
Oooh!  Put filter logic into active_months as a flag, and then it''s
not horrible to check the flag in 2 places.
Ah, another advantage of doing it that way is that the bills level does
not categorize revenue into types, so I would have to duplicate that 
logic in the plug if I based it on bills.

-- - Rename active_months to cust_months.
-- - Add is_active flag to it.
-- - OK wait how do I make sure that churn month shows up in bills?
--   Distinction between had ads any time in the month and had them extending past the end.
--   Similar with paid pro what if they got that 1 month with no revenue
--   (in the cancel month), how do I know to still include the record?
--   OK make sure that full_price is always populated whether or not sub continues past EoM.
--   Then in outer bls query, make mrr and potential_mrr.
--   If there is potential_mrr, then that is (part of) the filter to see if include in chains.
-- - Make sure the right stuff flows through bills for that logic.
-- - Add active filters to start_month and raw1.
-- - Go check for other places where I should be checking active.
-- - After I have chains, go back and fill in from cust_months
--   where there is revenue but is not active.

bls
  sub_id
  has_ads_during_month
  has_ads_eom
  -- is_active_during_month
  -- is_active_eom
  potential_mrr_total
  mrr
  revenue
from olaf
no filter

cust_months
  cust_id
  has_ads_during_month
  has_ads_eom
  is_active_during_month
  is_active_eom
  potential_mrr_total
  mrr
  revenue
from bls
filter: has_ads_during_month = 'Y' or potential_mrr_total > 0 or revenue <> 0

raw1 (and through to chains)
  cust_id
  has_ads_during_month
  has_ads_eom
  is_active_during_month
  is_active_eom
  potential_mrr_total
  mrr
  revenue
from cust_months
filter: has_ads_during_month = 'Y' or potential_mrr_total > 0
  (which is same as is_active_during_month = 'Y')

revenue_plug
  cust_id
  has_ads (in month)
  is_active (as of EoM) (N by definition)
  potential_mrr_total
  mrr
  revenue
from cust_months
filter: NOT (has_ads_during_month = 'Y' or potential_mrr_total > 0) AND revenue_current_total <> 0
  (which is is_active_during_month = 'N' AND revenue_current_total <> 0)

OK wait.  What about a month w/ signup and cancel in same month?
The version before these changes would not have included that.
Wait wouldn''t it? Ah think it would have because has_ads was during month.
Correct, MRR looked at exp date and has_ads did not.
So they would show up in the chain.

Strongly suspect that in old way, if there was revenue but no MRR,
they would show up as NO ACTIVITY.
-- - Need to think about how I want to classify them.
--   Conceptually they are NOT BILLED.  But that''s weird.
--   Would kinda like to call them NO ACTIVITY. 
  In the fully new world I might want a new category, REVENUE ONLY. 

-- - Check for dups after plug insert.
SELECT customer_id, year_month, COUNT(*)
FROM tmp_data_dm.coe_jrr_cust_chains
GROUP BY 1,2
HAVING COUNT(*) > 1
ok good.  No dups.

-- - Go back and review which new fields I do not actually need.
-- Well.  Actually.  For now I want them all.  Using quite a few of them
-- when inspecting exceptions.


Chk Category  Is Exception  
Category mismatch  OK  88
OK  OK  22272
OK: downsized to 0  OK  1
See exception field  Customer mismatch  2
See exception field  OK: Free non-ads  1199

Edgiest of edge cases: they only ever had web, so has_ads is always N,
and they were refunded the full amount in their final month so 
revenue = 0, and potential mrr = 0 because I pull mrr from main mrr 
and they canceled in month.  23155

I am going to attempt a run where in the mrr method, potential_mrr = mrr - churned_mrr (because churned is negative)
Hrm would have to mess with the whole mrr value.  Eh trying anyway.
It worked!

----
Do month formulas...

-- - Look into whether I can restart chain if returned but they were there the prev. month.  Think not.

DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_backfill_check_months ;
CREATE TABLE tmp_data_dm.coe_jrr_backfill_check_months AS
SELECT
   year_month
  ,year_month_begin_date
  ,mrr_customer_category
  ,mrr_customer_exception
  ,mrr_method
  ,SUM(revenue_current_total) AS                revenue_current_total
  ,SUM(mrr_current_total) AS                    mrr_current_total
  ,SUM(revenue_prior_total) AS                  revenue_prior_total
  ,SUM(mrr_prior_total) AS                      mrr_prior_total
  ,SUM(mrr_acquired) AS                         mrr_acquired
  ,SUM(mrr_penetrated) AS                       mrr_penetrated
  ,SUM(mrr_downsized) AS                        mrr_downsized
  ,SUM(mrr_churned) AS                          mrr_churned
  ,SUM(mrr_retained) AS                         mrr_retained
  ,SUM(mrr_returned) AS                         mrr_returned
  ,SUM(mrr_retained_subset_flat_customers) AS   mrr_retained_subset_flat_customers
  ,SUM(mrr_retained_subset_delta_customers) AS  mrr_retained_subset_delta_customers
  ,COUNT(*) AS customers
FROM tmp_data_dm.coe_jrr_backfill_customer_mrr
GROUP BY 1,2,3,4,5

SELECT *
FROM tmp_data_dm.coe_jrr_backfill_customer_mrr
WHERE year_month = 201407
  AND mrr_customer_category = 'NOT BILLED'
  AND mrr_current_total <> 0

SELECT
   year_month
  ,year_month_begin_date
  ,mrr_customer_category
  ,mrr_customer_exception
  ,mrr_method
  ,has_ads_during_month
  ,has_ads_eom
  ,has_non_ads_during_month
  ,has_non_ads_eom
  ,COUNT(*) AS customers
  ,SUM(revenue_current_total) AS                revenue_current_total
  ,SUM(mrr_current_total) AS                    mrr_current_total
  ,SUM(revenue_prior_total) AS                  revenue_prior_total
  ,SUM(mrr_prior_total) AS                      mrr_prior_total
  ,SUM(mrr_acquired) AS                         mrr_acquired
  ,SUM(mrr_penetrated) AS                       mrr_penetrated
  ,SUM(mrr_downsized) AS                        mrr_downsized
  ,SUM(mrr_churned) AS                          mrr_churned
  ,SUM(mrr_retained) AS                         mrr_retained
  ,SUM(mrr_returned) AS                         mrr_returned
  ,SUM(mrr_retained_subset_flat_customers) AS   mrr_retained_subset_flat_customers
  ,SUM(mrr_retained_subset_delta_customers) AS  mrr_retained_subset_delta_customers
FROM tmp_data_dm.coe_jrr_backfill_customer_mrr
WHERE year_month = 201407
GROUP BY 1,2,3,4,5,6,7,8,9
ORDER BY 3,4,6,7,8,9

  -- ,srt.mrr_customer_category AS start_cust_cat
  -- ,mth.mrr_customer_category AS mth_cust_cat

SELECT
   srt.year_month AS start_month
  ,CONCAT('M',LPAD(CAST(ym.tenure_month AS STRING),2,'0')) AS tenure_month
  ,ym.year_month
  ,COUNT(*) AS                                new_customers
  ,COUNT(mth.customer_id) AS                  retained_customers
  ,SUM(srt.mrr_current_advertisement) AS      new_mrr
  ,SUM(mth.mrr_current_advertisement) AS      retained_mrr
  ,SUM(srt.revenue_current_advertisement) AS  new_revenue
  ,SUM(mth.revenue_current_advertisement) AS  retained_revenue
  ,'99. Backfill candidate' AS run_version
FROM
    tmp_data_dm.coe_jrr_backfill_customer_mrr srt
  INNER JOIN
    (
    SELECT DISTINCT 
       m1.year_month AS start_month
      ,m2.year_month
      ,(FLOOR(m2.year_month/100)-FLOOR(m1.year_month/100)) * 12 +
             (m2.year_month%100-       m1.year_month%100) AS tenure_month
    FROM dm.month_dim m1
    INNER JOIN dm.month_dim m2 ON m1.year_month <= m2.year_month  
    WHERE m1.year_month BETWEEN 201304 AND 201610
      AND m2.year_month BETWEEN 201304 AND 201610
    ) ym
          ON srt.year_month = ym.start_month
  LEFT OUTER JOIN tmp_data_dm.coe_jrr_backfill_customer_mrr mth
          ON srt.customer_id = mth.customer_id
         AND srt.chain_number = mth.chain_number
         AND  ym.year_month = mth.year_month
         AND mth.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
         AND mth.has_ads_eom = 'Y'
WHERE srt.chain_number = 1
  AND srt.tenure_month_lifetime = 0
  AND srt.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
  AND srt.has_ads_eom = 'Y'
GROUP BY 1,2,3,10
ORDER BY 1,3

I might have to take this back to ads only to do any reasonable comparison.
Yep.  That data is in tmp_data_dm.coe_jrr_backfill_customer_mrr_match_ss.
For that version, customer counts match ss exactly.
MRR differences basically come down to if a sub is discounted, the ss
does not know its full price until it is billed at full price.

----
Can I do something about legit cancel followed by return in the
next month?
Maybe I don''t have to do anything about it.  The only weird thing
is that returns may not always be at tenure_month_chain = 0.
And churns may not always be at the last month in the chain.

-- - LOOK still need to fill in other NOT BILLED. done.

-- DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_ad_counts ;
-- CREATE TABLE tmp_data_dm.coe_jrr_ad_counts AS
-- SELECT
--    sub.customer_id
--   ,sub.yearmonth AS year_month
--   ,SUM(sub.ad_current_count) AS ad_current_count
-- FROM dm.mrr_subscription_all_products sub
-- GROUP BY 1,2

DROP TABLE IF EXISTS tmp_data_dm.coe_jrr_first_churn ;
CREATE TABLE tmp_data_dm.coe_jrr_first_churn AS
SELECT
   sub.customer_id
  ,sub.yearmonth AS year_month
  ,SUM(sub.ad_current_count) AS ad_current_count
FROM dm.mrr_subscription_all_products sub
GROUP BY 1,2

SELECT
   srt.yearmonth AS start_month
  ,CONCAT('M',LPAD(CAST(ym.tenure_month AS STRING),2,'0')) AS tenure_month
  ,ym.year_month
  ,COUNT(*) AS                                new_customers
  ,COUNT(mth.customer_id) AS                  retained_customers
  ,SUM(srt.mrr_current_advertisement) AS      new_mrr
  ,SUM(mth.mrr_current_advertisement) AS      retained_mrr
  ,SUM(srt.revenue_current_advertisement) AS  new_revenue
  ,SUM(mth.revenue_current_advertisement) AS  retained_revenue
  ,'999. Current MRR All Products' AS run_version
FROM
    dm.mrr_customer_category_all_products srt
  INNER JOIN
    (
    SELECT DISTINCT 
       m1.year_month AS start_month
      ,m2.year_month
      ,(FLOOR(m2.year_month/100)-FLOOR(m1.year_month/100)) * 12 +
             (m2.year_month%100-       m1.year_month%100) AS tenure_month
    FROM dm.month_dim m1
    INNER JOIN dm.month_dim m2 ON m1.year_month <= m2.year_month  
    WHERE m1.year_month BETWEEN 201304 AND 201610
      AND m2.year_month BETWEEN 201304 AND 201610
    ) ym
          ON srt.yearmonth = ym.start_month
  LEFT OUTER JOIN
    (
    SELECT customer_id, MIN(CASE WHEN mrr_customer_category = 'CHURNED' THEN yearmonth ELSE NULL END) AS churn_month
    FROM dm.mrr_customer_category_all_products
    GROUP BY 1
    ) chrn
          ON srt.customer_id = chrn.customer_id
  LEFT OUTER JOIN dm.mrr_customer_category_all_products mth
          ON srt.customer_id = mth.customer_id
         AND  ym.year_month = mth.yearmonth
         AND mth.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
         AND mth.yearmonth <= IFNULL(chrn.churn_month, 299901)
  -- LEFT OUTER JOIN tmp_data_dm.coe_jrr_ad_counts ads_mth
  --         ON srt.customer_id = ads_mth.customer_id
  --        AND  ym.year_month = ads_mth.year_month
WHERE srt.mrr_customer_category IN ('ACQUIRED')
GROUP BY 1,2,3,10
ORDER BY 1,3

-- - how do I restrict to only first chain? done.

----
-- - Aw shoot the NOT BILLED plug needs to get all prior customers, not
-- just the ones that signed up since where I am looking.
-- Probably need to launch from a different table.  ugh.
-- - Did I do this?

-- - And while I am at it, would be extra handy to identify frickin free pro.
-- - And add a failed CC flag.

-- - LOOK IMPORTANT!!! need to include product_line_id=18 (AdPlacement).

SELECT
   cust.customer_id
  ,mth.month_begin_date AS        year_month_begin_date
  ,NULL AS                        chain_number
  ,NULL AS                        tenure_month_chain
  ,1+(FLOOR(mth.year_month/100)-FLOOR(cust.start_month/100)) * 12 +
           (mth.year_month%100-       cust.start_month%100) AS tenure_month_lifetime
  ,NULL AS                        active_months_to_date
  ,NULL AS                        start_month_chain
  ,NULL AS                        start_month_begin_date_chain
  ,cust.start_month AS             start_month_lifetime
  ,cust.start_month_begin_date AS  start_month_begin_date_lifetime
  ,cust.first_payment_month
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
  ,CASE WHEN cust.first_payment_month <= mth.year_month THEN 'Y' ELSE 'N' END AS has_had_payment_lifetime
  ,'OK' AS mrr_customer_exception
  ,mth.year_month
FROM
  --       dm.customer_dimension cust
  -- INNER JOIN 
    (
    SELECT
       nrt.id AS customer_id
      ,TO_DATE(nrt.created_at) AS start_date
      ,CAST(from_unixtime(unix_timestamp(CAST(nrt.created_at AS TIMESTAMP)), 'yyyyMM') AS INT) AS start_month
      ,TO_DATE(TRUNC(nrt.created_at, 'MONTH')) AS start_month_begin_date
      ,CAST(from_unixtime(unix_timestamp(CAST(fp.first_payment_date AS TIMESTAMP)), 'yyyyMM') AS INT) AS first_payment_month
    FROM src.nrt_customer nrt
      LEFT OUTER JOIN
        (
        SELECT customer_id, MIN(order_line_payment_date) AS first_payment_date
        FROM dm.order_line_accumulation_fact
        WHERE order_line_payment_date NOT IN ('1900-01-01', '-1') 
          AND order_line_net_price_amount_usd > 0
        GROUP BY 1
        ) fp
      ON nrt.id = fp.customer_id
    ) cust
          -- ON cust.customer_id = nrt.customer_id
  INNER JOIN tmp_data_dm.coe_my_month_dim mth
          ON cust.start_date <= mth.month_end_date
         AND mth.year_month BETWEEN 201304 AND 201610
  LEFT OUTER JOIN tmp_data_dm.coe_jrr_backfill_customer_mrr mrr
          ON srt.customer_id = mrr.customer_id
         AND mth.year_month = mrr.year_month
WHERE mrr.customer_id IS NULL 
;


tmp_data_dm.coe_my_month_dim

  ,MAX(CASE WHEN olaf.product_line_id IN (2,7,18) THEN 'Y' ELSE 'N' END) AS has_ads

select source_system_begin_date, count(*) from dm.historical_customer_dimension group by 1 order by 1

SELECT cust_hist_start, cust_nrt_start, COUNT(*) AS customers
FROM
    (
    SELECT customer_id, TRUNC(MIN(source_system_begin_date), 'MONTH') AS cust_hist_start
    FROM dm.historical_customer_dimension
    GROUP BY 1
    ) cust
  FULL OUTER JOIN
    (
    SELECT id AS customer_id, TRUNC(MIN(created_at), 'MONTH') AS cust_nrt_start
    FROM src.nrt_customer
    GROUP BY 1
    ) nrtc
  ON cust.customer_id = nrtc.customer_id
GROUP BY 1,2
OK so nrt_start is always <= hist_start.  So I am going with nrt.
No NULLs on either side which is good

TRUNC(nrt.created_at, 'MONTH')

tmp_data_dm.coe_jrr_cust_lifetime_start srt
  INNER JOIN dm.month_dim mth
          ON srt.start_month <= mth.year_month
         AND mth.year_month BETWEEN 201304 AND 201610
  LEFT OUTER JOIN tmp_data_dm.coe_jrr_backfill_customer_mrr mrr
          ON srt.customer_id = mrr.customer_id
         AND mth.year_month = mrr.year_month
WHERE mrr.customer_id IS NULL ;

dm.order_line_accumulation_fact olaf

customer_exists_prior as
(
select customer_id,
max(last_billed_date) as last_billed_date
from customer_professional_purchase_map
where yearmonth=cast(concat(year(add_months(current_date, -2)), lpad(month(add_months(current_date, -2)),2,0)) as int)
group by customer_id
),

SELECT
   mth.year_month, COUNT(*) AS customers
FROM         dm.customer_dimension cust
  INNER JOIN 
             (
             SELECT id AS customer_id, TO_DATE(created_at) AS cust_start_date
             FROM src.nrt_customer
             ) nrt
          ON cust.customer_id = nrt.customer_id
  INNER JOIN tmp_data_dm.coe_my_month_dim mth
          ON nrt.cust_start_date <= mth.month_end_date
         AND mth.year_month BETWEEN 201304 AND 201610
GROUP BY 1
ORDER BY 1

SELECT
   srtm.year_month AS start_month, mth.year_month, COUNT(*) AS customers
FROM         dm.customer_dimension cust
  INNER JOIN 
             (
             SELECT id AS customer_id, TO_DATE(created_at) AS cust_start_date
             FROM src.nrt_customer
             ) nrt
          ON cust.customer_id = nrt.customer_id
  INNER JOIN tmp_data_dm.coe_my_month_dim mth
          ON nrt.cust_start_date <= mth.month_end_date
         AND mth.year_month BETWEEN 201304 AND 201610
  INNER JOIN tmp_data_dm.coe_my_month_dim srtm
          ON nrt.cust_start_date BETWEEN srtm.month_begin_date AND srtm.month_end_date
GROUP BY 1,2
way slow.

SELECT
   CAST(from_unixtime(unix_timestamp(CAST(nrt.cust_start_date AS TIMESTAMP)), 'yyyyMM') AS INT) AS start_month
  ,mth.year_month, COUNT(*) AS customers
FROM         dm.customer_dimension cust
  INNER JOIN 
             (
             SELECT id AS customer_id, TO_DATE(created_at) AS cust_start_date
             FROM src.nrt_customer
             ) nrt
          ON cust.customer_id = nrt.customer_id
  INNER JOIN tmp_data_dm.coe_my_month_dim mth
          ON nrt.cust_start_date <= mth.month_end_date
         AND mth.year_month BETWEEN 201304 AND 201610
GROUP BY 1,2
much faster.

SELECT
*
FROM 
                tmp_data_dm.coe_temp_new new
FULL OUTER JOIN tmp_data_dm.coe_temp_off off
        ON new.customer_id = off.customer_id
       AND new.year_month = off.year_month
where new.mrr_customer_category = 'NOT BILLED'
and off.mrr_customer_category = 'CHURNED'
These are free pro where pro rolled off.

Free pro can show up in a couple of NOT BILLED plugs.
ok free pro is getting too complicated what am I missing?
bls has all bills, including free pro.
But it does not break things into buckets.
mth has buckets, but filters so some free pro would not be included.
Oh maybe mth is filtering out too much; when I go to build chains,
all I look at is active in month.  The intent was then I could dump
other stuff into mth.

OK, free pro (et. al) is has_non_ads_eom = 'Y' and mrr_customer_category = 'NOT BILLED'.

One last thing: my look at subscription_price has to look at deleted_datetime
(code pending from Hema).  done.

----
Huh
SELECT
         olaf.order_line_cancelled_date AS order_line_cancelled_date_raw
        ,sub.expire_datetime AS exp_dttm_raw
        ,TRUNC(sub.expire_datetime, 'DAY') AS exp_date_trunc
        ,from_unixtime(unix_timestamp(sub.expire_datetime), 'yyyy-MM-dd') AS exp_date_unx
        ,CASE WHEN olaf.order_line_cancelled_date = '-1' AND TRUNC(sub.expire_datetime, 'DAY') = '1900-01-01' THEN NULL
              WHEN olaf.order_line_cancelled_date = '-1'                                                      THEN TRUNC(sub.expire_datetime, 'DAY')
              WHEN                                           TRUNC(sub.expire_datetime, 'DAY') = '1900-01-01' THEN olaf.order_line_cancelled_date
              WHEN olaf.order_line_cancelled_date > TRUNC(sub.expire_datetime, 'DAY')                         THEN olaf.order_line_cancelled_date
              ELSE TRUNC(sub.expire_datetime, 'DAY')
         END AS max_expired_date
        ,'Subscription Price' AS mrr_method
        ,dt.year_month
        ,dt.month_begin_date AS year_month_begin_date
        ,dt.month_end_date AS year_month_end_date
        ,IFNULL(mrr.full_price, 0) AS full_price
        ,olaf.*
        ,CASE WHEN LOWER(sub.expired_reason) = 'failed cc' THEN 'Y' ELSE 'N' END AS has_cc_failure_during_month
      FROM         dm.order_line_accumulation_fact olaf
        INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
        LEFT OUTER JOIN dm.subscription_dimension sub
                ON olaf.product_subscription_id = sub.subscription_id
        LEFT OUTER JOIN tmp_data_dm.coe_jrr_sub_price mrr
                ON olaf.product_subscription_id = mrr.subscription_id
      WHERE olaf.order_line_begin_date = '2015-09-01'
TRUNC does not do what I expect it to do (at least when truncing to DAY).
