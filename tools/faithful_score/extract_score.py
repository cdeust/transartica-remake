#!/usr/bin/env python3
"""MIT. Audit original ALIS words and instrument a separate reader copy.

Sources: alis.c:adresmus; music_v2.c:mv2_soundrout/mv2_soundvoix;
tools/prepare_music_preview.py and tools/package_music_capture.py.
No original file is edited. Capture requires an explicitly built copied reader.
"""
import argparse
from dataclasses import dataclass
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess

TRACKS = (("bojeu",0,13),("bojeu",1,14),("bojeu2",0,14),
          ("bolieu",0,10),("bolieu",1,11),("bolieu",2,12),("bolieu",3,13),
          ("bolost",0,0),("bopres",0,0))


def sha(data):
    return hashlib.sha256(data).hexdigest()


def resource_offset(data, index):
    integer=lambda at: struct.unpack_from(">i",data,at)[0]
    base=integer(14)  # source: alis.c:adresmus reads the resource-table pointer at +0x0e.
    count=struct.unpack_from(">H",data,base+16)[0]
    if not 0<=index<count:
        raise ValueError("resource index outside source table")
    pointer=base+integer(base+12)+index*4
    offset=pointer+integer(pointer)
    if not 0<=offset<len(data):
        raise ValueError("resource outside script")
    return offset


def decode_word(raw):
    if len(raw)!=4:
        raise ValueError("source row word must have four bytes")
    period,third,parameter=struct.unpack(">HBB",raw)
    # Match mv2_soundvoix's unsigned arithmetic, including no-trigger rows.
    slot=(((((third&0xf0)|(0x100 if period&0x1000 else 0))>>1)-8)&0xffff)>>3
    return {"raw":raw.hex(),"trigger":bool(period),"period":period&0x0fff,
            "slot":slot if period else None,"effect":third&15,"parameter":parameter}


def read_row(data, start, row):
    offset=start+row*16
    words=[decode_word(data[offset+ch*4:offset+ch*4+4]) for ch in range(4)]
    return {"row":row,"offset":offset,"words":words}


def read_patterns(data, offset, orders):
    # Source: music_v2.c:mv2_soundrout, 64 rows of four four-byte words.
    patterns={}
    for pattern in sorted(set(orders)):
        start=offset+8+0x84+pattern*0x400
        if start+0x400>len(data):
            raise ValueError("pattern outside script")
        patterns[str(pattern)]=[read_row(data,start,row) for row in range(64)]
    return patterns


def audit(source):
    result={"version":1,"cues":{}}
    for script,selector,index in TRACKS:
        data=(source/"unpacked"/(script+".alis")).read_bytes()
        offset=resource_offset(data,index)
        if data[offset]!=4:
            raise ValueError("expected PCM tracker resource type 4")
        count=data[offset+6]
        orders=list(data[offset+8:offset+8+count])
        if not count or len(orders)!=count:
            raise ValueError("invalid order table")
        patterns=read_patterns(data,offset,orders)
        result["cues"][f"{script}-{selector}"]={"script":script,"selector":selector,
            "resource":index,"resource_offset":offset,"script_sha256":sha(data),
            "orders":orders,"patterns":patterns}
    return result


def replace_once(text, old, new):
    if text.count(old)!=1:
        raise ValueError("instrumentation anchor changed: "+old[:80])
    return text.replace(old,new,1)


def instrument(text):
    text=replace_once(text,'void mv2_gomusic(void)\n{',
                      '#include "observe_score.h"\n\nvoid mv2_gomusic(void)\n{')
    text=replace_once(text,'    audio.muflag = 1;\n}\n\nvoid mv2_calculfrq',
                      '    score_start();\n    audio.muflag = 1;\n    score_run_offline();\n}\n\nvoid mv2_calculfrq')
    text=replace_once(text,'            noteat = mv2_soundvoix(noteat, &mv2a.voices[0]);',
                      '            score_row(noteat);\n            noteat = mv2_soundvoix(noteat, &mv2a.voices[0]);')
    text=replace_once(text,'        memset(audio.muadresse, 0, audio.mutaloop * 2);',
                      '        score_tick(1);\n        memset(audio.muadresse, 0, audio.mutaloop * 2);')
    text=replace_once(text,'        mv2_soundcal(&mv2a.voices[3]);\n    }\n}',
                      '        mv2_soundcal(&mv2a.voices[3]);\n    } else { score_tick(0); }\n    score_advance();\n}')
    text=replace_once(text,'}\n\nvoid mv2_checkcom(u32 noteat',
                      '    score_trigger(voice, instidx);\n}\n\nvoid mv2_checkcom(u32 noteat')
    text=replace_once(text,'            if (longsam2 == 0)\n                break;',
                      '            if (longsam2 == 0) {\n                score_endvoice(voice, (unsigned)index);\n                break;\n            }')
    text=replace_once(text,'void mv2_stopmusic(void)\n{\n    audio.muflag = 0;',
                      'void mv2_stopmusic(void)\n{\n    score_stop();\n    audio.muflag = 0;')
    return text


