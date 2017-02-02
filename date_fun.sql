select strleft(from_unixtime(unix_timestamp(cast('2016-03-16' as timestamp) - interval 1 months), 'yyyy-MM-dd HH:mm:ss'),7)

SELECT
   year
  ,year_month AS year_month_num
  ,CONCAT(CAST(year AS STRING), '-', LPAD(CAST(month_nbr_in_year AS STRING), 2, '0')) AS year_month_str
  ,month_nbr_in_year
  ,qtr_nbr_in_year
  ,month_name
  ,short_month_name
  ,month_begin_date
  ,month_end_date
  ,CAST(TRANSLATE(STRLEFT(FROM_UNIXTIME(UNIX_TIMESTAMP(CAST(month_begin_date AS TIMESTAMP) - INTERVAL 1 MONTHS), 'yyyy-MM-dd HH:mm:ss'),7), '-','') AS INT) AS prev_year_month_num
  ,STRLEFT(FROM_UNIXTIME(UNIX_TIMESTAMP(CAST(month_begin_date AS TIMESTAMP) - INTERVAL 1 MONTHS), 'yyyy-MM-dd HH:mm:ss'),7) AS prev_year_month_str
  ,COUNT(*) AS days_in_month
  ,COUNT(CASE WHEN (day_nbr_in_wk BETWEEN 1 AND 5) THEN actual_date ELSE NULL END) AS week_days_in_month
  ,COUNT(CASE WHEN (day_nbr_in_wk BETWEEN 1 AND 5) AND (us_bank_holiday_ind = 'Not a U.S. Bank Holiday') THEN actual_date ELSE NULL END) AS business_days_in_month
FROM dm.date_dim
WHERE year_month BETWEEN 201501 AND 201604
GROUP BY 1,2,3,4,5,6,7,8,9,10,11
-- ORDER BY year_month_num

When extracting year_month, can just use yyyy-MM in FROM_UNIXTIME,
and then the STRLEFT is not needed.
from_unixtime(unix_timestamp(CAST(month_begin_date AS TIMESTAMP)), 'yyyy-MM') AS year_month

CAST (from_unixtime(unix_timestamp(CAST(o.order_line_begin_date AS TIMESTAMP)), 'yyyyMM') AS INT) AS year_month

----
Months difference between two integer year_month values...

(FLOOR(x1.year_month/100) - FLOOR(x2.year_month/100)) * 12 +
      (x1.year_month%100 -        x2.year_month%100) AS diff

SELECT
   x1
  ,x2
  ,(FLOOR(x1/100) - FLOOR(x2/100))*12 + (x1%100 - x2%100) AS months_diff
FROM
  (
  SELECT * FROM
    (
          SELECT 201610 AS x1, 201610 AS x2
    UNION SELECT 201610 AS x1, 201609 AS x2
    UNION SELECT 201610 AS x1, 201510 AS x2
    UNION SELECT 201610 AS x1, 201611 AS x2
    UNION SELECT 201601 AS x1, 201601 AS x2
    UNION SELECT 201601 AS x1, 201512 AS x2
    UNION SELECT 201601 AS x1, 201501 AS x2
    UNION SELECT 201601 AS x1, 201502 AS x2
    ) dts
  ) qry
ORDER BY 1,2

yep formula works.

----


select
   min(actual_date) AS min_date
  ,max(actual_date) AS max_date
from dm.date_dim

select
   min(year_month) AS min_year_month
  ,max(year_month) AS max_year_month
from dm.month_dim

----
select actual_date,
from_unixtime(unix_timestamp(cast(actual_date as timestamp) - interval 1 months), 'yyyy-MM-dd') AS date_minus_1_month
FROM dm.date_dim
WHERE year = 2016
order by 1
If that date the previous month does not exist it chooses the last day of the previous month.
----
DROP TABLE IF EXISTS tmp_data_dm.coe_my_month_dim ;
CREATE TABLE tmp_data_dm.coe_my_month_dim AS
SELECT
   mth.month_key
  ,mth.year_month
  ,mth.month_name
  ,mth.short_month_name
  ,mth.month_begin_date
  ,mth.month_end_date
  ,CASE WHEN md.business_day_in_month_count = 0 THEN NULL ELSE md.business_day_in_month_count END AS business_day_in_month_count
  ,md.day_in_month_count
  ,CONCAT(CAST(FLOOR(mth.year_month/100) AS STRING), '-',LPAD(CAST(mth.year_month%100 AS STRING),2,'0')) AS month_label
  ,DATE_ADD(mth.month_begin_date, CAST(md.day_in_month_count/2 AS INT)) AS month_mid_ish_date
  ,CAST(mth.year*10 + mth.qtr_nbr_in_year AS INT) AS year_qtr
  ,mth.qtr_nbr_in_year
  ,mth.month_nbr_in_qtr
  ,qtr.qtr_begin_date
  ,qtr.qtr_end_date
  ,CASE WHEN qtr.business_day_in_qtr_count = 0 THEN NULL ELSE qtr.business_day_in_qtr_count END AS business_day_in_qtr_count
  ,qtr.day_in_qtr_count
  ,CONCAT('FY', CAST(mth.year % 2000 AS STRING), ' Q', CAST(mth.qtr_nbr_in_year AS STRING)) AS qtr_label
  ,DATE_ADD(qtr.qtr_begin_date, CAST(qtr.day_in_qtr_count/2 AS INT)) AS qtr_mid_ish_date
  ,mth.year
  ,mth.month_nbr_in_year
  ,yr.year_begin_date
  ,yr.year_end_date
  ,CASE WHEN yr.business_day_in_year_count = 0 THEN NULL ELSE yr.business_day_in_year_count END AS business_day_in_year_count
  ,yr.day_in_year_count
  ,DATE_ADD(yr.year_begin_date, CAST(yr.day_in_year_count/2 AS INT)) AS year_mid_ish_date
FROM dm.month_dim mth
  INNER JOIN
  (  -- I calculate these here because in the month_dim table, some of them (I think in the future) are NULL.
     -- Far future rows are still NULL because the holiday indicator is not populated.
  SELECT
     year_month
    ,SUM(CASE WHEN us_bank_holiday_ind = 'Not a U.S. Bank Holiday' THEN 1 ELSE 0 END) AS business_day_in_month_count
    ,SUM(1) AS day_in_month_count
  FROM dm.date_dim
  GROUP BY 1
  ) md
     ON mth.year_month = md.year_month
  INNER JOIN
  (
  SELECT
     year
    ,qtr_nbr_in_year
    ,MIN(actual_date) AS qtr_begin_date
    ,MAX(actual_date) AS qtr_end_date
    ,SUM(CASE WHEN us_bank_holiday_ind = 'Not a U.S. Bank Holiday' THEN 1 ELSE 0 END) AS business_day_in_qtr_count
    ,SUM(1) AS day_in_qtr_count
  FROM dm.date_dim
  GROUP BY 1,2
  ) qtr
     ON mth.year = qtr.year
    AND mth.qtr_nbr_in_year = qtr.qtr_nbr_in_year
  INNER JOIN
  (
  SELECT
     year
    ,MIN(actual_date) AS year_begin_date
    ,MAX(actual_date) AS year_end_date
    ,SUM(CASE WHEN us_bank_holiday_ind = 'Not a U.S. Bank Holiday' THEN 1 ELSE 0 END) AS business_day_in_year_count
    ,SUM(1) AS day_in_year_count
  FROM dm.date_dim
  GROUP BY 1
  ) yr
     ON mth.year = yr.year
WHERE mth.year_month BETWEEN 200001 AND 203012

