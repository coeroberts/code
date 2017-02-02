OK so 'successful transactions' is *loosely* purchases net of voids,
but it also excludes cc failures and some weird sessions.
It is just the count of cc charges.
(Note that in terms of customer problem solved, in a sense it counts,
 but we don''t want to count it.)

OK actually have to define what our basic metrics are.
Cam has GTV, Gross Revenue, and Net Revenue,
Her Gross is purchases - voids, but before refunds.
LOOK add basic business metrics:
consumer_charge_amount
purchase_amount
discount_amount
marketing_fee

gross_transactions
gross_retail_price
gross_purchase_price
gross_marketing_fee
gross_effective_marketing_fee
successful_transactions
successful_retail_price
successful_purchase_price
successful_marketing_fee
successful_effective_marketing_fee
net_transactions
net_retail_price
net_purchase_price
net_marketing_fee
net_effective_marketing_fee


  ,CASE
     WHEN evt.event_category = 'bbbbbbbb' THEN  cccccccc
     WHEN evt.event_category = 'dddddddd' THEN -1 * eeeeeeee
     ELSE NULL END AS     aaaaaaaa

drop TABLE tmp_data_dm.coe_temp_event;
CREATE TABLE tmp_data_dm.coe_temp_event as
select * from tmp_data_dm.coe_session_event_detail
where event_date BETWEEN '2016-09-01' AND '2016-09-30'

select * from tmp_data_dm.coe_services_session_detail
where session_start_date BETWEEN '2016-09-01' AND '2016-09-30'

OK next step on this is build a dup of one of the existing als metrics tables,
and check amounts.  yep, works.

SELECT
   dt.year_month
  ,SUM(gross_transactions) AS                  purchases
  ,SUM(voids) AS                               voids
  ,SUM(successful_transactions) AS             capture_succeeded
  ,SUM(refunds) AS                             refunds
  ,SUM(net_transactions) AS                    net_trans

  ,SUM(gross_transactions) AS                  gross_transactions
  ,SUM(gross_retail_price) AS                  gross_retail_price
  ,SUM(gross_purchase_price) AS                gross_purchase_price
  ,SUM(gross_discount) AS                      gross_discount
  ,SUM(gross_marketing_fee) AS                 gross_marketing_fee
  ,SUM(gross_effective_marketing_fee) AS       gross_effective_marketing_fee
  ,SUM(successful_transactions) AS             successful_transactions
  ,SUM(successful_retail_price) AS             successful_retail_price
  ,SUM(successful_purchase_price) AS           successful_purchase_price
  ,SUM(successful_discount) AS                 successful_discount
  ,SUM(successful_marketing_fee) AS            successful_marketing_fee
  ,SUM(successful_effective_marketing_fee) AS  successful_effective_marketing_fee
  ,SUM(net_transactions) AS                    net_transactions
  ,SUM(net_retail_price) AS                    net_retail_price
  ,SUM(net_purchase_price) AS                  net_purchase_price
  ,SUM(net_discount) AS                        net_discount
  ,SUM(net_marketing_fee) AS                   net_marketing_fee
  ,SUM(net_effective_marketing_fee) AS         net_effective_marketing_fee
FROM         tmp_data_dm.coe_services_event_detail evt
  INNER JOIN dm.date_dim dt
          ON evt.event_date = dt.actual_date
WHERE dt.year_month >= 201604
GROUP BY 1 ORDER BY 1

-- - Have to change mine to use created_at_pst. done
- Look into 'truly free' sessions.
Thoughts about this:
We have had 294 advice sessions in 2016 w/ purchase price = 0
~30 are employee (26 of them through 10/31)
$662K total retail price
$35K total discount
$13K of that discount was completely free (to the consumer) transactions
(about $12K non-employee and free)
----

Jan 2017 rename and refine business metrics...

Q: For the aggregated, succeeded might really mean succeeded.  Our 
deposit fee events are attorney_account_deposit_succeeded_aggregate 
and attorney_account_deposit_fee_transferred_aggregate.  We did not 
have attorney_account_deposit_failed_aggregate
Answer: 1, now I''m wondering what would trigger 
a_a_d_succeeded_aggregate. If we can get only the ultimately 
successful ones, neat, but maybe we actually can''t? And we should 
have initiated and rejected? 
We need to meet with the devs on this.  My guess is since they have
not implemented, they are not certain of exact definition.

