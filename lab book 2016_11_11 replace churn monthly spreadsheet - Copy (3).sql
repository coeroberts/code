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

DROP TABLE IF EXISTS tmp_data_dm.coe_churn_by_cohort ;
CREATE TABLE tmp_data_dm.coe_churn_by_cohort AS
SELECT
   ym.cohort_month
  ,ym.cohort_month_num
  ,ym.cohort_quarter
  ,ym.cohort_quarter_num
  ,ym.cohort_year
  ,CONCAT('M',LPAD(CAST(ym.tenure_month AS STRING),2,'0')) AS    tenure_month
  ,                     ym.tenure_month AS                       tenure_month_num
  ,CONCAT('Q',CAST(FLOOR((ym.tenure_month-1)/3)+1 AS STRING)) AS tenure_quarter
  ,                FLOOR((ym.tenure_month-1)/3)+1 AS             tenure_quarter_num
  ,FLOOR((ym.tenure_month-1)/12)+1 AS tenure_year
  -- ,CONCAT('Q',CAST(FLOOR(ym.tenure_month/3)+1 AS STRING)) AS tenure_quarter
  ,ym.calendar_month
  ,ym.calendar_month_num
  ,ym.calendar_quarter
  ,ym.calendar_quarter_num
  ,ym.calendar_year
  ,CASE WHEN coh.chain_number = 1 THEN 'Acquisition' ELSE 'Return' END AS chain_type
  ,coh.has_ads_eom AS has_ads
  ,COUNT(*) AS                                new_customers
  ,COUNT(mth.customer_id) AS                  retained_customers
  ,SUM(coh.mrr_current_advertisement) AS      new_mrr
  ,SUM(mth.mrr_current_advertisement) AS      retained_mrr
FROM
    tmp_data_dm.coe_jrr_backfill_customer_mrr coh
  INNER JOIN
    (
    SELECT DISTINCT 
       m1.year_month AS cohort_month_num
      ,CONCAT(CAST(FLOOR(m1.year_month/100) AS STRING), '-',LPAD(CAST(m1.year_month%100 AS STRING),2,'0')) AS cohort_month
      ,m1.year*10 + m1.qtr_nbr_in_year AS cohort_quarter_num
      ,CONCAT('FY', CAST(m1.year % 2000 AS STRING), ' Q', CAST(m1.qtr_nbr_in_year AS STRING)) AS cohort_quarter
      ,m1.year AS cohort_year

      ,m2.year_month AS calendar_month_num
      ,CONCAT(CAST(FLOOR(m2.year_month/100) AS STRING), '-',LPAD(CAST(m2.year_month%100 AS STRING),2,'0')) AS calendar_month
      ,m2.year*10 + m2.qtr_nbr_in_year AS calendar_quarter_num
      ,CONCAT('FY', CAST(m2.year % 2000 AS STRING), ' Q', CAST(m2.qtr_nbr_in_year AS STRING)) AS calendar_quarter
      ,m2.year AS calendar_year

      ,1+(FLOOR(m2.year_month/100)-FLOOR(m1.year_month/100)) * 12 +
               (m2.year_month%100-       m1.year_month%100) AS tenure_month
    FROM dm.month_dim m1
    INNER JOIN dm.month_dim m2 ON m1.year_month <= m2.year_month  
    WHERE m1.year_month BETWEEN 201304 AND 201610
      AND m2.year_month BETWEEN 201304 AND 201610
    ) ym
          ON coh.year_month = ym.cohort_month_num
  LEFT OUTER JOIN tmp_data_dm.coe_jrr_backfill_customer_mrr mth
          ON coh.customer_id = mth.customer_id
         AND coh.chain_number = mth.chain_number
         AND  ym.calendar_month_num = mth.year_month
         AND mth.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
         AND mth.has_ads_eom = 'Y'
WHERE coh.tenure_month_chain = 1
  AND coh.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
  -- AND coh.has_ads_eom = 'Y'  -- LOOK
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17

Add churned customers so I can look at churn %.
Old ss calcs churn % as % of start.

Q1 has MRR Retention % > 100%.
Well shoot.  If you take months 1-3, new will not = retained
(in the way that it will if you are only looking at M1).
Ah!  So actually maybe it is ok.  I am just getting rid of the first
column (Q0) in each of the tables.

Was going to move string formatting into Tableau, but the ones from
SQL are SO much faster, sticking with that.

Want to remove chain_number filter and add a variable specifying
acquisition or return chain.
Done.

Sayle feedback
- cohort for returned is still acq cohort
- look at 2013 q4 and such cohorts mrr table
- Fix math so first quarter is always 100%.
  (probably involved in averaging 3 months for customers and such)
