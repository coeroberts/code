Churn spreadsheet: cohort visuals
MoM
% of start month

Quarter rollup (damn, that means the PoP stuff will have to be in tableau.)

MRR format is in thousands: #,##0.0,;(#,##0.0,)
Quarter looks like Q2 FY13

Vert: Cohort Month
  Quarter rollup is always sum.
Horz: Tenure Month
  Quarter rollup is average? Not quite.  Kinda customers is avg and mrr is sum?
  Ah but then avg per customer takes the averaged cust count and multiplies by 3.

1. Retained Customer Count
2. Retained MRR
3. Retained MRR as % of M0 MRR
4. Average MRR: Retained MRR / Retained Customers

Charts:
5. Average MRR as % of M1 Average MRR
6. MRR (sum) as % of M1 MRR
7. Customers as % of M1 Customers
(with cohort on colors)

Questions:
- Do we do any MoM (or QoQ)?
- Do we want a churn % table or chart?
  If so, is it % of cohort or of prev month?

----

-- DROP TABLE IF EXISTS tmp_data_dm.coe_churn_by_cohort_v1 ;
-- CREATE TABLE tmp_data_dm.coe_churn_by_cohort_v1 AS
-- SELECT
--    ym.cohort_month
--   ,ym.cohort_month_num
--   ,ym.cohort_quarter
--   ,ym.cohort_quarter_num
--   ,ym.cohort_year
--   ,CONCAT('M',LPAD(CAST(ym.tenure_month AS STRING),2,'0')) AS    tenure_month
--   ,                     ym.tenure_month AS                       tenure_month_num
--   ,CONCAT('Q',CAST(FLOOR((ym.tenure_month-1)/3)+1 AS STRING)) AS tenure_quarter
--   ,                FLOOR((ym.tenure_month-1)/3)+1 AS             tenure_quarter_num
--   ,FLOOR((ym.tenure_month-1)/12)+1 AS tenure_year
--   -- ,CONCAT('Q',CAST(FLOOR(ym.tenure_month/3)+1 AS STRING)) AS tenure_quarter
--   -- ,ym.calendar_month
--   ,ym.calendar_year_month
--   -- ,ym.calendar_quarter
--   -- ,ym.calendar_quarter_num
--   -- ,ym.calendar_year
--   ,CASE WHEN coh.chain_number = 1 THEN 'Acquisition' ELSE 'Return' END AS chain_type
--   ,coh.has_ads_eom AS has_ads
--   ,COUNT(*) AS                                new_customers
--   ,COUNT(mth.customer_id) AS                  retained_customers
--   ,SUM(coh.mrr_current_advertisement) AS      new_mrr
--   ,SUM(mth.mrr_current_advertisement) AS      retained_mrr
-- FROM
--     tmp_data_dm.coe_jrr_backfill_customer_mrr coh
--   INNER JOIN
--     (
--     SELECT DISTINCT 
--        m1.year_month AS cohort_month_num
--       ,CONCAT(CAST(FLOOR(m1.year_month/100) AS STRING), '-',LPAD(CAST(m1.year_month%100 AS STRING),2,'0')) AS cohort_month
--       ,m1.year*10 + m1.qtr_nbr_in_year AS cohort_quarter_num
--       ,CONCAT('FY', CAST(m1.year % 2000 AS STRING), ' Q', CAST(m1.qtr_nbr_in_year AS STRING)) AS cohort_quarter
--       ,m1.year AS cohort_year

--       ,m2.year_month AS calendar_month_num
--       -- ,CONCAT(CAST(FLOOR(m2.year_month/100) AS STRING), '-',LPAD(CAST(m2.year_month%100 AS STRING),2,'0')) AS calendar_month
--       -- ,m2.year*10 + m2.qtr_nbr_in_year AS calendar_quarter_num
--       -- ,CONCAT('FY', CAST(m2.year % 2000 AS STRING), ' Q', CAST(m2.qtr_nbr_in_year AS STRING)) AS calendar_quarter
--       -- ,m2.year AS calendar_year

--       ,1+(FLOOR(m2.year_month/100)-FLOOR(m1.year_month/100)) * 12 +
--                (m2.year_month%100-       m1.year_month%100) AS tenure_month
--     FROM dm.month_dim m1
--     INNER JOIN dm.month_dim m2 ON m1.year_month <= m2.year_month  
--     WHERE m1.year_month BETWEEN 201304 AND 201610
--       AND m2.year_month BETWEEN 201304 AND 201610
--     ) ym
--           ON coh.year_month = ym.cohort_month_num
--   LEFT OUTER JOIN tmp_data_dm.coe_jrr_backfill_customer_mrr mth
--           ON coh.customer_id = mth.customer_id
--          AND coh.chain_number = mth.chain_number
--          AND  ym.calendar_month_num = mth.year_month
--          AND mth.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
--          -- AND mth.has_ads_eom = 'Y'
-- WHERE coh.tenure_month_chain = 1
--   AND coh.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
--   -- AND coh.has_ads_eom = 'Y'  -- LOOK
-- GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13

