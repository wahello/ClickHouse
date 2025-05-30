-- Tags: no-parallel-replicas
-- no-parallel-replicas: optimize_read_in_order=0 leads to "Replica 1 decided to read in Default mode, not in WithOrder. This is a bug: While executing Remote. (LOGICAL_ERROR)"

select '-- enable distinct in order optimization';
set optimize_distinct_in_order=1;
select '-- create table with only primary key columns';
drop table if exists distinct_in_order sync;
create table distinct_in_order (a int) engine=MergeTree() order by a settings index_granularity=10;
select '-- the same values in every chunk, pre-distinct should skip entire chunks with the same key as previous one';
insert into distinct_in_order (a) select * from zeros(10);
insert into distinct_in_order (a) select * from zeros(10); -- this entire chunk should be skipped in pre-distinct
select distinct * from distinct_in_order settings max_block_size=10, max_threads=1;

select '-- create table with only primary key columns';
select '-- pre-distinct should skip part of chunk since it contains values from previous one';
drop table if exists distinct_in_order sync;
create table distinct_in_order (a int) engine=MergeTree() order by a settings index_granularity=10;
insert into distinct_in_order (a) select * from zeros(10);
insert into distinct_in_order select * from numbers(10); -- first row (0) from this chunk should be skipped in pre-distinct
select distinct a from distinct_in_order settings max_block_size=10, max_threads=1;

select '-- create table with not only primary key columns';
drop table if exists distinct_in_order sync;
create table distinct_in_order (a int, b int, c int) engine=MergeTree() order by (a, b) SETTINGS index_granularity = 8192, index_granularity_bytes = '10Mi';
insert into distinct_in_order select number % number, number % 5, number % 10 from numbers(1,1000000);

select '-- distinct with primary key prefix only';
select distinct a from distinct_in_order;
select '-- distinct with primary key prefix only, order by sorted column';
select distinct a from distinct_in_order order by a;
select '-- distinct with primary key prefix only, order by sorted column desc';
select distinct a from distinct_in_order order by a desc;

select '-- distinct with full key, order by sorted column';
select distinct a,b from distinct_in_order order by b;
select '-- distinct with full key, order by sorted column desc';
select distinct a,b from distinct_in_order order by b desc;

select '-- distinct with key prefix and non-sorted column, order by non-sorted';
select distinct a,c from distinct_in_order order by c;
select '-- distinct with key prefix and non-sorted column, order by non-sorted desc';
select distinct a,c from distinct_in_order order by c desc;

select '-- distinct with non-key prefix and non-sorted column, order by non-sorted';
select distinct b,c from distinct_in_order order by c;
select '-- distinct with non-key prefix and non-sorted column, order by non-sorted desc';
select distinct b,c from distinct_in_order order by c desc;

select '-- distinct with constants columns';
-- { echoOn }
select distinct 1 as x, 2 as y from distinct_in_order;
select distinct 1 as x, 2 as y from distinct_in_order order by x;
select distinct 1 as x, 2 as y from distinct_in_order order by x, y;
select a, x from (select distinct a, 1 as x from distinct_in_order order by x) order by a;
select distinct a, 1 as x, 2 as y from distinct_in_order order by a;
select a, b, x, y from(select distinct a, b, 1 as x, 2 as y from distinct_in_order order by a) order by a, b;
select distinct x, y from (select 1 as x, 2 as y from distinct_in_order order by x) order by y;
select distinct a, b, x, y from (select a, b, 1 as x, 2 as y from distinct_in_order order by a) order by a, b;
-- { echoOff }

drop table if exists distinct_in_order sync;

select '-- check that distinct in order returns the same result as ordinary distinct';
drop table if exists distinct_cardinality_low sync;
CREATE TABLE distinct_cardinality_low (low UInt64, medium UInt64, high UInt64) ENGINE MergeTree() ORDER BY (low, medium) SETTINGS index_granularity = 8192, index_granularity_bytes = '10Mi';
INSERT INTO distinct_cardinality_low SELECT number % 1e1, number % 1e2, number % 1e3 FROM numbers_mt(1e4);

