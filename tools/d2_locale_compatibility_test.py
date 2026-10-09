"""Current native locale loading/source callback and exact imported-generation custody."""
from pathlib import Path
import argparse, hashlib, json, os, subprocess, tempfile
import d2_source_package as p
import sandbox_surface as scanner

ROOT=Path(__file__).resolve().parents[1];MOD=ROOT/'mod/42.20';FIX=ROOT/'tools/d2_locale_compatibility'
GAME=Path('C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid');JDK=Path('C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin')
def sha(file):return hashlib.sha256(file.read_bytes()).hexdigest()

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--out',required=True,type=Path);args=parser.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 base=ROOT/'_scratch/d2-leisure-01/locale-compatibility';before=base/'before';manifest=MOD/'media/SAOSources/manifest.json';original=json.loads((before/'mod/42.20/media/SAOSources/manifest.json').read_text());current=json.loads(manifest.read_text());owner=MOD/'media/lua/shared/RadioCom/zISRadioInteractions_lsHook.lua';deprecated=MOD/'media/lua/client/RadioCom/TVRADIOTraits_ISRadioInteractions.lua';vault=MOD/'media/SAOSources/LifestyleHobbies/media/lua/shared/RadioCom/zISRadioInteractions_lsHook.lua'
 jars=[GAME/'projectzomboid.jar',*sorted((GAME/'jars').glob('*.jar'))];inputs=[Path(__file__),ROOT/'tools/d2_source_package.py',ROOT/'tools/sandbox_surface.py',ROOT/'tools/menu_reach.py',manifest,owner,vault,deprecated,*sorted(FIX.iterdir()),GAME/'stdlib.lua',*jars,*[GAME/'media/lua/shared/Translate/EN'/(n+'.json')for n in ['ContextMenu','Tooltip','IG_UI']],*[MOD/path for path in p.LIFESTYLE_LOCALE_COMPATIBILITY]]
 inputs += [MOD/'media/lua/shared/SAO_SourcePackageManifest.lua',*[MOD/source['sentinel']for source in current['sources'].values()],*[MOD/'media/SAOSources/Merged'/path for path in p.LIFESTYLE_LOCALE_COMPATIBILITY],*[MOD/'media/SAOSources/LifestyleHobbies'/path for path in p.LIFESTYLE_LOCALE_COMPATIBILITY],MOD/'media/SAOSources/LifestyleHobbies/provenance/selected-mod.info']
 pins={str(f):sha(f)for f in inputs};receipt={'status':'INCOMPLETE','inputsBefore':pins,'nativeRuns':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 try:
  different=[(a,b)for a,b in zip(original['files'],current['files'])if a!=b];assert len(different)==13
  assert len(current['files'])==89521;assert sum(original['sources'][k]['seal']!=v['seal']for k,v in current['sources'].items())==6
  assert (before/'mod/42.20/media/lua/client/RadioCom/TVRADIOTraits_ISRadioInteractions.lua').read_bytes()==deprecated.read_bytes()
  generated,adaptations=p.adapt_lua(vault.read_bytes(),'LifestyleHobbies');generated,extra=p.adapt_lifestyle_native_locale(generated,'media/lua/shared/RadioCom/zISRadioInteractions_lsHook.lua');assert generated==owner.read_bytes()
  assert generated.replace(b'getText("IGUI_perks_MetalWelding"), Perks.MetalWelding',b'getText("IGUI_perks_Metalworking"), Perks.MetalWelding',1)==(before/'mod/42.20/media/lua/shared/RadioCom/zISRadioInteractions_lsHook.lua').read_bytes()
  registered=json.loads((before/'registered211.json').read_text());changed=[n for n,h in registered.items()if sha(MOD/n)!=h];assert sorted(changed)==sorted(p.LIFESTYLE_LOCALE_COMPATIBILITY)
  for path,additions in p.LIFESTYLE_LOCALE_COMPATIBILITY.items():
   old,_=p.parse_translation((before/'mod/42.20'/path).read_bytes(),path);values,_=p.parse_translation((MOD/path).read_bytes(),path);assert all(values[k]==v for k,v in old.items());assert set(values)-set(old)==set(additions)
   assert (MOD/path).read_bytes()==(MOD/'media/SAOSources/Merged'/path).read_bytes()
  with tempfile.TemporaryDirectory(prefix='sao-locale-')as temporary:
   work=Path(temporary);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes());cp=os.pathsep.join(map(str,jars));result=subprocess.run([str(JDK/'javac.exe'),'-cp',cp,'-d',str(work),str(FIX/'LocaleProbe.java')],capture_output=True);(out/'compile.log').write_bytes(result.stdout+result.stderr);assert result.returncode==0
   expected=out/'expected.tsv';expected.write_text(''.join(k+'\t'+v+'\n'for values in p.LIFESTYLE_LOCALE_COMPATIBILITY.values()for k,v in values.items()))
   for name in ['baseline','restored-missing-label','restored-old-native-key']:
    target=MOD;source=owner
    if name=='restored-missing-label':
     target=work/'missing-label';dest=target/'media/lua/shared/Translate/EN';dest.mkdir(parents=True)
     for path in p.LIFESTYLE_LOCALE_COMPATIBILITY:
      values=json.loads((MOD/path).read_text());values.pop('ContextMenu_LSMP_InUse',None);(dest/Path(path).name).write_text(json.dumps(values))
    if name=='restored-old-native-key':source=out/'old-native-key.lua';source.write_bytes((before/'mod/42.20/media/lua/shared/RadioCom/zISRadioInteractions_lsHook.lua').read_bytes())
    result=subprocess.run([str(JDK/'java.exe'),'-cp',str(work)+os.pathsep+cp,'LocaleProbe',str(GAME),str(target),str(expected),str(FIX/'prelude.lua'),str(deprecated),str(FIX/'deprecated.lua'),str(source),str(FIX/'cases.lua')],capture_output=True,cwd=work,timeout=50);log=out/(name+'.log');log.write_bytes(result.stdout+result.stderr);text=log.read_text(errors='replace');marker='D2_LOCALE:native_context_label_ContextMenu_LSMP_InUse'if name=='restored-missing-label'else'D2_LOCALE:actual_source_welding_halo_native_label'
    assert (result.returncode==0 and'PASS native locale'in text)if name=='baseline'else(result.returncode!=0 and marker in text),text
    receipt['nativeRuns'].append({'name':name,'exit':result.returncode,'logSha256':sha(log),'expectedFailure':None if name=='baseline'else marker});save()
   sample=work/'scanner';sample.mkdir();(sample/'calls.lua').write_text('getText("UI_live--literal") --getText("UI_comment")\n--[[getText("UI_longcomment")]]\ngetTextOrNull(\'UI_second\')\n--[=[getText("UI_equal_comment")]=]\n')
   oldLua=scanner.LUA;oldRoot=scanner.ROOT
   try:
    scanner.LUA=sample;scanner.ROOT=work;requests=scanner.requested_keys();assert [(n,k)for _,n,k in requests]==[(1,'UI_live--literal'),(3,'UI_second')]
    from unittest.mock import patch
    with patch('menu_reach.strip_lua',lambda text,strings=False:text):
     defective=scanner.requested_keys();assert len(defective)==5 and any(k=='UI_longcomment'for _,_,k in defective)
   finally:scanner.LUA=oldLua;scanner.ROOT=oldRoot
   # Actual importer hooks on a bounded source fixture, with full preceding
   # merged catalogues as the preserved canonical preimage.
   spec=p.SOURCES['LifestyleHobbies'];workshop=work/'workshop';selected=workshop/spec[0]/spec[1];fakeMod=work/'mod'
   relativePaths=[*p.LIFESTYLE_LOCALE_COMPATIBILITY,'media/lua/shared/RadioCom/zISRadioInteractions_lsHook.lua']
   for path in relativePaths:
    target=selected/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((MOD/'media/SAOSources/LifestyleHobbies'/path).read_bytes())
    if path in p.LIFESTYLE_LOCALE_COMPATIBILITY:
     target=fakeMod/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((before/'mod/42.20'/path).read_bytes())
   (selected/'mod.info').write_bytes((MOD/'media/SAOSources/LifestyleHobbies/provenance/selected-mod.info').read_bytes())
   allSources=p.SOURCES;p.SOURCES={'LifestyleHobbies':spec}
   try:
    plan,outputs,_=p.build_plan(workshop,fakeMod)
    assert outputs['media/lua/shared/RadioCom/zISRadioInteractions_lsHook.lua']==owner.read_bytes()
    for path in p.LIFESTYLE_LOCALE_COMPATIBILITY:assert outputs['media/SAOSources/Merged/'+path]==(MOD/path).read_bytes()
    from unittest.mock import patch
    with patch.object(p,'adapt_lifestyle_locale_values',lambda values,path:(values,[])):
     badPlan,badOutputs,_=p.build_plan(workshop,fakeMod)
     assert any(badOutputs['media/SAOSources/Merged/'+path]!=(MOD/path).read_bytes()for path in p.LIFESTYLE_LOCALE_COMPATIBILITY)
   finally:p.SOURCES=allSources
  receipt['inputsAfter']={str(f):sha(f)for f in inputs};assert receipt['inputsAfter']==pins;receipt.update(status='PASS',changedRows=13,unchangedRows=89508,changedFamilySeals=6,preservedRegisteredOutputs=208,nativeControls=2,lexicalControls=1,actualImporterHook=True,restoredImporterHookControl=True);save();print('PASS native locale/source +2 restored controls, lexical/importer controls,13rows/208 registered outputs preserved')
 except Exception as error:receipt.update(status='FAIL',error=str(error));save();raise
if __name__=='__main__':main()
