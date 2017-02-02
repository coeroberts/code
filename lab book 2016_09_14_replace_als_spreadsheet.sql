Fields calculated in base data:
is_discount: IF promotion_id IS NULL THEN 'No' ELSE 'Yes' END
price, marketing_fee: lookup in offers table based on offer_id
translate to dollars from cents: processor_fee, transaction_amount, discount
contra revenue: min(discount, provider_fee (which is the marketing fee))

Want to add: 
actual list of payables and receivables.
    Payable is currently (price for capture succeeded) - (price for refund) + (price for payable_after_refund).
        But we have a trust_account_deposit_succeeded event that should replace this (maybe just the c_s part).
    Receivable is debit pending (on mkt fee) and no marketing_fee_payment_succeeded.
We have the data, it''s a matter of comparing.

-- Exceptions:
-- trust_account_deposit_succeeded w/o capture_succeeded.
--     Find these by going manually through stripe data and matching (on transaction_id).
-- refund (gave money to consumer) without refund_withdraw (took money from atty).
-- debit_pending w/o marketing_fee_payment_succeeded
-- marketing_fee_payment_succeeded w/o debit_pending

-- Assertions:
-- marketing_fee for capture_succeeded should = transaction_amount for atty trust deposit succeeded.

debit_pending represents earned marketing fee.

TA is atty trust deposit succeeded - atty account deposit succeeded
We should calc this and then compare to ending balance in stripe.
(which we back into with a scheduled job that queries stripe)

----
Formula playground:

Transaction
 =GETPIVOTDATA("Sum of event_transaction_amount_in_dollars",$B$70,"event_type","capture_succeeded") (A - Call and capture) charge_transaction_amount
 =GETPIVOTDATA("Sum of processor_fee_in_dollars",$B$70,"event_type","capture_succeeded") (A - Call and capture) charge_processor_fee
 =GETPIVOTDATA("Sum of provider_fee_in_dollars",$B$47,"event_type","capture_succeeded") (B - Revenue earned) charge_marketing_fee
 =GETPIVOTDATA("Sum of consumer_fee_in_dollars",$B$70,"event_type","capture_succeeded") (A - Call and capture) charge_retail_price

Consumer CC charge failed
 =GETPIVOTDATA("Sum of provider_fee_in_dollars",$B$47,"event_type","failed_payment") (B - Revenue earned) failed_payment_marketing_fee
 =GETPIVOTDATA("Sum of consumer_fee_in_dollars",$B$70,"event_type","failed_payment") (A - Call and capture) failed_payment_retail_price
 
Refund
 =GETPIVOTDATA("Sum of event_transaction_amount_in_dollars",$B$66,"event_type","refund") (C - Refunds) refund_transaction_amount
 =GETPIVOTDATA("Sum of processor_fee_in_dollars",$B$66,"event_type","refund") (C - Refunds) refund_processor_fee
 =GETPIVOTDATA("Sum of provider_fee_in_dollars",$B$66,"event_type","refund") (C - Refunds) refund_marketing_fee
 =GETPIVOTDATA("Sum of consumer_fee_in_dollars",$B$66,"event_type","refund") (C - Refunds) refund_retail_price

Attorney Payable After Refund
 =GETPIVOTDATA("Sum of provider_fee_in_dollars",$B$59,"event_type","payable_after_refund") (D - Payable After Refund) payable_after_refund_marketing_fee
 =GETPIVOTDATA("Sum of consumer_fee_in_dollars",$B$59,"event_type","payable_after_refund") (D - Payable After Refund) payable_after_refund_retail_price

Marketing Fee Payment Succeeded
 =GETPIVOTDATA("Sum of event_transaction_amount_in_dollars",$B$81,"event_type","marketing_fee_payment_succeeded_aggregate") (E - Bank Account Exchange) marketing_fee_payment_succeeded_transaction_amount
 =GETPIVOTDATA("Sum of processor_fee_in_dollars",$B$81,"event_type","marketing_fee_payment_succeeded_aggregate") (E - Bank Account Exchange) marketing_fee_payment_succeeded_processor_fee

Marketing Fee Payment Failed
 =GETPIVOTDATA("Sum of event_transaction_amount_in_dollars",$B$81,"event_type","marketing_fee_payment_succeeded_aggregate") (E - Bank Account Exchange) marketing_fee_payment_failed_transaction_amount
 =COUNT marketing_fee_payment_failed_count

Chargeback Initiated
 =GETPIVOTDATA("Sum of event_transaction_amount_in_dollars",$B$65,"event_type","chargeback") (F - Chargeback activity) chargeback_initiated_transaction_amount
 =GETPIVOTDATA("Sum of processor_fee_in_dollars",$B$65,"event_type","chargeback") (F - Chargeback activity) chargeback_initiated_processor_fee

Chargeback Succeeded
 =GETPIVOTDATA("Sum of event_transaction_amount_in_dollars",$B$65,"event_type","chargeback_succeeded") (F - Chargeback activity) chargeback_succeeded_transaction_amount
 =GETPIVOTDATA("Sum of processor_fee_in_dollars",$B$65,"event_type","chargeback_succeeded") (F - Chargeback activity) chargeback_succeeded_processor_fee

Earned Revenue
Contra Revenue
Processing Fees
Cash Paid by Customers (and corresponding contra-COS)
Full Value of Sessions Purchased (and corresponding COS)

To be added:
- attorney_trust_account_deposit_succeeded
- debit_pending

Things that are manually linked to directly in the data table:
- Benefit session transaction value and marketing fee (has to stay manual)
- Details from chargeback stripe data
- Refunds not withdrawn from attorneys (I should calc this)

----

Discounts: We recognize the mkt fees as revenue.  If trx was discounted,
we need to subtract the amount of the discount from the revenue we recognize.
But that can''t go negative.  We may give away a $39.99 service for 
free, and only collect $10 for it.  So that''s not -29.99 revenue,
it''s just 0.

Things that will stay pseudo-manual:
Data sources other than main query:


