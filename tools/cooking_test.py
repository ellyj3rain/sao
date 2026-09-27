#!/usr/bin/env python3
"""Border 204: native cooking, physical lifecycle and actual Controller/Body joins."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

def main():
    here=Path(__file__).resolve().parent
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',nargs='?',type=Path,default=here.parent)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    root=args.root.resolve()
    game=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
    jdk=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
    if not (game/'projectzomboid.jar').is_file() or not (jdk/'javac.exe').is_file() or not (jdk/'java.exe').is_file():
        print('  204) SKIPPED -- installed game and JDK required for native cooking proof')
        return 0
    with tempfile.TemporaryDirectory(prefix='sao-cooking-gate-') as temporary:
        output=(args.output or Path(temporary)).resolve()
        output.mkdir(parents=True,exist_ok=True)
        proofs={}
        for name in ['native','lua','inspection','join']:
            result=subprocess.run([sys.executable,str(here/'cooking_checks'/('run_'+name+'.py')),
                str(root),'--output',str(output)],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=240)
            path=output/(name+'-verification.json')
            if result.returncode or not path.is_file():
                print(result.stdout);print(result.stderr)
                print('  204) FAULT -- cooking '+name+' proof');return 1
            receipt=json.loads(path.read_text(encoding='utf-8'))
            if receipt.get('status')!='passed':
                print(result.stdout);print('  204) FAULT -- cooking '+name+' proof');return 1
            proofs[name]={'cases':receipt['cases'],'controls':len(receipt['controls'])}
            print('  cooking '+name+': '+str(proofs[name]['cases'])+' cases, '+str(proofs[name]['controls'])+' controls',flush=True)
        total=sum(v['cases'] for v in proofs.values())
        controls=sum(v['controls'] for v in proofs.values())
        (output/'cooking-verification.json').write_text(json.dumps({'status':'passed','proofs':proofs,
            'cases':total,'controls':controls},indent=2)+'\n',encoding='utf-8')
        print('  204) PASS -- cooking '+str(total)+' checks; '+str(controls)+' named defect controls')
    return 0
if __name__=='__main__':raise SystemExit(main())