Q: Is it reasonable to say Revenue = Earned Revenue - Contra Revenue?
Answer: 2, exactly correct. We track contra separately for our 
internal detail because it''s important, but the "Revenue" we report 
is always after the effects of contra revenue.

But today: turns out there''s some kind of loophole in Services 
transactions. Found out because 3 people complained, looked into it, 
there''s like 60 of these sessions :| Who should I email with "here's 
what's happening, how is it happening, can we make it stop"
DIR-6395
Customer requests refund, we pull the money back from trust,
we say payable after refund but then never put the money back into
trust (or should not have pulled it out).  It is like we decided
atty did not do the work, but we have some attys complaining that
they did, and we think they did to the extent that we see
payable_after_refund, but atty does not end up with the money.

Q: Splain to me again why Trust Account Asset and Trust Account 
Liability have the same sign?
Answer: Because it is never not going to be the same number.
Analogy is revenue and accounts receivable – they are converse, 
but both end up positive in these metrics.

Compare:

SELECT
   'New' as version
  ,dt.year_month
  ,SUM(attempted_transactions) AS              purchases
  ,SUM(voids) AS                               voids
  ,SUM(successful_transactions) AS             capture_succeeded
  ,SUM(refunds) AS                             refunds
  ,SUM(net_transactions) AS                    net_trans
  ,SUM(attempted_transactions) AS              attempted_transactions
  ,SUM(attempted_retail_price) AS              attempted_retail_price
  ,SUM(attempted_purchase_price) AS            attempted_purchase_price
  ,SUM(attempted_discount) AS                  attempted_discount
  ,SUM(attempted_marketing_fee) AS             attempted_marketing_fee
  ,SUM(attempted_effective_marketing_fee) AS   attempted_effective_marketing_fee
  ,SUM(successful_transactions) AS             successful_transactions
  ,SUM(successful_retail_price) AS             successful_retail_price
  ,SUM(successful_purchase_price) AS           successful_purchase_price
  ,SUM(successful_discount) AS                 successful_discount
  ,SUM(successful_marketing_fee) AS            successful_marketing_fee
  ,SUM(successful_effective_marketing_fee) AS  successful_effective_marketing_fee
  ,SUM(net_transactions) AS                    net_transactions
  ,SUM(net_retail_price) AS                    net_retail_price
  ,SUM(net_purchase_price) AS                  net_purchase_price
  ,SUM(net_discount) AS                        net_discount
  ,SUM(net_marketing_fee) AS                   net_marketing_fee
  ,SUM(net_effective_marketing_fee) AS         net_effective_marketing_fee
  ,SUM(revenue) AS                             revenue
  ,SUM(gross_margin) AS                        gross_margin
  ,SUM(earned_revenue) AS                      earned_revenue
  ,SUM(contra_revenue) AS                      contra_revenue
  ,SUM(chargeback) AS                          chargeback
  ,SUM(cos) AS                                 cos
  ,SUM(contra_cos) AS                          contra_cos
FROM         tmp_data_dm.coe_services_event_detail evt
  INNER JOIN dm.date_dim dt
          ON evt.event_date = dt.actual_date
WHERE dt.year_month BETWEEN 201604 AND 201612
GROUP BY 1,2

SELECT
   'Old' as version
  ,dt.year_month
  ,SUM(gross_transactions) AS                  purchases
  ,SUM(voids) AS                               voids
  ,SUM(successful_transactions) AS             capture_succeeded
  ,SUM(refunds) AS                             refunds
  ,SUM(net_transactions) AS                    net_trans
  ,SUM(gross_transactions) AS              attempted_transactions
  ,SUM(gross_retail_price) AS              attempted_retail_price
  ,SUM(gross_purchase_price) AS            attempted_purchase_price
  ,SUM(gross_discount) AS                  attempted_discount
  ,SUM(gross_marketing_fee) AS             attempted_marketing_fee
  ,SUM(gross_effective_marketing_fee) AS   attempted_effective_marketing_fee
  ,SUM(successful_transactions) AS             successful_transactions
  ,SUM(successful_retail_price) AS             successful_retail_price
  ,SUM(successful_purchase_price) AS           successful_purchase_price
  ,SUM(successful_discount) AS                 successful_discount
  ,SUM(successful_marketing_fee) AS            successful_marketing_fee
  ,SUM(successful_effective_marketing_fee) AS  successful_effective_marketing_fee
  ,SUM(net_transactions) AS                    net_transactions
  ,SUM(net_retail_price) AS                    net_retail_price
  ,SUM(net_purchase_price) AS                  net_purchase_price
  ,SUM(net_discount) AS                        net_discount
  ,SUM(net_marketing_fee) AS                   net_marketing_fee
  ,SUM(net_effective_marketing_fee) AS         net_effective_marketing_fee
  ,SUM(NULL) AS                            revenue
  ,SUM(NULL) AS                            gross_margin
  ,SUM(earned_revenue) AS                      earned_revenue
  ,SUM(contra_revenue) AS                      contra_revenue
  ,SUM(chargeback) AS                          chargeback
  ,SUM(cos) AS                                 cos
  ,SUM(contra_cos) AS                          contra_cos
