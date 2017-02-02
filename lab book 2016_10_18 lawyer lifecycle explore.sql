-- SELECT
--    as_of_date
--   ,COUNT(DISTINCT professional_id) AS professionals
--   ,COUNT(*) AS num_rows
-- FROM dm.lawyer_cube_data_by_day
-- GROUP BY 1 ORDER BY 1

SELECT
   HOUR(claim_date) AS claim_hour
  ,COUNT(*) AS professionals
FROM dm.lawyer_cube_data_by_day
WHERE as_of_date = '2016-11-07'
  AND YEAR(claim_date) IN (2015, 2016)
GROUP BY 1
ORDER BY 1


SELECT
   HOUR(cub.claim_date) AS claim_hour_pacific_time
  ,cub.state
  ,reg.region
  ,reg.time_zone_approx
  ,reg.time_zone_offset_approx
  ,(HOUR(cub.claim_date) + 24 + reg.time_zone_offset_approx) % 24 AS adjusted_hour
  ,COUNT(*) AS professionals
  ,AVG(cub.avvo_rating) AS avvo_rating
FROM         dm.lawyer_cube_data_by_day cub
  LEFT OUTER JOIN tmp_data_dm.coe_state_x_us_region reg
          ON LOWER(cub.state) = LOWER(reg.state)
WHERE cub.as_of_date = '2016-11-07'
  AND YEAR(cub.claim_date) IN (2015, 2016)
  AND reg.time_zone_short IN ('EST', 'CST', 'MST', 'PST')
GROUP BY 1,2,3,4,5,6


