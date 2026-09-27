"""Actual candidate + installed vanilla timed-action Lua, in installed Kahlua.

Bodies, transfer receipts and thermal receivers are controlled here. The
separate CookingProbe runs the actual native Food/stove/XP mechanisms.
"""
from pathlib import Path
import hashlib, json, os, re, shutil, subprocess, tempfile
HERE=Path(__file__).resolve().parent
from config import ROOT, OUT, GAME, JDK, COOKING_LUA
PZ=GAME/'projectzomboid.jar'
SOURCES=[HERE/'prelude.lua',GAME/'media/lua/shared/ISBaseObject.lua',
    GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
    GAME/'media/lua/shared/TimedActions/ISToggleStoveAction.lua',
    COOKING_LUA,HERE/'cases.lua']
CONTROLS = [
    ('cancel-instead-of-reapproach', '    if not state then\n        -- Native separation', '    if not state then\n        if work.stage ~= "approach-appliance" then return finish(id, "interrupted", "appliance-unavailable") end\n        -- Native separation', 'bumped_cook_reapproaches_same_heat_without_remote_read'),
    ('reuse-stale-appliance-approach', 'route(id, body, rt, approach)', 'route(id, body, rt, appliance)', 'bumped_cook_reapproaches_same_heat_without_remote_read'),
    ('read-heat-before-physical-return', '        local approach = SAOJavaBridge:cookingApproach', '        SAOJavaBridge:cookingHeatState(body, work.id)\n        local approach = SAOJavaBridge:cookingApproach', 'bumped_cook_reapproaches_same_heat_without_remote_read'),
    ('discard-binding-before-physical-return', '        local approach = SAOJavaBridge:cookingApproach', '        SAOJavaBridge:clearCookingHeat(body, work.id)\n        local approach = SAOJavaBridge:cookingApproach', 'bumped_cook_reapproaches_same_heat_without_remote_read'),
    ('reapproach-different-source', 'approach.sourceId ~= work.sourceId or approach.sourceX', 'approach.sourceX', 'reach_repair_rejects_changed_appliance_identity'),
    ('reapproach-relocated-source', 'approach.sourceX ~= appliance.sourceX\n            or ', '', 'reach_repair_rejects_relocated_source'),
    ('discard-six-hour-budget', 'if hours() - work.startedAt > 6 or hours() < work.startedAt then', 'if false then', 'reach_repair_keeps_six_hour_budget'),
    ('fake-cooked-write', '            work.stage = "heat"', '            item.cooked = true\n            work.stage = "heat"', 'physical_deposit_has_no_cooked_write'),
    ('queued-toggle-as-completion', '    if not SAO.Needs.queueVerified(action) then action.saoCancelled = true rt.toggle = nil return "failed" end',
        '    if not SAO.Needs.queueVerified(action) then action.saoCancelled = true rt.toggle = nil return "failed" end\n    rt.appliance.object:Toggle()', 'native_toggle_completion_owns_activation'),
    ('foreign-receipt-actor', 'or receipt.reservationId ~= work.transferId or receipt.actorId ~= id',
        'or receipt.reservationId ~= work.transferId', 'transfer_receipt_requires_actor'),
    ('foreign-receipt-reservation', 'or receipt.reservationId ~= work.transferId or receipt.actorId ~= id',
        'or receipt.actorId ~= id', 'transfer_receipt_requires_reservation'),
    ('foreign-receipt-source', 'or receipt.operation ~= work.transferOperation or receipt.sourceId ~= work.transferSource',
        'or receipt.operation ~= work.transferOperation', 'transfer_receipt_requires_source'),
    ('foreign-receipt-operation', 'or receipt.operation ~= work.transferOperation or receipt.sourceId ~= work.transferSource',
        'or receipt.sourceId ~= work.transferSource', 'transfer_receipt_requires_operation'),
    ('receipt-without-physical-transfer', 'if item:getContainer() ~= expected then', 'if false then', 'completed_receipt_requires_physical_item_transfer'),
    ('skip-personal-inspection', 'local inspected, reason = SAO.WorldSources.inspectContainer(id, body, context)',
        'local inspected, reason = true, nil', 'physical_deposit_requires_personal_inspection'),
    ('fabricate-native-completion', 'local result = SAOJavaBridge:completeCookingHeat(body, work.id)',
        'local result = { credited = true, actorId = id, workId = work.id, itemId = work.itemId, progressed = true }', 'native_completion_refusal_cannot_report_success'),
    ('drop-unreconciled-source-owner', 'if not body or SAO.SourceUse.closeForOwnershipTransfer(id, body, reason) ~= true then',
        'if false then', 'interruption_preserves_unreconciled_source_owner'),
    ('admit-foreign-route', 'if job and not job.done then return false end', 'if false then return false end', 'foreign_route_prevents_admission'),
    ('ignore-new-foreign-route', 'if job and not job.done and job ~= rt.route then', 'if false then', 'new_foreign_route_interrupts_stationary_cooking'),
    ('ignore-body-owner-token', 'or data.SAOExternalToken ~= rec.bodyOwnerToken then return nil end', 'then return nil end', 'foreign_token_mismatch_cannot_begin'),
    ('admit-passive-sao-owner', 'or agent.passive or agent.state == "PASSIVE"', 'or agent.state == "PASSIVE"', 'passive_sao_owner_cannot_begin'),
    ('admit-sleeping-body', 'or body:isAsleep() or body:isDead() then return false end', 'or body:isDead() then return false end', 'sleeping_body_cannot_begin'),
    ('leave-owned-stove-on', 'if rt.turnedOn and state.active then', 'if false then', 'native_progression_retrieval_and_shutdown_complete'),
    ('ignore-other-meal', 'if otherMeal(id, rt) then work.shutdown = "shared-use"', 'if false then work.shutdown = "shared-use"', 'another_meal_prevents_owned_shutdown'),
    ('shutdown-refusal-as-success', 'if switched ~= "done" then return finish(id, "interrupted", "appliance-shutdown-refused") end',
        'if switched ~= "done" then return finish(id, "completed", "native-food-cooked-and-retrieved") end', 'failed_shutdown_queue_is_not_success'),
    ('ignore-queue-identity', 'if SAO.Needs.busy(body) and not (rt.toggle and queued(body, rt.toggle)) then',
        'if SAO.Needs.busy(body) and not rt.toggle then', 'lost_toggle_queue_cannot_keep_ownership'),
    ('retain-runtime-on-load', '    runtime = {}\nend', '    -- restored defect: runtime survives world reset\nend', 'load_clears_runtime_without_restored_success'),
    ('retain-dead-runtime', '    runtime[id] = nil\n    local work = rec and rec.cookingWork',
        '    -- restored defect: dead runtime retained\n    local work = rec and rec.cookingWork', 'death_detach_drops_runtime_with_unresolved_transfer'),
    ('detach-wrong-body', 'if rt and rt.body ~= body then return false, "body-mismatch" end',
        'if false then return false, "body-mismatch" end', 'detach_refuses_wrong_body_without_releasing_work'),
    ('detach-clears-unresolved-source', '        return true, "source-pending"',
        '        rec.worldSourceReservation = nil\n        return true, "source-pending"', 'death_detach_drops_runtime_with_unresolved_transfer'),
    ('detach-loses-thermal-clear', '    pcall(function() SAOJavaBridge:clearCookingHeat(rt.body, workId) end)',
        '    -- restored defect: native binding retained', 'death_detach_clears_exact_thermal_binding'),
    ('detach-steals-foreign-route', 'SAO.Locomotion.jobs[id] == rt.route',
        'true', 'detach_preserves_foreign_route_and_reservation'),
    ('detach-retires-new-work', 'if not work or rt and work.id ~= rt.workId then',
        'if not work then', 'detach_does_not_retire_replacement_work'),
]