FROM         tmp_data_dm.coe_services_event_detail_old evt
  INNER JOIN dm.date_dim dt
          ON evt.event_date = dt.actual_date
WHERE dt.year_month BETWEEN 201604 AND 201612
GROUP BY 1,2

It works.
----
Notes from 1/18 meeting about the new fee transfer aggregate event...

https://avvojira.atlassian.net/browse/DIR-6106

attorney_account_deposit_succeeded_aggregate: Stripe says 'Here are 
the trust account to atty account deposit transactions that we expect 
to charge you fees for'.
Would be great if we got that from Stripe, but if we have to generate 
it, we might as well do that on the data side instead of making the 
front-end team simulate it.  They would just be sending a sum of the 
same data that we already have.

attorney_account_deposit_fee_transferred_aggregate
We do need in some way to get this from Stripe.
Stripe puts in the fee payment as an adjustment (event).
Currently chargebacks (might) come in as adjustments.

We ignore SOME of the Stripe events that we receive.
So they do have a filter.

Stripe told K that we would start to be charged for these events.

Does 'succeeded' really mean succeeded, or does it mean initiated and
we may see a failed too.

She got the email in Nov and it said they would start taking the cash in Dec.
We are charged by number of payouts.
They are taking the cash out.
(Wee see it because it comes out of our Stripe cash account)

K does not see anything corresponding to atty account 
deposit succeeded (initiated) or failed.
Devs are looking to see how it is generated.

From Matt P:
https://stripe.com/docs/api#event_object
These are the events that we process that come directly from Stripe:
    'account.updated'
    'customer.source.updated'
    'charge.captured'
    'charge.dispute.created'
    'charge.dispute.closed'
    'charge.failed'
    'charge.refunded'
    'charge.succeeded'
    'charge.updated'
    'transfer.created'
    'transfer.failed'
    'transfer.paid'
    'transfer.reversed'
    'transfer.updated'

----
UAT for productionalized table + view prsn.financial_services_event_detail

