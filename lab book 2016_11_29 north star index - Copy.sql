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
-- Get all approved reviews by create date, where the professional
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
WHERE pfrv.approval_status_id = 2          
GROUP BY 1                                                      

select count(*)
  FROM src.contact_impression
  WHERE event_date >= '2016-08-01'
and professional_id = -1
returns 1012 (of 1519431 total)
