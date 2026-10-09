"""Pinned original Lifestyle source in native Kahlua and native Stats.

Bodies, station identity, emitters, planner and event delivery are controlled;
this source qualification is distinct from an actual off-slot actor trial.
"""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,tempfile
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from native_proof_preflight import installed_presence, installed_path
ROOT=Path(__file__).resolve().parents[2]
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
 music=ROOT/'mod/42.20/media/lua/client/SAO_LeisureMusic.lua';musicText=music.read_text();musicNames=re.findall(r'\["LifestyleHobbies:([^"]+\.lua)"\] =',musicText);names=list(dict.fromkeys(names+musicNames))
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 jars=[GAME/'projectzomboid.jar',*sorted((GAME/'jars').glob('*.jar'))]
 inputs=[Path(__file__),ROOT/'tools/native_proof_preflight.py',OWNER,music,BASE/'MusicProbe.java',BASE/'prelude.lua',FIX/'prelude.lua',FIX/'hearing-cases.lua',*native,*jars,GAME/'stdlib.lua',*[LS/n for n in names]]
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
  with tempfile.TemporaryDirectory(prefix='sao-lifestyle-')as tmp:
   work=Path(tmp);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,BASE/'MusicProbe.java'],work);assert code==0,log
   controls=[('hearing','and SAOJavaBridge:canConverseNow(a.body,body,8)==true','and true','native_directed_hearing_required'),
    ('source-flag','and a.body:getModData().PlayingInstrument==true','and true','source_flag_required'),
    ('source-sound','and a.body:getEmitter():isPlaying(handle)','and true','actual_current_performer_sound_required'),
    ('dj-hearing','and SAOJavaBridge:canConverseNow(a.body,body,8)==true','and true','DJ_directed_hearing_required')]
   receipt['controls']=[]
   for name,old,new,marker in [('baseline',None,None,None)]+([]if a.baseline_only else controls):
    source=text if name.startswith('dj-')else musicText
    if old:assert source.count(old)==1,(name,source.count(old));source=source.replace(old,new,1)
    variant=out/(name+'-music.lua');variant.write_text(musicText if name.startswith('dj-')else source,encoding='utf8')
    lifestyle=out/(name+'-lifestyle.lua');lifestyle.write_text(source if name.startswith('dj-')else text,encoding='utf8')
    code,log=run(name,[JDK/'java.exe','--enable-native-access=ALL-UNNAMED','-Djava.awt.headless=true','-cp',str(work)+os.pathsep+cp,'MusicProbe',manifest,BASE/'prelude.lua',*native,LS/'shared/LSUtil.lua',FIX/'prelude.lua',variant,lifestyle,FIX/'hearing-cases.lua'],work)
    if marker:assert code!=0 and 'D2_LIFESTYLE_HEARING:'+marker in log,(name,log[-5500:]);receipt['controls'].append({'name':name,'failure':marker})
    else:assert code==0 and 'PASS Lifestyle hearing 'in log,log[-8500:];receipt['checks']=int(re.search(r'PASS Lifestyle hearing (\d+)',log)[1])
  receipt['inputsAfter']={str(q):sha(q)for q in inputs};assert before==receipt['inputsAfter'],'input seal changed';receipt['status']='PASS';save();print('PASS Lifestyle hearing',receipt['checks'],len(receipt['controls']));return 0
 except Exception as error:receipt['status']='FAIL';receipt['error']=str(error);save();raise
if __name__=='__main__':raise SystemExit(main())
