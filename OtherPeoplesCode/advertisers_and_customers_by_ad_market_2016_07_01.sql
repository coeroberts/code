SELECT distinct olaf.profnl_id as professional_id
  , olaf.cust_ID as customer_id
  , OLAMF.ad_market_id
  -- ,AD.AD_ID
  , PLD.PRODUCT_LN_ITM_NAME 
  , dm.year_month
  , amd.ad_region_id
  , amd.ad_market_region_name
  , amd.ad_market_state_name
  , amd.ad_market_county_name
  , amd.ad_market_specialty_name
FROM DM.ORDER_LN_ACCUM_FACT OLAF 
left JOIN DM.order_line_ad_market_fact OLAMF ON OLAF.ORDER_LN_NBR = OLAMF.order_line_number 
JOIN DM.DATE_DIM DM ON DM.actual_date = OLAF.ORDER_LN_BEGIN_USE_DATE
left JOIN DM.PRODUCT_LN_DIM PLD ON OLAF.PRODUCT_LN_KEY = PLD.PRODUCT_LN_KEY 
left join dm.ad_market_dimension amd on amd.ad_market_id = olamf.ad_market_id
  -- AND PLD.PRODUCT_LN_ITM_NAME IN ('Display Medium Rectangle','Sponsored Listing') 
-- left JOIN DM.AD_DIM ad on ad.ad_key = olamf.ad_key
where olaf.PRODUCT_LN_KEY in (2,7) 
  and olaf.order_paymnt_date not like '1900-%'
  and dm.year_month >= 201301
