
-- ---------------------------------------------------------------------------------------------------------
-- ### TAINT may want to count events to check event count is 0 or 1
create function FM._cond_focuses_has_no_event( ¶cond_focuses FM_TYPES.focus[] )
  returns boolean immutable parallel safe language sql as $$
    select not U._any_matches( ¶cond_focuses, '^\^' ); $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM.add_transition(
  ¶cond_topics FM_TYPES.topic[], ¶cond_focuses FM_TYPES.focus[],
  ¶csqt_topics FM_TYPES.topic[], ¶csqt_focuses FM_TYPES.focus[] )
  returns void volatile language plpgsql as $$
  begin
    -- make sure lengths of cond_topics, cond_focuses are equal and > 0
    -- make sure lengths of csqt_topics, csqt_focuses are equal and > 0
    if FM._cond_focuses_has_no_event( ¶cond_focuses ) then
      ¶cond_topics  :=  array_append( ¶cond_topics, '°FSM'    );
      ¶cond_focuses :=  array_append( ¶cond_focuses, '^TICK'  );
      end if;
    insert into FM.transition_phrases ( cond_topics, cond_focuses, csqt_topics, csqt_focuses ) values
      ( ¶cond_topics, ¶cond_focuses, ¶csqt_topics, ¶csqt_focuses );
  end; $$;

comment on function FM.add_transition( FM_TYPES.topic[], FM_TYPES.focus[], FM_TYPES.topic[], FM_TYPES.focus[] )
is 'Basic form of adding a transition phrase that requires the ready-made column vectors as arguments.';

-- ---------------------------------------------------------------------------------------------------------
-- ### TAINT use more precise input type?
create function FM.add_transition( ¶conds FM_TYPES.nonempty_text[], ¶csqts FM_TYPES.nonempty_text[] )
  returns void volatile language plpgsql as $$
  declare
    ¶pair_pattern     text              :=  '^([°^:][^°^:,]+)([°^:][^°^:,]+)$';
    ¶topic_focus      text[]            :=  null;
    ¶cond_topics      FM_TYPES.topic[]  :=  null;
    ¶cond_focuses     FM_TYPES.focus[]  :=  null;
    ¶csqt_topics      FM_TYPES.topic[]  :=  null;
    ¶csqt_focuses     FM_TYPES.focus[]  :=  null;
  begin
    for ¶idx in 1 .. array_length( ¶conds, 1 ) loop
      ¶topic_focus  :=  regexp_match( ¶conds[ ¶idx ], ¶pair_pattern );
      ¶cond_topics  :=  array_append( ¶cond_topics,   ¶topic_focus[ 1 ]::FM_TYPES.topic );
      ¶cond_focuses :=  array_append( ¶cond_focuses,  ¶topic_focus[ 2 ]::FM_TYPES.focus );
      end loop;
    for ¶idx in 1 .. array_length( ¶csqts, 1 ) loop
      ¶topic_focus  :=  regexp_match( ¶csqts[ ¶idx ], ¶pair_pattern );
      ¶csqt_topics  :=  array_append( ¶csqt_topics,   ¶topic_focus[ 1 ]::FM_TYPES.topic );
      ¶csqt_focuses :=  array_append( ¶csqt_focuses,  ¶topic_focus[ 2 ]::FM_TYPES.focus );
      end loop;
    perform FM.add_transition( ¶cond_topics, ¶cond_focuses, ¶csqt_topics, ¶csqt_focuses );
  end; $$;

comment on function FM.add_transition( FM_TYPES.nonempty_text[], FM_TYPES.nonempty_text[] ) is 'Intermediate
form of adding a transition phrase that requires arguments to be lists of conditions and consequents (that
are not yet split into topics and focuses).';

-- ---------------------------------------------------------------------------------------------------------
-- ### TAINT validate that each phrase contains exactly one event (plus any number of state matchers)
create function FM.add_transition( ¶phrase FM_TYPES.nonempty_text )
  returns void volatile language plpgsql as $$
  declare
    ¶phrase_pattern   text :=  '^(.+\S)\s*(?:=>|⇒)\s*(.+)$';
    ¶conds_csqts      text[];
    ¶conds            FM_TYPES.nonempty_text[];
    ¶csqts            FM_TYPES.nonempty_text[];
  begin
    -- ### TAINT make sure match was successful
    ¶phrase           :=  regexp_replace( ¶phrase, '^\s+', '' );
    ¶phrase           :=  regexp_replace( ¶phrase, '\s+$', '' );
    ¶conds_csqts      :=  regexp_match( ¶phrase, ¶phrase_pattern );
    ¶conds            :=  regexp_split_to_array( ¶conds_csqts[ 1 ], '\s*,\s*' );
    ¶csqts            :=  regexp_split_to_array( ¶conds_csqts[ 2 ], '\s*,\s*' );
    perform FM.add_transition( ¶conds, ¶csqts );
  end; $$;

comment on function FM.add_transition( FM_TYPES.nonempty_text ) is 'Top level form of adding a transition
phrase that requires the phrase in its notational form, as in ''°power:on, °button^press => °bell^ring,
°lamp:on''. The arrow may be written as two characters `=`, `>` or a single ⇒ (U+21D2); terms are separated
by commas; spaces may appear between terms and around the arrow, but not inside terms.';


