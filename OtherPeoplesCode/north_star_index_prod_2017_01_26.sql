----------------

WITH timeframes AS
(
SELECT
   tf.period
  ,tf.period_num
  ,tf.period_type
  ,tf.period_start_date
  ,tf.period_end_date
  ,tf.report_chart_date
FROM tmp_data_dm.coe_north_star_timeframes tf
  CROSS JOIN
    (
    SELECT
       actual_date AS today
      ,from_unixtime(unix_timestamp( cast(actual_date as timestamp) - interval 12 months), 'yyyy-MM-dd') AS todays_date_last_year
      ,from_unixtime(unix_timestamp((cast(actual_date as timestamp) - interval 12 months) - interval 2 weeks), 'yyyy-MM-dd') AS todays_date_last_year_minus_2_weeks
      ,from_unixtime(unix_timestamp( cast(actual_date as timestamp) - interval 14 months), 'yyyy-MM-dd') AS todays_date_last_year_minus_2_months
    FROM dm.date_dim
    WHERE from_unixtime(unix_timestamp(NOW()), 'yyyy-MM-dd') = actual_date
    ) td
WHERE
     (    tf.period_type = 'Weekly'
      AND td.todays_date_last_year_minus_2_weeks <= tf.period_start_date
      AND tf.period_end_date < td.today
     )
  OR
     (    tf.period_type = 'Monthly'
      AND td.todays_date_last_year_minus_2_months <= tf.period_start_date
      AND tf.period_end_date < td.today
     )
)

, services_events AS
(
  SELECT
     tf1.period_num
    ,ofr.package_category
    ,SUM(CASE WHEN evt.event_type = 'capture_succeeded' THEN 1 ELSE 0 END) -
     SUM(CASE WHEN evt.event_type = 'refund'            THEN 1 ELSE 0 END) AS net_transactions
  FROM  src.ocato_financial_event_logs evt
    INNER JOIN timeframes tf1
            ON from_unixtime(unix_timestamp(CAST(evt.created_at_pst AS TIMESTAMP)), 'yyyy-MM-dd') BETWEEN tf1.period_start_date AND tf1.period_end_date
    LEFT OUTER JOIN 
      (
      SELECT
         oo.id
        ,CASE WHEN pkg.package_category_id = 1 THEN 'Advisor'
              WHEN pkg.package_category_id = 2 THEN 'Doc Review'
              WHEN pkg.package_category_id = 3 THEN 'Full Service'
              ELSE 'Unknown'
         END AS package_category
      FROM         src.ocato_offers oo
        LEFT OUTER JOIN (SELECT id, package_category_id FROM src.ocato_packages) pkg
                ON oo.package_id = pkg.id
      ) ofr
        ON evt.offer_id = ofr.id
  GROUP BY 1,2
)

