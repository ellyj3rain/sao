"""Replay the preserved Java invocation. Written after observation; not itself executed during the audit."""
import json, pathlib, subprocess
receipt=json.loads((pathlib.Path(__file__).parent/'audit-probe-receipt.json').read_text(encoding='utf8'))
p=receipt['process']
r=subprocess.run(p['argv'],cwd=p['cwd'],capture_output=p['capture_output'],text=p['text'],timeout=p['timeout_seconds'])
print(r.stdout,end='')
print(r.stderr,end='')
raise SystemExit(r.returncode)
