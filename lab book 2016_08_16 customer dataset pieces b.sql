Customer dataset - timeboxed

Caution!  This is a quick and dirty dataset for exploration, with assumptions that might make it incompatible with outher data sources.  If you want to use any of this data for a presentation or model, we need to put the time into making sure the part you''re using is solid.
Assumptions:
- Include all customers with at least one non-zero bill in 2016_07.
- All professionals are included, not just advertisers.
- As a workaround for no connection to SF data yet, I am defining the primary professional as the one with the highest revenue for that customer (forever).  Tiebreaker is earliest license date.
- Primary PA is currently the top PA for the primary professional.  Not too much more work to get the top PA across all professionals, but this was quicker.  Yeah, after looking at data, should do this top across all.
- Contacts are since Nov 2015 (much messier to get contacts for all time).
- For all of these counts metrics, since it''s not broken down by month, older customers will have more than younger.
- Questions, endorsements, reviews and stuff are for all time (or as far back as the data goes).
- Not a ton of subtlety on revenue figure - just summing from order_line_accumulation_fact.  So it''s actual revenue, not MRR.  And it is monthly average, over the all months billed to the customer.
- If revenue is not associated with a professional it is not included.

----
Dates: licensed, claimed, acquired
Revenue and MRR
Primary practice area 
    What PA did they tell us? 
    Would also be great to know where they have the most ads. No, too much work.
Endorsements given and received
Consumer reviews
Questions answered
Contacts, ACU, ACV (where do I find targets?)

----

DROP TABLE tmp_data_dm.coe_customers;
CREATE TABLE tmp_data_dm.coe_customers AS
SELECT
   olaf.customer_id
  ,cd.customer_state_name
  ,MAX(CASE WHEN olaf.product_line_id IN (2,7) THEN 'Y' ELSE 'N' END) AS has_ads
  ,MAX(CASE WHEN olaf.product_line_id IN (15, 12) THEN 'Y' ELSE 'N' END) AS has_website
FROM         dm.order_line_accumulation_fact olaf
  INNER JOIN dm.customer_dimension cd
          ON olaf.customer_id = cd.customer_id
WHERE olaf.order_line_begin_date BETWEEN '2016-07-01' AND '2016-07-31'
GROUP BY 1,2

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
WHERE pfrv.approval_status_id = 2          
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


-- The uber-query
DROP TABLE tmp_data_dm.coe_cust_dataset2;
CREATE TABLE tmp_data_dm.coe_cust_dataset2 AS
SELECT
   cust.customer_id
  ,cust.customer_state_name AS state
  ,cust.has_ads
  ,cust.has_website
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
  ,((2016 - CAST(STRLEFT(prof.earliest_bill_date, 4) AS INTEGER)) * 12) +
    (   8 - CAST(SUBSTR(prof.earliest_bill_date, 6, 2) AS INTEGER)) + 1 AS tenure_months
  ,prof.earliest_license_date
  ,prof.total_prof_revenue / prof.professionals AS average_prof_revenue
  ,prof.total_years_licensed / prof.professionals AS average_years_licensed
  ,prof.endorsed_professionals
  ,prof.total_prof_endorsements / prof.endorsed_professionals AS average_prof_endorsements
  ,prof.reviewed_professionals
  ,prof.total_prof_reviews / prof.reviewed_professionals AS average_prof_reviews
  ,prof.total_prof_review_avg_rating / prof.reviewed_professionals AS average_prof_review_rating
  ,prof.questions_answered_professionals
  ,prof.total_prof_questions_answered / prof.questions_answered_professionals AS average_prof_questions_answered
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
      ,SUM(CAST(cp.avvo_rating AS FLOAT)) AS total_avvo_rating
      ,MIN(cp.claim_date_prof) AS          earliest_claim_date
      ,MIN(cp.first_bill_dt_prof) AS       earliest_bill_date
      ,MIN(cp.license_date_prof) AS        earliest_license_date
      ,SUM(cp.revenue_prof) AS             total_prof_revenue
      ,SUM(cp.years_licensed) AS           total_years_licensed
      ,COUNT(endr.professional_id) AS      endorsed_professionals
      ,SUM(endr.endorsements) AS           total_prof_endorsements
      ,COUNT(rev.professional_id) AS       reviewed_professionals
      ,SUM(rev.num_reviews) AS             total_prof_reviews
      ,SUM(rev.average_rating) AS          total_prof_review_avg_rating
      ,COUNT(ques.professional_id) AS      questions_answered_professionals
      ,SUM(ques.questions_answered) AS     total_prof_questions_answered
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

-- where cust.customer_id = 46673
