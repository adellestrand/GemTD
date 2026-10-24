extends "res://tests/check_campaign.gd"

func run_checks() -> void:
	var combat = fixture("aquamarine",6)
	var cells = combat.run.board.cells
	cells[at].mvp = 3
	cells[at+Vector2i(1,0)] = gem("opal")
	cells[at+Vector2i(0,1)] = gem("opal")
	cells[at+Vector2i(-1,0)] = gem("diamond")
	cells[at+Vector2i(-1,0)].mvp = 10
	cells[at+Vector2i(9,0)] = gem("diamond")
	cells[at+Vector2i(9,0)].mvp = 10
	combat.sync_towers()
	var before = combat.run.snapshot()
	var rng = combat.run.combat_rng.state
	var text = GemTowerEffects.text(cells[at],at,cells,combat)
	check(text.contains("Own MVP 3/10: +30%") and text.contains("Total MVP damage bonus: +130%"),"own and nearby MVP bonuses shown separately with effective total")
	check(text.count("MVP aura:") == 1 and text.contains("(10, 11)"),"MVP source location shown and out-of-range source excluded")
	check(text.count("Attack speed +20") == 1 and text.count("Reveals invisible enemies") == 1,"same-quality speed and detection support each appear once, matching non-stacking combat")
	check(text.contains("Innate:") and text.contains("+500"),"innate attack speed shown separately")
	combat.towers[at].buffs["test"] = {"until":combat.elapsed+2,"properties":{"attack_speed":15}}
	combat.towers[at].buffs["expired"] = {"until":combat.elapsed-1,"properties":{"attack_speed":999}}
	combat.towers[at].disabled = combat.elapsed+1.5
	combat.towers[at].hostile_disarm_until = combat.elapsed+.5
	text = GemTowerEffects.text(cells[at],at,cells,combat)
	check(text.contains("Temporary:") and text.contains("2.0s left") and not text.contains("999"),"only unexpired temporary buffs shown with remaining time")
	check(text.contains("Cannot attack: 1.5s") and text.contains("Enemy disarm: 0.5s"),"both disabling effects visible with their actual remaining time")
	check(combat.towers[at].buffs.has("expired"),"inspection does not expire or mutate real combat modifiers")
	check(combat.run.snapshot() == before and combat.run.combat_rng.state == rng,"inspection preserves saved state and RNG")
	cells.erase(at+Vector2i(1,0))
	cells.erase(at+Vector2i(0,1))
	cells.erase(at+Vector2i(-1,0))
	combat.sync_towers()
	text = GemTowerEffects.text(cells[at],at,cells,combat)
	check(not text.contains("Aura:") and not text.contains("MVP aura:"),"removing support clears stale source entries")
	var game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.audio.volume = 0
	game.run.board.cells[at] = gem("diamond")
	game.run.board.cells[at].mvp = 2
	game.on_cell_clicked(at)
	check(game.affecting_effects.visible and game.affecting_effects.text.contains("MVP 2/10"),"clicking a tower reveals affecting effects in the real panel")
	game.run.board.cells[at] = gem("stone")
	game.refresh_ui()
	check(not game.affecting_effects.visible,"stone selection hides previous tower effects")
	game.new_run(7)
	check(not game.affecting_effects.visible,"restart clears selected tower effects")
	game.free()
	print("TOWER_EFFECTS_CHECK_%s checks=%d failures=%d" % ["OK" if failures == 0 else "FAILED",checks,failures])
	quit(1 if failures else 0)