Questions for Katherine:
*- Why is discount info in another spreadsheet?
*  Tidiness because she had to manually look up amounts.
*- Should probably use the term "Consumer Price"?  Or is it more 
*  correct to call it Retail Price, since it is by definition not 
*  necessarily what we charged the consumer?
*- When reconciling, does everything match on advice_session_id?
*  On our side, yes.

Wahoo!  Katherine confirmed that both discounted and non-discounted
transactions (for refund) happen as a 2-step
process, through AvvoS.  That simplifies the diagram.

----

select *
from src.ocato_financial_event_logs
where advice_session_id = 20132

----
Diagram
- 2 scenarios for Payable After Refund - one already has money in 
  the right place; the other doesn''t?
  So: *does p_a_r always, sometimes, or never represent a money transfer?
  Never.  There may be a money transfer before or after.
  Scenarios:
  1. payable_after_refund
     Refund is issued, money is withdrawn from attorney trust account 
     (refund_withdraw), attorney comes to Avvo to dispute, THEN we 
     mark payable and return money to attorney 
     (attorney_trust_account_deposit_succeeded).
     Currently a payable_after_refund event. Remains the same.
  2. paid_attorney_and_refunded
     Customer contacts Avvo, and the attorney did do the work.  We 
     refund the transaction to the customer and mark it payable 
     at the same time. Attorney trust account is not contacted at all.
     Currently a payable_after_refund event
  3. refund_after_transfer
     Attorney did not do the work but payment has already been 
     transferred from trust account to bank account so we cannot 
     withdraw funds, then customer requests refund. We refund the 
     customer but do not pull any money back from attorney.
     Currently does not have an event
  4. payable_without_charge
     Attorney does not call - session is timed out and voided. 
     Attorney contacts us after and says they will take the call. 
     This currently creates a payable_after_refund, then 
     attorney_trust_account_deposit_succeeded. There is never a 
     capture_succeeded for this session because customer CC was never 
     charged.
     Currently a payable_after_refund event

*- Double-check different buffer account for capture_succeeded. yes
- Double-check different buffer account for refund. no (theory)
  *In both cases, are the accounts involved the same whether discounted
  or not?
  Partly comes down to: If I wanted to write code to track ins/outs
  for the AvvoStripe account, do I need 'If order was discounted' 
  logic?
- 9th of the month - it''s weird listing both the event and the agg 
  event as though they both happen multiple times.
- Timing of chargeback event.
- Why is aggregate marketing fee higher than the sum of the 
  non-aggregates?  *Looks like in some cases, marketing fee is 0 in 
  the non-agg event.
- What''s diff between provider fee and provider commission?
  looks like commission always = retail price
- *For marketing_fee_failed_payment_aggregate, we are showing the 
  wrong fee.
- We see multiple attorney_account_deposit_succeeded records for same session.

----

Coe: Is A/R defined as earned revenue - received revenue?
Coe: well i spose it would be earned - contra - received?
Katherine: actually contra doesn''t figure into it
Katherine: just earned - received
Katherine: atty does discounted session, we earn $10 but ding 
  ourselves $4 for the discount we gave to the customer, atty pays us $10

-- Errors in log data that will affect me:
Well actually, most of these are not errors; it''s just what
gets put into which field.
failed_payment is actually an error.

refund:
payable_after_refund:
  transaction_amount
  discount_amount
attorney_trust_account_deposit_succeeded:
attorney_trust_account_deposit_failed:
refund_withdraw:
  transaction_amount
  (also discount_amount?)

refund
payable_after_refund
attorney_trust_account_deposit_succeeded
attorney_trust_account_deposit_failed
refund_withdraw
  transaction_amount

-- List of exceptions to flag in detail data:
-- - attorney_trust_account_deposit_failed
-- - multiple attorney_account_deposit_succeeded records for same session.
-- trust_account_deposit_succeeded w/o capture_succeeded.
--     Find these by going manually through stripe data and matching (on transaction_id).
-- refund (gave money to consumer) without refund_withdraw (took money from atty).
-- debit_pending w/o marketing_fee_payment_succeeded
-- marketing_fee_payment_succeeded w/o debit_pending
-- Assertions:
-- marketing_fee for capture_succeeded = transaction_amount for debit_pending.
-- Anything without a purchase.
-- attorney_account_deposit_succeeded without attorney_trust_account_deposit_succeeded
-- i got into a weird set of events. also a question for a dev? we are creating $0 marketing_fee_succeeded and atty_acct_dep.. events
-- for one, now it has to go beyond "acct_deposit without marketing_fee" since that won''t grab $0 marketing fees


Things we need from Stripe for reconciliation:
- 

Data sources (well actually tabs):
- Metrics by day
- Event counts by day
- Session metrics - includes discount codes and biz metrics, not event detail
  purchase_date, cc_charge_date.
- Event detail (with new metrics added)
- Session exceptions: certain events not paired with corresponding other events
  (maybe just part of session detail, but maybe not because for the
   exceptions we would want them to show the most relevant date) (or not)


REQUESTS:
- Make hist_ocato_offers usable (with extra fields).
- Do we have a "choose your own attorney yes/no" kind of field?
- Review chargeback events, diagram, and transfers.


ToDo
-- - Fill out list of exceptions
- Fill out list of stripe elements needed
-- - Wordsmith event definitions
-- - Tune diagram
-- - Create new metrics in query.  done.
-- - Make queries for each data source

----
SELECT advice_session_id, COUNT(DISTINCT promotion_id) AS promotions
FROM src.ocato_financial_event_logs
GROUP BY 1
HAVING COUNT(DISTINCT promotion_id) > 1
returns no results.
BUT some rows (specifically purchase) can have NULL when other rows
for that session have a value.

OK my code rewrite (naming and cleanup) matches.

