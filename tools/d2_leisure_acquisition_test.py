"""Production leisure source/planner/transfer-ledger join in installed Kahlua.

Exact physical transfer and metadata-preview receivers use existing controlled
SourceUse fixtures. This proves producer/consumer selection, custody admission,
same-purpose continuity and refusals; native transport and source metadata require
their separate installed-owner proof. No rendered gameplay or outcome is inferred.
"""
import argparse,hashlib,json,os,re,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
LUA=ROOT/'mod/42.20/media/lua'
FILES={'world':LUA/'shared/SAO_WorldSources.lua','plan':LUA/'shared/SAO_ProceduralPlanning.lua',
       'source':LUA/'client/SAO_SourceUse.lua','acquisition':LUA/'client/SAO_LeisureAcquisition.lua'}
CASES=Path(__file__).with_name('d2_leisure_acquisition_cases.lua')
CONTROLS=[
 ('private-type-preview','acquisition','row.itemType==itemType','true','preview_type_cannot_substitute_known_item'),
 ('owner-binding','plan','acquisition.owner == owner','true','replacement_owner_refused_false'),
 ('exact-item-binding','acquisition','if bound then','if true then','replacement_item_refused_false'),
 ('forget-acquisition-purpose','plan','local purpose = acquired or leisurePurpose','local purpose = leisurePurpose','native_hobby_retains_original_purpose_false'),
 ('source-revision','world','physical.revision == source.revision','true','changed_private_revision_refused'),
 ('station-context','acquisition','local contextual=row.role=="playable-item"','local contextual=true','station_material_needs_acquired_context'),
 ('lose-material-retry-chain','plan','if not a.resultId and a.sourceId==exact.sourceId','if false and a.sourceId==exact.sourceId','second_material_retry_retains_original_chain'),
 ('replace-selected-requirement','acquisition','if exact.requirement[key]~=row.requirement[key] then return false end','if false then return false end','selected_requirement_revision_cannot_change'),
 ('replace-selected-source','acquisition','if exact.option.parameters[key]~=row.option.parameters[key] then return false end','if false then return false end','selected_source_revision_cannot_change'),
]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--baseline-only',action='store_true');ap.add_argument('--required',action='store_true');args=ap.parse_args()
 game=Path(os.environ.get('PZ_GAME_DIR',os.environ.get('PZ_DIR',r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid')))
 jdk=Path(os.environ.get('JDK_BIN',r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
 helper=ROOT/'tools/native_proof_preflight.py'
 if not helper.is_file():print('FAILED D2 acquisition: owned proof inputs absent: '+str(helper));return 1
 from native_proof_preflight import presence
 owned=[Path(__file__),helper,CASES,*FILES.values(),ROOT/'tools/source_use_test.py',ROOT/'tools/luacheck/LuaRun.java']
 installed=[game/'projectzomboid.jar',game/'stdlib.lua',jdk/'java.exe',jdk/'javac.exe']
 preflight=presence(owned,installed,args.required,'D2 acquisition')
 if preflight is not None:return preflight
 import source_use_test as fixture
 fixture.PZ_DIR=game;fixture.JDK=jdk
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 inputs=owned+installed
 receipt={'status':'INCOMPLETE','boundary':__doc__,'inputsBefore':{str(p):sha(p)for p in inputs},'runs':[],'controls':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd,wd):
  r=subprocess.run(list(map(str,cmd)),cwd=wd,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr)
  receipt['runs'].append({'name':name,'exitCode':r.returncode,'log':str(log),'sha256':sha(log)});save();return r.returncode,log.read_text(encoding='utf-8',errors='replace')
 try:
  with tempfile.TemporaryDirectory(prefix='sao-leisure-acquisition-')as tmp:
   work=Path(tmp);(work/'stdlib.lua').write_bytes((fixture.PZ_DIR/'stdlib.lua').read_bytes())
   status,log=run('compile',[fixture.JDK/'javac.exe','-encoding','UTF-8','-cp',fixture.PZ_DIR/'projectzomboid.jar','-d',work,ROOT/'tools/luacheck/LuaRun.java'],work);assert status==0,log
   source={'id':'C:cards:0','fp':'cards','rev':'r1','kind':'container','x':8,'y':8,'building':42,
      'quantities':{'leisure-material':2},'items':[{'id':11,'type':'Base.CardDeck','amount':0,'cats':'leisure-material'},
      {'id':12,'type':'Base.Dice','amount':0,'cats':'leisure-material'}]}
   post=dict(source,rev='r2',quantities={'leisure-material':1},items=source['items'][1:])
   ground=dict(source,id='G:cards',kind='ground',quantities={'leisure-material':1},items=source['items'][:1])
   coins=[{'id':21,'type':'Base.SilverCoin','amount':0,'cats':'leisure-material'},
          {'id':22,'type':'Base.SilverCoin','amount':0,'cats':'leisure-material'}]
   arcade=dict(source,id='C:arcade:0',fp='arcade-currency',items=coins)
   arcade_after_first=dict(arcade,rev='r2',quantities={'leisure-material':1},items=coins[1:])
   arcade_after_both=dict(arcade,rev='r3',quantities={},items=[])
   setup='require=function()end\nModData.get=function(k)return __stores[k]end\nSAO.Controller={agents={}}\n'
   for name,rows in [('before',[source]),('changedBefore',[dict(source,rev='r2')]),('after',[post]),('afterBoth',[dict(source,rev='r3',state='spent',quantities={},items=[])]),('groundBefore',[ground]),('groundAfter',[]),('arcadeBefore',[arcade]),('arcadeAfterFirst',[arcade_after_first]),('arcadeAfterBoth',[arcade_after_both])]:setup+='__'+name+'='+json.dumps(fixture.snapshot(1,1,name,rows))+'\n'
   for name,src in [('containerTransfer','C:cards:0'),('groundTransfer','G:cards')]:setup+='__'+name+'='+json.dumps('T|operation=acquire|source='+src+'|id=11|type=Base.CardDeck|uses=1|amount=0|fluid=|poison=0|rotten=0|cats=leisure-material')+'\n'
   for name,item_id in [('arcadeTransferFirst',21),('arcadeTransferSecond',22)]:setup+='__'+name+'='+json.dumps('T|operation=acquire|source=C:arcade:0|id='+str(item_id)+'|type=Base.SilverCoin|uses=1|amount=0|fluid=|poison=0|rotten=0|cats=leisure-material')+'\n'
   paths=[]
   for name,text in [('prelude',fixture.ACTION_PRELUDE),('setup',setup)]:p=out/(name+'.lua');p.write_text(text,encoding='utf-8');paths.append(p)
   texts={k:p.read_text(encoding='utf-8-sig')for k,p in FILES.items()}
   variants=[('baseline',None,None,None,None)]
   # Each restored defect must fail the stated production-join assertion.
   if not args.baseline_only:variants+=CONTROLS
   for name,target,before,after,marker in variants:
    code=dict(texts)
    if target:
     assert before in code[target],(name,before);code[target]=code[target].replace(before,after,1)
    loaded=[]
    for key,text in code.items():p=out/(name+'-'+key+'.lua');p.write_text(text,encoding='utf-8');loaded.append(p)
    status,log=run(name,[fixture.JDK/'java.exe','-Djava.awt.headless=true','-cp',str(work)+os.pathsep+str(fixture.PZ_DIR/'projectzomboid.jar'),'LuaRun',*paths,*loaded,CASES,'--','__acquisitionResults'],work)
    if marker:assert status!=0 and 'D2_ACQUISITION:'+marker in log,(name,log[-6000:]);receipt['controls'].append({'name':name,'failedCheck':marker})
    else:assert status==0 and 'PASS D2 acquisition 'in log,log[-7000:];receipt['checks']=int(re.search(r'PASS D2 acquisition (\d+)',log).group(1))
   receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsAfter']==receipt['inputsBefore'],'input drift';receipt['status']='PASS'
 except Exception as e:receipt['failure']=str(e);save();print('FAIL',e);return 1
 save();print('PASS D2 acquisition',receipt['checks'],len(receipt['controls']));return 0
if __name__=='__main__':raise SystemExit(main())