def main():
    receipt = {'boundary': __doc__, 'inputs': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCES+[PZ]}, 'runs': []}
    expected = set(re.findall(r'case\("([a-z0-9_]+)",', (HERE/'cases.lua').read_text()))
    try:
        with tempfile.TemporaryDirectory(prefix='kahlua-') as directory:
            work = Path(directory); shutil.copy2(GAME/'stdlib.lua', work/'stdlib.lua')
            def command(label, args):
                done = subprocess.run(list(map(str,args)), cwd=work, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60)
                receipt['runs'].append({'name':label,'exit':done.returncode,'stdout':done.stdout,'stderr':done.stderr})
                return done
            done = command('compile', [JDK/'javac.exe','-encoding','UTF-8','-cp',PZ,'-d',work,ROOT/'tools/luacheck/LuaRun.java'])
            if done.returncode: raise RuntimeError(done.stderr)
            def execute(label, changed=None):
                paths=list(SOURCES)
                original = changed if changed is not None else (COOKING_LUA).read_text(encoding='utf-8')
                if original.count('return C\n') != 1: raise RuntimeError('Runtime observation export drift')
                instrumented=original.replace('return C\n','C.__fixtureRuntime = function() return runtime end\nreturn C\n')
                path=work/(label+'.lua'); path.write_text(instrumented,encoding='utf-8'); paths[-2]=path
                done=command(label,[JDK/'java.exe','-Djava.awt.headless=true','-cp',str(work)+os.pathsep+str(PZ),'LuaRun',*paths,'--','__cookingResults'])
                checks=dict(re.findall(r'^([a-z0-9_]+)=(true|false)$',done.stdout.replace('VALUE ',''),re.M))
                if done.returncode or set(checks)!=expected:
                    raise RuntimeError(f'{label}: missing={expected-set(checks)} exit={done.returncode} {done.stdout[-6000:]}')
                return checks
            checks=execute('candidate')
            failures=[k for k,v in checks.items() if v!='true']
            if failures: raise RuntimeError('Candidate cases failed: '+', '.join(failures))
            receipt['cases']=len(checks); receipt['controls']=[]
            source=(COOKING_LUA).read_text(encoding='utf-8-sig')
            for name,before,after,target in CONTROLS:
                if source.count(before)!=1: raise RuntimeError(name+': mutation anchor must match exactly once')
                changed=source.replace(before,after,1); checks=execute(name,changed)
                if checks[target]!='false': raise RuntimeError(name+': target did not flip: '+target)
                if 'CASE_ERROR '+target+':' in receipt['runs'][-1]['stdout']:
                    raise RuntimeError(name+': target failed by exception instead of its verdict')
                receipt['controls'].append({'name':name,'target':target,'source_sha256':hashlib.sha256(changed.encode()).hexdigest(),'verdict':checks[target]})
            receipt['status']='passed'
    except Exception as error:
        receipt['status']='failed'; receipt['error']=str(error)
    (OUT/'lua-verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:receipt.get(k) for k in ('status','cases','error')}))
    if receipt['status']=='passed': print('CONTROLS',len(receipt['controls']))
    return 0 if receipt['status']=='passed' else 1
if __name__=='__main__': raise SystemExit(main())
