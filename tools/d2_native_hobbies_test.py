#!/usr/bin/env python3
"""Original Lifestyle action/utility, native Stats and durable attempt controls."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get('PZ_DIR', r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK = Path(os.environ.get('JDK_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
SOURCE = Path(os.environ.get('LIFESTYLE_DIR', r'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3403870858\mods\Lifestyle'))
FIXTURES = ROOT / 'tools/d2_native_hobbies'
OWNER = ROOT / 'mod/42.20/media/lua/client/SAO_Leisure.lua'
CONTROLS = [
    ('foreign-offer', 'not equivalent(current, offer)', 'false', 'spoof_offer_refused'),
    ('body-owner', 'SAO.Needs.ownsRecoveryBody(id, body) == true', 'true', 'foreign_body_refused'),
    ('owned-source-presence', 'not (SAO.SourceIntegration and SAO.SourceIntegration.available(SOURCE))', 'false', 'owned_source_missing_refused'),
    ('person-knowledge', 'if not evidence then return {}, "meditation-not-personally-understood" end',
     'if not evidence then evidence = {} end', 'unacquired_concept_refused'),
    ('progress', 'or rec.leisureWork.progress <= 0 or self:getJobDelta() < 1',
     'or false or self:getJobDelta() < 1', 'instant_perform_no_proof'),
    ('detached-outcome', 'then return plain(row) end', 'then return row end', 'detached_outcome'),
    ('planner-admission', 'not planner.admitHobbyWork(id, purposeId, sequence)', 'false', 'planner_refusal_prevents_queue'),
    ('manufactured-completion', 'finish(id, "interrupted", active.failureReason or "native-source-stopped")',
     'active.performed = true; finish(id, "completed", active.failureReason or "native-source-stopped")', 'partial_is_interruption'),
    ('missing-source-initialization', 'LSMoodleManager.init(body)', 'local ignored = body', 'source_actor_initialized'),
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, default=ROOT / '_scratch/d2-leisure-01/native-hobbies/proof-01')
    parser.add_argument('--baseline-only', action='store_true')
    args = parser.parse_args()
    args.out = args.out.resolve()
    args.out.mkdir(parents=True, exist_ok=False)
    action = SOURCE / 'common/media/lua/shared/TimedActions/LSMeditateAction.lua'
    voice = SOURCE / 'common/media/lua/client/TimedActions/PlayerVoiceTracks.lua'
    utility = SOURCE / 'common/media/lua/shared/LSUtil.lua'
    menu = SOURCE / 'common/media/lua/client/ISMeditation/ZenWellnessContextMenu.lua'
    manager = SOURCE / 'common/media/lua/client/LSMoodleManager.lua'
    properties = SOURCE / 'common/media/lua/client/Properties/MoodleProperties.lua'
    native = [GAME / 'media/lua/shared/ISBaseObject.lua', GAME / 'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
    jars = [GAME / 'projectzomboid.jar', *sorted((GAME / 'jars').glob('*.jar'))]
    skill_owner=ROOT/'mod/42.20/media/lua/client/SAO_LeisureSkill.lua'
    instrument_probe=ROOT/'tools/instrument_checks/InstrumentProbe.java'
    native_helpers=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',ROOT/'tools/cognition_checks/CognitionUseProbe.java']
    native_jars=[GAME/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar']
    inputs = [Path(__file__), OWNER, *FIXTURES.iterdir(), action, voice, utility, menu, manager, properties,
              SOURCE / '42/mod.info', SOURCE/'common/media/perks.txt',GAME/'stdlib.lua', *native, *jars,
              skill_owner,instrument_probe,*native_helpers,*native_jars]
    absent = installed_presence(inputs, GAME, JDK, 'D2 original native hobbies',installed_roots=(SOURCE,))
    if absent is not None:
        return absent
    pins = {str(path): sha(path) for path in inputs}
    receipt = {'schema': 'sao-d2-native-hobbies-proof/2', 'status': 'INCOMPLETE', 'inputsBefore': pins, 'runs': [],
        'boundary': 'Original installed Lifestyle constructors/start/update/perform/stop and full LSUtil sealed in actor-local Kahlua environments; native Stats and save/load. Old action boundary uses controlled body/queue/clock/neck/presentation/planner and canonical request receiver. Joined native XP probe uses actual off-slot SAOIsoPlayerShell bodies, source Meditation perk parsing, original complete source action/utility, native GlobalObject.addXp/SyncXp and native XP. Audio hardware, timed-action queue/clock, concept familiarity and typed admission hosts remain controlled; no rendered game or multiplayer authority claim.'}
    def save():
        (args.out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    def run(name, command, cwd):
        result = subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True, timeout=90)
        log = args.out / (name + '.log')
        log.write_bytes(result.stdout + result.stderr)
        receipt['runs'].append({'name': name, 'exitCode': result.returncode, 'log': str(log), 'logSha256': sha(log)})
        save()
        return result.returncode, log.read_text(encoding='utf-8', errors='replace')
    try:
        text = OWNER.read_text(encoding='utf-8')
        for path in (action, voice, utility, menu, manager, properties):
            assert sha(path) in text, 'source revision differs: ' + str(path)
        cases = (FIXTURES / 'cases.lua').read_text(encoding='utf-8')
        expected = len(re.findall(r"check\('[a-z0-9_]+", cases))
        receipt['checks'] = expected
        with tempfile.TemporaryDirectory(prefix='sao-hobbies-') as temp:
            work = Path(temp)
            shutil.copyfile(GAME/'stdlib.lua', work/'stdlib.lua')
            manager_text = manager.read_text(encoding='utf-8')
            prefix = 'LSMoodleManager.init = function(player)'
            assert manager_text.count(prefix) == 1
            initializer = prefix + manager_text.split(prefix, 1)[1].split('function LSMoodleManager.getMoodle', 1)[0]
            init_file = args.out / 'source-initializer.lua'
            init_file.write_text('__moodleProperties=(function()\n' + properties.read_text(encoding='utf-8')
                + '\nend)()\nLSMoodleManager={}\nrequire=function(name)if name=="Properties/MoodleProperties" then return __moodleProperties end end\n'
                + initializer, encoding='utf-8', newline='')
            cp = os.pathsep.join(map(str, jars))
            code, log = run('compile', [JDK/'javac.exe', '-encoding', 'UTF-8', '-cp', cp, '-d', work, FIXTURES/'HobbyProbe.java'], work)
            assert code == 0, log
            rows = [('baseline', None, None, None)]
            if not args.baseline_only:
                rows += CONTROLS
            receipt['controls'] = []
            for name, before, after, marker in rows:
                source = text
                if before:
                    assert source.count(before) == (2 if name == 'person-knowledge' else 1), name
                    source = source.replace(before, after, 1)
                variant = args.out / (name + '-owner.lua')
                variant.write_text(source, encoding='utf-8', newline='')
                code, log = run(name, [JDK/'java.exe', '-Djava.awt.headless=true', '--enable-native-access=ALL-UNNAMED',
                    '-cp', str(work)+os.pathsep+cp, 'HobbyProbe', FIXTURES/'prelude.lua', *native,
                    utility, action, voice, init_file, variant, FIXTURES/'cases.lua'], work)
                if marker:
                    assert code != 0 and 'D2_HOBBY:' + marker in log, (name, log[-4000:])
                    receipt['controls'].append({'name': name, 'expectedFailure': marker})
                else:
                    assert code == 0 and 'PASS D2 native hobbies ' + str(expected) in log, log[-4000:]
            java=instrument_probe.read_text(encoding='utf-8').replace('public final class InstrumentProbe','public final class MeditationXPProbe')
            java=java.replace('IsoCell.class,zombie.iso.IsoGridSquare.class','java.util.Map.class,zombie.characters.IsoGameCharacter.XP.class,zombie.characters.skills.PerkFactory.Perk.class,zombie.characters.skills.PerkFactory.Perks.class,zombie.scripting.objects.CharacterTrait.class,zombie.characters.BodyDamage.Metabolics.class,\n            IsoCell.class,zombie.iso.IsoGridSquare.class')
            injection='''LuaCompiler.register(env);
        var custom=new zombie.characters.skills.CustomPerks();
        var readPerks=zombie.characters.skills.CustomPerks.class.getDeclaredMethod("readFile",String.class);readPerks.setAccessible(true);
        readPerks.invoke(custom,PERKS_PATH);custom.init();custom.initLua();
        var global=new zombie.Lua.LuaManager.GlobalObject();
        env.rawset("addXp",(JavaFunction)(frame,count)->{global.addXp((zombie.characters.IsoPlayer)frame.get(0),(zombie.characters.skills.PerkFactory.Perk)frame.get(1),((Number)frame.get(2)).floatValue());return 0;});
        env.rawset("SyncXp",(JavaFunction)(frame,count)->{global.SyncXp((zombie.characters.IsoPlayer)frame.get(0));return 0;});
        env.rawset("__clearXP",(JavaFunction)(frame,count)->{body.getXp().xpMap.clear();other.getXp().xpMap.clear();return 0;});
        var texts=platform.newTable();
        texts.rawset("shared/LSUtil.lua",Files.readString(Path.of(UTILITY_PATH)).replace("\\r\\n","\\n"));
        texts.rawset("shared/TimedActions/LSMeditateAction.lua",Files.readString(Path.of(ACTION_PATH)).replace("\\r\\n","\\n"));
        texts.rawset("client/TimedActions/PlayerVoiceTracks.lua",Files.readString(Path.of(VOICE_PATH)).replace("\\r\\n","\\n"));
        env.rawset("__sourceTexts",texts);
        env.rawset("__reloadMeditation",(JavaFunction)(frame,count)->{
            try{thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[args.length-2])),"reloaded-meditation",env),null,null,null);}
            catch(Exception error){throw new IllegalStateException(error);}return 0;
        });
        '''
            for marker,path in [('PERKS_PATH',SOURCE/'common/media/perks.txt'),('UTILITY_PATH',utility),('ACTION_PATH',action),('VOICE_PATH',voice)]:
                injection=injection.replace(marker,json.dumps(str(path)))
            java=java.replace('env.rawset("__body",body);',injection+'env.rawset("__body",body);')
            probe=args.out/'MeditationXPProbe.java';probe.write_text(java,encoding='utf-8')
            ncp=os.pathsep.join(map(str,[*jars,*native_jars]))
            code,log=run('native-XP-compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',ncp,'-d',work,*native_helpers,probe],work)
            assert code==0,log
            receiver=skill_owner.read_text(encoding='utf-8-sig')
            receipt['nativeXPControls']=[]
            variants=[('native-XP',receiver,text,None)]
            if not args.baseline_only:
                variants+=[('native-XP-omitted',receiver.replace('addXp(body,perk,request.amount)','-- omit actual native application',1),text,'joined_native_XP')]
                for name,before,after,marker in [
                    ('native-source-pin','h1~=pin[1] or h2~=pin[2] or #lines~=pin[3]','false','changed_source_refused'),
                    ('native-private-request','active.skillRequests and active.skillRequests[sequence]',
                     'person(id).leisureSkillRequests and person(id).leisureSkillRequests[sequence]','saved_request_tampering_refused'),
                    ('native-source-receiver','SAO.LeisureSkill.consume(id,body,"SAO.Leisure",work.sequence,request.sequence)',
                     'local ignored = request','joined_native_XP'),
                    ('native-mastered-zero','not finite(args[2]) or args[2]<0','not finite(args[2]) or args[2]<=0','mastered_source_zero_noop'),
                    ('native-dead-source-flag','data.IsMeditating=false','local ignored=data','dead_source_preserves_follower'),
                    ('native-source-resets-followers','if queue.current==action then queue:onCompleted(action)else queue:removeFromQueue(action)end',
                     'queue:resetQueue()','retired_purpose_detach_cleans_only_own_action')]:
                    assert text.count(before)==(2 if name=='native-source-resets-followers' else 1),name
                    variants.append((name,receiver,text.replace(before,after,1),marker))
            for name,contents,owner_contents,marker in variants:
                variant=args.out/(name+'-receiver.lua');variant.write_text(contents,encoding='utf-8')
                owner_variant=args.out/(name+'-native-owner.lua');owner_variant.write_text(owner_contents,encoding='utf-8')
                code,log=run(name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
                    '-cp',str(work)+os.pathsep+ncp,'MeditationXPProbe',GAME,FIXTURES/'native-xp-prelude.lua',*native,
                    utility,action,init_file,variant,owner_variant,FIXTURES/'native-xp-cases.lua'],work)
                if marker:
                    assert code!=0 and 'D2_NATIVE_MEDITATION:'+marker in log,log[-5000:]
                    receipt['nativeXPControls'].append({'name':name,'expectedFailure':marker})
                else:
                    assert code==0 and 'PASS native meditation XP ' in log,log[-6500:]
                    receipt['nativeXPChecks']=int(re.search(r'PASS native meditation XP (\d+)',log)[1])
        receipt['inputsAfter'] = {str(path): sha(path) for path in inputs}
        assert pins == receipt['inputsAfter'], 'inputs changed during proof'
        receipt['status'] = 'PASS'
        save()
        print('PASS D2 native hobbies', expected, 'checks;', receipt['nativeXPChecks'], 'joined native XP checks;',
              len(receipt['controls'])+len(receipt['nativeXPControls']), 'defect controls')
        return 0
    except Exception as error:
        receipt['status'] = 'FAIL'
        receipt['error'] = str(error)
        save()
        raise


if __name__ == '__main__':
    raise SystemExit(main())
