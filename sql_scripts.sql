create or replace function issue_type (
  kind text[], priority text[], other text[]
)
returns text
language plpgsql
as $f$
BEGIN
CASE WHEN 'release-blocker' = ANY(other) or 'release-blocker' = ANY(priority) THEN
  RETURN 'release-blocker';
WHEN 'critical-urgent' = ANY(priority) THEN
  RETURN 'critical';
WHEN 'important-soon' = ANY(priority) THEN
  RETURN 'important';
WHEN 'failing-test' = ANY(priority) or 'failing-test' = ANY(kind) THEN
  RETURN 'failing-test';
WHEN 'important-longterm' = ANY(priority) THEN
  RETURN 'longterm';
WHEN priority IS NULL OR 'milestone/incomplete-labels' = ANY(other) THEN
  RETURN 'incomplete';
WHEN priority IS NOT NULL THEN
  RETURN 'other';
ELSE
  RETURN 'unknown';
END CASE;
END;
$f$;

CREATE FUNCTION s2a ( text )
RETURNS text[]
LANGUAGE sql
AS $f$
SELECT string_to_array($1, ',');
$f$;

SELECT *
FROM crosstab( $q$ select sigs.sig, issue_type(kind, priority, other), count(*)
                    from issues join sigs on sigs.sig = ANY(issues.sig)
                    where issue_type(kind, priority, other) <> 'unknown'
                    and ts = '2018-02-26'
                    group by 1,2 order by 1,2 $q$,
              $$ SELECT issue_type from issue_types where issue_type <> 'unknown'
              order by listing $$)
     AS final_result(sig text, "release-blocker" int, critical int, important int, "failing-test" int, longterm int, other int, "no-priority" int);

     SELECT *
     FROM crosstab( $q$ select sigs.sig, kinds.kind, count(*) from issues
                        join sigs on sigs.sig = ANY(issues.sig)
                        join kinds on ( kinds.kind = ANY(issues.kind)
                          OR ( kinds.kind = 'NO-KIND' and issues.kind IS NULL ) )
                        where ts = '2018-02-26'
                        group by 1,2 order by 1,2 $q$,
                   $$ SELECT kind from kinds order by kind $$)
          AS final_result(sig text, bug int, cleanup int, design int, documentation int, enhancement int, feature int, flake int, "no-kind" int, "technical-debt" int);


create table x_kind (
  kind text,
  bug int,
  cleanup int,
  design int,
  documentation int,
  enhancement int,
  feature int,
  "technical-debt" int,
  "no-kind" int
);

insert into x_kind values
( 'bug',          1, 0, 0, 0, 0, 0, 0, 0 ),
( 'cleanup',      0, 1, 0, 0, 0, 0, 0, 0 ),
( 'design',       0, 0, 1, 0, 0, 0, 0, 0 ),
( 'documentation',0, 0, 0, 1, 0, 0, 0, 0 ),
( 'enhancement',  0, 0, 0, 0, 1, 0, 0, 0 ),
( 'feature',      0, 0, 0, 0, 0, 1, 0, 0 ),
( 'technical-debt',0, 0, 0, 0, 0, 0, 1, 0 ),
( NULL,           0, 0, 0, 0, 0, 0, 0, 1 );



CREATE OR REPLACE function sig_kind (
  INOUT ts timestamptz,
  OUT bug INT,
  OUT cleanup INT,
  OUT design INT,
  OUT documentation INT,
  OUT enhancement INT,
  OUT feature INT,
  OUT technical-debt INT
)
RETURNS setof sig_kind
LANGUAGE plpgsql
AS $f$




truncate issues_raw;

\copy issues_raw from issues.csv with csv

insert into issues select
  '2018-02-26',
  url,
  title,
  s2a(kind),
  s2a(sig),
  s2a(priority),
  s2a(area),
  s2a(status),
  s2a(other)
from issues_raw;

insert into sigs
select distinct (unnest(issues.sig)) as sig
FROM issues
EXCEPT
select sig from sigs;

insert into kinds
select distinct (unnest(issues.kind)) as kind
FROM issues
EXCEPT select kind from kinds;

insert into priorities
select distinct (unnest(issues.priority)) as priority
FROM issues
except select priority from priorities;

insert into status
select distinct (unnest(issues.status)) as status
FROM issues
except select status from status;

insert into areas
select distinct (unnest(issues.area)) as area
FROM issues
except select area from areas;

select sigs.sig, count(*)
from issues join sigs on sigs.sig = ANY (issues.sig)
where ts = '2018-02-26'
group by sigs.sig
order by sigs.sig;

select status.status, count(*)
from issues join status on status.status = ANY (issues.status)
where ts = '2018-02-12'
group by status.status
order by status.status;

select issue_type(kind, priority, other), count(*)
from issues
where ts = '2018-02-26'
group by 1 order by 1;

select kinds.kind, count(*)
from issues join kinds on kinds.kind = ANY (issues.kind)
where ts = '2018-02-12'
group by 1
UNION ALL
select 'NO-KIND', count(*)
from issues
where ts = '2018-02-12'
and kind is null
group by 1
order by 1;


create table issue_types ( issue_type text, listing int);

insert into issue_types values
  ('release-blocker', 1),
  ('critical', 2),
  ('important', 3),
  ('longterm', 4),
  ('other', 5),
  ('incomplete', 6);


select distinct(unnest(other)) from issues;

create table incomplete as
select url, title, array_to_string(kind,',') as kind,
  array_to_string(priority,',') as priority,
  array_to_string(sig, ',') as sig
from issues
where ( kind is null or priority is null or sig is null)
  and ts = '2018-02-19'
order by sig, title;

create function a2s ( text[] )
returns text
language sql
as $$
SELECT array_to_string($1, ',');
$$;

create table issue_dump as
select url,
  '[' || title || '](' || url || ')' as link,
  a2s(sig) as sigs,
  a2s(kind) as kind,
  a2s(priority) as priority,
  case when 'approved-for-milestone' = ANY (other) or 'approved-for-milestone' = ANY (status) then
   'approved'
  else
   'not approved'
  end as is_approved
from issues
where ts = '2018-02-20'
order by url;
