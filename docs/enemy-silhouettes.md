# Egna fiendesiluetter (2026-10-24)

Endast presentation. Inga vågor, fiendetyper eller värden ändras; varje kampanjfiende behåller sitt `source_id` och sina förmågor. Nya fiendetyper eller vågor vore en regeländring (röd zon) och kräver uttryckligt beslut.

## Underlag

Kampanjen har 50 unika fiender. I Dota-versionen är varje fiende en egen courier-modell; modellsökvägen står i referensdatan (`.tools/reference/units.json`, fältet `Model`, se tabellen nedan). I vårt spel finns bara tio grundbilder (refined-v3) och 43 fiender är omfärgningar av dem (`tools/art/variants.py`). Utseende härleds här från modellnamnet och allmän kännedom om Dota-couriers; poster märkta *bekräfta* behöver jämföras med en bild (t.ex. Liquipedias courier-sida) innan konst beställs.

## Status (2026-10-24): genomfört

32 fiender har egen kropp i stället för omfärgning, alla ritade direkt i pxl i `tools/art/anims/creatures.px.js` (godkänd stilprototyp: stump) med egen gång-/vingcykel.

| Grundform | Fiender |
|---|---|
| Växt/trä | stump, shroomy, shagbark (boss) |
| Fisk | shark, furry_fish, goldfish (flyg) |
| Fågel | flamingo (på skateboard), drodo, chicken (med mästarbälte) |
| Farkost | corsair (flygande skepp), carpet_rider (smeevil på flygande matta, boss) |
| Ande/demon | young_demon (imp), ghost (wraith, flygboss), ripper (skelettraptor), boooofus (liten liemannen) |
| Hovdjur | alpaca (lama med schabrak) |
| Liten Roshan | baby_roshan (flygboss) |
| Små däggdjur | rabbit, fox, jinyin_fox, wabbit, panda_flyer (flyg), lilnova (lejonunge i hjälm) |
| Kistor ("Boxhound") | lockjaw (gul, horn, blått öga), trapjaw (lila, gröna ädelstenar, horn, orange öga), machjaw (stål, periskophuvud) |
| Småfolk | jumo (alvflicka med lykta), zombie (jiangshi som hoppar), sheep (Forest Faun: satyrbarn med säckpipa) |
| Insekt | kupu (orange fjäril, flyg) |
| Amfibie | mermaid (amfibiebarn på flygande fisk) |

Bekräftat med bilder från Dota 2-wikin (dota2.fandom.com, gallerierna för respektive courier; Liquipedia kräver människoverifiering): Lil' Nova (Lunas Nova som unge), Duskie (huskyvalp, därför kvar som omfärgad hound), Boooofus, Jumo, Kupu the Metamorpher, Zombie Hopper (`pw_zombie`, Perfect World), Forest Faun (`courier_faun`), Lockjaw/Trapjaw/Mechjaw the Boxhound. Två tidigare antaganden var fel och är rättade: lockjaw/trapjaw/machjaw är kistor, inte ödlor/krokodil, och "sheep" är en faun.

Remsorna heter `assets/graphics/refined-v3/anims/<fiende>_<walk|flap>_v2.png`; de gamla omfärgningarna (`_v1`, `variants/*.png`) ligger kvar, och manifestet före bytet är sparat i `output/pxl/manifest_before_silhouettes.json` (git-ignorerad). Fortfarande omfärgning med rätt kroppstyp: pig_princess, bajie, bulldog, baekho, dusky, bookwyrm, azuremir, crummy, invisible_spider, huntling, chirpy, ig_dragon. Våg 5 "balloon badger" (`courier_badger_flying`, Fearless Badger) har nu egen kropp: grävling under två lapptäcksballonger med säck och stjärtrotor. Totalt 32 egna kroppar.

De 32 kropparna finns nu AI-förfinade (refined-v4, samma metod som refined-v3) och används i spelet som `_v3`-remsor; de pxl-ritade `_v2`-remsorna är reserv. Se `docs/ai-enemy-sheets-v2.md`.

Pixelstorlek: varje kropp har en egen skala i `creature(..., scale)` så att den i spelet får samma pixelstorlek som refined-v3 (cirka 2,1 skärmpixlar per bildpixel vid 1,25 rutor, bossar 2,47 vid 1,85; nu 2,08–2,16 respektive 2,47–2,50 mot refined-v3:s 1,76–2,60). Formerna ritas om i den större upplösningen i stället för att förstoras. Målerisk yta: tonövergångar följer mjukt värdebrus (penselkluster i stället för rutmönster), delar får kontaktskugga där de överlappar, och päls-, fjäder-, fjäll- och ullockstruktur (`fur`, `scallops`, `curls`) läggs på i slutupplösningen. Kvarstående skillnad: kropparna bygger på enkla skuggade former och har något mindre detalj än de AI-förfinade bilderna.

