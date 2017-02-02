-- -- One row per (cohort, tenure) (and conceptually by cohort_type,      LOOK update me!
-- -- since different types of cohort have different formats for the 
-- -- cohort field.)
-- -- The reason for the final pass after building the raw table is
-- -- that for average customers I have to turn the Cohort1 value into
-- -- the baseline (only a problem for quarter). 
-- -- This is pretty brittle - since I am taking the average in SQL, 
-- -- I can''t add attributes because it would not add up right.

-- DROP TABLE IF EXISTS tmp_data_dm.coe_churn_by_cohort_raw ;
-- CREATE TABLE tmp_data_dm.coe_churn_by_cohort_raw AS
-- SELECT
--    'Month acq only' AS              cohort_type
--   ,ym.cohort_month AS      cohort
--   ,CAST(ym.cohort_month_num AS INT) AS  cohort_num
--   ,ym.cohort_year
--   ,CONCAT('M',LPAD(CAST(ym.tenure_month AS STRING),2,'0')) AS  tenure
--   ,                CAST(ym.tenure_month AS INT) AS         tenure_num
--   ,CAST(FLOOR((ym.tenure_month-1)/12)+1 AS INT) AS         tenure_year
--   ,ym.cohort_start_date
--   ,ym.cohort_end_date
--   ,                CAST(ym.tenure_month AS INT) AS         tenure_mid_num
--   ,ym.tenure_start_date
--   ,ym.tenure_end_date
--   ,ym.tenure_year_month
--   ,COUNT(*) AS                        new_customers_sum
--   -- ,COUNT(*) AS                        new_customers_avg
--   ,COUNT(mth.customer_id) AS          retained_customers_sum
--   ,COUNT(mth.customer_id) AS          retained_customers_avg
--   ,SUM(coh.mrr_current_total) AS      new_mrr_sum
--   ,SUM(mth.mrr_current_total) AS      retained_mrr_sum
--   ,SUM(mth.mrr_current_total) AS      retained_mrr_avg
-- FROM
--     tmp_data_dm.coe_jrr_backfill_customer_mrr coh
--   INNER JOIN
--     (
--     SELECT DISTINCT 
--        m1.year_month AS        cohort_month_num
--       ,m1.month_label AS       cohort_month
--       ,m1.year AS              cohort_year
--       ,m1.month_begin_date AS  cohort_start_date
--       ,m1.month_end_date AS    cohort_end_date
--       ,m2.year_month AS        tenure_year_month
--       ,1+(FLOOR(m2.year_month/100)-FLOOR(m1.year_month/100)) * 12 +
--                (m2.year_month%100-       m1.year_month%100) AS tenure_month
--       ,m2.month_begin_date AS  tenure_start_date
--       ,m2.month_end_date AS    tenure_end_date

--     FROM       tmp_data_dm.coe_my_month_dim m1
--     INNER JOIN tmp_data_dm.coe_my_month_dim m2 ON m1.year_month <= m2.year_month
--     WHERE m1.month_end_date BETWEEN '2013-04-01' AND NOW()
--       AND m2.month_end_date BETWEEN '2013-04-01' AND NOW()
--      ) ym
--           ON coh.year_month = ym.cohort_month_num
--   LEFT OUTER JOIN tmp_data_dm.coe_jrr_backfill_customer_mrr mth
--           ON coh.customer_id = mth.customer_id
--          AND coh.chain_number = mth.chain_number
--          AND  ym.tenure_year_month = mth.year_month
--          AND mth.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
-- WHERE coh.tenure_month_chain = 1
--   AND coh.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
--   AND coh.chain_number = 1
-- GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13 ;

