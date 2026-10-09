"""Actual installed native concept LOS, collections, parts and geometry.

Objects, rooms, placed item, vehicle part and geometry are controlled physical
fixtures. Device profile/state/playback, rendered perception and vehicle spawning
are outside this proof. The existing observer probe is extended, never altered.
"""
import argparse,hashlib,json,os,subprocess
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parents[2]
GAME=Path(os.environ.get('PZ_GAME_DIR',r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
SOURCE=ROOT/'java/src/com/sao/engine/SAOConceptObservation.java'
HERE=Path(__file__).parent
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--jar',type=Path,default=ROOT/'mod/42.20/media/java/SAO.jar');ap.add_argument('--baseline-only',action='store_true');args=ap.parse_args()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 probe=ROOT/'tools/javacheck/ConceptObservationProbe.java';boot=ROOT/'tools/luacheck/MovementCrossingProbe.java'
 jars=[args.jar.resolve(),GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar']
 files=[Path(__file__),SOURCE,probe,boot,HERE/'observation_extra.java.inc',*jars]
 absent=installed_presence(files,GAME,JDK,'D2 observation_test');
 if absent is not None:return absent
 receipt={'status':'INCOMPLETE','boundary':__doc__,'inputsBefore':{str(p):sha(p)for p in files},'runs':[],'controls':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,cwd):
  p=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=90)
  log=out/(name+'.log');log.write_bytes(p.stdout+p.stderr);receipt['runs'].append({'name':name,'exit':p.returncode,'log':str(log),'sha256':sha(log)});save()
  return p.returncode,log.read_text(errors='replace')
 variants=[('baseline',None,None,None),
  ('world-collection-omitted','var worldObjects = square.getWorldObjects();','var worldObjects = new java.util.ArrayList<IsoWorldInventoryObject>();','placed_actual_world_collection'),
  ('world-item-custody-bypass','item.getWorldItem() != object','false','placed_replaced_item_custody_refused'),
  ('vehicle-visibility-bypass','if (!custody && !SAOPerceptionScanner.canSeeWorldSquareNow(body, square, radius)) continue;','if (false) continue;','vehicle_hidden_native_wall_excluded'),
  ('vehicle-custody-bypass','seat >= 0 && vehicle.getCharacter(seat) == body','occupiedVehicle == vehicle','spoof_vehicle_without_native_seat_refused'),
  ('arcade-omitted','return "arcade-machine";','return null;','arcade_source_sprite_recreational_01_16'),
 ]
 if args.baseline_only:variants=variants[:1]
 try:
  java=probe.read_text().replace('public final class ConceptObservationProbe','public final class D2ObservationProbe')
  java=java.replace('private static int checks;', 'private static int checks;\n'+(HERE/'observation_extra.java.inc').read_text())
  java=java.replace('System.out.println("PASS concept observation "+checks);','extra(body,cell);System.out.println("PASS concept observation "+checks);')
  generated=out/'D2ObservationProbe.java';generated.write_text(java)
  cp=os.pathsep.join(map(str,jars))
  for name,before,after,marker in variants:
   target=out/name;target.mkdir();text=SOURCE.read_text()
   if before:assert text.count(before)==1,name;text=text.replace(before,after,1)
   candidate=target/'SAOConceptObservation.java';candidate.write_text(text)
   code,log=run(name+'-compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',target,candidate,generated,boot],ROOT);assert code==0,log
   code,log=run(name,[JDK/'java.exe','-Duser.home='+str(target),'-Djava.awt.headless=true','-Djava.library.path='+str(GAME),'-cp',str(target)+os.pathsep+cp,'D2ObservationProbe'],GAME)
   if marker:
    assert code!=0 and 'CONCEPT:'+marker in log,(name,log[-5000:]);receipt['controls'].append({'name':name,'marker':marker})
   else:
    assert code==0 and 'PASS concept observation' in log,log[-5000:]
    receipt['checks']=int(log.split('PASS concept observation ')[1].split()[0])
  receipt['inputsAfter']={str(p):sha(p)for p in files};assert receipt['inputsAfter']==receipt['inputsBefore'],'input drift'
  receipt['status']='PASS'
 except Exception as e:receipt['failure']=str(e);save();print('FAIL',e);return 1
 save();print('PASS expanded observation',receipt['checks'],len(receipt['controls']));return 0
if __name__=='__main__':raise SystemExit(main())
