

/* ###################################################################################################### */
\ir '../intershop/db/010-trm.sql'
\ir './set-signal-color.sql'
-- \ir './test-begin.sql'
-- \pset pager on
\timing off
\set filename 200-setup.sql
-- -- \set ECHO queries

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 1 }———:reset
drop schema if exists X cascade; create schema X;


-- =========================================================================================================
--
-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 2 }———:reset
create domain X.positive_integer  as integer  check ( value > 0                   );
create domain X.nonempty_text     as text     check ( value ~ '.+'                );
create domain X.component_name    as text     check ( value ~ '^°.+'              );
create domain X.verb_name         as text     check ( value ~ '^\^.+'             );
create domain X.aspect_name       as text     check ( value ~ '^:.+'              );
create domain X.topic_name        as text     check ( value ~ '^°.+'              ); -- i.e., component
create domain X.focus_name        as text     check ( value ~ '^[:^].+'           ); -- i.e., verb or aspect
create domain X.atom_name         as text     check ( value ~ '^[°^:].+'          ); -- i.e., component, verb, or aspect
create domain X.sigil             as text     check ( value ~ '^[°^:]$'           );
create domain X.sigilcombo        as text     check ( value ~ '^([°^:])|(°[^:])$' );


-- =========================================================================================================
--
-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 6 }———:reset
create table X.kinds (
    kind      X.nonempty_text   not null  unique,
    sigil     X.sigilcombo      not null  unique,
    comment   X.nonempty_text,
  primary key ( kind ) );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 6 }———:reset
-- ### TAINT add check that sigil matches kind
create table X.atoms (
    atom      X.atom_name       not null  unique,
    kind      text              not null  references X.kinds ( kind ),
    comment   X.nonempty_text,
  primary key ( atom ) );


-- =========================================================================================================
--
-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 6 }———:reset
-- ### TAINT add constraint to check that sigils, kinds match
-- ### TAINT add constraint to check that exactly one state has dflt = true
-- ### TAINT add constraint to check that all events have dflt = false (or null)
create table X.pairs (
    topic       X.topic_name      not null  references X.atoms ( atom ),
    focus       X.focus_name      not null  references X.atoms ( atom ),
    predicate   jsonb             not null  default 'true'::jsonb,
    kind        text              not null  references X.kinds ( kind ),
    dflt        boolean           not null  default false,
    comment     X.nonempty_text,
  primary key ( topic, focus )
  -- constraint on ( topic ) check
);

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 9 }———:reset
create table X.transitions (
    id                bigint generated always as identity primary key,
    termid            bigint        not null,
    topic             X.topic_name  not null,
    focus             X.focus_name  not null,
    predicate         jsonb         not null  default 'true'::jsonb,
    action            bigint                  references X.transitions ( id ),
  unique ( id, termid, topic, focus, predicate, action ),
  foreign key ( topic, focus ) references X.pairs );


-- =========================================================================================================
--
-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 10 }———:reset
-- TAINT add constraint to ensure only events, not other pair kinds, are entered
-- OTOH should be clear from domains used for names
create table X.eventlog (
    id          bigint generated always as identity primary key,
    t           timestamp with time zone  not null default now(),
    topic       X.component_name          not null,
    focus       X.verb_name               not null,
  foreign key ( topic, focus ) references X.pairs ( topic, focus ) );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 11 }———:reset
create table X.statelog (
    id          bigint generated always as identity primary key,
    t           timestamp with time zone  not null default now(),
    topic       X.component_name          not null,
    focus       X.aspect_name             not null,
  foreign key ( topic, focus ) references X.pairs ( topic, focus ) );


-- =========================================================================================================
-- INITIAL DATA
-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 6 }———:reset
insert into X.kinds ( kind, sigil, comment ) values
  ( 'component',  '°',  'models interacting parts of the system'            ),
  ( 'verb',       '^',  'models what parts of the system can do'            ),
  ( 'aspect',     ':',  'models malleable phases of components'             ),
  ( 'event',      '°^', 'models ex- and internal actuations of the system'  ),
  ( 'state',      '°:', 'models static and dynamic postures of the system'  );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 6 }———:reset
insert into X.atoms ( atom, kind, comment ) values
  ( '°FSM',       'component',  'pseudo-component for the automaton itself' ),
  ( ':IDLE',      'aspect',     'when the automaton is not in use'          ),
  ( ':ACTIVE',    'aspect',     'when the automaton is in use'              ),
  ( '^RESET',     'verb',       'put the automaton in its initial state'    );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 6 }———:reset
