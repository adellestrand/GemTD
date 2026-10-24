-- Run with execute_sql/psql against a migrated project. All fixture data rolls back.
begin;
do $$
declare
  player_a uuid := gen_random_uuid();
  player_b uuid := gen_random_uuid();
  first_run uuid := gen_random_uuid();
  rules text := repeat(replace(gen_random_uuid()::text,'-',''),2);
  best record;
  total integer;
begin
  insert into auth.users(id,is_anonymous) values(player_a,true),(player_b,true);
  insert into public.leaderboard_releases values(rules,'test',1,true);
  perform public.submit_leaderboard_run(player_a,first_run,'Test A',rules,3,10,1,'1','{}');
  perform public.submit_leaderboard_run(player_a,first_run,'Changed',rules,100,999,1,'1','{}');
  select count(*) into total from public.leaderboard_runs where rules_hash=rules;
  assert total=1, 'Retry must be idempotent';
  assert (select completed_waves from public.leaderboard_runs where run_id=first_run)=3, 'Retry must not overwrite';
  perform public.submit_leaderboard_run(player_a,gen_random_uuid(),'Test A',rules,4,2,1,'1','{}');
  perform public.submit_leaderboard_run(player_b,gen_random_uuid(),'Test B',rules,4,3,1,'1','{}');
  select * into best from public.leaderboard_top(rules,20) limit 1;
  assert best.display_name='Test B' and best.completed_waves=4 and not best.verified, 'Sort by cleared waves then lives, unverified';
  select count(*) into total from public.leaderboard_top(rules,20);
  assert total=2, 'Only one best result per player';
  select count(*) into total from public.leaderboard_top(rules,1);
  assert total=1, 'Limit respected';
  begin
    perform public.submit_leaderboard_run(player_b,first_run,'Test B',rules,1,1,1,'1','{}');
    raise exception 'Expected identity conflict';
  exception when others then
    if sqlerrm <> 'run_identity_conflict' then raise; end if;
  end;
  for i in 1..8 loop
    perform public.submit_leaderboard_run(player_a,gen_random_uuid(),'Test A',rules,1,1,1,'1','{}');
  end loop;
  begin
    perform public.submit_leaderboard_run(player_a,gen_random_uuid(),'Test A',rules,1,1,1,'1','{}');
    raise exception 'Expected rate limit';
  exception when others then
    if sqlerrm <> 'submission_rate_limit' then raise; end if;
  end;
  assert not has_table_privilege('anon','public.leaderboard_runs','SELECT'), 'Raw reports must be private';
  assert not has_table_privilege('authenticated','public.leaderboard_runs','INSERT'), 'Direct client writes forbidden';
  assert not has_function_privilege('authenticated','public.submit_leaderboard_run(uuid,uuid,text,text,integer,integer,numeric,text,jsonb)','EXECUTE'), 'Only server may submit';
  assert has_function_privilege('anon','public.leaderboard_top(text,integer)','EXECUTE'), 'Public can read safe list';
end;
$$;
rollback;
select 'LEADERBOARD_DATABASE_CHECK_OK' as result;