The concept: in happy undiscounted sessions, we earn revenue and 
COS/Contra COS balance out - we got the exact amount of cash to 
pay the atty. With discounted sessions, the COS > Contra COS in 
the amount of the discount. We''re pretty much taking our revenue 
dollars and stuffing them down into Contra COS to fill the gap, so 
instead of having a cost and normal revenue, we have no(or lower) 
cost and less (or no) revenue.                    


This duplicates the query Katherine currently uses, but reformatted and renamed.
-- --ALS Query with consumer fees provider fees and contra revenue
-- SELECT
--    log.event_tm
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
--     -- Contra revenue represents the impact of discounts on net revenue.
--     -- Contra revenue = MIN(marketing_fee, discount_amount)
-- -- LOOK change capture_succeeded to atty_trust_account_deposit_succeed
--   ,CASE WHEN log.event_type IN('capture_succeeded', 'refund', 'payable_after_refund') AND log.promotion_id IS NOT NULL 
--           THEN LEAST(ofr.marketing_fee, (ofr.retail_price - log.transaction_amount))
--              -- (CASE WHEN ofr.marketing_fee < (ofr.retail_price - log.transaction_amount) 
--              --         THEN ofr.marketing_fee 
--              --         ELSE ofr.retail_price - log.transaction_amount
--              --  END) 
--           ELSE NULL END AS contra_revenue_delta
--   ,log.financial_transaction_id
-- FROM
--   (
--   SELECT
--      id 
--     ,created_at AS                               event_tm
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
-- ORDER BY TO_DATE(log.event_tm), log.advice_session_id, log.event_tm

-- OK so wait a minute.
-- For a given event category, one of the metrics might add to cash and another subtract from it.

-- -- Detailed event-level data
-- DROP TABLE tmp_data_dm.coe_als_event_detail;
-- CREATE TABLE tmp_data_dm.coe_als_event_detail AS
-- SELECT
--    TO_DATE(evt.event_tm) AS event_date
--   ,evt.event_tm
--   ,evt.advice_session_id
--   ,evt.event_category
--   ,evt.event_type_raw
--   ,evt.financial_event_type_id
--   ,evt.offer_id
--   ,evt.promotion_id
--   ,evt.is_discounted
--   ,evt.is_professional_selected_at_purchase
--   ,evt.professional_id
--   ,evt.financial_transaction_id
--   ,CASE
--      WHEN evt.event_category = 'cc_charge' THEN                                  transaction_amount_raw + (-1 * processor_fee_raw)
--      WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   (-1 * transaction_amount_raw)
--      WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            transaction_amount_raw
--      WHEN evt.event_category = 'refund' THEN                                     (-1 * transaction_amount_raw) + processor_fee_raw
--      WHEN evt.event_category = 'marketing_fee_payment_succeeded_aggregate' THEN  transaction_amount_raw + (-1 * processor_fee_raw)
--      WHEN evt.event_category = 'marketing_fee_payment_failed_aggregate' THEN                              (-1 * processor_fee_raw)
--      WHEN evt.event_category = 'chargeback_opened' THEN                          (-1 * transaction_amount_raw) + (-1 * processor_fee_raw)
--      WHEN evt.event_category = 'chargeback_won' THEN                             transaction_amount_raw + processor_fee_raw
--      ELSE NULL END AS     cash
--   ,CASE
--      WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   transaction_amount_raw
--      WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            -1 * transaction_amount_raw
--      ELSE NULL END AS     cos
--   ,CASE
--      WHEN evt.event_category = 'cc_charge' THEN                                  transaction_amount_raw
--      WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   contra_revenue_raw
--      WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            -1 * contra_revenue_raw
--      WHEN evt.event_category = 'refund' THEN                                     -1 * transaction_amount_raw
--      ELSE NULL END AS     contra_cos
--   ,CASE
--      WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   marketing_fee_raw
--      WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            -1 * marketing_fee_raw
--      ELSE NULL END AS     earned_revenue
--   ,CASE
--      WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   contra_revenue_raw
--      WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            -1 * contra_revenue_raw
--      ELSE NULL END AS     contra_revenue
--   ,CASE
--      WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   marketing_fee_raw
--      WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            -1 * marketing_fee_raw
--      WHEN evt.event_category = 'marketing_fee_payment_succeeded_aggregate' THEN  -1 * transaction_amount_raw
--      ELSE NULL END AS     accounts_receivable
--   ,CASE
--      WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   marketing_fee_raw
--      WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            -1 * marketing_fee_raw
--      WHEN evt.event_category = 'marketing_fee_payment_succeeded' THEN            -1 * transaction_amount_raw
--      ELSE NULL END AS     accounts_receivable_for_session
--   ,CASE
--      WHEN evt.event_category = 'chargeback_opened' THEN                          transaction_amount_raw
--      WHEN evt.event_category = 'chargeback_won' THEN                             -1 * transaction_amount_raw
--      ELSE NULL END AS     chargeback
--   ,CASE
--      WHEN evt.event_category = 'chargeback_opened' THEN                          processor_fee_raw
--      WHEN evt.event_category = 'chargeback_won' THEN                             -1 * processor_fee_raw
--      ELSE NULL END AS     chargeback_fee
--   ,CASE
--      WHEN evt.event_category = 'cc_charge' THEN                                  processor_fee_raw
--      WHEN evt.event_category = 'refund' THEN                                     -1 * processor_fee_raw
--      WHEN evt.event_category = 'marketing_fee_payment_succeeded_aggregate' THEN  processor_fee_raw
--      WHEN evt.event_category = 'marketing_fee_payment_failed_aggregate' THEN     processor_fee_raw
--      ELSE NULL END AS     processor_fee
--    -- trust_account_balance ends up populating both trust_account_asset and trust_account_liability. 
--   ,CASE
--      WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN   transaction_amount_raw
--      WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN            -1 * transaction_amount_raw
--      WHEN evt.event_category = 'attorney_account_deposit_initiated' THEN         -1 * transaction_amount_raw
--      WHEN evt.event_category = 'attorney_account_deposit_rejected' THEN          transaction_amount_raw
--      ELSE NULL END AS     trust_account_balance
--    -- The only reason for this field is sanity-check and tracking.
--   ,CASE
--      WHEN evt.event_category = 'failed_payment' THEN                             transaction_amount_raw
--      ELSE NULL END AS     failed_payment_amount
--   ,evt.transaction_amount_raw
--   ,evt.processor_fee_raw
--   ,evt.discount_amount_raw
--   ,evt.retail_price_raw
--   ,evt.marketing_fee_raw
--   ,evt.contra_revenue_raw
--   ,evt.purch_transaction_amount
--   ,evt.purch_discount_amount
--   ,evt.chk_purchase_not_found
-- FROM
--   (
--   SELECT
--      log.event_tm
--     ,log.advice_session_id
--     ,CASE WHEN log.event_type = 'capture_succeeded' THEN                  'cc_charge'
--           WHEN log.event_type = 'refund_withdraw' THEN                    'attorney_trust_account_withdraw'
--           WHEN log.event_type = 'attorney_account_deposit_succeeded' THEN 'attorney_account_deposit_initiated'
--           WHEN log.event_type = 'attorney_account_deposit_failed' THEN    'attorney_account_deposit_rejected'
--           WHEN log.event_type = 'chargeback' THEN                         'chargeback_opened'
--           WHEN log.event_type = 'chargeback_succeeded' THEN               'chargeback_won'
--           ELSE log.event_type
--      END AS event_category
--     ,log.event_type AS event_type_raw
--     ,log.financial_event_type_id
--     ,log.offer_id
--     ,log.promotion_id
--     ,CASE WHEN log.promotion_id IS NULL THEN 'N' ELSE 'Y' END AS is_discounted
--     ,log.is_professional_selected_at_purchase
--     ,log.professional_id
--     ,log.financial_transaction_id
--     ,CASE WHEN log.event_type = 'failed_payment' THEN log.purch_transaction_amount ELSE log.transaction_amount END AS  transaction_amount_raw
--     ,log.processor_fee AS       processor_fee_raw
--     ,log.discount_amount AS     discount_amount_raw
--     ,ofr.retail_price AS        retail_price_raw
--     ,ofr.marketing_fee AS       marketing_fee_raw
--     ,log.purch_transaction_amount
--     ,log.purch_discount_amount
--     ,log.chk_purchase_not_found
--       -- Contra revenue represents the impact of discounts on net revenue.
--       -- Contra revenue = MIN(marketing_fee, discount_amount)
--     ,CASE WHEN log.event_type IN ('atty_trust_account_deposit_succeed', 'refund_withdraw') AND log.promotion_id IS NOT NULL 
--             THEN LEAST(ofr.marketing_fee, log.purch_discount_amount)
--             ELSE NULL END AS    contra_revenue_raw
--   FROM
--     (
--     SELECT
--        evt.id AS                                       event_id
--       ,evt.created_at AS                               event_tm
--       ,evt.event_type
--       ,evt.advice_session_id
--       ,evt.offer_id
--       ,evt.promotion_id
--       ,evt.professional_id
--       ,CASE WHEN purch.professional_id IS NULL THEN 'N' ELSE 'Y' END AS is_professional_selected_at_purchase
--       ,evt.financial_transaction_id
--       ,evt.financial_event_type_id
--       ,(evt.processor_fee_in_cents/100) AS             processor_fee
--       ,(evt.event_transaction_amount_in_cents/100) AS  transaction_amount
--       ,(evt.discount_amount_in_cents/100) AS           discount_amount
--       ,CASE WHEN purch.id IS NULL THEN 'Exception: purchase not found' ELSE NULL END AS chk_purchase_not_found
--       ,(IFNULL(purch.event_transaction_amount_in_cents, 0)/100) AS  purch_transaction_amount
--       ,(IFNULL(purch.discount_amount_in_cents, 0)/100) AS           purch_discount_amount
--     FROM src.ocato_financial_event_logs evt
--       LEFT OUTER JOIN src.ocato_financial_event_logs purch
--               ON evt.advice_session_id = purch.advice_session_id
--              AND purch.event_type = 'purchase'
--     -- WHERE TO_DATE(evt.created_at) BETWEEN '2016-08-01' AND '2016-09-30'
--     ) log
--   LEFT OUTER JOIN 
--     (
--     SELECT
--        oo.id
--       ,pkg.name
--       ,oo.state_id
--       ,oo.package_id
--       ,(oo.consumer_fee_in_cents/100) AS retail_price
--       ,(oo.provider_fee_in_cents/100) AS marketing_fee
--       -- ,(marketing_commission_in_cents/100) as marketing_commission  
--     FROM         src.ocato_offers oo
--       LEFT OUTER JOIN (SELECT id, name FROM src.ocato_packages) pkg
--               ON oo.package_id = pkg.id
--     ) ofr
--       ON log.offer_id = ofr.id
--   ) evt


SELECT CASE WHEN advice_session_id IN (23402, 23787, 24996) THEN 'Benefit' ELSE 'Normal' END AS session_type
,*
FROM tmp_data_dm.coe_als_event_detail
WHERE TO_DATE(event_tm) BETWEEN '2016-08-01' AND '2016-08-31'
ORDER BY advice_session_id, event_tm

-- SELECT
--  evt.id, evt.created_at, evt.advice_session_id, evt.event_type
-- ,COUNT(purch.advice_session_id) AS purchases
-- FROM src.ocato_financial_event_logs evt
-- LEFT OUTER JOIN src.ocato_financial_event_logs purch
--         ON evt.advice_session_id = purch.advice_session_id
--        AND purch.event_type = 'purchase'
-- WHERE evt.event_type NOT IN ('marketing_fee_payment_succeeded_aggregate', 'marketing_fee_payment_failed_aggregate')
-- GROUP BY 1,2,3,4
-- HAVING COUNT(purch.advice_session_id) <> 1
-- A few without purch; none with > 1 purch.

-- SELECT
--    exc_purchase_not_found
--   ,check_null_evt_trx
--   ,check_null_purch_trx
--   ,check_transaction_amount
--   ,check_discount_amount
--   ,check_promotion_id
--   ,COUNT(*) AS num_rows
-- FROM (
--     SELECT
--        evt.id AS                                       event_id
--       ,evt.created_at AS                               event_tm
--       ,evt.event_type
--       ,evt.advice_session_id
--       ,evt.offer_id
--       ,evt.promotion_id
--       ,evt.professional_id
--       ,evt.financial_transaction_id
--       ,evt.financial_event_type_id
--       ,(evt.processor_fee_in_cents/100) AS             processor_fee
--       ,(evt.event_transaction_amount_in_cents/100) AS  transaction_amount
--       ,(evt.discount_amount_in_cents/100) AS           discount_amount
--       ,CASE WHEN purch.id IS NULL THEN 'purchase not found' ELSE '' END AS exc_purchase_not_found
--       ,(IFNULL(purch.event_transaction_amount_in_cents, 0)/100) AS  purch_transaction_amount
--       ,(IFNULL(purch.discount_amount_in_cents, 0)/100) AS           purch_discount_amount
--       ,CASE WHEN evt.event_transaction_amount_in_cents IS NULL THEN 'NULL event transaction amount' ELSE 'OK' END AS check_null_evt_trx
--       ,CASE WHEN purch.event_transaction_amount_in_cents IS NULL THEN 'NULL purch transaction amount' ELSE 'OK' END AS check_null_purch_trx
--       ,CASE WHEN IFNULL(evt.event_transaction_amount_in_cents, 99999) <> IFNULL(purch.event_transaction_amount_in_cents, 99999) THEN 'different transaction amount' ELSE 'OK' END AS check_transaction_amount
--       ,CASE WHEN IFNULL(evt.discount_amount_in_cents, 99999) <> IFNULL(purch.discount_amount_in_cents, 99999) THEN 'different discount amount' ELSE 'OK' END AS check_discount_amount
--       ,CASE WHEN IFNULL(evt.promotion_id, 999999) <> IFNULL(purch.promotion_id, 999999) THEN 'different promotion_id' ELSE 'OK' END AS check_promotion_id
--     FROM src.ocato_financial_event_logs evt
--       LEFT OUTER JOIN src.ocato_financial_event_logs purch
--               ON evt.advice_session_id = purch.advice_session_id
--              AND purch.event_type = 'purchase'
--     WHERE TO_DATE(evt.created_at) BETWEEN '2016-08-01' AND '2016-08-31'
-- ) qry
-- WHERE event_type = 'capture_succeeded'
-- GROUP BY 1,2,3,4,5,6
-- OK all of these come up good except one that looks like a test in Dec 2015.


-- DROP TABLE tmp_data_dm.coe_als_session_detail;
-- CREATE TABLE tmp_data_dm.coe_als_session_detail AS
-- SELECT
--    ses.*
--   ,CASE WHEN purchase_count = 0
--          AND marketing_fee_payment_succeeded_aggregate_count = 0
--          AND marketing_fee_payment_failed_aggregate_count = 0
--              THEN 'Error: No purchase'
--              ELSE '' END AS chk_purchase_count
--   ,CASE WHEN attorney_trust_account_deposit_succeeded_count > 1 
--          AND payable_after_refund_count = 0 
--              THEN 'Error: > 1 trust account deposit without payable_after_refund'
--              ELSE '' END AS chk_trust_account_deposit_without_par_count
--   ,CASE WHEN attorney_account_deposit_initiated_count > 1 
--              THEN 'Error: > 1 attorney account deposit'
--              ELSE '' END AS chk_account_deposit_count
--   ,CASE WHEN attorney_trust_account_deposit_failed_count > 0 
--              THEN 'Error: Trust account deposit failed'
--         WHEN attorney_trust_account_deposit_succeeded_count > 0
--          AND cc_charge_count = 0
--          AND payable_after_refund_count = 0 
--              THEN 'Error: Trust account deposit without cc charge'
--         WHEN attorney_trust_account_deposit_succeeded_count > 0
--          AND cc_charge_count = 0
--          AND payable_after_refund_count > 0 
--              THEN 'Warning: Trust account deposit without cc charge but with payable_after_refund'
--              ELSE '' END AS chk_trust_account_deposit
--   ,CASE WHEN attorney_account_deposit_rejected_count > 0 
--              THEN 'Error: Attorney account deposit rejected'
--              ELSE '' END AS chk_account_deposit_failed
--   ,CASE WHEN attorney_account_deposit_initiated_count > 0
--          AND attorney_trust_account_deposit_succeeded_count = 0  
--              THEN 'Error: Attorney account deposit without trust account deposit'
--              ELSE '' END AS chk_bank_and_trust
--   ,CASE WHEN attorney_trust_account_deposit_succeeded_count > 0
--          AND attorney_account_deposit_initiated_count = 0  
--              THEN 'Note: Trust account deposit without attorney account deposit'
--              ELSE '' END AS chk_trust_and_bank
--   ,CASE WHEN attorney_trust_account_deposit_succeeded_count > 0
--          AND marketing_fee_payment_succeeded_count = 0  
--              THEN 'Note: Trust account deposit without marketing fee payment'
--              ELSE '' END AS chk_trust_and_fee
--   ,CASE WHEN marketing_fee_payment_succeeded_count > 0
--          AND attorney_trust_account_deposit_succeeded_count = 0  
--              THEN 'Error: Marketing fee payment without trust account deposit'
--              ELSE '' END AS chk_fee_and_trust
--   ,CASE WHEN attorney_account_deposit_initiated_count > 0
--          AND marketing_fee_payment_succeeded_count = 0  
--              THEN 'Error: Attorney account deposit without marketing fee payment'
--              ELSE '' END AS chk_bank_transfer_and_fee
--   ,CASE WHEN attorney_trust_account_deposit_succeeded_count > 0
--          AND cc_charge_count + failed_payment_count + payable_after_refund_count + void_count = 0  
--              THEN 'Error: Trust account deposit without appropriate consumer event'
--              ELSE '' END AS chk_trust_and_consumer_event
--   ,CASE WHEN payable_after_refund_count > 0
--          AND refund_count + void_count = 0  
--              THEN 'Error: Payable after refund without refund or void'
--              ELSE '' END AS chk_payable_after_refund
--   ,CASE WHEN refund_count > 0
--          AND attorney_trust_account_withdraw_count = 0  
--              THEN 'Note: Refund without attorney_trust_account_withdraw'
--         WHEN refund_count > 0
--          AND transaction_amount_refund <> transaction_amount_ataw  
--              THEN 'Error: Refund and attorney_trust_account_withdraw amounts do not match'
--              ELSE '' END AS chk_refund
--   ,CASE WHEN marketing_fee_payment_succeeded_count > 1 
--              THEN 'Error: Multiple marketing fee payments'
--         WHEN marketing_fee_payment_succeeded_count > 0
--          AND transaction_amount_mfps = 0
--              THEN 'Warning: $0 marketing fee payment' 
--         WHEN marketing_fee_payment_succeeded_count > 0
--          AND marketing_fee <> transaction_amount_mfps 
--              THEN 'Error: Marketing fee does not match marketing fee payment' 
--              ELSE '' END AS chk_marketing_fee_payment
--   ,CASE WHEN retail_price <> transaction_amount_atads 
--          AND attorney_trust_account_deposit_succeeded_count > 0
--              THEN 'Error: Retail price does not match trust account deposit' 
--              ELSE '' END AS chk_price_match_trust_deposit
--   ,CASE WHEN attorney_account_deposit_initiated_count > 0
--          AND transaction_amount_aa_ini = 0
--              THEN 'Warning: $0 attorney account deposit initiated' 
--         WHEN attorney_account_deposit_initiated_count > 0
--          AND retail_price <> transaction_amount_aa_ini 
--              THEN 'Error: Retail price does not match attorney account deposit'
--              ELSE '' END AS chk_attorney_deposit
--   -- When we have the 3 events, this is an error if none of them happened.
--   -- ,CASE WHEN refund_count > 0
--   --        AND attorney_trust_account_withdraw = 0 
--   --            THEN 'Warning: refund without attorney_trust_account_withdraw'
--   --            ELSE '' END AS chk_refund_withdraw
-- FROM
--   (
--   SELECT
--      evt.advice_session_id
--     ,MAX(evt.is_discounted) AS             is_discounted
--     ,MAX(evt.is_professional_selected_at_purchase) AS  is_professional_selected_at_purchase
--     ,TO_DATE(MIN(evt.event_tm)) AS         session_start_date
--     ,        MIN(evt.event_tm) AS          session_start_tm
--     ,TO_DATE(MAX(evt.event_tm)) AS         session_last_date
--     ,        MAX(evt.event_tm) AS          session_last_tm
--     ,TO_DATE(MIN(CASE WHEN evt.event_category = 'cc_charge' THEN evt.event_tm ELSE NULL END)) AS  cc_charge_date
--     ,        MIN(CASE WHEN evt.event_category = 'cc_charge' THEN evt.event_tm ELSE NULL END) AS   cc_charge_tm
--     ,MAX(evt.purch_transaction_amount) AS  purch_transaction_amount
--     ,MAX(evt.purch_discount_amount) AS     purch_discount_amount
--     ,MAX(evt.retail_price_raw) AS          retail_price
--     ,MAX(evt.marketing_fee_raw) AS         marketing_fee
--     ,SUM(CASE WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN evt.transaction_amount_raw ELSE NULL END) AS transaction_amount_atads
--     ,SUM(CASE WHEN evt.event_category = 'attorney_trust_account_deposit_failed'    THEN evt.transaction_amount_raw ELSE NULL END) AS transaction_amount_atadf
--     ,SUM(CASE WHEN evt.event_category = 'attorney_trust_account_withdraw'          THEN evt.transaction_amount_raw ELSE NULL END) AS transaction_amount_ataw
--     ,SUM(CASE WHEN evt.event_category = 'attorney_account_deposit_initiated'       THEN evt.transaction_amount_raw ELSE NULL END) AS transaction_amount_aa_ini
--     ,SUM(CASE WHEN evt.event_category = 'attorney_account_deposit_rejected'        THEN evt.transaction_amount_raw ELSE NULL END) AS transaction_amount_aa_rej
--     ,SUM(CASE WHEN evt.event_category = 'marketing_fee_payment_succeeded'          THEN evt.transaction_amount_raw ELSE NULL END) AS transaction_amount_mfps
--     ,SUM(CASE WHEN evt.event_category = 'refund'                                   THEN evt.transaction_amount_raw ELSE NULL END) AS transaction_amount_refund
--     ,SUM(evt.cash) AS                             cash
--     ,SUM(evt.cos) AS                              cos
--     ,SUM(evt.contra_cos) AS                       contra_cos
--     ,SUM(evt.earned_revenue) AS                   earned_revenue
--     ,SUM(evt.contra_revenue) AS                   contra_revenue
--     ,SUM(evt.accounts_receivable) AS              accounts_receivable
--     ,SUM(evt.accounts_receivable_for_session) AS  accounts_receivable_for_session
--     ,SUM(evt.chargeback) AS                       chargeback
--     ,SUM(evt.chargeback_fee) AS                   chargeback_fee
--     ,SUM(evt.processor_fee) AS                    processor_fee
--     ,SUM(evt.trust_account_balance) AS            trust_account_balance
--     ,SUM(evt.failed_payment_amount) AS            failed_payment_amount
--     ,SUM(CASE WHEN evt.event_category = 'purchase' THEN 1 ELSE 0 END) AS                                   purchase_count
--     ,SUM(CASE WHEN evt.event_category = 'cc_charge' THEN 1 ELSE 0 END) AS                                  cc_charge_count
--     ,SUM(CASE WHEN evt.event_category = 'failed_payment' THEN 1 ELSE 0 END) AS                             failed_payment_count
--     ,SUM(CASE WHEN evt.event_category = 'attorney_trust_account_deposit_succeeded' THEN 1 ELSE 0 END) AS   attorney_trust_account_deposit_succeeded_count
--     ,SUM(CASE WHEN evt.event_category = 'attorney_trust_account_deposit_failed' THEN 1 ELSE 0 END) AS      attorney_trust_account_deposit_failed_count
--     ,SUM(CASE WHEN evt.event_category = 'attorney_trust_account_withdraw' THEN 1 ELSE 0 END) AS            attorney_trust_account_withdraw_count
--     ,SUM(CASE WHEN evt.event_category = 'attorney_account_deposit_initiated' THEN 1 ELSE 0 END) AS         attorney_account_deposit_initiated_count
--     ,SUM(CASE WHEN evt.event_category = 'attorney_account_deposit_rejected' THEN 1 ELSE 0 END) AS          attorney_account_deposit_rejected_count
--     ,SUM(CASE WHEN evt.event_category = 'refund' THEN 1 ELSE 0 END) AS                                     refund_count
--     ,SUM(CASE WHEN evt.event_category = 'attorney_initiated_refund' THEN 1 ELSE 0 END) AS                  attorney_initiated_refund_count
--     ,SUM(CASE WHEN evt.event_category = 'payable_after_refund' THEN 1 ELSE 0 END) AS                       payable_after_refund_count
--     ,SUM(CASE WHEN evt.event_category = 'marketing_fee_payment_succeeded' THEN 1 ELSE 0 END) AS            marketing_fee_payment_succeeded_count
--     ,SUM(CASE WHEN evt.event_category = 'marketing_fee_payment_failed' THEN 1 ELSE 0 END) AS               marketing_fee_payment_failed_count
--     ,SUM(CASE WHEN evt.event_category = 'marketing_fee_payment_succeeded_aggregate' THEN 1 ELSE 0 END) AS  marketing_fee_payment_succeeded_aggregate_count
--     ,SUM(CASE WHEN evt.event_category = 'marketing_fee_payment_failed_aggregate' THEN 1 ELSE 0 END) AS     marketing_fee_payment_failed_aggregate_count
--     ,SUM(CASE WHEN evt.event_category = 'chargeback_opened' THEN 1 ELSE 0 END) AS                          chargeback_opened_count
--     ,SUM(CASE WHEN evt.event_category = 'chargeback_won' THEN 1 ELSE 0 END) AS                             chargeback_won_count
--     ,SUM(CASE WHEN evt.event_category = 'call' THEN 1 ELSE 0 END) AS                                       call_count
--     ,SUM(CASE WHEN evt.event_category = 'void' THEN 1 ELSE 0 END) AS                                       void_count
--     ,MIN(1) AS sessions
--   FROM tmp_data_dm.coe_als_event_detail evt
--   GROUP BY 1
--   ) ses


;
SELECT
*
FROM tmp_data_dm.coe_als_session_detail
WHERE ((TO_DATE(session_start_tm) <= '2016-08-31') AND (TO_DATE(session_last_tm) >= '2016-08-01'))

select *
  FROM tmp_data_dm.coe_als_event_detail
  where advice_session_id = 22843

select *
  FROM tmp_data_dm.coe_als_session_detail
  where advice_session_id = 22843

add "choose your own attorney yes/no" kind of field
If atty is NULL in purchase, no.

----

From here on, use the dedicated files as true source for the queries.

Tabs for Cameron...

Need:
Purchases
Transactions
Product mix is % of total by product (based on transaction counts)

•  Capture succeeded transaction # by month by product (ie advisor, doc review, offline service)
•  Purchases # by month by product (ie advisor, doc review, offline service)
•  Product mix by purchase & capture succeeded
•  Average Marketing fee by product (including & excluding promos) for purchases & capture succeeded
•  Average fee to Avvo (including & excluding promos) for purchases and capture succeeded

Count
Consumer price by product
Marketing fee
(including and excluding promos)

Logic for package type:
=IF(H6=39,"Advisor",(IF(IFERROR((SEARCH("document",D6)>0),0)>0,"Doc Review","Offline Service")))

    SELECT
       oo.id
      ,pkg.name
      ,oo.state_id
      ,oo.package_id
      ,(oo.consumer_fee_in_cents/100) AS retail_price
      ,(oo.provider_fee_in_cents/100) AS marketing_fee
      ,CASE WHEN 
    FROM         src.ocato_offers oo
      LEFT OUTER JOIN (SELECT id, name FROM src.ocato_packages) pkg
              ON oo.package_id = pkg.id

       oo.id
      ,oo.consumer_fee_in_cents
      ,oo.provider_fee_in_cents
      ,pkg.name
      ,oo.package_id
      ,pkg.symbolic_name
      ,pkg.advisor
      ,pkg.offline
      ,pkg.package_category_id
      ,CASE WHEN package_category_id = 1 THEN 'Advisor'
            WHEN package_category_id = 2 THEN 'Doc Review'
            ELSE 'Offline Service'
       END AS package_category
      ,pkg.document
      ,pkg.record_flag

    SELECT *
      ,CASE WHEN pkg.package_category_id = 1 THEN 'Advisor'
            WHEN pkg.package_category_id = 2 THEN 'Doc Review'
            WHEN pkg.package_category_id = 3 THEN 'Offline Service'
            WHEN oo.consumer_fee_in_cents = 3900 THEN 'Advisor'
            ELSE 'Unknown'
       END AS package_category
      ,CASE WHEN pkg.advisor = 1 THEN 'Advisor' ELSE 'Not advisor' END AS is_advisor
      ,CASE WHEN pkg.offline = 1 THEN 'Offline' ELSE 'Not offline' END AS is_offline
      ,CASE WHEN pkg.document = 1 THEN 'Document' ELSE 'Not document' END AS is_document
      ,1 AS offers
    FROM         src.ocato_offers oo
      LEFT OUTER JOIN src.ocato_packages pkg
              ON oo.package_id = pkg.id

Looks like it falls into Advisor, Offline, and all other (which gets called doc review)?
advisor and offline are mutually exclusive.
But advisor sessions can be document (most) or not.
package_category_id  package_cat
1  Advisor
2  Doc Review
3  Offline Service


  -- ,CASE
  --    WHEN evt.event_category = 'purchase' THEN  1
  --    ELSE NULL END AS     purchases
  -- ,CASE
  --    WHEN evt.event_category = 'cc_charge' THEN 1
  --    ELSE NULL END AS     transactions
----

Why do discounted advisor transactions still show up with $10 marketing fee?
(In sept specifically)
"We do not discount what the lawyer receives but we do reduce the amount
 that the lawyer pays us."

SELECT *
    ,CASE WHEN log.event_type = 'capture_succeeded' THEN                  'cc_charge'
          WHEN log.event_type = 'refund_withdraw' THEN                    'attorney_trust_account_withdraw'
          WHEN log.event_type = 'attorney_account_deposit_succeeded' THEN 'attorney_account_deposit_initiated'
          WHEN log.event_type = 'attorney_account_deposit_failed' THEN    'attorney_account_deposit_rejected'
          WHEN log.event_type = 'chargeback' THEN                         'chargeback_opened'
          WHEN log.event_type = 'chargeback_succeeded' THEN               'chargeback_won'
          ELSE log.event_type
     END AS event_category
    ,CASE WHEN log.promotion_id IS NULL THEN 'N' ELSE 'Y' END AS is_discounted
    ,1 AS events
  FROM
    (
    SELECT
       evt.id AS                                       event_id
      ,evt.created_at AS                               event_tm
      ,evt.event_type
      ,evt.advice_session_id
      ,evt.offer_id
      ,evt.promotion_id
      ,evt.professional_id
      ,CASE WHEN purch.professional_id IS NULL THEN 'N' ELSE 'Y' END AS is_professional_selected_at_purchase
      ,evt.financial_transaction_id
      ,evt.financial_event_type_id
      ,(evt.processor_fee_in_cents/100) AS             processor_fee
      ,(evt.event_transaction_amount_in_cents/100) AS  transaction_amount
      ,(evt.discount_amount_in_cents/100) AS           discount_amount
      ,CASE WHEN purch.id IS NULL THEN 'Exception: purchase not found' ELSE NULL END AS chk_purchase_not_found
      ,(IFNULL(purch.event_transaction_amount_in_cents, 0)/100) AS  purch_transaction_amount
      ,(IFNULL(purch.discount_amount_in_cents, 0)/100) AS           purch_discount_amount
    FROM src.ocato_financial_event_logs evt
      LEFT OUTER JOIN src.ocato_financial_event_logs purch
              ON evt.advice_session_id = purch.advice_session_id
             AND purch.event_type = 'purchase'
    WHERE TO_DATE(evt.created_at) BETWEEN '2016-09-01' AND '2016-09-30'
    ) log
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
      ON log.offer_id = ofr.id
-- WHERE ofr.package_category = 'Advisor'

OK here''s how the marketing fee payment works:
The attorney pays us the full marketing fee, so the 
marketing_fee_payment_succeeded event shows the full amount
(such as $10 for advisor).
But we don''t book that much as revenue, because the transaction
was discounted.  That''s why we only book 
marketing_fee_raw - discount_amount_raw (lower-bounded at 0).
When we show the marketing fee in reports, it should be the net amount.
But when we check the transaction amount on marketing_fee_payment_succeeded,
we need to compare to marketing_fee_raw.

----

Look at cc...

-- DROP TABLE tmp_data_dm.coe_temp_als_cc;
-- CREATE TABLE tmp_data_dm.coe_temp_als_cc AS
-- SELECT
--    purch_transaction_amount
--   ,session_start_date
--   ,is_discounted
--   ,CASE WHEN is_professional_selected_at_purchase = 'Y'
--          AND cc_charge_count = 1 THEN 'Professional pre-selected'
--         WHEN is_professional_selected_at_purchase = 'Y'
--          AND cc_charge_count = 0 THEN 'Error: Professional pre-selected but CC failure'
--         WHEN cc_charge_attempt_failed_count > 0
--          AND cc_charge_count = 1 THEN 'CC charge failed then recovered'
--         WHEN cc_charge_count = 1 THEN 'CC charge succeeded'
--         WHEN cc_charge_count > 1 THEN 'Error: Too much cc charge success'
--         WHEN void_count = 1 THEN 'Void'
--         WHEN void_count > 1 THEN 'Error: Too much void'
--         WHEN failed_payment_count = 1 THEN 'CC charge failed'
--         WHEN failed_payment_count > 1 THEN 'Error: Too much cc charge failure'
--         ELSE 'No result yet'
--    END AS session_cc_disposition
--   ,cc_charge_attempt_failed_count
--   -- ,void_count
--   ,COUNT(*) AS sessions
-- FROM tmp_data_dm.coe_als_session_detail 
-- -- WHERE session_start_date >= '2016-01-01'
-- GROUP BY 1,2,3,4,5

-- select * from tmp_data_dm.coe_als_session_detail 
-- where cc_charge_count + void_count + failed_payment_count = 0
-- and session_start_date >= '2016-01-01'

DROP TABLE tmp_data_dm.coe_temp_als_cc;
CREATE TABLE tmp_data_dm.coe_temp_als_cc AS
SELECT
   session_type
  ,session_start_date
  ,purch_transaction_amount
  ,is_discounted
  ,session_cc_disposition
  ,cc_charge_attempt_failed_count
  ,COUNT(*) AS sessions
FROM tmp_data_dm.coe_als_session_detail 
-- WHERE session_start_date >= '2016-01-01'
GROUP BY 1,2,3,4,5,6
