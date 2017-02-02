SELECT
   blg.*
  ,IFNULL(CAST(olaf.product_subscription_id AS STRING), '') AS subscription_id
  ,IFNULL(CAST(olaf.order_number  AS STRING), '') AS order_number
FROM      dm.billing_report blg
  LEFT OUTER JOIN
    (
    SELECT DISTINCT product_subscription_id, order_number, order_line_number
    FROM dm.order_line_accumulation_fact 
    ) olaf
          ON blg.order_line_number = olaf.order_line_number

11316190 distinct rows
11316198 total rows

select count(*) from
    (
    SELECT  product_subscription_id, order_number, order_line_number
    FROM dm.order_line_accumulation_fact 
    ) olaf

select product_subscription_id, order_number, order_line_number, count(*) from
dm.order_line_accumulation_fact 
GROUP BY 1,2,3
HAVING COUNT(*) > 1

It is > 1 record because there were 8 line items in the order.

Orig:
-- SELECT
--    blg.*
--   ,IFNULL(CAST(olaf.product_subscription_id AS STRING), '') AS subscription_id
--   ,IFNULL(CAST(olaf.order_number  AS STRING), '') AS order_number
-- FROM      dm.billing_report blg
--   LEFT OUTER JOIN dm.order_line_accumulation_fact olaf
--           ON blg.order_line_number = olaf.order_line_number