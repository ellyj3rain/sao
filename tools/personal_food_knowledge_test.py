"""Private native knowledge -> conceptual roots -> actual eating choice.

Native engine recognition runs over controlled bodies/items; Lua production
owners use controlled native boundary outputs and action queue receivers.
No loaded gameplay, assessed curriculum or general recipe-execution claim.
"""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess
import concept_observation_test as native
from native_proof_preflight import installed_presence
ROOT=native.ROOT
LUA=ROOT/'mod/42.20/media/lua'
FILES={k:LUA/f/('SAO_'+v+'.lua') for k,f,v in [
 ('models','shared','CognitiveModels'),('cognition','shared','Cognition'),
 ('perception','shared','Perception'),('concepts','shared','ConceptKnowledge'),('needs','client','Needs')]}
PRELUDE='''
SAO={Identity={},Body={active={},foreign={}},Controller={agents={}},History={},Log={line=function()end},
 Perception={beliefs={}},Disposition={traits=function()return{}end},Labor={capabilityOf=function()return{}end}}
require=function()end
Events=setmetatable({},{__index=function()return{Add=function()end,Remove=function()end}end})
ISInventoryTransferAction={derive=function()return{}end}
ISEatFoodAction={new=function(self,body,item,percentage)return{character=body,item=item,percentage=percentage}end}
instanceof=function(_,kind)return kind=="Food"end
SAOJavaBridge={isShell=function()return true end}
'''
CONTROLS=[
 ('bound-before-appraisal','concepts','for _,row in ipairs(view.foods) do\n        local identity="eat:"..row.itemId',
  'for index,row in ipairs(view.foods) do if index>15 then break end\n        local identity="eat:"..row.itemId','late_lower_risk_candidate_reaches_actual_action'),
 ('drop-native-roots','concepts','for _,edge in ipairs(background or {}) do edges[#edges+1]=copy(edge) end',
  'for _,edge in ipairs({}) do edges[#edges+1]=copy(edge) end','authentic_background_supplies_semantic_root'),
 ('discard-personal-risk','models','candidate.utility - risk * (modelId == "ordinary" and 0.45 or 0.30) + adjustment',
  'candidate.utility + adjustment','same_utilities_private_knowledge_changes_choice'),
 ('ignore-foreign-view','perception','or view.actorId~=id or view.status~="available"','or view.status~="available"','foreign_native_view_refused'),
 ('ignore-token','needs','and data.SAOExternalToken == rec.bodyOwnerToken','and true','replaced_body_token_refused'),
 ('use-first-instead-of-choice','concepts','local selected=reasoning and byId[reasoning.selected]',
  'local selected=reasoning and view.foods[1]','same_utilities_private_knowledge_changes_choice'),
 ('drop-actual-queue-selection','needs','chosen.itemId,chosen.itemType,chosen.recognizedPoison,chosen.basis',
  '81,"Base.Berry",false,"unrecognized"','known_actual_native_action'),
]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--part',choices=['lua','native'],required=True)
 ap.add_argument('--output',type=Path,required=True);ap.add_argument('--variants',nargs='*');args=ap.parse_args()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
 jar=native.GAME/'projectzomboid.jar';mod=ROOT/'mod/42.20/media/java/SAO.jar'
 java=[native.SOURCE,ROOT/'java/src/com/sao/engine/SAONeeds.java',native.BRIDGE,
       ROOT/'tools/javacheck/PersonalFoodKnowledgeProbe.java',native.BOOT]
 runner=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java';cases=ROOT/'tools/personal_food_knowledge_cases.lua'
 paths=[*FILES.values(),*java,runner,cases,Path(__file__),jar,mod,native.GAME/'ZombieBuddy.jar',native.GAME/'stdlib.lua']
 paths.append(Path(__file__).with_name('native_proof_preflight.py'))
 preflight = installed_presence(paths, native.GAME, native.JDK, "personal food knowledge")
 if preflight is not None:
     raise SystemExit(preflight)
 pins=lambda:{str(p):sha(p) for p in paths}
 receipt={'schema':'sao.personal-food-knowledge/1','part':args.part,'status':'INCOMPLETE','inputs':pins(),'variants':[],'boundary':__doc__}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(cmd,cwd):
  p=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,text=True,timeout=120)
  return p.returncode,p.stdout+p.stderr
 save()
 if args.part=='lua':
  command=[native.JDK/'javac.exe','-cp',jar,'-d',out,runner];code,log=run(command,out)
  receipt['compile']={'command':list(map(str,command)),'cwd':str(out),'exit':code};save()
  assert code==0,log
  shutil.copy2(native.GAME/'stdlib.lua',out/'stdlib.lua');(out/'prelude.lua').write_text(PRELUDE,encoding='utf-8')
  original={k:p.read_text(encoding='utf-8') for k,p in FILES.items()};original['cases']=cases.read_text(encoding='utf-8')
  variants=[('production',None,None,None,None)]+CONTROLS
 else:
  original={p.name:p.read_text(encoding='utf-8') for p in java}
  variants=[('production',None,None,None,None),
   ('omniscient-poison-filter','SAONeeds.java','&& food.getHungChange() < 0.0f && !shell.isKnownPoison(item)',
    '&& food.getHungChange() < 0.0f && food.getPoisonPower() == 0','person_facing_filter_has_no_omniscient_poison'),
   ('ignore-current-recognition','SAOConceptObservation.java','if (current.equals(basis) && recognizedPoison == !current.equals("unrecognized")) return item;',
    'if (true) return item;','native_choice_revalidates_exact_knowledge'),
   ('invent-unknown-recipe-meaning','SAOConceptObservation.java','if (!body.isKnownPoison(item)) return "unrecognized";',
    'if (!body.isKnownPoison(item) && !body.getKnownRecipes().contains("Unknown.ForgedHerbalist")) return "unrecognized";',
    'unresolved_recipe_has_no_meaning')]
 if args.variants:
  variants=[v for v in variants if v[0] in args.variants];assert len(variants)==len(args.variants)
 for name,module,before,after,marker in variants:
  texts=original.copy();target=out/name;target.mkdir(exist_ok=True);compiled=None
  if module:
   assert texts[module].count(before)==1,name+' control anchor missing or ambiguous'
   texts[module]=texts[module].replace(before,after,1)
  if args.part=='lua':
   for k,t in texts.items():(target/(k+'.lua')).write_text(t,encoding='utf-8')
   command=[native.JDK/'java.exe','-cp',os.pathsep.join(map(str,[out,jar])),'PhysicalMeansLuaProbe',out/'prelude.lua',
    *[target/(n+'.lua') for n in ['models','cognition','perception','concepts','needs','cases']],'--','__result']
   cwd=out
  else:
   for k,t in texts.items():(target/k).write_text(t,encoding='utf-8')
   cp=os.pathsep.join(map(str,[jar,native.GAME/'ZombieBuddy.jar',mod]))
   compilecmd=[native.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',target,*[target/p.name for p in java]]
   code,log=run(compilecmd,out);(target/'compile.log').write_text(log,encoding='utf-8')
   compiled={'command':list(map(str,compilecmd)),'cwd':str(out),'exit':code,'logSha256':sha(target/'compile.log')}
   assert code==0,log
   command=[native.JDK/'java.exe','-Duser.home='+str(target),'-Djava.awt.headless=true',
    '-Djava.library.path='+str(native.GAME),'-cp',str(target)+os.pathsep+cp,'PersonalFoodKnowledgeProbe'];cwd=native.GAME
  code,log=run(command,cwd);logpath=target/'run.log';logpath.write_text(log,encoding='utf-8')
  passed=(code!=0 and 'PERSONAL_FOOD:'+marker in log) if marker else code==0 and 'PASS personal food' in log
  receipt['variants'].append({'name':name,'command':list(map(str,command)),'cwd':str(cwd),'exit':code,'expectedFailure':marker,
   'mutation':{'source':module,'before':before,'after':after} if module else None,'log':str(logpath),'logSha256':sha(logpath),'passed':passed,'compile':compiled});save()
  assert passed,log
  print(name+': '+(marker or next(l for l in log.splitlines() if 'PASS personal food' in l)),flush=True)
 receipt['inputsAfter']=pins();assert receipt['inputsAfter']==receipt['inputs'],'inputs changed'
 receipt['status']='PASS';save()
if __name__=='__main__':
 try:main()
 except Exception as error:
  print('FAIL personal food: '+str(error),flush=True)
  raise SystemExit(1)
