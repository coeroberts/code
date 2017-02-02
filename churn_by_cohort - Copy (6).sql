-- Note somehting here about churn math.

SELECT * FROM
(
  SELECT DISTINCT 
     m1.year_month AS        cohort_year_month
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
)

-- One row per (cust_type, cohort, tenure) (and conceptually by 
-- cohort_type, since different types of cohort have different 
-- formats for the cohort field.)
-- The reason for the final pass after building the raw table is
-- that for average customers I have to turn the Cohort1 value into
-- the baseline (only a problem for quarter). 
-- This is pretty brittle - since I am taking the average in SQL, 
-- I can''t add attributes because it would not add up right.

DROP TABLE IF EXISTS tmp_data_dm.coe_churn_by_cohort_raw ;
CREATE TABLE tmp_data_dm.coe_churn_by_cohort_raw AS
SELECT
   cohort_type
  ,cust_type
  ,cohort
  ,cohort_num
  ,cohort_year
  ,cohort_length
  ,tenure
  ,tenure_num
  ,cohort_start_date
  ,cohort_end_date
  ,tenure_mid_num
  ,tenure_start_date
  ,tenure_end_date
  ,tenure_year_month
  ,data_months
  ,new_customers_sum
  ,retained_customers_sum
  ,retained_customers_avg
  ,churned_customers_sum
  ,churned_customers_avg
  -- ,LAG(retained_customers_sum) OVER(PARTITION BY cust_type, cohort_num 
  --                                       ORDER BY tenure_num) AS prior_month_customers_sum
  ,LAG(retained_customers_avg) OVER(PARTITION BY cust_type, cohort_num 
                                        ORDER BY tenure_num) AS prior_month_customers_avg
  ,new_mrr_sum
  ,retained_mrr_sum
  ,retained_mrr_avg
  ,churned_mrr_sum
  ,churned_mrr_avg
  -- ,LAG(retained_mrr_sum)       OVER(PARTITION BY cust_type, cohort_num 
  --                                       ORDER BY tenure_num) AS prior_month_mrr_sum
  ,LAG(retained_mrr_avg)       OVER(PARTITION BY cust_type, cohort_num 
                                        ORDER BY tenure_num) AS prior_month_mrr_avg
FROM
  (
  SELECT
     'Month' AS              cohort_type
    ,CASE WHEN coh.chain_number = 1 THEN 'Acquired' ELSE 'Returned' END AS cust_type
    ,ym.cohort_month AS      cohort
    ,CAST(ym.cohort_month_num AS INT) AS  cohort_num
    ,ym.cohort_year
    ,1 AS                                 cohort_length
    ,CONCAT('M',LPAD(CAST(ym.tenure_month AS STRING),2,'0')) AS  tenure
    ,                CAST(ym.tenure_month AS INT) AS             tenure_num
    ,ym.cohort_start_date
    ,ym.cohort_end_date
    ,                CAST(ym.tenure_month AS INT) AS             tenure_mid_num
    ,ym.tenure_start_date
    ,ym.tenure_end_date
    ,ym.tenure_year_month
    ,CAST(1 AS BIGINT) AS               data_months
    ,COUNT(CASE WHEN mth.mrr_customer_category <> 'CHURNED' THEN coh.customer_id ELSE NULL END) AS      new_customers_sum
    ,COUNT(CASE WHEN mth.mrr_customer_category <> 'CHURNED' THEN mth.customer_id ELSE NULL END) AS      retained_customers_sum
    ,COUNT(CASE WHEN mth.mrr_customer_category <> 'CHURNED' THEN mth.customer_id ELSE NULL END) AS      retained_customers_avg
    ,-1 * COUNT(CASE WHEN mth.mrr_customer_category = 'CHURNED' THEN mth.customer_id ELSE NULL END) AS  churned_customers_sum
    ,-1 * COUNT(CASE WHEN mth.mrr_customer_category = 'CHURNED' THEN mth.customer_id ELSE NULL END) AS  churned_customers_avg
    ,SUM(CASE WHEN mth.mrr_customer_category <> 'CHURNED' THEN coh.mrr_current_total ELSE NULL END) AS  new_mrr_sum
    ,SUM(CASE WHEN mth.mrr_customer_category <> 'CHURNED' THEN mth.mrr_current_total ELSE NULL END) AS  retained_mrr_sum
    ,SUM(CASE WHEN mth.mrr_customer_category <> 'CHURNED' THEN mth.mrr_current_total ELSE NULL END) AS  retained_mrr_avg
    ,SUM(CASE WHEN mth.mrr_customer_category = 'CHURNED' THEN mth.mrr_churned ELSE NULL END) AS         churned_mrr_sum
    ,SUM(CASE WHEN mth.mrr_customer_category = 'CHURNED' THEN mth.mrr_churned ELSE NULL END) AS         churned_mrr_avg
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
           -- AND mth.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
           AND mth.mrr_customer_category NOT IN ('NOT BILLED')
  WHERE coh.tenure_month_chain = 1
    AND coh.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
  GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14, 15
) raw ;


