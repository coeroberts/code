---- ACV and ACU by professional and ad market
	select ARVSF.professional_id
		, ARVSF.AD_MARKET_ID
		, ad.ad_detail_type as ad_detail_type
		, ARVSF.customer_id
		, cast(
	                 concat(
		                 cast(year(ARVSF.attribution_date) as string)
		                 , lpad(cast(month(ARVSF.attribution_date) as string),2,'0')
		             ) 
                 as int) as YEAR_MONTH
		, SUM(ARVSF.adjusted_attribution_value) AS ACV
		, sum(arvsf.email_attributed_count) as email_attributed_count
		, sum(arvsf.website_attributed_count) as website_attributed_count
		, sum(arvsf.phone_attributed_count) as phone_attributed_count
	from DM.webanalytics_ad_attribution_v0 ARVSF 
         join dm.ad_dimension ad on ad.ad_id = arvsf.ad_id
    where ARVSF.attribution_date BETWEEN '2016-06-01' AND '2016-06-30'
	and arvsf.customer_id=2
	GROUP BY 1,2,3,4,5
	