Add churned customers so I can look at churn %.
Old ss calcs churn % as % of start.

Q1 has MRR Retention % > 100%.
Well shoot.  If you take months 1-3, new will not = retained
(in the way that it will if you are only looking at M1).
Ah!  So actually maybe it is ok.  I am just getting rid of the first
column (Q0) in each of the tables.
Nope, not ok.  Fixing.

Was going to move string formatting into Tableau, but the ones from
SQL are SO much faster, sticking with that.

Want to remove chain_number filter and add a variable specifying
acquisition or return chain.
Done.

Sayle feedback
- Cohort for returned is still acq cohort
- look at 2013 q4 and such cohorts mrr table
- Fix math so first quarter is always 100%.
  (probably involved in averaging 3 months for customers and such)
  OK yeah, for those charts, the first month is the baseline.
  So we do lose a bit of info about churn in the first quarter,
  but we can get that by monthly view of churn itself.
- Q: Is the divisor in retained MRR per customer the cohort size or 
  retained customers?  Thought I''d seen that it was retained 
  customers.  Hrm maybe not.  Retained cust yes.
-- - Can get rid of calendar fields.

I think this might mean that I do have to enter new baseline rows?
Well kinda not.  
So, interestingly, if my theory was both correct and complete then
the monthly view charts should all start at 100% and they do not.
Woohoo!  Now they do.  Left has_ads filter in retained.  Now I have
removed it.

-- Retained MRR in M01 is always NULL.
-- Retained customers in M01 should = new customers and it doesn''t.

Might need to re-pull ss data or something close somehow?

Why is cohort MRR per customer changing (a bit)?
Is it incomplete tenure quarters?
It is fine in month views.
OK so in some way it is based on rolling month up to quarter.
So each cohort quarter has 6 rows for a tenure quarter, 3 each for
has_ads, and 1 row for each of the 3 tenure months in the tenure 
quarter. 
Should I just do separate data pulls for quarter and month?
OK pretty sure that one problem is that cohort 201309 skips tenure_month 39.
Oh!  It doesn''t skip it, it has not hit it yet.  So in that cohort,
there is 1 cohort month that has all 3 tenure months in the tenure 
quarter available, and 1 with only 2 tenure months available, and 1 with 1.
Can I just not show the quarter til it''s done?
Miiiight be able to do QTD if I get the deduping right.
Nope.  Need all 3 months of the cohort or it''s not apples to apples.

Have to re-think the structure of the query.
The mrr table is by (customer_id, year_month).
Maybe I could roll it up to (customer_id, quarter)?
And then the structure of the cross join table is also quarter?
Ah but it gets weird because for different customers in a quarter,
different calendar months will make up a given tenure month.
Does it help if I put tenure_month and tenure_quarter into mrr table?

- How does has_ads come into play?  Yeah that messes it up even at
  month level because they might go to no ads and then again ads
  all in one chain.
Where do I put not_billed and churned filter?
What if they were in chain 1 in M1 and chain 2 in M3?

Can I just do all the quarter calcs on aggregates?  maybe?
It may be that all of my customer-level questins go away because I am
just doing math on aggregates?

- Add filter for not current month or quarter.
  Confusing tho because not only do I not want to show this quarter''s
  cohort, but I only want to show tenure quarters that are complete.
  And tenure quarter does not line up on all months.
  So maybe those filters have to be in SQL?
  BUT I can show more recent month data than quarter data.
  So maybe I only do current_month filter in SQL, but then add a
  field that I can additionally filter on if quarter.
  So that filter would say true if Month or (Quarter and Flag = Y)
  Oh ugh.  Back to tenure quarter not lining up on calendar months.
  OK wait by definition if we have not seen ALL 3 tenure months,
  the end date on those months is still the same as end date for an 
  earlier tenure quarter that des have all 3 because we have not yet
  seen those later ones.

