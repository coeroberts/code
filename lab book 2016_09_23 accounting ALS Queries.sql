LOOK this file is no longer used - rolled it into lab book 09_14_replace_als_spreadsheet.sql.


This duplicates the query Katherine currently uses, but reformatted and renamed.
-- --ALS Query with consumer fees provider fees and contra revenue
-- SELECT
--    log.event_dttm
--   ,log.advice_session_id
--   ,log.event_type
--   ,log.financial_event_type_id
--   ,log.offer_id
--   ,log.promotion_id
--   ,CASE WHEN log.promotion_id IS NULL THEN 'N' ELSE 'Y' END AS discounted_yes_no
--   ,log.professional_id
--   ,log.transaction_amount
--   ,log.processor_fee
--   ,log.discount_amount
--   ,ofr.retail_price
--   ,ofr.marketing_fee
--     --when it is a refund, payable after refund, or capture succeeded and there is a promo ID we want to calculate contra revenue
--     -- Contra revenue = MIN(marketing_fee, discount_amount)
-- -- LOOK change capture_succeeded to atty_trust_account_deposit_succeed
--   ,CASE WHEN log.event_type IN('capture_succeeded', 'refund', 'payable_after_refund') AND log.promotion_id IS NOT NULL 
--           THEN LEAST(ofr.marketing_fee, (ofr.retail_price - log.transaction_amount))
--              -- (CASE WHEN ofr.marketing_fee < (ofr.retail_price - log.transaction_amount) 
--              --         THEN ofr.marketing_fee 
--              --         ELSE ofr.retail_price - log.transaction_amount
--              --  END) 
--           ELSE NULL END AS contra_revenue
--   ,log.financial_transaction_id
-- FROM
--   (
--   SELECT
--      id 
--     ,created_at AS                               event_dttm
--     ,event_type
--     ,advice_session_id
--     ,offer_id
--     ,promotion_id
--     ,professional_id
--     ,financial_transaction_id
--     ,financial_event_type_id
--     ,(processor_fee_in_cents/100) AS             processor_fee
--     ,(event_transaction_amount_in_cents/100) AS  transaction_amount
--     ,(discount_amount_in_cents/100) AS           discount_amount
--   FROM src.ocato_financial_event_logs
--   WHERE TO_DATE(created_at) BETWEEN '2016-08-01' AND '2016-08-31'
--   ) log
-- LEFT JOIN 
--   (
--   SELECT
--      oo.id
--     ,name
--     ,state_id
--     ,package_id
--     ,(consumer_fee_in_cents/100) AS retail_price
--     ,(provider_fee_in_cents/100) AS marketing_fee
--     -- ,(marketing_commission_in_cents/100) as marketing_commission  
--   FROM         src.ocato_offers oo
--     LEFT OUTER JOIN (SELECT id, name FROM src.ocato_packages) pkg
--             ON oo.package_id = pkg.id
--   ) ofr
--     ON log.offer_id = ofr.id
-- ORDER BY TO_DATE(log.event_dttm), log.advice_session_id, log.event_dttm

-- Detailed event-level data
DROP TABLE tmp_data_dm.coe_als_event_detail;
CREATE TABLE tmp_data_dm.coe_als_event_detail AS
SELECT
   log.event_dttm
  ,log.advice_session_id
  ,log.event_type
  ,log.financial_event_type_id
  ,log.offer_id
  ,log.promotion_id
  ,CASE WHEN log.promotion_id IS NULL THEN 'N' ELSE 'Y' END AS discounted_yes_no
  ,log.professional_id
  ,log.transaction_amount
  ,log.processor_fee
  ,log.discount_amount
  ,ofr.retail_price
  ,ofr.marketing_fee
    --when it is a refund, payable after refund, or capture succeeded and there is a promo ID we want to calculate contra revenue
    -- Contra revenue = MIN(marketing_fee, discount_amount)
-- LOOK change capture_succeeded to atty_trust_account_deposit_succeed
  ,CASE WHEN log.event_type IN('capture_succeeded', 'refund', 'payable_after_refund') AND log.promotion_id IS NOT NULL 
          THEN LEAST(ofr.marketing_fee, (ofr.retail_price - log.transaction_amount))
             -- (CASE WHEN ofr.marketing_fee < (ofr.retail_price - log.transaction_amount) 
             --         THEN ofr.marketing_fee 
             --         ELSE ofr.retail_price - log.transaction_amount
             --  END) 
          ELSE NULL END AS contra_revenue
  ,log.financial_transaction_id
FROM
  (
  SELECT
     id 
    ,created_at AS                               event_dttm
    ,event_type
    ,advice_session_id
    ,offer_id
    ,promotion_id
    ,professional_id
    ,financial_transaction_id
    ,financial_event_type_id
    ,(processor_fee_in_cents/100) AS             processor_fee
    ,(event_transaction_amount_in_cents/100) AS  transaction_amount
    ,(discount_amount_in_cents/100) AS           discount_amount
  FROM src.ocato_financial_event_logs
  WHERE TO_DATE(created_at) BETWEEN '2016-08-01' AND '2016-08-31'
  ) log
LEFT JOIN 
  (
  SELECT
     oo.id
    ,name
    ,state_id
    ,package_id
    ,(consumer_fee_in_cents/100) AS retail_price
    ,(provider_fee_in_cents/100) AS marketing_fee
    -- ,(marketing_commission_in_cents/100) as marketing_commission  
  FROM         src.ocato_offers oo
    LEFT OUTER JOIN (SELECT id, name FROM src.ocato_packages) pkg
            ON oo.package_id = pkg.id
  ) ofr
    ON log.offer_id = ofr.id
ORDER BY TO_DATE(log.event_dttm), log.advice_session_id, log.event_dttm
