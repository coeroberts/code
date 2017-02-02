SELECT distinct olaf.professional_id
  , olaf.customer_id
  , olamf.ad_market_id
  -- ,ad.ad_id
  , pd.product_line_item_name 
  , dm.year_month
  , amd.ad_region_id
  , amd.ad_market_region_name
  , amd.ad_market_state_name
  , amd.ad_market_county_name
  , amd.ad_market_specialty_name
FROM dm.order_line_accumulation_fact olaf 
left JOIN dm.order_line_ad_market_fact olamf ON olaf.order_line_number = olamf.order_line_number 
JOIN dm.date_dim dm ON dm.actual_date = olaf.order_line_begin_date
left JOIN dm.product_line_dimension pd ON olaf.product_line_id = pd.product_line_id
left join dm.ad_market_dimension amd on amd.ad_market_id = olamf.ad_market_id
  -- AND PLD.product_line_item_name IN ('Display Medium Rectangle','Sponsored Listing') 
-- left JOIN DM.AD_DIM ad on ad.ad_key = olamf.ad_key
where olaf.product_line_id in (2,7) 
  and olaf.order_line_payment_date not like '1900-%'
  and dm.year_month >= 201301