-- INSERT INTO tmp_data_dm.coe_churn_by_cohort_raw
-- SELECT
--    'Quarter acq only' AS     cohort_type
--   ,m1.qtr_label AS           cohort
--   ,m1.year_qtr AS            cohort_num
--   ,chn.cohort_year
--   ,CONCAT('Q',CAST(FLOOR((chn.tenure_num-1)/3)+1 AS STRING)) AS tenure
--   ,           CAST(FLOOR((chn.tenure_num-1)/3)+1 AS INT) AS tenure_num
--   ,chn.tenure_year
--   ,m1.qtr_begin_date  AS  cohort_start_date
--   ,m1.qtr_end_date  AS    cohort_end_date
--   ,CAST(FLOOR(AVG(chn.tenure_mid_num)) AS INT)  AS  tenure_mid_num
--   ,MIN(m2.qtr_begin_date)  AS  tenure_start_date  -- Note I don''t know if this changes granularity.  Think it's OK.
--   ,MAX(m2.qtr_end_date)  AS    tenure_end_date
--   ,MAX(NULL) AS                    tenure_year_month
--   ,CAST(SUM(chn.new_customers_sum) AS INT) AS       new_customers_sum
--   -- ,CAST(AVG(chn.new_customers_sum) AS INT) AS       new_customers_avg
--   ,CAST(SUM(chn.retained_customers_sum) AS INT) AS  retained_customers_sum
--   ,CAST(AVG(chn.retained_customers_sum) AS INT) AS  retained_customers_avg
--   ,CAST(SUM(chn.new_mrr_sum) AS DECIMAL(20,2)) AS             new_mrr_sum
--   -- ,SUM(chn.retained_mrr) AS            retained_mrr
--   ,CAST(SUM(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS        retained_mrr_sum
--   ,CAST(AVG(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS        retained_mrr_avg
-- FROM
--                tmp_data_dm.coe_churn_by_cohort_raw chn
--     INNER JOIN tmp_data_dm.coe_my_month_dim m1
--             ON chn.cohort_num = m1.year_month
--     INNER JOIN tmp_data_dm.coe_my_month_dim m2
--             ON chn.tenure_year_month = m2.year_month
-- WHERE chn.cohort_type = 'Month acq only'
-- GROUP BY 1,2,3,4,5,6,7,8,9 ;

-- INSERT INTO tmp_data_dm.coe_churn_by_cohort_raw
-- SELECT
--    'Month acq and ret' AS               cohort_type
--   ,ym.cohort_month AS                   cohort
--   ,CAST(ym.cohort_month_num AS INT) AS  cohort_num
--   ,ym.cohort_year
--   ,CONCAT('M',LPAD(CAST(ym.tenure_month AS STRING),2,'0')) AS  tenure
--   ,                CAST(ym.tenure_month AS INT) AS         tenure_num
--   ,CAST(FLOOR((ym.tenure_month-1)/12)+1 AS INT) AS         tenure_year
--   ,ym.cohort_start_date
--   ,ym.cohort_end_date
--   ,                CAST(ym.tenure_month AS INT) AS         tenure_mid_num
--   ,ym.tenure_start_date
--   ,ym.tenure_end_date
--   ,ym.tenure_year_month
--   ,COUNT(*) AS                        new_customers_sum
--   -- ,COUNT(*) AS                        new_customers_avg
--   ,COUNT(mth.customer_id) AS          retained_customers_sum
--   ,COUNT(mth.customer_id) AS          retained_customers_avg
--   ,SUM(coh.mrr_current_total) AS      new_mrr_sum
--   ,SUM(mth.mrr_current_total) AS      retained_mrr_sum
--   ,SUM(mth.mrr_current_total) AS      retained_mrr_avg
-- FROM
--     tmp_data_dm.coe_jrr_backfill_customer_mrr coh
--   INNER JOIN
--     (
--     SELECT DISTINCT 
--        m1.year_month AS        cohort_month_num
--       ,m1.month_label AS       cohort_month
--       ,m1.year AS              cohort_year
--       ,m1.month_begin_date AS  cohort_start_date
--       ,m1.month_end_date AS    cohort_end_date
--       ,m2.year_month AS        tenure_year_month
--       ,1+(FLOOR(m2.year_month/100)-FLOOR(m1.year_month/100)) * 12 +
--                (m2.year_month%100-       m1.year_month%100) AS tenure_month
--       ,m2.month_begin_date AS  tenure_start_date
--       ,m2.month_end_date AS    tenure_end_date
--     FROM       tmp_data_dm.coe_my_month_dim m1
--     INNER JOIN tmp_data_dm.coe_my_month_dim m2 ON m1.year_month <= m2.year_month
--     WHERE m1.month_end_date BETWEEN '2013-04-01' AND NOW()
--       AND m2.month_end_date BETWEEN '2013-04-01' AND NOW()
--     ) ym
--           ON coh.year_month = ym.cohort_month_num
--   LEFT OUTER JOIN tmp_data_dm.coe_jrr_backfill_customer_mrr mth
--           ON coh.customer_id = mth.customer_id
--          AND coh.chain_number = mth.chain_number
--          AND  ym.tenure_year_month = mth.year_month
--          AND mth.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
-- WHERE coh.tenure_month_chain = 1
--   AND coh.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
--   -- AND coh.chain_number = 1
-- GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13 ;

-- INSERT INTO tmp_data_dm.coe_churn_by_cohort_raw
-- SELECT
--    'Quarter acq and ret' AS  cohort_type
--   ,m1.qtr_label AS           cohort
--   ,m1.year_qtr AS            cohort_num
--   ,chn.cohort_year
--   ,CONCAT('Q',CAST(FLOOR((chn.tenure_num-1)/3)+1 AS STRING)) AS tenure
--   ,           CAST(FLOOR((chn.tenure_num-1)/3)+1 AS INT) AS tenure_num
--   ,chn.tenure_year
--   ,m1.qtr_begin_date  AS  cohort_start_date
--   ,m1.qtr_end_date  AS    cohort_end_date
--   ,CAST(FLOOR(AVG(chn.tenure_mid_num)) AS INT)  AS  tenure_mid_num
--   ,MIN(m2.qtr_begin_date)  AS  tenure_start_date  -- LOOK I don''t know if this changes granularity
--   ,MAX(m2.qtr_end_date)  AS    tenure_end_date
--   ,MAX(NULL) AS                    tenure_year_month
--   ,CAST(SUM(chn.new_customers_sum) AS INT) AS       new_customers_sum
--   -- ,CAST(AVG(chn.new_customers_sum) AS INT) AS       new_customers_avg
--   ,CAST(SUM(chn.retained_customers_sum) AS INT) AS  retained_customers_sum
--   ,CAST(AVG(chn.retained_customers_sum) AS INT) AS  retained_customers_avg
--   ,CAST(SUM(chn.new_mrr_sum) AS DECIMAL(20,2)) AS             new_mrr_sum
--   -- ,SUM(chn.retained_mrr) AS            retained_mrr
--   ,CAST(SUM(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS        retained_mrr_sum
--   ,CAST(AVG(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS        retained_mrr_avg
-- FROM
--                tmp_data_dm.coe_churn_by_cohort_raw chn
--     INNER JOIN tmp_data_dm.coe_my_month_dim m1
--             ON chn.cohort_num = m1.year_month
--     INNER JOIN tmp_data_dm.coe_my_month_dim m2
--             ON chn.tenure_year_month = m2.year_month
-- WHERE chn.cohort_type = 'Month acq and ret'
-- GROUP BY 1,2,3,4,5,6,7,8,9 ;

-- INSERT INTO tmp_data_dm.coe_churn_by_cohort_raw
-- SELECT
--    'Year acq and ret' AS               cohort_type
--   ,CAST(chn.cohort_year AS STRING) AS  cohort
--   ,chn.cohort_year AS                  cohort_num
--   ,chn.cohort_year
--   ,CAST(chn.tenure_year AS STRING) AS  tenure
--   ,chn.tenure_year AS                  tenure_num
--   ,chn.tenure_year
--   ,m1.year_begin_date  AS  cohort_start_date
--   ,m1.year_end_date  AS    cohort_end_date
--   ,CAST(FLOOR(AVG(chn.tenure_mid_num)) AS INT)  AS  tenure_mid_num
--   ,MIN(m2.year_begin_date)  AS  tenure_start_date  -- Note I don''t know if this changes granularity.  Think it's OK.
--   ,MAX(m2.year_end_date)  AS    tenure_end_date
--   ,MAX(NULL) AS                    tenure_year_month
--   ,CAST(SUM(chn.new_customers_sum) AS INT) AS       new_customers_sum
--   -- ,CAST(AVG(chn.new_customers_sum) AS INT) AS       new_customers_avg
--   ,CAST(SUM(chn.retained_customers_sum) AS INT) AS  retained_customers_sum
--   ,CAST(AVG(chn.retained_customers_sum) AS INT) AS  retained_customers_avg
--   ,CAST(SUM(chn.new_mrr_sum) AS DECIMAL(20,2)) AS             new_mrr_sum
--   -- ,SUM(chn.retained_mrr) AS            retained_mrr
--   ,CAST(SUM(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS        retained_mrr_sum
--   ,CAST(AVG(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS        retained_mrr_avg
-- FROM
--                tmp_data_dm.coe_churn_by_cohort_raw chn
--     INNER JOIN tmp_data_dm.coe_my_month_dim m1
--             ON chn.cohort_num = m1.year_month
--     INNER JOIN tmp_data_dm.coe_my_month_dim m2
--             ON chn.tenure_year_month = m2.year_month
-- WHERE chn.cohort_type = 'Month acq and ret'
-- GROUP BY 1,2,3,4,5,6,7,8,9 ;

-- DROP TABLE IF EXISTS tmp_data_dm.coe_churn_by_cohort ;
-- CREATE TABLE tmp_data_dm.coe_churn_by_cohort AS
-- SELECT
--    cohort_type
--   ,cohort
--   ,cohort_num
--   ,cohort_year
--   ,tenure
--   ,tenure_num
--   ,tenure_year
--   ,tenure_mid_num
--   ,cohort_start_date
--   ,cohort_end_date
--   ,tenure_start_date
--   ,tenure_end_date
--   ,CASE WHEN cohort_end_date < NOW() AND tenure_end_date < NOW() THEN 'Complete' ELSE 'Incomplete' END AS period_complete_status
--   ,new_customers_sum
--   ,FIRST_VALUE(retained_customers_avg) OVER(PARTITION BY cohort_type, cohort_num
--                                                 ORDER BY tenure_num) AS new_customers_avg
--   ,retained_customers_sum
--   ,retained_customers_avg
--   ,new_mrr_sum
--   ,FIRST_VALUE(retained_mrr_avg) OVER(PARTITION BY cohort_type, cohort_num
--                                       ORDER BY tenure_num) AS new_mrr_avg
--   ,retained_mrr_sum
--   ,retained_mrr_avg
-- FROM tmp_data_dm.coe_churn_by_cohort_raw
-- WHERE cohort_type IN ('Month acq only', 'Quarter acq only') ;

----

DROP TABLE IF EXISTS tmp_data_dm.coe_churn_by_cohort_raw ;
CREATE TABLE tmp_data_dm.coe_churn_by_cohort_raw AS
SELECT
   'Month' AS              cohort_type
  ,CASE WHEN coh.chain_number = 1 THEN 'Acquired' ELSE 'Returned' END AS cust_type
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
  -- AND coh.chain_number = 1
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14 ;

INSERT INTO tmp_data_dm.coe_churn_by_cohort_raw
SELECT
   'Quarter' AS              cohort_type
  ,chn.cust_type
  ,m1.qtr_label AS           cohort
  ,m1.year_qtr AS            cohort_num
  ,chn.cohort_year
  ,CONCAT('Q',CAST(FLOOR((chn.tenure_num-1)/3)+1 AS STRING)) AS tenure
  ,           CAST(FLOOR((chn.tenure_num-1)/3)+1 AS INT) AS tenure_num
  ,chn.tenure_year
  ,m1.qtr_begin_date  AS                                cohort_start_date
  ,m1.qtr_end_date  AS                                  cohort_end_date
  ,CAST(FLOOR(AVG(chn.tenure_mid_num)) AS INT)  AS      tenure_mid_num
  ,MIN(m2.qtr_begin_date)  AS                           tenure_start_date
  ,MAX(m2.qtr_end_date)  AS                             tenure_end_date
  ,MAX(NULL) AS                                         tenure_year_month
  ,CAST(SUM(chn.new_customers_sum) AS INT) AS           new_customers_sum
  -- ,CAST(AVG(chn.new_customers_sum) AS INT) AS          new_customers_avg
  ,CAST(SUM(chn.retained_customers_sum) AS INT) AS      retained_customers_sum
  ,CAST(AVG(chn.retained_customers_sum) AS INT) AS      retained_customers_avg
  ,CAST(SUM(chn.new_mrr_sum) AS DECIMAL(20,2)) AS       new_mrr_sum
  -- ,SUM(chn.retained_mrr) AS                            retained_mrr
  ,CAST(SUM(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS  retained_mrr_sum
  ,CAST(AVG(chn.retained_mrr_sum) AS DECIMAL(20,2)) AS  retained_mrr_avg
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
  ,tenure_year
  ,tenure_mid_num
  ,cohort_start_date
  ,cohort_end_date
  ,tenure_start_date
  ,tenure_end_date
  ,CASE WHEN cohort_end_date < NOW() AND tenure_end_date < NOW() THEN 'Complete' ELSE 'Incomplete' END AS period_complete_status
  ,new_customers_sum
  ,FIRST_VALUE(retained_customers_avg) OVER(PARTITION BY cohort_type, cust_type, cohort_num
                                                ORDER BY tenure_num) AS new_customers_avg
  ,retained_customers_sum
  ,retained_customers_avg
  ,new_mrr_sum
  ,FIRST_VALUE(retained_mrr_avg) OVER(PARTITION BY cohort_type, cust_type, cohort_num
                                      ORDER BY tenure_num) AS new_mrr_avg
  ,retained_mrr_sum
  ,retained_mrr_avg
FROM tmp_data_dm.coe_churn_by_cohort_raw
-- WHERE cohort_type IN ('Month', 'Quarter') ;
