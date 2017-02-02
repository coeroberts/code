SELECT
   olaf.professional_id
   , min(dm.month_begin_date) as first_admonth
FROM DM.order_line_accumulation_fact OLAF 
left JOIN DM.order_line_ad_market_fact OLAMF ON OLAF.order_line_number = OLAMF.order_line_number 
JOIN DM.DATE_DIM DM ON DM.actual_date = OLAF.order_line_begin_date
left JOIN DM.product_line_dimension PLD ON OLAF.product_line_id = PLD.product_line_id
where olaf.product_line_id in (2,7) 
  and olaf.order_line_payment_date not like '1900-%'
group by olaf.professional_id