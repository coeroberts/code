FYI - i talked to Sendi about North Start.  Basically he wants to 
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

DROP TABLE tmp_data_dm.coe_north_star_draft;
CREATE TABLE tmp_data_dm.coe_north_star_draft AS
SELECT
   aaaaaa AS period
  ,aaaaaa AS period_num
  ,'Daily' AS period_type
  ,aaaaaa AS reference_date
  ,aaaaaa AS period_start_date
  ,aaaaaa AS period_end_date
  ,qry.year_month
  ,mth.month_begin_date
  ,IFNULL(qry.q_answered_within_48h_raw, 0) + 
   IFNULL(qry.client_reviews_raw, 0) + 
   IFNULL(qry.contacts_email_raw, 0) + IFNULL(qry.contacts_message_raw, 0) + 
   (IFNULL(qry.contacts_website_raw, 0) / 10) + 
   IFNULL(qry.contacts_phone_raw, 0) + 
   IFNULL(qry.ls_net_transactions_advisor_raw, 0) + 
   IFNULL(qry.ls_net_transactions_doc_review_raw, 0) + 
   IFNULL(qry.ls_net_transactions_offline_raw, 0) AS     north_star_index
  ,qry.q_answered_within_48h_raw AS                      q_and_a_within_48h
  ,qry.client_reviews_raw AS                             client_reviews
  ,qry.contacts_email_raw + qry.contacts_message_raw AS  emails_or_chat_conversations
  ,qry.contacts_website_raw AS                           website_visits
  ,qry.contacts_phone_raw AS                             phone_calls
  ,qry.ls_net_transactions_advisor_raw AS                ls_net_transactions_advisor
  ,qry.ls_net_transactions_doc_review_raw AS             ls_net_transactions_doc_review
  ,qry.ls_net_transactions_offline_raw AS                ls_net_transactions_offline