OK need to review that the problems actually are:
1. Need Q1 to set the baseline, as calc of averages when necessary.
2. Not sure if the math gets weird when I add segment variables and
   there are very small segments.
3. Not sure what happens if a customer is in both acq chain and return 
   chain in a given quarter.

New Questions:
- I think a return just quietly adds back into Retained - agreed?
- No charts of absolute numbers of customers or MRR?
- Chart or table of churn %?



-- DROP TABLE IF EXISTS tmp_data_dm.coe_churn_by_cohort ;
-- CREATE TABLE tmp_data_dm.coe_churn_by_cohort AS
-- SELECT
--    'Month' AS              cohort_type
--   ,ym.cohort_month AS      cohort
--   ,CAST(ym.cohort_month_num AS INT) AS  cohort_num
--   ,ym.cohort_year
--   ,CONCAT('M',LPAD(CAST(ym.tenure_month AS STRING),2,'0')) AS  tenure
--   ,                CAST(ym.tenure_month AS INT) AS         tenure_num
--   ,CAST(FLOOR((ym.tenure_month-1)/12)+1 AS INT) AS tenure_year
--   ,CASE WHEN coh.chain_number = 1 THEN 'Acquisition' ELSE 'Return' END AS chain_type
--   ,coh.has_ads_eom AS has_ads
--   ,ym.cohort_start_date
--   ,ym.cohort_end_date
--   ,ym.tenure_start_date
--   ,ym.tenure_end_date
--   ,COUNT(*) AS                        new_customers_sum
--   ,COUNT(*) AS                        new_customers_avg
--   ,COUNT(mth.customer_id) AS          retained_customers_sum
--   ,COUNT(mth.customer_id) AS          retained_customers_avg
--   ,SUM(coh.mrr_current_total) AS      new_mrr
--   ,SUM(mth.mrr_current_total) AS      retained_mrr
-- FROM
--     tmp_data_dm.coe_jrr_backfill_customer_mrr coh
--   INNER JOIN
--     (
--     SELECT DISTINCT 
--        m1.year_month AS        cohort_month_num
--       ,CONCAT(CAST(FLOOR(m1.year_month/100) AS STRING), '-',LPAD(CAST(m1.year_month%100 AS STRING),2,'0')) AS cohort_month
--       ,m1.year AS              cohort_year
--       ,m1.month_begin_date AS  cohort_start_date
--       ,m1.month_end_date AS    cohort_end_date
--       ,m2.year_month AS        calendar_month_num
--       ,1+(FLOOR(m2.year_month/100)-FLOOR(m1.year_month/100)) * 12 +
--                (m2.year_month%100-       m1.year_month%100) AS tenure_month
--       ,m2.month_begin_date AS  tenure_start_date
--       ,m2.month_end_date AS    tenure_end_date
--       ,CASE WHEN m2.month_end_date UGH still won''t work.
--     FROM       dm.month_dim m1
--     INNER JOIN dm.month_dim m2 ON m1.year_month <= m2.year_month  
--     WHERE m1.year_month BETWEEN 201304 AND 201610  -- LOOK make this generic to last month.
--       AND m2.year_month BETWEEN 201304 AND 201610
--     ) ym
--           ON coh.year_month = ym.cohort_month_num
--   LEFT OUTER JOIN tmp_data_dm.coe_jrr_backfill_customer_mrr mth
--           ON coh.customer_id = mth.customer_id
--          AND coh.chain_number = mth.chain_number
--          AND  ym.calendar_month_num = mth.year_month
--          AND mth.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
-- WHERE coh.tenure_month_chain = 1
--   AND coh.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
--   -- AND coh.chain_number = 1 -- LOOK remove me later just for testing
-- GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12 ;

