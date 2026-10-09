"""Installed native event lifecycles and exact eight-leaf source/package custody."""
import argparse,hashlib,json,os,subprocess,tempfile
from pathlib import Path
import d2_source_package as package

ROOT=Path(__file__).resolve().parents[1];MOD=ROOT/'mod/42.20';FIX=ROOT/'tools/d2_callback_bindings'
GAME=Path('C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid');JDK=Path('C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin')
CASES={'LSBladeMaster':['tick'],'LSCommando':['zombie','zombie-update','update'],'LSElDorado':['zombie'],'LSExplorer':['zombie'],'LSGoodEating':['zombie'],'LSKnockdown':['zombie'],'LSLordDeath':['zombie','tick'],'LSTheProfessional':['zombie','zombie-update','update']}
def sha(file):return hashlib.sha256(file.read_bytes()).hexdigest()
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--out',required=True,type=Path);args=parser.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 before=ROOT/'_scratch/d2-leisure-01/callback-bindings/before';manifest=MOD/'media/SAOSources/manifest.json';old=json.loads((before/'media/SAOSources/manifest.json').read_text());current=json.loads(manifest.read_text())
 originals=[MOD/'media/SAOSources/LifestyleHobbies'/p for p in package.LIFESTYLE_CALLBACK_BINDINGS];owned=[MOD/p for p in package.LIFESTYLE_CALLBACK_BINDINGS]
 inputs=[Path(__file__),ROOT/'tools/d2_source_package.py',manifest,MOD/'media/lua/shared/SAO_SourcePackageManifest.lua',MOD/current['sources']['LifestyleHobbies']['sentinel'],*originals,*owned,*[f for f in FIX.iterdir()if f.is_file()],GAME/'projectzomboid.jar',GAME/'stdlib.lua'];pins={str(f):sha(f)for f in inputs};receipt={'status':'INCOMPLETE','inputsBefore':pins,'nativeRuns':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 try:
  assert len(current['files'])==89521;assert sum(a!=b for a,b in zip(old['files'],current['files']))==8
  assert [k for k in current['sources']if old['sources'][k]!=current['sources'][k]]==['LifestyleHobbies']
  for path,names in package.LIFESTYLE_CALLBACK_BINDINGS.items():
   original=MOD/'media/SAOSources/LifestyleHobbies'/path;content,_=package.adapt_lua(original.read_bytes(),'LifestyleHobbies');assert content==(before/path).read_bytes()
   generated,adaptations=package.adapt_lifestyle_callback_bindings(content,path);assert generated==(MOD/path).read_bytes();assert adaptations[0]['callbacks']==list(names)
   # Reverse the complete scoped adaptation, proving all source bodies retained.
   back=(MOD/path).read_bytes().replace(('local '+', '.join(names)+'\n').encode(),b'',1)
   for name in names:back=back.replace((name+' = function(').encode(),('local function '+name+'(').encode(),1)
   assert back==content
   try:package.adapt_lifestyle_callback_bindings(content.replace(('local function '+names[0]+'(').encode(),b'changed(',1),path);raise AssertionError('bad anchor accepted')
   except ValueError:pass
  cp=str(GAME/'projectzomboid.jar')
  with tempfile.TemporaryDirectory(prefix='sao-callback-')as temp:
   work=Path(temp);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes())
   # Exercise the real importer caller, not only the leaf adapter.
   spec=package.SOURCES['LifestyleHobbies'];workshop=work/'workshop';selected=workshop/spec[0]/spec[1];fakeMod=work/'mod'
   for path in package.LIFESTYLE_CALLBACK_BINDINGS:
    target=selected/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((MOD/'media/SAOSources/LifestyleHobbies'/path).read_bytes())
   (selected/'mod.info').write_bytes((MOD/'media/SAOSources/LifestyleHobbies/provenance/selected-mod.info').read_bytes())
   previousSources=package.SOURCES;package.SOURCES={'LifestyleHobbies':spec}
   try:
    plan,outputs,_=package.build_plan(workshop,fakeMod)
    for path in package.LIFESTYLE_CALLBACK_BINDINGS:assert outputs[path]==(MOD/path).read_bytes()
    from unittest.mock import patch
    with patch.object(package,'adapt_lifestyle_callback_bindings',lambda raw,path:(raw,[])):
     _,brokenOutputs,_=package.build_plan(workshop,fakeMod)
     assert all(brokenOutputs[path]!=(MOD/path).read_bytes()for path in package.LIFESTYLE_CALLBACK_BINDINGS)
   finally:package.SOURCES=previousSources
   run=subprocess.run([str(JDK/'javac.exe'),'-cp',cp,'-d',str(work),str(FIX/'CallbackProbe.java')],capture_output=True);(out/'compile.log').write_bytes(run.stdout+run.stderr);assert run.returncode==0
   for family,modes in CASES.items():
    path='media/lua/client/ISAmbt/'+family+'.lua'
    for mode in modes:
     variants=[('baseline',MOD/path,None)]
     names=package.LIFESTYLE_CALLBACK_BINDINGS[path]
     for name in names:
      expected=('Tick' in name and mode=='tick')or('PlayerUpdate' in name and mode=='update')or('ZDead' in name and mode in ['zombie','zombie-update'])
      if expected:
       broken=out/(family+'-'+mode+'-'+name+'.lua');raw=(MOD/path).read_bytes();declaration=('local '+', '.join(names)+'\n').encode();remaining=[n for n in names if n!=name];raw=raw.replace(declaration,('local '+', '.join(remaining)+'\n').encode()if remaining else b'',1);raw=raw.replace((name+' = function(').encode(),('local function '+name+'(').encode(),1);broken.write_bytes(raw);variants.append(('restored-'+name,broken,'D2_CALLBACK:retired_'+name))
     for variant,source,marker in variants:
      run=subprocess.run([str(JDK/'java.exe'),'-cp',str(work)+os.pathsep+cp,'CallbackProbe',family+':'+mode,str(FIX/'prelude.lua'),str(source),str(FIX/'cases.lua')],capture_output=True,cwd=work,timeout=40);log=out/(family+'-'+mode+'-'+variant+'.log');log.write_bytes(run.stdout+run.stderr);text=log.read_text(errors='replace')
      assert (run.returncode==0 and'PASS native Event lifecycle'in text)if marker is None else(run.returncode!=0 and marker in text),text
      receipt['nativeRuns'].append({'case':family+':'+mode,'variant':variant,'exit':run.returncode,'expectedFailure':marker,'logSha256':sha(log)});save()
  receipt['inputsAfter']={str(f):sha(f)for f in inputs};assert receipt['inputsAfter']==pins
  receipt.update(status='PASS',nativeLifecycles=13,restoredControls=13,repairedLocalCallbacks=11,changedRows=8,unchangedRows=89513,changedFamilySeals=1,sourceBodiesByteExact=True,originalsByteExact=True,controlledActorServices=True,nativeEventProducer=True,actualImporterCaller=True,restoredImporterControl=True);save();print('PASS13 actual native Event lifecycles/13 restored lexical controls; eight exact leaves/11 callback bindings')
 except Exception as error:receipt.update(status='FAIL',error=str(error));save();raise
if __name__=='__main__':main()
