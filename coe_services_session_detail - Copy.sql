DROP TABLE tmp_data_dm.coe_als_session_detail;
CREATE TABLE tmp_data_dm.coe_als_session_detail AS
SELECT
   chk.*
  ,CONCAT(
     CASE WHEN chk_purchase_count                          LIKE 'E%' THEN CONCAT(chk_purchase_count, ';  ') ELSE '' END,
     CASE WHEN chk_trust_account_deposit_without_par_count LIKE 'E%' THEN CONCAT(chk_trust_account_deposit_without_par_count, ';  ') ELSE '' END,
     CASE WHEN chk_account_deposit_count                   LIKE 'E%' THEN CONCAT(chk_account_deposit_count, ';  ') ELSE '' END,
     CASE WHEN chk_trust_account_deposit                   LIKE 'E%' THEN CONCAT(chk_trust_account_deposit, ';  ') ELSE '' END,
     CASE WHEN chk_account_deposit_failed                  LIKE 'E%' THEN CONCAT(chk_account_deposit_failed, ';  ') ELSE '' END,
     CASE WHEN chk_bank_and_trust                          LIKE 'E%' THEN CONCAT(chk_bank_and_trust, ';  ') ELSE '' END,
     CASE WHEN chk_trust_and_bank                          LIKE 'E%' THEN CONCAT(chk_trust_and_bank, ';  ') ELSE '' END,
     CASE WHEN chk_trust_and_fee                           LIKE 'E%' THEN CONCAT(chk_trust_and_fee, ';  ') ELSE '' END,
     CASE WHEN chk_fee_and_trust                           LIKE 'E%' THEN CONCAT(chk_fee_and_trust, ';  ') ELSE '' END,
     CASE WHEN chk_bank_transfer_and_fee                   LIKE 'E%' THEN CONCAT(chk_bank_transfer_and_fee, ';  ') ELSE '' END,
     CASE WHEN chk_trust_and_consumer_event                LIKE 'E%' THEN CONCAT(chk_trust_and_consumer_event, ';  ') ELSE '' END,
     CASE WHEN chk_payable_after_refund                    LIKE 'E%' THEN CONCAT(chk_payable_after_refund, ';  ') ELSE '' END,
     CASE WHEN chk_refund                                  LIKE 'E%' THEN CONCAT(chk_refund, ';  ') ELSE '' END,
     CASE WHEN chk_marketing_fee_payment                   LIKE 'E%' THEN CONCAT(chk_marketing_fee_payment, ';  ') ELSE '' END,
     CASE WHEN chk_price_match_trust_deposit               LIKE 'E%' THEN CONCAT(chk_price_match_trust_deposit, ';  ') ELSE '' END,
     CASE WHEN chk_attorney_deposit                        LIKE 'E%' THEN CONCAT(chk_attorney_deposit, ';  ') ELSE '' END
   ) AS chk_errors
  ,CONCAT(
     CASE WHEN chk_purchase_count                          LIKE 'W%' THEN CONCAT(chk_purchase_count, ';  ') ELSE '' END,
     CASE WHEN chk_trust_account_deposit_without_par_count LIKE 'W%' THEN CONCAT(chk_trust_account_deposit_without_par_count, ';  ') ELSE '' END,
     CASE WHEN chk_account_deposit_count                   LIKE 'W%' THEN CONCAT(chk_account_deposit_count, ';  ') ELSE '' END,
     CASE WHEN chk_trust_account_deposit                   LIKE 'W%' THEN CONCAT(chk_trust_account_deposit, ';  ') ELSE '' END,
     CASE WHEN chk_account_deposit_failed                  LIKE 'W%' THEN CONCAT(chk_account_deposit_failed, ';  ') ELSE '' END,
     CASE WHEN chk_bank_and_trust                          LIKE 'W%' THEN CONCAT(chk_bank_and_trust, ';  ') ELSE '' END,
     CASE WHEN chk_trust_and_bank                          LIKE 'W%' THEN CONCAT(chk_trust_and_bank, ';  ') ELSE '' END,
     CASE WHEN chk_trust_and_fee                           LIKE 'W%' THEN CONCAT(chk_trust_and_fee, ';  ') ELSE '' END,
     CASE WHEN chk_fee_and_trust                           LIKE 'W%' THEN CONCAT(chk_fee_and_trust, ';  ') ELSE '' END,
     CASE WHEN chk_bank_transfer_and_fee                   LIKE 'W%' THEN CONCAT(chk_bank_transfer_and_fee, ';  ') ELSE '' END,
     CASE WHEN chk_trust_and_consumer_event                LIKE 'W%' THEN CONCAT(chk_trust_and_consumer_event, ';  ') ELSE '' END,
     CASE WHEN chk_payable_after_refund                    LIKE 'W%' THEN CONCAT(chk_payable_after_refund, ';  ') ELSE '' END,
     CASE WHEN chk_refund                                  LIKE 'W%' THEN CONCAT(chk_refund, ';  ') ELSE '' END,
     CASE WHEN chk_marketing_fee_payment                   LIKE 'W%' THEN CONCAT(chk_marketing_fee_payment, ';  ') ELSE '' END,
     CASE WHEN chk_price_match_trust_deposit               LIKE 'W%' THEN CONCAT(chk_price_match_trust_deposit, ';  ') ELSE '' END,
     CASE WHEN chk_attorney_deposit                        LIKE 'W%' THEN CONCAT(chk_attorney_deposit, ';  ') ELSE '' END
   ) AS chk_warnings
  ,CONCAT(
     CASE WHEN chk_purchase_count                          LIKE 'N%' THEN CONCAT(chk_purchase_count, ';  ') ELSE '' END,
     CASE WHEN chk_trust_account_deposit_without_par_count LIKE 'N%' THEN CONCAT(chk_trust_account_deposit_without_par_count, ';  ') ELSE '' END,
     CASE WHEN chk_account_deposit_count                   LIKE 'N%' THEN CONCAT(chk_account_deposit_count, ';  ') ELSE '' END,
     CASE WHEN chk_trust_account_deposit                   LIKE 'N%' THEN CONCAT(chk_trust_account_deposit, ';  ') ELSE '' END,
     CASE WHEN chk_account_deposit_failed                  LIKE 'N%' THEN CONCAT(chk_account_deposit_failed, ';  ') ELSE '' END,
     CASE WHEN chk_bank_and_trust                          LIKE 'N%' THEN CONCAT(chk_bank_and_trust, ';  ') ELSE '' END,
     CASE WHEN chk_trust_and_bank                          LIKE 'N%' THEN CONCAT(chk_trust_and_bank, ';  ') ELSE '' END,
     CASE WHEN chk_trust_and_fee                           LIKE 'N%' THEN CONCAT(chk_trust_and_fee, ';  ') ELSE '' END,
     CASE WHEN chk_fee_and_trust                           LIKE 'N%' THEN CONCAT(chk_fee_and_trust, ';  ') ELSE '' END,
     CASE WHEN chk_bank_transfer_and_fee                   LIKE 'N%' THEN CONCAT(chk_bank_transfer_and_fee, ';  ') ELSE '' END,
     CASE WHEN chk_trust_and_consumer_event                LIKE 'N%' THEN CONCAT(chk_trust_and_consumer_event, ';  ') ELSE '' END,
     CASE WHEN chk_payable_after_refund                    LIKE 'N%' THEN CONCAT(chk_payable_after_refund, ';  ') ELSE '' END,
     CASE WHEN chk_refund                                  LIKE 'N%' THEN CONCAT(chk_refund, ';  ') ELSE '' END,
     CASE WHEN chk_marketing_fee_payment                   LIKE 'N%' THEN CONCAT(chk_marketing_fee_payment, ';  ') ELSE '' END,
     CASE WHEN chk_price_match_trust_deposit               LIKE 'N%' THEN CONCAT(chk_price_match_trust_deposit, ';  ') ELSE '' END,
     CASE WHEN chk_attorney_deposit                        LIKE 'N%' THEN CONCAT(chk_attorney_deposit, ';  ') ELSE '' END
   ) AS chk_notes
