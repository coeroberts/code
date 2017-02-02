SELECT contact_type, event_date, `timestamp` as ts, professional_id, user_id, session_id
FROM src.contact_impression
WHERE event_date = '2016-08-01'
AND contact_type = 'message'
