"""Compile the imported runtime Lua with both installed Kahlua modes.

Original nonautoload snapshots are custody artifacts. This checks the actual
imported/adapted engine paths and the owned registry, without game execution.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);args=ap.parse_args()
    root=Path(__file__).resolve().parents[1];mod=root/'mod/42.20'
    game=Path(os.environ.get('PZ_GAME_DIR',r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
    jdk=Path(os.environ.get('JDK_BIN',r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
    manifest_path=mod/'media/SAOSources/manifest.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    files=sorted({mod/row['destination'] for row in manifest['files'] if row['kind']=='runtime-lua'})
    files += [mod/'media/lua/shared/SAO_SourceIntegration.lua',mod/'media/lua/shared/SAO_SourcePackageManifest.lua']
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    classes=out/'classes';classes.mkdir()
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    inputs=[Path(__file__),root/'tools/luacheck/LuaSyntax.java',game/'projectzomboid.jar',manifest_path,*files]
    pins={str(p):sha(p) for p in inputs}
    compile_run=subprocess.run([str(jdk/'javac.exe'),'-encoding','UTF-8','-cp',str(game/'projectzomboid.jar'),'-d',str(classes),str(root/'tools/luacheck/LuaSyntax.java')],capture_output=True,timeout=60)
    (out/'compile.log').write_bytes(compile_run.stdout+compile_run.stderr)
    if compile_run.returncode:raise RuntimeError(compile_run.stderr.decode(errors='replace'))
    arguments=['-cp',str(game/'projectzomboid.jar')+';'+str(classes),'LuaSyntax',*map(str,files)]
    argsfile=out/'syntax.args';argsfile.write_text('\n'.join('"'+a.replace('\\','/').replace('"','\\"')+'"' for a in arguments)+'\n',encoding='utf-8')
    run=subprocess.run([str(jdk/'java.exe'),'@'+str(argsfile)],cwd=game,capture_output=True,timeout=120)
    log=out/'syntax.log';log.write_bytes(run.stdout+run.stderr)
    text=run.stdout.decode(encoding='utf-8',errors='replace')
    failures=[line for line in text.splitlines() if line.startswith('FAIL\t')]
    unchanged=all(p.is_file() and sha(p)==pins[str(p)] for p in inputs)
    receipt={'status':'PASS' if run.returncode==0 and unchanged else 'FAIL','boundary':__doc__,'runtimeFiles':len(files),'normalAndDebugVerdicts':sum(line.startswith('OK\t') for line in text.splitlines()),'failures':failures,'exitCode':run.returncode,'inputs':pins,'inputsUnchanged':unchanged,'log':str(log),'logSha256':sha(log)}
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in receipt.items() if k not in {'inputs','boundary'}},indent=2))
    return 0 if receipt['status']=='PASS' else 1


if __name__=='__main__':raise SystemExit(main())