SELECT
   IFNULL(new.event_id, old.event_id) AS joint_event_id
  ,IFNULL(new.event_datetime, old.event_dttm) AS joint_event_dttm
  ,IFNULL(new.advice_session_id, old.advice_session_id) AS joint_advice_session_id
  ,MAX(CASE WHEN new.event_date = old.event_date THEN '' ELSE 'Error' END) AS chk_event_date
  ,MAX(CASE WHEN new.event_datetime = old.event_dttm THEN '' ELSE 'Error' END) AS chk_event_dttm
  ,MAX(CASE WHEN IFNULL(new.advice_session_id, 0) = IFNULL(old.advice_session_id, 0) THEN '' ELSE 'Error' END) AS chk_advice_session_id
  ,MAX(CASE WHEN IFNULL(new.advice_session_id_hacked, 0) = IFNULL(old.advice_session_id_hacked, 0) THEN '' ELSE 'Error' END) AS chk_advice_session_id_hacked
  ,MAX(CASE WHEN IFNULL(new.event_category, '') = IFNULL(old.event_category, '') THEN '' ELSE 'Error' END) AS chk_event_category
  ,MAX(CASE WHEN IFNULL(new.event_type_raw, '') = IFNULL(old.event_type_raw, '') THEN '' ELSE 'Error' END) AS chk_event_type_raw
  ,MAX(CASE WHEN IFNULL(new.package_category, '') = IFNULL(old.package_category, '') THEN '' ELSE 'Error' END) AS chk_package_category
  ,MAX(CASE WHEN IFNULL(new.specialty_id, 0) = IFNULL(old.specialty_id, 0) THEN '' ELSE 'Error' END) AS chk_specialty_id
  ,MAX(CASE WHEN IFNULL(new.financial_event_type_id, 0) = IFNULL(old.financial_event_type_id, 0) THEN '' ELSE 'Error' END) AS chk_financial_event_type_id
  ,MAX(CASE WHEN IFNULL(new.offer_id, 0) = IFNULL(old.offer_id, 0) THEN '' ELSE 'Error' END) AS chk_offer_id
  ,MAX(CASE WHEN IFNULL(new.promotion_id, 0) = IFNULL(old.promotion_id, 0) THEN '' ELSE 'Error' END) AS chk_promotion_id
  ,MAX(CASE WHEN IFNULL(new.is_discounted, '') = IFNULL(old.is_discounted, '') THEN '' ELSE 'Error' END) AS chk_is_discounted
  ,MAX(CASE WHEN IFNULL(new.is_professional_selected_at_purchase, '') = IFNULL(old.is_professional_selected_at_purchase, '') THEN '' ELSE 'Error' END) AS chk_is_professional_selected_at_purchase
  ,MAX(CASE WHEN IFNULL(new.professional_id, 0) = IFNULL(old.professional_id, 0) THEN '' ELSE 'Error' END) AS chk_professional_id
  ,MAX(CASE WHEN IFNULL(new.financial_transaction_id, '') = IFNULL(old.financial_transaction_id, '') THEN '' ELSE 'Error' END) AS chk_financial_transaction_id
  ,MAX(CASE WHEN IFNULL(new.is_aggregate_event, '') = IFNULL(old.is_aggregate_event, '') THEN '' ELSE 'Error' END) AS chk_is_aggregate_event
  ,MAX(CASE WHEN IFNULL(new.attempted_transactions, 0) = IFNULL(old.attempted_transactions, 0) THEN '' ELSE 'Error' END) AS chk_attempted_transactions
  ,MAX(CASE WHEN IFNULL(new.attempted_retail_price, 0) = IFNULL(old.attempted_retail_price, 0) THEN '' ELSE 'Error' END) AS chk_attempted_retail_price
  ,MAX(CASE WHEN IFNULL(new.attempted_purchase_price, 0) = IFNULL(old.attempted_purchase_price, 0) THEN '' ELSE 'Error' END) AS chk_attempted_purchase_price
  ,MAX(CASE WHEN IFNULL(new.attempted_discount, 0) = IFNULL(old.attempted_discount, 0) THEN '' ELSE 'Error' END) AS chk_attempted_discount
  ,MAX(CASE WHEN IFNULL(new.attempted_marketing_fee, 0) = IFNULL(old.attempted_marketing_fee, 0) THEN '' ELSE 'Error' END) AS chk_attempted_marketing_fee
  ,MAX(CASE WHEN IFNULL(new.attempted_effective_marketing_fee, 0) = IFNULL(old.attempted_effective_marketing_fee, 0) THEN '' ELSE 'Error' END) AS chk_attempted_effective_marketing_fee
  ,MAX(CASE WHEN IFNULL(new.successful_transactions, 0) = IFNULL(old.successful_transactions, 0) THEN '' ELSE 'Error' END) AS chk_successful_transactions
  ,MAX(CASE WHEN IFNULL(new.successful_retail_price, 0) = IFNULL(old.successful_retail_price, 0) THEN '' ELSE 'Error' END) AS chk_successful_retail_price
  ,MAX(CASE WHEN IFNULL(new.successful_purchase_price, 0) = IFNULL(old.successful_purchase_price, 0) THEN '' ELSE 'Error' END) AS chk_successful_purchase_price
  ,MAX(CASE WHEN IFNULL(new.successful_discount, 0) = IFNULL(old.successful_discount, 0) THEN '' ELSE 'Error' END) AS chk_successful_discount
  ,MAX(CASE WHEN IFNULL(new.successful_marketing_fee, 0) = IFNULL(old.successful_marketing_fee, 0) THEN '' ELSE 'Error' END) AS chk_successful_marketing_fee
  ,MAX(CASE WHEN IFNULL(new.successful_effective_marketing_fee, 0) = IFNULL(old.successful_effective_marketing_fee, 0) THEN '' ELSE 'Error' END) AS chk_successful_effective_marketing_fee
  ,MAX(CASE WHEN IFNULL(new.net_transactions, 0) = IFNULL(old.net_transactions, 0) THEN '' ELSE 'Error' END) AS chk_net_transactions
  ,MAX(CASE WHEN IFNULL(new.net_retail_price, 0) = IFNULL(old.net_retail_price, 0) THEN '' ELSE 'Error' END) AS chk_net_retail_price
  ,MAX(CASE WHEN IFNULL(new.net_purchase_price, 0) = IFNULL(old.net_purchase_price, 0) THEN '' ELSE 'Error' END) AS chk_net_purchase_price
  ,MAX(CASE WHEN IFNULL(new.net_discount, 0) = IFNULL(old.net_discount, 0) THEN '' ELSE 'Error' END) AS chk_net_discount
  ,MAX(CASE WHEN IFNULL(new.net_marketing_fee, 0) = IFNULL(old.net_marketing_fee, 0) THEN '' ELSE 'Error' END) AS chk_net_marketing_fee
  ,MAX(CASE WHEN IFNULL(new.net_effective_marketing_fee, 0) = IFNULL(old.net_effective_marketing_fee, 0) THEN '' ELSE 'Error' END) AS chk_net_effective_marketing_fee
  ,MAX(CASE WHEN IFNULL(new.refunds, 0) = IFNULL(old.refunds, 0) THEN '' ELSE 'Error' END) AS chk_refunds
  ,MAX(CASE WHEN IFNULL(new.voids, 0) = IFNULL(old.voids, 0) THEN '' ELSE 'Error' END) AS chk_voids
  ,MAX(CASE WHEN IFNULL(new.cash, 0) = IFNULL(old.cash, 0) THEN '' ELSE 'Error' END) AS chk_cash
  ,MAX(CASE WHEN IFNULL(new.cos, 0) = IFNULL(old.cos, 0) THEN '' ELSE 'Error' END) AS chk_cos
  ,MAX(CASE WHEN IFNULL(new.contra_cos, 0) = IFNULL(old.contra_cos, 0) THEN '' ELSE 'Error' END) AS chk_contra_cos
  ,MAX(CASE WHEN IFNULL(new.earned_revenue, 0) = IFNULL(old.earned_revenue, 0) THEN '' ELSE 'Error' END) AS chk_earned_revenue
  ,MAX(CASE WHEN IFNULL(new.contra_revenue, 0) = IFNULL(old.contra_revenue, 0) THEN '' ELSE 'Error' END) AS chk_contra_revenue
  ,MAX(CASE WHEN IFNULL(new.accounts_receivable, 0) = IFNULL(old.accounts_receivable, 0) THEN '' ELSE 'Error' END) AS chk_accounts_receivable
  ,MAX(CASE WHEN IFNULL(new.accounts_receivable_for_session, 0) = IFNULL(old.accounts_receivable_for_session, 0) THEN '' ELSE 'Error' END) AS chk_accounts_receivable_for_session
  ,MAX(CASE WHEN IFNULL(new.chargeback, 0) = IFNULL(old.chargeback, 0) THEN '' ELSE 'Error' END) AS chk_chargeback
  ,MAX(CASE WHEN IFNULL(new.chargeback_fee, 0) = IFNULL(old.chargeback_fee, 0) THEN '' ELSE 'Error' END) AS chk_chargeback_fee
  ,MAX(CASE WHEN IFNULL(new.processor_fee, 0) = IFNULL(old.processor_fee, 0) THEN '' ELSE 'Error' END) AS chk_processor_fee
  ,MAX(CASE WHEN IFNULL(new.accrued_fee, 0) = IFNULL(old.accrued_fee, 0) THEN '' ELSE 'Error' END) AS chk_accrued_fee
  ,MAX(CASE WHEN IFNULL(new.trust_account_balance, 0) = IFNULL(old.trust_account_balance, 0) THEN '' ELSE 'Error' END) AS chk_trust_account_balance
  ,MAX(CASE WHEN IFNULL(new.failed_payment_amount, 0) = IFNULL(old.failed_payment_amount, 0) THEN '' ELSE 'Error' END) AS chk_failed_payment_amount
  ,MAX(CASE WHEN IFNULL(new.consumer_charge_amount, 0) = IFNULL(old.consumer_charge_amount, 0) THEN '' ELSE 'Error' END) AS chk_consumer_charge_amount
  ,MAX(CASE WHEN IFNULL(new.marketing_fee, 0) = IFNULL(old.marketing_fee, 0) THEN '' ELSE 'Error' END) AS chk_marketing_fee
  ,MAX(CASE WHEN IFNULL(new.transaction_amount_raw, 0) = IFNULL(old.transaction_amount_raw, 0) THEN '' ELSE 'Error' END) AS chk_transaction_amount_raw
  ,MAX(CASE WHEN IFNULL(new.processor_fee_raw, 0) = IFNULL(old.processor_fee_raw, 0) THEN '' ELSE 'Error' END) AS chk_processor_fee_raw
  ,MAX(CASE WHEN IFNULL(new.discount_amount_raw, 0) = IFNULL(old.discount_amount_raw, 0) THEN '' ELSE 'Error' END) AS chk_discount_amount_raw
  ,MAX(CASE WHEN IFNULL(new.retail_price_raw, 0) = IFNULL(old.retail_price_raw, 0) THEN '' ELSE 'Error' END) AS chk_retail_price_raw
  ,MAX(CASE WHEN IFNULL(new.marketing_fee_raw, 0) = IFNULL(old.marketing_fee_raw, 0) THEN '' ELSE 'Error' END) AS chk_marketing_fee_raw
  ,MAX(CASE WHEN IFNULL(new.contra_revenue_raw, 0) = IFNULL(old.contra_revenue_raw, 0) THEN '' ELSE 'Error' END) AS chk_contra_revenue_raw
  ,MAX(CASE WHEN IFNULL(new.purchase_transaction_amount, 0) = IFNULL(old.purch_transaction_amount, 0) THEN '' ELSE 'Error' END) AS chk_purch_transaction_amount
  ,MAX(CASE WHEN IFNULL(new.purchase_discount_amount, 0) = IFNULL(old.purch_discount_amount, 0) THEN '' ELSE 'Error' END) AS chk_purch_discount_amount
  ,MAX(CASE WHEN IFNULL(new.check_purchase_not_found, '') = IFNULL(old.chk_purchase_not_found, '') THEN '' ELSE 'Error' END) AS chk_chk_purchase_not_found
  ,MAX(CASE WHEN IFNULL(new.events, 0) = IFNULL(old.events, 0) THEN '' ELSE 'Error' END) AS chk_events
  ,MAX(CASE WHEN IFNULL(new.revenue, 0) = IFNULL(old.revenue, 0) THEN '' ELSE 'Error' END) AS chk_revenue
  ,MAX(CASE WHEN IFNULL(new.gross_margin, 0) = IFNULL(old.gross_margin, 0) THEN '' ELSE 'Error' END) AS chk_gross_margin