-- INSERT INTO tmp_data_dm.coe_churn_by_cohort
-- SELECT
--    'Quarter' AS            cohort_type
--   ,CONCAT('FY', CAST(m1.year % 2000 AS STRING), ' Q', CAST(m1.qtr_nbr_in_year AS STRING)) AS cohort
--   ,CAST(m1.year*10 + m1.qtr_nbr_in_year AS INT) AS cohort_num
--   ,chn.cohort_year
--   ,CONCAT('Q',CAST(FLOOR((chn.tenure_num-1)/3)+1 AS STRING)) AS tenure
--   ,           CAST(FLOOR((chn.tenure_num-1)/3)+1 AS INT) AS tenure_num
--   ,chn.tenure_year
--   ,chn.chain_type
--   -- ,'Acquisition' AS chain_type
--   ,coh.has_ads_eom AS has_ads
--   ,MIN(chn.cohort_start_date)  AS  cohort_start_date
--   ,MAX(chn.cohort_end_date)  AS    cohort_end_date
--   ,MIN(chn.tenure_start_date)  AS  tenure_start_date
--   ,MAX(chn.tenure_end_date)  AS    tenure_end_date
--   ,CAST(SUM(chn.new_customers_sum) AS INT) AS       new_customers_sum  -- LOOK still need to set Q1 as baseline.
--   ,CAST(AVG(chn.new_customers_sum) AS INT) AS       new_customers_avg
--   ,CAST(SUM(chn.retained_customers_sum) AS INT) AS  retained_customers_sum
--   ,CAST(AVG(chn.retained_customers_sum) AS INT) AS  retained_customers_avg
--   ,SUM(chn.new_mrr) AS                 new_mrr
--   ,SUM(chn.retained_mrr) AS            retained_mrr
-- FROM
--                tmp_data_dm.coe_churn_by_cohort chn
--     INNER JOIN dm.month_dim m1
--             ON chn.cohort_num = m1.year_month
-- GROUP BY 1,2,3,4,5,6,7,8 ;

----
-- OK so here is what I thought:
-- Have a final pass over the data that identifies the new
-- customers.  That way I can do first_value, and set that
-- as baseline.
-- If I do that part right, then everything is average monthly,
-- and a final quarter that is not complete might be ok.

Ah yeah can see the problem already.  The average is average of the 
lowest grain.
Hmmm also something about when we want to get the Q1 baseline values,
need to be careful of chain_id because by definition I want the
starting values to ignore chain_id.  Ugh.
OK and have to do the baselining not only for customers but for mrr.
OK hold on.  Maybe I do not have to do this as averages, as long
as I am resetting the Cohort1 values.
Does that help?
Let''s try:
-- - Implement everything as SUM (put it in avg now so I don''t have to change much in tableau yet).
-- - Run another version with attributes and compare.  O wait nvr mind it will not work because of FIRST_VALUE.  ???

-- - OK wait! Returns count same as acquisition, and cohort is the 
--   chain cohort.  And ok to not be able to split those out if that
--   makes it ugly.  In fact he currently just rolls them in and does
--   not split them out (when doing equivalent of churn spreadsheet).
-- - Make year rollup too.
-- - Do need to allow for only complete quarters (both cohort and tenure)
--   because I am not precalaulating averages.  Ah but if I go back to
--   average does that allow me to show partial quarters?  Try this.
--   Yeah that is worth it.  Screw the extra attributes, partial quarters
--   are more compelling.

OK waaaay simplifying.
has_ads goes away.
Acquisition vs. Return goes away.
(except maybe for a test run to compare)

-- - Hey BTW I want to make my own month_dim with month and quarter
--   start and end dates and number of days.

OK I am pretty good with the calcs now and baselining first quarter.
- See if I can make it filter to full tenure quarters, because the
  ratio works with non-full quarters, but absolute numbers do not.
-- - Change date filter end date to current month - 1.



-- One row per (cohort, tenure) (and conceptually by cohort_type,
-- since different types of cohort have different formats for the 
-- cohort field.)
-- The reason for the final pass after building the raw table is
-- that for average customers I have to turn the Cohort1 value into
-- the baseline (only a problem for quarter). 
-- This is pretty brittle - since I am taking the average in SQL, 
-- I can''t add attributes.

