"""Pinned original Lifestyle source in native Kahlua and native Stats.

Bodies, station identity, emitters, planner and event delivery are controlled;
this source qualification is distinct from an actual off-slot actor trial.
"""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,tempfile
from native_proof_preflight import installed_presence, installed_path
ROOT=Path(__file__).resolve().parents[1]
GAME=installed_path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
LS=GAME.parent.parent/'workshop/content/108600/3403870858/mods/Lifestyle/common/media/lua'
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
FIX=ROOT/'tools/d2_leisure_lifestyle';BASE=ROOT/'tools/d2_leisure_music'
OWNER=ROOT/'mod/42.20/media/lua/client/SAO_LeisureLifestyle.lua'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--baseline-only',action='store_true');a=p.parse_args()
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 text=OWNER.read_text(encoding='utf8');names=re.findall(r'\["([^"]+\.lua)"\]=\{',text)
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 jars=[GAME/'projectzomboid.jar',*sorted((GAME/'jars').glob('*.jar'))]
 inputs=[Path(__file__),ROOT/'tools/native_proof_preflight.py',OWNER,BASE/'MusicProbe.java',BASE/'prelude.lua',FIX/'prelude.lua',FIX/'cases.lua',*native,*jars,GAME/'stdlib.lua',*[LS/n for n in names]]
 absent=installed_presence(inputs,GAME,JDK,'D2 Lifestyle station source',installed_roots=(LS.parent,))
 if absent is not None:return absent
 before={str(q):sha(q)for q in inputs}
 receipt={'schema':'sao-d2-lifestyle-source/1','status':'INCOMPLETE','inputsBefore':before,'runs':[],
 'boundary':'Unchanged installed action constructors and source callback/effect/scheduler bodies, native Kahlua and Stats. Physical bodies, station and native visibility/hearing requery, emitters, queue, planner and event delivery are controlled. No loaded-game audio or gameplay claim.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8')
 def run(name,cmd,cwd):
  r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr)
  receipt['runs'].append({'name':name,'exitCode':r.returncode,'log':str(log),'sha256':sha(log)});save();return r.returncode,log.read_text(encoding='utf8',errors='replace')
 try:
  manifest=out/'sources.tsv';manifest.write_text(''.join('LifestyleHobbies:'+n+'\t'+str(LS/n)+'\n'for n in names),encoding='utf8')
  selected=(LS/'client/DJBoothContextMenu.lua').read_text(encoding='utf8')
  begin=selected.index('DJBoothMenu.onPlay = function(')
  end=selected.index('Events.OnFillWorldObjectContextMenu.Add(',begin)
  original_callback=out/'selected-original-onplay.lua'
  original_callback.write_text('DJBoothMenu={}\n'+selected[begin:end]
   +'\nDJBoothMenu.walkToFront=function()return true end\n',encoding='utf8')
  receipt['selectedOriginalOnPlaySha256']=sha(original_callback)
  with tempfile.TemporaryDirectory(prefix='sao-lifestyle-')as tmp:
   work=Path(tmp);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,BASE/'MusicProbe.java'],work);assert code==0,log
   controls=[('spoof','same(row,offer)','(true)','spoof_refused'),('body','SAO.Needs.ownsRecoveryBody(id,body)==true','true','foreign_body_refused'),
    ('hearing','SAO.Perception.canHearLeisureObject(id,body,row,8)==true','true','native_hearing_required'),
    ('sound','d.Emitter:isPlaying(d.OnPlayEMITTER)','true','actual_emitter_required'),
    ('revision','a~=pin[2]or b~=pin[3]or #lines~=pin[4]','(false)','source_drift_refused'),
    ('volume','function manager:setMusicVolume(value)self.volume=value end','function manager:setMusicVolume(value)getSoundManager():setMusicVolume(value)end','operator_volume_unchanged'),
    ('accounting','runEvents(a,name);a.lastMeasured=sample(a.body)','a.lastMeasured=sample(a.body)','native_accounting_applies_mood'),
    ('mix-ending','and a.inputRetiredHandle~=handle','and true','source_mix_not_terminal'),
    ('cleanup-fault','a.work.nativeProgress.cleanupAfterSourceFault=retireCaptured(a,action)','a.work.nativeProgress.cleanupAfterSourceFault=false','captured_cleanup_after_fault'),
    ('reload-offer','retireSaved(id)\n if runtime[id]','do end\n if runtime[id]','offer_archives_lost_runtime'),
    ('audience','invoke(a,"update",a.env.sourceDjAudience,a.body:getModData().LSMoodles.DJAudience.Value,audience)','do end','original_source_audience_moodle')]
   receipt['controls']=[]
   for name,old,new,marker in [('baseline',None,None,None)]+([]if a.baseline_only else controls):
    source=text
    if old:assert source.count(old)==1,(name,source.count(old));source=source.replace(old,new,1)
    variant=out/(name+'-owner.lua');variant.write_text(source,encoding='utf8')
    code,log=run(name,[JDK/'java.exe','--enable-native-access=ALL-UNNAMED','-Djava.awt.headless=true','-cp',str(work)+os.pathsep+cp,'MusicProbe',manifest,BASE/'prelude.lua',*native,LS/'shared/LSUtil.lua',FIX/'prelude.lua',LS/'shared/TimedActions/PlayDJBoothAction.lua',original_callback,variant,FIX/'cases.lua'],work)
    if marker:assert code!=0 and 'D2_LIFESTYLE:'+marker in log,(name,log[-5500:]);receipt['controls'].append({'name':name,'failure':marker})
    else:assert code==0 and 'PASS D2 Lifestyle 'in log,log[-8500:];receipt['checks']=int(re.search(r'PASS D2 Lifestyle (\d+)',log)[1])
  receipt['inputsAfter']={str(q):sha(q)for q in inputs};assert before==receipt['inputsAfter'],'input seal changed';receipt['status']='PASS';save();print('PASS D2 Lifestyle',receipt['checks'],len(receipt['controls']));return 0
 except Exception as error:receipt['status']='FAIL';receipt['error']=str(error);save();raise
if __name__=='__main__':raise SystemExit(main())
