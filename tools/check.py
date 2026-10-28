"""Fail on engine errors even when an import/smoke process returns zero."""
from pathlib import Path
import subprocess
import sys
from godot import ENGINE, ROOT, local_environment

LOGS = []

def checked(command, required=None):
    process = subprocess.run(command, cwd=ROOT, env=local_environment(),
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             encoding='utf8', errors='replace', timeout=180)
    print(process.stdout, end='', flush=True)
    LOGS.append(process.stdout)
    (ROOT/'output/checks.log').write_text('\n'.join(LOGS),encoding='utf8')
    if process.returncode or 'ERROR:' in process.stdout or (required and required not in process.stdout):
        raise SystemExit(f'Check failed (exit {process.returncode}): {command}')
    return process.stdout

if __name__ == '__main__':
    output = ROOT / 'output'
    output.mkdir(exist_ok=True)
    (output/'.gdignore').touch()
    logs = []
    logs.append(checked([sys.executable,'tools/verify_balance.py'], 'failures=0'))
    logs.append(checked([sys.executable,'tools/verify_full_reference.py'], '"failures": 0'))
    logs.append(checked([sys.executable,'tools/verify_campaign.py'], '"failures": 0'))
    logs.append(checked([str(ENGINE),'--headless','--editor','--path','.','--import']))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/run_tests.gd'], 'failures=0'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_cadence.gd'], 'CADENCE_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_content_limits.gd'], 'CONTENT_LIMITS_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_expanded_gems.gd','--','--expanded-gems','--smoke'], 'EXPANDED_GEMS_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_campaign.gd','--','--campaign','--smoke'], 'CAMPAIGN_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_campaign_edges.gd','--','--campaign','--smoke'], 'CAMPAIGN_EDGES_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_trap_placement.gd','--','--campaign','--smoke'], 'TRAP_PLACEMENT_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_mechanics_parity.gd','--','--campaign','--smoke'], 'MECHANICS_PARITY_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_tower_moves.gd','--','--campaign','--smoke'], 'TOWER_MOVES_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_spells.gd','--','--campaign','--smoke'], 'SPELLS_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_ability_art.gd','--','--campaign','--smoke'], 'ABILITY_ART_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_ability_clips.gd','--','--campaign','--smoke'], 'ABILITY_CLIPS_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_tower_effects.gd','--','--campaign','--smoke'], 'TOWER_EFFECTS_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_quality_pass.gd','--','--campaign','--smoke'], 'QUALITY_PASS_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_leaderboard.gd','--','--campaign','--smoke'], 'LEADERBOARD_CHECK_OK'))
    logs.append(checked([sys.executable,'tools/check_leaderboard_transport.py'], 'LEADERBOARD_TRANSPORT_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_campaign_flight.gd','--','--campaign','--smoke'], 'CAMPAIGN_FLIGHT_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_proc_random.gd','--','--campaign','--smoke'], 'PROC_RANDOM_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_boss_discount.gd','--','--campaign','--smoke'], 'BOSS_DISCOUNT_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_combat_audit.gd','--','--campaign','--smoke'], 'COMBAT_AUDIT_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_movement_detection.gd','--','--campaign','--smoke'], 'MOVEMENT_DETECTION_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_aura_lifecycle.gd','--','--campaign','--smoke'], 'AURA_LIFECYCLE_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_readability.gd','--','--campaign','--smoke'], 'READABILITY_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_art.gd'], 'ART_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_cell_fit.gd'], 'CELL_FIT_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_enemy_frames.gd'], 'ENEMY_FRAMES_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_presentation.gd'], 'PRESENTATION_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_build_guide.gd'], 'BUILD_GUIDE_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_build_ui.gd','--','--smoke'], 'BUILD_UI_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_recipe_guide.gd'], 'RECIPE_GUIDE_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_recipe_ui.gd','--','--smoke'], 'RECIPE_UI_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_tower_info.gd'], 'TOWER_INFO_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_tower_ui.gd','--','--smoke'], 'TOWER_UI_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_wave_guide.gd'], 'WAVE_GUIDE_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_wave_ui.gd','--','--smoke'], 'WAVE_UI_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_review.gd'], 'REVIEW_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--script','res://tests/check_release_ui.gd','--','--smoke'], 'RELEASE_UI_CHECK_OK'))
    logs.append(checked([str(ENGINE),'--headless','--path','.','--quit-after','5','--','--smoke'], 'SMOKE_READY'))
    if '--exports' in sys.argv:
        logs.append(checked([str(ROOT/'builds/windows/GemTD.exe'),'--headless','--quit-after','5','--','--smoke'], 'SMOKE_READY platform=Windows'))
    (output/'checks.log').write_text('\n'.join(logs),encoding='utf8')
    print('CHECKS_OK')