## Idé: nya grundformer i stället för en bild per fiende

Flera Dota-modeller delar kroppstyp. Sju nya grundbilder skulle ge ~25 fiender rätt siluett, och varje ny grundbild kan sedan få omfärgningar via `variants.py` och gång-/vingcykel via `tools/art/anims/walk.px.js` precis som i dag.

| Ny grundform | Ersätter för | Nuvarande (fel) bas |
|---|---|---|
| **Växt/trä** (stubbe/ent, svamp) | stump, shagbark (boss), shroomy | spider, boss_hound, frog |
| **Fisk** (simmar i luften/på marken) | goldfish (flyg), shark, furry_fish | bat, frog, frog |
| **Långbent fågel** (marklöpare) | flamingo, drodo, chicken | griffin |
| **Farkost** (skepp, flygande matta med åkare) | corsair (flyg), carpet_rider (flygboss) | bat, griffin |
| **Liten tvåbent demon/ande** | young_demon (imp), ghost (wraith, flygboss), ripper (*bekräfta*) | lizard, bat, spider |
| **Långhalsat hovdjur** | alpaca (lama), sheep (faun, *bekräfta*) | yak |
| **Liten Roshan** | baby_roshan (flygboss) | boss_hound |

Därefter, om formerna fungerar: rabbit (kanin, nu hound), panda_flyer (panda, nu griffin), mermaid (amphibian kid, nu griffin), fox/jinyin_fox/wabbit (flygande däggdjur, nu bat), machjaw (mekanisk krokodil, nu robot), lilnova, jumo, boooofus, kupu (*bekräfta* alla fyra).

Behålls som omfärgning (rätt kroppstyp redan): pig_princess, bajie (gris → boar), bulldog, baekho (hund/tiger → hound), lockjaw, trapjaw, bookwyrm, azuremir (ödla/drake → lizard), crummy (åsna → yak), invisible_spider (spindel), huntling, chirpy (fågel → griffin), ig_dragon (drake → bat). dusky och zombie: *bekräfta*.

## Arbetsflöde per ny grundform

1. Ta fram ett AI-ark i samma stil som de godkända (samma prompt-metod som `assets/graphics/PROMPTS.md`), eller generera med SpriteCook-pluginet. Användaren avvisade en helt ny pixelstil, så nya bilder ska matcha refined-v3.
2. `tools/art/refine.py` → ren pixelbild i `assets/graphics/refined-v3/`, versionsnamn.
3. Omfärgningar: flytta varianterna till den nya basen i `VARIANTS` (`tools/art/variants.py`).
4. Rörelse: ny `walk(...)`-rad i `tools/art/anims/walk.px.js` + rad i `ANIMS` i `tools/art/build_anims.py`.
5. Manifest: peka fiendens sprite på den nya remsan. `tests/check_enemy_frames.gd`, `check_art.gd`, `redesign_guard.py` och `check.py`.

Prioritet: växt/trä först (stump syns redan i våg 6 och shagbark är boss i våg 20), sedan fisk och fågel (många fiender per bild), sedan farkost och bossarna.

## Källmodeller (Dota-versionen, `units.json`)

