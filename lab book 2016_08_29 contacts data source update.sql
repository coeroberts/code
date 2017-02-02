This is now in 'data source contacts.sql'.

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
/*looking at user id in traffic and contact impression table to idnetify RU because traffic might be missing some...need to investigate*/
, case when (t.resolved_user_ID is not null or ci.user_id is not null) then 'Registered User' else 'Not Registered' end as Registered_User
, if(t.lawyer_user_id, 'Lawyer', 'Consumer') as Lawyer
, case when t.first_persistent_session = true then 'First Visit' else '' end as First_Visit
,case when datediff(t.event_date,fv.first_visit_date) <= 30 then 'New User' 
      else 'Return User' end as User_Status
, b.advertiser
, count(*) as num_contacts

from src.contact_impression ci
left join dm.traffic t on t.session_id = ci.session_id  and t.event_date = ci.event_date
join dm.date_dim d on d.actual_date = ci.event_date
left join b on b.professional_id  = ci.professional_id and d.year_month = b.year_month and  b.order_ln_begin_use_date <= ci.event_date
left join first_visit fv on fv.persistent_session_id = t.persistent_session_id 
where ci.event_date >= '2015-05-01'
group by ci.user_id, ci.contact_type, ci.event_date, Registered_User, Lawyer, User_Status, First_Visit, d.year_month, b.advertiser, t.lpv_page_type, t.lpv_medium, t.lpv_content

----

select
COUNT(DISTINCT conversation_id) AS conversations,
count(*) AS num_rows
FROM src.contact_impression ci
where event_date BETWEEN '2016-07-01' AND '2016-08-28'
AND contact_type = 'message'

select * from (
SELECT event_date
,COUNT(DISTINCT session_id) AS sessions
,COUNT(*) AS num_rows
FROM dm.traffic
WHERE event_date BETWEEN '2016-07-01' AND '2016-08-28'
group by 1
order by 1
) qry
where sessions <> num_rows
OK dm.traffic has one row per (session_id, event_date).

----

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

from src.contact_impression ci
left join dm.traffic t on t.session_id = ci.session_id  and t.event_date = ci.event_date
join dm.date_dim d on d.actual_date = ci.event_date
left join b on b.professional_id  = ci.professional_id and d.year_month = b.year_month and  b.order_ln_begin_use_date <= ci.event_date
left join first_visit fv on fv.persistent_session_id = t.persistent_session_id 
where ci.event_date >= '2015-05-01'
group by ci.user_id, ci.contact_type, ci.event_date, Registered_User, Lawyer, User_Status, First_Visit, d.year_month, b.advertiser, t.lpv_page_type, t.lpv_medium, t.lpv_content

----

-- SELECT contact_type, event_date, professional_id, user_id, session_id
-- FROM src.contact_impression
-- WHERE event_date >= '2015-05-01'
-- AND IFNULL(contact_type, 'ZZZZ') <> 'message'
-- UNION ALL
-- SELECT DISTINCT contact_type, event_date, professional_id, user_id, session_id
-- FROM
--   (
--     SELECT contact_type, event_date, professional_id, user_id, 
--       FIRST_VALUE(session_id) OVER (PARTITION BY contact_type, event_date, professional_id, user_id
--                                     ORDER BY gmt_timestamp) AS session_id
--     FROM src.contact_impression
--     WHERE event_date >= '2015-05-01'
--     AND contact_type = 'message'
--   ) msg


-- SELECT 
--    COUNT(*) AS num_rows
--   ,COUNT(DISTINCT contact_type, event_date, professional_id, user_id) AS distinct_rows  
--   ,SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) AS null_user_rows  
-- from
-- (
-- SELECT DISTINCT contact_type, event_date, professional_id, user_id, session_id
-- FROM
--   (
--     SELECT contact_type, event_date, professional_id, user_id, 
--       FIRST_VALUE(session_id) OVER (PARTITION BY contact_type, event_date, professional_id, user_id
--                                     ORDER BY gmt_timestamp) AS session_id
--     FROM src.contact_impression
--     WHERE event_date >= '2015-05-01'
--     AND contact_type = 'message'
--   ) msg
-- ) qry
-- OK important conclusion: if one of the fields can be NULL, distinct does
-- not roll those rows together.  Neither does GROUP BY.
--     AND user_id IS NOT NULL

