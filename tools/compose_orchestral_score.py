#!/usr/bin/env python3
"""MIT. Authored score, rendered from a bounded VSCO2 CE (CC0) sample subset.

All melody, harmony, tempo, orchestration and expression below are artistic
choices for this score, not reconstructions of historical Transarctica music.
Downloads and intermediate renders stay in .cache/orchestral-score.
"""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import urllib.parse
import wave

ROOT = pathlib.Path(__file__).resolve().parents[1]
CACHE = ROOT / '.cache/orchestral-score'
OUT = ROOT / 'game/assets/audio/orchestral'
REVISION = '440300901dfe9275fd84e0b7763af1f8443ae62e'
BASE = f'https://raw.githubusercontent.com/sgossner/VSCO-2-CE/{REVISION}/'
SFZ_REVISION = '6dd651d55dde97fd4028699be9d4481f26917891' # source: author SFZ branch tree.
MAPPINGS = {'strings':'ViolinEnsSusVib.sfz','cello':'CelloEnsSusVib.sfz',
            'horn':'FHornSus.sfz','flute':'FluteSusVib.sfz','harp':'Harp.sfz','timpani':'Timpani.sfz'}
# Author-recorded sustain samples at several roots avoid large transpositions.
SAMPLES = {
    'strings': [f'Strings/Violin Section/susVib/VlnEns_susVib_{n}_v1.wav' for n in ['D3','C4','G4']],
    'cello': [f'Strings/Cello Section/susvib/susvib_{n}_v1_1.wav' for n in ['C1','D2','C3']],
    'horn': [f'Brass/F Horn/sus/MOHorn_sus_{n}_v2_1.wav' for n in ['F2','C3','G1']],
    'flute': [f'Woodwinds/Flute/susvib/LDFlute_susvib_{n}_v1_1.wav' for n in ['C4','A4','C5']],
    'harp': [f'Strings/Harp/KSHarp_{n}_mf.wav' for n in ['C3','D4','C5']],
    'timpani': ['Percussion/Timpani/Timpani3_Hit_v3_rr1_Sum.wav'],
}


