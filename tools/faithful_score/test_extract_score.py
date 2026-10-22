"""Small extraction checks; original-source checks use ALIS_REFERENCE_SOURCE."""
import json
import os
from pathlib import Path
import tempfile
import subprocess
import unittest
from extract_score import audit, decode_word, instrument, validate_trace


class ExtractTests(unittest.TestCase):
    @unittest.skipUnless(os.environ.get("ALIS_REFERENCE_SOURCE"),"private reference not configured")
    def test_actual_c_observer_keeps_identical_triggers(self):
        source=Path(os.environ["ALIS_REFERENCE_SOURCE"])/"alis-source/src"
        observer=Path(__file__).with_name("observe_score.h").resolve()
        program='''#include "audio/audio.h"
sAudio audio; sMV2Audio mv2a;
u8 xread8(u32 at) {(void)at;return 0;}
s32 xread32(u32 at) {(void)at;return 0;}
'''+f'#include "{observer}"\n'+'''
int main(int argc,char **argv) {
 (void)argc;score_out=fopen(argv[1],"wb");
 mv2a.voices[0].freqsam=360;mv2a.tabfrq[360]=12345;
 score_trigger(&mv2a.voices[0],7);
 score_frame=882;score_trigger(&mv2a.voices[0],7);
 score_endvoice(&mv2a.voices[0],17);score_endvoice(&mv2a.voices[0],18);
 audio.mutaloop=882;mv2a.mumax=6;mv2a.muptr=5;mv2a.mucnt=64;
 score_advance();mv2a.muptr=0;mv2a.mucnt=65;score_advance();
 return fclose(score_out);
}
'''
        with tempfile.TemporaryDirectory() as directory:
            base=Path(directory);c=base/"test.c";binary=base/"observer";trace=base/"trace"
            c.write_text(program)
            subprocess.run(["cc","-O2","-I"+str(source),"-I/opt/homebrew/include",
                            str(c),"-L/opt/homebrew/lib","-lSDL2","-o",str(binary)],check=True,capture_output=True)
            subprocess.run([str(binary),str(trace)],check=True)
            events=[json.loads(line) for line in trace.read_text().splitlines()]
            triggers=[e for e in events if e["event"]=="trigger"]
            self.assertEqual([e["serial"] for e in triggers],[1,2])
            self.assertEqual([e["period"] for e in triggers],[360,360])
            self.assertEqual([e["rate_q16"] for e in triggers],[12345,12345])
            self.assertEqual([e["frame"] for e in events if e["event"]=="endvoice"],[899])
            self.assertEqual([e["frame"] for e in events if e["event"]=="loop"],[1764])

    def test_words_keep_effect_only_and_extended_instruments(self):
        self.assertEqual(decode_word(bytes.fromhex("01688e01")),
            {"raw":"01688e01","trigger":True,"period":360,"slot":7,"effect":14,"parameter":1})
        self.assertFalse(decode_word(bytes.fromhex("00000472"))["trigger"])
        self.assertEqual(decode_word(bytes.fromhex("11681000"))["slot"],16)

    def test_repeated_identical_notes_require_distinct_serials(self):
        raw=["01681000","00000000","00000000","00000000"]
        word=[decode_word(bytes.fromhex(item)) for item in raw]
        cue={"patterns":{"0":[{"words":word},{"words":word}]}}
        events=[]
        for i in range(2):
            events.extend([{"event":"row","pattern":0,"row":i,"raw":raw},
                {"event":"trigger","voice":0,"slot":0,"serial":i+1},
                {"event":"tick","frame":i*882,"frames":882}])
        events.append({"event":"complete","frame":1764})
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/"trace"
            path.write_text("".join(json.dumps(e)+"\n" for e in events))
            self.assertEqual(validate_trace(path,cue)["serials"],[2,0,0,0])
            events[4]["serial"]=1
            path.write_text("".join(json.dumps(e)+"\n" for e in events))
            with self.assertRaisesRegex(ValueError,"serial"):validate_trace(path,cue)

    @unittest.skipUnless(os.environ.get("ALIS_REFERENCE_SOURCE"),"private reference not configured")
    def test_nine_original_routes_and_unsupported_effect_bytes(self):
        source=Path(os.environ["ALIS_REFERENCE_SOURCE"])
        result=audit(source)["cues"]
        self.assertEqual(len(result),9)
        self.assertEqual(result["bojeu-0"]["orders"],[4,0,1,2,3])
        self.assertEqual(result["bojeu-0"]["patterns"]["1"][3]["words"][1]["raw"],"00000472")
        for selector in range(4):self.assertEqual(result[f"bolieu-{selector}"]["resource"],10+selector)
        original=(source/"alis-source/src/audio/music_v2.c").read_text()
        patched=instrument(original)
        self.assertEqual(patched.count("score_trigger(voice, instidx);"),1)
        with self.assertRaises(ValueError):instrument(patched)


if __name__=="__main__":unittest.main()
