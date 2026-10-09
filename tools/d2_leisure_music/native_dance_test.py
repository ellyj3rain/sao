#!/usr/bin/env python3
"""Original source dance on an actual off-slot body and native XP receiver."""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,sys,tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import d2_leisure_music_test as music
import d2_leisure_music.world_audio_test as world
from native_proof_preflight import installed_presence
def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--baseline-only',action='store_true');p.add_argument('--jar',type=Path);a=p.parse_args()
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 probe=music.ROOT/'tools/instrument_checks/InstrumentProbe.java'
 helpers=[music.ROOT/'tools/luacheck/MovementCrossingProbe.java',music.ROOT/'tools/luacheck/ResourceApproachProbe.java',music.ROOT/'tools/cognition_checks/CognitionUseProbe.java']
 skill=music.ROOT/'mod/42.20/media/lua/client/SAO_LeisureSkill.lua'
 native=[music.GAME/'media/lua/shared/ISBaseObject.lua',music.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 jars=[music.GAME/'projectzomboid.jar',*sorted((music.GAME/'jars').glob('*.jar')),music.GAME/'ZombieBuddy.jar',a.jar.resolve()if a.jar else music.ROOT/'mod/42.20/media/java/SAO.jar']
 manager=music.LS/'client/LSMoodleManager.lua';props=music.LS/'client/Properties/MoodleProperties.lua';perks=music.LS.parent/'perks.txt';registry=music.LS.parent/'registries.lua'
 inputs=[Path(__file__),music.ROOT/'tools/native_proof_preflight.py',Path(music.__file__),Path(world.__file__),probe,*helpers,skill,music.OWNER,music.ORG,music.FIXTURES/'prelude.lua',music.FIXTURES/'world-audio-cases.lua',music.FIXTURES/'native-dance-cases.lua',*native,*jars,music.GAME/'stdlib.lua',manager,props,perks,registry,*[music.LS/n for n in music.LS_FILES],*[music.NM/n for n in music.NM_FILES+music.NM_PROOF_FILES+world.EXTRA]]
 absent=installed_presence(inputs,music.GAME,music.JDK,'D2 native dance',installed_roots=(music.LS.parent,music.NM.parent))
 if absent is not None:return absent
 receipt={'schema':'sao-d2-native-dance/1','status':'INCOMPLETE','inputsBefore':{str(f):music.sha(f)for f in inputs},'runs':[],'controls':[],
 'boundary':'Actual installed native off-slot SAOIsoPlayerShell index1, native custom Dancing/Fitness perks and exact SP addXp/SyncXp receiver, registered traits/descriptor, native Stats/metabolic target/muscle state. Complete original Lifestyle source and exact four-call emitter tracing. Queue/hardware/source elapsed clock/acquired public source/native-hearing input and original NewMusic renderer host controlled; no loaded render/network/partner-consent claim.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,cwd):
  r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr)
  receipt['runs'].append({'name':name,'exitCode':r.returncode,'log':str(log),'logSha256':music.sha(log)});save();return r.returncode,log.read_text(errors='replace')
 try:
  keys={**music.pins(),**{'NewMusic:'+n:[]for n in music.NM_PROOF_FILES+world.EXTRA}}
  manifest=out/'source-paths.tsv';manifest.write_text(''.join(k+'\t'+str((music.LS if k.startswith('LifestyleHobbies:')else music.NM)/k.split(':',1)[1])+'\n'for k in keys))
  prefix=(music.FIXTURES/'world-audio-cases.lua').read_text().split('local function offer()')[0]
  combined=out/'combined-native-dance.lua';combined.write_text(prefix+(music.FIXTURES/'native-dance-cases.lua').read_text())
  init=out/'source-initializer.lua';anchor='LSMoodleManager.init = function(player)';source=manager.read_text();assert source.count(anchor)==1
  init.write_text('__moodleProperties=(function()\n'+props.read_text()+'\nend)()\nLSMoodleManager={}\nlocal previousRequire=require;require=function(name)if name=="Properties/MoodleProperties"then return __moodleProperties end;return previousRequire(name)end\n'+anchor+source.split(anchor)[1].split('function LSMoodleManager.getMoodle')[0])
  enums=out/'native-enums.lua';enums.write_text('Perks=__nativePerks;CharacterTrait=__nativeCharacterTrait;Metabolics=__nativeMetabolics;MoodleType=__nativeMoodleType;IsoDirections=__nativeIsoDirections;instanceof=__nativeinstanceof\n')
  java=probe.read_text().replace('public final class InstrumentProbe','public final class NativeDanceProbe')
  java=java.replace('IsoCell.class,zombie.iso.IsoGridSquare.class','java.util.Map.class,zombie.characters.IsoGameCharacter.XP.class,zombie.characters.skills.PerkFactory.Perk.class,zombie.characters.skills.PerkFactory.Perks.class,zombie.scripting.objects.CharacterTrait.class,zombie.characters.BodyDamage.Metabolics.class,zombie.iso.IsoDirections.class,zombie.characters.SurvivorDesc.class,IsoCell.class,zombie.iso.IsoGridSquare.class')
  injection='''LuaCompiler.register(env);
        var sources=platform.newTable();for(var row:Files.readAllLines(Path.of(MANIFEST))){var parts=row.split("\\t",2);sources.rawset(parts[0],Files.readString(Path.of(parts[1])).replace("\\r\\n","\\n"));}env.rawset("__sources",sources);
        var custom=new zombie.characters.skills.CustomPerks();var read=zombie.characters.skills.CustomPerks.class.getDeclaredMethod("readFile",String.class);read.setAccessible(true);read.invoke(custom,PERKS);custom.init();custom.initLua();
        for(String name:new String[]{"Perks","CharacterTrait","Metabolics","MoodleType","IsoDirections","instanceof"})env.rawset("__native"+name,env.rawget(name));
        exposer.exposeGlobalClassFunction((se.krka.kahlua.vm.KahluaTable)env.rawget("CharacterTrait"),zombie.scripting.objects.CharacterTrait.class,zombie.scripting.objects.CharacterTrait.class.getMethod("register",String.class),"register");
        exposer.exposeGlobalClassFunction((se.krka.kahlua.vm.KahluaTable)env.rawget("ItemTag"),zombie.scripting.objects.ItemTag.class,zombie.scripting.objects.ItemTag.class.getMethod("register",String.class),"register");
        var global=new zombie.Lua.LuaManager.GlobalObject();
        env.rawset("addXp",(JavaFunction)(f,n)->{global.addXp((zombie.characters.IsoPlayer)f.get(0),(zombie.characters.skills.PerkFactory.Perk)f.get(1),((Number)f.get(2)).floatValue());return 0;});
        env.rawset("SyncXp",(JavaFunction)(f,n)->{global.SyncXp((zombie.characters.IsoPlayer)f.get(0));return 0;});
        env.rawset("__initSourceTraits",(JavaFunction)(f,n)->{body.getCharacterTraits().getTraits().putAll(new zombie.characters.traits.CharacterTraits().getTraits());return 0;});
        env.rawset("__nativeBody",body);
        '''.replace('MANIFEST',json.dumps(str(manifest))).replace('PERKS',json.dumps(str(perks)))
  java=java.replace('env.rawset("__body",body);',injection+'env.rawset("__body",body);');generated=out/'NativeDanceProbe.java';generated.write_text(java)
  with tempfile.TemporaryDirectory(prefix='sao-native-dance-')as tmp:
   work=Path(tmp);shutil.copyfile(music.GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[music.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated],work);assert code==0,log
   receiver=skill.read_text(encoding='utf-8-sig');owner=music.OWNER.read_text()
   for name in ['baseline']+([]if a.baseline_only else ['native-XP-omitted','source-moods-omitted','dead-cleanup-omitted','completed-hand-custody-omitted','original-hand-binding-restored']):
    text=receiver.replace('addXp(body,perk,request.amount)','-- native XP deliberately omitted',1)if name=='native-XP-omitted'else receiver
    s=out/(name+'-receiver.lua');s.write_text(text)
    text=owner
    if name=='original-hand-binding-restored':
     target='code=changed;env.danceOwnershipSites[#env.danceOwnershipSites+1]={original=binding[1],derived=binding[2]}'
     assert text.count(target)==1
     text=text.replace(target,'if binding[1]~=\"not self.character:isItemInBothHands(handItemP)\"then code=changed end;env.danceOwnershipSites[#env.danceOwnershipSites+1]={original=binding[1],derived=binding[2]}',1)
    if name=='source-moods-omitted':text=text.replace('local before=measure(body);local result=sourceGroup(actor,moods)','local before=measure(body);local result=nil',1)
    if name=='dead-cleanup-omitted':text=text.replace('if not danceDeathRetired then a.action:stop()end','a.action:stop()',1)
    if name=='completed-hand-custody-omitted':
     start=text.index('-- Original perform may restore');end=text.index('a.performed=true',start)
     section=text[start:end];assert section.count('self[field]=0')==1
     text=text[:start]+section.replace('self[field]=0','do end ',1)+text[end:]
    o=out/(name+'-owner.lua');o.write_text(text)
    code,log=run(name,[music.JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'NativeDanceProbe',music.GAME,music.FIXTURES/'prelude.lua',enums,registry,*native,music.LS/'shared/LSUtil.lua',init,s,o,combined],work)
    marker={'native-XP-omitted':'canonical_actual_native_dancing_XP','source-moods-omitted':'native_original_cycle_stats','dead-cleanup-omitted':'native_dead_cleanup_no_pain_replay','completed-hand-custody-omitted':'native_completed_cleanup_cannot_reequip_transferred_hand_item','original-hand-binding-restored':'native_private_start_own_two_hand_argument'}.get(name)
    if marker:assert code!=0 and 'D2_NATIVE_DANCE:'+marker in log,(name,log[-7000:]);receipt['controls'].append({'name':name,'expectedFailure':marker})
    else:assert code==0 and 'PASS native source dance 'in log,log[-10000:];receipt['checks']=int(re.search(r'PASS native source dance (\d+)',log)[1])
  receipt['inputsAfter']={str(f):music.sha(f)for f in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'inputs changed during proof'
  receipt['status']='PASS';save();print('PASS native dance',receipt['checks'],len(receipt['controls']));return 0
 except Exception as e:receipt['status']='FAIL';receipt['error']=str(e);save();raise
if __name__=='__main__':raise SystemExit(main())
