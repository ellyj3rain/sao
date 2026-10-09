"""Exact private Music caller -> pinned original dance -> action-owned fields."""
import argparse,json,os,subprocess,sys,tempfile,shutil,re
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import d2_leisure_music_test as music
import d2_leisure_music.world_audio_test as world
from native_proof_preflight import installed_presence
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',required=True,type=Path);a=ap.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 native=[music.GAME/'media/lua/shared/ISBaseObject.lua',music.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua'];jars=[music.GAME/'projectzomboid.jar',*sorted((music.GAME/'jars').glob('*.jar'))]
 cases=music.FIXTURES/'action-binding-cases.lua';inputs=[Path(__file__),Path(music.__file__),Path(world.__file__),music.ROOT/'tools/native_proof_preflight.py',music.OWNER,music.ORG,cases,music.FIXTURES/'prelude.lua',music.FIXTURES/'MusicProbe.java',music.FIXTURES/'world-audio-cases.lua',*native,*jars,music.GAME/'stdlib.lua',*[music.LS/n for n in music.LS_FILES],*[music.NM/n for n in music.NM_FILES+music.NM_PROOF_FILES+world.EXTRA]]
 absent=installed_presence(inputs,music.GAME,music.JDK,'Music private action bindings',installed_roots=(music.LS.parent,music.NM.parent))
 if absent is not None:return absent
 receipt={'status':'INCOMPLETE','inputsBefore':{str(p):music.sha(p)for p in inputs},'runs':[],'controls':[],'boundary':'Actual production M.offers/begin/work -> whole pinned original dance source in private environment, native Kahlua/Stats. Actor/body/queue/native hearing/audio/rendering and clock hosts controlled. Canonical begin nonzero default retained; zero actionType is separately varied source public input. Native actual off-slot two-hand custody qualified in companion native01, not this fixture.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,cwd):
  r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=90);p=out/(name+'.log');p.write_bytes(r.stdout+r.stderr);receipt['runs'].append({'name':name,'exitCode':r.returncode,'logSha256':music.sha(p)});save();return r.returncode,p.read_text(errors='replace')
 save()
 try:
  keys={**music.pins(),**{'NewMusic:'+n:[]for n in music.NM_PROOF_FILES+world.EXTRA}};manifest=out/'source-paths.tsv';manifest.write_text(''.join(k+'\t'+str((music.LS if k.startswith('LifestyleHobbies:')else music.NM)/k.split(':',1)[1])+'\n'for k in keys))
  combined=out/'combined.lua';combined.write_text((music.FIXTURES/'world-audio-cases.lua').read_text().split('local function offer()')[0]+cases.read_text())
  target='code=changed;env.danceOwnershipSites[#env.danceOwnershipSites+1]={original=binding[1],derived=binding[2]}'
  variants=[('baseline',None,None),('original-hand-read','not self.character:isItemInBothHands(handItemP)','D2_BINDING:live_start_uses_own_primary'),('original-time-read','elseif AnimTime ~= 0','D2_BINDING:public_zero_type_ignores_foreign_ambient_time')]
  with tempfile.TemporaryDirectory(prefix='sao-private-dance-bindings-')as temp:
   work=Path(temp);shutil.copyfile(music.GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars));code,log=run('compile',[music.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,music.FIXTURES/'MusicProbe.java'],work);assert code==0,log
   for name,old,marker in variants:
    text=music.OWNER.read_text()
    if old:
     assert text.count(target)==1;text=text.replace(target,'if binding[1]~='+json.dumps(old)+'then code=changed end;env.danceOwnershipSites[#env.danceOwnershipSites+1]={original=binding[1],derived=binding[2]}',1)
    p=out/(name+'-owner.lua');p.write_text(text)
    code,log=run(name,[music.JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'MusicProbe',manifest,music.FIXTURES/'prelude.lua',*native,music.LS/'shared/LSUtil.lua',music.ORG,p,combined],work)
    if marker:assert code!=0 and marker in log,(name,log[-5000:]);receipt['controls'].append(name)
    else:assert code==0,log[-8000:];receipt['checks']=int(re.search('PASS private action bindings (\\d+)',log)[1])
  receipt['inputsAfter']={str(p):music.sha(p)for p in inputs};assert receipt['inputsAfter']==receipt['inputsBefore'];receipt['status']='PASS';save();print('PASS private action bindings',receipt['checks'],len(receipt['controls']))
 except Exception as e:receipt.update(status='FAIL',error=str(e));save();raise
if __name__=='__main__':main()
