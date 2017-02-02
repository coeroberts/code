SELECT
   dm.year_month
   , dm.month_begin_date
   , count(distinct( olaf.professional_id)) as cnt_professional_id

FROM DM.ORDER_LINE_ACCUMULATION_FACT OLAF 
left JOIN DM.order_line_ad_market_fact OLAMF ON OLAF.order_line_number = OLAMF.order_line_number 
JOIN DM.DATE_DIM DM ON DM.actual_date = OLAF.ORDER_LINE_BEGIN_DATE
left JOIN DM.PRODUCT_LINE_DIMENSION PLD ON OLAF.PRODUCT_LINE_ID = PLD.PRODUCT_LINE_ID 
where olaf.PRODUCT_LINE_ID in (2,7) 
  and olaf.order_line_payment_date not like '1900-%'
  and dm.year_month >= 201401
Group by 1,2