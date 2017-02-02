From Nadine:
FYI - i talked to Sendi about North Star.  Basically he wants to 
make sure Sayle & Monica sign off on definitions.  Create a tableau 
that pulls together the high level index.  We can have the separate 
tabs with each metric.  Publish it so it's updated and repeatable.
That's all.  Matt will be working on the leading indicators &  
building out (hopefully in our same tableau workbook) those views.

SELECT    
   created_by AS professional_id  
  ,COUNT(DISTINCT question_id) AS questions_answered
FROM src.content_answer              
WHERE approval_status_id IN (1,2)
GROUP BY 1       

content_question
    id
    subject
    body
    city_id
    state_id
    location_id
    created_at
    updated_at
    created_by
    updated_by
    annotation
    specialty_assigned_at
    ip_address
    approval_status_id
    additional_details
    specialty_id
    specialty_id_updated_at
    is_spam: N, 1 Unknown, 246 Y
    hi_seo_value
    lo_seo_value
    quality: 0 to 162; INTEGER.  Wondering if this is sum of helpful votes
    record_flag
    etl_load_date

content_answer
    id
    question_id
    body
    created_at
    updated_at
    created_by
    updated_by
    annotation
    ip_address
    approval_status_id
    best_answer: Y/N and 1 unknown.  about 3% are Y,
    needs_lawyer_id
    is_spam: N, 1 Unknown, 8 Y
    disclaimer
    answer_medium_id
    answer_quality: ranges 0 to 115.75 in increments of .25.
    draft: 0/1, mostly 0.
    record_flag
    etl_load_date

  ,COUNT(DISTINCT que.id) AS questions_total

-- SELECT
--    ques.q_created_month
--   ,ques.question_status
--   ,ques.is_spam
--   ,ques.best_answers
--   ,SUM(questions) AS      questions_total
--   ,SUM(CASE WHEN ques.draft_answers     > 0 THEN questions ELSE 0 END) AS  questions_w_draft_answers
--   ,SUM(CASE WHEN ques.spam_answers      > 0 THEN questions ELSE 0 END) AS  questions_w_spam_answers
--   ,SUM(CASE WHEN ques.answers_approved  > 0 THEN questions ELSE 0 END) AS  questions_w_answers_approved
--   ,SUM(CASE WHEN ques.answers_pending   > 0 THEN questions ELSE 0 END) AS  questions_w_answers_pending
--   ,SUM(CASE WHEN ques.answers_dispute   > 0 THEN questions ELSE 0 END) AS  questions_w_answers_dispute
--   ,SUM(CASE WHEN ques.answers_denied    > 0 THEN questions ELSE 0 END) AS  questions_w_answers_denied
--   ,SUM(CASE WHEN ques.answers_no_status > 0 THEN questions ELSE 0 END) AS  questions_w_answers_no_status
--   ,SUM(answers_total) AS      answers_total
--   ,SUM(draft_answers) AS      draft_answers
--   ,SUM(spam_answers) AS       spam_answers
--   ,SUM(answers_approved) AS   answers_approved
--   ,SUM(answers_pending) AS    answers_pending
--   ,SUM(answers_dispute) AS    answers_dispute
--   ,SUM(answers_denied) AS     answers_denied
--   ,SUM(answers_no_status) AS  answers_no_status
-- FROM
--   (
--   SELECT
--      que.id AS question_id
--     ,TO_DATE(TRUNC(que.created_at, 'MONTH')) AS q_created_month
--     ,qst.name AS question_status
--     ,CASE WHEN que.is_spam = 'Y' THEN 'Spam' ELSE 'OK' END AS is_spam
--     ,1 AS questions
--     ,COUNT(ans.id) AS answers_total
--     ,COUNT(CASE WHEN ans.draft = 1         THEN ans.id ELSE NULL END) AS draft_answers
--     ,COUNT(CASE WHEN ans.best_answer = 'Y' THEN ans.id ELSE NULL END) AS best_answers
--     ,COUNT(CASE WHEN ans.is_spam = 'Y'     THEN ans.id ELSE NULL END) AS spam_answers
--     ,COUNT(CASE WHEN ast.symbolic_name = 'APPROVED' THEN ans.id ELSE NULL END) AS answers_approved
--     ,COUNT(CASE WHEN ast.symbolic_name = 'PENDING'  THEN ans.id ELSE NULL END) AS answers_pending
--     ,COUNT(CASE WHEN ast.symbolic_name = 'DISPUTE'  THEN ans.id ELSE NULL END) AS answers_dispute
--     ,COUNT(CASE WHEN ast.symbolic_name = 'DENIED'   THEN ans.id ELSE NULL END) AS answers_denied
--     ,COUNT(CASE WHEN ast.symbolic_name IS NULL      THEN ans.id ELSE NULL END) AS answers_no_status
--   FROM
--                src.content_question que
--     LEFT OUTER JOIN src.content_answer ans
--             ON que.id = ans.question_id
--     LEFT OUTER JOIN src.content_approval_status qst
--             ON que.approval_status_id = qst.id
--     LEFT OUTER JOIN src.content_approval_status ast
--             ON ans.approval_status_id = ast.id
--   WHERE que.id <> -1
--   GROUP BY 1,2,3,4,5
--   ) ques
-- GROUP BY 1,2,3,4

Vast majority of question statuses are pending
We have some spam questions w/ pending status.
Most do not have city or state buyt do have location_id.

SELECT
   ques.q_created_month
  ,SUM(q_answered) AS     q_answered
  ,SUM(CASE WHEN answertime_mins <= 2880 THEN 1 ELSE 0 END) AS q_answered_within_48h
  ,SUM(questions) AS      questions_total
  ,SUM(CASE WHEN ques.draft_answers     > 0 THEN questions ELSE 0 END) AS  questions_w_draft_answers
  ,SUM(CASE WHEN ques.answers_approved  > 0 THEN questions ELSE 0 END) AS  questions_w_answers_approved
  ,SUM(CASE WHEN ques.answers_pending   > 0 THEN questions ELSE 0 END) AS  questions_w_answers_pending
  ,SUM(answers_total) AS      answers_total
  ,SUM(draft_answers) AS      draft_answers
  ,SUM(answers_approved) AS   answers_approved
  ,SUM(answers_pending) AS    answers_pending
FROM
  (
  SELECT
     que.id AS question_id
    ,TO_DATE(TRUNC(que.created_at, 'MONTH')) AS q_created_month
    ,CASE WHEN 
    ,qst.name AS question_status
    ,MAX(1) AS questions
    ,MAX(CASE WHEN ans.id IS NOT NULL THEN 1 ELSE 0 END) AS q_answered
    ,COUNT(ans.id) AS answers_total
    ,COUNT(CASE WHEN ans.draft = 1         THEN ans.id ELSE NULL END) AS draft_answers
    ,COUNT(CASE WHEN ans.best_answer = 'Y' THEN ans.id ELSE NULL END) AS best_answers
    ,COUNT(CASE WHEN ast.symbolic_name = 'APPROVED' THEN ans.id ELSE NULL END) AS answers_approved
    ,COUNT(CASE WHEN ast.symbolic_name = 'PENDING'  THEN ans.id ELSE NULL END) AS answers_pending
    ,round((min(unix_timestamp(ans.created_at)-unix_timestamp(que.created_at)))/60,0) AS answertime_mins
  FROM
               src.content_question que
    LEFT OUTER JOIN src.content_answer ans
            ON que.id = ans.question_id
           AND ans.approval_status_id IN (1,2)  -- AND ans.is_spam <> 'Y'
    LEFT OUTER JOIN src.content_approval_status qst
            ON que.approval_status_id = qst.id
    LEFT OUTER JOIN src.content_approval_status ast
            ON ans.approval_status_id = ast.id
  WHERE que.id <> -1
    AND que.approval_status_id IN (1,2)  -- AND que.is_spam <> 'Y'
  GROUP BY 1,2,3
  ) ques
GROUP BY 1
ORDER BY 1

QUESTIONS:
-- - Exclude is_spam = 'Y'?  They do show up on the site.
--   There are 18 of them, and most do look legit.  No.

-- Definition of questions answered within 48h:
-- Get all approved and pending questions by create date and time (whether answered or not).
-- For each question, get all approved and pending answers.
-- For each question, calculate the number of minutes to the first answer as:
--   (first_answer_create_time - question_create_time)/60 (rounded to nearest integer)
-- (where both questions and answers meet the above filter criteria)
-- We will be interested in both the raw number of questions answered within
-- 48 hours and the proportion of those questions to total questions asked.
-- If 48 hours have not elapsed since the create date and time, the count of
-- questions asked should be populated, but the count of questions answered 
-- within 48 hours should be NULL.
SELECT
   ques.q_created_month
  ,SUM(ques.questions) AS      questions_asked
  -- ,SUM(ques.q_answered) AS     q_answered
  ,SUM(CASE WHEN ques.elapsed_48h <> 'Y' THEN NULL
            WHEN ques.answertime_mins <= 2880 THEN 1 
            ELSE 0 END) AS q_answered_within_48h
  -- ,SUM(ques.answers_total) AS  answers_total
