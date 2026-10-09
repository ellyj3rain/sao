#!/usr/bin/env python3
"""Original native animation producer joined to actual Music and social owners."""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,sys,tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import d2_leisure_music_test as music
import d2_leisure_music.world_audio_test as world
from native_proof_preflight import installed_presence
HERE=Path(__file__).resolve().parent
def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--jar',type=Path,default=music.ROOT/'mod/42.20/media/java/SAO.jar');p.add_argument('--baseline-only',action='store_true');a=p.parse_args()
 root=music.ROOT;coord=root/'mod/42.20/media/lua/shared/SAO_Coordination.lua';comm=root/'mod/42.20/media/lua/shared/SAO_Communication.lua'
 probe=root/'tools/instrument_checks/InstrumentProbe.java';helpers=[root/'tools/luacheck/MovementCrossingProbe.java',root/'tools/luacheck/ResourceApproachProbe.java',root/'tools/cognition_checks/CognitionUseProbe.java',HERE/'DanceCycleProbe.java']
 native=[music.GAME/'media/lua/shared/ISBaseObject.lua',music.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 jars=[a.jar.resolve(),music.GAME/'projectzomboid.jar',*sorted((music.GAME/'jars').glob('*.jar')),music.GAME/'ZombieBuddy.jar']
 manager=music.LS/'client/LSMoodleManager.lua';props=music.LS/'client/Properties/MoodleProperties.lua';perks=music.LS.parent/'perks.txt';registry=music.LS.parent/'registries.lua'
 assets=[music.GAME/'media/anims_X/Bob/Bob_Idle.x']+[music.LS.parent/suffix for name in ['Bob_DancingDiscoSourceDefault','Bob_DancingDiscoTargetDefault']for suffix in ['anims_X/'+name+'.fbx','AnimSets/player/actions/'+name+'.xml']]
 inputs=[root/'java/src/com/sao/engine/SAODanceCycle.java',root/'java/src/com/sao/agent/SAODanceCycleWeave.java',root/'java/src/com/sao/agent/SAOAgent.java',root/'java/src/com/sao/bridge/SAOBridge.java',Path(__file__),Path(music.__file__),Path(world.__file__),HERE/'native-join-cases.lua',probe,*helpers,music.OWNER,music.ORG,coord,comm,music.FIXTURES/'prelude.lua',music.FIXTURES/'world-audio-cases.lua',*native,*jars,music.GAME/'stdlib.lua',manager,props,perks,registry,*assets,*[music.LS/n for n in music.LS_FILES],*[music.NM/n for n in music.NM_FILES+music.NM_PROOF_FILES+world.EXTRA]]
 absent=installed_presence([x for x in inputs if not x.is_relative_to(music.LS.parent)and not x.is_relative_to(music.NM)],music.GAME,music.JDK,'D2 native Music partner join')
 if absent is not None:return absent
 if any(not x.is_file()for x in inputs):print('SKIPPED D2 native Music partner join: installed source dependency absent; native proof unchecked');return 0
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 receipt={'schema':'sao-d2-native-partner-caller-join/1','status':'INCOMPLETE','inputsBefore':{str(x):music.sha(x)for x in inputs},'runs':[],'controls':[],
 'boundary':'Actual off-slot bodies/native LuaTimedActionNew/current native animation producer imported original FBX; actual Music/Organization/Coordination/Communication and complete original Lifestyle partner actions/willingness/acceptance. Controlled loaded geometry, original public audio renderer hardware and catalogue input, hearing/acquisition/personal memory/planner host. Native lifecycle dispatcher driven explicitly; no rendered-game cadence or broad MP/mastery claim.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd,cwd):
  r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=100);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr);receipt['runs'].append({'name':name,'exitCode':r.returncode,'log':str(log),'logSha256':music.sha(log)});save();return r.returncode,log.read_text(errors='replace')
 try:
  keys={**music.pins(),**{'NewMusic:'+n:[]for n in music.NM_PROOF_FILES+world.EXTRA},'social:coord':[],'social:comm':[]}
  manifest=out/'source-paths.tsv';manifest.write_text(''.join(k+'\t'+str({'social:coord':coord,'social:comm':comm}.get(k,(music.LS if k.startswith('LifestyleHobbies:')else music.NM)/k.split(':',1)[1]))+'\n'for k in keys),encoding='utf-8')
  prefix=(music.FIXTURES/'world-audio-cases.lua').read_text().split('local function offer()')[0]
  combined=out/'combined-native-partner.lua';combined.write_text(prefix+(HERE/'native-join-cases.lua').read_text(),encoding='utf-8')
  init=out/'source-initializer.lua';anchor='LSMoodleManager.init = function(player)';source=manager.read_text();assert source.count(anchor)==1
  init.write_text('__moodleProperties=(function()\n'+props.read_text()+'\nend)()\nLSMoodleManager={}\nlocal previousRequire=require;require=function(name)if name=="Properties/MoodleProperties"then return __moodleProperties end;return previousRequire(name)end\n'+anchor+source.split(anchor)[1].split('function LSMoodleManager.getMoodle')[0],encoding='utf-8')
  enums=out/'native-enums.lua';enums.write_text('Perks=__nativePerks;CharacterTrait=__nativeCharacterTrait;Metabolics=__nativeMetabolics;MoodleType=__nativeMoodleType;IsoDirections=__nativeIsoDirections;instanceof=__nativeinstanceof\n',encoding='utf-8')
  java=probe.read_text().replace('public final class InstrumentProbe','public final class NativePartnerProbe').replace('public static void main(String[] args)throws Exception{','public static void main(String[] args)throws Exception{Thread.setDefaultUncaughtExceptionHandler((t,e)->{e.printStackTrace();System.exit(1);});')
  java=java.replace('IsoCell.class,zombie.iso.IsoGridSquare.class','java.util.Map.class,zombie.characters.IsoGameCharacter.XP.class,zombie.characters.skills.PerkFactory.Perk.class,zombie.characters.skills.PerkFactory.Perks.class,zombie.scripting.objects.CharacterTrait.class,zombie.characters.BodyDamage.Metabolics.class,zombie.iso.IsoDirections.class,zombie.characters.SurvivorDesc.class,IsoCell.class,zombie.iso.IsoGridSquare.class')
  inject='''
        com.sao.agent.SAODanceCycleWeave.install();if(!com.sao.agent.SAODanceCycleWeave.ready())throw new IllegalStateException("native dance perform weave unavailable");
        var sources=platform.newTable();for(var row:Files.readAllLines(Path.of(args[1]))){var parts=row.split("\\t",2);sources.rawset(parts[0],Files.readString(Path.of(parts[1])).replace("\\r\\n","\\n"));}env.rawset("__sources",sources);
        var custom=new zombie.characters.skills.CustomPerks();var read=zombie.characters.skills.CustomPerks.class.getDeclaredMethod("readFile",String.class);read.setAccessible(true);read.invoke(custom,PERKS);custom.init();custom.initLua();
        for(String name:new String[]{"Perks","CharacterTrait","Metabolics","MoodleType","IsoDirections","instanceof"})env.rawset("__native"+name,env.rawget(name));
        exposer.exposeGlobalClassFunction((se.krka.kahlua.vm.KahluaTable)env.rawget("CharacterTrait"),zombie.scripting.objects.CharacterTrait.class,zombie.scripting.objects.CharacterTrait.class.getMethod("register",String.class),"register");
        exposer.exposeGlobalClassFunction((se.krka.kahlua.vm.KahluaTable)env.rawget("ItemTag"),zombie.scripting.objects.ItemTag.class,zombie.scripting.objects.ItemTag.class.getMethod("register",String.class),"register");
        env.rawset("__initSourceTraits",(JavaFunction)(f,n)->{((SAOIsoPlayerShell)f.get(0)).getCharacterTraits().getTraits().putAll(new zombie.characters.traits.CharacterTraits().getTraits());return 0;});
        env.rawset("__stats",body.getStats());env.rawset("__stats2",other.getStats());env.rawset("__nativeBody",body);env.rawset("__nativePeer",other);env.rawset("__bridge",SAOBridge.INSTANCE);
        zombie.core.skinnedmodel.model.jassimp.JAssImpImporter.Init();
        var skin=DanceCycleProbe.importClip(Path.of(args[0]).resolve("media/anims_X/Bob/Bob_Idle.x"),null);
        for(String clip:java.util.List.of(DanceCycleProbe.SOURCE,DanceCycleProbe.TARGET))skin=DanceCycleProbe.importClip(Path.of(MEDIA).resolve("anims_X/"+clip+".fbx"),skin);
        final var danceSkin=skin;var nativePlayers=new java.util.IdentityHashMap<SAOIsoPlayerShell,zombie.core.skinnedmodel.animation.AnimationPlayer>();
        nativePlayers.put(body,DanceCycleProbe.player(body,skin));nativePlayers.put(other,DanceCycleProbe.player(other,skin));
        other.setX(11.5f);other.setY(20.5f);other.setCurrent(cell.getGridSquare(11,20,0));other.setSquare(other.getCurrentSquare());other.getCurrentSquare().getMovingObjects().add(other);
        env.rawset("__nativeQueue",(JavaFunction)(f,n)->{var row=(se.krka.kahlua.vm.KahluaTable)f.get(0);var actor=(SAOIsoPlayerShell)row.rawget("character");var action=new zombie.characters.CharacterTimedActions.LuaTimedActionNew(row,actor);row.rawset("action",action);actor.StartAction(action);return 0;});
        env.rawset("__nativeUpdate",(JavaFunction)(f,n)->{var actor=(SAOIsoPlayerShell)f.get(0);var previous=actor.getCurrentSquare();if(!actor.getCharacterActions().isEmpty())actor.getCharacterActions().get(0).update();actor.setCurrent(cell.getGridSquare((int)Math.floor(actor.getX()),(int)Math.floor(actor.getY()),0));actor.setSquare(actor.getCurrentSquare());if(previous!=actor.getCurrentSquare()){previous.getMovingObjects().remove(actor);actor.getCurrentSquare().getMovingObjects().add(actor);}return 0;});
        env.rawset("__nativeDiagnostics",(JavaFunction)(f,n)->{var actor=(SAOIsoPlayerShell)f.get(0);var action=actor.getCharacterActions().isEmpty()?null:actor.getCharacterActions().get(0);System.out.println("DIAGNOSTIC "+actor.getModData().rawget("SAOPersonId")+" exists="+actor.isExistInTheWorld()+" nativeXYZ="+actor.getX()+","+actor.getY()+" square="+actor.getCurrentSquare().getX()+","+actor.getCurrentSquare().getY()+" registeredSlot="+actor.getPlayerNum()+" action="+action+" started="+(action!=null&&action.isStarted())+" clip="+actor.getVariableString("PerformingAction"));return 0;});
        env.rawset("__nativeTrack",(JavaFunction)(f,n)->{try{var actor=(SAOIsoPlayerShell)f.get(0);var clip=(String)f.get(1);var node=zombie.core.skinnedmodel.advancedanimation.AnimNode.Parse(Path.of(MEDIA).resolve("AnimSets/player/actions/"+clip+".xml").toString());DanceCycleProbe.track(nativePlayers.get(actor),danceSkin.animationClips.get(clip),node,true);return 0;}catch(Exception e){throw new IllegalStateException(e);}});
        env.rawset("__nativeLoop",(JavaFunction)(f,n)->{var actor=(SAOIsoPlayerShell)f.get(0);for(var track:nativePlayers.get(actor).getMultiTrack().getTracks())DanceCycleProbe.loop(track);return 0;});
        env.rawset("__nativePerform",(JavaFunction)(f,n)->{var actor=(SAOIsoPlayerShell)f.get(0);if(!actor.getCharacterActions().isEmpty()){var action=actor.getCharacterActions().get(0);if(action.isForceComplete()){action.perform();action.complete();actor.getCharacterActions().remove(action);}else if(action.forceStop){action.stop();actor.getCharacterActions().remove(action);}}return 0;});
        '''.replace('PERKS',json.dumps(str(perks))).replace('MEDIA',json.dumps(str(music.LS.parent)))
  java=java.replace('for(int i=1;i<args.length;i++){',inject+'for(int i=2;i<args.length;i++){').replace('System.out.println("INSTRUMENT_NATIVE_DONE");','System.out.println("INSTRUMENT_NATIVE_DONE");System.exit(0);')
  generated=out/'NativePartnerProbe.java';generated.write_text(java,encoding='utf-8')
  with tempfile.TemporaryDirectory(prefix='sao-native-partner-')as directory:
   work=Path(directory);shutil.copyfile(music.GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[music.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated],work);assert code==0,log
   def execute(name,owner):return run(name,[music.JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','-Djava.library.path='+str(music.GAME),'--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'NativePartnerProbe',music.GAME,manifest,music.FIXTURES/'prelude.lua',enums,registry,*native,music.LS/'shared/LSUtil.lua',init,music.ORG,owner,combined],music.GAME)
   code,log=execute('baseline',music.OWNER)
   assert code==0 and 'PASS native Music partner join 'in log,log[-15000:];receipt['checks']=int(re.search(r'PASS native Music partner join (\d+)',log)[1])
   controls=[
    ('live-loop-guard-in-native-perform','nativeDanceCycleCompletionCurrent','nativeDanceCycleCurrent','actual_native_M_original_perform_completed'),
    ('mutual-current-music-guards-omitted',None,None,'actual_M_withdrawn_private_music_false'),
    ('original-source-perform-omitted','pcall(native.perform,self)','pcall(function()end)','original_source_terminal_variable_transition'),
   ]
   for name,old,new,marker in ([]if a.baseline_only else controls):
    text=music.OWNER.read_text(encoding='utf-8-sig')
    if name=='mutual-current-music-guards-omitted':
     start=text.index('function M.nativeDanceCycleAllowed(');end=text.index('local function observePartnerDanceCycle(',start);part=text[start:end]
     for needle in ['valid(id,a)','valid(peer.offer.actorId,peer)']:assert part.count(needle)==1;part=part.replace(needle,'true',1)
     text=text[:start]+part+text[end:]
    elif name=='live-loop-guard-in-native-perform':
     start=text.index('action.perform=function(self)');end=text.index('action.stop=function(self)',start);part=text[start:end];assert part.count(old)==2;part=part.replace(old,new);text=text[:start]+part+text[end:]
    else:assert text.count(old)==1,(name,text.count(old));text=text.replace(old,new,1)
    mutant=out/(name+'-Music.lua');mutant.write_text(text,encoding='utf-8');code,log=execute(name,mutant)
    assert code!=0 and 'D2_NATIVE_PARTNER:'+marker in log,(name,log[-15000:]);receipt['controls'].append({'name':name,'expectedFailure':marker,'mutantSha256':music.sha(mutant)})
  receipt['inputsAfter']={str(x):music.sha(x)for x in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'inputs changed';receipt['status']='PASS';save();print('PASS native Music partner join',receipt['checks']);return 0
 except Exception as error:receipt['status']='FAIL';receipt['error']=str(error);save();raise
if __name__=='__main__':raise SystemExit(main())
