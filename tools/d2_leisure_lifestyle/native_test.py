"""Off-slot native DJ body, original source effects and canonical SP XP."""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,sys,tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import d2_leisure_lifestyle_test as source
from native_proof_preflight import installed_presence
def main():
 p=argparse.ArgumentParser();p.add_argument('--out',required=True,type=Path);p.add_argument('--jar',type=Path);p.add_argument('--baseline-only',action='store_true');p.add_argument('--coexistence',action='store_true');args=p.parse_args()
 out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 R=source.ROOT;probe=R/'tools/instrument_checks/InstrumentProbe.java'
 helpers=[R/'tools/luacheck/MovementCrossingProbe.java',R/'tools/luacheck/ResourceApproachProbe.java',R/'tools/cognition_checks/CognitionUseProbe.java']
 skill=R/'mod/42.20/media/lua/client/SAO_LeisureSkill.lua';manager=source.LS/'client/LSMoodleManager.lua';properties=source.LS/'client/Properties/MoodleProperties.lua'
 perks=source.LS.parent/'perks.txt';registry=source.LS.parent/'registries.lua'
 native=[source.GAME/'media/lua/shared/ISBaseObject.lua',source.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 jars=[source.GAME/'projectzomboid.jar',*sorted((source.GAME/'jars').glob('*.jar')),source.GAME/'ZombieBuddy.jar',args.jar.resolve()if args.jar else R/'mod/42.20/media/java/SAO.jar']
 text=source.OWNER.read_text();names=re.findall(r'\["([^"]+\.lua)"\]=\{',text)
 inputs=[Path(__file__),Path(source.__file__),R/'tools/native_proof_preflight.py',source.OWNER,probe,*helpers,skill,source.BASE/'prelude.lua',source.FIX/'prelude.lua',source.FIX/'native-cases.lua',*native,*jars,source.GAME/'stdlib.lua',manager,properties,perks,registry,*[source.LS/n for n in names]]
 absent=installed_presence(inputs,source.GAME,source.JDK,'D2 native Lifestyle DJ',installed_roots=(source.LS.parent,))
 if absent is not None:return absent
 if args.coexistence:inputs += [source.FIX/'native-coexistence-cases.lua',R/'mod/42.20/media/lua/client/InteractionRange.lua',R/'mod/42.20/media/lua/client/LSEffectsAux.lua']
 before={str(f):source.sha(f)for f in inputs};receipt={'schema':'sao-d2-native-lifestyle/1','status':'INCOMPLETE','inputsBefore':before,'runs':[],'controls':[],
 'boundary':'Actual off-slot native SAOIsoPlayerShell index1, native station IsoObjects/current squares and source CustomName/Facing sprite properties, installed trait registry/moodle initializer/Music perk, native Stats and canonical exact SP AddXP. Queue/action progression, native-hearing acquisition, power, hardware emitter playback and clock are controlled; no rendered or normal native action-scheduler claim.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,cwd):
  r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr);receipt['runs'].append({'name':name,'exitCode':r.returncode,'log':str(log),'sha256':source.sha(log)});save();return r.returncode,log.read_text(errors='replace')
 try:
  manifest=out/'sources.tsv';manifest.write_text(''.join('LifestyleHobbies:'+n+'\t'+str(source.LS/n)+'\n'for n in names))
  init=out/'initializer.lua';anchor='LSMoodleManager.init = function(player)';code=manager.read_text();assert code.count(anchor)==1
  init.write_text('__moodleProperties=(function()\n'+properties.read_text()+'\nend)()\nLSMoodleManager={}\nlocal priorRequire=require;require=function(name)if name=="Properties/MoodleProperties"then return __moodleProperties end;return priorRequire(name)end\n'+anchor+code.split(anchor)[1].split('function LSMoodleManager.getMoodle')[0])
  enums=out/'enums.lua';enums.write_text('Perks=__nativePerks;CharacterTrait=__nativeCharacterTrait;Metabolics=__nativeMetabolics;MoodleType=__nativeMoodleType;IsoDirections=__nativeIsoDirections;instanceof=__nativeinstanceof\n')
  java=probe.read_text().replace('public final class InstrumentProbe','public final class NativeLifestyleProbe')
  java=java.replace('IsoCell.class,zombie.iso.IsoGridSquare.class','java.util.Map.class,zombie.characters.traits.CharacterTraits.class,zombie.characters.IsoGameCharacter.XP.class,zombie.characters.skills.PerkFactory.Perk.class,zombie.characters.skills.PerkFactory.Perks.class,zombie.scripting.objects.CharacterTrait.class,zombie.characters.BodyDamage.Metabolics.class,zombie.iso.IsoDirections.class,zombie.characters.SurvivorDesc.class,zombie.iso.sprite.IsoSprite.class,zombie.core.properties.PropertyContainer.class,IsoCell.class,zombie.iso.IsoGridSquare.class')
  injection='''LuaCompiler.register(env);
   var sources=platform.newTable();for(var row:Files.readAllLines(Path.of(MANIFEST))){var parts=row.split("\\t",2);sources.rawset(parts[0],Files.readString(Path.of(parts[1])).replace("\\r\\n","\\n"));}env.rawset("__sources",sources);
   var custom=new zombie.characters.skills.CustomPerks();var read=zombie.characters.skills.CustomPerks.class.getDeclaredMethod("readFile",String.class);read.setAccessible(true);read.invoke(custom,PERKS);custom.init();custom.initLua();
   for(String name:new String[]{"Perks","CharacterTrait","Metabolics","MoodleType","IsoDirections","instanceof"})env.rawset("__native"+name,env.rawget(name));
   exposer.exposeGlobalClassFunction((KahluaTable)env.rawget("CharacterTrait"),zombie.scripting.objects.CharacterTrait.class,zombie.scripting.objects.CharacterTrait.class.getMethod("register",String.class),"register");
   exposer.exposeGlobalClassFunction((KahluaTable)env.rawget("ItemTag"),zombie.scripting.objects.ItemTag.class,zombie.scripting.objects.ItemTag.class.getMethod("register",String.class),"register");
   var global=new zombie.Lua.LuaManager.GlobalObject();
   env.rawset("addXp",(JavaFunction)(f,n)->{try{global.addXp((zombie.characters.IsoPlayer)f.get(0),(zombie.characters.skills.PerkFactory.Perk)f.get(1),((Number)f.get(2)).floatValue());}catch(Throwable t){t.printStackTrace();throw t;}return 0;});
   env.rawset("SyncXp",(JavaFunction)(f,n)->{global.SyncXp((zombie.characters.IsoPlayer)f.get(0));return 0;});
   env.rawset("__initSourceTraits",(JavaFunction)(f,n)->{body.getCharacterTraits().getTraits().putAll(new zombie.characters.traits.CharacterTraits().getTraits());return 0;});
   env.rawset("__nativeBody",body);System.out.println("NATIVE_XP_OPTIONS "+zombie.SandboxOptions.instance);
   var properties=new HashMap<String,ArrayList<String>>();properties.put("CustomName",new ArrayList<>(java.util.List.of("Booth","Jukebox")));properties.put("Facing",new ArrayList<>(java.util.List.of("N","S","E","W")));zombie.core.TilePropertyAliasMap.instance.Generate(properties);
   for(int i=0;i<3;i++){var o=new IsoObject(cell);o.setSquare(cell.getGridSquare(i==0?10:i==1?9:11,19,0));o.getSquare().setS(cell.getGridSquare(i==0?10:i==1?9:11,20,0));var sprite=new zombie.iso.sprite.IsoSprite();sprite.name="ls_djbooth_01_"+(i==0?1:i==1?0:2);sprite.getProperties().set("CustomName","Booth");sprite.getProperties().set("Facing","S");o.setSprite(sprite);o.getSquare().getObjects().add(o);env.rawset("__station"+i,o);}
   var juke=new IsoObject(cell);juke.setSquare(cell.getGridSquare(10,19,0));var js=new zombie.iso.sprite.IsoSprite();js.name="source-jukebox-fixture";js.getProperties().set("CustomName","Jukebox");js.getProperties().set("Facing","S");juke.setSprite(js);juke.getSquare().getObjects().add(juke);env.rawset("__nativeJukebox",juke);
  '''.replace('MANIFEST',json.dumps(str(manifest))).replace('PERKS',json.dumps(str(perks)))
  if args.coexistence:
   injection=injection.replace('properties.put("Facing",','properties.put("GroupName",new ArrayList<>(java.util.List.of("Gramophone")));properties.put("Facing",').replace('js.getProperties().set("CustomName","Jukebox");','js.getProperties().set("CustomName","Jukebox");js.getProperties().set("GroupName","Gramophone");')
  java=java.replace('import se.krka.kahlua.vm.JavaFunction;','import se.krka.kahlua.vm.JavaFunction;\nimport se.krka.kahlua.vm.KahluaTable;').replace('env.rawset("__body",body);',injection+'env.rawset("__body",body);')
  generated=out/'NativeLifestyleProbe.java';generated.write_text(java)
  with tempfile.TemporaryDirectory(prefix='sao-native-lifestyle-')as tmp:
   work=Path(tmp);shutil.copyfile(source.GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[source.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated],work);assert code==0,log
   variants=['baseline']+([]if args.baseline_only else ['XP-omitted','source-effect-omitted','tracker-omitted','music-accounting-omitted'])
   if args.coexistence:variants += ['global-range-filter-omitted','global-ending-filter-omitted']
   for name in variants:
    receiver=skill.read_text();owner=text
    if name=='XP-omitted':receiver=receiver.replace('addXp(body,perk,request.amount)','-- native XP receiver omitted',1)
    if name=='source-effect-omitted':owner=owner.replace('original(actor,group);a.work.nativeProgress','do end;a.work.nativeProgress',1)
    if name=='tracker-omitted':owner=owner.replace('env.sourceTrackerInit();return trackerReady(body)','return trackerReady(body)',1)
    if name=='music-accounting-omitted':owner=owner.replace('invoke(a,"update",a.env.sourceMusicAccounting,a.body)','do end',1)
    s=out/(name+'-skill.lua');s.write_text(receiver);o=out/(name+'-owner.lua');o.write_text(owner)
    cases=source.FIX/'native-cases.lua'
    if args.coexistence:
     cases=out/(name+'-cases.lua');cases.write_text((source.FIX/'native-cases.lua').read_text().replace("print('PASS native Lifestyle '..checks)","")+(source.FIX/'native-coexistence-cases.lua').read_text())
     imported=[]
     for module in ['InteractionRange','LSEffectsAux']:
      imported_text=(R/('mod/42.20/media/lua/client/'+module+'.lua')).read_text()
      if (name=='global-range-filter-omitted'and module=='InteractionRange')or(name=='global-ending-filter-omitted'and module=='LSEffectsAux'):
       guard='not (SAO.LeisureLifestyle and SAO.LeisureLifestyle.physicalSourceOwner and SAO.LeisureLifestyle.physicalSourceOwner(v) == true)'
       assert imported_text.count(guard)==1;imported_text=imported_text.replace(guard,'true',1)
      owned=out/(name+'-'+module+'.lua');owned.write_text(imported_text);imported.append('Owned:'+module+'\t'+str(owned)+'\n')
     manifest.write_text(''.join('LifestyleHobbies:'+n+'\t'+str(source.LS/n)+'\n'for n in names)+''.join(imported))
    code,log=run(name,[source.JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'NativeLifestyleProbe',source.GAME,source.BASE/'prelude.lua',enums,registry,*native,source.LS/'shared/LSUtil.lua',source.FIX/'prelude.lua',init,s,o,cases],work)
    marker={'XP-omitted':'actual_native_Music_XP','source-effect-omitted':'actual_native_source_stats','tracker-omitted':'original_native_tracker_initializer','music-accounting-omitted':'native_original_music_moodle_accounting','global-range-filter-omitted':'native_far_operator_cannot_silence','global-ending-filter-omitted':'native_global_cannot_advance_owned_ending'}.get(name)
    if marker:assert code!=0 and 'D2_NATIVE_LIFESTYLE:'+marker in log,(name,log[-7000:]);receipt['controls'].append({'name':name,'failure':marker})
    else:assert code==0 and 'PASS native Lifestyle 'in log,log[-10000:];receipt['checks']=int(re.search(r'PASS native Lifestyle (\d+)',log)[1])
  receipt['inputsAfter']={str(f):source.sha(f)for f in inputs};assert before==receipt['inputsAfter'],'input seal changed';receipt['status']='PASS';save();print('PASS native Lifestyle',receipt['checks'],len(receipt['controls']));return 0
 except Exception as error:receipt['status']='FAIL';receipt['error']=str(error);save();raise
if __name__=='__main__':raise SystemExit(main())