insert into X.pairs ( topic, focus, kind, dflt, comment ) values
  ( '°FSM',     ':IDLE',      'state',  true,    'the automaton is not in use'                ),
  ( '°FSM',     ':ACTIVE',    'state',  false,   'the automaton is in use'                    ),
  ( '°FSM',     '^RESET',     'event',  false,   'reset the automaton to its initial state'   );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 10 }———:reset
insert into X.transitions ( termid, topic, focus, action ) values
  ( 1, '°FSM',  ':IDLE',    2     ),
  ( 1, '°FSM',  '^RESET',   2     ),
  ( 2, '°FSM',  ':ACTIVE',  null  );


/* ###################################################################################################### */
\echo :red ———{ :filename 13 }———:reset
\quit

/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */
/* ###################################################################################################### */

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 2 }———:reset
create function X.component_name( ¶x text )
  returns boolean immutable strict parallel safe language sql as $$
  select ¶x like '°?%'; $$;
create table X.check_violations (
  value row );

create function X.insert_to_X_components() returns trigger language plpgsql as $$
  begin
  end; $$;

create trigger check_insert_to_X_components
  instead insert on X.components
  for each row execute function X.insert_to_X_components();

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 2 }———:reset
create table X.components (
  component   text unique not null primary key check ( X.component_name( component ) ),
  comment     text );



/* ###################################################################################################### */
/* ###################################################################################################### */

-- ---------------------------------------------------------------------------------------------------------
drop schema if exists KWIC cascade; create schema KWIC;


/* ###################################################################################################### */

-- =========================================================================================================
-- ROLES
-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 1 }———:reset
create table KWIC.roles (
  role          text  unique  not null primary key,
  comment       text          not null );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 2 }———:reset
insert into KWIC.roles values
  ( 'G1', 'Guides: strokeclass (initial stroke)'          ),
  ( 'G2', 'Guides: shapeclass (up to 2 initial strokes)'  ),
  ( 'GF', 'Guides: factor'                                ),
  ( 'GR', 'Guides: crossref'                              ),
  ( 'OJ', '親字, head character, main entry'              );


-- =========================================================================================================
-- THE POOL
-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 3 }———:reset
create table KWIC.the_pool (
    iclabel         text    not null,
    role            text    not null references KWIC.roles ( role ),
    fformula_nr     integer not null,
    glyph           text    not null,
    components      text[]  not null,
    sortcodes       text[]  not null );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 4 }———:reset
insert into KWIC.the_pool ( select distinct
    m.iclabel                 as iclabel,
    'OJ'                      as role,
    m.fformula_nr             as fformula_nr,
    m.glyph                   as glyph,
    m.components              as components,
    m.sortcodes               as sortcodes
  from FFORMULAS.fformulas as m
  limit case when ¶( 'mojikura/debugging' )::boolean
    then ¶( 'mojikura/KWIC/debug/pool/limit' )::integer
    else null end );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 5 }———:reset
insert into KWIC.the_pool ( select distinct
    m.iclabel                 as iclabel,
    'G1'                      as role,
    1                         as fformula_nr,
    m.glyph                   as glyph,
    array[ m.glyph ]          as components,
    array[ m.sortcode ]       as sortcodes
  from FACTORS.factors as m
  where true
    and ( m.strokecount = 1 ) );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 6 }———:reset
insert into KWIC.the_pool ( select distinct
    m.iclabel                 as iclabel,
    'G2'                      as role,
    1                         as fformula_nr,
    m.glyph                   as glyph,
    array[ m.glyph ]          as components,
    array[ m.sortcode ]       as sortcodes
  from FACTORS.factors as m
  where true
    and ( m.strokecount <= 2 ) );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 7 }———:reset
insert into KWIC.the_pool ( select distinct
    m.iclabel                 as iclabel,
    'GF'                      as role,
    1                         as fformula_nr,
    m.glyph                   as glyph,
    array[ m.glyph ]          as components,
    array[ m.sortcode ]       as sortcodes
  from FACTORS.factors as m );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 8 }———:reset
