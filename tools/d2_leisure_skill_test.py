#!/usr/bin/env python3
"""Actual installed SP NPC XP owner, source-issued requests and typed admission.

Installed LS art adjustStats and AddXP handler, native custom-perk parser,
GlobalObject.addXp/SyncXp, NPC bodies/XP and Kahlua serialization are real.
Provider action/callback custody and random draw are controlled inputs. This
does not establish loaded source action participation or multiplayer NPC joins.
"""
import argparse,hashlib,json,os,subprocess,tempfile
from pathlib import Path
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parent.parent
GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
SOURCE=Path(r'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3403870858\mods\Lifestyle\common\media')
OWNER=ROOT/'mod/42.20/media/lua/client/SAO_LeisureSkill.lua'
PLAN=ROOT/'mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua'
CASES=ROOT/'tools/d2_leisure_skill/cases.lua';PRELUDE=CASES.with_name('prelude.lua')
CONTROLS=[
 ('foreign-body','or not live(id,body) then','then','foreign_body_refused'),
 ('foreign-request','request.actorId~=id','false','foreign_request_refused'),
 ('work-correlation','request.workId~=work.workId','false','foreign_work_refused'),
 ('future-request','request.atHours>at','false','future_request_refused'),
 ('source-revision','request.revision~=work.revision','false','source_revision_refused'),
 ('source-progress','progress.actionStarted~=true','false','actual_source_progress_required'),
 ('retired-work','work.status~="active"','false','retired_native_work_refused'),
 ('stale-generation','if work.bodyGenerationKnown~=(type(token)=="string" and #token>0)\n        or work.bodyToken~=token or token~=nil and not text(token,160) then','if false then','stale_body_generation_refused'),
 ('typed-owner','admission.ownerName~=name','false','wrong_typed_owner_refused'),
 ('duplicate','if cursor and (workSequence<cursor.workSequence or sequence<=cursor.sequence) then\n        return false,S.receipt(id,name,workSequence,sequence) or "request-already-consumed"\n    end\n    local expected=cursor and cursor.sequence+1 or 1',
  'local expected=sequence','duplicate_request_refused'),
 ('native-receiver','addXp(body,perk,request.amount)','-- omit actual native application','native_same_body_XP_applied'),
 ('reset-sequence-new-work','local expected=cursor and cursor.sequence+1 or 1','local expected=cursor and workSequence==cursor.workSequence and cursor.sequence+1 or 1','global_sequence_survives_second_work'),
]
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--baseline-only',action='store_true');args=p.parse_args()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False);sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
 probe=ROOT/'tools/instrument_checks/InstrumentProbe.java'
 helpers=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',ROOT/'tools/cognition_checks/CognitionUseProbe.java']
 jars=[GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar']
 art=SOURCE/'lua/shared/TimedActions/LSCanvasPaintingAction.lua';commands=SOURCE/'lua/server/LSservercommands.lua'
 inputs=[Path(__file__),OWNER,PLAN,PRELUDE,CASES,probe,*helpers,*jars,art,commands,SOURCE/'perks.txt',GAME/'stdlib.lua']
 absent=installed_presence(inputs,GAME,JDK,'D2 d2_leisure_skill_test',installed_roots=(SOURCE,));
 if absent is not None:return absent
 receipt={'status':'INCOMPLETE','inputsBefore':{str(f):sha(f) for f in inputs},'runs':[],'boundary':__doc__}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd,cwd):
  result=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=100)
  log=out/(name+'.log');log.write_bytes(result.stdout+result.stderr)
  receipt['runs'].append({'name':name,'exitCode':result.returncode,'log':str(log),'sha256':sha(log)});save()
  return result.returncode,log.read_text(encoding='utf-8',errors='replace')
 try:
  with tempfile.TemporaryDirectory(prefix='sao-skill-') as temporary:
   work=Path(temporary);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes())
   java=probe.read_text(encoding='utf-8').replace('public final class InstrumentProbe','public final class D2LeisureSkillProbe')
   java=java.replace('IsoCell.class,zombie.iso.IsoGridSquare.class','java.util.HashMap.class,java.util.Map.class,zombie.characters.IsoGameCharacter.XP.class,zombie.characters.skills.PerkFactory.Perk.class,zombie.characters.skills.PerkFactory.Perks.class,\n            IsoCell.class,zombie.iso.IsoGridSquare.class')
   injection='''var custom=new zombie.characters.skills.CustomPerks();
        var readPerks=zombie.characters.skills.CustomPerks.class.getDeclaredMethod("readFile",String.class);readPerks.setAccessible(true);
        readPerks.invoke(custom,PERKS_PATH);custom.init();custom.initLua();
        var global=new zombie.Lua.LuaManager.GlobalObject();
        env.rawset("addXp",(JavaFunction)(frame,count)->{global.addXp((zombie.characters.IsoPlayer)frame.get(0),(zombie.characters.skills.PerkFactory.Perk)frame.get(1),((Number)frame.get(2)).floatValue());return 0;});
        env.rawset("SyncXp",(JavaFunction)(frame,count)->{global.SyncXp((zombie.characters.IsoPlayer)frame.get(0));return 0;});
        env.rawset("__clearXP",(JavaFunction)(frame,count)->{body.getXp().xpMap.clear();other.getXp().xpMap.clear();return 0;});
        '''.replace('PERKS_PATH',json.dumps(str(SOURCE/'perks.txt')))
   java=java.replace('env.rawset("__body",body);',injection+'env.rawset("__body",body);')
   generated=out/'D2LeisureSkillProbe.java';generated.write_text(java,encoding='utf-8')
   cp=os.pathsep.join(map(str,jars));code,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated],work);assert code==0,log
   source=art.read_text(encoding='utf-8-sig')
   action=source[source.index('local function adjustStats('):source.index('local function getNewPalette(')].replace('local function adjustStats(', 'function __sourceIssueArt(',1)
   command=commands.read_text(encoding='utf-8-sig');operation=command[command.index('LS_Commands["AddXP"] = function'):command.index('LS_Commands["AddXPBatch"]')]
   operation=operation.replace('LS_Commands["AddXP"] = function','__sourceAddXP = function',1)
   source_file=out/'actual-source-functions.lua';source_file.write_text(action+'\n'+operation,encoding='utf-8')
   plan_file=out/'actual-planner.lua';plan_file.write_bytes(PLAN.read_bytes())
   production=OWNER.read_text(encoding='utf-8-sig');expected=CASES.read_text(encoding='utf-8').count("check('")
   receipt['checks']=expected;receipt['controls']=[]
   for name,before,after,marker in [('baseline',None,None,None)]+([] if args.baseline_only else CONTROLS):
    variant=production
    if before:assert before in variant,name;variant=variant.replace(before,after,1)
    variant_file=out/(name+'-owner.lua');variant_file.write_text(variant,encoding='utf-8')
    code,log=run(name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
       '-cp',str(work)+os.pathsep+cp,'D2LeisureSkillProbe',GAME,PRELUDE,plan_file,source_file,variant_file,CASES],work)
    if marker:assert code!=0 and 'LEISURE_SKILL:'+marker in log,(name,log[-4000:]);receipt['controls'].append({'name':name,'reason':marker})
    else:assert code==0 and 'PASS leisure skill '+str(expected) in log,log[-6000:]
   receipt['inputsAfter']={str(f):sha(f) for f in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'input drift'
   receipt['status']='PASS'
 except Exception as error:receipt['failure']=str(error);save();print('FAIL',error);return 1
 save();print('PASS leisure skill',receipt['checks'],'checks',len(receipt['controls']),'controls');return 0
if __name__=='__main__':raise SystemExit(main())