FROM
(
SELECT
   ses.*
  ,CASE WHEN purchase_count = 0
         AND is_aggregate_event = 'N'
             THEN 'Error: No purchase'
             ELSE '' END AS chk_purchase_count
  ,CASE WHEN attorney_trust_account_deposit_succeeded_count > 1 
         AND payable_after_refund_count = 0 
             THEN 'Error: > 1 trust account deposit without payable_after_refund'
             ELSE '' END AS chk_trust_account_deposit_without_par_count
  ,CASE WHEN attorney_account_deposit_initiated_count > 1
         AND attorney_account_deposit_rejected_count < (attorney_account_deposit_initiated_count - 1)
             THEN 'Error: too many attorney account deposits'
             ELSE '' END AS chk_account_deposit_count
  ,CASE WHEN attorney_trust_account_deposit_failed_count > 0 
             THEN 'Error: Trust account deposit failed'
        WHEN attorney_trust_account_deposit_succeeded_count > 0
         AND cc_charge_count = 0
         AND payable_after_refund_count = 0 
         AND failed_payment_count = 0
             THEN 'Error: Trust account deposit without cc charge'
        WHEN attorney_trust_account_deposit_succeeded_count > 0
         AND cc_charge_count = 0
         AND payable_after_refund_count > 0 
         AND failed_payment_count = 0
             THEN 'Warning: Trust account deposit without cc charge but with payable_after_refund'
             ELSE '' END AS chk_trust_account_deposit
  ,CASE WHEN attorney_account_deposit_initiated_count <= attorney_account_deposit_rejected_count
         AND attorney_account_deposit_initiated_count > 0
             -- If there is not 1 more initiated than rejected then the last thing that happend was a rejection.
             THEN 'Error: Attorney account deposit rejected'
        WHEN attorney_account_deposit_rejected_count > 0
             -- Not clear from the code but this is actually what it translates to.
             THEN 'Note: Multiple attempts for attorney account deposit'
             ELSE '' END AS chk_account_deposit_failed
  ,CASE WHEN attorney_account_deposit_initiated_count > 0
         AND attorney_trust_account_deposit_succeeded_count = 0  
             THEN 'Error: Attorney account deposit without trust account deposit'
             ELSE '' END AS chk_bank_and_trust
  ,CASE WHEN attorney_trust_account_deposit_succeeded_count > attorney_trust_account_withdraw_count
         AND attorney_account_deposit_initiated_count = 0
             THEN 'Note: Trust account deposit without attorney account deposit'
             ELSE '' END AS chk_trust_and_bank
  ,CASE WHEN attorney_trust_account_deposit_succeeded_count > attorney_trust_account_withdraw_count
         AND marketing_fee_payment_succeeded_count = 0  
             THEN 'Note: Trust account deposit without marketing fee payment'
             ELSE '' END AS chk_trust_and_fee
  ,CASE WHEN marketing_fee_payment_succeeded_count > 0
         AND attorney_trust_account_deposit_succeeded_count = 0  
             THEN 'Error: Marketing fee payment without trust account deposit'
             ELSE '' END AS chk_fee_and_trust
  ,CASE WHEN attorney_account_deposit_initiated_count > 0
         AND marketing_fee_payment_succeeded_count = 0  
         AND transaction_amount_aa_ini <> 0  -- 0 will be caught in a different field.
             THEN 'Error: Attorney account deposit without marketing fee payment'
             ELSE '' END AS chk_bank_transfer_and_fee
  ,CASE WHEN attorney_trust_account_deposit_succeeded_count > 0
         AND cc_charge_count + failed_payment_count + payable_after_refund_count + void_count = 0  
             THEN 'Error: Trust account deposit without appropriate consumer event'
             ELSE '' END AS chk_trust_and_consumer_event
  ,CASE WHEN payable_after_refund_count > 0
         AND refund_count + void_count = 0  
             THEN 'Error: Payable after refund without refund or void'
             ELSE '' END AS chk_payable_after_refund
  ,CASE WHEN refund_count > 0
         AND attorney_trust_account_withdraw_count = 0  
             THEN 'Note: Refund without attorney_trust_account_withdraw'
        WHEN refund_count > 0
         AND transaction_amount_refund <> (transaction_amount_ataw - purch_discount_amount)
             THEN 'Error: Refund and attorney_trust_account_withdraw amounts do not match'
             ELSE '' END AS chk_refund
  ,CASE WHEN marketing_fee_payment_succeeded_count > 1 
             THEN 'Error: Multiple marketing fee payments'
        WHEN marketing_fee_payment_succeeded_count > 0
         AND transaction_amount_mfps = 0
             THEN 'Warning: $0 marketing fee payment' 
        WHEN marketing_fee_payment_succeeded_count > 0
         AND marketing_fee_raw <> transaction_amount_mfps 
             THEN 'Error: Marketing fee does not match marketing fee payment' 
             ELSE '' END AS chk_marketing_fee_payment
  ,CASE WHEN retail_price <> (transaction_amount_atads - transaction_amount_ataw)
         AND attorney_trust_account_deposit_succeeded_count > 0
             THEN 'Error: Retail price does not match trust account deposit' 
             ELSE '' END AS chk_price_match_trust_deposit
  ,CASE WHEN attorney_account_deposit_initiated_count > 0
         AND transaction_amount_aa_ini = 0
             THEN 'Warning: $0 attorney account deposit initiated' 
        -- katherine corrected to consider aadr in comparison to retail price
        WHEN attorney_account_deposit_initiated_count > 0
         AND attorney_account_deposit_initiated_count <> attorney_account_deposit_rejected_count
        -- if final aa event is a rejection then net would be 0, which <> retail
        -- rejected but not retried is captured as Error: attorney account deposit rejected above
         AND retail_price <> (transaction_amount_aa_ini - transaction_amount_aa_rej)
             THEN 'Error: Retail price does not match attorney account deposit'
             ELSE '' END AS chk_attorney_deposit
  ,CASE WHEN is_aggregate_event = 'Y'
             THEN 'N/A: aggregate session'
        WHEN is_professional_selected_at_purchase = 'Y'
         AND cc_charge_count = 1 THEN 'Professional pre-selected'
        WHEN is_professional_selected_at_purchase = 'Y'
         AND cc_charge_count = 0 THEN 'Error: Professional pre-selected but CC failure'
        WHEN cc_charge_attempt_failed_count > 0
         AND cc_charge_count = 1 THEN 'CC charge failed then recovered'
        WHEN cc_charge_count = 1 THEN 'CC charge succeeded'
        WHEN cc_charge_count > 1 THEN 'Error: Too much cc charge success'
        WHEN void_count = 1 THEN 'Void'
        WHEN void_count > 1 THEN 'Error: Too much void'
        WHEN failed_payment_count = 1 THEN 'CC charge failed'
        WHEN failed_payment_count > 1 THEN 'Error: Too much cc charge failure'
        ELSE 'No result yet'
   END AS session_cc_disposition
  ,CASE WHEN is_aggregate_event = 'N'
             THEN 'Regular'
             ELSE 'Aggregate' END AS session_type
FROM
  (
  SELECT
     evt.advice_session_id
    ,MAX(evt.professional_id) AS           professional_id
    ,MAX(evt.is_discounted) AS             is_discounted
    ,MAX(evt.is_professional_selected_at_purchase) AS  is_professional_selected_at_purchase
    ,MAX(evt.is_aggregate_event) AS        is_aggregate_event
    ,TO_DATE(MIN(evt.event_tm)) AS         session_start_date
    ,        MIN(evt.event_tm) AS          session_start_tm
    ,TO_DATE(MAX(evt.event_tm)) AS         session_last_date
    ,        MAX(evt.event_tm) AS          session_last_tm
    ,TO_DATE(MIN(CASE WHEN evt.event_category = 'cc_charge' THEN evt.event_tm ELSE NULL END)) AS  cc_charge_date
    ,        MIN(CASE WHEN evt.event_category = 'cc_charge' THEN evt.event_tm ELSE NULL END) AS   cc_charge_tm
    ,TO_DATE(MIN(CASE WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN evt.event_tm ELSE NULL END)) AS  first_trust_account_deposit_date
    ,MAX(evt.purch_transaction_amount) AS  purch_transaction_amount
    ,MAX(evt.purch_discount_amount) AS     purch_discount_amount
    ,MAX(evt.retail_price_raw) AS          retail_price
    ,MAX(evt.marketing_fee) AS             marketing_fee
    ,MAX(evt.marketing_fee_raw) AS         marketing_fee_raw
    ,SUM(CASE WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN evt.transaction_amount_raw ELSE NULL END) AS transaction_amount_atads
    ,SUM(CASE WHEN evt.event_category = 'attorney_trust_account_deposit_failed'    THEN evt.transaction_amount_raw ELSE NULL END) AS transaction_amount_atadf
    ,SUM(CASE WHEN evt.event_category = 'attorney_trust_account_withdraw'          THEN evt.transaction_amount_raw ELSE NULL END) AS transaction_amount_ataw
    ,SUM(CASE WHEN evt.event_category = 'attorney_account_deposit_initiated'       THEN evt.transaction_amount_raw ELSE NULL END) AS transaction_amount_aa_ini
    ,SUM(CASE WHEN evt.event_category = 'attorney_account_deposit_rejected'        THEN evt.transaction_amount_raw ELSE NULL END) AS transaction_amount_aa_rej
    ,SUM(CASE WHEN evt.event_category = 'marketing_fee_payment_succeeded'          THEN evt.transaction_amount_raw ELSE NULL END) AS transaction_amount_mfps
    ,SUM(CASE WHEN evt.event_category = 'refund'                                   THEN evt.transaction_amount_raw ELSE NULL END) AS transaction_amount_refund
    ,SUM(evt.cash) AS                             cash
    ,SUM(evt.cos) AS                              cos
    ,SUM(evt.contra_cos) AS                       contra_cos
    ,SUM(evt.earned_revenue) AS                   earned_revenue
    ,SUM(evt.contra_revenue) AS                   contra_revenue
    ,SUM(evt.accounts_receivable) AS              accounts_receivable
    ,SUM(evt.accounts_receivable_for_session) AS  accounts_receivable_for_session
    ,SUM(evt.chargeback) AS                       chargeback
    ,SUM(evt.chargeback_fee) AS                   chargeback_fee
    ,SUM(evt.processor_fee) AS                    processor_fee
    ,SUM(evt.accrued_fee) AS                      accrued_fee
    ,SUM(evt.trust_account_balance) AS            trust_account_balance
    ,SUM(evt.failed_payment_amount) AS            failed_payment_amount
    ,SUM(CASE WHEN evt.event_category = 'purchase' THEN 1 ELSE 0 END) AS                                   purchase_count
    ,SUM(CASE WHEN evt.event_category = 'cc_charge' THEN 1 ELSE 0 END) AS                                  cc_charge_count
    ,SUM(CASE WHEN evt.event_category = 'cc_charge_attempt_failed' THEN 1 ELSE 0 END) AS                   cc_charge_attempt_failed_count
    ,SUM(CASE WHEN evt.event_category = 'failed_payment' THEN 1 ELSE 0 END) AS                             failed_payment_count
    ,SUM(CASE WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN 1 ELSE 0 END) AS   attorney_trust_account_deposit_succeeded_count
    ,SUM(CASE WHEN evt.event_category = 'attorney_trust_account_deposit_failed' THEN 1 ELSE 0 END) AS      attorney_trust_account_deposit_failed_count
    ,SUM(CASE WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN 1 ELSE 0 END) AS            attorney_trust_account_withdraw_count
    ,SUM(CASE WHEN evt.event_category = 'attorney_account_deposit_initiated' THEN 1 ELSE 0 END) AS         attorney_account_deposit_initiated_count
    ,SUM(CASE WHEN evt.event_category = 'attorney_account_deposit_rejected' THEN 1 ELSE 0 END) AS          attorney_account_deposit_rejected_count
    ,SUM(CASE WHEN evt.event_category = 'refund' THEN 1 ELSE 0 END) AS                                     refund_count
    ,SUM(CASE WHEN evt.event_category = 'attorney_initiated_refund' THEN 1 ELSE 0 END) AS                  attorney_initiated_refund_count
    ,SUM(CASE WHEN evt.event_category = 'payable_after_refund' THEN 1 ELSE 0 END) AS                       payable_after_refund_count
    ,SUM(CASE WHEN evt.event_category = 'marketing_fee_payment_succeeded' THEN 1 ELSE 0 END) AS            marketing_fee_payment_succeeded_count
    ,SUM(CASE WHEN evt.event_category = 'marketing_fee_payment_failed' THEN 1 ELSE 0 END) AS               marketing_fee_payment_failed_count
    ,SUM(CASE WHEN evt.event_category = 'marketing_fee_payment_succeeded_aggregate' THEN 1 ELSE 0 END) AS  marketing_fee_payment_succeeded_aggregate_count
    ,SUM(CASE WHEN evt.event_category = 'marketing_fee_payment_failed_aggregate' THEN 1 ELSE 0 END) AS     marketing_fee_payment_failed_aggregate_count
    ,SUM(CASE WHEN evt.event_category = 'chargeback_opened' THEN 1 ELSE 0 END) AS                          chargeback_opened_count
    ,SUM(CASE WHEN evt.event_category = 'chargeback_won' THEN 1 ELSE 0 END) AS                             chargeback_won_count
    ,SUM(CASE WHEN evt.event_category = 'call' THEN 1 ELSE 0 END) AS                                       call_count
    ,SUM(CASE WHEN evt.event_category = 'void' THEN 1 ELSE 0 END) AS                                       void_count
    ,SUM(CASE WHEN evt.event_category = 'attorney_account_deposit_succeeded_aggregate' THEN 1 ELSE 0 END) AS       attorney_account_deposit_succeeded_aggregate_count
    ,SUM(CASE WHEN evt.event_category = 'attorney_account_deposit_fee_transferred_aggregate' THEN 1 ELSE 0 END) AS attorney_account_deposit_fee_transferred_aggregate_count
    ,MIN(1) AS sessions
  FROM tmp_data_dm.coe_als_event_detail evt
  GROUP BY 1
  ) ses
) chk