INSERT INTO tmp_data_dm.coe_churn_by_cohort_raw
  SELECT
     'Quarter' AS              cohort_type
    ,chn.cust_type
    ,m1.qtr_label AS           cohort
    ,m1.year_qtr AS            cohort_num
    ,chn.cohort_year
    ,3 AS                      cohort_length
    ,CONCAT('Q',CAST(FLOOR((chn.tenure_num-1)/3)+1 AS STRING)) AS tenure
    ,           CAST(FLOOR((chn.tenure_num-1)/3)+1 AS INT) AS     tenure_num
    ,m1.qtr_begin_date  AS                                cohort_start_date
    ,m1.qtr_end_date  AS                                  cohort_end_date
    ,CAST(FLOOR(AVG(chn.tenure_mid_num)) AS INT)  AS      tenure_mid_num
    ,MIN(m2.qtr_begin_date)  AS                           tenure_start_date
    ,MAX(m2.qtr_end_date)  AS                             tenure_end_date  -- wow if this works it is only by chance.  think that is why stuff looks weird.
    ,MAX(NULL) AS                                         tenure_year_month
    ,SUM(chn.data_months) AS                              data_months
    ,CAST(SUM(chn.new_customers_sum) AS INT) AS           new_customers_sum
    ,CAST(SUM(chn.retained_customers_sum) AS INT) AS      retained_customers_sum
    ,CAST(AVG(chn.retained_customers_avg) AS INT) AS      retained_customers_avg
    ,CAST(SUM(chn.churned_customers_sum) AS INT) AS       churned_customers_sum
    ,CAST(AVG(chn.churned_customers_avg) AS INT) AS       churned_customers_avg
    -- ,CAST(SUM(chn.prior_month_customers_sum) AS INT) AS      prior_month_customers_sum
    ,CAST(AVG(chn.prior_month_customers_avg) AS INT) AS      prior_month_customers_avg
    ,CAST(SUM(chn.new_mrr_sum) AS DECIMAL(20,2)) AS       new_mrr_sum
    ,CAST(SUM(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS  retained_mrr_sum
    ,CAST(AVG(chn.retained_mrr_avg) AS DECIMAL(20,2)) AS  retained_mrr_avg
    ,CAST(SUM(chn.churned_mrr_sum) AS DECIMAL(20,2)) AS   churned_mrr_sum
    ,CAST(AVG(chn.churned_mrr_avg) AS DECIMAL(20,2)) AS   churned_mrr_avg
    -- ,CAST(SUM(chn.prior_month_mrr_sum) AS DECIMAL(20,2)) AS  prior_month_mrr_sum
    ,CAST(AVG(chn.prior_month_mrr_avg) AS DECIMAL(20,2)) AS  prior_month_mrr_avg
  FROM
                 tmp_data_dm.coe_churn_by_cohort_raw chn
      INNER JOIN tmp_data_dm.coe_my_month_dim m1
              ON chn.cohort_num = m1.year_month
      INNER JOIN tmp_data_dm.coe_my_month_dim m2
              ON chn.tenure_year_month = m2.year_month
  WHERE chn.cohort_type = 'Month'
  GROUP BY 1,2,3,4,5,6,7,8,9,10 ;

INSERT INTO tmp_data_dm.coe_churn_by_cohort_raw
  SELECT
     'Year' AS                           cohort_type
    ,chn.cust_type
    ,CAST(chn.cohort_year AS STRING) AS  cohort
    ,chn.cohort_year AS                  cohort_num
    ,chn.cohort_year
    ,12 AS                               cohort_length
    ,CONCAT('Y',CAST(FLOOR((chn.tenure_num-1)/12)+1 AS STRING)) AS tenure
    ,           CAST(FLOOR((chn.tenure_num-1)/12)+1 AS INT) AS     tenure_num
    ,m1.year_begin_date  AS                               cohort_start_date
    ,m1.year_end_date  AS                                 cohort_end_date
    ,CAST(FLOOR(AVG(chn.tenure_mid_num)) AS INT)  AS      tenure_mid_num
    ,MIN(m2.year_begin_date)  AS                          tenure_start_date
    ,MAX(m2.year_end_date)  AS                            tenure_end_date
    ,MAX(NULL) AS                                         tenure_year_month
    ,SUM(chn.data_months) AS                              data_months
    ,CAST(SUM(chn.new_customers_sum) AS INT) AS           new_customers_sum
    ,CAST(SUM(chn.retained_customers_sum) AS INT) AS      retained_customers_sum
    ,CAST(AVG(chn.retained_customers_avg) AS INT) AS      retained_customers_avg
    ,CAST(SUM(chn.churned_customers_sum) AS INT) AS       churned_customers_sum
    ,CAST(AVG(chn.churned_customers_avg) AS INT) AS       churned_customers_avg
    -- ,CAST(SUM(chn.prior_month_customers_sum) AS INT) AS      prior_month_customers_sum
    ,CAST(AVG(chn.prior_month_customers_avg) AS INT) AS      prior_month_customers_avg
    ,CAST(SUM(chn.new_mrr_sum) AS DECIMAL(20,2)) AS       new_mrr_sum
    ,CAST(SUM(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS  retained_mrr_sum
    ,CAST(AVG(chn.retained_mrr_avg) AS DECIMAL(20,2)) AS  retained_mrr_avg
    ,CAST(SUM(chn.churned_mrr_sum) AS DECIMAL(20,2)) AS   churned_mrr_sum
    ,CAST(AVG(chn.churned_mrr_avg) AS DECIMAL(20,2)) AS   churned_mrr_avg
    -- ,CAST(SUM(chn.prior_month_mrr_sum) AS DECIMAL(20,2)) AS  prior_month_mrr_sum
    ,CAST(AVG(chn.prior_month_mrr_avg) AS DECIMAL(20,2)) AS  prior_month_mrr_avg
  FROM
                 tmp_data_dm.coe_churn_by_cohort_raw chn
      INNER JOIN tmp_data_dm.coe_my_month_dim m1
              ON chn.cohort_num = m1.year_month
      INNER JOIN tmp_data_dm.coe_my_month_dim m2
              ON chn.tenure_year_month = m2.year_month
  WHERE chn.cohort_type = 'Month'
  GROUP BY 1,2,3,4,5,6,7,8,9,10 ;

DROP TABLE IF EXISTS tmp_data_dm.coe_churn_by_cohort ;
CREATE TABLE tmp_data_dm.coe_churn_by_cohort AS
SELECT
   cohort_type
  ,cust_type
  ,cohort
  ,cohort_num
  ,cohort_year
  ,tenure
  ,tenure_num
  ,tenure_mid_num
  ,cohort_start_date
  ,cohort_end_date
  ,cohort_should_end_date
  ,tenure_start_date
  ,tenure_end_date
  ,tenure_should_end_date
  ,data_months
  ,CASE WHEN cohort_end_date        < NOW() AND tenure_end_date < NOW()
         AND cohort_end_date = cohort_should_end_date AND tenure_end_date = tenure_should_end_date
     THEN 'Ended' ELSE 'Incomplete' END AS period_ended_status
  ,new_customers_sum
  ,FIRST_VALUE(retained_customers_avg) OVER(PARTITION BY cohort_type, cust_type, cohort_num
                                                ORDER BY tenure_num) AS new_customers_avg
  ,retained_customers_sum
  ,retained_customers_avg
  ,CASE WHEN tenure_num = 1 THEN 0 ELSE churned_customers_sum END AS churned_customers_sum
  ,CASE WHEN tenure_num = 1 THEN 0 ELSE churned_customers_avg END AS churned_customers_avg
  -- ,prior_month_customers_sum
  ,prior_month_customers_avg
  ,new_mrr_sum
  ,FIRST_VALUE(retained_mrr_avg) OVER(PARTITION BY cohort_type, cust_type, cohort_num
                                      ORDER BY tenure_num) AS new_mrr_avg
  ,retained_mrr_sum
  ,retained_mrr_avg
  ,CASE WHEN tenure_num = 1 THEN 0 ELSE churned_mrr_sum END AS churned_mrr_sum
  ,CASE WHEN tenure_num = 1 THEN 0 ELSE churned_mrr_avg END AS churned_mrr_avg
  -- ,prior_month_mrr_sum
  ,prior_month_mrr_avg
FROM
  (
  -- Funny thing going on here.  If we add up across all cohort months
  -- and calendar months, we end up with numbers too high.  Conceptually,
  -- we want to add up the values for all months in the cohort, and then
  -- average across tenure months in the tenure period.
  -- The math here only works if cohort period length = tenure period length.
  -- It is possible to compute if they are different, but the math 
  -- would have to get more complicated.
  -- Note that the churned metrics are activity metrics over the period,
  -- not state metrics at a point in time, so they get a simple sum
  -- (no adjustment).
  SELECT
     raw.cohort_type
    ,raw.cust_type
    ,raw.cohort
    ,raw.cohort_num
    ,raw.cohort_year
    ,raw.tenure
    ,raw.tenure_num
    ,raw.cohort_start_date
    ,raw.cohort_end_date
    ,from_unixtime(unix_timestamp(
       CAST(raw.cohort_start_date AS TIMESTAMP) + INTERVAL cohort_length MONTH - INTERVAL 1 DAY)
      ,'yyyy-MM-dd') AS  cohort_should_end_date
    ,raw.tenure_mid_num
    ,raw.tenure_start_date
    ,raw.tenure_end_date
    ,from_unixtime(unix_timestamp(
       CAST(raw.tenure_start_date AS TIMESTAMP) + INTERVAL cohort_length MONTH - INTERVAL 1 DAY)
      ,'yyyy-MM-dd') AS  tenure_should_end_date
    ,raw.tenure_year_month
    ,raw.data_months
    ,raw.new_customers_sum / (data_months/cohort_length) AS          new_customers_sum
    ,raw.retained_customers_sum / (data_months/cohort_length) AS     retained_customers_sum
    ,raw.retained_customers_avg
    ,raw.churned_customers_sum
    ,raw.churned_customers_avg
    -- ,raw.prior_month_customers_sum / (data_months/cohort_length) AS  prior_month_customers_sum
    ,raw.prior_month_customers_avg
    ,raw.new_mrr_sum / (data_months/cohort_length) AS                new_mrr_sum
    ,raw.retained_mrr_sum / (data_months/cohort_length) AS           retained_mrr_sum
    ,raw.retained_mrr_avg
    ,raw.churned_mrr_sum
    ,raw.churned_mrr_avg
    -- ,raw.prior_month_mrr_sum / (data_months/cohort_length) AS        prior_month_mrr_sum
    ,raw.prior_month_mrr_avg
  FROM tmp_data_dm.coe_churn_by_cohort_raw raw
  ) prd ;

Nope not quite right on should end stuff - it is not just start + cohort_length;
it is something like start + that squared or something weird.
OK back to driving table.
Square 1: goals
1. Do not screw up current stuff.
2. Detect period complete.
Is that all?

