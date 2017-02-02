set hive.exec.compress.intermediate=true;
set hive.exec.compress.output=true;
set mapred.output.compression.type=BLOCK;
set mapred.output.compression.codec=org.apache.hadoop.io.compress.SnappyCodec;
set hive.parquet.compression=SNAPPY;

set hive.exec.dynamic.partition=true;
set hive.exec.dynamic.partition.mode=nonstrict;
set hive.exec.max.dynamic.partitions = 10000;
set hive.exec.max.dynamic.partitions.pernode=10000;
set hive.support.quoted.identifiers=none;

use ${dmDatabase};

CREATE EXTERNAL TABLE IF NOT EXISTS customer_professional_purchase_map
(
customer_id int,
professional_id int,
last_purchased_date string,
last_billed_date string,
last_cancelled_date string,
etl_load_date string
) partitioned by(yearmonth int)
STORED as PARQUET;

INSERT OVERWRITE TABLE customer_professional_purchase_map partition (yearmonth)
select
customer_id,
professional_id,
max(order_line_purchase_date) as last_purchase_date,
max(order_line_begin_date) as last_billed_date,
max(order_line_cancelled_date) as last_cancelled_date,
max(cast(date_sub(FROM_UNIXTIME(UNIX_TIMESTAMP(),'yyyy-MM-dd'),1) as string)) as etl_load_date,
max(concat(year(date_sub(from_unixtime(unix_timestamp(), 'yyyy-MM-dd'),1)),lpad(month(date_sub(from_unixtime(unix_timestamp(), 'yyyy-MM-dd'),1)),2,0))) as yearmonth
from order_line_accumulation_fact
where yearmonth <= concat(year(date_sub(from_unixtime(unix_timestamp(), 'yyyy-MM-dd'),1)),lpad(month(date_sub(from_unixtime(unix_timestamp(), 'yyyy-MM-dd'),1)),2,0))
group by customer_id, professional_id;

