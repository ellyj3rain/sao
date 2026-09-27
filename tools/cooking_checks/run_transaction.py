"""Private whole Body/Snapshot/owned Pharmacology transaction fault probes.

Actual Lua owners execute in installed Kahlua; native receivers are controlled.
This is complementary to the installed native pharmacology suite.
"""
from pathlib import Path
import argparse
import hashlib, importlib.util, json, os, re, shutil, subprocess, sys, tempfile
HERE=Path(__file__).resolve().parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('root',nargs='?',type=Path,default=HERE.parents[1])
parser.add_argument('--zao-root',type=Path)
parser.add_argument('--output',type=Path)
args=parser.parse_args()
ROOT=args.root.resolve()
ZAO=(args.zao_root or ROOT.parent/'zombie-awareness').resolve()
_temporary=tempfile.TemporaryDirectory(prefix='sao-body-transaction-proof-')
OUTPUT=args.output or Path(_temporary.name)/'transaction-verification.json'
saved=sys.argv;sys.argv=[str(HERE.parent/'person_handoff_test.py'),str(ROOT)]
spec=importlib.util.spec_from_file_location('person_handoff_fixture',HERE.parent/'person_handoff_test.py')
M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M);sys.argv=saved
FILES=M.FILES
CONTROLS=[
 ('foreign-invalid-checkpoint-removal',[
  ('SAO_Body.lua','        if not SAO.BodySnapshot.valid(value, rec) then return false, "invalid-pending-snapshot" end',''),
  ('SAO_Body.lua','    if not SAO.BodySnapshot.valid(captured, rec) then return false, "invalid-pending-snapshot" end\n    if body and not removeOwned(body)', '    if body and not removeOwned(body)')],
  'foreign_invalid_drug_clock_retains_native_body'),
 ('foreign-journal-forgotten',[('SAO_Body.lua','    local captured = rec.bodyRelease','    local captured = nil')],
  'foreign_failed_removal_retries_original_snapshot'),
 ('foreign-journal-owner-ignored',[('SAO_Body.lua','if captured.releaseOwner ~= rec.bodyOwner or captured.releaseToken ~= rec.bodyOwnerToken then','if false then')],
  'foreign_pending_release_refuses_replaced_owner'),
 ('sleep-readback-ignored',[('SAO_Body.lua','body:isAsleep() ~= (rec.dormantSleeping == true)','false')],
  'native_sleep_refusal_during_replay_is_not_published'),
 ('posture-readback-ignored',[('SAO_Body.lua','body:isSitOnGround() ~= (rec.dormantResting == true or rec.dormantSleeping == true)','false')],
  'native_posture_refusal_during_replay_is_not_published'),
 ('external-owner-rollback-ignored',[('SAO_Body.lua','pcall(externalReplayOwner.rollbackDormancy, externalReplayToken)','true, true')],
  'foreign_failed_replay_retains_exact_maintenance_origin'),
 ('external-owner-copy-aliased',[('ZAO_Maintenance.lua','return { state = state, before = copyMaintenance(state.maintenance) }','return { state = state, before = state.maintenance }')],
  'foreign_failed_replay_retains_exact_maintenance_origin'),
 ('rest-rollback-ignored',[('SAO_Body.lua','            for _, key in ipairs(restKeys) do rec[key] = beforeRest[key] end','')],
  'failed_native_replay_restores_record_and_retires_shell'),
 ('failed-native-shell-lost',[('SAO_Body.lua','            Body.failedRestore[rec.id] = true\n            Body.recover(rec)\n            if not rollbackOk','            Body.recover(rec)\n            if not rollbackOk')],
  'failed_replay_teardown_retains_exact_handle_until_retry'),
 ('external-missing-owner-allocated',[('SAO_Body.lua','''        if not owner or type(owner.advanceDormant) ~= "function" then
            return nil, not owner and "execution-owner-unregistered"
                or "dormant-owner-unavailable"
        end''','''        if not owner then owner = { beginDormancy=function() return {} end,
            rollbackDormancy=function() return true end } end''')],
  'missing_external_owner_allocates_no_shell'),
 ('foreign-pending-checkpoint-overwritten',[('SAO_Body.lua','            and not hasTransitionJournal(rec) then','            then')],
  'foreign_pending_release_is_not_checkpointed_again'),
 ('external-rollback-hook-admission-ignored',[('SAO_Body.lua','''            if type(owner.beginDormancy) ~= "function"
                or type(owner.rollbackDormancy) ~= "function" then
                return nil, "dormant-owner-rollback-unavailable"
            end''','')],
  'missing_external_replay_hooks_allocate_no_shell'),
 ('failed-rollback-unmarked',[('SAO_Body.lua','                rec.bodyCheckpointFailure = { reason = "dormant-owner-rollback-failed", atHours = wakeAt }','')],
  'failed_external_rollback_blocks_future_materialization'),
 ('replaced-adapter-advances',[('SAO_Body.lua','if externalReplayOwner and SAO.Communication.executionOwners[rec.bodyOwner] ~= externalReplayOwner then','if false then')],
  'replaced_execution_adapter_cannot_advance_restore'),
]