FROM
  (
  SELECT
     year_month
    ,SUM(ls_net_transactions_advisor) AS     ls_net_transactions_advisor_raw
    ,SUM(ls_net_transactions_doc_review) AS  ls_net_transactions_doc_review_raw
    ,SUM(ls_net_transactions_offline) AS     ls_net_transactions_offline_raw
    ,SUM(contacts_email) AS                  contacts_email_raw
    ,SUM(contacts_message) AS                contacts_message_raw
    ,SUM(contacts_website) AS                contacts_website_raw
    ,SUM(contacts_phone) AS                  contacts_phone_raw
    ,SUM(client_reviews) AS                  client_reviews_raw
    ,SUM(questions_asked) AS                 questions_asked_raw
    ,SUM(q_answered_within_48h) AS           q_answered_within_48h_raw
  FROM
    (
      SELECT
         cat.year_month
        ,SUM(CASE WHEN cat.package_category = 'Advisor'
                    THEN cat.ls_transactions - cat.ls_refunds
                    ELSE 0 END) AS ls_net_transactions_advisor
        ,SUM(CASE WHEN cat.package_category = 'Doc Review'
                    THEN cat.ls_transactions - cat.ls_refunds
                    ELSE 0 END) AS ls_net_transactions_doc_review
        ,SUM(CASE WHEN cat.package_category = 'Offline Service'
                    THEN cat.ls_transactions - cat.ls_refunds
                    ELSE 0 END) AS ls_net_transactions_offline
        ,SUM(NULL) AS contacts_email
        ,SUM(NULL) AS contacts_message
        ,SUM(NULL) AS contacts_website
        ,SUM(NULL) AS contacts_phone
        ,SUM(NULL) AS client_reviews
        ,SUM(NULL) AS questions_asked
        ,SUM(NULL) AS q_answered_within_48h
      FROM
        (
        SELECT
           dt1.year_month
          ,evt.package_category
          ,SUM(CASE WHEN evt.event_category = 'cc_charge' THEN 1 ELSE 0 END) AS ls_transactions
          ,SUM(CASE WHEN evt.event_category = 'refund'    THEN 1 ELSE 0 END) AS ls_refunds
        FROM         tmp_data_dm.coe_services_event_detail evt
          INNER JOIN dm.date_dim dt1
                  ON evt.event_date = dt1.actual_date
        WHERE dt1.year_month >= 201601
        GROUP BY 1,2
        ) cat
      GROUP BY 1
    UNION ALL
      SELECT
         dt2.year_month
        ,SUM(NULL) AS ls_net_transactions_advisor
        ,SUM(NULL) AS ls_net_transactions_doc_review
        ,SUM(NULL) AS ls_net_transactions_offline
        ,SUM(CASE WHEN ctc.contact_type = 'email'   THEN ctc.num_contacts ELSE 0 END) AS contacts_email
        ,SUM(CASE WHEN ctc.contact_type = 'message' THEN ctc.num_contacts ELSE 0 END) AS contacts_message
        ,SUM(CASE WHEN ctc.contact_type = 'website' THEN ctc.num_contacts ELSE 0 END) AS contacts_website
        ,SUM(NULL) AS contacts_phone
        ,SUM(NULL) AS client_reviews
        ,SUM(NULL) AS questions_asked
        ,SUM(NULL) AS q_answered_within_48h
      FROM         tmp_data_dm.coe_temp_contacts_ds ctc
        INNER JOIN dm.date_dim dt2
                ON ctc.event_date = dt2.actual_date
      WHERE dt2.year_month >= 201501
      GROUP BY 1
    UNION ALL
      SELECT
         dt3.year_month
        ,SUM(NULL) AS ls_net_transactions_advisor
        ,SUM(NULL) AS ls_net_transactions_doc_review
        ,SUM(NULL) AS ls_net_transactions_offline
        ,SUM(NULL) AS contacts_email
        ,SUM(NULL) AS contacts_message
        ,SUM(NULL) AS contacts_website
        ,SUM(CASE WHEN cim.contact_type = 'phone' AND cim.duration >= 120 THEN 1 ELSE 0 END) AS contacts_phone
        ,SUM(NULL) AS client_reviews
        ,SUM(NULL) AS questions_asked
        ,SUM(NULL) AS q_answered_within_48h
      FROM         src.contact_impression cim
        INNER JOIN dm.date_dim dt3
                ON cim.event_date = dt3.actual_date
      WHERE dt3.year_month >= 201501
      GROUP BY 1
    UNION ALL
      SELECT
         dt4.year_month
        ,SUM(NULL) AS ls_net_transactions_advisor
        ,SUM(NULL) AS ls_net_transactions_doc_review
        ,SUM(NULL) AS ls_net_transactions_offline
        ,SUM(NULL) AS contacts_email
        ,SUM(NULL) AS contacts_message
        ,SUM(NULL) AS contacts_website
        ,SUM(NULL) AS contacts_phone
        ,COUNT(*) AS  client_reviews
        ,SUM(NULL) AS questions_asked
        ,SUM(NULL) AS q_answered_within_48h
      FROM         src.barrister_professional_review pfrv
        INNER JOIN dm.professional_dimension pf
                ON pf.professional_id = pfrv.professional_id
               AND pf.professional_delete_indicator = 'Not Deleted'
               AND pf.professional_name = 'lawyer'
               AND pf.industry_name = 'Legal'
        INNER JOIN dm.date_dim dt4
                ON TO_DATE(pfrv.created_at) = dt4.actual_date
      WHERE pfrv.approval_status_id IN (1, 2)
        AND dt4.year_month >= 201501
      GROUP BY 1
    UNION ALL
      SELECT
         dt5.year_month
        ,SUM(NULL) AS ls_net_transactions_advisor
        ,SUM(NULL) AS ls_net_transactions_doc_review
        ,SUM(NULL) AS ls_net_transactions_offline
        ,SUM(NULL) AS contacts_email
        ,SUM(NULL) AS contacts_message
        ,SUM(NULL) AS contacts_website
        ,SUM(NULL) AS contacts_phone
        ,SUM(NULL) AS client_reviews
        ,SUM(ques.questions) AS      questions_asked
        ,SUM(CASE WHEN ques.elapsed_48h <> 'Y' THEN NULL
                  WHEN ques.answertime_mins <= 2880 THEN 1 
                  ELSE 0 END) AS q_answered_within_48h
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
        INNER JOIN dm.date_dim dt5
                ON ques.q_created_date = dt5.actual_date
      WHERE dt5.year_month >= 201501
      GROUP BY 1
    ) uns
  GROUP BY 1
  ) qry
  INNER JOIN tmp_data_dm.coe_my_month_dim mth
          ON qry.year_month = mth.year_month

Ask Monica:
If we are defining successful transactions as cc purchases, then
cc failure does not get included even though consumer''s problem
probably got solved.
OK, that is fine.
She asks what about transactions that are free to the consumer, such as employee benefits?
They get included: "capture succeeded for empty_token... something like that" (from katherine)

