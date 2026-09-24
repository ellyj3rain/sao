"""Inspect the current native movement boundary without opening a game."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
GAME = Path(r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid')
JDK = Path(r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin')
AGENT = ROOT / 'java/dist/SAOAgent.jar'

def execute(argv, cwd):
    result = subprocess.run(list(map(str, argv)), cwd=cwd, capture_output=True, text=True, timeout=60)
    return dict(exitCode=result.returncode, stdout=result.stdout, stderr=result.stderr)

with tempfile.TemporaryDirectory(prefix='sao-crossed-body-probe-') as tmp:
    cp = os.pathsep.join([str(AGENT), str(GAME / '*'), tmp])
    build = execute([JDK/'javac.exe', '-cp', cp, '-d', tmp, HERE/'CrossedBodyProbe.java'], tmp)
    result = execute([JDK/'java.exe', '-cp', cp, 'CrossedBodyProbe'], tmp) if build['exitCode'] == 0 else None
    receipt = dict(schema='sao.crossed-body-probe/1', agentJarSha256=hashlib.sha256(AGENT.read_bytes()).hexdigest(),
                   engineJarSha256=hashlib.sha256((GAME/'projectzomboid.jar').read_bytes()).hexdigest(), build=build, result=result,
                   limits='Allocated objects only establish bridge type admission. No native movement, complete character initialization, gameplay or save migration is exercised.')
    (HERE/'crossed-body-probe.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(receipt))
    raise SystemExit(build['exitCode'] or (result and result['exitCode']) or 0)
