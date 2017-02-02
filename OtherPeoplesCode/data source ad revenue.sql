with chan_def as -- note: internal weblogs first touch
(select distinct lpv_source, lpv_medium, lpv_campaign, lpv_content,
case  
when lpv_source = '' and lpv_medium = '' and lpv_campaign = '' and lpv_content = '' then 'Organic/Direct'
when lpv_source = 'marchex' then 'Paid Call Channels - Marchex'
when lpv_source = 'elocal' then 'Paid Call Channels - eLocal'
when lpv_source = 'pbx' then 'Paid Call Channels - SEM Call Ext'
when lpv_medium in ('utm_medium=affiliate', 'utm_medium=affiliates', 'utm_medium=affiliawww')
                    or lpv_source in ('utm_source=boomerater', 'utm_source=boomerater%20', 'utm_source=lifecare', 'utm_source=affiliates', 'utm_source=affiliate')
                    then 'Marketing - Affiliates'
when lpv_medium in ('utm_medium=em', 'utm_medium=ema', 'utm_medium=emai', 'utm_medium=email', 'utm_medium=emailutm_content')
                    or lpv_source = 'utm_source=email'
                    then 'Marketing - Email'
when lpv_campaign like 'utm_campaign=FB_%' or lpv_campaign like 'utm_campaign=pls_avvofb%' or lpv_campaign = 'utm_campaign=pls_fb%'
                    or lpv_source in ('utm_source=facebook', 'utm_source=twitter', 'utm_source=linkedin', 'utm_source=gplus', 'utm_source=plus',
                                                             'utm_source=googleplus', 'utm_source=youtube', 'utm_source=pinterest', 'utm_source=twitterfeed',
                                                             'utm_source=Facebook', 'utm_source=Twitter', 'utm_source=topix',
                                                             'utm_source=SocialProof', 'utm_source=thetwitter', 'utm_source=faceb', 'utm_source=social')
                                           or lpv_medium in ('utm_medium=facebook', 'utm_medium=twitter')
                    then 'Marketing - Social'
when lpv_content = 'utm_content=adblock' or (lpv_campaign = 'utm_campaign=adblock' and lpv_content != 'utm_content=brand') or lpv_content = 'utm_content=amm'
          or (lpv_campaign = 'utm_campaign=amm' and lpv_content != 'utm_content=brand')
                    then 'SEM - Adblock'
when lpv_content = 'utm_content=sgt' or lpv_medium = 'utm_medium=sem%2F%3Futm_source%3Dgoogle%2F%3Futm_content%3Dsgt' or lpv_campaign = 'utm_campaign=sgt'
                    then 'SEM - Network'
when (lpv_medium in ('utm_medium=display','utm_medium=video','utm_medium=mobile_video', 'utm_medium=mobile', 'utm_medium=content', 'utm_medium=mobile_tablet')
                    and lpv_source != 'utm_source=google' and lpv_source != 'utm_source=gsp')
                    or lpv_source = 'utm_source=Outbrain' or lpv_source = 'utm_source=preroll'
                    then 'Marketing - Digital Brand and Engagement'
when lpv_campaign in ('utm_campaign=brand', 'utm_campaign=Branded_Terms', 'utm_campaign=legalbroad') or lpv_content = 'utm_content=brand'
                    then 'Marketing - SEM Brand'
when lpv_medium = 'utm_medium=sem' or lpv_medium = 'utm_medium=cpc' or lpv_medium = 'utm_medium=sem%3Fpromo_code%3DAVVO25'
                    then 'Marketing - SEM Nonbrand'
when lpv_campaign like 'utm_campaign=pls%' or lpv_campaign like 'utm_campaign=PLS%' 
                    then 'Marketing - Other Paid Marketing'
when lpv_medium in ('utm_medium=avvo_badge', 'utm_medium=avvo_badg', 'utm_medium=avvo_bad', 'utm_medium=avvo_ba', 'utm_medium=avvo_b')
                    then 'Other - Avvo Badge'
when lpv_source = 'utm_source=avvo' or lpv_source = 'utm_source=eboutique' then 'Other - Other'
else 'Marketing - Other Paid Marketing' end channel 
from dm.ad_attribution_v3_all
),