def prepare(source, scratch):
    source=source.resolve();scratch=scratch.resolve()
    if scratch.exists():
        raise ValueError("scratch must be a new task-owned directory")
    if scratch==source or source in scratch.parents:
        raise ValueError("scratch must be outside immutable reference source")
    report=audit(source)
    original=source/"alis-source"
    original_c=original/"src/audio/music_v2.c"
    patched=instrument(original_c.read_text())
    scratch.mkdir(parents=True)
    copied=scratch/"reader"
    shutil.copytree(original,copied,ignore=shutil.ignore_patterns(".git","build","CMakeFiles"))
    (copied/"src/audio/music_v2.c").write_text(patched)
    observer=Path(__file__).with_name("observe_score.h")
    shutil.copyfile(observer,copied/"src/audio/observe_score.h")
    preview_path=Path(__file__).resolve().parents[1]/"prepare_music_preview.py"
    spec=importlib.util.spec_from_file_location("prepare_music_preview",preview_path)
    preview=importlib.util.module_from_spec(spec);spec.loader.exec_module(preview)
    report["sources"]={"music_v2_sha256":sha(original_c.read_bytes()),
        "extractor_sha256":sha(Path(__file__).read_bytes()),
        "observer_sha256":sha(observer.read_bytes()),"instrumented_music_v2_sha256":sha(patched.encode()),
        "preview_sha256":sha(preview_path.read_bytes()),
        "reader_files":{str(p.relative_to(original)):sha(p.read_bytes())
            for p in sorted((original/"src").rglob("*")) if p.is_file()}}
    for script,selector,_ in TRACKS:
        key=f"{script}-{selector}"
        preview.prepare(source,scratch/"previews"/key,script,selector)
    (scratch/"audit.json").write_text(json.dumps(report,indent=2)+"\n")
    print("Prepared nine source audits and isolated reader:",copied)


def finalize_instrument(event, samples):
    data=(samples/event["resource_file"]).read_bytes()
    event["sha256"]=sha(data)
    event["payload_sha256"]=sha(data[event["payload_offset"]:])
    event["pcm_bytes"]=len(data)-event["payload_offset"]
    # Source: mv2_soundins and mv2_soundcal. The mixer's actual
    # indexing differs from interpreting header offsets as WAV loops.
    loop_length=event["source_loop_end_field"]-event["source_loop_start_field"]
    event["loop_pcm_length"]=loop_length
    event["loop_pcm_start"]=len(data)-32-loop_length
    event["initial_pcm_end"]=len(data)-32
    if len(data)!=event["resource_bytes"]:
        raise ValueError("instrument dump length mismatch")


def finalize(trace, samples):
    # Streaming rewrite keeps a large per-tick trace below the process memory cap.
    temporary=trace.with_suffix(".finalizing")
    completed=False;events=0;digests={}
    with trace.open() as src,temporary.open("w") as dst:
        for line in src:
            event=json.loads(line);events+=1
            if event["event"]=="instrument":
                finalize_instrument(event,samples)
                digests[str(event["slot"])]=event
            completed |= event["event"]=="complete"
            dst.write(json.dumps(event,separators=(",",":"))+"\n")
    if not completed:
        temporary.unlink()
        raise ValueError("capture lacks semantic completion")
    temporary.replace(trace)
    (samples/"manifest.json").write_text(json.dumps(digests,indent=2)+"\n")
    return events


def validate_row(event, cue, pending):
    if pending:
        raise ValueError("missing source trigger before next row")
    if cue.get("orders") and cue["orders"][event["order"]]!=event["pattern"]:
        raise ValueError("executed pattern differs from original order table")
    expected=cue["patterns"][str(event["pattern"])][event["row"]]["words"]
    if event["raw"]!=[word["raw"] for word in expected]:
        raise ValueError("executed row differs from original resource")
    return {voice:word for voice,word in enumerate(expected) if word["trigger"]}