-- SELECT COUNT(*) AS num_rows, COUNT(DISTINCT contact_type, event_date, professional_id, user_id) AS distinct_rows  
-- FROM
-- (
-- SELECT contact_type, event_date, professional_id, CASE WHEN user_id = 'ZZZZ' THEN NULL ELSE user_id END AS user_id, session_id 
-- FROM
--   (
--   SELECT DISTINCT contact_type, event_date, professional_id, user_id, session_id
--   FROM
--     (
--       SELECT contact_type, event_date, professional_id, IFNULL(user_id, 'ZZZZ') AS user_id, 
--         FIRST_VALUE(session_id) OVER (PARTITION BY contact_type, event_date, professional_id, IFNULL(user_id, 'ZZZZ')
--                                       ORDER BY gmt_timestamp) AS session_id
--       FROM src.contact_impression
--       WHERE event_date >= '2015-05-01'
--       AND contact_type = 'message'
--     ) msg0
--   ) msg1
-- ) msg
-- This returns num_rows=14063 and distinct_rows=14009.
-- Now this makes different results, but it should, because of the NULLS.
-- OK so wait, maybe I could go back to a simpler form, given that I want the NULL
-- rows to end up separately.
-- Yep.  Never mind that detour.  Original way does what I want.

-- SELECT contact_type, count(*) as num_rows FROM
-- (
-- SELECT contact_type, event_date, professional_id, user_id, session_id
-- FROM src.contact_impression
-- WHERE event_date >= '2015-05-01'
-- ) qry
-- GROUP BY 1 ORDER BY 1

-- SELECT contact_type, count(*) as num_rows FROM
-- (
-- SELECT contact_type, event_date, professional_id, user_id, session_id
-- FROM src.contact_impression
-- WHERE event_date >= '2015-05-01'
-- AND contact_type <> 'message'
-- UNION
-- SELECT DISTINCT contact_type, event_date, professional_id, user_id, session_id
-- FROM
--   (
--     SELECT contact_type, event_date, professional_id, user_id, 
--       FIRST_VALUE(session_id) OVER (PARTITION BY contact_type, event_date, professional_id, user_id
--                                     ORDER BY gmt_timestamp) AS session_id
--     FROM src.contact_impression
--     WHERE event_date >= '2015-05-01'
--     AND contact_type = 'message'
--   ) msg
-- ) qry
-- GROUP BY 1 ORDER BY 1
-- Urgh.  I think the UNION is deduping.
-- Yep. "The UNION keyword by itself is the same as UNION DISTINCT."
-- Oh UNION ALL!

OK this is the one:

SELECT contact_type, event_date, professional_id, user_id, session_id
FROM src.contact_impression
WHERE event_date >= '2015-05-01'
AND IFNULL(contact_type, 'ZZZZ') <> 'message'
UNION ALL
SELECT DISTINCT contact_type, event_date, professional_id, user_id, session_id
FROM
  (
    SELECT contact_type, event_date, professional_id, user_id, 
      FIRST_VALUE(session_id) OVER (PARTITION BY contact_type, event_date, professional_id, user_id
                                    ORDER BY gmt_timestamp) AS session_id
    FROM src.contact_impression
    WHERE event_date >= '2015-05-01'
    AND contact_type = 'message'
  ) msg


But now we probably want to use conversation_id and a 30-day gap.
Nope, not 30-day gap.  Dedup by single days.

I want to validate the 4%.  Can implement the 30-day gap one
and compare to the single-day one.

-- SELECT contact_type, event_date, COUNT(*) as num_rows
-- FROM
-- (
-- SELECT contact_type, event_date, professional_id, user_id, session_id
-- FROM src.contact_impression
-- WHERE event_date >= '2016-07-01'
-- AND IFNULL(contact_type, 'ZZZZ') <> 'message'
-- UNION ALL
-- SELECT DISTINCT contact_type, event_date, professional_id, user_id, session_id
-- FROM
--   (
--     SELECT contact_type, event_date, professional_id, user_id, 
--       FIRST_VALUE(session_id) OVER (PARTITION BY contact_type, event_date, professional_id, user_id
--                                     ORDER BY gmt_timestamp) AS session_id
--     FROM src.contact_impression
--     WHERE event_date >= '2016-07-01'
--     AND contact_type = 'message'
--   ) msg
-- ) qry
-- WHERE contact_type in ('email', 'message')
-- GROUP BY 1,2
That shows me trends.  Clearly started July 14 and launched
nationwide sometime during the day of Wednesday Aug. 17.