FROM
  (
  SELECT
     que.id AS question_id
    ,TO_DATE(TRUNC(que.created_at, 'MONTH')) AS q_created_month
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
GROUP BY 1
ORDER BY 1

-- Definition of client reviews:
-- Get all (pending and) approved reviews by create date, where the professional
-- is a lawyer, in the legal industry, and has not been deleted.
-- We will be interested in the raw number of reviews.
SELECT
  TO_DATE(pfrv.created_at) AS review_date
 ,COUNT(*) AS num_reviews
FROM         src.barrister_professional_review pfrv
  INNER JOIN dm.professional_dimension pf
          ON pf.professional_id = pfrv.professional_id
         AND pf.professional_delete_indicator = 'Not Deleted'
         AND pf.professional_name = 'lawyer'
         AND pf.industry_name = 'Legal'
WHERE pfrv.approval_status_id IN (1,2)
GROUP BY 1

SELECT COUNT(*)
  FROM src.contact_impression
  WHERE event_date >= '2016-08-01'
    AND professional_id = -1
returns 1012 (of 1519431 total)
I think for the contacts I just say go get it from the contacts data source.

----
tmp_data_dm.coe_services_event_detail
tmp_data_dm.coe_services_session_detail


SELECT
   dt.year_month
  ,SUM(CASE WHEN evt.event_category = 'purchase' THEN 1 ELSE 0 END) AS   purchases
  ,SUM(CASE WHEN evt.event_category = 'cc_charge' THEN 1 ELSE 0 END) AS  cc_charges
  ,SUM(CASE WHEN evt.event_category = 'refund' THEN 1 ELSE 0 END) AS     refunds
  ,SUM(CASE WHEN evt.event_category = 'void' THEN 1 ELSE 0 END) AS       voids
FROM         tmp_data_dm.coe_services_event_detail evt
  INNER JOIN dm.date_dim dt
          ON evt.event_date = dt.actual_date
GROUP BY 1
ORDER BY 1

SELECT
   dt.year_month
  ,SUM(ses.purchase_count) AS   purchases
  ,SUM(ses.cc_charge_count) AS  cc_charges
  ,SUM(ses.failed_payment_count) AS  failed_payments
  ,SUM(ses.refund_count) AS     refunds
  ,SUM(ses.void_count) AS       voids
FROM         tmp_data_dm.coe_services_session_detail ses
  INNER JOIN dm.date_dim dt
          ON ses.session_start_date = dt.actual_date
WHERE dt.year_month >= 201601
GROUP BY 1
ORDER BY 1

SELECT
   dt.year_month
  ,ses.*
FROM         tmp_data_dm.coe_services_session_detail ses
  INNER JOIN dm.date_dim dt
          ON ses.session_start_date = dt.actual_date
WHERE dt.year_month = 201609
  AND ses.purchase_count = 1
  AND ses.cc_charge_count = 0
  AND ses.void_count = 0
OK the difference appears to be:
  Attorney not selected at purchase.
  Ultimate CC failure (failed_payment_count = 1)
Weird in Feb: 14448 and 15315

Happy with this one for month.  Changing for day, week, month.
-- DROP TABLE tmp_data_dm.coe_north_star_draft1;
-- CREATE TABLE tmp_data_dm.coe_north_star_draft1 AS
-- SELECT
--    qry.year_month
--   ,mth.month_begin_date
--   ,IFNULL(qry.q_answered_within_48h_raw, 0) + 
--    IFNULL(qry.client_reviews_raw, 0) + 
--    IFNULL(qry.contacts_email_raw, 0) + IFNULL(qry.contacts_message_raw, 0) + 
--    (IFNULL(qry.contacts_website_raw, 0) / 10) + 
--    IFNULL(qry.contacts_phone_raw, 0) + 
--    IFNULL(qry.ls_net_transactions_advisor_raw, 0) + 
--    IFNULL(qry.ls_net_transactions_doc_review_raw, 0) + 
--    IFNULL(qry.ls_net_transactions_offline_raw, 0) AS     north_star_index
--   ,qry.q_answered_within_48h_raw AS                      q_and_a_within_48h
--   ,qry.client_reviews_raw AS                             client_reviews
--   ,qry.contacts_email_raw + qry.contacts_message_raw AS  emails_or_chat_conversations
--   ,qry.contacts_website_raw AS                           website_visits
--   ,qry.contacts_phone_raw AS                             phone_calls
--   ,qry.ls_net_transactions_advisor_raw AS                ls_net_transactions_advisor
--   ,qry.ls_net_transactions_doc_review_raw AS             ls_net_transactions_doc_review
--   ,qry.ls_net_transactions_offline_raw AS                ls_net_transactions_offline
-- FROM
--   (
--   SELECT
--      year_month
--     ,SUM(ls_net_transactions_advisor) AS     ls_net_transactions_advisor_raw
--     ,SUM(ls_net_transactions_doc_review) AS  ls_net_transactions_doc_review_raw
--     ,SUM(ls_net_transactions_offline) AS     ls_net_transactions_offline_raw
--     ,SUM(contacts_email) AS                  contacts_email_raw
--     ,SUM(contacts_message) AS                contacts_message_raw
--     ,SUM(contacts_website) AS                contacts_website_raw
--     ,SUM(contacts_phone) AS                  contacts_phone_raw
--     ,SUM(client_reviews) AS                  client_reviews_raw
--     ,SUM(questions_asked) AS                 questions_asked_raw
--     ,SUM(q_answered_within_48h) AS           q_answered_within_48h_raw
--   FROM
--     (
--       SELECT
--          cat.year_month
--         ,SUM(CASE WHEN cat.package_category = 'Advisor'
--                     THEN cat.ls_transactions - cat.ls_refunds
--                     ELSE 0 END) AS ls_net_transactions_advisor
--         ,SUM(CASE WHEN cat.package_category = 'Doc Review'
--                     THEN cat.ls_transactions - cat.ls_refunds
--                     ELSE 0 END) AS ls_net_transactions_doc_review
--         ,SUM(CASE WHEN cat.package_category = 'Offline Service'
--                     THEN cat.ls_transactions - cat.ls_refunds
--                     ELSE 0 END) AS ls_net_transactions_offline
--         ,SUM(NULL) AS contacts_email
--         ,SUM(NULL) AS contacts_message
--         ,SUM(NULL) AS contacts_website
--         ,SUM(NULL) AS contacts_phone
--         ,SUM(NULL) AS client_reviews
--         ,SUM(NULL) AS questions_asked
--         ,SUM(NULL) AS q_answered_within_48h
--       FROM
--         (
--         SELECT
--            dt1.year_month
--           ,evt.package_category
--           ,SUM(CASE WHEN evt.event_category = 'cc_charge' THEN 1 ELSE 0 END) AS ls_transactions
--           ,SUM(CASE WHEN evt.event_category = 'refund'    THEN 1 ELSE 0 END) AS ls_refunds
--         FROM         tmp_data_dm.coe_services_event_detail evt
--           INNER JOIN dm.date_dim dt1
--                   ON evt.event_date = dt1.actual_date
--         WHERE dt1.year_month >= 201601
--         GROUP BY 1,2
--         ) cat
--       GROUP BY 1
--     UNION ALL
--       SELECT
--          dt2.year_month
--         ,SUM(NULL) AS ls_net_transactions_advisor
--         ,SUM(NULL) AS ls_net_transactions_doc_review
--         ,SUM(NULL) AS ls_net_transactions_offline
--         ,SUM(CASE WHEN ctc.contact_type = 'email'   THEN ctc.num_contacts ELSE 0 END) AS contacts_email
--         ,SUM(CASE WHEN ctc.contact_type = 'message' THEN ctc.num_contacts ELSE 0 END) AS contacts_message
--         ,SUM(CASE WHEN ctc.contact_type = 'website' THEN ctc.num_contacts ELSE 0 END) AS contacts_website
--         ,SUM(NULL) AS contacts_phone
--         ,SUM(NULL) AS client_reviews
--         ,SUM(NULL) AS questions_asked
--         ,SUM(NULL) AS q_answered_within_48h
--       FROM         tmp_data_dm.coe_temp_contacts_ds ctc
--         INNER JOIN dm.date_dim dt2
--                 ON ctc.event_date = dt2.actual_date
--       WHERE dt2.year_month >= 201501
--       GROUP BY 1
--     UNION ALL
--       SELECT
--          dt3.year_month
--         ,SUM(NULL) AS ls_net_transactions_advisor
--         ,SUM(NULL) AS ls_net_transactions_doc_review
--         ,SUM(NULL) AS ls_net_transactions_offline
--         ,SUM(NULL) AS contacts_email
--         ,SUM(NULL) AS contacts_message
--         ,SUM(NULL) AS contacts_website
--         ,SUM(CASE WHEN cim.contact_type = 'phone' AND cim.duration >= 120 THEN 1 ELSE 0 END) AS contacts_phone
--         ,SUM(NULL) AS client_reviews
--         ,SUM(NULL) AS questions_asked
--         ,SUM(NULL) AS q_answered_within_48h
--       FROM         src.contact_impression cim
--         INNER JOIN dm.date_dim dt3
--                 ON cim.event_date = dt3.actual_date
--       WHERE dt3.year_month >= 201501
--       GROUP BY 1
--     UNION ALL
--       SELECT
--          dt4.year_month
--         ,SUM(NULL) AS ls_net_transactions_advisor
--         ,SUM(NULL) AS ls_net_transactions_doc_review
--         ,SUM(NULL) AS ls_net_transactions_offline
--         ,SUM(NULL) AS contacts_email
--         ,SUM(NULL) AS contacts_message
--         ,SUM(NULL) AS contacts_website
--         ,SUM(NULL) AS contacts_phone
--         ,COUNT(*) AS client_reviews
--         ,SUM(NULL) AS questions_asked
--         ,SUM(NULL) AS q_answered_within_48h
--       FROM         src.barrister_professional_review pfrv
--         INNER JOIN dm.professional_dimension pf
--                 ON pf.professional_id = pfrv.professional_id
--                AND pf.professional_delete_indicator = 'Not Deleted'
--                AND pf.professional_name = 'lawyer'
--                AND pf.industry_name = 'Legal'
--         INNER JOIN dm.date_dim dt4
--                 ON TO_DATE(pfrv.created_at) = dt4.actual_date
--       WHERE pfrv.approval_status_id IN (1,2)
--         AND dt4.year_month >= 201501
--       GROUP BY 1
--     UNION ALL
--       SELECT
--          dt5.year_month
--         ,SUM(NULL) AS ls_net_transactions_advisor
--         ,SUM(NULL) AS ls_net_transactions_doc_review
--         ,SUM(NULL) AS ls_net_transactions_offline
--         ,SUM(NULL) AS contacts_email
--         ,SUM(NULL) AS contacts_message
--         ,SUM(NULL) AS contacts_website
--         ,SUM(NULL) AS contacts_phone
--         ,SUM(NULL) AS client_reviews
--         ,SUM(ques.questions) AS      questions_asked
--         ,SUM(CASE WHEN ques.elapsed_48h <> 'Y' THEN NULL
--                   WHEN ques.answertime_mins <= 2880 THEN 1 
--                   ELSE 0 END) AS q_answered_within_48h
--       FROM
--         (
--         SELECT
--            que.id AS question_id
--           ,TO_DATE(que.created_at) AS q_created_date
--           ,CASE WHEN que.created_at <= date_sub(now(), interval 2880 minutes) THEN 'Y' ELSE 'N' END AS elapsed_48h
--           ,MAX(1) AS questions
--           ,MAX(CASE WHEN ans.id IS NOT NULL THEN 1 ELSE 0 END) AS q_answered
--           ,COUNT(ans.id) AS answers_total
--           ,round((min(unix_timestamp(ans.created_at)-unix_timestamp(que.created_at)))/60,0) AS answertime_mins
--         FROM
--                      src.content_question que
--           LEFT OUTER JOIN src.content_answer ans
--                   ON que.id = ans.question_id
--                  AND ans.approval_status_id IN (1,2)
--         WHERE que.approval_status_id IN (1,2)
--         GROUP BY 1,2,3
--         ) ques
--         INNER JOIN dm.date_dim dt5
--                 ON ques.q_created_date = dt5.actual_date
--       WHERE dt5.year_month >= 201501
--       GROUP BY 1
--     ) uns
--   GROUP BY 1
--   ) qry
--   INNER JOIN tmp_data_dm.coe_my_month_dim mth
--           ON qry.year_month = mth.year_month

I want to make daily, weekly, and monthly versions of this with mid_date
so I can layer them in tableau.
Maaaaybe populate a day table and then do inserts from it to it
separately for week and month.

Kevin thing: What would the North Star for data architecture be?

Not sure what I was thinking with this:
  ,reference_date STRING


-- DROP TABLE tmp_data_dm.coe_north_star_timeframes;
-- CREATE TABLE tmp_data_dm.coe_north_star_timeframes
-- (
--    period             STRING
--   ,period_num         INTEGER
--   ,period_type        STRING
--   ,period_start_date  STRING
--   ,period_end_date    STRING
--   ,report_chart_date  STRING
-- )
-- -- PARTITIONED BY (year_month INT)
-- STORED AS PARQUET ;

   aaaaaa AS period
  ,aaaaaa AS period_num
  ,aaaaaa AS period_type
  ,aaaaaa AS period_start_date
  ,aaaaaa AS period_end_date
  ,aaaaaa AS report_chart_date
  -- SELECT
  --    dt.actual_date AS period
  --   ,CAST(from_unixtime(unix_timestamp(CAST(dt.actual_date AS TIMESTAMP)), 'yyyyMMdd') AS INT) AS period_num
  --   ,'DAILY' AS        period_type
  --   ,dt.actual_date AS period_start_date
  --   ,dt.actual_date AS period_end_date
  --   ,dt.actual_date AS report_chart_date
  -- FROM dm.date_dim dt
  -- -- WHERE dt.actual_date BETWEEN '2016-01-01' AND '2016-11-30'
  -- UNION ALL

-- To keep things simple in queries, I would like period_num to be unique
-- in this table so I can pass just it through and join back later to
-- get start date, report date, etc.
-- INSERT INTO tmp_data_dm.coe_north_star_timeframes
DROP TABLE IF EXISTS tmp_data_dm.coe_north_star_timeframes ;
CREATE TABLE tmp_data_dm.coe_north_star_timeframes AS
SELECT * FROM
(
  SELECT
     CONCAT(wk.week_begin_date, ' to ', wk.week_end_date) AS period
    ,CAST(CONCAT(from_unixtime(unix_timestamp(CAST(wk.week_begin_date AS TIMESTAMP)), 'yyyyMMdd'), '00') AS INTEGER) AS period_num
    ,'Weekly' AS period_type
    ,wk.week_begin_date AS period_start_date
    ,wk.week_end_date AS period_end_date
    ,from_unixtime(unix_timestamp(CAST(wk.week_begin_date AS TIMESTAMP) + INTERVAL 3 DAYS), 'yyyy-MM-dd') AS report_chart_date
  FROM
    (
    SELECT DISTINCT
       rpt_wk_begin_date AS week_begin_date
      ,from_unixtime(unix_timestamp(CAST(rpt_wk_begin_date AS TIMESTAMP) + INTERVAL 6 DAYS), 'yyyy-MM-dd') AS week_end_date
    FROM dm.date_dim
    -- WHERE actual_date BETWEEN '2016-01-01' AND '2016-11-30'
    ) wk
  UNION ALL
  SELECT
     from_unixtime(unix_timestamp(CAST(mth.month_begin_date AS TIMESTAMP)), 'yyyy-MM') AS period
    ,year_month AS period_num
    ,'Monthly' AS period_type
    ,mth.month_begin_date AS period_start_date
    ,mth.month_end_date AS period_end_date
    ,from_unixtime(unix_timestamp(CAST(mth.month_begin_date AS TIMESTAMP) + INTERVAL CAST(mth.day_in_month_count/2 AS INT) DAYS), 'yyyy-MM-dd') AS report_chart_date
  FROM dm.month_dim mth
  -- WHERE mth.month_begin_date BETWEEN '2016-01-01' AND '2016-11-30'
) uns
WHERE period_start_date BETWEEN '2015-04-27' AND '2017-12-31'
  AND period_end_date   BETWEEN '2015-04-27' AND '2017-12-31'
;


-- DROP TABLE tmp_data_dm.coe_north_star_draft;
-- CREATE TABLE tmp_data_dm.coe_north_star_draft AS
-- SELECT
--    tf.period
--   ,tf.period_num
--   ,tf.period_type
--   ,tf.period_start_date
--   ,tf.period_end_date
--   ,tf.report_chart_date
--   ,IFNULL(qry.q_answered_within_48h_raw, 0) + 
--    IFNULL(qry.client_reviews_raw, 0) + 
--    IFNULL(qry.contacts_email_raw, 0) + IFNULL(qry.contacts_message_raw, 0) + 
--    (IFNULL(qry.contacts_website_raw, 0) / 10) + 
--    IFNULL(qry.contacts_phone_raw, 0) + 
--    IFNULL(qry.ls_net_transactions_advisor_raw, 0) + 
--    IFNULL(qry.ls_net_transactions_doc_review_raw, 0) + 
--    IFNULL(qry.ls_net_transactions_offline_raw, 0) AS     north_star_index
--   ,qry.q_answered_within_48h_raw AS                      q_and_a_within_48h
--   ,qry.client_reviews_raw AS                             client_reviews
--   ,qry.contacts_email_raw + qry.contacts_message_raw AS  emails_or_chat_conversations
--   ,qry.contacts_website_raw AS                           website_visits
--   ,qry.contacts_phone_raw AS                             phone_calls
--   ,qry.ls_net_transactions_advisor_raw AS                ls_net_transactions_advisor
--   ,qry.ls_net_transactions_doc_review_raw AS             ls_net_transactions_doc_review
--   ,qry.ls_net_transactions_offline_raw AS                ls_net_transactions_offline
-- FROM
--   (
--   SELECT
--      period_num
--     ,SUM(ls_net_transactions_advisor) AS     ls_net_transactions_advisor_raw
--     ,SUM(ls_net_transactions_doc_review) AS  ls_net_transactions_doc_review_raw
--     ,SUM(ls_net_transactions_offline) AS     ls_net_transactions_offline_raw
--     ,SUM(contacts_email) AS                  contacts_email_raw
--     ,SUM(contacts_message) AS                contacts_message_raw
--     ,SUM(contacts_website) AS                contacts_website_raw
--     ,SUM(contacts_phone) AS                  contacts_phone_raw
--     ,SUM(client_reviews) AS                  client_reviews_raw
--     ,SUM(questions_asked) AS                 questions_asked_raw
--     ,SUM(q_answered_within_48h) AS           q_answered_within_48h_raw
--   FROM
--     (
--       SELECT
--          cat.period_num
--         ,SUM(CASE WHEN cat.package_category = 'Advisor'
--                     THEN cat.ls_transactions - cat.ls_refunds
--                     ELSE 0 END) AS ls_net_transactions_advisor
--         ,SUM(CASE WHEN cat.package_category = 'Doc Review'
--                     THEN cat.ls_transactions - cat.ls_refunds
--                     ELSE 0 END) AS ls_net_transactions_doc_review
--         ,SUM(CASE WHEN cat.package_category = 'Offline Service'
--                     THEN cat.ls_transactions - cat.ls_refunds
--                     ELSE 0 END) AS ls_net_transactions_offline
--         ,SUM(NULL) AS contacts_email
--         ,SUM(NULL) AS contacts_message
--         ,SUM(NULL) AS contacts_website
--         ,SUM(NULL) AS contacts_phone
--         ,SUM(NULL) AS client_reviews
--         ,SUM(NULL) AS questions_asked
--         ,SUM(NULL) AS q_answered_within_48h
--       FROM
--         (
--         SELECT
--            tf1.period_num
--           ,evt.package_category
--           ,SUM(CASE WHEN evt.event_category = 'cc_charge' THEN 1 ELSE 0 END) AS ls_transactions
--           ,SUM(CASE WHEN evt.event_category = 'refund'    THEN 1 ELSE 0 END) AS ls_refunds
--         FROM         tmp_data_dm.coe_services_event_detail evt
--           INNER JOIN tmp_data_dm.coe_north_star_timeframes tf1
--                   ON evt.event_date BETWEEN tf1.period_start_date AND tf1.period_end_date
--           -- INNER JOIN dm.date_dim dt1
--           --         ON evt.event_date = dt1.actual_date
--         -- WHERE dt1.year_month >= 201601
--         GROUP BY 1,2
--         ) cat
--       GROUP BY 1
--     UNION ALL
--       SELECT
--          tf2.period_num
--         ,SUM(NULL) AS ls_net_transactions_advisor
--         ,SUM(NULL) AS ls_net_transactions_doc_review
--         ,SUM(NULL) AS ls_net_transactions_offline
--         ,SUM(CASE WHEN ctc.contact_type = 'email'   THEN ctc.num_contacts ELSE 0 END) AS contacts_email
--         ,SUM(CASE WHEN ctc.contact_type = 'message' THEN ctc.num_contacts ELSE 0 END) AS contacts_message
--         ,SUM(CASE WHEN ctc.contact_type = 'website' THEN ctc.num_contacts ELSE 0 END) AS contacts_website
--         ,SUM(NULL) AS contacts_phone
--         ,SUM(NULL) AS client_reviews
--         ,SUM(NULL) AS questions_asked
--         ,SUM(NULL) AS q_answered_within_48h
--       FROM         tmp_data_dm.coe_temp_contacts_ds ctc
--         INNER JOIN tmp_data_dm.coe_north_star_timeframes tf2
--                 ON ctc.event_date BETWEEN tf2.period_start_date AND tf2.period_end_date
--       --   INNER JOIN dm.date_dim dt2
--       --           ON ctc.event_date = dt2.actual_date
--       -- WHERE dt2.year_month >= 201501
--       GROUP BY 1
--     UNION ALL
--       SELECT
--          tf3.period_num
--         ,SUM(NULL) AS ls_net_transactions_advisor
--         ,SUM(NULL) AS ls_net_transactions_doc_review
--         ,SUM(NULL) AS ls_net_transactions_offline
--         ,SUM(NULL) AS contacts_email
--         ,SUM(NULL) AS contacts_message
--         ,SUM(NULL) AS contacts_website
--         ,SUM(CASE WHEN cim.contact_type = 'phone' AND cim.duration >= 120 THEN 1 ELSE 0 END) AS contacts_phone
--         ,SUM(NULL) AS client_reviews
--         ,SUM(NULL) AS questions_asked
--         ,SUM(NULL) AS q_answered_within_48h
--       FROM         src.contact_impression cim
--         INNER JOIN tmp_data_dm.coe_north_star_timeframes tf3
--                 ON cim.event_date BETWEEN tf3.period_start_date AND tf3.period_end_date
--       --   INNER JOIN dm.date_dim dt3
--       --           ON cim.event_date = dt3.actual_date
--       -- WHERE dt3.year_month >= 201501
--       GROUP BY 1
--     UNION ALL
--       SELECT
--          tf4.period_num
--         ,SUM(NULL) AS ls_net_transactions_advisor
--         ,SUM(NULL) AS ls_net_transactions_doc_review
--         ,SUM(NULL) AS ls_net_transactions_offline
--         ,SUM(NULL) AS contacts_email
--         ,SUM(NULL) AS contacts_message
--         ,SUM(NULL) AS contacts_website
--         ,SUM(NULL) AS contacts_phone
--         ,COUNT(*) AS  client_reviews
--         ,SUM(NULL) AS questions_asked
--         ,SUM(NULL) AS q_answered_within_48h
--       FROM         src.barrister_professional_review pfrv
--         INNER JOIN dm.professional_dimension pf
--                 ON pf.professional_id = pfrv.professional_id
--                AND pf.professional_delete_indicator = 'Not Deleted'
--                AND pf.professional_name = 'lawyer'
--                AND pf.industry_name = 'Legal'
--         INNER JOIN tmp_data_dm.coe_north_star_timeframes tf4
--                 ON TO_DATE(pfrv.created_at) BETWEEN tf4.period_start_date AND tf4.period_end_date
--         -- INNER JOIN dm.date_dim dt4
--         --         ON TO_DATE(pfrv.created_at) = dt4.actual_date
--       WHERE pfrv.approval_status_id IN (1, 2)
--         -- AND dt4.year_month >= 201501
--       GROUP BY 1
--     UNION ALL
--       SELECT
--          tf5.period_num
--         ,SUM(NULL) AS ls_net_transactions_advisor
--         ,SUM(NULL) AS ls_net_transactions_doc_review
--         ,SUM(NULL) AS ls_net_transactions_offline
--         ,SUM(NULL) AS contacts_email
--         ,SUM(NULL) AS contacts_message
--         ,SUM(NULL) AS contacts_website
--         ,SUM(NULL) AS contacts_phone
--         ,SUM(NULL) AS client_reviews
--         ,SUM(ques.questions) AS      questions_asked
--         ,SUM(CASE WHEN ques.elapsed_48h <> 'Y' THEN NULL
--                   WHEN ques.answertime_mins <= 2880 THEN 1 
--                   ELSE 0 END) AS q_answered_within_48h
--       FROM
--         (
--         SELECT
--            que.id AS question_id
--           ,TO_DATE(que.created_at) AS q_created_date
--           ,CASE WHEN que.created_at <= date_sub(now(), interval 2880 minutes) THEN 'Y' ELSE 'N' END AS elapsed_48h
--           ,MAX(1) AS questions
--           ,MAX(CASE WHEN ans.id IS NOT NULL THEN 1 ELSE 0 END) AS q_answered
--           ,COUNT(ans.id) AS answers_total
--           ,round((min(unix_timestamp(ans.created_at)-unix_timestamp(que.created_at)))/60,0) AS answertime_mins
--         FROM
--                      src.content_question que
--           LEFT OUTER JOIN src.content_answer ans
--                   ON que.id = ans.question_id
--                  AND ans.approval_status_id IN (1,2)
--         WHERE que.approval_status_id IN (1,2)
--         GROUP BY 1,2,3
--         ) ques
--         INNER JOIN tmp_data_dm.coe_north_star_timeframes tf5
--                 ON ques.q_created_date BETWEEN tf5.period_start_date AND tf5.period_end_date
--       --   INNER JOIN dm.date_dim dt5
--       --           ON ques.q_created_date = dt5.actual_date
--       -- WHERE dt5.year_month >= 201501
--       GROUP BY 1
--     ) uns
--   GROUP BY 1
--   ) qry
--   INNER JOIN tmp_data_dm.coe_north_star_timeframes tf
--           ON qry.period_num = tf.period_num

-- Ask Monica:
-- If we are defining successful transactions as cc purchases, then
-- cc failure does not get included even though consumer''s problem
-- probably got solved.
-- OK, that is fine.
-- She asks what about transactions that are free to the consumer, such as employee benefits?
-- They get included: "capture succeeded for empty_token... something like that" (from katherine)
-- We covered this.  They are small, and excluding is a lot of work and raises questions
-- about other $0 transactions, so we are not going to try to exclude them.

OK not a ton of value to flexible timeframes the way I did the grid,
because these are not ratios so vertical axes are different for the
different timeframes.
That might mean that I need to change how I present it.
Daily is worthless.  gone now.
----

Ask Sayle whether we want trendable ratios too.
For example, if we are growing quickly, the % of questions that get
answered within 48h may plummet but raw number of questions answered
within 48h still goes up.
Nope, keep it simple for now.

Would like to provide week and month options.
Can pre-populate coe_north_star_timeframes way into the future
and then use a filter in the final queries to only get trailing 13mo.
(approx 56 weeks)
Contacts data source by definition is day.
So maybe I do the other one by day too and join to timeframes
in Tableau.

Q&A – question asked and answered within 48 hours: Q&A question level but does not quite give rolling 13mo.
Client reviews: ???
Website visits: Contacts
Chat conversations or emails: Contacts
Phone calls – 2 or more minutes in duration: Similar to Contacts but does not have duration.
Services - Advisor session with no refund: 
Services - Document review with no refund: 
Services - Full service with no refund: 

Have to blank out incomplete weeks or months if I don''t already do that.
In the report, just have a filter that says period end <= yesterday?
Would be nice for period start too but not crucial.

OK for index dataset, yes I want an attribute, but can I have both an
aggregate metric and the individual metrics?  Have to think about that.

-- DROP TABLE IF EXISTS tmp_data_dm.coe_north_star_draft;
-- CREATE TABLE tmp_data_dm.coe_north_star_draft AS
-- WITH tf AS
-- (
-- SELECT
--    tf.period
--   ,tf.period_num
--   ,tf.period_type
--   ,tf.period_start_date
--   ,tf.period_end_date
--   ,tf.report_chart_date
-- FROM tmp_data_dm.coe_north_star_timeframes tf
--   CROSS JOIN
--     (
--     SELECT
--        actual_date AS today
--       ,from_unixtime(unix_timestamp( cast(actual_date as timestamp) - interval 12 months), 'yyyy-MM-dd') AS todays_date_last_year
--       ,from_unixtime(unix_timestamp((cast(actual_date as timestamp) - interval 12 months) - interval 2 weeks), 'yyyy-MM-dd') AS todays_date_last_year_minus_2_weeks
--       ,from_unixtime(unix_timestamp( cast(actual_date as timestamp) - interval 14 months), 'yyyy-MM-dd') AS todays_date_last_year_minus_2_months
--     FROM dm.date_dim
--     WHERE from_unixtime(unix_timestamp(NOW()), 'yyyy-MM-dd') = actual_date
--     ) td
-- WHERE
--      (    tf.period_type = 'Weekly'
--       AND td.todays_date_last_year_minus_2_weeks <= tf.period_start_date
--       AND tf.period_end_date < td.today
--      )
--   OR
--      (    tf.period_type = 'Monthly'
--       AND td.todays_date_last_year_minus_2_months <= tf.period_start_date
--       AND tf.period_end_date < td.today
--      )
-- )

-- SELECT
--    tf0.period
--   ,tf0.period_num
--   ,tf0.period_type
--   ,tf0.period_start_date
--   ,tf0.period_end_date
--   ,tf0.report_chart_date
--   ,xxxx.metric_type
--   -- ,SUM(CASE WHEN xxxx.metric_type IN ())

--   ,IFNULL(qry.q_answered_within_48h_raw, 0) + 
--    IFNULL(qry.client_reviews_raw, 0) + 
--    IFNULL(qry.contacts_email_raw, 0) + IFNULL(qry.contacts_message_raw, 0) + 
--    (IFNULL(qry.contacts_website_raw, 0) / 10) + 
--    IFNULL(qry.contacts_phone_raw, 0) + 
--    IFNULL(qry.ls_net_transactions_advisor_raw, 0) + 
--    IFNULL(qry.ls_net_transactions_doc_review_raw, 0) + 
--    IFNULL(qry.ls_net_transactions_offline_raw, 0) AS     north_star_index
--   ,qry.q_answered_within_48h_raw AS                      q_and_a_within_48h
--   ,qry.client_reviews_raw AS                             client_reviews
--   ,qry.contacts_email_raw + qry.contacts_message_raw AS  emails_or_chat_conversations
--   ,qry.contacts_website_raw AS                           website_visits
--   ,qry.contacts_phone_raw AS                             phone_calls
--   ,qry.ls_net_transactions_advisor_raw AS                ls_net_transactions_advisor
--   ,qry.ls_net_transactions_doc_review_raw AS             ls_net_transactions_doc_review
--   ,qry.ls_net_transactions_offline_raw AS                ls_net_transactions_offline
-- FROM
--   (
--   SELECT
--      period_num
--     ,SUM(ls_net_transactions_advisor) AS     ls_net_transactions_advisor_raw
--     ,SUM(ls_net_transactions_doc_review) AS  ls_net_transactions_doc_review_raw
--     ,SUM(ls_net_transactions_offline) AS     ls_net_transactions_offline_raw
--     ,SUM(contacts_email) AS                  contacts_email_raw
--     ,SUM(contacts_message) AS                contacts_message_raw
--     ,SUM(contacts_website) AS                contacts_website_raw
--     ,SUM(contacts_phone) AS                  contacts_phone_raw
--     ,SUM(client_reviews) AS                  client_reviews_raw
--     ,SUM(questions_asked) AS                 questions_asked_raw
--     ,SUM(q_answered_within_48h) AS           q_answered_within_48h_raw
--   FROM
--     (
--       SELECT
--          cat.period_num
--         ,SUM(CASE WHEN cat.package_category = 'Advisor'
--                     THEN cat.ls_transactions - cat.ls_refunds
--                     ELSE 0 END) AS ls_net_transactions_advisor
--         ,SUM(CASE WHEN cat.package_category = 'Doc Review'
--                     THEN cat.ls_transactions - cat.ls_refunds
--                     ELSE 0 END) AS ls_net_transactions_doc_review
--         ,SUM(CASE WHEN cat.package_category = 'Offline Service'
--                     THEN cat.ls_transactions - cat.ls_refunds
--                     ELSE 0 END) AS ls_net_transactions_offline
--         ,SUM(NULL) AS contacts_email
--         ,SUM(NULL) AS contacts_message
--         ,SUM(NULL) AS contacts_website
--         ,SUM(NULL) AS contacts_phone
--         ,SUM(NULL) AS client_reviews
--         ,SUM(NULL) AS questions_asked
--         ,SUM(NULL) AS q_answered_within_48h
--       FROM
--         (
--         SELECT
--            tf1.period_num
--           ,evt.package_category
--           ,SUM(CASE WHEN evt.event_category = 'cc_charge' THEN 1 ELSE 0 END) AS ls_transactions
--           ,SUM(CASE WHEN evt.event_category = 'refund'    THEN 1 ELSE 0 END) AS ls_refunds
--         FROM         tmp_data_dm.coe_services_event_detail evt
--           INNER JOIN tf tf1
--                   ON evt.event_date BETWEEN tf1.period_start_date AND tf1.period_end_date
--           -- INNER JOIN dm.date_dim dt1
--           --         ON evt.event_date = dt1.actual_date
--         -- WHERE dt1.year_month >= 201601
--         GROUP BY 1,2
--         ) cat
--       GROUP BY 1
--     UNION ALL
--       SELECT
--          tf2.period_num
--         ,SUM(NULL) AS ls_net_transactions_advisor
--         ,SUM(NULL) AS ls_net_transactions_doc_review
--         ,SUM(NULL) AS ls_net_transactions_offline
--         ,SUM(CASE WHEN ctc.contact_type = 'email'   THEN ctc.num_contacts ELSE 0 END) AS contacts_email
--         ,SUM(CASE WHEN ctc.contact_type = 'message' THEN ctc.num_contacts ELSE 0 END) AS contacts_message
--         ,SUM(CASE WHEN ctc.contact_type = 'website' THEN ctc.num_contacts ELSE 0 END) AS contacts_website
--         ,SUM(NULL) AS contacts_phone
--         ,SUM(NULL) AS client_reviews
--         ,SUM(NULL) AS questions_asked
--         ,SUM(NULL) AS q_answered_within_48h
--       FROM         tmp_data_dm.coe_temp_contacts_ds ctc
--         INNER JOIN tf tf2
--                 ON ctc.event_date BETWEEN tf2.period_start_date AND tf2.period_end_date
--       --   INNER JOIN dm.date_dim dt2
--       --           ON ctc.event_date = dt2.actual_date
--       -- WHERE dt2.year_month >= 201501
--       GROUP BY 1
--     UNION ALL
--       SELECT
--          tf3.period_num
--         ,SUM(NULL) AS ls_net_transactions_advisor
--         ,SUM(NULL) AS ls_net_transactions_doc_review
--         ,SUM(NULL) AS ls_net_transactions_offline
--         ,SUM(NULL) AS contacts_email
--         ,SUM(NULL) AS contacts_message
--         ,SUM(NULL) AS contacts_website
--         ,SUM(CASE WHEN cim.contact_type = 'phone' AND cim.duration >= 120 THEN 1 ELSE 0 END) AS contacts_phone
--         ,SUM(NULL) AS client_reviews
--         ,SUM(NULL) AS questions_asked
--         ,SUM(NULL) AS q_answered_within_48h
--       FROM         src.contact_impression cim
--         INNER JOIN tf tf3
--                 ON cim.event_date BETWEEN tf3.period_start_date AND tf3.period_end_date
--       --   INNER JOIN dm.date_dim dt3
--       --           ON cim.event_date = dt3.actual_date
--       -- WHERE dt3.year_month >= 201501
--       GROUP BY 1
--     UNION ALL
      -- SELECT
      --    tf4.period_num
      --   ,SUM(NULL) AS ls_net_transactions_advisor
      --   ,SUM(NULL) AS ls_net_transactions_doc_review
      --   ,SUM(NULL) AS ls_net_transactions_offline
      --   ,SUM(NULL) AS contacts_email
      --   ,SUM(NULL) AS contacts_message
      --   ,SUM(NULL) AS contacts_website
      --   ,SUM(NULL) AS contacts_phone
      --   ,COUNT(*) AS  client_reviews
      --   ,SUM(NULL) AS questions_asked
      --   ,SUM(NULL) AS q_answered_within_48h
      -- FROM         src.barrister_professional_review pfrv
      --   INNER JOIN dm.professional_dimension pf
      --           ON pf.professional_id = pfrv.professional_id
      --          AND pf.professional_delete_indicator = 'Not Deleted'
      --          AND pf.professional_name = 'lawyer'
      --          AND pf.industry_name = 'Legal'
      --   INNER JOIN tf tf4
      --           ON TO_DATE(pfrv.created_at) BETWEEN tf4.period_start_date AND tf4.period_end_date
      --   -- INNER JOIN dm.date_dim dt4
      --   --         ON TO_DATE(pfrv.created_at) = dt4.actual_date
      -- WHERE pfrv.approval_status_id IN (1, 2)
      --   -- AND dt4.year_month >= 201501
      -- GROUP BY 1
--     UNION ALL
      -- SELECT
      --    tf5.period_num
      --   ,SUM(NULL) AS ls_net_transactions_advisor
      --   ,SUM(NULL) AS ls_net_transactions_doc_review
      --   ,SUM(NULL) AS ls_net_transactions_offline
      --   ,SUM(NULL) AS contacts_email
      --   ,SUM(NULL) AS contacts_message
      --   ,SUM(NULL) AS contacts_website
      --   ,SUM(NULL) AS contacts_phone
      --   ,SUM(NULL) AS client_reviews
      --   ,SUM(ques.questions) AS      questions_asked
      --   ,SUM(CASE WHEN ques.elapsed_48h <> 'Y' THEN NULL
      --             WHEN ques.answertime_mins <= 2880 THEN 1 
      --             ELSE 0 END) AS q_answered_within_48h
      -- FROM
      --   (
      --   SELECT
      --      que.id AS question_id
      --     ,TO_DATE(que.created_at) AS q_created_date
      --     ,CASE WHEN que.created_at <= date_sub(now(), interval 2880 minutes) THEN 'Y' ELSE 'N' END AS elapsed_48h
      --     ,MAX(1) AS questions
      --     ,MAX(CASE WHEN ans.id IS NOT NULL THEN 1 ELSE 0 END) AS q_answered
      --     ,COUNT(ans.id) AS answers_total
      --     ,round((min(unix_timestamp(ans.created_at)-unix_timestamp(que.created_at)))/60,0) AS answertime_mins
      --   FROM
      --                src.content_question que
      --     LEFT OUTER JOIN src.content_answer ans
      --             ON que.id = ans.question_id
      --            AND ans.approval_status_id IN (1,2)
      --   WHERE que.approval_status_id IN (1,2)
      --   GROUP BY 1,2,3
      --   ) ques
      --   INNER JOIN tf tf5
      --           ON ques.q_created_date BETWEEN tf5.period_start_date AND tf5.period_end_date
      -- --   INNER JOIN dm.date_dim dt5
      -- --           ON ques.q_created_date = dt5.actual_date
      -- -- WHERE dt5.year_month >= 201501
      -- GROUP BY 1
--     ) uns
--   GROUP BY 1
--   ) qry
--   INNER JOIN tf tf0
--           ON qry.period_num = tf0.period_num

Date logic for weeks:
Start of range is the week BEFORE the week that contains today''s date last year.
End of range is the most recent complete week.
-- BUT I may end up later deciding that I want the week range to extend back
-- as far as whatever complete week gets us the month range.  (looking a few more weeks back)
Logic says yes if:
        period_type = 'Weekly'
    AND todays''s date last year minus 2 weeks <= rpt_wk_begin_date
    AND rpt_wk_end_date < today
OR
        period_type = 'Monthly'
    AND todays''s date last year minus 2 months <= month_begin_date
    AND month_end_date < today

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
----
  -- ,IFNULL(qry.q_answered_within_48h_raw, 0) + 
  --  IFNULL(qry.client_reviews_raw, 0) + 
  --  IFNULL(qry.contacts_email_raw, 0) + IFNULL(qry.contacts_message_raw, 0) + 
  --  (IFNULL(qry.contacts_website_raw, 0) / 10) + 
  --  IFNULL(qry.contacts_phone_raw, 0) + 
  --  IFNULL(qry.ls_net_transactions_advisor_raw, 0) + 
  --  IFNULL(qry.ls_net_transactions_doc_review_raw, 0) + 
  --  IFNULL(qry.ls_net_transactions_offline_raw, 0) AS     north_star_index
  -- ,qry.q_answered_within_48h_raw AS                      q_and_a_within_48h
  -- ,qry.client_reviews_raw AS                             client_reviews
  -- ,qry.contacts_email_raw + qry.contacts_message_raw AS  emails_or_chat_conversations
  -- ,qry.contacts_website_raw AS                           website_visits
  -- ,qry.contacts_phone_raw AS                             phone_calls
  -- ,qry.ls_net_transactions_advisor_raw AS                ls_net_transactions_advisor
  -- ,qry.ls_net_transactions_doc_review_raw AS             ls_net_transactions_doc_review
  -- ,qry.ls_net_transactions_offline_raw AS                ls_net_transactions_offline

----

--  Replicate contacts numbers.

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
  --    (    tf.period_type = 'Weekly'
  --     AND td.todays_date_last_year_minus_2_weeks <= tf.period_start_date
  --     AND tf.period_end_date < td.today
  --    )
  -- OR
     (    tf.period_type = 'Monthly'
      AND td.todays_date_last_year_minus_2_months <= tf.period_start_date
      AND tf.period_end_date < td.today
     )
)

