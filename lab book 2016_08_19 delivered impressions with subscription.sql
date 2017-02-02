SELECT daw.calculation_date
  ,admkt.ad_mkt_key
  ,daw.ad_id
  ,pro.professional_id AS lawyerid
  ,pro.name
  ,admkt.ad_mkt_state_name
  ,admkt.ad_mkt_cnty_name
  ,admkt.ad_mkt_regn_name
  ,admkt.ad_mkt_speclty_name
  ,MIN(target_block_count) AS target_block_cnt
  ,MIN(target_impression_count) AS target_imprsn_cnt
  ,MIN(target_purchase_price) AS target_purch_price_amt
  ,MIN(delivered_impression_count) AS delvr_imprsn_cnt
  ,MIN(delivered_attribution_value) AS delvr_attrib_value
  ,MIN(iq) AS iq
  ,MIN(vq) AS vq 
  ,MAX(daw.max_block_count) AS BlockAvailable
  ,MAX(daw.total_sold_block_count)  BlockSold
FROM dm.webanalytics_ad_weight daw
JOIN dm.ad_mkt_dim admkt on admkt.ad_mkt_key = daw.ad_market_key
LEFT JOIN 
(
  SELECT admap.ad_id
     , pf.professional_id
     , CONCAT(pf.professional_first_name,' ',pf.professional_last_name) AS name
  FROM
  (
     SELECT adcustmap.ad_id, min(adcustmap.professional_id) AS professional_id, count(distinct adcustmap.professional_id) AS pcount
     FROM dm.historical_ad_customer_professional_map adcustmap
     WHERE adcustmap.etl_effective_end_date >= <Parameters.current_date>
     GROUP BY adcustmap.ad_id
     ORDER BY pcount DESC
  ) admap
  LEFT JOIN dm.professional_dimension pf ON pf.professional_id = admap.professional_id
) pro ON pro.ad_id = daw.ad_id
WHERE daw.calculation_date >= '2015-01-01'
  AND admkt.ad_mkt_block_flag = 'Y'
GROUP BY 1,2,3,4,5,6,7,8,9

webanalytics_ad_weight
    ad_id
    ad_market_key
    ad_region_id
    specialty_id

historical_ad_customer_professional_map
    ad_id
    customer_id
    professional_id
    product_line_item_id

subscription_dimension
    subscription_id
    customer_id
    sales_order_id
    inventory_id
    inventory_type
    ad_id
    ad_type

order_line_ad_market_fact
    order_line_number
    ad_market_id
    ad_id
    professional_id

SELECT calculation_date, ad_id, ad_market_key, template_name, render_type_name, COUNT(*) as num_rows
FROM dm.webanalytics_ad_weight
WHERE calculation_date = '2015-08-17'
GROUP BY 1,2,3,4,5
HAVING COUNT(*) > 1
This works.

SELECT *
FROM dm.webanalytics_ad_weight
WHERE calculation_date = '2015-08-17' AND ad_id = 43361

FROM         dm.order_line_accumulation_fact

SELECT ad_id, ad_market_id, yearmonth, COUNT(*)
FROM dm.order_line_ad_market_fact
GROUP BY 1,2,3
HAVING COUNT(*) > 1

SELECT *
FROM       dm.order_line_ad_market_fact amf
LEFT OUTER JOIN dm.order_line_accumulation_fact olaf
        ON amf.order_line_number = olaf.order_line_number
WHERE amf.ad_id = 16979
and amf.ad_market_id = 9116
and amf.yearmonth = 201607
OK there are 4 rows with all the same ad_id, ad_market_id, yearmonth, professional_id.
They have different orders and subscriptions.
(not the only example)

customer_id, ad_market_id, yearmonth
Try sem vs. organic

SELECT ad_id, COUNT(DISTINCT customer_id) AS customers
FROM dm.historical_ad_customer_professional_map
GROUP BY 1
HAVING COUNT(DISTINCT customer_id) > 1
No results... *whew*

OK, IN CURRENT DATA looks like there is one row per 
(calculation_date, ad_id, ad_market_key, template_name)
But some historical data (2015-08-17 and earlier) has mult rows.
Aha!  render_type_name.
One row per (calculation_date, ad_id, ad_market_key, template_name, render_type_name)
OK I am going to ignore that for now because all we need is 2016.
And really it''s hard to tell what to do with mobile/desktop.  I think
if we want history we would do where coalesce (render type, desktop) = desktop
(or the moral equivalent).


SELECT
   COUNT(*) AS num_rows
  ,SUM(qry.delivered_impressions) AS        delivered_impressions
  ,SUM(qry.delivered_attribution_value) AS  delivered_attribution_value
FROM
(
) qry


SELECT
   dt.year_month
  ,mkt.ad_mkt_id AS ad_market_id
  ,awt.ad_region_id
  ,admap.customer_id
  ,SUM(awt.delivered_impressions) AS        delivered_impressions
  ,SUM(awt.delivered_attribution_value) AS  delivered_attribution_value
FROM
    (
    -- There are multiple rows for the different templates.
    -- Get the values just once.
    SELECT
       calculation_date
      ,ad_id
      ,ad_market_key
      ,ad_region_id
      ,specialty_id
      ,MIN(delivered_impression_count) AS   delivered_impressions
      ,MIN(delivered_attribution_value) AS  delivered_attribution_value
    FROM dm.webanalytics_ad_weight
    -- WHERE calculation_date BETWEEN '2016-06-01' AND '2016-07-31'          LOOK
    WHERE calculation_date = '2016-07-16'
    GROUP BY 1,2,3,4,5
    ) awt
  INNER JOIN dm.date_dim dt
          ON awt.calculation_date = dt.actual_date
  INNER JOIN dm.ad_mkt_dim mkt
          ON awt.ad_market_key = mkt.ad_mkt_key
  INNER JOIN 
    (
    SELECT DISTINCT ad_id, customer_id
    FROM dm.historical_ad_customer_professional_map
    ) admap
          ON awt.ad_id = admap.ad_id
GROUP BY 1,2,3,4


