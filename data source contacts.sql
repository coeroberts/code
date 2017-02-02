-- 8153274
-- 8152305 fv
-- 8152305 b
-- 8151106 t

-- OK so both the join to fv and the join to t throw extra rows in there.


with b as 
(select 
olaf.professional_id
, 'Advertiser or Pro' as Advertiser
, d.year_month
, min(order_line_begin_date) as order_ln_begin_use_date
, max(order_line_cancelled_date) as order_ln_cncl_date
from dm.order_line_accumulation_fact olaf
join dm.date_dim d on d.actual_date = order_line_begin_date
where d.year_month >= 201505
and olaf.product_line_id in (2,7,4)
group by 1,2,3
) 

, first_visit as 
( select
 t.persistent_session_id
 , t.event_date as first_visit_date
 from dm.traffic t
 where t.first_persistent_session = true
 )


select 
ci.contact_type
, ci.event_date
, d.year_month
, t.lpv_page_type
, t.lpv_medium
, t.lpv_content
/*looking at user id in traffic and contact impression table to identify RU because traffic might be missing some...need to investigate*/
, case when (t.resolved_user_ID is not null or ci.user_id is not null) then 'Registered User' else 'Not Registered' end as Registered_User
, if(t.lawyer_user_id, 'Lawyer', 'Consumer') as Lawyer
, case when t.first_persistent_session = true then 'First Visit' else '' end as First_Visit
,case when datediff(t.event_date,fv.first_visit_date) <= 30 then 'New User' 
      else 'Return User' end as User_Status
, b.advertiser
, count(*) as num_contacts

from 
(
SELECT contact_type, event_date, professional_id, user_id, session_id
FROM src.contact_impression
WHERE event_date >= '2015-05-01'
AND IFNULL(contact_type, 'ZZZZ') <> 'message'
UNION ALL
SELECT contact_type, event_date, professional_id, user_id, session_id
FROM
  (  -- Filter to only conversation-starting messages.
  SELECT
     contact_type
    ,event_date
    ,user_id
    ,professional_id
    ,session_id
  FROM
    (
    SELECT contact_type, event_date, FROM_UNIXTIME(gmt_timestamp) AS gmt_time, professional_id, user_id, session_id
      ,LAG(event_date) OVER (PARTITION BY contact_type, professional_id, user_id
                                    ORDER BY gmt_timestamp) AS prev_event_date
    FROM src.contact_impression
    WHERE event_date >= '2015-05-01'
    AND contact_type = 'message'
    ) ctc
  WHERE ((prev_event_date IS NULL)
      OR (DATEDIFF(event_date, prev_event_date) >= 14))
  ) msg
) ci
left join dm.traffic t on t.session_id = ci.session_id  and t.event_date = ci.event_date
join dm.date_dim d on d.actual_date = ci.event_date
left join b on b.professional_id  = ci.professional_id and d.year_month = b.year_month and  b.order_ln_begin_use_date <= ci.event_date
left join first_visit fv on fv.persistent_session_id = t.persistent_session_id 
where ci.event_date >= '2015-05-01'
group by ci.user_id, ci.contact_type, ci.event_date, Registered_User, Lawyer, User_Status, First_Visit, d.year_month, b.advertiser, t.lpv_page_type, t.lpv_medium, t.lpv_content
