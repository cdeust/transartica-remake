# PR44 correction validation

- Original head: 8de3910436d8a71c6ba0eef19c085cb3c1a5b6cd.
- Fixed Codex child usage and unchanged legacy threshold migration.
- 125 Python tests passed; coverage 95%; Ruff and pinned lock validation passed.
- 75 shell tests passed; ShellCheck 0.11.0 passed.
- Independent reviewer approved after custom-default regression was fixed.
- Native Codex 0.157.1 probe: plugin hook trust is required. Stop blocked, hookPrompt consumed, model wrote checkpoint, next Stop completed and parent turn completed.
- Native child probe: SubagentStop completed, parent aggregate recorded one child, and parent checkpoint surfaced billed tokens with unavailable cost. Events: native-child-evidence.jsonl.
- Isolated credential copy removed after probes. Nothing from .review is staged.

Next: commit, push to PR44 branch, verify CI, merge, install in actual Codex profile, verify loaded hook trust and hashes, then resume Transartica.

Completed: PR merged 52fe5935218b719a92b1f60f967b6b1300471fcf; installed context-guard@session-optimizer-codex 2.1.0 from main. Hook module bytes match reviewed code. Both active hooks trusted, exactly one context-guard pair loaded. Actual Astra thresholds180000/220000. Other plugin settings preserved. Old context-guard 2.0.0 removed. New sessions required to load the updated plugin.
