-- User-approved rule: five free tower moves per run, then 100 gold per successful move.
insert into public.leaderboard_releases(rules_hash,game_version,content_version)
values ('ef7eae658a3e760c775ad98cc680d601d6292f373f396c9ff4b9de1e26bf732b','1.4.1-dev',13)
on conflict (rules_hash) do nothing;
