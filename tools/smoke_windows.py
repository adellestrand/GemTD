"""Render the actual exported Windows executable and verify generated audio samples."""
from array import array
from pathlib import Path
import json
import math
import subprocess
import sys
import wave
from godot import ROOT, local_environment

if __name__ == '__main__':
    attack = '--attack' in sys.argv
    campaign = '--campaign' in sys.argv
    output = ROOT/('output/campaign-native-attack' if campaign and attack else 'output/campaign-native' if campaign else 'output/native-attack' if attack else 'output/native-export')
    output.mkdir(parents=True,exist_ok=True)
    movie = output/'frame.png'
    process = subprocess.run([str(ROOT/'builds/windows/GemTD.exe'),
                              '--write-movie',str(movie),'--quit-after','20',
                              '--','--smoke','--smoke-attack' if attack else '--smoke-audio',*(['--campaign'] if campaign else [])],
                             cwd=ROOT,env=local_environment(),stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT,encoding='utf8',errors='replace',timeout=60)
    print(process.stdout)
    (output/'engine.log').write_text(process.stdout,encoding='utf8')
    if process.returncode or 'ERROR:' in process.stdout or 'SMOKE_READY' not in process.stdout:
        raise SystemExit('Exported Windows runtime failed.')
    with wave.open(str(output/'frame.wav'),'rb') as audio:
        width = audio.getsampwidth()
        if width not in (2,4):
            raise SystemExit(f'Unsupported PCM sample width: {width}')
        samples = array('h' if width == 2 else 'i',audio.readframes(audio.getnframes()))
        rms = math.sqrt(sum(s*s for s in samples)/max(1,len(samples)))
        rms /= float(2**(width*8-1))
    if rms < 0.00001 or not (output/'frame00000019.png').exists():
        raise SystemExit('Missing render or silent procedural audio.')
    result = dict(platform='Windows export',render='1360x900',frames=20,audio_cue='attack' if attack else 'place',audio_rms=round(rms,6))
    (output/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print('WINDOWS_RENDER_AUDIO_OK',json.dumps(result))