DROP TABLE IF EXISTS tmp_data_dm.coe_churn_by_cohort_raw ;
CREATE TABLE tmp_data_dm.coe_churn_by_cohort_raw AS
SELECT
   'Month acq only' AS              cohort_type
  ,ym.cohort_month AS      cohort
  ,CAST(ym.cohort_month_num AS INT) AS  cohort_num
  ,ym.cohort_year
  ,CONCAT('M',LPAD(CAST(ym.tenure_month AS STRING),2,'0')) AS  tenure
  ,                CAST(ym.tenure_month AS INT) AS         tenure_num
  ,CAST(FLOOR((ym.tenure_month-1)/12)+1 AS INT) AS         tenure_year
  ,ym.cohort_start_date
  ,ym.cohort_end_date
  ,                CAST(ym.tenure_month AS INT) AS         tenure_mid_num
  ,ym.tenure_start_date
  ,ym.tenure_end_date
  ,ym.tenure_year_month
  ,COUNT(*) AS                        new_customers_sum
  -- ,COUNT(*) AS                        new_customers_avg
  ,COUNT(mth.customer_id) AS          retained_customers_sum
  ,COUNT(mth.customer_id) AS          retained_customers_avg
  ,SUM(coh.mrr_current_total) AS      new_mrr_sum
  ,SUM(mth.mrr_current_total) AS      retained_mrr_sum
  ,SUM(mth.mrr_current_total) AS      retained_mrr_avg
FROM
    tmp_data_dm.coe_jrr_backfill_customer_mrr coh
  INNER JOIN
    (
    SELECT DISTINCT 
       m1.year_month AS        cohort_month_num
      ,m1.month_label AS       cohort_month
      ,m1.year AS              cohort_year
      ,m1.month_begin_date AS  cohort_start_date
      ,m1.month_end_date AS    cohort_end_date
      ,m2.year_month AS        tenure_year_month
      ,1+(FLOOR(m2.year_month/100)-FLOOR(m1.year_month/100)) * 12 +
               (m2.year_month%100-       m1.year_month%100) AS tenure_month
      ,m2.month_begin_date AS  tenure_start_date
      ,m2.month_end_date AS    tenure_end_date

    FROM       tmp_data_dm.coe_my_month_dim m1
    INNER JOIN tmp_data_dm.coe_my_month_dim m2 ON m1.year_month <= m2.year_month
    WHERE m1.month_end_date BETWEEN '2013-04-01' AND NOW()
      AND m2.month_end_date BETWEEN '2013-04-01' AND NOW()
     ) ym
          ON coh.year_month = ym.cohort_month_num
  LEFT OUTER JOIN tmp_data_dm.coe_jrr_backfill_customer_mrr mth
          ON coh.customer_id = mth.customer_id
         AND coh.chain_number = mth.chain_number
         AND  ym.tenure_year_month = mth.year_month
         AND mth.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
WHERE coh.tenure_month_chain = 1
  AND coh.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
  AND coh.chain_number = 1
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13 ;

