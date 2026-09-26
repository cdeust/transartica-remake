# PR44 Codex review

Reviewed exact remote head `8de3910436d8a71c6ba0eef19c085cb3c1a5b6cd`.
Verdict: request changes for the advertised full Codex support. The main Stop
usage reader is useful; SubagentStop is not adapted yet.

1. P2: Codex SubagentStop is installed but silently records zero agents.
   `plugins/context-guard/hooks/subagent-tracker.py:153` reads only
   `transcript_path`; line 158 additionally requires an `agent-` basename.
   Codex supplies the child's `agent_transcript_path` and names rollouts
   `rollout-*.jsonl`. Its usage parser also remains Claude-only. The new
   Codex manifest activates this unchanged hook. Reproduction with a child
   containing 1000 input / 100 output tokens yields count=0 and all totals=0.
   Adapt path selection and usage parsing, or explicitly remove this hook
   from the advertised Codex scope until supported.

2. P2: Astra's advertised hard threshold is lost with the bundled statusline
   configuration. The new row is only in `FALLBACK_THRESHOLDS` at
   `plugins/context-guard/hooks/stop-context-guard.py:96`; loading the existing
   JSON replaces that entire table. `plugins/statusline/assets/ctxguard-thresholds.json`
   lacks Astra. Reproduction: no config gives (180000,220000), bundled config
   gives (180000,200000). Update the shared config and cover coexistence.

Verification on the unchanged PR source:
- Pinned dependencies installed with `--require-hashes --no-deps`.
- Python suite: 115 passed; coverage 95% (Python 3.12.11 locally, CI uses 3.11).
- Ruff lint/format and lock-drift checks passed.
- `.review/test_codex_gaps.py`: two independently added expected-behavior
  tests fail; raw output in `.review/gaps.log`.
- Reader compared with 6 actual local Codex rollouts and their per-request input counters, without
  exporting transcript content. Cached input is correctly treated as a subset.
- Remote head rechecked; CI test and CodeQL green.

Native lifecycle remains unproven by this review. The PR's direct subprocess
test demonstrates payload handling, not that an interactive Codex host fires
Stop and consumes decision:block. Installation success does not prove that
lifecycle either. No plugin was installed into the owner's live configuration;
no review was published and no branch was changed.
