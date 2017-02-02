ocato_reviews
id (int)
advice_session_id (int)
rating (int)
body (string)
created_at (string)
created_at_pst (string)
updated_at (string)
approval_status_id (int)
device_type (string)
remote_ip (string)
user_agent (string)
authorization_token (string)
record_flag (string)
etl_load_date (string)


-- SELECT
--    IFNULL(ofr.package_category, 'Unknown') AS package_category
--   ,rev.rating
--   ,COUNT(DISTINCT ses.id) AS total_sessions  -- cannot do 2 different distincts
--   ,COUNT(DISTINCT rev.advice_session_id) AS reviewed_sessions
--   ,COUNT(rev.advice_session_id) AS reviews
--   ,COUNT(CASE WHEN rev.rating >= 4 THEN rev.advice_session_id ELSE NULL END) AS reviews_4_plus
-- FROM
--   (
--   SELECT
--      ses.id AS advice_session_id
--     ,
--     ,MAX(rev.rating) AS session_rating

--   FROM src.ocato_advice_sessions ses
--     LEFT OUTER JOIN 
--       (
--       SELECT
--          oo.id
--         ,pkg.name
--         ,oo.state_id
--         ,oo.package_id
--         ,(oo.consumer_fee_in_cents/100) AS retail_price
--         ,(oo.provider_fee_in_cents/100) AS marketing_fee
--         ,CASE WHEN pkg.package_category_id = 1 THEN 'Advisor'
--               WHEN pkg.package_category_id = 2 THEN 'Doc Review'
--               WHEN pkg.package_category_id = 3 THEN 'Offline Service'
--               -- WHEN oo.consumer_fee_in_cents = 3900 THEN 'Advisor'
--               ELSE 'Unknown'
--          END AS package_category
--       FROM         src.ocato_offers oo
--         LEFT OUTER JOIN (SELECT id, name, package_category_id FROM src.ocato_packages) pkg
--                 ON oo.package_id = pkg.id
--       ) ofr
--         ON ses.offer_id = ofr.id
--     LEFT OUTER JOIN src.ocato_reviews rev
--             ON ses.id = rev.advice_session_id
--   WHERE ses.created_at >= '2016-01-01'
--   GROUP BY 1,2
--   ) qry
  ,ses.advice_session_id
  ,ses.rating

SELECT
   IFNULL(ofr.package_category, 'Unknown') AS package_category
  ,COUNT(*) AS total_sessions
  ,SUM(CASE WHEN ses.rating IS NOT NULL THEN 1 ELSE 0 END) AS rated_sessions
  ,SUM(IFNULL(ses.reviews, 0)) AS reviews
  ,SUM(CASE WHEN ses.rating >= 4 THEN 1 ELSE 0 END) AS rated_sessions_4_plus
FROM
    (
    SELECT
       ssn.id AS advice_session_id
      ,ssn.offer_id
      ,MAX(rev.rating) AS rating
      ,COUNT(rev.id) AS reviews
    FROM src.ocato_advice_sessions ssn
    LEFT OUTER JOIN src.ocato_reviews rev
          ON ssn.id = rev.advice_session_id
    WHERE ssn.created_at >= '2016-01-01'
    GROUP BY 1,2
    ) ses
  LEFT OUTER JOIN 
    (
    SELECT
       oo.id
      ,pkg.name
      ,oo.state_id
      ,oo.package_id
      ,(oo.consumer_fee_in_cents/100) AS retail_price
      ,(oo.provider_fee_in_cents/100) AS marketing_fee
      ,CASE WHEN pkg.package_category_id = 1 THEN 'Advisor'
            WHEN pkg.package_category_id = 2 THEN 'Doc Review'
            WHEN pkg.package_category_id = 3 THEN 'Offline Service'
            -- WHEN oo.consumer_fee_in_cents = 3900 THEN 'Advisor'
            ELSE 'Unknown'
       END AS package_category
    FROM         src.ocato_offers oo
      LEFT OUTER JOIN (SELECT id, name, package_category_id FROM src.ocato_packages) pkg
              ON oo.package_id = pkg.id
    ) ofr
      ON ses.offer_id = ofr.id
GROUP BY 1