def main():
    if not (M.GAME/'projectzomboid.jar').is_file() or not (M.JDK/'javac.exe').is_file():
        print('SKIPPED: installed game and JDK required for body transaction proof');return 0
    if not (ZAO/'mod/42.20/media/lua/shared/ZAO_ExecutionOwner.lua').is_file():
        print('SKIPPED: sibling ZAO source required for body transaction proof');return 0
    OUTPUT.parent.mkdir(parents=True,exist_ok=True)
    paths={name:M.source_path(name) for name in FILES}
    for name in ['ZAO_Maintenance.lua','ZAO_ExecutionOwner.lua']:
        paths[name]=ZAO/'mod/42.20/media/lua/shared'/name
    receipt={'boundary':__doc__,'inputs':{str(p):hashlib.sha256(p.read_bytes()).hexdigest()
      for p in list(paths.values())+[HERE/'transaction_prelude.lua',HERE/'transaction_cases.lua',Path(__file__),
        Path(M.__file__),M.GAME/'projectzomboid.jar',ROOT/'tools/luacheck/LuaRun.java']},'runs':[],'controls':[]}
    sources={name:path.read_text(encoding='utf-8-sig') for name,path in paths.items()}
    expected=set(re.findall(r"__transactionCase\('([a-z0-9_]+)'",(HERE/'transaction_cases.lua').read_text()))
    with tempfile.TemporaryDirectory(prefix='body-transaction-') as directory:
        work=Path(directory);shutil.copy2(M.GAME/'stdlib.lua',work/'stdlib.lua')
        built=subprocess.run([str(M.JDK/'javac.exe'),'-encoding','UTF-8','-cp',str(M.GAME/'projectzomboid.jar'),'-d',str(work),
          str(ROOT/'tools/luacheck/LuaRun.java')],capture_output=True,text=True,timeout=60)
        if built.returncode:raise RuntimeError(built.stderr)
        pre=work/'prelude.lua';pre.write_text('require=function() end\n'+M.PRELUDE,encoding='utf-8')
        def execute(label,mutations=()):
            changed=dict(sources)
            for name,before,after in mutations:
                if changed[name].count(before)!=1:raise RuntimeError(label+': mutation anchor must match once: '+name)
                changed[name]=changed[name].replace(before,after,1)
            chunks=[pre]
            for name,source in changed.items():
                if name=='SAO_Pharmacology.lua':
                    source=source.replace('local ok=pcall(function()\n        local original=', 'local ok,err=pcall(function()\n        local original=')
                    source=source.replace('if not ok then return false,"native-restore-refused" end', 'if not ok then __phFailure=tostring(err) return false,"native-restore-refused" end')
                out=work/name;out.write_text(M.instrument(name,source),encoding='utf-8');chunks.append(out)
            result=subprocess.run([str(M.JDK/'java.exe'),'-Djava.awt.headless=true','-cp',str(work)+os.pathsep+str(M.GAME/'projectzomboid.jar'),
              'LuaRun',*map(str,chunks),str(HERE/'transaction_prelude.lua'),str(HERE/'transaction_cases.lua'),'--','__transactionReport'],
              cwd=work,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
            receipt['runs'].append({'name':label,'exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr})
            lines=[line.replace('VALUE ','',1) for line in result.stdout.splitlines() if '=' in line]
            checks=dict(line.split('=',1) for line in lines if line.split('=',1)[0].replace('_','').isalnum())
            if set(checks)!=expected:raise RuntimeError(label+': missing='+str(expected-set(checks))+' '+result.stdout)
            return checks,changed
        try:
            checks,_=execute('candidate')
            receipt['checks']=checks;receipt['cases']=len(checks)
            if any(value!='true' for value in checks.values()):raise RuntimeError('Failed cases: '+str(checks))
            for label,mutations,target in CONTROLS:
                checks,changed=execute(label,mutations)
                if checks[target]=='true':raise RuntimeError(label+': named target did not fail: '+target)
                receipt['controls'].append({'name':label,'target':target,'failure':checks[target],
                    'sha256':{name:hashlib.sha256(changed[name].encode()).hexdigest() for name,_,_ in mutations}})
            receipt['status']='passed'
        except Exception as error:
            receipt['status']='failed';receipt['error']=str(error)
    OUTPUT.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({key:receipt.get(key) for key in ['status','cases','error']}));print('CONTROLS',len(receipt['controls']))
    return int(receipt['status']!='passed')
if __name__=='__main__':raise SystemExit(main())