-- SELECT contact_type, professional_id, user_id, COUNT(*) AS dates, MIN(event_date) AS first_date, MAX(event_date) AS last_date
-- FROM
-- (
-- SELECT DISTINCT contact_type, event_date, professional_id, user_id, session_id
-- FROM
--   (
--     SELECT contact_type, event_date, professional_id, user_id, 
--       FIRST_VALUE(session_id) OVER (PARTITION BY contact_type, event_date, professional_id, user_id
--                                     ORDER BY gmt_timestamp) AS session_id
--     FROM src.contact_impression
--     WHERE event_date >= '2016-07-01'
--     AND contact_type = 'message'
--   ) msg
-- ) qry
-- GROUP BY 1,2,3

OK in the data I pulled, dates from 7/14 through 8/23 (1 week ago):
So... 8% of message conversations have contacts in > 1 day.
We only have a small sample of conversations that could have contacts > 30 days ago,
but of those it''s well below 1%.

----

OK I think more people will understand ROW_NUMBER instead of
FIRST_VALUE and DISTINCT.

SELECT event_date, count(*) AS num_rows from
(
SELECT DISTINCT contact_type, event_date, professional_id, user_id, session_id
FROM
  (
    SELECT contact_type, event_date, professional_id, user_id, 
      FIRST_VALUE(session_id) OVER (PARTITION BY contact_type, event_date, professional_id, user_id
                                    ORDER BY gmt_timestamp) AS session_id
    FROM src.contact_impression
    WHERE event_date >= '2015-05-01'
    AND contact_type = 'message'
  ) msg
) qry
group by 1 order by 1

SELECT event_date, count(*) AS num_rows from
(
SELECT *
FROM
  (
    SELECT contact_type, event_date, professional_id, user_id, session_id,
      ROW_NUMBER() OVER (PARTITION BY contact_type, event_date, professional_id, user_id
                                    ORDER BY gmt_timestamp) AS row_num
    FROM src.contact_impression
    WHERE event_date >= '2015-05-01'
    AND contact_type = 'message'
  ) msg
WHERE row_num = 1
) qry
group by 1 order by 1

-- ----


-- with b as 
-- (select 
-- olaf.professional_id
-- , 'Advertiser or Pro' as Advertiser
-- , d.year_month
-- , min(order_line_begin_date) as order_ln_begin_use_date
-- , max(order_line_cancelled_date) as order_ln_cncl_date
-- from dm.order_line_accumulation_fact olaf
-- join dm.date_dim d on d.actual_date = order_line_begin_date
-- where d.year_month >= 201505
-- and olaf.product_line_id in (2,7,4)
-- group by 1,2,3
-- ) 

-- , first_visit as 
-- ( select
--  t.persistent_session_id
--  , t.event_date as first_visit_date
--  from dm.traffic t
--  where t.first_persistent_session = true
--  )


-- select 
-- ci.contact_type
-- , ci.event_date
-- , d.year_month
-- , t.lpv_page_type
-- , t.lpv_medium
-- , t.lpv_content
-- /*looking at user id in traffic and contact impression table to identify RU because traffic might be missing some...need to investigate*/
-- , case when (t.resolved_user_ID is not null or ci.user_id is not null) then 'Registered User' else 'Not Registered' end as Registered_User
-- , if(t.lawyer_user_id, 'Lawyer', 'Consumer') as Lawyer
-- , case when t.first_persistent_session = true then 'First Visit' else '' end as First_Visit
-- ,case when datediff(t.event_date,fv.first_visit_date) <= 30 then 'New User' 
--       else 'Return User' end as User_Status
-- , b.advertiser
-- , count(*) as num_contacts

-- from 
-- (
-- SELECT contact_type, event_date, professional_id, user_id, session_id
-- FROM src.contact_impression
-- WHERE event_date >= '2015-05-01'
-- AND IFNULL(contact_type, 'ZZZZ') <> 'message'
-- UNION ALL
-- SELECT contact_type, event_date, professional_id, user_id, session_id
-- FROM
--   (
--     SELECT contact_type, event_date, professional_id, user_id, session_id,
--       ROW_NUMBER() OVER (PARTITION BY contact_type, event_date, professional_id, user_id
--                                     ORDER BY gmt_timestamp) AS row_num
--     FROM src.contact_impression
--     WHERE event_date >= '2015-05-01'
--     AND contact_type = 'message'
--   ) msg
-- WHERE row_num = 1
-- ) ci
-- left join dm.traffic t on t.session_id = ci.session_id  and t.event_date = ci.event_date
-- join dm.date_dim d on d.actual_date = ci.event_date
-- left join b on b.professional_id  = ci.professional_id and d.year_month = b.year_month and  b.order_ln_begin_use_date <= ci.event_date
-- left join first_visit fv on fv.persistent_session_id = t.persistent_session_id 
-- where ci.event_date >= '2015-05-01'
-- group by ci.user_id, ci.contact_type, ci.event_date, Registered_User, Lawyer, User_Status, First_Visit, d.year_month, b.advertiser, t.lpv_page_type, t.lpv_medium, t.lpv_content