def fetch():
    CACHE.mkdir(parents=True, exist_ok=True)
    provenance = []
    for group, paths in {'license': ['LICENSE'], **SAMPLES}.items():
        for path in paths:
            target = CACHE / 'samples' / path
            target.parent.mkdir(parents=True, exist_ok=True)
            url = BASE + urllib.parse.quote(path, safe='/')
            if not target.exists():
                subprocess.run(['curl', '--fail', '--silent', '--show-error', '--location', '--max-time', '90', url, '-o', str(target)], check=True)
            content = target.read_bytes()
            if group == 'license' and not content.startswith(b'CC0 1.0 Universal'):
                raise ValueError('Author license is not the expected CC0 dedication')
            provenance.append({'group': group, 'path': path, 'url': url, 'sha256': hashlib.sha256(content).hexdigest(), 'bytes': len(content)})
    for path in MAPPINGS.values():
        target=CACHE/'mappings'/path
        target.parent.mkdir(parents=True,exist_ok=True)
        if not target.exists():
            subprocess.run(['curl','--fail','--silent','--show-error','--location','--max-time','90',
                f'https://raw.githubusercontent.com/sgossner/VSCO-2-CE/{SFZ_REVISION}/{path}','-o',str(target)],check=True)
        content=target.read_bytes()
        provenance.append({'group':'mapping','path':path,'url':f'https://raw.githubusercontent.com/sgossner/VSCO-2-CE/{SFZ_REVISION}/{path}',
                           'sha256':hashlib.sha256(content).hexdigest(),'bytes':len(content)})
    (CACHE / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')


def composition(name, bpm, mood="minor", work=False):
    """Eight 4/4 bars: two contrasting phrases, with continuous ensemble voicing."""
    major, dark = mood == "major", mood == "dark"
    # Deliberate original D-centred progression and a rising/falling motif.
    chords = [[50,57,62,65], [46,53,58,62], [48,55,60,64], [45,52,57,61]]
    if major:
        chords = [[50,57,62,66], [47,54,59,62], [43,50,55,59], [45,52,57,61]]
    if dark:
        chords = [[50,56,62,65], [46,53,58,61], [43,50,55,58], [45,52,57,61]]
    motif = [74,77 if not major else 78,81,79,77 if not major else 78,74,72,73]
    answer = [77 if not major else 78,81,86,84,81,79,77 if not major else 78,73]
    seconds = 60.0 / bpm
    events = []
    def note(part, pitch, timing, velocity):
        beat, beats = timing
        events.append({'part':part, 'note':pitch, 'start':beat*seconds, 'duration':beats*seconds, 'velocity':velocity})
    for bar in range(8):
        chord = chords[bar % 4]
        beat = bar*4
        # Stereo string voices, bass bow, quiet horns breathe between bars.
        for pitch in chord[1:]: note('strings',pitch+12,(beat,3.85),48+(bar%4)*4)
        note('cello',chord[0]-12,(beat,3.85),61)
        note('horn',chord[1],(beat+.2,2.7),42 if name=='cities' else 57)
        melody = motif if bar < 4 else answer
        for k in range(2):
            pitch = melody[(bar%4)*2+k]
            note('flute' if name in ['exploration','cities'] else 'strings',pitch,(beat+k*2+.12,1.65),61+(bar%3)*3)
        for k in range(8 if work else 4):
            note('harp',chord[k%4]+12,(beat+k*(.5 if work else 1),.8),41 if dark else 53)
        if name in ['title','worksite','danger']:
            note('timpani',38,(beat,.9),55 if name=='worksite' else 68)
            if name=='danger': note('cello',chord[0]-12,(beat+2,1.7),75)
    return {'name':name, 'bpm':bpm, 'seconds':32*seconds, 'events':events,
            'samples':{k:[str(CACHE/'samples'/p) for p in v] for k,v in SAMPLES.items()}}


def render():
    import numpy as np
    CACHE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    scores = [composition('exploration',84), composition('cities',76,mood='major'),
              composition('worksite',104,work=True), composition('danger',66,mood='dark'),
              composition('title',92,mood='major')]
    (CACHE/'score.json').write_text(json.dumps(scores,indent=2)+'\n')
    render_samples(scores)
    measurements = {}
    for score in scores:
        # Four cycles prime sampler/reverb memory; publish last two cycles.
        with wave.open(str(CACHE/(score['name']+'.wav')),'rb') as source:
            rate=source.getframerate(); count=round(score['seconds']*rate)
            source.setpos(count*2); data=source.readframes(count*2)
            if source.getsampwidth()!=2 or source.getnchannels()!=2:
                raise ValueError('Renderer must deliver stereo signed PCM16')
        target=OUT/(score['name']+'.wav')
        if score['name'] in ['cities','worksite','danger']:
            # Artistic two-beat cadence fade for source non-repeating cues.
            pcm=np.frombuffer(data,dtype='<i2').reshape(-1,2).copy()
            tail=round(120/score['bpm']*rate)
            pcm[-tail:]=np.rint(pcm[-tail:]*np.linspace(1,0,tail)[:,None]).astype('<i2')
            data=pcm.tobytes()
        with wave.open(str(target),'wb') as output:
            output.setnchannels(2);output.setsampwidth(2);output.setframerate(rate);output.writeframes(data)
        measurements[score['name']]={'bpm':score['bpm'],'sample_rate':rate,'loop_begin':count,'loop_end':count*2,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
    routes={'bojeu-0':'exploration','bojeu-1':'exploration','bojeu2-0':'exploration',
            'bolieu-0':'cities','bolieu-1':'cities','bolieu-2':'worksite','bolieu-3':'cities',
            'bolost-0':'danger','bopres-0':'title'}
    # source: decoded original cmusic calls, reference-private/audio/music.json.
    tracks={key:{'file':f'res://assets/audio/orchestral/{name}.wav',
                 'cycle':key.startswith('bojeu') or key=='bopres-0',
                 'duration_ticks':32000 if key.startswith('bojeu') else 1000 if key.startswith('bolieu') else 10000,
                 **{k:v for k,v in measurements[name].items() if k in ['loop_begin','loop_end']}}
            for key,name in routes.items()}
    (OUT/'music.json').write_text(json.dumps({'version':1,'authorship':'Original score for Transartica; not historical soundtrack transcription','sample_library':'VSCO2 CE, CC0-1.0','tracks':tracks},indent=2)+'\n')
    (CACHE/'measurements.json').write_text(json.dumps(measurements,indent=2)+'\n')
    print(json.dumps({'tracks':len(tracks),'compositions':len(scores),'output':str(OUT)}))


def _sample_banks(rate):
    """Decode the recorded samples at their unchanged author SFZ roots."""
    import numpy as np
    banks={}
    for part,paths in SAMPLES.items():
        mapping=(CACHE/'mappings'/MAPPINGS[part]).read_text()
        roots={}
        for region in mapping.split('<region>')[1:]:
            sample=re.search(r'sample=([^\r\n]+)',region)
            root=re.search(r'pitch_keycenter=(\d+)',region)
            if sample and root: roots[pathlib.PureWindowsPath(sample[1].strip()).name]=int(root[1])
        bank=[]
        for path in paths:
            name=pathlib.Path(path).name
            if name not in roots: raise ValueError(f'No author SFZ root for {name}')
            decoded=subprocess.check_output(['ffmpeg','-v','error','-i',str(CACHE/'samples'/path),'-f','f32le','-ar',str(rate),'-ac','2','-'])
            data=np.frombuffer(decoded,dtype='<f4').reshape(-1,2).copy()
            # Remove only near-silent lead-in, using a measured relative threshold.
            energy=np.max(abs(data),axis=1); audible=np.flatnonzero(energy>float(energy.max())*.01)
            if len(audible): data=data[max(0,int(audible[0])-round(.01*rate)):]
            bank.append((roots[name],data))
        banks[part]=bank
    return banks


def _render_note(event, banks, pans, rate):
    """Transpose and envelope one real sample without changing operation order."""
    import numpy as np
    root,sample=min(banks[event['part']],key=lambda pair:abs(pair[0]-event['note']))
    ratio=2**((event['note']-root)/12)
    release=.35 if event['part'] in ['strings','cello','horn','flute'] else .7 # Artistic bowed/breath/plucked release shapes.
    length=round((event['duration']+release)*rate)
    positions=np.arange(length)*ratio
    positions=positions[positions<len(sample)-1]
    note=np.column_stack([np.interp(positions,np.arange(len(sample)),sample[:,c]) for c in range(2)])
    envelope=np.ones(len(note))
    attack=min(len(note),round(.025*rate))
    envelope[:attack]=np.linspace(0,1,attack)
    tail=min(len(note),round(release*rate))
    envelope[-tail:]=np.linspace(1,0,tail)**2
    angle=(pans[event['part']]+1)*np.pi/4
    note*=envelope[:,None]*(event['velocity']/127)*np.array([np.cos(angle),np.sin(angle)])
    return note


def _render_phrase(score, banks, pans, rate):
    """Accumulate notes and circular reflections in their original order."""
    import numpy as np
    count=round(score['seconds']*rate)
    phrase=np.zeros((count,2),dtype=np.float64)
    for event in score['events']:
        note=_render_note(event,banks,pans,rate)
        # Circular addition retains the real room/sample release at loop wrap.
        offset=round(event['start']*rate)
        np.add.at(phrase,(np.arange(len(note))+offset)%count,note)
    # Artistic hall reflection pattern, no oscillators or synthetic instruments.
    dry=phrase.copy()
    for seconds,gain in [(.071,.12),(.113,.10),(.173,.08),(.251,.065),(.379,.045),(.521,.025)]:
        phrase+=gain*np.roll(dry[:,::-1],round(seconds*rate),axis=0)
    phrase-=phrase.mean(axis=0)
    # A measured peak determines gain; no hardcoded assumed input amplitude.
    peak=float(np.max(abs(phrase)))
    if peak==0:raise ValueError('Silent orchestral composition')
    phrase*=10**(-3/20)/peak # Artistic master headroom of3dB, not a safety threshold.
    return phrase


def _render_metrics(phrase, pcm, banks):
    import numpy as np
    return {'peak_dbfs':20*float(np.log10(np.max(abs(phrase)))),
        'rms_dbfs':20*float(np.log10(np.sqrt(np.mean(phrase**2)))),
        'loop_step_pcm':int(np.max(abs(pcm[0].astype(int)-pcm[-1].astype(int)))),
        'max_adjacent_step_pcm':int(np.max(abs(np.diff(pcm.astype(int),axis=0)))),
        'author_roots':{part:[root for root,_ in bank] for part,bank in banks.items()}}


def render_samples(scores):
    """Render recorded waveforms at author SFZ roots; deterministic circular hall.

    NumPy is the only Python dependency. FFmpeg decodes the author's PCM24 WAVs.
    Sustain durations are shorter than the recordings, so no invented sample loops.
    """
    import numpy as np
    rate=44100
    banks=_sample_banks(rate)
    pans={'strings':-.35,'cello':-.2,'horn':.3,'flute':.45,'harp':-.45,'timpani':0}
    metrics={}
    for score in scores:
        phrase=_render_phrase(score,banks,pans,rate)
        pcm=np.rint(phrase*32767).astype('<i2')
        metrics[score['name']]=_render_metrics(phrase,pcm,banks)
        with wave.open(str(CACHE/(score['name']+'.wav')),'wb') as output:
            output.setnchannels(2);output.setsampwidth(2);output.setframerate(rate)
            output.writeframes(np.tile(pcm,(4,1)).tobytes())
    (CACHE/'render-metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch',action='store_true')
    args=parser.parse_args()
    if args.fetch: fetch()
    else: render()