INSERT INTO tmp_data_dm.coe_churn_by_cohort_raw  -- LOOK this is dropping out
SELECT
   'Quarter acq only' AS     cohort_type
  ,m1.qtr_label AS           cohort
  ,m1.year_qtr AS            cohort_num
  ,chn.cohort_year
  ,CONCAT('Q',CAST(FLOOR((chn.tenure_num-1)/3)+1 AS STRING)) AS tenure
  ,           CAST(FLOOR((chn.tenure_num-1)/3)+1 AS INT) AS tenure_num
  ,chn.tenure_year
  ,m1.qtr_begin_date  AS  cohort_start_date
  ,m1.qtr_end_date  AS    cohort_end_date
  ,CAST(FLOOR(AVG(chn.tenure_mid_num)) AS INT)  AS  tenure_mid_num
  ,MIN(m2.qtr_begin_date)  AS  tenure_start_date  -- LOOK I don''t know if this changes granularity
  ,MAX(m2.qtr_end_date)  AS    tenure_end_date
  ,MAX(NULL) AS                    tenure_year_month
  ,CAST(SUM(chn.new_customers_sum) AS INT) AS       new_customers_sum
  -- ,CAST(AVG(chn.new_customers_sum) AS INT) AS       new_customers_avg
  ,CAST(SUM(chn.retained_customers_sum) AS INT) AS  retained_customers_sum
  ,CAST(AVG(chn.retained_customers_sum) AS INT) AS  retained_customers_avg
  ,CAST(SUM(chn.new_mrr_sum) AS DECIMAL(20,2)) AS             new_mrr_sum
  -- ,SUM(chn.retained_mrr) AS            retained_mrr
  ,CAST(SUM(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS        retained_mrr_sum
  ,CAST(AVG(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS        retained_mrr_avg
FROM
               tmp_data_dm.coe_churn_by_cohort_raw chn
    INNER JOIN tmp_data_dm.coe_my_month_dim m1
            ON chn.cohort_num = m1.year_month
    INNER JOIN tmp_data_dm.coe_my_month_dim m2
            ON chn.tenure_year_month = m2.year_month
WHERE chn.cohort_type = 'Month acq only'
GROUP BY 1,2,3,4,5,6,7,8,9 ;

INSERT INTO tmp_data_dm.coe_churn_by_cohort_raw
SELECT
   'Month acq and ret' AS               cohort_type
  ,ym.cohort_month AS                   cohort
  ,CAST(ym.cohort_month_num AS INT) AS  cohort_num
  ,ym.cohort_year
  ,CONCAT('M',LPAD(CAST(ym.tenure_month AS STRING),2,'0')) AS  tenure
  ,                CAST(ym.tenure_month AS INT) AS         tenure_num
  ,CAST(FLOOR((ym.tenure_month-1)/12)+1 AS INT) AS         tenure_year
  ,ym.cohort_start_date
  ,ym.cohort_end_date
  ,                CAST(ym.tenure_month AS INT) AS         tenure_mid_num
  ,ym.tenure_start_date
  ,ym.tenure_end_date
  ,ym.tenure_year_month
  ,COUNT(*) AS                        new_customers_sum
  -- ,COUNT(*) AS                        new_customers_avg
  ,COUNT(mth.customer_id) AS          retained_customers_sum
  ,COUNT(mth.customer_id) AS          retained_customers_avg
  ,SUM(coh.mrr_current_total) AS      new_mrr_sum
  ,SUM(mth.mrr_current_total) AS      retained_mrr_sum
  ,SUM(mth.mrr_current_total) AS      retained_mrr_avg
FROM
    tmp_data_dm.coe_jrr_backfill_customer_mrr coh
  INNER JOIN
    (
    SELECT DISTINCT 
       m1.year_month AS        cohort_month_num
      ,m1.month_label AS       cohort_month
      ,m1.year AS              cohort_year
      ,m1.month_begin_date AS  cohort_start_date
      ,m1.month_end_date AS    cohort_end_date
      ,m2.year_month AS        tenure_year_month
      ,1+(FLOOR(m2.year_month/100)-FLOOR(m1.year_month/100)) * 12 +
               (m2.year_month%100-       m1.year_month%100) AS tenure_month
      ,m2.month_begin_date AS  tenure_start_date
      ,m2.month_end_date AS    tenure_end_date
    FROM       tmp_data_dm.coe_my_month_dim m1
    INNER JOIN tmp_data_dm.coe_my_month_dim m2 ON m1.year_month <= m2.year_month
    WHERE m1.month_end_date BETWEEN '2013-04-01' AND NOW()
      AND m2.month_end_date BETWEEN '2013-04-01' AND NOW()
    ) ym
          ON coh.year_month = ym.cohort_month_num
  LEFT OUTER JOIN tmp_data_dm.coe_jrr_backfill_customer_mrr mth
          ON coh.customer_id = mth.customer_id
         AND coh.chain_number = mth.chain_number
         AND  ym.tenure_year_month = mth.year_month
         AND mth.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
WHERE coh.tenure_month_chain = 1
  AND coh.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
  -- AND coh.chain_number = 1
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13 ;

INSERT INTO tmp_data_dm.coe_churn_by_cohort_raw
SELECT
   'Quarter acq and ret' AS  cohort_type
  ,m1.qtr_label AS           cohort
  ,m1.year_qtr AS            cohort_num
  ,chn.cohort_year
  ,CONCAT('Q',CAST(FLOOR((chn.tenure_num-1)/3)+1 AS STRING)) AS tenure
  ,           CAST(FLOOR((chn.tenure_num-1)/3)+1 AS INT) AS tenure_num
  ,chn.tenure_year
  ,m1.qtr_begin_date  AS  cohort_start_date
  ,m1.qtr_end_date  AS    cohort_end_date
  ,CAST(FLOOR(AVG(chn.tenure_mid_num)) AS INT)  AS  tenure_mid_num
  ,MIN(m2.qtr_begin_date)  AS  tenure_start_date  -- LOOK I don''t know if this changes granularity
  ,MAX(m2.qtr_end_date)  AS    tenure_end_date
  ,MAX(NULL) AS                    tenure_year_month
  ,CAST(SUM(chn.new_customers_sum) AS INT) AS       new_customers_sum
  -- ,CAST(AVG(chn.new_customers_sum) AS INT) AS       new_customers_avg
  ,CAST(SUM(chn.retained_customers_sum) AS INT) AS  retained_customers_sum
  ,CAST(AVG(chn.retained_customers_sum) AS INT) AS  retained_customers_avg
  ,CAST(SUM(chn.new_mrr_sum) AS DECIMAL(20,2)) AS             new_mrr_sum
  -- ,SUM(chn.retained_mrr) AS            retained_mrr
  ,CAST(SUM(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS        retained_mrr_sum
  ,CAST(AVG(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS        retained_mrr_avg
FROM
               tmp_data_dm.coe_churn_by_cohort_raw chn
    INNER JOIN tmp_data_dm.coe_my_month_dim m1
            ON chn.cohort_num = m1.year_month
    INNER JOIN tmp_data_dm.coe_my_month_dim m2
            ON chn.tenure_year_month = m2.year_month
WHERE chn.cohort_type = 'Month acq and ret'
GROUP BY 1,2,3,4,5,6,7,8,9 ;

INSERT INTO tmp_data_dm.coe_churn_by_cohort_raw
SELECT
   'Year acq and ret' AS               cohort_type
  ,CAST(chn.cohort_year AS STRING) AS  cohort
  ,chn.cohort_year AS                  cohort_num
  ,chn.cohort_year
  ,CAST(chn.tenure_year AS STRING) AS  tenure
  ,chn.tenure_year AS                  tenure_num
  ,chn.tenure_year
  ,m1.year_begin_date  AS  cohort_start_date
  ,m1.year_end_date  AS    cohort_end_date
  ,CAST(FLOOR(AVG(chn.tenure_mid_num)) AS INT)  AS  tenure_mid_num
  ,MIN(m2.year_begin_date)  AS  tenure_start_date  -- LOOK I don''t know if this changes granularity
  ,MAX(m2.year_end_date)  AS    tenure_end_date
  ,MAX(NULL) AS                    tenure_year_month
  ,CAST(SUM(chn.new_customers_sum) AS INT) AS       new_customers_sum
  -- ,CAST(AVG(chn.new_customers_sum) AS INT) AS       new_customers_avg
  ,CAST(SUM(chn.retained_customers_sum) AS INT) AS  retained_customers_sum
  ,CAST(AVG(chn.retained_customers_sum) AS INT) AS  retained_customers_avg
  ,CAST(SUM(chn.new_mrr_sum) AS DECIMAL(20,2)) AS             new_mrr_sum
  -- ,SUM(chn.retained_mrr) AS            retained_mrr
  ,CAST(SUM(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS        retained_mrr_sum
  ,CAST(AVG(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS        retained_mrr_avg
FROM
               tmp_data_dm.coe_churn_by_cohort_raw chn
    INNER JOIN tmp_data_dm.coe_my_month_dim m1
            ON chn.cohort_num = m1.year_month
    INNER JOIN tmp_data_dm.coe_my_month_dim m2
            ON chn.tenure_year_month = m2.year_month
WHERE chn.cohort_type = 'Month acq and ret'
GROUP BY 1,2,3,4,5,6,7,8,9 ;

DROP TABLE IF EXISTS tmp_data_dm.coe_churn_by_cohort ;
CREATE TABLE tmp_data_dm.coe_churn_by_cohort AS
SELECT
   cohort_type
  ,cohort
  ,cohort_num
  ,cohort_year
  ,tenure
  ,tenure_num
  ,tenure_year
  ,tenure_mid_num
  ,cohort_start_date
  ,cohort_end_date
  ,tenure_start_date
  ,tenure_end_date
  ,CASE WHEN cohort_end_date < NOW() AND tenure_end_date < NOW() THEN 'Y' ELSE 'N' END AS is_period_complete
  ,new_customers_sum
  ,FIRST_VALUE(retained_customers_avg) OVER(PARTITION BY cohort_type, cohort_num
                                                ORDER BY tenure_num) AS new_customers_avg
  ,retained_customers_sum
  ,retained_customers_avg
  ,new_mrr_sum
  ,FIRST_VALUE(retained_mrr_avg) OVER(PARTITION BY cohort_type, cohort_num
                                      ORDER BY tenure_num) AS new_mrr_avg
  ,retained_mrr_sum
  ,retained_mrr_avg
FROM tmp_data_dm.coe_churn_by_cohort_raw
WHERE cohort_type IN ('Month acq only', 'Quarter acq only') ;
