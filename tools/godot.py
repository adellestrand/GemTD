"""Run the pinned portable engine with writable, project-local user data.

Usage: python tools/godot.py --headless --path . --script res://tests/run_tests.gd
The child environment is isolated; the parent process and Windows settings are unchanged.
"""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'

def local_environment():
    env = os.environ.copy()
    data = ROOT / '.tools/userdata'
    data.mkdir(parents=True, exist_ok=True)
    env['APPDATA'] = str(data)
    return env

if __name__ == '__main__':
    if not ENGINE.exists():
        raise SystemExit('Run powershell -ExecutionPolicy Bypass -File tools/bootstrap.ps1 first.')
    raise SystemExit(subprocess.call([str(ENGINE), *sys.argv[1:]], cwd=ROOT, env=local_environment()))
