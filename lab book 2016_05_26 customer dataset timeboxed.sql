Customer dataset - timeboxed

Caution!  This is a quick and dirty dataset for exploration, with assumptions that might make it incompatible with outher data sources.  If you want to use any of this data for a presentation or model, we need to put the time into making sure the part you're using is solid.
Assumptions:
- Include all customers with at least one non-zero bill since 2015-11-01.
- Not a ton of subtlety on revenue figure - just summing from order_line_accumulation_fact.  So it's actual revenue, not MRR.  And it is monthly average, over the all months billed to the customer.
- If revenue is not associated with a professional it is not included.
- As a workaround for no connection to SF data yet, I am defining the primary professional as the one with the highest revenue for that customer (forever).  Tiebreaker is earliest license date.
- Primary PA is currently the top PA for the primary professional.  Not too much more work to get the top PA across all professionals, but this was quicker.  Yeah, after looking at data, should do this top across all.
- Contacts are since Nov 2015 (much messier to get contacts for all time).
- For all of these counts metrics, since it''s not broken down by month, older customers will have more than younger.
- Questions, endorsements, reviews and stuff are for all time (or as far back as the data goes).

Fields

customer_id
state
months_billed - they may have been advertisers on other months, but those months were free.
total_revenue - all revenue for the customer, whether associated with a professional or not
average_monthly_revenue - total revenue / months billed
primary_specialty - primary PA of the top-billed atty
professionals - how many attys ever associated with the customer bill
primary_prof_avvo_rating - avvo rating of the top-billed atty
average_avvo_rating - across all attys for this customer
lowest_avvo_rating
highest_avvo_rating
earliest_claim_date
earliest_bill_date
earliest_license_date
primary_prof_revenue
average_prof_revenue
lowest_prof_revenue
highest_prof_revenue
primary_prof_years_licensed
average_years_licensed
lowest_years_licensed
highest_years_licensed
endorsed_professionals - endorsement data counts how many endorsements were received, not how many were granted by this atty to another
primary_prof_endorsement
average_prof_endorsements
lowest_prof_endorsement
highest_prof_endorsement
reviewed_professionals
primary_prof_reviews
average_prof_reviews
lowest_prof_review
highest_prof_review
primary_prof_review_avg_rating - there are multiple ratings - this is the average rating of the top-billed atty
average_prof_review_rating - this is an average of averages - perhaps suspect
lowest_prof_review_avg_rating
highest_prof_review_avg_rating
questions_answered_professionals
primary_prof_questions_answered
average_prof_questions_answered
lowest_prof_questions_answered
highest_prof_questions_answered
cust_website_contacts
cust_phone_contacts
cust_email_contacts


How hard would it be to export customer ID and 1st bill date for customers who billed since November?