, contacts AS
(
SELECT 
   tf2.period_num
  ,ci.contact_type
  ,COUNT(*) AS num_contacts
FROM 
(
SELECT contact_type, event_date, professional_id, user_id, session_id
FROM src.contact_impression
WHERE event_date >= '2015-05-01'
  AND IFNULL(contact_type, 'ZZZZ') NOT IN ('message', 'phone')
UNION ALL
SELECT contact_type, event_date, professional_id, user_id, session_id
FROM src.contact_impression
WHERE event_date >= '2015-05-01'
  AND contact_type = 'phone'
  AND duration >= 120
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
    INNER JOIN timeframes tf2
            ON from_unixtime(unix_timestamp(CAST(ci.event_date AS TIMESTAMP)), 'yyyy-MM-dd') BETWEEN tf2.period_start_date AND tf2.period_end_date
GROUP BY 1,2
)

SELECT
   tf0.period
  ,tf0.period_num
  ,tf0.period_type
  ,tf0.period_start_date
  ,tf0.period_end_date
  ,tf0.report_chart_date
  ,qry.metric_type
  ,qry.metric_value
  ,qry.north_star_index_for_pct
  ,qry.services_advisor_sessions
  ,qry.services_doc_review
  ,qry.services_full_service
  ,qry.chat_conversations_and_emails
  ,qry.phone_calls_at_least_2_mins
  ,qry.website_visits_scaled
  ,qry.client_reviews
  ,qry.q_and_a_within_48hours
FROM
(
SELECT
   met.period_num
  ,met.metric_type
  ,met.metric_value
  ,SUM(met.metric_value) OVER(PARTITION BY met.period_num) AS north_star_index_for_pct
  ,met.services_advisor_sessions
  ,met.services_doc_review
  ,met.services_full_service
  ,met.chat_conversations_and_emails
  ,met.phone_calls_at_least_2_mins
  ,met.website_visits_scaled
  ,met.client_reviews
  ,met.q_and_a_within_48hours
FROM
  (
  SELECT
     inn.period_num
    ,inn.metric_type
    ,SUM(inn.metric_value) AS metric_value
    ,SUM(CASE WHEN inn.metric_type = 'Services - Advisor Sessions'   THEN inn.metric_value ELSE 0 END) AS services_advisor_sessions
    ,SUM(CASE WHEN inn.metric_type = 'Services - Doc Review'         THEN inn.metric_value ELSE 0 END) AS services_doc_review
    ,SUM(CASE WHEN inn.metric_type = 'Services - Full Service'       THEN inn.metric_value ELSE 0 END) AS services_full_service
    ,SUM(CASE WHEN inn.metric_type = 'Chat Conversations and Emails' THEN inn.metric_value ELSE 0 END) AS chat_conversations_and_emails
    ,SUM(CASE WHEN inn.metric_type = 'Phone Calls at least 2 mins'   THEN inn.metric_value ELSE 0 END) AS phone_calls_at_least_2_mins
    ,SUM(CASE WHEN inn.metric_type = 'Website Visits (Scaled)'       THEN inn.metric_value ELSE 0 END) AS website_visits_scaled
    ,SUM(CASE WHEN inn.metric_type = 'Client Reviews'                THEN inn.metric_value ELSE 0 END) AS client_reviews
    ,SUM(CASE WHEN inn.metric_type = 'Q and A within 48 hours'       THEN inn.metric_value ELSE 0 END) AS q_and_a_within_48hours
  FROM
    (
        SELECT
           evt1.period_num
          ,'Services - Advisor Sessions' AS metric_type
          ,evt1.net_transactions AS metric_value
        FROM services_events evt1
        WHERE evt1.package_category = 'Advisor'
      UNION ALL
        SELECT
           evt2.period_num
          ,'Services - Doc Review' AS metric_type
          ,evt2.net_transactions AS metric_value
        FROM services_events evt2
        WHERE evt2.package_category = 'Doc Review'
      UNION ALL
        SELECT
           evt3.period_num
          ,'Services - Full Service' AS metric_type
          ,evt3.net_transactions AS metric_value
        FROM services_events evt3
        WHERE evt3.package_category = 'Full Service'
      UNION ALL
        SELECT
           con1.period_num
          ,'Chat Conversations and Emails' AS metric_type
          ,SUM(con1.num_contacts) AS metric_value
        FROM contacts con1
        WHERE contact_type IN ('message', 'email')
        GROUP BY 1,2
      UNION ALL
        SELECT
           con1.period_num
          ,'Phone Calls at least 2 mins' AS metric_type
          ,SUM(con1.num_contacts) AS metric_value
        FROM contacts con1
        WHERE contact_type IN ('phone')
        GROUP BY 1,2
      UNION ALL
        SELECT
           con1.period_num
          ,'Website Visits (Scaled)' AS metric_type
          ,CAST(SUM(con1.num_contacts) / 10 AS INTEGER) AS metric_value
        FROM contacts con1
        WHERE contact_type IN ('website')
        GROUP BY 1,2
      UNION ALL
        SELECT
           tf4.period_num
          ,'Client Reviews' AS metric_type
          ,COUNT(*) AS  metric_value
        FROM         src.barrister_professional_review pfrv
          INNER JOIN dm.professional_dimension pf
                  ON pf.professional_id = pfrv.professional_id
                 AND pf.professional_delete_indicator = 'Not Deleted'
                 AND pf.professional_name = 'lawyer'
                 AND pf.industry_name = 'Legal'
          INNER JOIN timeframes tf4
                  ON TO_DATE(pfrv.created_at) BETWEEN tf4.period_start_date AND tf4.period_end_date
        WHERE pfrv.approval_status_id IN (1, 2)
        GROUP BY 1
      UNION ALL
        SELECT
           tf5.period_num
          ,'Q and A within 48 hours' AS metric_type
          ,SUM(CASE WHEN ques.elapsed_48h <> 'Y' THEN NULL
                    WHEN ques.answertime_mins <= 2880 THEN 1 
                    ELSE 0 END) AS metric_value
        FROM
          (
          SELECT
             que.id AS question_id
            ,TO_DATE(que.created_at) AS q_created_date
            ,CASE WHEN que.created_at <= date_sub(now(), interval 2880 minutes) THEN 'Y' ELSE 'N' END AS elapsed_48h
            ,MAX(1) AS questions
            ,MAX(CASE WHEN ans.id IS NOT NULL THEN 1 ELSE 0 END) AS q_answered
            ,COUNT(ans.id) AS answers_total
            ,round((min(unix_timestamp(ans.created_at)-unix_timestamp(que.created_at)))/60,0) AS answertime_mins
          FROM
                       src.content_question que
            LEFT OUTER JOIN src.content_answer ans
                    ON que.id = ans.question_id
                   AND ans.approval_status_id IN (1,2)
          WHERE que.approval_status_id IN (1,2)
          GROUP BY 1,2,3
          ) ques
          INNER JOIN timeframes tf5
                  ON ques.q_created_date BETWEEN tf5.period_start_date AND tf5.period_end_date
        GROUP BY 1
    ) inn
  GROUP BY 1,2
  ) met
) qry
  INNER JOIN timeframes tf0
          ON qry.period_num = tf0.period_num
