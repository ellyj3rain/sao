"""Exact private means feedback: production Lua choices and installed native visible-source identity.

Native scenes and result receivers are controlled. No rendered-world or learning-corpus acceptance.
The native identity slice reuses the previously passed, unchanged geometry/animation contracts.
"""
from pathlib import Path
import argparse,hashlib,json,os,subprocess
import recovery_placement_test as placement
import recovery_place_test as native
from native_proof_preflight import installed_presence

ROOT=placement.ROOT

def native_proof(out):
    base=native.base
    sources=[native.SOURCE,base.SOURCE,base.BRIDGE,native.PROBE,base.BOOT,
        ROOT/'java/src/com/sao/engine/SAORecoveryPose.java',ROOT/'java/src/com/sao/engine/SAOOrientationAnimation.java',
        ROOT/'tools/orienting_checks/RecoveryPoseProbe.java',ROOT/'tools/orienting_checks/OrientationProbe.java']
    jars=[base.GAME/'projectzomboid.jar',base.GAME/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar']
    paths=[*sources,*jars,Path(__file__),Path(native.__file__),Path(base.__file__)]
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, base.GAME, base.JDK, "physical means")
    if preflight is not None:
        raise SystemExit(preflight)
    pins=lambda:{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    out.mkdir(parents=True,exist_ok=True)
    receipt={'schema':'sao.physical-means-native-proof/1','status':'INCOMPLETE','boundary':__doc__,
        'inputs':pins(),'variants':[]}
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    save();cp=os.pathsep.join(map(str,jars));original=native.SOURCE.read_text(encoding='utf-8')
    variants=[('production',None,None,None),
        ('separate-visible-parts','return objectKey(resolved==null?object:resolved);','return objectKey(object);','visible_parts_share_exact_recovery_source'),
        ('infer-obscured-head','if(!visible(body,square,radius))return null;','if(square==null)return null;','obscured_head_identity_not_inferred')]
    for name,old,new,marker in variants:
        target=out/name;target.mkdir(exist_ok=True);source=original
        if old:
            assert source.count(old)==1,name
            source=source.replace(old,new,1)
        candidate=target/native.SOURCE.name;candidate.write_text(source,encoding='utf-8')
        compile_command=[base.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',target,candidate,*sources[1:]]
        compiled=subprocess.run(list(map(str,compile_command)),capture_output=True,text=True,timeout=120)
        (target/'compile.log').write_text(compiled.stdout+compiled.stderr,encoding='utf-8')
        assert compiled.returncode==0,compiled.stdout+compiled.stderr
        command=[base.JDK/'java.exe','-Duser.home='+str(target),'-Djava.awt.headless=true','-Dsao.test.meansIdentityOnly=true',
            '-Djava.library.path='+str(base.GAME),'-cp',str(target)+os.pathsep+cp,'RecoveryPlaceProbe']
        result=subprocess.run(list(map(str,command)),cwd=base.GAME,capture_output=True,text=True,timeout=120)
        log=result.stdout+result.stderr;(target/'run.log').write_text(log,encoding='utf-8')
        receipt['variants'].append({'name':name,'exit':result.returncode,'expected':marker,
            'command':list(map(str,command)),'cwd':str(base.GAME),'compileCommand':list(map(str,compile_command)),
            'compileExit':compiled.returncode,'mutation':{'before':old,'after':new} if old else None,
            'logSha256':hashlib.sha256(log.encode()).hexdigest()});save()
        assert (result.returncode!=0 and 'RECOVERY_PLACE:'+marker in log) if marker else (
            result.returncode==0 and 'PASS recovery means identity' in log),log
        print(name+': '+(marker or next(line for line in log.splitlines() if line.startswith('PASS recovery means'))),flush=True)
    receipt['inputsAfter']=pins();assert receipt['inputsAfter']==receipt['inputs'],'native proof inputs changed'
    receipt['status']='PASS';save()

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--part',choices=['lua','native'],required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--variants',nargs='+',help='Run only named Lua controls; retain existing independent passes.')
    args=parser.parse_args()
    try:
        if args.part=='native':native_proof(args.output.resolve())
        else:
            placement.OUT=args.output.resolve();placement.run(args.variants)
    except Exception as error:
        print('FAIL physical means: '+str(error),flush=True)
        raise SystemExit(1)