----

SELECT contact_type, event_date, professional_id, user_id, session_id
FROM
  (
    SELECT contact_type, event_date, professional_id, user_id, session_id,
      ROW_NUMBER() OVER (PARTITION BY contact_type, event_date, professional_id, user_id
                                    ORDER BY gmt_timestamp) AS row_num
    FROM src.contact_impression
    WHERE event_date >= '2015-05-01'
    AND contact_type = 'message'
  ) msg
WHERE row_num = 1

PID/UID
113477  1418523
1426907  3577203

-- LOOK dedup on session_id instead of user_id and professional_id,
-- because professional_id may be NULL.
-- BUT session_id is different for same (user_id, professional_id).

-- DROP TABLE tmp_data_dm.coe_temp_dedup;
-- CREATE TABLE tmp_data_dm.coe_temp_dedup AS
-- SELECT
--    contact_type
--   ,gmt_time
--   ,first_event_date
--   ,event_date
--   ,prev_event_date
--   ,user_id
--   ,professional_id
--   ,conversation_id
--   ,row_num
--   ,DATEDIFF(event_date, prev_event_date) AS days_since_last_message
--   ,messages
--   ,CASE WHEN prev_event_date IS NULL THEN 'Y'
--         WHEN DATEDIFF(event_date, prev_event_date) >= 14 THEN 'Y'
--         ELSE 'N'
--    END AS count_new_conversation  -- LOOK this is not going to be enough.
-- FROM
--   (
--     SELECT contact_type, event_date, FROM_UNIXTIME(gmt_timestamp) AS gmt_time, professional_id, user_id, conversation_id
--       ,ROW_NUMBER() OVER    (PARTITION BY contact_type, professional_id, user_id
--                                     ORDER BY gmt_timestamp) AS row_num
--       ,LAG(event_date) OVER (PARTITION BY contact_type, professional_id, user_id
--                                     ORDER BY gmt_timestamp) AS prev_event_date
--       ,FIRST_VALUE(event_date) OVER (PARTITION BY contact_type, professional_id, user_id
--                                     ORDER BY gmt_timestamp) AS first_event_date
--       -- ,COUNT(*) OVER (PARTITION BY contact_type, professional_id, user_id
--       --                               ) AS messages
--     FROM src.contact_impression
--     -- WHERE event_date >= '2015-05-01'
--     WHERE event_date >= '2016-08-01'
--     AND contact_type = 'message'
--   ) msg

SELECT *
FROM tmp_data_dm.coe_temp_dedup
WHERE messages > 1
ORDER BY first_event_date, user_id, professional_id, gmt_time

OH!  conversation_id is just <some standin for professional_id> '-' <user_id>.

324141-3596241 is a good long example w/ a gap.

SELECT user_id, professional_id, SUM(CASE WHEN count_new_conversation = 'Y' THEN 1 ELSE 0 END) AS deduped_count
FROM tmp_data_dm.coe_temp_dedup
WHERE messages > 1
GROUP BY 1,2
HAVING SUM(CASE WHEN count_new_conversation = 'Y' THEN 1 ELSE 0 END) > 1
ORDER BY first_event_date, user_id, professional_id, gmt_time

SELECT
   user_id
  ,professional_id
  ,SUM(chat_conversations) AS chat_conversations
  ,SUM(chat_messages) AS chat_messages
FROM tmp_data_dm.coe_temp_dedup
GROUP BY 1,2
ORDER BY 3 DESC, user_id, professional_id