rev as
(select d1.year_month, case when p.product_line_id = 2 then 'Display' when p.product_line_id = 7 then 'Sponsored' else 'Other' end inventory_type,
 case when a2.ad_market_block_flag = 'Y' then 'Block' else 'Exclusive' end market_type, am.ad_market_id,
 sum(o.order_line_net_price_amount_usd) revenue
 from dm.order_line_accumulation_fact o
 join dm.order_line_ad_market_fact am on am.order_line_number = o.order_line_number
 join dm.product_line_dimension p on p.product_line_id = o.product_line_id
 join dm.date_dim d1 on d1.actual_date = o.order_line_begin_date
 join dm.ad_market_dimension a2 on a2.ad_market_id = am.ad_market_id
  where -- am.ad_market_id = 745288 -- in (719913,720420,714583)
 d1.year_month >= 201601
 group by 1,2,3,4),
 
 
total_acv as
(select 'Sponsored' inventory_type, d.year_month, case when a.ad_market_block_flag = 'Y' then 'Block' else 'Exclusive' end market_type, a.ad_market_id,
sum(sl_adcontact_value) ACV
from dm.ad_attribution_v3_all v3
join dm.date_dim d on d.actual_date = v3.event_date
join dm.ad_market_dimension a on a.ad_market_id = v3.ad_market_id
where -- a.ad_market_id = 745288 -- in (719913,720420,714583)
d.year_month >= 201601
group by 1,2,3,4

 union all

select 'Display' inventory_type, d.year_month, case when a.ad_market_block_flag = 'Y' then 'Block' else 'Exclusive' end market_type, a.ad_market_id,
sum(da_adcontact_value) ACV
from dm.ad_attribution_v3_all v3
join dm.date_dim d on d.actual_date = v3.event_date
join dm.ad_market_dimension a on a.ad_market_id = v3.ad_market_id
where -- a.ad_market_id = 745288 -- in (719913,720420,714583)
d.year_month >= 201601
group by 1,2,3,4 
),


m2_acv_old as
(
select 'Sponsored' inventory_type, d.year_month, case when a.ad_market_block_flag = 'Y' then 'Block' else 'Exclusive' end market_type, a.ad_market_id,
sum(case when chan_def.channel in ('SEM - Adblock', 'Marketing - SEM Brand', 'SEM - Network', 'Marketing - SEM Nonbrand') then v3.sl_adcontact_value end) sem_acv_old,
sum(case when chan_def.channel not in ('SEM - Adblock', 'Marketing - SEM Brand', 'SEM - Network', 'Marketing - SEM Nonbrand') then v3.sl_adcontact_value end) other_acv_old
from dm.ad_attribution_v3_all v3
join dm.date_dim d on d.actual_date = v3.event_date
join dm.ad_market_dimension a on a.ad_market_id = v3.ad_market_id
join chan_def on chan_def.lpv_source = v3.lpv_source and chan_def.lpv_medium = v3.lpv_medium and chan_def.lpv_campaign = v3.lpv_campaign and chan_def.lpv_content = v3.lpv_content
where d.year_month >= 201601
 -- a.ad_market_id = 745288 -- in (719913,720420,714583)
group by 1,2,3,4
  
union all

select 'Display' inventory_type, d.year_month, case when a.ad_market_block_flag = 'Y' then 'Block' else 'Exclusive' end market_type, a.ad_market_id,
sum(case when chan_def.channel in ('SEM - Adblock', 'Marketing - SEM Brand', 'SEM - Network', 'Marketing - SEM Nonbrand') then v3.da_adcontact_value end) sem_acv_old,
sum(case when chan_def.channel not in ('SEM - Adblock', 'Marketing - SEM Brand', 'SEM - Network', 'Marketing - SEM Nonbrand') then v3.da_adcontact_value end) other_acv_old
from dm.ad_attribution_v3_all v3
join dm.date_dim d on d.actual_date = v3.event_date
join dm.ad_market_dimension a on a.ad_market_id = v3.ad_market_id
join chan_def on chan_def.lpv_source = v3.lpv_source and chan_def.lpv_medium = v3.lpv_medium and chan_def.lpv_campaign = v3.lpv_campaign and chan_def.lpv_content = v3.lpv_content
where d.year_month >= 201601
 -- a.ad_market_id = 745288 -- in (719913,720420,714583)
group by 1,2,3,4
),

