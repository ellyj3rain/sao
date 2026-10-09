#!/usr/bin/env python3
"""Source Art/Radio material context, native ScriptItem metadata/aggregate/world category.

Actual installed Kahlua, item definitions/factory and original Lifestyle consumption.
Body/station observation, permissions, source knowledge, queue and physical callback
hosts are controlled. No autonomous acquisition, rendered gameplay or MP claim.
"""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys,tempfile
sys.dont_write_bytecode=True
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parents[1]
HERE=ROOT/'tools/d2_leisure_materials'
GAME=Path(os.environ.get('PZ_DIR',r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
sys.path.insert(0,str(ROOT/'tools/d2_leisure_art'))
import source_profile as profile
ART=ROOT/'mod/42.20/media/lua/client/SAO_LeisureArt.lua'
RADIO=ROOT/'mod/42.20/media/lua/client/SAO_LeisureRadio.lua'
AGG=ROOT/'java/src/com/sao/engine/SAOLeisureMaterials.java'
WORLD=ROOT/'java/src/com/sao/engine/SAOWorldSources.java'
NATIVE=['shared/ISBaseObject.lua','shared/TimedActions/ISBaseTimedAction.lua']
RADIO_FILES=['shared/RadioCom/ISRadioInteractions.lua','shared/RadioCom/ISRadioAction.lua',
 'shared/TimedActions/ISDeviceBatteryAction.lua','shared/TimedActions/ISDeviceMediaAction.lua']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path,required=True)
 ap.add_argument('--jar',type=Path,default=ROOT/'mod/42.20/media/java/SAO.jar')
 ap.add_argument('--baseline-only',action='store_true');args=ap.parse_args()
 out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 jars=[args.jar.resolve(),GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',*sorted((GAME/'jars').glob('*.jar'))]
 probe=ROOT/'tools/instrument_checks/InstrumentProbe.java'
 helpers=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',ROOT/'tools/cognition_checks/CognitionUseProbe.java']
 libraries=[*sorted((profile.SOURCE/'client/Painting/lib').glob('*.lua')),*sorted((profile.SOURCE/'client/Painting/Sculpting/lib').glob('*.lua')),profile.SOURCE/'client/Painting/Quality.lua']
 original=[profile.SOURCE/p for p in [*profile.ACTION_FILES.values(),*profile.MENU_FILES.values(),*profile.EXTRA]]
 script=profile.SOURCE.parent/'scripts/Lifestyle_items.txt'
 native_scripts=[GAME/'media/scripts/generated/items'/f for f in ['normal.txt','weapon.txt','drainable.txt','clothing.txt','radio.txt']]
 inputs=[Path(__file__),Path(profile.__file__),ART,RADIO,AGG,WORLD,probe,*helpers,HERE/'metadata.java.inc',HERE/'art-cases.lua',HERE/'radio-cases.lua',
  ROOT/'tools/d2_leisure_art/fixture.lua',ROOT/'tools/d2_leisure_radio/prelude.lua',*jars,GAME/'stdlib.lua',script,*native_scripts,
  *[GAME/'media/lua'/p for p in NATIVE+RADIO_FILES],*libraries,*original]
 absent=installed_presence(inputs,GAME,JDK,'D2 leisure material native/source qualification',installed_roots=(profile.SOURCE.parent,))
 if absent is not None:return absent
 receipt={'schema':'sao-d2-materials/1','status':'INCOMPLETE','boundary':__doc__,'inputsBefore':{str(p):sha(p)for p in inputs},'runs':[],'checks':{},'controls':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd,work):
  p=subprocess.run(list(map(str,cmd)),cwd=work,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(p.stdout+p.stderr)
  receipt['runs'].append({'name':name,'exitCode':p.returncode,'logSha256':sha(log)});save()
  return p.returncode,log.read_text(encoding='utf-8',errors='replace')
 save()
 try:
  art=ART.read_text(encoding='utf-8');radio=RADIO.read_text(encoding='utf-8')
  for name,block in profile.blocks():assert art.count('-- BEGIN INSTALLED SOURCE '+name+'\n'+block+'-- END INSTALLED SOURCE '+name+'\n')==1,('source-profile',name)
  receipt['exactSourceProfiles']=5
  manifest=out/'native-sources.tsv';manifest.write_text(''.join('native:'+p+'\t'+str(GAME/'media/lua'/p)+'\n'for p in RADIO_FILES),encoding='utf-8')
  entries=[(script,'Lifestyle',n)for n in ['oldPaintBrush','paintPalette','paintPaletteEmpty']]
  entries +=[(GAME/'media/scripts/generated/items'/f,'Base',n)for f,n in [('normal.txt','Saw'),('weapon.txt','Hammer'),('weapon.txt','CarpentryChisel'),('weapon.txt','MasonsChisel'),('drainable.txt','BlowTorch'),('clothing.txt','WeldingMask'),('drainable.txt','Battery'),('normal.txt','SilverCoin'),('normal.txt','Disc_Retail'),('normal.txt','VHS_Retail'),('normal.txt','VHS_Home'),('radio.txt','RadioRed')]]
  table=out/'native-items.tsv';table.write_text(''.join(str(f)+'\t'+m+'\t'+n+'\n'for f,m,n in entries),encoding='utf-8')
  java=probe.read_text(encoding='utf-8').replace('public final class InstrumentProbe','public final class MaterialsProbe')
  java=java.replace('public static void main(String[] args)throws Exception{',(HERE/'metadata.java.inc').read_text()+'\npublic static void main(String[] args)throws Exception{\nThread.setDefaultUncaughtExceptionHandler((t,e)->{e.printStackTrace();System.exit(1);});')
  java=java.replace('InventoryItem.class,zombie.inventory.ItemContainer.class','zombie.scripting.ScriptManager.class,zombie.radio.media.RecordedMedia.class,zombie.inventory.types.DrainableComboItem.class,InventoryItem.class,zombie.inventory.ItemContainer.class')
  injection='''
        LuaCompiler.register(env);
        env.rawset("__proofPrint",(JavaFunction)(f,n)->{System.out.println(f.get(0));return 0;});
        env.rawset("__stats",body.getStats());
        var materialDictionary=new MaterialDictionary();data.set(null,materialDictionary);
        var nativeItems=platform.newTable();short materialId=3000;
        for(var row:Files.readAllLines(Path.of(TABLE))){var p=row.split("\\t",3);var it=material(Path.of(p[0]),p[1],p[2],materialId++,materialDictionary);nativeItems.rawset(it.getFullType(),it);}
        env.rawset("__nativeItems",nativeItems);env.rawset("__scriptManager",ScriptManager.instance);
        env.rawset("__nativeItemTag",env.rawget("ItemTag"));env.rawset("__nativeRecordedMedia",env.rawget("RecordedMedia"));
        env.rawset("__newItem",(JavaFunction)(f,n)->{var it=zombie.inventory.InventoryItemFactory.CreateItem((String)f.get(0));it.setID(4000);return f.push(it);});
        var sources=platform.newTable();for(var row:Files.readAllLines(Path.of(MANIFEST))){var p=row.split("\\t",2);sources.rawset(p[0],Files.readString(Path.of(p[1])).replace("\\r\\n","\\n"));}env.rawset("__sources",sources);
        env.rawset("__requirements",(JavaFunction)(f,n)->f.push(com.sao.engine.SAOLeisureMaterials.requirements(f.get(0) instanceof SAOIsoPlayerShell b?b:null,(String)f.get(1))));
        var itemRow=Class.forName("com.sao.engine.SAOWorldSources$ItemRow");var of=itemRow.getDeclaredMethod("of",InventoryItem.class);of.setAccessible(true);
        var categories=itemRow.getDeclaredField("categories");categories.setAccessible(true);
        env.rawset("__categories",(JavaFunction)(f,n)->{try{return f.push(String.join(",",(java.util.List<String>)categories.get(of.invoke(null,f.get(0)))));}catch(Exception e){throw new IllegalStateException(e);}});
        '''.replace('TABLE',json.dumps(str(table))).replace('MANIFEST',json.dumps(str(manifest)))
  java=java.replace('env.rawset("__body",body);',injection+'env.rawset("__body",body);')
  java=java.replace('System.out.println("INSTRUMENT_NATIVE_DONE");','System.out.println("INSTRUMENT_NATIVE_DONE");System.exit(0);')
  generated=out/'MaterialsProbe.java';generated.write_text(java,encoding='utf-8')
  lib=out/'libraries.lua';lib.write_text('__libraries={}\n'+''.join('__libraries['+json.dumps(str(p.relative_to(profile.SOURCE/'client')).replace('\\','/')[:-4])+']=(function()\n'+p.read_text(encoding='utf-8-sig')+'\nend)()\n'for p in libraries),encoding='utf-8')
  with tempfile.TemporaryDirectory(prefix='sao-materials-')as temp:
   work=Path(temp);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated],work);assert code==0,log
   controls={
    'art':[
     ('instance','and P.resolveLeisureObject(id,body,row.key)==obj','', 'art_replaced_instance_refused'),
     ('fulfilled','if not name or findItem(body,name) then return false end','if not name then return false end','art_fulfilled_refused'),
     ('palette','and (name~="paintPalette" or _G.LSUtil.itemHasUses(item))','', 'art_spent_palette_is_missing'),
     ('skills','if skills then return true end','if true then return true end','art_source_sculpture_skill_Hedge'),
    ],
    'radio':[
     ('fulfilled','and not replacementBattery(body,data,d.kind)then return true end','then return true end','radio_carried_spare_closes_need'),
     ('compatibility','data:getMediaType()==mediaType and not data:hasMedia()','not data:hasMedia()','radio_incompatible_media_refused'),
     ('canonical','if not admitted then return false end','if false then return false end','radio_forged_requirement_refused'),
     ('context','local mediaType=category and RecordedMedia and RecordedMedia.getMediaTypeForCategory(category)\n for _,d in ipairs(devices(id,body))do',
      'local mediaType=category and RecordedMedia and RecordedMedia.getMediaTypeForCategory(category)\n for _,d in ipairs({{device=__radio,kind="carried"}})do','radio_no_private_device_refused'),
    ]}
   for family,production in [('art',art),('radio',radio)]:
    paths=([ROOT/'tools/d2_leisure_art/fixture.lua',*[GAME/'media/lua'/p for p in NATIVE],lib,profile.SOURCE/'shared/LSUtil.lua',profile.SOURCE/'shared/LSSync.lua',profile.SOURCE/'shared/Art/ArtFunctions.lua',profile.SOURCE/'shared/Art/PaintingMarkings.lua']if family=='art'else[ROOT/'tools/d2_leisure_radio/prelude.lua',*[GAME/'media/lua'/p for p in NATIVE]])
    for name,old,new,marker in [('baseline',None,None,None)]+([]if args.baseline_only else controls[family]):
     text=production
     if old:assert text.count(old)==1,(family,name,text.count(old));text=text.replace(old,new,1)
     owner=out/(family+'-'+name+'.lua');owner.write_text(text,encoding='utf-8')
     cases=out/(family+'-'+name+'-cases.lua');cases.write_text('local ok,err=pcall(function()\n'+(HERE/(family+'-cases.lua')).read_text()+'\nend)\nif not ok then error(tostring(err).." AFTER "..tostring(__lastPrint))end\n',encoding='utf-8')
     code,log=run(family+'-'+name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'MaterialsProbe',GAME,*paths,owner,cases],work)
     if marker:
      assert code!=0 and 'D2_MATERIALS:'+marker in log,(family,name,log[-6500:]);receipt['controls'].append({'family':family,'name':name,'expectedFailure':marker})
     else:
      assert code==0 and 'PASS D2 materials '+family+' 'in log,log[-8500:]
      receipt['checks'][family]=int(re.search('PASS D2 materials '+family+r' (\d+)',log)[1])
     print(family+' '+name+': PASS',flush=True)
   if not args.baseline_only:
    nativeControls=[
     ('revision',AGG,'||!revision.matches("[a-f0-9]{64}")','', 'native_aggregate_rejects_forged_owner_fields'),
     ('duplicate',AGG,'if(!seen.add(key))continue;','seen.add(key);','native_aggregate_rejects_forged_owner_fields'),
     ('recursive',AGG,'||QUERYING.get()','', 'native_aggregate_reentrancy_refused'),
     ('games-owner',AGG,'"LeisureGames",','', 'native_games_owner_registration'),
     ('world-category',WORLD,'if (SAOLeisureMaterials.recognizes(item.getFullType())) out.add("leisure-material");','', 'art_world_category_Lifestyle.oldPaintBrush'),
    ]
    paths=[ROOT/'tools/d2_leisure_art/fixture.lua',*[GAME/'media/lua'/p for p in NATIVE],lib,profile.SOURCE/'shared/LSUtil.lua',profile.SOURCE/'shared/LSSync.lua',profile.SOURCE/'shared/Art/ArtFunctions.lua',profile.SOURCE/'shared/Art/PaintingMarkings.lua']
    for name,source,old,new,marker in nativeControls:
     text=source.read_text(encoding='utf-8');assert text.count(old)==1,(name,text.count(old))
     variantDir=out/('native-'+name);variantDir.mkdir();sourceFile=variantDir/source.name;sourceFile.write_text(text.replace(old,new,1),encoding='utf-8')
     code,log=run('native-'+name+'-compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',variantDir,sourceFile],work);assert code==0,log
     code,log=run('native-'+name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(variantDir)+os.pathsep+str(work)+os.pathsep+cp,'MaterialsProbe',GAME,*paths,out/'art-baseline.lua',out/'art-baseline-cases.lua'],work)
     assert code!=0 and 'D2_MATERIALS:'+marker in log,(name,log[-6500:]);receipt['controls'].append({'family':'native','name':name,'expectedFailure':marker})
     print('native '+name+': PASS',flush=True)
   receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsAfter']==receipt['inputsBefore'],'changed input during proof'
   receipt['status']='PASS';save();print('PASS D2 leisure materials',receipt['checks'],len(receipt['controls']));return 0
 except Exception as e:
  receipt['status']='FAIL';receipt['error']=str(e);save();print('FAIL',str(e));return 1
if __name__=='__main__':raise SystemExit(main())
