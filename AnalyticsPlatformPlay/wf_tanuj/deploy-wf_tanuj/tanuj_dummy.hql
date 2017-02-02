use ${aaDatabase};
drop table tanuj_dummy;
CREATE EXTERNAL TABLE IF NOT EXISTS tanuj_dummy
(
professional_id int
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '|'
LINES TERMINATED BY '\n'
STORED AS INPUTFORMAT
'org.apache.hadoop.mapred.TextInputFormat'
OUTPUTFORMAT
'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat';

insert into table tanuj_dummy values (1);