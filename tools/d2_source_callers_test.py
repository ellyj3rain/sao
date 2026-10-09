#!/usr/bin/env python3
"""Actual owned vault/registry caller qualification; native Kahlua/Stats, controlled physical host."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,tempfile,shutil,re
import d2_leisure_music_test as music
from native_proof_preflight import installed_presence
ROOT=music.ROOT;HERE=ROOT/'tools/d2_source_callers';PACKAGE=ROOT/'mod/42.20';SHARED=PACKAGE/'media/lua/shared';CLIENT=PACKAGE/'media/lua/client'
OWNERS=[CLIENT/('SAO_'+n+'.lua')for n in ['Leisure','LeisureArt','LeisureGames','LeisureExercise','LeisureMusic','LeisureLifestyle','LeisureMusicSupply']]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,required=True);args=parser.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 manifest=SHARED/'SAO_SourcePackageManifest.lua';registry=SHARED/'SAO_SourceIntegration.lua'
 jars=[music.GAME/'projectzomboid.jar',*sorted((music.GAME/'jars').glob('*.jar'))];native=[music.GAME/'media/lua/shared/ISBaseObject.lua',music.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 originals=list((PACKAGE/'media/SAOSources').rglob('*.lua'));jsonManifest=PACKAGE/'media/SAOSources/manifest.json';seals=[PACKAGE/row['sentinel']for row in json.loads(jsonManifest.read_text(encoding='utf-8'))['sources'].values()]
 inputs=[Path(__file__),Path(music.__file__),manifest,jsonManifest,registry,*OWNERS,*HERE.iterdir(),*originals,*seals,*native,*jars,music.GAME/'stdlib.lua',music.FIXTURES/'MusicProbe.java',music.FIXTURES/'prelude.lua',ROOT/'tools/d2_leisure_lifestyle/prelude.lua',music.ORG]
 missing=installed_presence(inputs,music.GAME,music.JDK,'D2 owned source callers')
 if missing is not None:return missing
 receipt={'schema':'sao-owned-source-callers/1','status':'INCOMPLETE','inputsBefore':{str(p):sha(p)for p in inputs},'runs':[],'boundary':'Actual owned manifest/registry, actual imported original files and native Kahlua/Stats. Existing controlled body/queue/audio/clock/Planner host; no rendered gameplay or multiplayer claim. Byte/effect predecessor evidence reused for adapted Art/Games/Exercise. Filesystem host restricts every reader to actual SurvivorAwareness package; no Workshop fallback.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,command,work):
  r=subprocess.run(list(map(str,command)),cwd=work,capture_output=True,timeout=120);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr);receipt['runs'].append({'name':name,'exitCode':r.returncode,'log':str(log),'sha256':sha(log)});save();return r.returncode,log.read_text(encoding='utf-8',errors='replace')
 try:
  for p in OWNERS:
   s=p.read_text(encoding='utf-8');assert 'SAO_SourceIntegration' in s and 'getModFileReader(' not in s,p
   if p.name!='SAO_LeisureExercise.lua':assert 'getActivatedMods'not in s,p
  receipt['routeAuditOwners']=7
  # Every existing original authority is preserved byte-for-byte in the project vault.
  names={}
  for id,oldroot in [('LifestyleHobbies',music.LS),('NewMusic',music.NM)]:
   for p in (PACKAGE/'media/SAOSources'/id/'media/lua').rglob('*.lua'):
    original=oldroot/p.relative_to(PACKAGE/'media/SAOSources'/id/'media/lua');assert original.is_file()and sha(p)==sha(original),('owned original drift',p);names[id+':'+p.relative_to(PACKAGE/'media/SAOSources'/id/'media/lua').as_posix()]=p
  receipt['ownedOriginalByteParity']=len(names)
  paths=out/'source-paths.tsv';paths.write_text(''.join(k+'\t'+str(p)+'\n'for k,p in names.items()),encoding='utf-8')
  with tempfile.TemporaryDirectory(prefix='sao-owned-callers-')as temp:
   work=Path(temp);shutil.copyfile(music.GAME/'stdlib.lua',work/'stdlib.lua')
   code=(music.FIXTURES/'MusicProbe.java').read_text(encoding='utf-8').replace('public final class MusicProbe','public final class OwnedCallerProbe')
   injection='''
        Path packageRoot=Path.of(System.getProperty("sao.ownedPackage")).toRealPath();
        env.rawset("__packageFile",(JavaFunction)(frame,count)->{
            String name=(String)frame.get(0);Path selected=packageRoot.resolve(name).normalize();
            if(!selected.startsWith(packageRoot))throw new IllegalArgumentException("outside owned package");
            try{return frame.push(Files.isRegularFile(selected)?Files.readString(selected).replace("\\r\\n","\\n"):null);}catch(Exception error){throw new IllegalStateException(error);}
        });
        '''
   code=code.replace('var sources=platform.newTable();',injection+'var sources=platform.newTable();');java=out/'OwnedCallerProbe.java';java.write_text(code,encoding='utf-8')
   cp=os.pathsep.join(map(str,jars));status,log=run('compile',[music.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,java],work);assert status==0,log
   base=[music.JDK/'java.exe','-Djava.awt.headless=true','-Dsao.ownedPackage='+str(PACKAGE),'--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'OwnedCallerProbe',paths,music.FIXTURES/'prelude.lua',*native,HERE/'package_host.lua',names['LifestyleHobbies:shared/LSUtil.lua']]
   status,log=run('music-supply-owned',base+[music.ORG,CLIENT/'SAO_LeisureMusicSupply.lua',music.OWNER,HERE/'music_cases.lua'],work);assert status==0 and 'PASS owned source callers'in log,log[-7000:];receipt['musicSupplyChecks']=int(re.search(r'PASS owned source callers (\d+)',log)[1])
   receipt['controls']=[]
   for name,target,old,new,marker in [
    ('duplicate-source',registry,'return type(id)=="string" and mods and mods:contains(id)==true or false','return false','duplicate_external_refused'),
    ('private-availability',registry,'function S.available(id)','function S.available(id)\n    if getActivatedMods():contains(id) then return false end','private_source_available_with_external'),
    ('private-reader-gate',registry,'if not S.available(id) then return nil,S.loadReport[tostring(id)] end','if not S.active(id) then return nil,S.loadReport[tostring(id)] end','private_original_readable_with_external'),
    ('vault-path',registry,'or not pathSafe(path)','or false','unsafe_path_refused'),
    ('vault-seal',registry,'tostring(line)~="SAO-OWNED-SOURCE/1 "..id.." "..row.seal','false','bad_owned_seal_refused'),
    ('original-revision',CLIENT/'SAO_LeisureMusicSupply.lua','h1~=pin[2]or h2~=pin[3]or #lines~=pin[4]','false ','altered_owned_original_refused')]:
    text=target.read_text(encoding='utf-8');assert text.count(old)==1,(name,text.count(old));variant=out/(name+'.lua');variant.write_text(text.replace(old,new,1),encoding='utf-8')
    if target==registry:
     selectedPaths=out/(name+'-sources.tsv');selectedPaths.write_text(paths.read_text(encoding='utf-8')+'variant:registry\t'+str(variant)+'\n',encoding='utf-8');setup=out/(name+'-setup.lua');setup.write_text('__registryText=__sources["variant:registry"]',encoding='utf-8')
     selectedBase=[*base];selectedBase[selectedBase.index(paths)]=selectedPaths;selectedBase.insert(selectedBase.index(HERE/'package_host.lua'),setup);extraSupply=CLIENT/'SAO_LeisureMusicSupply.lua'
    else:selectedBase=base;extraSupply=variant
    status,log=run(name,selectedBase+[music.ORG,extraSupply,music.OWNER,HERE/'music_cases.lua'],work);assert status!=0 and 'OWNED_CALLER:'+marker in log,(name,log[-5000:]);receipt['controls'].append({'name':name,'expectedFailure':marker})
   status,log=run('lifestyle-owned',base+[music.OWNER,ROOT/'tools/d2_leisure_lifestyle/prelude.lua',CLIENT/'SAO_LeisureLifestyle.lua',HERE/'lifestyle_cases.lua'],work);assert status==0 and 'PASS owned lifestyle'in log,log[-7000:];receipt['lifestyleChecks']=int(re.search(r'PASS owned lifestyle (\d+)',log)[1])
   lifestyle=CLIENT/'SAO_LeisureLifestyle.lua';source=lifestyle.read_text(encoding='utf-8')
   old='if row.customName=="Jukebox"and stationPhysicalEnabled()then'
   assert source.count(old)==1
   variant=out/'external-station-owner.lua';variant.write_text(source.replace(old,'if row.customName=="Jukebox"then',1),encoding='utf-8')
   status,log=run('external-station-gate',base+[music.OWNER,ROOT/'tools/d2_leisure_lifestyle/prelude.lua',variant,HERE/'lifestyle_cases.lua'],work)
   assert status!=0 and 'OWNED_LIFESTYLE:private_station_offer_with_external' in log,log[-7000:]
   receipt['controls'].append({'name':'external-station-gate','expectedFailure':'private_station_offer_with_external'})
  receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'owned source inputs drifted';receipt['status']='PASS';save();print('PASS owned source callers',receipt['musicSupplyChecks']+receipt['lifestyleChecks']);return 0
 except Exception as error:receipt['status']='FAIL';receipt['failure']=str(error);save();print('FAIL',error);return 1
if __name__=='__main__':raise SystemExit(main())
