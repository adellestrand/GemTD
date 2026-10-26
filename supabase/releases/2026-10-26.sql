-- Published gold-spells campaign, commit a24714b (content unchanged from e4f7745).
insert into public.leaderboard_releases(rules_hash,game_version,content_version)
values ('3233b65bf638b2efb108b3b83e6f65d4c2293bd72bc7b1f92369e14124f60d38','1.4.1-dev',10)
on conflict (rules_hash) do nothing;