-- =========================================================================================================
--
-- ---------------------------------------------------------------------------------------------------------
create function FM_FSM.reset() returns void volatile language plpgsql as $$
  -- Reset all values to their defaults
  begin
    perform log( '^FM_FSM.reset^' );
    insert into FM.journal  ( topic, focus, kind, remark )
      select                  topic, focus, kind, 'RESET'
      from FM.pairs
      where dflt; -- `kind = 'state'` is implicit for `dflt = true`
    -- ### TAINT consider to actually use entries in `transition_phrases`:
    insert into FM.journal  ( topic,  focus,      kind,     remark  ) values
                            ( '°FSM', ':ACTIVE',  'state',  'RESET' );
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM_FSM.record_unmatched_event( ¶row FM.queue ) returns void volatile language plpgsql as $$
  begin
    insert into FM.journal ( topic, focus, remark ) values ( ¶row.topic, ¶row.focus, 'UNPROCESSED' );
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM_FSM.move_queued_event_to_journal( ¶row FM.queue, ¶remark text )
  returns void volatile language plpgsql as $$
  begin
    delete from FM.queue where id = ¶row.id;
    insert into FM.journal ( topic, focus, kind, remark ) values ( ¶row.topic, ¶row.focus, 'event', ¶remark );
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create function FM_FSM.match_event( ¶row FM.queue )
  returns text volatile language plpgsql as $$
  declare
    ¶remark       text  :=  'RESOLVED';
    ¶transitions  record;
  begin
    perform log( '^388799^', ¶row::text );
    ¶remark :=  'UNPROCESSED';
    -- for ¶transitions in
    --   select csqt_topics, csqt_focuses
    --     from FM.transition_phrases
    --       where true
    --         and topic = ¶row.topic
    --         and focus = ¶row.focus
    --   loop
    --     perform log( '^3877^', transitions::text );
    --     end loop;
    return ¶remark;
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
/* ### TAINT  when used as an actual queue, should not trigger on insert but run independently, possibly
              using external clok. */
create function FM.on_after_insert_into_fm_eventqueue() returns trigger language plpgsql as $$
  declare
    ¶event    text  :=  null;
    ¶remark   text  :=  'RESOLVED';
  begin
    ¶event  := new.topic || new.focus;
    perform log( '^6643^', new::text );
    perform log( '^6643^', new.topic::text );
    perform log( '^6643^', new.focus::text );
    perform log( '^6643^', pg_typeof( new )::text );
    -- .....................................................................................................
    case ¶event
      when '°FSM^RESET' then
        perform FM_FSM.reset();
        perform FM_FSM.move_queued_event_to_journal( new, ¶remark );
      else                    ¶remark :=  FM_FSM.match_event( new );
      -- else                    ¶remark :=  'UNPROCESSED';
      end case;
    -- .....................................................................................................
    return null;
    end; $$;

-- ---------------------------------------------------------------------------------------------------------
create trigger on_after_insert_into_fm_eventqueue after insert on FM.queue
  for each row execute procedure FM.on_after_insert_into_fm_eventqueue();


-- =========================================================================================================
-- INITIAL DATA
-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 6 }———:reset
insert into FM.kinds ( kind, sigil, comment ) values
  ( 'component',  '°',  'models interacting parts of the system'            ),
  ( 'verb',       '^',  'models what parts of the system can do'            ),
  ( 'aspect',     ':',  'models malleable phases of components'             ),
  ( 'event',      '°^', 'models ex- and internal actuations of the system'  ),
  ( 'state',      '°:', 'models static and dynamic postures of the system'  );

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 10 }———:reset
do $$ begin
  -- -------------------------------------------------------------------------------------------------------
  perform FM.add_atom( '°FSM',       'component',  'pseudo-component for the automaton itself' );
  perform FM.add_atom( ':IDLE',      'aspect',     'when the automaton is not in use'          );
  perform FM.add_atom( ':ACTIVE',    'aspect',     'when the automaton is in use'              );
  perform FM.add_atom( '^RESET',     'verb',       'put the automaton in its initial state'    );
  -- perform FM.add_atom( '^START',     'verb',       'start the automaton'                       );
  -- -------------------------------------------------------------------------------------------------------
  perform FM.add_pair(  '°FSM', ':IDLE',    'state',  true,   'the automaton is not in use'               );
  perform FM.add_pair(  '°FSM', ':ACTIVE',  'state',  false,  'the automaton is in use'                   );
  perform FM.add_pair(  '°FSM', '^RESET',   'event',  false,  'reset the automaton to its initial state'  );
  -- perform FM.add_pair(  '°FSM', '^START',   'event',  false,  'start the automaton'                       );
  -- -------------------------------------------------------------------------------------------------------
  end; $$;

-- ---------------------------------------------------------------------------------------------------------
\echo :signal ———{ :filename 10 }———:reset
do $$ begin
  -- -------------------------------------------------------------------------------------------------------
  -- The 'raw' form to define a transition:
  -- perform FM.add_transition(
  --      '{°FSM,°FSM}'::FM_TYPES.topic[],
  --   '{:IDLE,^START}'::FM_TYPES.focus[],
  --           '{°FSM}'::FM_TYPES.topic[],
  --        '{:ACTIVE}'::FM_TYPES.focus[] );
  -- -------------------------------------------------------------------------------------------------------
  perform FM.add_transition( '°FSM:IDLE,°FSM^START => °FSM:ACTIVE' );
  -- -------------------------------------------------------------------------------------------------------
  end; $$;



/* ###################################################################################################### */
\echo :red ———{ :filename 13 }———:reset
\quit

