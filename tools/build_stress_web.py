"""Build an isolated UI load fixture using unchanged production game sources."""
from pathlib import Path
import re
import shutil
import subprocess
from godot import ROOT, ENGINE, local_environment

HARNESS = '''extends Node
var samples: Array[float] = []
var frames = 0
func _ready() -> void:
	var game = preload("res://game/main.tscn").instantiate()
	add_child(game)
	game.smoke = true
	game.audio.volume = 0
	var fixture = preload("res://game/testing/late_fixture.gd").setup(99,64)
	game.new_run(8099,fixture.run.snapshot())
	game.run.phase = "combat"
	game.run.combat_started.emit()
	game.combat.wave_data.count = 96
	for i in range(96): game.combat.spawn_enemy()
	game.refresh_ui()
	var label = Label.new()
	label.text = "LOAD FIXTURE · 64 towers / 96 simultaneous enemies · not an earned run"
	label.position = Vector2(380,4)
	label.add_theme_font_size_override("font_size",13)
	label.modulate = Color("f6d488")
	game.add_child(label)
func _process(dt: float) -> void:
	frames += 1
	if frames > 60 and frames <= 300: samples.append(dt*1000)
	if frames == 300:
		samples.sort()
		print("STRESS_UI frames=%d p50=%.3fms p95=%.3fms max=%.3fms" % [samples.size(),samples[samples.size()/2],samples[int(samples.size()*.95)],samples.back()])
'''


if __name__ == '__main__':
    target=ROOT/'output/stress-project'
    target.mkdir(parents=True,exist_ok=True)
    for name in ['game','assets','data']:
        shutil.copytree(ROOT/name,target/name,dirs_exist_ok=True)
    testing=target/'game/testing'
    testing.mkdir(exist_ok=True)
    shutil.copy2(ROOT/'tools/late_fixture.gd',testing/'late_fixture.gd')
    (testing/'stress.gd').write_text(HARNESS,encoding='utf8')
    (testing/'stress.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://game/testing/stress.gd" id="1"]\n[node name="Stress" type="Node"]\nscript = ExtResource("1")\n',encoding='utf8')
    project=(ROOT/'project.godot').read_text(encoding='utf8')
    project=re.sub(r'run/main_scene=.*', 'run/main_scene="res://game/testing/stress.tscn"',project)
    (target/'project.godot').write_text(project,encoding='utf8')
    presets=(ROOT/'export_presets.cfg').read_text(encoding='utf8')
    presets=presets.replace('.tools/templates/',(ROOT/'.tools/templates').as_posix()+'/')
    (target/'export_presets.cfg').write_text(presets,encoding='utf8')
    destination=ROOT/'builds/web-stress'
    destination.mkdir(parents=True,exist_ok=True)
    for args in [['--headless','--editor','--path',str(target),'--import'],
                 ['--headless','--path',str(target),'--export-release','Web',str(destination/'index.html')]]:
        result=subprocess.run([str(ENGINE),*args],cwd=ROOT,env=local_environment(),capture_output=True,text=True,encoding='utf8',errors='replace',timeout=180)
        log=result.stdout+result.stderr
        if result.returncode or 'ERROR:' in log:raise SystemExit(log)
    for path in (ROOT/'game').rglob('*'):
        if path.is_file():assert path.read_bytes()==(target/'game'/path.relative_to(ROOT/'game')).read_bytes()
    print('STRESS_WEB_READY '+str(destination))