def validate_trigger(event, pending, serials):
    voice=event["voice"];word=pending.pop(voice,None)
    if word is None or word["slot"]!=event["slot"]:
        raise ValueError("trigger has no corresponding source word")
    serials[voice]+=1
    if event["serial"]!=serials[voice]:
        raise ValueError("trigger serial omitted or duplicated")


def validate_tick(event, pending, last_tick):
    if pending:
        raise ValueError("missing source trigger before tick")
    if last_tick is not None and event["frame"]!=last_tick:
        raise ValueError("non-contiguous generated frame clock")
    return event["frame"]+event["frames"]


def validate_trace(trace, cue):
    """Cross-check executed row bytes and every trigger against original input."""
    serials=[0]*4;pending={};rows=triggers=0;last_tick=None;loops=[];complete=None
    with trace.open() as stream:
        for line in stream:
            event=json.loads(line);kind=event["event"]
            if kind=="row":
                pending=validate_row(event,cue,pending)
                rows+=1
            elif kind=="trigger":
                validate_trigger(event,pending,serials)
                triggers+=1
            elif kind=="tick":
                last_tick=validate_tick(event,pending,last_tick)
            elif kind=="loop":loops.append(event["frame"])
            elif kind=="complete":complete=event
    if pending or complete is None:raise ValueError("incomplete trace")
    return {"rows":rows,"triggers":triggers,"serials":serials,"loops":loops,"complete":complete}


@dataclass(frozen=True)
class CaptureOptions:
    offline: bool = False
    output_name: str | None = None


def capture(scratch, binary, cue, options=CaptureOptions()):
    report=json.loads((scratch/"audit.json").read_text())
    selected=report["cues"][cue]
    name=options.output_name or cue
    if Path(name).name!=name or name in (".",".."):
        raise ValueError("output name must be one directory component")
    out=scratch/"captures"/name
    out.mkdir(parents=True,exist_ok=False)
    samples=out/"samples";samples.mkdir()
    cycles=2 if selected["script"] in ("bojeu","bojeu2","bopres") else (1 if selected["script"]=="bolost" else 0)
    header={"event":"header","version":1,"rate":44100,"cue":cue,
        "script_sha256":selected["script_sha256"],"resource":selected["resource"],
        "sources":report["sources"],"binary_sha256":sha(binary.read_bytes()),
        "frame_origin":"first generated music buffer; no device-open silence",
        "cycles_requested":cycles,"offline":options.offline}
    env=os.environ.copy()
    env.update(ALIS_SCORE_TRACE=str(out/"score.ndjson"),ALIS_SCORE_SAMPLES=str(samples),
               ALIS_SCORE_HEADER=json.dumps(header,separators=(",",":")),ALIS_SCORE_CYCLES=str(cycles))
    env.pop("ALIS_SCORE_OFFLINE",None)
    if options.offline:env["ALIS_SCORE_OFFLINE"]="1"
    with (out/"reader.log").open("wb") as log:
        subprocess.run([str(binary),str(scratch/"previews"/cue)+"/"],env=env,
                       stdout=log,stderr=subprocess.STDOUT,check=True)
    events=finalize(out/"score.ndjson",samples)
    receipt=validate_trace(out/"score.ndjson",selected)
    (out/"validation.json").write_text(json.dumps(receipt,indent=2)+"\n")
    print(cue,events,"events",out/"score.ndjson")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest="command",required=True)
    p=sub.add_parser("prepare");p.add_argument("--source",type=Path,required=True);p.add_argument("--scratch",type=Path,required=True)
    p=sub.add_parser("capture");p.add_argument("--scratch",type=Path,required=True);p.add_argument("--binary",type=Path,required=True);p.add_argument("--cue",choices=[f"{s}-{n}" for s,n,_ in TRACKS],required=True)
    p.add_argument("--offline",action="store_true");p.add_argument("--output-name")
    args=parser.parse_args()
    if args.command=="prepare":prepare(args.source,args.scratch)
    else:capture(args.scratch.resolve(),args.binary.resolve(),args.cue,CaptureOptions(args.offline,args.output_name))


if __name__=="__main__":main()
