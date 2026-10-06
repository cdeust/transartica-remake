#!/usr/bin/env python3
"""MIT. Reproducible measurements of delivered orchestral PCM and loop joins."""
import hashlib
import json
from pathlib import Path
import subprocess
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'game/assets/audio/orchestral'
EVIDENCE=ROOT/'tasks/validation/orchestral-score-20261006'
EVIDENCE.mkdir(parents=True,exist_ok=True)
report={}
for path in sorted(OUT.glob('*.wav')):
    with wave.open(str(path),'rb') as stream:
        rate=stream.getframerate()
        assert stream.getnchannels()==2 and stream.getsampwidth()==2
        pcm=np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').reshape(-1,2).astype(np.int32)
    half=len(pcm)//2
    steps=abs(np.diff(pcm,axis=0))
    values=pcm/32768
    report[path.stem]={'frames':len(pcm),'rate':rate,'duration_seconds':len(pcm)/rate,
        'peak_dbfs':float(20*np.log10(np.max(abs(values)))),
        'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(values**2)))),
        'dc_pcm':np.mean(pcm,axis=0).tolist(),'clipped_samples':int(np.sum(abs(pcm)>=32767)),
        'boundary_step_pcm':int(np.max(abs(pcm[half]-pcm[-1]))),
        'normal_max_step_pcm':int(steps.max()),'normal_99pct_step_pcm':float(np.percentile(steps,99)),
        'periods_identical':bool(np.array_equal(pcm[:half],pcm[half:])),
        'final_pcm':pcm[-1].tolist(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(path),'-lavfi',
        'showspectrumpic=s=1024x512:legend=1:scale=log:fscale=log','-frames:v','1',
        str(EVIDENCE/(path.stem+'-spectrogram.png'))],check=True)
(EVIDENCE/'measurements.json').write_text(json.dumps(report,indent=2)+'\n')
provenance=json.loads((ROOT/'.cache/orchestral-score/provenance.json').read_text())
(EVIDENCE/'sample-provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
print(json.dumps({name:{k:row[k] for k in ['peak_dbfs','rms_dbfs','boundary_step_pcm','clipped_samples','periods_identical']} for name,row in report.items()},indent=2))
