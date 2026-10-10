#!/usr/bin/env python3
"""Actual native generator/material/source/power and private Lua serialization boundaries.

Native methods are real; loaded geometry, engine bootstrap, weather/grid state and
Lua actor/bridge receivers are controlled. Native timed operations belong to the
separate generator owner instrument.
"""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys,tempfile,shutil
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
HELPER=ROOT/'tools/native_proof_preflight.py'
if not HELPER.is_file():
    print('FAILED D36 generator sources: owned proof inputs absent: '+str(HELPER));raise SystemExit(1)
from native_proof_preflight import presence,causal_controls,installed_path
GAME=installed_path(os.environ.get('PZ_DIR',r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK=installed_path(os.environ.get('JDK_BIN',r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
WORLD=ROOT/'java/src/com/sao/engine/SAOWorldSources.java'
NEEDS=ROOT/'java/src/com/sao/engine/SAONeeds.java'
BRIDGE=ROOT/'java/src/com/sao/bridge/SAOBridge.java'
LUA=ROOT/'mod/42.20/media/lua/shared/SAO_WorldSources.lua'
MATERIAL=ROOT/'mod/42.20/media/lua/shared/SAO_Material.lua'
PROBE=ROOT/'tools/luacheck/D36GeneratorSourceProbe.java'
CASES=ROOT/'tools/d36_generator_sources/cases.lua'
METADATA=ROOT/'tools/d2_leisure_materials/metadata.java.inc'
PRELUDE=r'''
SAO={History={countyHours=function()return 12 end},Log={line=function()end}}
__stores={};ModData={getOrCreate=function(key)__stores[key]=__stores[key]or{};return __stores[key]end,get=function(key)return __stores[key]end}
Events=setmetatable({},{__index=function(t,k)local v={Add=function()end,Remove=function()end};rawset(t,k,v);return v end})
'''
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path,required=True);ap.add_argument('--required',action='store_true');ap.add_argument('--baseline-only',action='store_true')
    args=ap.parse_args()
    jar=ROOT/'mod/42.20/media/java/SAO.jar'
    helpers=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',ROOT/'tools/luacheck/LuaSyntax.java']
    owned=[Path(__file__),HELPER,WORLD,NEEDS,BRIDGE,LUA,MATERIAL,PROBE,CASES,METADATA,jar,*helpers]
    rows=[('normal.txt',name)for name in ['Generator','Generator_Yellow','Generator_Blue','Generator_Old','ElectronicsScrap','ElectricWire','PetrolCan','WaterBottle']]
    rows += [('literature.txt','ElectronicsMag4'),('literature.txt','ElectronicsMag1'),('literature.txt','Magazine'),('container.txt','Bag_Schoolbag')]
    installed=[GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe',*[GAME/'media/scripts/generated/items'/file for file,_ in rows],GAME/'media/scripts/generated/fluids.txt',GAME/'media/scripts/generated/fluids_Beverages.txt',GAME/'media/scripts/generated/fluids_Alcoholic.txt']
    absent=presence(owned,installed,args.required,'D36 generator sources')
    if absent is not None:return absent
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
    jars=[jar,GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',*sorted((GAME/'jars').glob('*.jar'))]
    inputs=list(dict.fromkeys(owned+installed+jars))
    receipt={'schema':'sao-d36-generator-sources/1','status':'INCOMPLETE','boundary':__doc__,'inputsBefore':{str(p):sha(p)for p in inputs},'runs':[],'controls':[]}
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    def run(name,cmd,work):
        done=subprocess.run(list(map(str,cmd)),cwd=work,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(done.stdout+done.stderr)
        receipt['runs'].append({'name':name,'exitCode':done.returncode,'logSha256':sha(log)});save()
        return done.returncode,log.read_text(encoding='utf-8',errors='replace')
    save()
    try:
        table=out/'items.tsv';table.write_text(''.join(str(GAME/'media/scripts/generated/items'/file)+'\tBase\t'+name+'\n'for file,name in rows))
        metadata=METADATA.read_text();anchor='definition.Load(name,text.substring(match.start(),end));';assert metadata.count(anchor)==1
        metadata=metadata.replace(anchor,'var modField=ScriptManager.class.getDeclaredField("currentLoadFileMod");modField.setAccessible(true);Object oldMod=modField.get(null);modField.set(null,"fixture-installed-source");try{definition.setModID("fixture-installed-source");definition.InitLoadPP(name);'+anchor+'}finally{modField.set(null,oldMod);}',1)
        generated=out/PROBE.name;generated.write_text(PROBE.read_text().replace('    METADATA',metadata,1))
        prelude=out/'prelude.lua';prelude.write_text(PRELUDE)
        with tempfile.TemporaryDirectory(prefix='sao-d36-sources-')as temp:
            work=Path(temp);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
            code,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated],work);assert code==0,log
            code,log=run('syntax',[JDK/'java.exe','-cp',str(work)+os.pathsep+cp,'LuaSyntax',LUA,MATERIAL,CASES,prelude],work);assert code==0,log
            def probe(name,variant=None,owner=LUA):
                classpath=(str(variant)+os.pathsep if variant else '')+str(work)+os.pathsep+cp
                return run(name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',classpath,'D36GeneratorSourceProbe',GAME,table,prelude,owner,CASES],work)
            code,log=probe('baseline');assert code==0 and 'PASS D36 native sources 'in log and 'PASS D36 private sources 'in log,log
            if not args.baseline_only:
                controls=[('scrap-type',NEEDS,'"ElectronicsScrap".equals(item.getType())','true','wire_not_scrap','electronics-scrap'),('petrol-identity',NEEDS,'petrol.contains(zombie.entity.components.fluids.Fluid.Petrol)','true','water_not_petrol','petrol'),('petrol-threshold',NEEDS,'petrol.getAmount() >= 0.099f','petrol.getAmount() > 0','petrol_below_native_threshold','petrol'),('manual-recipe',NEEDS,'manual.getLearnedRecipes().contains("Generator")','true','ordinary_magazine_not_manual','generator-manual'),('revision',WORLD,'if (revision != null && !operation.equals("verify-power") && !revision.equals(physical.revision)) throw new ActionRefusal("REVISION_CHANGED");','if(false)throw new ActionRefusal("REVISION_CHANGED");','changed_revision_refused_Base.Generator',None)]
                for name,source,before,after,marker,category in controls:
                    text=source.read_text();start=text.index('case "'+category+'":')if category else text.index('private static IsoGenerator generatorFixture');end=text.index('case ',start+6)if category else text.index('private static boolean generatorOperation',start)
                    section=text[start:end];assert section.count(before)==1,(name,section.count(before));variant=out/name;variant.mkdir();mutated=variant/source.name;mutated.write_text(text[:start]+section.replace(before,after,1)+text[end:])
                    code,log=run(name+'-compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',variant,mutated],work);assert code==0,log
                    code,log=probe(name,variant);assert code!=0 and 'D36_SOURCES:'+marker in log,(name,log);receipt['controls'].append({'name':name,'expectedFailure':marker})
                receipt['preflightControls']=causal_controls(ROOT,Path(__file__),owned,child_args=['--out','proof'],missing_owned=PROBE)
            receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'changed input during proof'
            receipt['status']='PASS';save();print('PASS D36 generator sources;controls='+str(len(receipt['controls'])));return 0
    except Exception as error:
        receipt['status']='FAIL';receipt['error']=str(error);save();print('FAIL D36 generator sources: '+str(error)[-2500:]);return 1
if __name__=='__main__':raise SystemExit(main())
