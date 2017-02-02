-- Detailed event-level data
DROP TABLE IF EXISTS tmp_data_dm.coe_services_event_detail;
CREATE TABLE tmp_data_dm.coe_services_event_detail AS
SELECT
   calc.*
  ,IFNULL(earned_revenue, 0) - IFNULL(contra_revenue, 0) AS revenue
  ,IFNULL(earned_revenue, 0) - IFNULL(contra_revenue, 0) - IFNULL(chargeback, 0) - (IFNULL(cos, 0) - IFNULL(contra_cos, 0)) AS gross_margin
FROM
  (
  SELECT
     evt.event_id
    ,TO_DATE(evt.event_dttm) AS event_date
    ,evt.event_dttm
    ,evt.advice_session_id
    -- For session analysis, we would like to group together each type of aggregate event for a month.
    ,CASE
       WHEN evt.event_category = 'marketing_fee_payment_succeeded_aggregate'
         THEN -1 * (1000000 + evt.event_year_month)
       WHEN evt.event_category = 'marketing_fee_payment_failed_aggregate'
         THEN -1 * (2000000 + evt.event_year_month)
       WHEN evt.event_category = 'attorney_account_deposit_succeeded_aggregate'
         THEN -1 * (3000000 + evt.event_year_month)
       WHEN evt.event_category = 'attorney_account_deposit_fee_transferred_aggregate'
         THEN -1 * (4000000 + evt.event_year_month)
       ELSE advice_session_id END AS     advice_session_id_hacked
    ,evt.event_category
    ,evt.event_type_raw
    ,evt.package_category
    ,evt.specialty_id
    ,evt.financial_event_type_id
    ,evt.offer_id
    ,evt.promotion_id
    ,evt.is_discounted
    ,evt.is_professional_selected_at_purchase
    ,evt.professional_id
    ,evt.financial_transaction_id
    ,CASE
       WHEN evt.event_category IN ('marketing_fee_payment_succeeded_aggregate' 
                                  ,'marketing_fee_payment_failed_aggregate' 
                                  ,'attorney_account_deposit_succeeded_aggregate' 
                                  ,'attorney_account_deposit_fee_transferred_aggregate')
         THEN 'Y'
       ELSE 'N' END AS   is_aggregate_event
    -- Business Metrics
    ,CASE
       WHEN evt.event_category = 'purchase' THEN 1
       ELSE 0 END AS     attempted_transactions  -- Purchases #
    ,CASE
       WHEN evt.event_category = 'purchase' THEN evt.purch_transaction_amount + evt.purch_discount_amount
       ELSE 0 END AS     attempted_retail_price
    ,CASE
       WHEN evt.event_category = 'purchase' THEN evt.purch_transaction_amount
       ELSE 0 END AS     attempted_purchase_price
    ,CASE
       WHEN evt.event_category = 'purchase' THEN evt.purch_discount_amount
       ELSE 0 END AS     attempted_discount
    ,CASE
       WHEN evt.event_category = 'purchase' THEN evt.marketing_fee_raw
       ELSE 0 END AS     attempted_marketing_fee
    ,CASE
       WHEN evt.event_category = 'purchase' THEN evt.marketing_fee_raw - LEAST(evt.marketing_fee_raw, evt.purch_discount_amount)
       ELSE 0 END AS     attempted_effective_marketing_fee

    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN 1
       ELSE 0 END AS     successful_transactions  -- Capture Succeeded #
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN   evt.purch_transaction_amount + evt.purch_discount_amount
       ELSE 0 END AS     successful_retail_price
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN evt.purch_transaction_amount
       ELSE 0 END AS     successful_purchase_price  -- Transactions $
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN evt.purch_discount_amount
       ELSE 0 END AS     successful_discount  -- Discount $
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN evt.marketing_fee_raw
       ELSE 0 END AS     successful_marketing_fee
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN evt.marketing_fee_raw - LEAST(evt.marketing_fee_raw, evt.purch_discount_amount)
       ELSE 0 END AS     successful_effective_marketing_fee

    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN  1
       WHEN evt.event_category = 'refund'    THEN -1
       ELSE 0 END AS     net_transactions  -- Net Transactions #
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN      evt.purch_transaction_amount + evt.purch_discount_amount
       WHEN evt.event_category = 'refund'    THEN -1 * evt.purch_transaction_amount + evt.purch_discount_amount
       ELSE 0 END AS     net_retail_price
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN      evt.purch_transaction_amount
       WHEN evt.event_category = 'refund'    THEN -1 * evt.purch_transaction_amount
       ELSE 0 END AS     net_purchase_price
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN      evt.purch_discount_amount
       WHEN evt.event_category = 'refund'    THEN -1 * evt.purch_discount_amount
       ELSE 0 END AS     net_discount
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN      evt.marketing_fee_raw
       WHEN evt.event_category = 'refund'    THEN -1 * evt.marketing_fee_raw
       ELSE 0 END AS     net_marketing_fee
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN      evt.marketing_fee_raw - LEAST(evt.marketing_fee_raw, evt.purch_discount_amount)
       WHEN evt.event_category = 'refund'    THEN -1 * evt.marketing_fee_raw - LEAST(evt.marketing_fee_raw, evt.purch_discount_amount)
       ELSE 0 END AS     net_effective_marketing_fee

    ,CASE
       WHEN evt.event_category = 'refund' THEN 1
       ELSE 0 END AS     refunds  -- Refunds #
    ,CASE
       WHEN evt.event_category = 'void' THEN 1
       ELSE 0 END AS     voids
    -- Accounting Metrics
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN                                  transaction_amount_raw + (-1 * processor_fee_raw)
       WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   (-1 * transaction_amount_raw)
       WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            transaction_amount_raw
       WHEN evt.event_category = 'refund' THEN                                     (-1 * transaction_amount_raw) + processor_fee_raw
       WHEN evt.event_category = 'marketing_fee_payment_succeeded_aggregate' THEN  transaction_amount_raw + (-1 * processor_fee_raw)
       WHEN evt.event_category = 'marketing_fee_payment_failed_aggregate' THEN                              (-1 * processor_fee_raw)
       WHEN evt.event_category = 'chargeback_opened' THEN                          (-1 * transaction_amount_raw) + (-1 * processor_fee_raw)
       WHEN evt.event_category = 'chargeback_won' THEN                             transaction_amount_raw + processor_fee_raw
       WHEN evt.event_category = 'attorney_account_deposit_fee_transferred_aggregate' THEN (-1 * processor_fee_raw)
       ELSE NULL END AS     cash
    ,CASE
       WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   transaction_amount_raw
       WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            -1 * transaction_amount_raw
       ELSE NULL END AS     cos
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN                                  transaction_amount_raw
       WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   contra_revenue_raw
       WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            -1 * contra_revenue_raw
       WHEN evt.event_category = 'refund' THEN                                     -1 * transaction_amount_raw
       ELSE NULL END AS     contra_cos
    ,CASE
       WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   marketing_fee_raw
       WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            -1 * marketing_fee_raw
       ELSE NULL END AS     earned_revenue
    ,CASE
       WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   contra_revenue_raw
       WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            -1 * contra_revenue_raw
       ELSE NULL END AS     contra_revenue
    ,CASE
       WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   marketing_fee_raw
       WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            -1 * marketing_fee_raw
       WHEN evt.event_category = 'marketing_fee_payment_succeeded_aggregate' THEN  -1 * transaction_amount_raw
       ELSE NULL END AS     accounts_receivable
    ,CASE
       WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   marketing_fee_raw
       WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            -1 * marketing_fee_raw
       WHEN evt.event_category = 'marketing_fee_payment_succeeded' THEN            -1 * transaction_amount_raw
       ELSE NULL END AS     accounts_receivable_for_session
    ,CASE
       WHEN evt.event_category = 'chargeback_opened' THEN                          transaction_amount_raw
       WHEN evt.event_category = 'chargeback_won' THEN                             -1 * transaction_amount_raw
       ELSE NULL END AS     chargeback
    ,CASE
       WHEN evt.event_category = 'chargeback_opened' THEN                          processor_fee_raw
       WHEN evt.event_category = 'chargeback_won' THEN                             -1 * processor_fee_raw
       ELSE NULL END AS     chargeback_fee
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN                                  processor_fee_raw
       WHEN evt.event_category = 'refund' THEN                                     -1 * processor_fee_raw
       WHEN evt.event_category = 'marketing_fee_payment_succeeded_aggregate' THEN  processor_fee_raw
       WHEN evt.event_category = 'marketing_fee_payment_failed_aggregate' THEN     processor_fee_raw
       WHEN evt.event_category = 'attorney_account_deposit_succeeded_aggregate' THEN  processor_fee_raw
       ELSE NULL END AS     processor_fee
    ,CASE
       WHEN evt.event_category = 'attorney_account_deposit_succeeded_aggregate' THEN  processor_fee_raw
       WHEN evt.event_category = 'attorney_account_deposit_fee_transferred_aggregate' THEN -1 * processor_fee_raw
       ELSE NULL END AS     accrued_fee
     -- trust_account_balance ends up populating both trust_account_asset and trust_account_liability. 
    ,CASE
       WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   transaction_amount_raw
       WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            -1 * transaction_amount_raw
       WHEN evt.event_category = 'attorney_account_deposit_initiated' THEN         -1 * transaction_amount_raw
       WHEN evt.event_category = 'attorney_account_deposit_rejected' THEN          transaction_amount_raw
       WHEN evt.event_category = 'attorney_account_deposit_rejected' THEN          transaction_amount_raw
       ELSE NULL END AS     trust_account_balance
    ,CASE
       WHEN evt.event_category = 'failed_payment' THEN                             transaction_amount_raw
       ELSE NULL END AS     failed_payment_amount
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN                             transaction_amount_raw
       ELSE NULL END AS     consumer_charge_amount
    ,CASE
       WHEN evt.event_category = 'cc_charge' THEN                             marketing_fee_raw
       ELSE NULL END AS     marketing_fee
    ,evt.transaction_amount_raw
    ,evt.processor_fee_raw
    ,evt.discount_amount_raw
    ,evt.retail_price_raw
    ,evt.marketing_fee_raw
    ,evt.contra_revenue_raw
    ,evt.purch_transaction_amount
    ,evt.purch_discount_amount
    ,evt.chk_purchase_not_found
    ,1 AS events
  FROM
    (
    SELECT
       log.event_id
      ,log.event_dttm
      ,CAST(from_unixtime(unix_timestamp(CAST(log.event_dttm AS TIMESTAMP)), 'yyyyMM') AS INT) AS event_year_month
      ,log.advice_session_id
      ,CASE WHEN log.event_type = 'capture_succeeded' THEN                  'cc_charge'
            WHEN log.event_type = 'capture_failed' THEN                     'cc_charge_attempt_failed'
            WHEN log.event_type = 'refund_withdraw' THEN                    'attorney_trust_account_withdraw'
            WHEN log.event_type = 'attorney_account_deposit_succeeded' THEN 'attorney_account_deposit_initiated'
            WHEN log.event_type = 'attorney_account_deposit_failed' THEN    'attorney_account_deposit_rejected'
            WHEN log.event_type = 'chargeback' THEN                         'chargeback_opened'
            WHEN log.event_type = 'chargeback_succeeded' THEN               'chargeback_won'
            ELSE log.event_type
       END AS event_category
      ,log.event_type AS event_type_raw
      ,log.financial_event_type_id
      ,log.offer_id
      ,log.promotion_id
      ,CASE WHEN log.promotion_id IS NULL THEN 'N' ELSE 'Y' END AS is_discounted
      ,log.is_professional_selected_at_purchase
      ,log.professional_id
      ,ofr.package_category
      ,ofr.specialty_id
      ,log.financial_transaction_id
      -- Adjust for a bug where we do not see the correct transaction amount for a failed payment.
      ,CASE WHEN log.event_type = 'failed_payment' THEN log.purch_transaction_amount ELSE log.transaction_amount END AS  transaction_amount_raw
      ,log.processor_fee AS       processor_fee_raw
      ,log.discount_amount AS     discount_amount_raw
      ,ofr.retail_price AS        retail_price_raw
      ,ofr.marketing_fee AS       marketing_fee_raw
      ,log.purch_transaction_amount
      ,log.purch_discount_amount
      ,log.chk_purchase_not_found
        -- Contra revenue represents the impact of discounts on net revenue.
        -- Contra revenue = MIN(marketing_fee, discount_amount)
      ,CASE WHEN log.event_type IN ('attorney_trust_account_deposit_succeeded', 'refund_withdraw') AND log.promotion_id IS NOT NULL 
              THEN LEAST(ofr.marketing_fee, log.purch_discount_amount)
              ELSE NULL END AS    contra_revenue_raw
      ,ofr.marketing_fee - LEAST(ofr.marketing_fee, log.purch_discount_amount) AS marketing_fee
    FROM
      (
      SELECT
         log.id AS                                       event_id
        -- ,log.created_at AS                               event_dttm  -- LOOK use this one instead if you want UTC.
        ,log.created_at_pst AS                           event_dttm
        ,log.event_type
        ,log.advice_session_id
        ,log.offer_id
        ,log.promotion_id
        ,log.professional_id
        ,CASE WHEN purch.professional_id IS NULL THEN 'N' ELSE 'Y' END AS is_professional_selected_at_purchase
        ,log.financial_transaction_id
        ,log.financial_event_type_id
        ,(log.processor_fee_in_cents/100) AS             processor_fee
        ,(log.event_transaction_amount_in_cents/100) AS  transaction_amount
        ,(log.discount_amount_in_cents/100) AS           discount_amount
        ,CASE WHEN purch.id IS NULL THEN 'Exception: purchase not found' ELSE NULL END AS chk_purchase_not_found
        ,(IFNULL(purch.event_transaction_amount_in_cents, 0)/100) AS  purch_transaction_amount
        ,(IFNULL(purch.discount_amount_in_cents, 0)/100) AS           purch_discount_amount
      FROM src.ocato_financial_event_logs log
        LEFT OUTER JOIN src.ocato_financial_event_logs purch
                ON log.advice_session_id = purch.advice_session_id
               AND purch.event_type = 'purchase'
      -- WHERE TO_DATE(log.created_at) BETWEEN '2016-08-01' AND '2016-09-30'
      ) log
    LEFT OUTER JOIN 
      (
      SELECT
         oo.id
        ,pkg.name
        ,oo.state_id
        ,oo.package_id
        ,pkg.specialty_id
        ,(oo.consumer_fee_in_cents/100) AS retail_price
        ,(oo.provider_fee_in_cents/100) AS marketing_fee
        ,CASE WHEN pkg.package_category_id = 1 THEN 'Advisor'
              WHEN pkg.package_category_id = 2 THEN 'Doc Review'
              WHEN pkg.package_category_id = 3 THEN 'Offline Service'
              -- WHEN oo.consumer_fee_in_cents = 3900 THEN 'Advisor'
              ELSE 'Unknown'
         END AS package_category
      FROM         src.ocato_offers oo
        LEFT OUTER JOIN (SELECT id, name, package_category_id, specialty_id FROM src.ocato_packages) pkg
                ON oo.package_id = pkg.id
      ) ofr
        ON log.offer_id = ofr.id
    ) evt
  ) calc