FROM
             prsn.services_event_detail new
  FULL OUTER JOIN tmp_data_dm.coe_services_event_detail old
          ON new.event_id = old.event_id
GROUP BY 1,2,3

SELECT
   IFNULL(new.event_id, old.event_id) AS joint_event_id
  ,IFNULL(new.event_datetime, old.event_dttm) AS joint_event_dttm
  ,IFNULL(new.advice_session_id, old.advice_session_id) AS joint_advice_session_id
  ,old.*
  ,new.*
  ,CASE WHEN IFNULL(new.cash, 0) = IFNULL(old.cash, 0) THEN '' ELSE 'Error' END AS chk_cash
  ,CASE WHEN IFNULL(new.processor_fee, 0) = IFNULL(old.processor_fee, 0) THEN '' ELSE 'Error' END AS chk_processor_fee
  ,CASE WHEN IFNULL(new.processor_fee_raw, 0) = IFNULL(old.processor_fee_raw, 0) THEN '' ELSE 'Error' END AS chk_processor_fee_raw
  ,CASE WHEN IFNULL(new.gross_margin, 0) = IFNULL(old.gross_margin, 0) THEN '' ELSE 'Error' END AS chk_gross_margin
FROM
             prsn.services_event_detail new
  FULL OUTER JOIN tmp_data_dm.coe_services_event_detail old
          ON new.event_id = old.event_id
WHERE -- IFNULL(new.event_date, old.event_date) >= '2017-01-20'
AND CONCAT(
  CASE WHEN IFNULL(new.cash, 0) = IFNULL(old.cash, 0) THEN '' ELSE 'Error' END,
  CASE WHEN IFNULL(new.processor_fee, 0) = IFNULL(old.processor_fee, 0) THEN '' ELSE 'Error' END,
  CASE WHEN IFNULL(new.processor_fee_raw, 0) = IFNULL(old.processor_fee_raw, 0) THEN '' ELSE 'Error' END,
  CASE WHEN IFNULL(new.gross_margin, 0) = IFNULL(old.gross_margin, 0) THEN '' ELSE 'Error' END
) <> ''

OK it''s fine.

(Weirdly, a few rows showed inequalities, even though on inspection
the values look the same and the data types are consistent.  Not
worried about it.)
