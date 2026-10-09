"""Three full source action repeat schedules in native Kahlua, exact package custody."""
import argparse,hashlib,json,os,re,subprocess,tempfile
from pathlib import Path
import d2_source_package as package
ROOT=Path(__file__).resolve().parents[1];MOD=ROOT/'mod/42.20';FIX=ROOT/'tools/d2_leisure_art'
GAME=Path('C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid');JDK=Path('C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--out',required=True,type=Path);args=parser.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 paths=sorted(package.LIFESTYLE_SOUND_INTERVAL_PATHS);clients=[p.replace('/shared/','/client/')for p in paths];mp=MOD/'media/SAOSources/manifest.json';current=json.loads(mp.read_text());before=ROOT/'_scratch/d2-leisure-01/art-sound-interval/before';previous=json.loads((before/'media/SAOSources/manifest.json').read_text())
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua'];runner=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java'
 inputs=[Path(__file__),ROOT/'tools/d2_source_package.py',mp,MOD/'media/lua/shared/SAO_SourcePackageManifest.lua',MOD/current['sources']['LifestyleHobbies']['sentinel'],runner,FIX/'fixture.lua',FIX/'interval_cases.lua',*native,GAME/'projectzomboid.jar',GAME/'stdlib.lua',*[MOD/p for p in paths+clients],*[MOD/'media/SAOSources/LifestyleHobbies'/p for p in paths+clients]];pins={str(p):sha(p)for p in inputs};receipt={'status':'INCOMPLETE','inputsBefore':pins,'runs':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 try:
  assert sum(a!=b for a,b in zip(previous['files'],current['files']))==3;assert previous['mergeRequired']==current['mergeRequired'];assert [s for s in current['sources']if previous['sources'][s]!=current['sources'][s]]==['LifestyleHobbies']
  for path in paths:
   raw=(MOD/'media/SAOSources/LifestyleHobbies'/path).read_bytes();old,_=package.adapt_lua(raw,'LifestyleHobbies');assert old==(before/path).read_bytes();new,_=package.adapt_lifestyle_sound_interval(old,path);assert new==(MOD/path).read_bytes();assert new.replace(b'\n\t\tself.soundTimeInterval = self.soundTime+self.doAnim',b'\n\t\tsoundTimeInterval = self.soundTime+self.doAnim',1)==old
   assert re.findall(r'soundTime\s*=\s*(\d+)',raw.decode('utf-8')) and set(re.findall(r'soundTime\s*=\s*(\d+)',raw.decode('utf-8')))=={'0'}
  for path in clients:
   old,_=package.adapt_lua((MOD/'media/SAOSources/LifestyleHobbies'/path).read_bytes(),'LifestyleHobbies');assert old==(MOD/path).read_bytes();assert package.adapt_lifestyle_sound_interval(old,path)==(old,[])
  with tempfile.TemporaryDirectory(prefix='sao-interval-')as tmp:
   work=Path(tmp);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes());cp=str(GAME/'projectzomboid.jar');result=subprocess.run([str(JDK/'javac.exe'),'-cp',cp,'-d',str(work),str(runner)],capture_output=True);(out/'compile.log').write_bytes(result.stdout+result.stderr);assert result.returncode==0
   stubCheck=out/'stub-check.lua';stubCheck.write_text("assert(LSCanvasAppraiseAction==nil and LSCheckYourself==nil and LSCheckYourselfAP==nil,'D2_SOURCE_INTERVAL:client_stubs_have_no_actions')\n")
   for name in ['production',*[Path(p).stem for p in paths]]:
    selected=[]
    for path in paths:
     source=MOD/path
     if Path(path).stem==name:source=out/(name+'-restored.lua');source.write_bytes((before/path).read_bytes())
     selected.append(source)
    command=[str(JDK/'java.exe'),'-cp',str(work)+os.pathsep+cp,'PhysicalMeansLuaProbe',str(FIX/'fixture.lua'),*map(str,native),*[str(MOD/p)for p in clients],str(stubCheck),*map(str,selected),str(FIX/'interval_cases.lua'),'--','__result'];result=subprocess.run(command,capture_output=True,cwd=work,timeout=35);log=out/(name+'.log');log.write_bytes(result.stdout+result.stderr);text=log.read_text(errors='replace');marker=None if name=='production'else'D2_SOURCE_INTERVAL:private_interval_advanced_'+name
    assert(result.returncode==0 and'PASS source intervals 39'in text)if marker is None else(result.returncode!=0 and marker in text),text
    receipt['runs'].append({'name':name,'exit':result.returncode,'expectedFailure':marker,'logSha256':sha(log)});save()
   spec=package.SOURCES['LifestyleHobbies'];workshop=work/'workshop';selected=workshop/spec[0]/spec[1];fakeMod=work/'mod'
   for path in paths+clients:
    target=selected/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((MOD/'media/SAOSources/LifestyleHobbies'/path).read_bytes())
   (selected/'mod.info').write_bytes((MOD/'media/SAOSources/LifestyleHobbies/provenance/selected-mod.info').read_bytes())
   allSources=package.SOURCES;package.SOURCES={'LifestyleHobbies':spec}
   try:
    _,outputs,_=package.build_plan(workshop,fakeMod)
    for path in paths+clients:assert outputs[path]==(MOD/path).read_bytes()
    from unittest.mock import patch
    with patch.object(package,'adapt_lifestyle_sound_interval',lambda raw,path:(raw,[])):
     _,wrong,_=package.build_plan(workshop,fakeMod);assert all(wrong[p]!=(MOD/p).read_bytes()for p in paths);assert all(wrong[p]==(MOD/p).read_bytes()for p in clients)
   finally:package.SOURCES=allSources
  receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsAfter']==pins;receipt.update(status='PASS',nativeSourceChecks=39,restoredControls=3,actualImporterAndOmissionControl=True,changedRows=3,unchangedRows=89518,clientStubsByteExact=True,defaultCatalogueSoundTimeZero=True,controlledNonzeroActionState=True);save();print('PASS39 native source repeat timing/isolation+3restored controls; actual importer/stub custody')
 except Exception as error:receipt.update(status='FAIL',error=str(error));save();raise
if __name__=='__main__':main()