-- DROP TABLE tmp_data_dm.coe_temp_dedup;
-- CREATE TABLE tmp_data_dm.coe_temp_dedup AS
-- SELECT
--    contact_type
--   ,event_date
--   ,user_id
--   ,professional_id
--   ,COUNT(*) AS chat_messages
--   ,SUM(CASE WHEN count_new_conversation = 'Y' THEN 1 ELSE 0 END) AS chat_conversations
-- FROM
--   (
--   SELECT
--      contact_type
--     ,gmt_time
--     ,first_event_date
--     ,event_date
--     ,prev_event_date
--     ,user_id
--     ,professional_id
--     ,conversation_id
--     ,row_num
--     ,DATEDIFF(event_date, prev_event_date) AS days_since_last_message
--     ,CASE WHEN prev_event_date IS NULL THEN 'Y'
--           WHEN DATEDIFF(event_date, prev_event_date) >= 14 THEN 'Y'
--           ELSE 'N'
--      END AS count_new_conversation
--   FROM
--     (
--       SELECT contact_type, event_date, FROM_UNIXTIME(gmt_timestamp) AS gmt_time, professional_id, user_id, conversation_id
--         ,ROW_NUMBER() OVER    (PARTITION BY contact_type, professional_id, user_id
--                                       ORDER BY gmt_timestamp) AS row_num
--         ,LAG(event_date) OVER (PARTITION BY contact_type, professional_id, user_id
--                                       ORDER BY gmt_timestamp) AS prev_event_date
--         ,FIRST_VALUE(event_date) OVER (PARTITION BY contact_type, professional_id, user_id
--                                       ORDER BY gmt_timestamp) AS first_event_date
--       FROM src.contact_impression
--       -- WHERE event_date >= '2015-05-01'
--       WHERE event_date >= '2016-08-01'
--       AND contact_type = 'message'
--     ) msg
--   ) qry
-- GROUP BY 1,2,3,4

-- DROP TABLE tmp_data_dm.coe_temp_dedup;
-- CREATE TABLE tmp_data_dm.coe_temp_dedup AS
-- SELECT
--    contact_type
--   ,event_date
--   ,user_id
--   ,professional_id
--   ,session_id
--   ,COUNT(*) AS chat_messages
--   ,SUM(CASE WHEN count_new_conversation = 'Y' THEN 1 ELSE 0 END) AS chat_conversations
-- FROM
--   (
--   SELECT
--      contact_type
--     ,gmt_time
--     ,event_date
--     ,prev_event_date
--     ,user_id
--     ,professional_id
--     ,session_id
--     ,CASE WHEN prev_event_date IS NULL THEN 'Y'
--           WHEN DATEDIFF(event_date, prev_event_date) >= 14 THEN 'Y'
--           ELSE 'N'
--      END AS count_new_conversation
--   FROM
--     (
--       SELECT contact_type, event_date, FROM_UNIXTIME(gmt_timestamp) AS gmt_time, professional_id, user_id, session_id
--         ,LAG(event_date) OVER (PARTITION BY contact_type, professional_id, user_id
--                                       ORDER BY gmt_timestamp) AS prev_event_date
--       FROM src.contact_impression
--       -- WHERE event_date >= '2015-05-01'
--       WHERE event_date >= '2016-08-01'
--       AND contact_type = 'message'
--     ) ci
--   ) msg
-- GROUP BY 1,2,3,4,5

-- DROP TABLE tmp_data_dm.coe_temp_dedup;
-- CREATE TABLE tmp_data_dm.coe_temp_dedup AS
-- SELECT
--    contact_type
--   ,event_date
--   ,user_id
--   ,professional_id
--   ,session_id
--   ,COUNT(*) AS chat_messages
--   ,SUM(CASE WHEN prev_event_date IS NULL THEN 1
--             WHEN DATEDIFF(event_date, prev_event_date) >= 14 THEN 1
--             ELSE 0
--        END) AS chat_conversations
-- FROM
--   (
--   SELECT contact_type, event_date, FROM_UNIXTIME(gmt_timestamp) AS gmt_time, professional_id, user_id, session_id
--     ,LAG(event_date) OVER (PARTITION BY contact_type, professional_id, user_id
--                                   ORDER BY gmt_timestamp) AS prev_event_date
--   FROM src.contact_impression
--   -- WHERE event_date >= '2015-05-01'
--   WHERE event_date >= '2016-08-01'
--   AND contact_type = 'message'
--   ) msg
-- GROUP BY 1,2,3,4,5

----