drop table if exists distinct_in_order sync;
drop table if exists ordinary_distinct sync;

select '-- check that distinct in order WITH order by returns the same result as ordinary distinct';
create table distinct_in_order (low UInt64, medium UInt64, high UInt64) engine=MergeTree() order by (low, medium) SETTINGS index_granularity = 8192, index_granularity_bytes = '10Mi';
insert into distinct_in_order select distinct * from distinct_cardinality_low order by high settings optimize_distinct_in_order=1;
create table ordinary_distinct (low UInt64, medium UInt64, high UInt64) engine=MergeTree() order by (low, medium) SETTINGS index_granularity = 8192, index_granularity_bytes = '10Mi';
insert into ordinary_distinct select distinct * from distinct_cardinality_low order by high settings optimize_distinct_in_order=0;
select count() as diff from (select distinct * from distinct_in_order except select * from ordinary_distinct);

drop table if exists distinct_in_order sync;
drop table if exists ordinary_distinct sync;

select '-- check that distinct in order WITHOUT order by returns the same result as ordinary distinct';
create table distinct_in_order (low UInt64, medium UInt64, high UInt64) engine=MergeTree() order by (low, medium) SETTINGS index_granularity = 8192, index_granularity_bytes = '10Mi';
insert into distinct_in_order select distinct * from distinct_cardinality_low settings optimize_distinct_in_order=1;
create table ordinary_distinct (low UInt64, medium UInt64, high UInt64) engine=MergeTree() order by (low, medium) SETTINGS index_granularity = 8192, index_granularity_bytes = '10Mi';
insert into ordinary_distinct select distinct * from distinct_cardinality_low settings optimize_distinct_in_order=0;
select count() as diff from (select distinct * from distinct_in_order except select * from ordinary_distinct);

drop table if exists distinct_in_order;
drop table if exists ordinary_distinct;

select '-- check that distinct in order WITHOUT order by and WITH filter returns the same result as ordinary distinct';
create table distinct_in_order (low UInt64, medium UInt64, high UInt64) engine=MergeTree() order by (low, medium) SETTINGS index_granularity = 8192, index_granularity_bytes = '10Mi';
insert into distinct_in_order select distinct * from distinct_cardinality_low where low > 0 settings optimize_distinct_in_order=1;
create table ordinary_distinct (low UInt64, medium UInt64, high UInt64) engine=MergeTree() order by (low, medium) SETTINGS index_granularity = 8192, index_granularity_bytes = '10Mi';
insert into ordinary_distinct select distinct * from distinct_cardinality_low where low > 0 settings optimize_distinct_in_order=0;
select count() as diff from (select distinct * from distinct_in_order except select * from ordinary_distinct);

drop table if exists distinct_in_order;
drop table if exists ordinary_distinct;
drop table if exists distinct_cardinality_low;

-- bug 42185
drop table if exists sorting_key_empty_tuple;
drop table if exists sorting_key_contain_function;

select '-- bug 42185, distinct in order and empty sort description';
select '-- distinct in order, sorting key tuple()';
create table sorting_key_empty_tuple (a int, b int) engine=MergeTree() order by tuple() SETTINGS index_granularity = 8192, index_granularity_bytes = '10Mi';
insert into sorting_key_empty_tuple select number % 2, number % 5 from numbers(1,10);
select distinct a from sorting_key_empty_tuple;

select '-- distinct in order, sorting key contains function';
create table sorting_key_contain_function (datetime DateTime, a int) engine=MergeTree() order by (toDate(datetime)) SETTINGS index_granularity = 8192, index_granularity_bytes = '10Mi';
insert into sorting_key_contain_function values ('2000-01-01', 1);
insert into sorting_key_contain_function values ('2000-01-01', 2);
select distinct datetime from sorting_key_contain_function;
select distinct toDate(datetime) from sorting_key_contain_function;

drop table sorting_key_empty_tuple;
drop table sorting_key_contain_function;