insert into KWIC.the_pool ( select distinct
    m.iclabel                 as iclabel,
    'GR'                      as role,
    m.dformula_nr             as dformula_nr,
    m.glyph                   as glyph,
    m.components              as components,
    m.sortcodes               as sortcodes
  from DFORMULAS.dformulas as m );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 9 }———:reset
/* Supply `OJ` roles for `A:u-----:0000a7:§` and `A:ucsym-:003013:〓` where missing; this is
a hotfix for an oversight that probably originates in `SFX.xformulas`. The problem should
properly fixed there, and we only accept the hotfix for these two special cases. */
insert into KWIC.the_pool ( select distinct
    m.iclabel                 as iclabel,
    'OJ'                      as role,
    1                         as fformula_nr,
    m.glyph                   as glyph,
    m.components              as components,
    m.sortcodes               as sortcodes
  from KWIC.the_pool as m
  where true
    and ( m.iclabel in ( 'A:u-----:0000a7:§', 'A:ucsym-:003013:〓' ) )
    and ( not exists ( select 1
      from KWIC.the_pool as v1
      where true
        and ( m.iclabel = v1.iclabel )
        and ( v1.role = 'OJ' ) ) ) );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 10 }———:reset
alter table KWIC.the_pool add primary key ( iclabel, role, fformula_nr );
alter table KWIC.the_pool add constraint "iclabel must be an iclabel"           check ( qis.iclabel(        iclabel       ) );
alter table KWIC.the_pool add constraint "glyph must be a glyph"                check ( qis.glyph(          glyph         ) );
alter table KWIC.the_pool add constraint "components must be a non-empty array" check ( array_length( components, 1 ) >= 1  );
alter table KWIC.the_pool add constraint "sortcodes must be a non-empty array"  check ( array_length( sortcodes, 1 ) >= 1   );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 11 }———:reset
create        index on KWIC.the_pool           ( glyph                     );
create        index on KWIC.the_pool           ( role                      );
create unique index on KWIC.the_pool           ( iclabel, role, components );
create        index on KWIC.the_pool using gin ( components                );
create        index on KWIC.the_pool using gin ( sortcodes                 );


-- =========================================================================================================
--
-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 12 }———:reset
set role dba;
create function KWIC.get_permutations_SEQ(
    glyph text, factors text[], sortcodes text[], prefix_width integer, suffix_width integer )
  returns table ( glyph text, infix text, sortcode text, line text )
  immutable strict language plpython3u as $$
  plpy.execute( 'select U.py_init()' ); ctx = GD[ 'ctx' ]
  import kwic as _KWIC
  for ( infix, sortcode, line, ) in _KWIC.get_permutations_as_mkts_literals(
    glyph, factors, sortcodes, prefix_width, suffix_width ):
    yield ( glyph, infix, sortcode, line, )
  $$;
reset role;

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 13 }———:reset
/* `KWIC.get_permutations_PLL` is considerably faster than `KWIC.get_permutations_SEQ` due to it being
executed in parallel. However, parallel Python functions cannot use `plpy.execute()`; even `plpy.execute(
'select 42;' )` will fail with `ERROR: cannot start subtransactions during a parallel operation`.
Therefore, we cannot use our standard procedure to initialize Python's context (which is necessary
to update `sys.path` so that our custom modules are found by `import`).
*/
do $outer$
  declare
    ¶sql text;
  begin
    -- .....................................................................................................
    ¶sql := $sql$
      set role dba;
      create function KWIC.get_permutations_PLL(
          glyph text, factors text[], sortcodes text[], widths integer[] )
        returns table ( glyph text, lnr integer, rnr integer, infix text, sortcode text, lines text[] )
        -- immutable strict language plpython3u as $$
        immutable strict parallel safe language plpython3u as $$
        #.........................................................................................................
        try:
          KWIC = GD[ 'KWIC' ]
        #.........................................................................................................
        except KeyError:
          path = %s
          import sys
          sys.path.insert( 0, path )
          import kwic as KWIC
          GD[ 'KWIC' ] = KWIC
        #.........................................................................................................
        for ( lnr, rnr, infix, sortcode, lines, ) in KWIC.get_permutations_as_mkts_literals_2(
          glyph, factors, sortcodes, widths ):
          yield ( glyph, lnr, rnr, infix, sortcode, lines, )
        $$;
      reset role; $sql$;
    -- .....................................................................................................
    ¶sql := format( ¶sql, '''' || ¶( 'intershop/host/modules/path' ) || '''' );
    execute ¶sql;
    end; $outer$;

-- -- ---------------------------------------------------------------------------------------------------------
-- \echo :signal ———{ 14 }———:reset
-- /* ### TAINT unify with that other normalization function (in FMT?) */
-- create function KWIC._normalize( text ) returns text immutable strict parallel safe language sql as $$
--   select regexp_replace( $1, '&[^;]+;', '�', 'g' ); $$;

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 15 }———:reset
create table KWIC.kwic (
    iclabel         text    not null,
    glyph           text    not null,
    role            text    not null,
    lnr             integer not null,
    rnr             integer not null,
    wbf1            text    not null,
    g1              text    not null,
    g2              text    not null,
    pinfix          text    not null,
    infix           text    not null,
    wbf5            text    not null,
    wbf8            text    not null,
    kwic_23         text    not null,
    kwic_25         text    not null,
    kwic_34         text    not null,
    kwic_99         text    not null,
    sortcode        text    not null );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 16 }———:reset