These make sense at the customer level:
    -- 1st bill date
    Avg MRR size (clarify - over all time)
    -- Geo = State & MSA (customer_dimension has state; don''t have MSA
    -- AM  (what is AM?  account manager? yes) (in spreadsheet)

Attributes at the professional level - how to roll up?
    Current Avvo Rating?  professional_dimension table (see if she wants average, high, low, the one associated with the SF primary professional - would need to export and load)
    Primary PA (the one with the highest specialty percentage.  In case of a tie, is there a preference toward certain PAs?)
    Years Licensed - src.barrister_license has license_date - how to roll up to customer?  Could maybe have mult rows for a professional.  Sophia.
    Client Review - how to roll up professional?  Nadine will FUP - what''s easy is rounded.
    Claim date  

Metrics at the professional level - how to roll up?
    - professional to customer
    - what time period - monthly avg?
The metrics:
    No of Contacts - contact_impressions, only since may of last year.
        Phone Calls  
        Websites  
        Emails  
    No of Client Reviews  
    No of Peer Reviews (= Endorsements)
    Questions Answered  

Harder to get:
    Avvo Rating at time of churn (Sophia has pulled hisorical Avvo rating data)

Ping Sophia for how to upload.

----

Add up metrics for pro.
For attributes take the primary pro.
(Keeping it simple for now, and we will see what patterns fall out.)

----

From Nadine:

What’s the simplest way to check if advertiser?
No simple way – you have to go to the order line accumulation fact table and do it based on if they purchased ads in the given month.

--
All these are currently pulling all professionalIDs, not just advertisers.

AM Mapping
Excel is attached – the AM is column B and you can vlookup to the final output based on customer ID.

# Reviews & Rating
select                                                                    
  pfrv.professional_id                                                    
  , sum(pfrv.overall_rating)/COUNT(distinct pfrv.id) as review_rating      
  , COUNT(distinct pfrv.id) as num_reviews             
from src.barrister_professional_review pfrv       
                join DM.professional_dimension pf on pf.professional_id = pfrv.professional_id
                join dm.date_dim dt on dt.actual_date = to_date(pfrv.created_at)
                where pfrv.approval_status_id IN (1,2)
                                -- and pfrv.DEL_FLAG = 'N'           
                                and pf.professional_delete_indicator = 'Not Deleted'
                                and pf.professional_name = 'lawyer'
                                and pf.industry_name = 'Legal'
  group by 1                                                      

# Questions
select    
    created_by as professional_id  
    , count(distinct question_id) as num_questionsanswered              
from src.content_answer              
               where approval_status_id in (1,2)
    group by 1       


# Endorsements
Because I’m lazy tonight, here’s the query that give you the raw data of date, lawyer giving & getting the endorsement (I forget which Sayle wanted, but I think it was endorsements received/endorsee_id).  Can you use these tables and joins to count the # endorsements? I can help more Friday afternoon if needed.

select to_date(eds.created_at) as Endorse_Date
               , eds.endorsee_id 
               , eds.endorser_id
               , eds.ID as Endorsement_ID
               , coalesce(ps.primary_specialty,'N/A') as primary_specialty
from src.barrister_professional_endorsement eds
left join 
(
               select x.professional_id        
                              , MIN(case when x.rt = 1 then x.specialty_name else NULL end) as primary_specialty        
               from           
               (          
                              select pfsp.professional_id
                                             , pfsp.specialty_percent 
                                             , sp.specialty_name  
                                             , ROW_NUMBER() OVER(partition by pfsp.professional_id order by pfsp.specialty_percent desc, sp.specialty_name) rt   
                              from DM.professional_specialty_bridge pfsp      
                              join DM.specialty_dimension sp on sp.specialty_id = pfsp.specialty_id       
                              where pfsp.delete_flag = 'N'   
               ) x        
               group by 1    
) ps on ps.professional_id = eds.endorsee_id
where to_date(eds.created_at)>='2013-01-01'

----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------

These make sense at the customer level:
    -- 1st bill date
    Avg MRR size (clarify - over all time)
    -- Geo = State & MSA (customer_dimension has state; don''t have MSA
    -- AM  (what is AM?  account manager? yes) (in spreadsheet)

Attributes at the professional level - how to roll up?
    -- Current Avvo Rating?  professional_dimension table (see if she wants average, high, low, the one associated with the SF primary professional - would need to export and load)
    -- Primary PA (the one with the highest specialty percentage.  In case of a tie, is there a preference toward certain PAs?)
    -- Years Licensed - src.barrister_license has license_date - how to roll up to customer?  Could maybe have mult rows for a professional.  Sophia.
    Client Review - how to roll up professional?  Nadine will FUP - what''s easy is rounded.
    -- Claim date  

Metrics at the professional level - how to roll up?
    - professional to customer
    - what time period - monthly avg?
The metrics:
    No of Contacts - contact_impressions, only since may of last year.
        Phone Calls  
        Websites  
        Emails  
    No of Client Reviews  
    No of Peer Reviews (= Endorsements)
    Questions Answered  

DROP TABLE tmp_data_dm.coe_customers;
CREATE TABLE tmp_data_dm.coe_customers AS
SELECT DISTINCT
   olaf.customer_id
  ,cd.customer_state_name
FROM         dm.order_line_accumulation_fact olaf
  INNER JOIN dm.customer_dimension cd
          ON olaf.customer_id = cd.customer_id
WHERE olaf.order_line_begin_date >= '2015-11-01'

DROP TABLE tmp_data_dm.coe_cust_prof;
CREATE TABLE tmp_data_dm.coe_cust_prof AS
SELECT
   cust.customer_id
  ,olaf.professional_id
  ,pf.professional_avvo_rating AS avvo_rating
  ,CASE WHEN IFNULL(pf.professional_claim_date, '1900-01-01 00:00:00') NOT lIKE '1900%'
          THEN TO_DATE(pf.professional_claim_date) 
          ELSE NULL END AS             claim_date_prof
  ,olaf.first_bill_dt_prof  -- First bill for this professional
  ,olaf.revenue_prof        -- Total revenue ever for them
  ,lic.license_date_prof    -- Their earliest license date
  ,ROUND(DATEDIFF(TO_DATE(NOW()), lic.license_date_prof) / 365) AS years_licensed
  ,ROW_NUMBER() OVER (PARTITION BY cust.customer_id
                          ORDER BY olaf.revenue_prof DESC, lic.license_date_prof) AS rank_prof
FROM
             tmp_data_dm.coe_customers cust
  INNER JOIN (
             SELECT 
                customer_id
               ,professional_id
               ,MIN(order_line_begin_date) AS first_bill_dt_prof
               ,SUM(order_line_purchase_price_amount_usd) AS revenue_prof
             FROM dm.order_line_accumulation_fact
             WHERE professional_id <> -1
             GROUP BY 1,2
             ) olaf
          ON cust.customer_id = olaf.customer_id
  LEFT OUTER JOIN dm.professional_dimension pf 
          ON olaf.professional_id = pf.professional_id
  LEFT OUTER JOIN 
             (
             SELECT professional_id, MIN(license_date) AS license_date_prof
             FROM src.barrister_license
             GROUP BY 1
             ) lic
          ON olaf.professional_id = lic.professional_id

DROP TABLE tmp_data_dm.coe_prof_specialty;
CREATE TABLE tmp_data_dm.coe_prof_specialty AS
SELECT
   x.professional_id        
  ,MIN(CASE WHEN x.rt = 1 THEN x.specialty_name ELSE NULL END) AS primary_specialty        
FROM           
  (          
  SELECT
     pfsp.professional_id
    ,pfsp.specialty_percent 
    ,sp.specialty_name  
    ,ROW_NUMBER() OVER(PARTITION BY pfsp.professional_id 
                           ORDER BY pfsp.specialty_percent DESC, sp.specialty_name) rt   
  FROM tmp_data_dm.coe_cust_prof cp
  JOIN DM.professional_specialty_bridge pfsp ON cp.professional_id = pfsp.professional_id
  JOIN DM.specialty_dimension sp ON sp.specialty_id = pfsp.specialty_id       
  WHERE pfsp.delete_flag = 'N'   
  ) x        
GROUP BY 1    

DROP TABLE tmp_data_dm.coe_all_endorsements;
CREATE TABLE tmp_data_dm.coe_all_endorsements AS
SELECT
   TO_DATE(eds.created_at) AS endorse_date
  ,eds.endorsee_id AS endorsee_prof_id
  ,eds.endorser_id AS endorser_prof_id
  ,eds.ID AS endorsement_id
  FROM src.barrister_professional_endorsement eds
WHERE TO_DATE(eds.created_at)>='2013-01-01'

-- # Reviews & Rating
DROP TABLE tmp_data_dm.coe_prof_reviews;
CREATE TABLE tmp_data_dm.coe_prof_reviews AS
SELECT                                                                    
  pfrv.professional_id                                                    
 ,SUM(pfrv.overall_rating)/COUNT(DISTINCT pfrv.id) AS average_rating      
 ,COUNT(DISTINCT pfrv.id) AS num_reviews             
FROM tmp_data_dm.coe_cust_prof cp
  INNER JOIN src.barrister_professional_review pfrv ON cp.professional_id = pfrv.professional_id
  INNER JOIN DM.professional_dimension pf ON pf.professional_id = pfrv.professional_id
  INNER JOIN dm.date_dim dt ON dt.actual_date = TO_DATE(pfrv.created_at)
WHERE pfrv.approval_status_id IN (1,2)
  -- and pfrv.DEL_FLAG = 'N'           
  AND pf.professional_delete_indicator = 'Not Deleted'
  AND pf.professional_name = 'lawyer'
  AND pf.industry_name = 'Legal'
GROUP BY 1                                                      

-- # Questions
DROP TABLE tmp_data_dm.coe_prof_questions;
CREATE TABLE tmp_data_dm.coe_prof_questions AS
SELECT    
   created_by AS professional_id  
  ,COUNT(DISTINCT question_id) AS questions_answered
FROM src.content_answer              
WHERE approval_status_id IN (1,2)
GROUP BY 1       

-- Advertiser Contacts
-- Note: contact_impression is only advertisers?
DROP TABLE tmp_data_dm.coe_prof_contacts;
CREATE TABLE tmp_data_dm.coe_prof_contacts AS
SELECT
   imp.professional_id
  ,SUM(CASE WHEN imp.contact_type = 'website' THEN 1 ELSE 0 END) AS website_contacts
  ,SUM(CASE WHEN imp.contact_type = 'phone'   THEN 1 ELSE 0 END) AS phone_contacts
  ,SUM(CASE WHEN imp.contact_type = 'email'   THEN 1 ELSE 0 END) AS email_contacts
FROM tmp_data_dm.coe_cust_prof cp
  INNER JOIN src.contact_impression imp ON cp.professional_id = imp.professional_id
WHERE imp.event_date >= '2015-11-01'
GROUP BY 1


DROP TABLE tmp_data_dm.coe_cust_monthly_revenue;
CREATE TABLE tmp_data_dm.coe_cust_monthly_revenue AS
SELECT
   rev.customer_id
  ,COUNT(*) AS                          months_billed
  ,SUM(rev.revenue_cust) AS             total_revenue
  ,SUM(rev.revenue_cust) / COUNT(*) AS  average_monthly_revenue
FROM
  (
  SELECT
     olaf.customer_id
    ,dt.year_month AS year_month_num
    ,SUM(order_line_purchase_price_amount_usd) AS revenue_cust
  FROM
               tmp_data_dm.coe_customers cust
    INNER JOIN dm.order_line_accumulation_fact olaf
            ON cust.customer_id = olaf.customer_id
    INNER JOIN dm.date_dim dt
            ON olaf.order_line_begin_date = dt.actual_date
  GROUP BY 1,2
  ) rev
GROUP BY 1

tmp_data_dm.coe_customers
  customer_id
  customer_state_name
SELECT COUNT(*) FROM tmp_data_dm.coe_customers
26731

tmp_data_dm.coe_cust_prof
  customer_id
  professional_id
  avvo_rating
  claim_date_prof
  first_bill_dt_prof
  revenue_prof
  license_date_prof
  years_licensed
  rank_prof
SELECT COUNT(*) FROM tmp_data_dm.coe_cust_prof
WHERE rank_prof = 1
26416

tmp_data_dm.coe_prof_specialty
  professional_id
  primary_specialty
SELECT COUNT(*) FROM tmp_data_dm.coe_cust_prof prof
INNER JOIN tmp_data_dm.coe_prof_specialty spec
ON prof.professional_id = spec.professional_id
WHERE prof.rank_prof = 1
26368

tmp_data_dm.coe_all_endorsements
  endorse_date
  endorsee_prof_id
  endorser_prof_id
  endorsement_id
SELECT COUNT(*) FROM
  (SELECT endorsee_prof_id, COUNT(*) AS endorsements
   FROM tmp_data_dm.coe_cust_prof prof
   INNER JOIN tmp_data_dm.coe_all_endorsements endr
           ON prof.professional_id = endr.endorsee_prof_id
   GROUP BY 1) my_endr
21934

tmp_data_dm.coe_prof_reviews
  professional_id
  average_rating
  num_reviews

tmp_data_dm.coe_prof_questions
  professional_id
  questions_answered

tmp_data_dm.coe_prof_contacts
  professional_id
  website_contacts
  phone_contacts
  email_contacts

tmp_data_dm.coe_cust_monthly_revenue
  customer_id
  months_billed
  total_revenue
  average_monthly_revenue

-- The uber-query
DROP TABLE tmp_data_dm.coe_cust_dataset1;
CREATE TABLE tmp_data_dm.coe_cust_dataset1 AS
SELECT
   cust.customer_id
  ,cust.customer_state_name AS state
  ,crev.months_billed
  ,crev.total_revenue
  ,crev.average_monthly_revenue
  ,prof.primary_specialty
  ,prof.professionals
  ,prof.primary_prof_avvo_rating
  ,prof.total_avvo_rating / prof.professionals AS average_avvo_rating
  ,prof.lowest_avvo_rating
  ,prof.highest_avvo_rating
  ,prof.earliest_claim_date
  ,prof.earliest_bill_date
  ,prof.earliest_license_date
  ,prof.primary_prof_revenue
  ,prof.total_prof_revenue / prof.professionals AS average_prof_revenue
  ,prof.lowest_prof_revenue
  ,prof.highest_prof_revenue
  ,prof.primary_prof_years_licensed
  ,prof.total_years_licensed / prof.professionals AS average_years_licensed
  ,prof.lowest_years_licensed
  ,prof.highest_years_licensed

  ,prof.endorsed_professionals
  ,prof.primary_prof_endorsement
  ,prof.total_prof_endorsements / prof.endorsed_professionals AS average_prof_endorsements
  ,prof.lowest_prof_endorsement
  ,prof.highest_prof_endorsement

  ,prof.reviewed_professionals
  ,prof.primary_prof_reviews
  ,prof.total_prof_reviews / prof.reviewed_professionals AS average_prof_reviews
  ,prof.lowest_prof_review
  ,prof.highest_prof_review
  ,prof.primary_prof_review_avg_rating
  ,prof.total_prof_review_avg_rating / prof.reviewed_professionals AS average_prof_review_rating
  ,prof.lowest_prof_review_avg_rating
  ,prof.highest_prof_review_avg_rating

  ,prof.questions_answered_professionals
  ,prof.primary_prof_questions_answered
  ,prof.total_prof_questions_answered / prof.questions_answered_professionals AS average_prof_questions_answered
  ,prof.lowest_prof_questions_answered
  ,prof.highest_prof_questions_answered

  ,prof.cust_website_contacts
  ,prof.cust_phone_contacts
  ,prof.cust_email_contacts
FROM tmp_data_dm.coe_customers cust
  LEFT OUTER JOIN tmp_data_dm.coe_cust_monthly_revenue crev
    ON cust.customer_id = crev.customer_id
  LEFT OUTER JOIN
    (
    SELECT
       cp.customer_id
      ,MAX(spec.primary_specialty) AS primary_specialty
      ,COUNT(*) AS professionals
      ,SUM(CASE WHEN cp.rank_prof = 1 THEN CAST(cp.avvo_rating AS FLOAT) ELSE NULL END) AS primary_prof_avvo_rating
      ,SUM(CAST(cp.avvo_rating AS FLOAT)) AS total_avvo_rating
      ,MIN(CAST(cp.avvo_rating AS FLOAT)) AS lowest_avvo_rating
      ,MAX(CAST(cp.avvo_rating AS FLOAT)) AS highest_avvo_rating
      ,MIN(cp.claim_date_prof) AS          earliest_claim_date
      ,MIN(cp.first_bill_dt_prof) AS       earliest_bill_date
      ,MIN(cp.license_date_prof) AS        earliest_license_date

      ,SUM(CASE WHEN cp.rank_prof = 1 THEN cp.revenue_prof ELSE NULL END) AS primary_prof_revenue
      ,SUM(cp.revenue_prof) AS             total_prof_revenue
      ,MIN(cp.revenue_prof) AS             lowest_prof_revenue
      ,MAX(cp.revenue_prof) AS             highest_prof_revenue

      ,SUM(CASE WHEN cp.rank_prof = 1 THEN cp.years_licensed ELSE NULL END) AS primary_prof_years_licensed
      ,SUM(cp.years_licensed) AS           total_years_licensed
      ,MIN(cp.years_licensed) AS           lowest_years_licensed
      ,MAX(cp.years_licensed) AS           highest_years_licensed

      ,COUNT(endr.professional_id) AS      endorsed_professionals
      ,SUM(CASE WHEN cp.rank_prof = 1 THEN endr.endorsements ELSE NULL END) AS primary_prof_endorsement
      ,SUM(endr.endorsements) AS           total_prof_endorsements
      ,MIN(endr.endorsements) AS           lowest_prof_endorsement
      ,MAX(endr.endorsements) AS           highest_prof_endorsement

      ,COUNT(rev.professional_id) AS       reviewed_professionals
      ,SUM(CASE WHEN cp.rank_prof = 1 THEN rev.num_reviews ELSE NULL END) AS primary_prof_reviews
      ,SUM(rev.num_reviews) AS             total_prof_reviews
      ,MIN(rev.num_reviews) AS             lowest_prof_review
      ,MAX(rev.num_reviews) AS             highest_prof_review
      ,SUM(CASE WHEN cp.rank_prof = 1 THEN rev.average_rating ELSE NULL END) AS primary_prof_review_avg_rating
      ,SUM(rev.average_rating) AS          total_prof_review_avg_rating
      ,MIN(rev.average_rating) AS          lowest_prof_review_avg_rating
      ,MAX(rev.average_rating) AS          highest_prof_review_avg_rating

      ,COUNT(ques.professional_id) AS      questions_answered_professionals
      ,SUM(CASE WHEN cp.rank_prof = 1 THEN ques.questions_answered ELSE NULL END) AS primary_prof_questions_answered
      ,SUM(ques.questions_answered) AS     total_prof_questions_answered
      ,MIN(ques.questions_answered) AS     lowest_prof_questions_answered
      ,MAX(ques.questions_answered) AS     highest_prof_questions_answered

      ,SUM(ctct.website_contacts) AS       cust_website_contacts
      ,SUM(ctct.phone_contacts) AS         cust_phone_contacts
      ,SUM(ctct.email_contacts) AS         cust_email_contacts
    FROM
      tmp_data_dm.coe_cust_prof cp
      LEFT OUTER JOIN tmp_data_dm.coe_prof_specialty spec
        ON cp.professional_id = spec.professional_id
       AND cp.rank_prof = 1
      LEFT OUTER JOIN
        (
        SELECT endorsee_prof_id AS professional_id, COUNT(*) AS endorsements
        FROM tmp_data_dm.coe_all_endorsements
        GROUP BY 1
        ) endr
        ON cp.professional_id = endr.professional_id
      LEFT OUTER JOIN tmp_data_dm.coe_prof_reviews rev
        ON cp.professional_id = rev.professional_id
      LEFT OUTER JOIN tmp_data_dm.coe_prof_questions ques
        ON cp.professional_id = ques.professional_id
      LEFT OUTER JOIN tmp_data_dm.coe_prof_contacts ctct
        ON cp.professional_id = ctct.professional_id
    GROUP BY 1
    ) prof
    ON cust.customer_id = prof.customer_id


  where professionals = 4 and customer_state_name = 'CA'

select * from tmp_data_dm.coe_cust_prof where customer_id = 46673

OH!
When > 1 prof, we end up with 1 row with prim spec NULL and one with a value.
