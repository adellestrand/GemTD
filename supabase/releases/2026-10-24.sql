-- Explicitly approved, committed campaign rules; never auto-accept client hashes.
insert into public.leaderboard_releases(rules_hash,game_version,content_version)
values ('84986c6e49cdd1ef0b5e7fc74a7750e65a297beacd032a4e70b69d23871c2781','1.4.1-dev',10)
on conflict (rules_hash) do nothing;