m2_acv_new as
(select 'Sponsored' inventory_type, d.year_month, case when a.ad_market_block_flag = 'Y' then 'Block' else 'Exclusive' end market_type, a.ad_market_id,
sum(case when chan_def.channel in ('SEM - Adblock', 'Paid Call Channels - Marchex', 'Paid Call Channels - eLocal',  'Paid Call Channels - SEM Call Ext', 'Marketing - SEM Brand', 'SEM - Network', 'Marketing - SEM Nonbrand') then v3.sl_adcontact_value end) paid_acv_new,
sum(case when chan_def.channel not in ('SEM - Adblock', 'Paid Call Channels - Marchex', 'Paid Call Channels - eLocal',  'Paid Call Channels - SEM Call Ext', 'Marketing - SEM Brand', 'SEM - Network', 'Marketing - SEM Nonbrand') then v3.sl_adcontact_value end) other_acv_new
from dm.ad_attribution_v3_all v3
join dm.date_dim d on d.actual_date = v3.event_date
join dm.ad_market_dimension a on a.ad_market_id = v3.ad_market_id
join chan_def on chan_def.lpv_source = v3.lpv_source and chan_def.lpv_medium = v3.lpv_medium and chan_def.lpv_campaign = v3.lpv_campaign and chan_def.lpv_content = v3.lpv_content
 where -- a.ad_market_id = 745288 -- in (719913,720420,714583)
 d.year_month >= 201601
group by 1,2,3,4

union all

select 'Display' inventory_type, d.year_month, case when a.ad_market_block_flag = 'Y' then 'Block' else 'Exclusive' end market_type, a.ad_market_id,
sum(case when chan_def.channel in ('SEM - Adblock', 'Paid Call Channels - Marchex', 'Paid Call Channels - eLocal',  'Paid Call Channels - SEM Call Ext', 'Marketing - SEM Brand', 'SEM - Network', 'Marketing - SEM Nonbrand') then v3.da_adcontact_value end) paid_acv_new,
sum(case when chan_def.channel not in ('SEM - Adblock', 'Paid Call Channels - Marchex', 'Paid Call Channels - eLocal',  'Paid Call Channels - SEM Call Ext', 'Marketing - SEM Brand', 'SEM - Network', 'Marketing - SEM Nonbrand') then v3.da_adcontact_value end) other_acv_new
from dm.ad_attribution_v3_all v3
join dm.date_dim d on d.actual_date = v3.event_date
join dm.ad_market_dimension a on a.ad_market_id = v3.ad_market_id
join chan_def on chan_def.lpv_source = v3.lpv_source and chan_def.lpv_medium = v3.lpv_medium and chan_def.lpv_campaign = v3.lpv_campaign and chan_def.lpv_content = v3.lpv_content
 where -- a.ad_market_id = 745288 -- in (719913,720420,714583)
 d.year_month >= 201601
group by 1,2,3,4)


-- this outer query of sum of rev by channel is test
/* select channel, sum(revenue_m1) revm1, sum(acv) acv, sum(total_acv) total_acv, sum(m2_sem_acv_old) m2semacvold, sum(m2_other_acv_old) m2otheracvold,
 sum(total_rev) total_rev, sum(revenue_m2_old) revm2old
 from ( */

select inventory_type, year_month, market_type, ad_market_id, state, county, region, parent_pa, PA,
channel, avg(total_rev) total_rev, avg(total_acv) total_acv, sum(acv) acv,
  -- averaging total_rev and total_acv here because we already have the sum by market which we want to keep to calculate the m1
case when avg(total_acv) = 0 then 0 else (sum(acv)/avg(total_acv))*avg(total_rev) end revenue_m1,
avg(sem_acv_old) m2_sem_acv_old, avg(other_acv_old) m2_other_acv_old, avg(paid_acv_new) m2_paid_acv_new, avg(other_acv_new) m2_other_acv_new,

case when avg(total_rev) > avg(total_acv) then 'case 1'
when channel in ('SEM - Adblock', 'Marketing - SEM Brand', 'SEM - Network', 'Marketing - SEM Nonbrand') and avg(total_rev) > avg(other_acv_old)
then 'case 2'
when channel in ('SEM - Adblock', 'Marketing - SEM Brand', 'SEM - Network', 'Marketing - SEM Nonbrand') and avg(total_rev) <= avg(other_acv_old)
then 'case 3'
when avg(other_acv_old) < avg(total_rev) then 'case 4'
else 'case 5' end revenue_m2_old_test,