-- SELECT 
--    tf2.period_num
--   ,ci.contact_type
--   ,COUNT(*) AS num_contacts
-- FROM 
-- (
-- SELECT contact_type, event_date, professional_id, user_id, session_id
-- FROM src.contact_impression
-- WHERE event_date >= '2015-05-01'
--   AND IFNULL(contact_type, 'ZZZZ') <> 'message'
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
--     INNER JOIN timeframes tf2
--             ON from_unixtime(unix_timestamp(CAST(ci.event_date AS TIMESTAMP)), 'yyyy-MM-dd') BETWEEN tf2.period_start_date AND tf2.period_end_date
-- GROUP BY 1,2

----
-- WITH timeframes AS
-- (
-- SELECT
--    tf.period
--   ,tf.period_num
--   ,tf.period_type
--   ,tf.period_start_date
--   ,tf.period_end_date
--   ,tf.report_chart_date
-- FROM tmp_data_dm.coe_north_star_timeframes tf
--   CROSS JOIN
--     (
--     SELECT
--        actual_date AS today
--       ,from_unixtime(unix_timestamp( cast(actual_date as timestamp) - interval 12 months), 'yyyy-MM-dd') AS todays_date_last_year
--       ,from_unixtime(unix_timestamp((cast(actual_date as timestamp) - interval 12 months) - interval 2 weeks), 'yyyy-MM-dd') AS todays_date_last_year_minus_2_weeks
--       ,from_unixtime(unix_timestamp( cast(actual_date as timestamp) - interval 14 months), 'yyyy-MM-dd') AS todays_date_last_year_minus_2_months
--     FROM dm.date_dim
--     WHERE from_unixtime(unix_timestamp(NOW()), 'yyyy-MM-dd') = actual_date
--     ) td
-- WHERE
--   --    (    tf.period_type = 'Weekly'
--   --     AND td.todays_date_last_year_minus_2_weeks <= tf.period_start_date
--   --     AND tf.period_end_date < td.today
--   --    )
--   -- OR
--      (    tf.period_type = 'Monthly'
--       AND td.todays_date_last_year_minus_2_months <= tf.period_start_date
--       AND tf.period_end_date < td.today
--      )
-- )

-- ,services_events AS
-- (
--   SELECT
--      tf1.period_num
--     ,ofr.package_category
--     ,SUM(CASE WHEN evt.event_type = 'capture_succeeded' THEN 1 ELSE 0 END) -
--      SUM(CASE WHEN evt.event_type = 'refund'            THEN 1 ELSE 0 END) AS net_transactions
--   FROM  src.ocato_financial_event_logs evt
--     INNER JOIN timeframes tf1
--             ON from_unixtime(unix_timestamp(CAST(evt.created_at_pst AS TIMESTAMP)), 'yyyy-MM-dd') BETWEEN tf1.period_start_date AND tf1.period_end_date
--     LEFT OUTER JOIN 
--       (
--       SELECT
--          oo.id
--         ,CASE WHEN pkg.package_category_id = 1 THEN 'Advisor'
--               WHEN pkg.package_category_id = 2 THEN 'Doc Review'
--               WHEN pkg.package_category_id = 3 THEN 'Full Service'
--               ELSE 'Unknown'
--          END AS package_category
--       FROM         src.ocato_offers oo
--         LEFT OUTER JOIN (SELECT id, package_category_id FROM src.ocato_packages) pkg
--                 ON oo.package_id = pkg.id
--       ) ofr
--         ON evt.offer_id = ofr.id
--   GROUP BY 1,2
-- )

-- ,contacts AS
-- (
-- SELECT 
--    tf2.period_num
--   ,ci.contact_type
--   ,COUNT(*) AS num_contacts
-- FROM 
-- (
-- SELECT contact_type, event_date, professional_id, user_id, session_id
-- FROM src.contact_impression
-- WHERE event_date >= '2015-05-01'
--   AND IFNULL(contact_type, 'ZZZZ') NOT IN ('message', 'phone')
-- UNION ALL
-- SELECT contact_type, event_date, professional_id, user_id, session_id
-- FROM src.contact_impression
-- WHERE event_date >= '2015-05-01'
--   AND contact_type = 'phone'
--   AND duration >= 120
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
--     INNER JOIN timeframes tf2
--             ON from_unixtime(unix_timestamp(CAST(ci.event_date AS TIMESTAMP)), 'yyyy-MM-dd') BETWEEN tf2.period_start_date AND tf2.period_end_date
-- GROUP BY 1,2
-- )

-- SELECT
--    tf0.period
--   ,tf0.period_num
--   ,tf0.period_type
--   ,tf0.period_start_date
--   ,tf0.period_end_date
--   ,tf0.report_chart_date
--   ,qry.metric_type
--   ,SUM(qry.metric_value) AS metric_value
-- FROM
-- (
--     SELECT
--        evt1.period_num
--       ,'Services Net Transactions Advisor' AS metric_type
--       ,evt1.net_transactions AS metric_value
--     FROM services_events evt1
--     WHERE evt1.package_category = 'Advisor'
--   UNION ALL
--     SELECT
--        evt2.period_num
--       ,'Services Net Transactions Doc Review' AS metric_type
--       ,evt2.net_transactions AS metric_value
--     FROM services_events evt2
--     WHERE evt2.package_category = 'Doc Review'
--   UNION ALL
--     SELECT
--        evt3.period_num
--       ,'Services Net Transactions Full Service' AS metric_type
--       ,evt3.net_transactions AS metric_value
--     FROM services_events evt3
--     WHERE evt3.package_category = 'Full Service'
--   UNION ALL
--     SELECT
--        con1.period_num
--       ,'Chat Conversations and Emails' AS metric_type
--       ,SUM(con1.num_contacts) AS metric_value
--     FROM contacts con1
--     WHERE contact_type IN ('message', 'email')
--     GROUP BY 1,2
--   UNION ALL
--     SELECT
--        con1.period_num
--       ,'Phone Calls' AS metric_type
--       ,SUM(con1.num_contacts) AS metric_value
--     FROM contacts con1
--     WHERE contact_type IN ('phone')
--     GROUP BY 1,2
--   UNION ALL
--     SELECT
--        con1.period_num
--       ,'Website Visits (Scaled)' AS metric_type
--       ,CAST(SUM(con1.num_contacts) / 10 AS INTEGER) AS metric_value
--     FROM contacts con1
--     WHERE contact_type IN ('website')
--     GROUP BY 1,2
--   UNION ALL
--     SELECT
--        tf4.period_num
--       ,'Client Reviews' AS metric_type
--       ,COUNT(*) AS  metric_value
--     FROM         src.barrister_professional_review pfrv
--       INNER JOIN dm.professional_dimension pf
--               ON pf.professional_id = pfrv.professional_id
--              AND pf.professional_delete_indicator = 'Not Deleted'
--              AND pf.professional_name = 'lawyer'
--              AND pf.industry_name = 'Legal'
--       INNER JOIN timeframes tf4
--               ON TO_DATE(pfrv.created_at) BETWEEN tf4.period_start_date AND tf4.period_end_date
--     WHERE pfrv.approval_status_id IN (1, 2)
--     GROUP BY 1
--   UNION ALL
--     SELECT
--        tf5.period_num
--       ,'Q and A Within 48H' AS metric_type
--       ,SUM(CASE WHEN ques.elapsed_48h <> 'Y' THEN NULL
--                 WHEN ques.answertime_mins <= 2880 THEN 1 
--                 ELSE 0 END) AS metric_value
--     FROM
--       (
--       SELECT
--          que.id AS question_id
--         ,TO_DATE(que.created_at) AS q_created_date
--         ,CASE WHEN que.created_at <= date_sub(now(), interval 2880 minutes) THEN 'Y' ELSE 'N' END AS elapsed_48h
--         ,MAX(1) AS questions
--         ,MAX(CASE WHEN ans.id IS NOT NULL THEN 1 ELSE 0 END) AS q_answered
--         ,COUNT(ans.id) AS answers_total
--         ,round((min(unix_timestamp(ans.created_at)-unix_timestamp(que.created_at)))/60,0) AS answertime_mins
--       FROM
--                    src.content_question que
--         LEFT OUTER JOIN src.content_answer ans
--                 ON que.id = ans.question_id
--                AND ans.approval_status_id IN (1,2)
--       WHERE que.approval_status_id IN (1,2)
--       GROUP BY 1,2,3
--       ) ques
--       INNER JOIN timeframes tf5
--               ON ques.q_created_date BETWEEN tf5.period_start_date AND tf5.period_end_date
--     GROUP BY 1
-- ) qry
--   INNER JOIN timeframes tf0
--           ON qry.period_num = tf0.period_num
-- GROUP BY 1,2,3,4,5,6,7

OK happy with the data quality.

----

-- DROP TABLE IF EXISTS tmp_data_dm.coe_north_star_index;
-- CREATE TABLE tmp_data_dm.coe_north_star_index AS
-- WITH timeframes AS
-- (
-- SELECT
--    tf.period
--   ,tf.period_num
--   ,tf.period_type
--   ,tf.period_start_date
--   ,tf.period_end_date
--   ,tf.report_chart_date
-- FROM tmp_data_dm.coe_north_star_timeframes tf
--   CROSS JOIN
--     (
--     SELECT
--        actual_date AS today
--       ,from_unixtime(unix_timestamp( cast(actual_date as timestamp) - interval 12 months), 'yyyy-MM-dd') AS todays_date_last_year
--       ,from_unixtime(unix_timestamp((cast(actual_date as timestamp) - interval 12 months) - interval 2 weeks), 'yyyy-MM-dd') AS todays_date_last_year_minus_2_weeks
--       ,from_unixtime(unix_timestamp( cast(actual_date as timestamp) - interval 14 months), 'yyyy-MM-dd') AS todays_date_last_year_minus_2_months
--     FROM dm.date_dim
--     WHERE from_unixtime(unix_timestamp(NOW()), 'yyyy-MM-dd') = actual_date
--     ) td
-- WHERE
--      (    tf.period_type = 'Weekly'
--       AND td.todays_date_last_year_minus_2_weeks <= tf.period_start_date
--       AND tf.period_end_date < td.today
--      )
--   OR
--      (    tf.period_type = 'Monthly'
--       AND td.todays_date_last_year_minus_2_months <= tf.period_start_date
--       AND tf.period_end_date < td.today
--      )
-- )

-- ,services_events AS
-- (
--   SELECT
--      tf1.period_num
--     ,ofr.package_category
--     ,SUM(CASE WHEN evt.event_type = 'capture_succeeded' THEN 1 ELSE 0 END) -
--      SUM(CASE WHEN evt.event_type = 'refund'            THEN 1 ELSE 0 END) AS net_transactions
--   FROM  src.ocato_financial_event_logs evt
--     INNER JOIN timeframes tf1
--             ON from_unixtime(unix_timestamp(CAST(evt.created_at_pst AS TIMESTAMP)), 'yyyy-MM-dd') BETWEEN tf1.period_start_date AND tf1.period_end_date
--     LEFT OUTER JOIN 
--       (
--       SELECT
--          oo.id
--         ,CASE WHEN pkg.package_category_id = 1 THEN 'Advisor'
--               WHEN pkg.package_category_id = 2 THEN 'Doc Review'
--               WHEN pkg.package_category_id = 3 THEN 'Full Service'
--               ELSE 'Unknown'
--          END AS package_category
--       FROM         src.ocato_offers oo
--         LEFT OUTER JOIN (SELECT id, package_category_id FROM src.ocato_packages) pkg
--                 ON oo.package_id = pkg.id
--       ) ofr
--         ON evt.offer_id = ofr.id
--   GROUP BY 1,2
-- )

-- ,contacts AS
-- (
-- SELECT 
--    tf2.period_num
--   ,ci.contact_type
--   ,COUNT(*) AS num_contacts
-- FROM 
-- (
-- SELECT contact_type, event_date, professional_id, user_id, session_id
-- FROM src.contact_impression
-- WHERE event_date >= '2015-05-01'
--   AND IFNULL(contact_type, 'ZZZZ') NOT IN ('message', 'phone')
-- UNION ALL
-- SELECT contact_type, event_date, professional_id, user_id, session_id
-- FROM src.contact_impression
-- WHERE event_date >= '2015-05-01'
--   AND contact_type = 'phone'
--   AND duration >= 120
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
--     INNER JOIN timeframes tf2
--             ON from_unixtime(unix_timestamp(CAST(ci.event_date AS TIMESTAMP)), 'yyyy-MM-dd') BETWEEN tf2.period_start_date AND tf2.period_end_date
-- GROUP BY 1,2
-- )

-- SELECT
--    tf0.period
--   ,tf0.period_num
--   ,tf0.period_type
--   ,tf0.period_start_date
--   ,tf0.period_end_date
--   ,tf0.report_chart_date
--   ,qry.metric_type
--   ,qry.metric_value
--   ,qry.north_star_index_for_pct
--   ,qry.services_advisor_sessions
--   ,qry.services_doc_review
--   ,qry.services_full_service
--   ,qry.chat_conversations_and_emails
--   ,qry.phone_calls_at_least_2_mins
--   ,qry.website_visits_scaled
--   ,qry.client_reviews
--   ,qry.q_and_a_within_48hours
-- FROM
-- (
-- SELECT
--    met.period_num
--   ,met.metric_type
--   ,met.metric_value
--   ,SUM(met.metric_value) OVER(PARTITION BY met.period_num) AS north_star_index_for_pct
--   ,met.services_advisor_sessions
--   ,met.services_doc_review
--   ,met.services_full_service
--   ,met.chat_conversations_and_emails
--   ,met.phone_calls_at_least_2_mins
--   ,met.website_visits_scaled
--   ,met.client_reviews
--   ,met.q_and_a_within_48hours
-- FROM
--   (
--   SELECT
--      inn.period_num
--     ,inn.metric_type
--     ,SUM(inn.metric_value) AS metric_value
--     ,SUM(CASE WHEN inn.metric_type = 'Services - Advisor Sessions'   THEN inn.metric_value ELSE 0 END) AS services_advisor_sessions
--     ,SUM(CASE WHEN inn.metric_type = 'Services - Doc Review'         THEN inn.metric_value ELSE 0 END) AS services_doc_review
--     ,SUM(CASE WHEN inn.metric_type = 'Services - Full Service'       THEN inn.metric_value ELSE 0 END) AS services_full_service
--     ,SUM(CASE WHEN inn.metric_type = 'Chat Conversations and Emails' THEN inn.metric_value ELSE 0 END) AS chat_conversations_and_emails
--     ,SUM(CASE WHEN inn.metric_type = 'Phone Calls at least 2 mins'   THEN inn.metric_value ELSE 0 END) AS phone_calls_at_least_2_mins
--     ,SUM(CASE WHEN inn.metric_type = 'Website Visits (Scaled)'       THEN inn.metric_value ELSE 0 END) AS website_visits_scaled
--     ,SUM(CASE WHEN inn.metric_type = 'Client Reviews'                THEN inn.metric_value ELSE 0 END) AS client_reviews
--     ,SUM(CASE WHEN inn.metric_type = 'Q and A within 48 hours'       THEN inn.metric_value ELSE 0 END) AS q_and_a_within_48hours
--   FROM
--     (
--         SELECT
--            evt1.period_num
--           ,'Services - Advisor Sessions' AS metric_type
--           ,evt1.net_transactions AS metric_value
--         FROM services_events evt1
--         WHERE evt1.package_category = 'Advisor'
--       UNION ALL
--         SELECT
--            evt2.period_num
--           ,'Services - Doc Review' AS metric_type
--           ,evt2.net_transactions AS metric_value
--         FROM services_events evt2
--         WHERE evt2.package_category = 'Doc Review'
--       UNION ALL
--         SELECT
--            evt3.period_num
--           ,'Services - Full Service' AS metric_type
--           ,evt3.net_transactions AS metric_value
--         FROM services_events evt3
--         WHERE evt3.package_category = 'Full Service'
--       UNION ALL
--         SELECT
--            con1.period_num
--           ,'Chat Conversations and Emails' AS metric_type
--           ,SUM(con1.num_contacts) AS metric_value
--         FROM contacts con1
--         WHERE contact_type IN ('message', 'email')
--         GROUP BY 1,2
--       UNION ALL
--         SELECT
--            con1.period_num
--           ,'Phone Calls at least 2 mins' AS metric_type
--           ,SUM(con1.num_contacts) AS metric_value
--         FROM contacts con1
--         WHERE contact_type IN ('phone')
--         GROUP BY 1,2
--       UNION ALL
--         SELECT
--            con1.period_num
--           ,'Website Visits (Scaled)' AS metric_type
--           ,CAST(SUM(con1.num_contacts) / 10 AS INTEGER) AS metric_value
--         FROM contacts con1
--         WHERE contact_type IN ('website')
--         GROUP BY 1,2
--       UNION ALL
--         SELECT
--            tf4.period_num
--           ,'Client Reviews' AS metric_type
--           ,COUNT(*) AS  metric_value
--         FROM         src.barrister_professional_review pfrv
--           INNER JOIN dm.professional_dimension pf
--                   ON pf.professional_id = pfrv.professional_id
--                  AND pf.professional_delete_indicator = 'Not Deleted'
--                  AND pf.professional_name = 'lawyer'
--                  AND pf.industry_name = 'Legal'
--           INNER JOIN timeframes tf4
--                   ON TO_DATE(pfrv.created_at) BETWEEN tf4.period_start_date AND tf4.period_end_date
--         WHERE pfrv.approval_status_id IN (1, 2)
--         GROUP BY 1
--       UNION ALL
--         SELECT
--            tf5.period_num
--           ,'Q and A within 48 hours' AS metric_type
--           ,SUM(CASE WHEN ques.elapsed_48h <> 'Y' THEN NULL
--                     WHEN ques.answertime_mins <= 2880 THEN 1 
--                     ELSE 0 END) AS metric_value
--         FROM
--           (
--           SELECT
--              que.id AS question_id
--             ,TO_DATE(que.created_at) AS q_created_date
--             ,CASE WHEN que.created_at <= date_sub(now(), interval 2880 minutes) THEN 'Y' ELSE 'N' END AS elapsed_48h
--             ,MAX(1) AS questions
--             ,MAX(CASE WHEN ans.id IS NOT NULL THEN 1 ELSE 0 END) AS q_answered
--             ,COUNT(ans.id) AS answers_total
--             ,round((min(unix_timestamp(ans.created_at)-unix_timestamp(que.created_at)))/60,0) AS answertime_mins
--           FROM
--                        src.content_question que
--             LEFT OUTER JOIN src.content_answer ans
--                     ON que.id = ans.question_id
--                    AND ans.approval_status_id IN (1,2)
--           WHERE que.approval_status_id IN (1,2)
--           GROUP BY 1,2,3
--           ) ques
--           INNER JOIN timeframes tf5
--                   ON ques.q_created_date BETWEEN tf5.period_start_date AND tf5.period_end_date
--         GROUP BY 1
--     ) inn
--   GROUP BY 1,2
--   ) met
-- ) qry
--   INNER JOIN timeframes tf0
--           ON qry.period_num = tf0.period_num
