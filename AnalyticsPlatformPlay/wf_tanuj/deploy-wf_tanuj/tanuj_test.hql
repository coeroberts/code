use ${aaDatabase};
drop table tanuj_ad;
create table tanuj_ad as
select * from ${dmDatabase}.ad_dim;