Here is the sample code to count conversations and messages:
SELECT
   contact_type
  ,event_date
  ,user_id
  ,professional_id
  ,session_id
  ,COUNT(*) AS chat_messages
  ,SUM(CASE WHEN prev_event_date IS NULL THEN 1
            WHEN DATEDIFF(event_date, prev_event_date) >= 14 THEN 1
            ELSE 0
       END) AS chat_conversations
FROM
  (
  SELECT contact_type, event_date, FROM_UNIXTIME(gmt_timestamp) AS gmt_time, professional_id, user_id, session_id
    ,LAG(event_date) OVER (PARTITION BY contact_type, professional_id, user_id
                                  ORDER BY gmt_timestamp) AS prev_event_date
  FROM src.contact_impression
  WHERE event_date >= '2016-08-01'
  AND contact_type = 'message'
  ) msg
GROUP BY 1,2,3,4,5


----

The join to traffic is what''s so slow, so if we could have a table 
populated with that daily then we could manage the view.

Here is the whole new version: (deduping at 14-day level)

-- DROP TABLE tmp_data_dm.coe_temp_contacts;
-- CREATE TABLE tmp_data_dm.coe_temp_contacts AS


-- with b as 
-- (select 
-- olaf.professional_id
-- , 'Advertiser or Pro' as Advertiser
-- , d.year_month
-- , min(order_line_begin_date) as order_ln_begin_use_date
-- , max(order_line_cancelled_date) as order_ln_cncl_date
-- from dm.order_line_accumulation_fact olaf
-- join dm.date_dim d on d.actual_date = order_line_begin_date
-- where d.year_month >= 201505
-- and olaf.product_line_id in (2,7,4)
-- group by 1,2,3
-- ) 

-- , first_visit as 
-- ( select
--  t.persistent_session_id
--  , t.event_date as first_visit_date
--  from dm.traffic t
--  where t.first_persistent_session = true
--  )


-- select 
-- ci.contact_type
-- , ci.event_date
-- , d.year_month
-- , t.lpv_page_type
-- , t.lpv_medium
-- , t.lpv_content
-- /*looking at user id in traffic and contact impression table to identify RU because traffic might be missing some...need to investigate*/
-- , case when (t.resolved_user_ID is not null or ci.user_id is not null) then 'Registered User' else 'Not Registered' end as Registered_User
-- , if(t.lawyer_user_id, 'Lawyer', 'Consumer') as Lawyer
-- , case when t.first_persistent_session = true then 'First Visit' else '' end as First_Visit
-- ,case when datediff(t.event_date,fv.first_visit_date) <= 30 then 'New User' 
--       else 'Return User' end as User_Status
-- , b.advertiser
-- , count(*) as num_contacts

-- from 
-- (
-- SELECT contact_type, event_date, professional_id, user_id, session_id
-- FROM src.contact_impression
-- WHERE event_date >= '2015-05-01'
-- AND IFNULL(contact_type, 'ZZZZ') <> 'message'
-- UNION ALL
-- SELECT contact_type, event_date, professional_id, user_id, session_id
-- FROM
--   (  -- Filter to only conversation-starting messages.
--   SELECT
--      contact_type
--     ,event_date
--     ,user_id
--     ,professional_id
--     ,session_id
--   FROM
--     (
--     SELECT contact_type, event_date, FROM_UNIXTIME(gmt_timestamp) AS gmt_time, professional_id, user_id, session_id
--       ,LAG(event_date) OVER (PARTITION BY contact_type, professional_id, user_id
--                                     ORDER BY gmt_timestamp) AS prev_event_date
--     FROM src.contact_impression
--     WHERE event_date >= '2015-05-01'
--     AND contact_type = 'message'
--     ) ctc
--   WHERE ((prev_event_date IS NULL)
--       OR (DATEDIFF(event_date, prev_event_date) >= 14))
--   ) msg
-- ) ci
-- left join dm.traffic t on t.session_id = ci.session_id  and t.event_date = ci.event_date
-- join dm.date_dim d on d.actual_date = ci.event_date
-- left join b on b.professional_id  = ci.professional_id and d.year_month = b.year_month and  b.order_ln_begin_use_date <= ci.event_date
-- left join first_visit fv on fv.persistent_session_id = t.persistent_session_id 
-- where ci.event_date >= '2015-05-01'
-- group by ci.user_id, ci.contact_type, ci.event_date, Registered_User, Lawyer, User_Status, First_Visit, d.year_month, b.advertiser, t.lpv_page_type, t.lpv_medium, t.lpv_content