-- \echo :gold 'vacuum freeze analyze FACTORS.factors;':reset
-- vacuum freeze analyze FACTORS.factors;
insert into KWIC.kwic select
    tp.iclabel                            as iclabel,
    tp.glyph                              as glyph,
    tp.role                               as role,
    k.lnr                                 as lnr,
    k.rnr                                 as rnr,
    substring( fc.s1_wbf from 1 for 1 )   as wbf1,
    fc.s1_glyph                           as g1,
    fc.s2_glyph                           as g2,
    FMT._gaiji_as_geta( fc.pglyph    )    as pinfix,
    FMT._gaiji_as_geta( k.infix      )    as infix,
    fc.wbf5                               as wbf5,
    fc.wbf8                               as wbf8,
    FMT._gaiji_as_geta( k.lines[ 1 ] )    as kwic_23,
    FMT._gaiji_as_geta( k.lines[ 2 ] )    as kwic_25,
    FMT._gaiji_as_geta( k.lines[ 3 ] )    as kwic_34,
    FMT._gaiji_as_geta( k.lines[ 4 ] )    as kwic_99,
    k.sortcode                            as sortcode
  from KWIC.the_pool as tp
  -- join KWIC.get_permutations_SEQ(
  join KWIC.get_permutations_PLL(
    tp.glyph, tp.components, tp.sortcodes, '{{2,3},{2,5},{3,4},{9,9}}'::integer[] )
    as k ( glyph, lnr, rnr, infix, sortcode, lines ) using ( glyph )
  left join FACTORS.factors as fc on ( k.infix = fc.glyph );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 17 }———:reset
alter table KWIC.kwic add primary key ( iclabel, role, sortcode );
create unique index on KWIC.kwic ( iclabel, role, kwic_99 );
create index on KWIC.kwic ( iclabel   );
create index on KWIC.kwic ( glyph     );
create index on KWIC.kwic ( role      );
create index on KWIC.kwic ( wbf1      );
create index on KWIC.kwic ( g1        );
create index on KWIC.kwic ( g2        );
create index on KWIC.kwic ( wbf5      );
create index on KWIC.kwic ( wbf8      );
create index on KWIC.kwic ( pinfix    );
create index on KWIC.kwic ( lnr       );
create index on KWIC.kwic ( rnr       );
create index on KWIC.kwic ( infix     );
create index on KWIC.kwic ( kwic_23   );
create index on KWIC.kwic ( kwic_25   );
create index on KWIC.kwic ( kwic_34   );
create index on KWIC.kwic ( kwic_99   );
create index on KWIC.kwic ( sortcode  );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ 18 }———:reset
/* Sanity Check: See that all glyphs with role `GF` (guide/factor) also appear in role `OJ` (oyaji) */
do $$
  declare
    ¶row    record;
    ¶count  integer := 0;
  begin
    for ¶row in ( select *
       from KWIC.kwic as k1
       where true
        and k1.role = 'GF'
        and not exists ( select 1 from KWIC.kwic as k2 where k1.glyph = k2.glyph and k2.role = 'OJ' )
        order by sortcode ) loop
      ¶count := ¶count + 1;
      perform log( '44982', ¶row::text );
      end loop;
    if ¶count > 0 then
      raise exception 'KWIC #89743 the above factors do not have a corresponding OJ-entry';
      end if;
    end; $$;