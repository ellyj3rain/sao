"""Native personally visible Lifestyle station classifiers and current hearing.

Installed engine LOS, traits, square/object identity and hearing execute. Furniture
and residency are controlled physical fixtures. Playback/emission producer and
rendered gameplay remain separately qualified by their source owners.
"""
from pathlib import Path
import argparse,hashlib,json,os,subprocess
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parents[1]
GAME=Path(os.environ.get('PZ_GAME_DIR',r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
HERE=ROOT/'tools/d2_exercise_observation'
SOURCE=ROOT/'java/src/com/sao/engine/SAOConceptObservation.java'
BRIDGE=ROOT/'java/src/com/sao/bridge/SAOBridge.java'
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',required=True,type=Path)
    ap.add_argument('--jar',type=Path,default=ROOT/'mod/42.20/media/java/SAO.jar');args=ap.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    probe=ROOT/'tools/javacheck/ConceptObservationProbe.java';boot=ROOT/'tools/luacheck/MovementCrossingProbe.java'
    jars=[args.jar.resolve(),GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar']
    inputs=[Path(__file__),SOURCE,BRIDGE,probe,boot,HERE/'station_extra.java.inc',*jars]
    absent=installed_presence(inputs,GAME,JDK,'D2 leisure stations')
    if absent is not None:return absent
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    receipt={'status':'INCOMPLETE','boundary':__doc__,'inputsBefore':{str(p):sha(p)for p in inputs},'runs':[],'controls':[]}
    def seal():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def run(name,cmd):
        r=subprocess.run(list(map(str,cmd)),cwd=GAME,capture_output=True,timeout=90)
        log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr)
        receipt['runs'].append({'name':name,'exitCode':r.returncode,'logSha256':sha(log)});seal()
        return r.returncode,log.read_text(errors='replace')
    variants=[('production',None,None,None,None),
        ('jukebox-omitted',SOURCE,'if (name.equals("jukebox")) return "jukebox";','if (name.equals("jukebox")) return null;','jukebox_source_custom_name'),
        ('dj-center-omitted',SOURCE,'return "dj-booth";','return null;','dj_source_center_ls_djbooth_01_1'),
        ('dj-part-omitted',SOURCE,'return "dj-booth-part";','return null;','dj_source_part_ls_djbooth_01_0'),
        ('native-hearing-omitted',BRIDGE,'target!=null&&com.sao.engine.SAOPerceptionScanner.canHearSourceNow(body,target.getSquare(),(float)range)','target!=null','native_deaf_station_refused'),
        ('exact-instance-omitted',SOURCE,
         ['if (!key.equals(row.rawget("key")) || !instance.equals(row.rawget("runtimeInstance"))) continue;',
          '&& instance.equals(Integer.toHexString(System.identityHashCode(object))) ? object : null;'],
         ['if (!key.equals(row.rawget("key"))) continue;','? object : null;'],'foreign_native_instance_refused')]
    try:
        java=probe.read_text().replace('public final class ConceptObservationProbe','public final class D2StationProbe')
        java=java.replace('private static int checks;','private static int checks;\n'+(HERE/'station_extra.java.inc').read_text())
        java=java.replace('"Table")))','"Table","Jukebox","Booth")))')
        java=java.replace('System.out.println("PASS concept observation "+checks);','stations(body,cell);System.out.println("PASS concept observation "+checks);')
        generated=out/'D2StationProbe.java';generated.write_text(java,encoding='utf-8')
        cp=os.pathsep.join(map(str,jars));seal()
        for name,path,before,after,marker in variants:
            target=out/name;target.mkdir();files=[]
            for original in (SOURCE,BRIDGE):
                text=original.read_text()
                if path==original:
                    for old,new in zip(before if isinstance(before,list) else [before],after if isinstance(after,list) else [after]):
                        assert text.count(old)==1,(name,text.count(old));text=text.replace(old,new,1)
                candidate=target/original.name;candidate.write_text(text,encoding='utf-8');files.append(candidate)
            code,log=run(name+'-compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',target,*files,generated,boot]);assert code==0,log
            code,log=run(name,[JDK/'java.exe','-Duser.home='+str(target),'-Djava.awt.headless=true','-Djava.library.path='+str(GAME),'-cp',str(target)+os.pathsep+cp,'D2StationProbe'])
            if marker:
                assert code!=0 and 'CONCEPT:'+marker in log,(name,log[-4500:]);receipt['controls'].append({'name':name,'marker':marker})
            else:
                assert code==0 and 'PASS concept observation ' in log,log[-4500:]
                receipt['checks']=int(log.split('PASS concept observation ')[1].split()[0])
        receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsAfter']==receipt['inputsBefore'],'input drift'
        receipt['status']='PASS'
    except Exception as error:receipt['failure']=str(error);seal();print('FAIL',error);return 1
    seal();print('PASS native leisure stations',receipt['checks'],len(receipt['controls']));return 0
if __name__=='__main__':raise SystemExit(main())
