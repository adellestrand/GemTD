-- Scores are deliberately UNVERIFIED. Only the Edge Function may submit.
create table public.leaderboard_releases (
  rules_hash text primary key check (rules_hash ~ '^[a-f0-9]{64}$'),
  game_version text not null,
  content_version integer not null,
  accepting boolean not null default true
);
create table public.leaderboard_runs (
  run_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  rules_hash text not null references public.leaderboard_releases(rules_hash),
  display_name text not null check (char_length(display_name) between 2 and 24),
  completed_waves integer not null check (completed_waves between 0 and 100),
  lives integer not null check (lives between 0 and 1000000),
  simulation_seconds numeric not null check (simulation_seconds >= 0),
  seed text not null,
  report jsonb not null,
  verified boolean not null default false,
  created_at timestamptz not null default now()
);
create index leaderboard_runs_user_time on public.leaderboard_runs(user_id, created_at);
create index leaderboard_runs_ranking on public.leaderboard_runs(rules_hash, completed_waves desc, lives desc, created_at);
alter table public.leaderboard_releases enable row level security;
alter table public.leaderboard_runs enable row level security;
revoke all on public.leaderboard_releases, public.leaderboard_runs from anon, authenticated;
grant all on public.leaderboard_releases, public.leaderboard_runs to service_role;

create function public.leaderboard_top(p_rules_hash text, p_limit integer default 20)
returns table(display_name text, completed_waves integer, lives integer, verified boolean, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select x.display_name, x.completed_waves, x.lives, x.verified, x.created_at
  from (
    select r.*, row_number() over (partition by r.user_id order by r.completed_waves desc, r.lives desc, r.created_at) as place
    from public.leaderboard_runs r where r.rules_hash = p_rules_hash
  ) x where x.place = 1
  order by x.completed_waves desc, x.lives desc, x.created_at, x.run_id
  limit greatest(1, least(coalesce(p_limit,20),100));
$$;
revoke all on function public.leaderboard_top(text,integer) from public;
grant execute on function public.leaderboard_top(text,integer) to anon, authenticated, service_role;

create function public.submit_leaderboard_run(p_user uuid, p_run uuid, p_nickname text,
  p_rules_hash text, p_waves integer, p_lives integer, p_seconds numeric, p_seed text, p_report jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare existing_user uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text,0));
  select user_id into existing_user from public.leaderboard_runs where run_id=p_run;
  if found then
    if existing_user <> p_user then raise exception 'run_identity_conflict'; end if;
    return p_run; -- retries are idempotent; never overwrite an earlier result
  end if;
  if not exists (select 1 from public.leaderboard_releases where rules_hash=p_rules_hash and accepting) then
    raise exception 'rules_not_accepting';
  end if;
  if (select count(*) from public.leaderboard_runs where user_id=p_user and created_at > now()-interval '1 hour') >= 10 then
    raise exception 'submission_rate_limit';
  end if;
  insert into public.leaderboard_runs(run_id,user_id,rules_hash,display_name,completed_waves,lives,simulation_seconds,seed,report)
    values(p_run,p_user,p_rules_hash,p_nickname,p_waves,p_lives,p_seconds,p_seed,p_report);
  return p_run;
end;
$$;
revoke all on function public.submit_leaderboard_run(uuid,uuid,text,text,integer,integer,numeric,text,jsonb) from public, anon, authenticated;
grant execute on function public.submit_leaderboard_run(uuid,uuid,text,text,integer,integer,numeric,text,jsonb) to service_role;

insert into public.leaderboard_releases(rules_hash,game_version,content_version)
values ('50ead0c1187245bc9c9da4224a0b47296d3f0445eaca5391cdcf6c698a5812bb','1.4.1-dev',10);