case when avg(total_rev) > avg(total_acv) then (sum(acv)/avg(total_acv))*avg(total_rev)
when channel in ('SEM - Adblock', 'Marketing - SEM Brand', 'SEM - Network', 'Marketing - SEM Nonbrand') and avg(total_rev) > avg(other_acv_old)
then sum(acv)/(avg(total_acv)-avg(other_acv_old))*(avg(total_rev)-avg(other_acv_old))
when channel in ('SEM - Adblock', 'Marketing - SEM Brand', 'SEM - Network', 'Marketing - SEM Nonbrand') and avg(total_rev) <= avg(other_acv_old)
then 0
when avg(other_acv_old) < avg(total_rev) then (sum(acv)/avg(other_acv_old))*avg(other_acv_old) -- (which is just ACV, but I did it this way so these case statements could be more easily mapped to the old query)
else (sum(acv)/avg(other_acv_old))*avg(total_rev) end revenue_m2_old,

-- if all revenue is greater than all acv, don't have to worry about giving too much credit to any channel because all acv is needed
-- else if looking at an SEM/paid channel (depending on new or old definitions), take the % of SEM/paid ACV that this channel makes up and apply that to the remaining revenue not fulfilled by other channel ACV
-- if there is no revenue not fulfilled by other channels, then the SEM/paid channel will have m2 revenue of 0
-- otherwise, if looking at an "other" channel, the m2 revenue will be the % of "other" ACV it makes up times the "other" acv (so full ACV value) if it's less than the total rev. or the % of "other" acv times total revenue
               
               
case when avg(total_rev) > avg(total_acv) then  (sum(acv)/avg(total_acv))*avg(total_rev)
when channel in ('SEM - Adblock', 'Paid Call Channels - Marchex', 'Paid Call Channels - eLocal',  'Paid Call Channels - SEM Call Ext', 'Marketing - SEM Brand', 'SEM - Network', 'Marketing - SEM Nonbrand') and avg(total_rev) > avg(other_acv_new)
then sum(acv)/(avg(total_acv)-avg(other_acv_new))*(avg(total_rev)-avg(other_acv_new)) -- (remember can't use paid acv in the denominator)
when channel in ('SEM - Adblock', 'Paid Call Channels - Marchex', 'Paid Call Channels - eLocal',  'Paid Call Channels - SEM Call Ext', 'Marketing - SEM Brand', 'SEM - Network', 'Marketing - SEM Nonbrand') and avg(total_rev) <= avg(other_acv_new)
then 0
when avg(other_acv_new) < avg(total_rev) then (sum(acv)/avg(other_acv_new))*avg(other_acv_new) 
else (sum(acv)/avg(other_acv_new))*avg(total_rev) end revenue_m2_new

from (
select 'Sponsored' inventory_type, d.year_month, a.market_type, a.ad_market_id, a.state, a.county, a.region, a.parent_pa, a.PA,
chan_def.channel, rev.revenue total_rev, total_acv.acv total_acv, m2_acv_old.sem_acv_old, m2_acv_old.other_acv_old, m2_acv_new.paid_acv_new, m2_acv_new.other_acv_new, 
sum(sl_adcontact_value) ACV
from dm.ad_attribution_v3_all v3
  join chan_def on chan_def.lpv_source = v3.lpv_source and chan_def.lpv_medium = v3.lpv_medium and chan_def.lpv_campaign = v3.lpv_campaign and chan_def.lpv_content = v3.lpv_content
join dm.date_dim d on d.actual_date = v3.event_date
join (select ad_market_id, case when ad_market_block_flag = 'Y' then 'Block' else 'Exclusive' end market_type,
      a1.ad_market_state_name state, a1.ad_market_county_name county, a1.ad_market_region_name region, s1.parent_specialty_name parent_pa, s1.specialty_name pa
      from dm.ad_market_dimension a1
     join dm.specialty_dimension s1 on s1.specialty_id = a1.specialty_id
     ) a on a.ad_market_id = v3.ad_market_id
left join rev on rev.year_month = d.year_month and rev.inventory_type = 'Sponsored' and rev.market_type = a.market_type and rev.ad_market_id = v3.ad_market_id
left join total_acv on total_acv.year_month = d.year_month and total_acv.inventory_type = 'Sponsored' and total_acv.market_type = a.market_type and total_acv.ad_market_id = v3.ad_market_id
left join m2_acv_old on m2_acv_old.year_month = d.year_month and m2_acv_old.inventory_type = 'Sponsored' and m2_acv_old.market_type = a.market_type and m2_acv_old.ad_market_id = v3.ad_market_id
left join m2_acv_new on m2_acv_new.year_month = d.year_month and m2_acv_new.inventory_type = 'Sponsored' and m2_acv_new.market_type = a.market_type and m2_acv_new.ad_market_id = v3.ad_market_id
  where d.year_month >= 201601
-- and a.market_type = 'Block'  and a.ad_market_id = 745288 -- in (719913,720420,714583)
 group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
  
  union all
  
select 'Display' inventory_type, d.year_month, a.market_type, a.ad_market_id, a.state, a.county, a.region, a.parent_pa, a.PA,
chan_def.channel, rev.revenue total_rev, total_acv.acv total_acv, m2_acv_old.sem_acv_old, m2_acv_old.other_acv_old, m2_acv_new.paid_acv_new, m2_acv_new.other_acv_new, 
sum(da_adcontact_value) ACV
from dm.ad_attribution_v3_all v3
  join chan_def on chan_def.lpv_source = v3.lpv_source and chan_def.lpv_medium = v3.lpv_medium and chan_def.lpv_campaign = v3.lpv_campaign and chan_def.lpv_content = v3.lpv_content
join dm.date_dim d on d.actual_date = v3.event_date
join (select ad_market_id, case when ad_market_block_flag = 'Y' then 'Block' else 'Exclusive' end market_type,
      a1.ad_market_state_name state, a1.ad_market_county_name county, a1.ad_market_region_name region, s1.parent_specialty_name parent_pa, s1.specialty_name pa
      from dm.ad_market_dimension a1
     join dm.specialty_dimension s1 on s1.specialty_id = a1.specialty_id
     ) a on a.ad_market_id = v3.ad_market_id
left join rev on rev.year_month = d.year_month and rev.inventory_type = 'Display' and rev.market_type = a.market_type and rev.ad_market_id = v3.ad_market_id
left join total_acv on total_acv.year_month = d.year_month and total_acv.inventory_type = 'Display' and total_acv.market_type = a.market_type and total_acv.ad_market_id = v3.ad_market_id
left join m2_acv_old on m2_acv_old.year_month = d.year_month and m2_acv_old.inventory_type = 'Display' and m2_acv_old.market_type = a.market_type and m2_acv_old.ad_market_id = v3.ad_market_id
left join m2_acv_new on m2_acv_new.year_month = d.year_month and m2_acv_new.inventory_type = 'Display' and m2_acv_new.market_type = a.market_type and m2_acv_new.ad_market_id = v3.ad_market_id
  where d.year_month >= 201601
-- and a.market_type = 'Block'  and a.ad_market_id = 745288 -- in (719913,720420,714583)
 group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16

  ) t
  group by 1,2,3,4,5,6,7,8,9,10
-- ) test
-- group by 1

----
_v0 _v3 NOTES ON ACV

Channels included in M2 paid channel classification:
SEM - Adblock
SEM - Network
Paid Call Channels - Marchex
Paid Call Channels - eLocal
Paid Call Channels - SEM Call Ext
Marketing - SEM Brand
Marketing - SEM Nonbrand

From Whitney:
We look at m1/m2 just for sem and paid call channels. for m1, 
when we attribute revenue that goes toward a channel, we take 
the % of acv that channel drove and apply that to the revenue 
driven that month, and say it drove the same % of acv as revenue.

For m2, we look at the % of acv we think that channel is actually 
responsible for after organic is taken out.

So like, 
if have 1000 revenue, needed 1000 acv 
and organic drove 800 acv and sem drove 500, 
the m1 revenue for sem is 500/(500+800) * 1000 . 
the m2 is (1000-800)/(500+800) * 1000 .

M1: SEM / (SEM + Organic)
M2: (ACV needed - Organic delivered) / (SEM + Organic)

ACV adjustment ratio is based on mix of organic / paid for that advertiser.