| Våg | Fiende (`source_id` utan `gemtd_`) | Namn | Dota-modell | Vår bild (bas) |
|---|---|---|---|---|
| 1 | kuangbaoyezhu | frenzied pig | courier/mighty_boar | boar |
| 2 | kuaidiqingwatiaotiao | swift frog | courier/frog | frog |
| 3 | zhongchenggaoshanmaoniu | sturdy yak | courier/yak | yak |
| 4 | moluokedejixiezhushou | smart robot | courier/courier_mech | robot |
| 5 | wuweizhihuan_fly | balloon badger | courier/badger (flying) | griffin |
| 6 | shudunziranzhizhu | tardy stump | courier/stump | stump (spider) |
| 7 | chaomengjuxi | satisfied lizard | courier/tegu | lizard |
| 8 | mengzhu | invisible spider | items/courier/itsy | invisible_spider (spider) |
| 9 | dashiqi | dusky | items/courier/duskie | dusky (hound) |
| 10 | buquzhanquan_boss | invincible dog | courier/juggernaut_dog | boss_hound |
| 11 | maorongrongdefeiyangyang | sheep | items/courier/courier_faun | sheep (yak) |
| 12 | caonimalama | funny alpaca | items/courier/livery_llama_courier | alpaca (yak) |
| 13 | fengtungongzhu | pig princess | items/courier/gnomepig | pig_princess (boar) |
| 14 | bugou | bulldog | items/courier/butch_pudge_dog | bulldog (hound) |
| 15 | banzhuduizhang_fly | bamboo addict | items/courier/captain_bamboo (flying) | panda_flyer (griffin) |
| 16 | xunjiemotong | young demon | courier/imp | young_demon (lizard) |
| 17 | yonggandexiaoji | belted chicken | items/courier/mighty_chicken | chicken (griffin) |
| 18 | xiaobajie | bajie | items/courier/bajie_pig | bajie (boar) |
| 19 | shentu | exquisite rabbit | items/courier/arneyb_rabbit | rabbit (hound) |
| 20 | huxiaotao_boss | shakbag | items/courier/shagbark | shagbark (boss_hound) |
| 21 | siwangsiliezhe | ripper | items/courier/deathripper | ripper (spider) |
| 22 | yaorenxiangluoke | lockjaw | courier/lockjaw | lockjaw (lizard) |
| 23 | tiezuiyaorenxiang | trapjaw | courier/trapjaw | trapjaw (lizard) |
| 24 | jixieyaorenxiang | machjaw | courier/mechjaw | machjaw (robot) |
| 25 | fengbaozhizikesaier_fly | corsair | items/courier/corsair_ship (flying) | corsair (bat) |
| 26 | niepanhuolieniao | skateboard flamingo | items/courier/courier_mvp_redkita | flamingo (griffin) |
| 27 | lgddejinmengmeng_fly | lgd goldfish | items/courier/lgd_golden_skipper (flying) | goldfish (bat) |
| 28 | youniekesizhinu_fly | ig dragon | items/courier/ig_dragon (flying) | ig_dragon (bat) |
| 29 | feihuxia_fly | vg fox | items/courier/vigilante_fox_red (flying) | fox (bat) |
| 30 | mofafeitanxiaoemo_boss_fly | carpet rider | courier/smeevil_magic_carpet (flying) | carpet_rider (griffin) |
| 31 | modianxiaolong | bookwyrm | items/courier/bookwyrm | bookwyrm (lizard) |
| 32 | xiaoshayu | rechargeable shark | items/courier/kanyu_shark | shark (frog) |
| 33 | feijiangxiaobao | ribboned zombie | items/courier/pw_zombie | zombie (hound) |
| 34 | shangjinbaobao_fly | bounty apprentice | courier/huntling (flying) | huntling (griffin) |
| 35 | jinyinhuling_fly | black and white fox | items/courier/jin_yin_white_fox (flying) | jinyin_fox (bat) |
| 36 | cuihua | jumo | items/courier/jumo | jumo (yak) |
| 37 | xiaobaihu | baekho | items/courier/baekho | baekho (hound) |
| 38 | xiaoxingyue | lilnova | items/courier/lilnova | lilnova (frog) |
| 39 | liangqiyuhai_fly | mermaid rider | items/courier/amphibian_kid (flying) | mermaid (griffin) |
| 40 | guixiaoxieling_boss_fly | thrilling ghost | items/courier/mlg_courier_wraith (flying) | ghost (bat) |
| 41 | weilanlong | azuremir | items/courier/azuremircourierfinal | azuremir (lizard) |
| 42 | saodiekupu_fly | kupu | items/courier/kupu_courier (flying) | kupu (griffin) |
| 43 | maomaoyu | Maomaoyu | items/courier/coral_furryfish | furry_fish (frog) |
| 44 | xiaomogu | Xiaomogu | items/courier/shroomy | shroomy (frog) |
| 45 | jiujiu_fly | Jiujiu Fly | items/courier/bts_chirpy (flying) | chirpy (griffin) |
| 46 | siwangxintu | Siwangxintu | items/courier/boooofus_courier | boooofus (yak) |
| 47 | jilamofashi | Jilamofashi | courier/donkey_crummy_wizard_2014 | crummy (yak) |
| 48 | xiaofeixia_fly | Xiaofeixia Fly | items/courier/wabbit_the_mighty_courier_of_heroes (flying) | wabbit (bat) |
| 49 | juniaoduoduo | Juniaoduoduo | courier/drodo | drodo (griffin) |
| 50 | roushan_boss_fly | Roushan Boss Fly | courier/baby_rosh (flying) | baby_roshan (boss_hound) |

Våg 51–100 återanvänder dessa 50. Dota-modellerna och deras texturer följer inte med spelet; de används bara som formreferens.
