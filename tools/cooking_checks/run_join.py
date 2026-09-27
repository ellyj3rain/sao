"""Actual private Controller/Body + Cooking and production CrossedTransfer in installed Kahlua.

Native actions, SourceUse receipt closure and snapshot receivers are controlled.
Only existing private functions/runtime are exported in temporary probe copies.
Root integration sources are read-only and identified by hash in the receipt.
"""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess,tempfile
HERE=Path(__file__).resolve().parent
from config import ROOT, OUT, GAME, JDK, COOKING_LUA
PZ=GAME/'projectzomboid.jar'
FILES={'cooking':COOKING_LUA,
    'body':ROOT/'mod/42.20/media/lua/client/SAO_Body.lua',
    'controller':ROOT/'mod/42.20/media/lua/client/SAO_Controller.lua',
    'transfer':ROOT/'mod/42.20/media/lua/client/SAO_CrossedTransfer.lua'}
CONTROLS=[
    ('resume-before-cooking-quiescence', [('controller', 'if agent.rec.cookingWork and (not SAO.Cooking\n            or SAO.Cooking.interrupt(id, body, "zao-person-ownership-transfer") ~= true) then', 'if false then')], 'root_pending_zao_retires_cooking_route_before_handoff'),
    ('prepare-before-cooking-quiescence', [('body', 'if not quiesceCooking(rec, body, "body-owner-transfer") then return false, "cooking-reconciliation-pending" end', '')], 'root_prepare_handoff_quiesces_route_before_capture'),
    ('foreign-release-before-cooking-quiescence', [('body', 'if not quiesceCooking(rec, body, "external-body-release") then return false, "cooking-reconciliation-pending" end', '')], 'root_foreign_unresolved_transfer_blocks_capture_and_removal'),
    ('foreign-source-owner-ignored', [('body', 'for _, owners in ipairs({ Body.active, Body.foreign }) do\n            for id, owned in pairs(owners) do\n                if owned == body then\n                    ownerId = tostring(id)', 'for _, owners in ipairs({ Body.active }) do\n            for id, owned in pairs(owners) do\n                if owned == body then\n                    ownerId = tostring(id)')], 'root_foreign_readiness_honors_non_cooking_source_owner'),
    ('release-captures-live-cooking', [('body', 'if not quiesceCooking(rec, body, "body-release") then return false, "cooking-reconciliation-pending" end', '')], 'root_release_clears_heat_before_snapshot'),
    ('remove-before-cooking-reconciliation', [('body', 'if owned == body and not quiesceCooking(SAO.Identity.get(id), body, "body-removal") then', 'if false then')], 'root_remove_owned_refuses_unresolved_cooking'),
    ('commit-over-new-cooking', [('body', 'if rec.cookingWork then return false, "cooking-work-after-capture" end', '')], 'root_captured_journal_refuses_new_cooking_owner'),
    ('ordinary-death-retains-cooking', [('controller', '        if SAO.Cooking and SAO.Cooking.detach then\n            pcall(SAO.Cooking.detach, id, body, "death")\n        end', '')], 'root_ordinary_death_detaches_unresolved_cooking'),
    ('external-death-retains-cooking', [('controller', '    if SAO.Cooking and SAO.Cooking.detach then\n        pcall(SAO.Cooking.detach, id, body, "death")\n    end', '')], 'root_external_death_detaches_unresolved_cooking'),
    ('passive-death-retains-cooking', [('controller', '            if SAO.Cooking and SAO.Cooking.detach then\n                pcall(SAO.Cooking.detach, id, body, "death")\n            end', '')], 'root_passive_death_detaches_restored_cooking'),
    ('direct-drop-retains-cooking', [('controller', 'if rec and rec.cookingWork then\n            local okCooking, closedCooking', 'if false then\n            local okCooking, closedCooking')], 'root_direct_drop_retires_idle_heat_runtime'),
]
def main():
    sources={key:path.read_text(encoding='utf-8-sig') for key,path in FILES.items()}
    fixtures=[HERE/'prelude.lua',HERE/'join_prelude.lua',GAME/'media/lua/shared/ISBaseObject.lua',
        GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',GAME/'media/lua/shared/TimedActions/ISToggleStoveAction.lua']
    receipt={'boundary':__doc__,'inputs':{str(path):hashlib.sha256(path.read_bytes()).hexdigest() for path in list(FILES.values())+fixtures+[HERE/'join_cases.lua',PZ]},'runs':[],'controls':[]}
    expected=set(re.findall(r'case\("([a-z0-9_]+)",',(HERE/'join_cases.lua').read_text()))
    try:
        with tempfile.TemporaryDirectory(prefix='join-') as directory:
            work=Path(directory);shutil.copy2(GAME/'stdlib.lua',work/'stdlib.lua')
            def command(label,args):
                done=subprocess.run(list(map(str,args)),cwd=work,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
                receipt['runs'].append({'name':label,'exit':done.returncode,'stdout':done.stdout,'stderr':done.stderr})
                return done
            done=command('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',PZ,'-d',work,ROOT/'tools/luacheck/LuaRun.java'])
            if done.returncode:raise RuntimeError(done.stderr)
            def execute(label,mutations=()):
                changed=dict(sources)
                for key,before,after in mutations:
                    if changed[key].count(before)!=1:raise RuntimeError(label+': mutation anchor must match once: '+key)
                    changed[key]=changed[key].replace(before,after,1)
                paths=[]
                for key in ['cooking','body','controller','transfer']:
                    value=changed[key]
                    for before,after in {
                        'cooking':[('return C\n','C.__fixtureRuntime = function() return runtime end\nreturn C\n')],
                        'body':[('return Body\n','Body.__cookingFixtureRemove = removeOwned\nreturn Body\n')],
                        'controller':[('return Ctl\n','Ctl.__cookingFixtureUpdate = updateAgent\nreturn Ctl\n')],
                    }.get(key,[]):
                        if value.count(before)!=1:raise RuntimeError('Observation export drift: '+key)
                        value=value.replace(before,after,1)
                    path=work/(label+'-'+key+'.lua');path.write_text(value,encoding='utf-8');paths.append(path)
                done=command(label,[JDK/'java.exe','-Djava.awt.headless=true','-cp',str(work)+os.pathsep+str(PZ),'LuaRun',*fixtures,*paths,HERE/'join_cases.lua','--','__cookingResults'])
                checks=dict(re.findall(r'^([a-z0-9_]+)=(true|false)$',done.stdout.replace('VALUE ',''),re.M))
                if done.returncode or set(checks)!=expected:raise RuntimeError(label+': missing='+str(expected-set(checks))+' '+done.stdout[-6500:])
                return checks,changed
            checks,_=execute('candidate')
            failed=[name for name,value in checks.items() if value!='true']
            if failed:raise RuntimeError('Candidate join failures: '+', '.join(failed))
            receipt['cases']=len(checks)
            for label,mutations,target in CONTROLS:
                checks,changed=execute(label,mutations)
                if checks[target]!='false':raise RuntimeError(label+': target did not fail: '+target)
                receipt['controls'].append({'name':label,'target':target,'verdict':'false','source_sha256':{key:hashlib.sha256(changed[key].encode()).hexdigest() for key,_,_ in mutations}})
            receipt['status']='passed'
    except Exception as error:
        receipt['status']='failed';receipt['error']=str(error)
    (OUT/'join-verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({key:receipt.get(key) for key in ['status','cases','error']}))
    return 0 if receipt['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
