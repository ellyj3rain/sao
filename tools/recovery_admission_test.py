from pathlib import Path
import hashlib,json,subprocess,shutil,sys,os
HERE=Path(__file__).resolve().parent;OWNER=HERE.parent
ROOT=next(p for p in HERE.parents if (p/'NEO.md').is_file())
sys.path.insert(0,str(ROOT/'tools'))
import concept_knowledge_test as base
import recovery_placement_test as placement
OUT=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'_scratch/recovery-admission-regression'
OUT=OUT.resolve()
if not base.fixture.GAME.joinpath('projectzomboid.jar').is_file():
    print('SKIP recovery admission: installed Project Zomboid unavailable');raise SystemExit(0)
OUT.mkdir(parents=True,exist_ok=True)
adapter=ROOT
paths={**base.FILES,'controller':OWNER/'mod/42.20/media/lua/client/SAO_Controller.lua',
    'needs':OWNER/'mod/42.20/media/lua/client/SAO_Needs.lua',
    'pose':adapter/'mod/42.20/media/lua/client/SAO_RecoveryPose.lua',
    'placement':adapter/'tools/recovery_placement_cases.lua','admission':HERE/'recovery_admission_cases.lua'}
fixture=base.fixture;jar=fixture.GAME/'projectzomboid.jar';runner=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=[*paths.values(),Path(__file__),Path(base.__file__),Path(placement.__file__),Path(fixture.__file__),runner,jar,fixture.GAME/'stdlib.lua']
pins={str(p):sha(p)for p in inputs}
def run(command,name):
    p=subprocess.run(list(map(str,command)),cwd=OUT,capture_output=True,timeout=120)
    log=OUT/(name+'.log');log.write_bytes(p.stdout+p.stderr)
    return p.returncode,log.read_text(errors='replace'),{'command':list(map(str,command)),'exit':p.returncode,'logSha256':sha(log)}
code,log,compileRow=run([fixture.JDK/'javac.exe','-cp',jar,'-d',OUT,runner],'compile');assert code==0,log
shutil.copyfile(fixture.GAME/'stdlib.lua',OUT/'stdlib.lua')
(OUT/'prelude.lua').write_bytes((fixture.PRELUDE+'\nrequire=function()end\nISInventoryTransferAction={derive=function()return {}end}\n__ordinaryPerception={} for k,v in pairs(SAO.Perception) do __ordinaryPerception[k]=v end\n').encode())
(OUT/'capture.lua').write_bytes(b'__actualBeginRecovery=SAO.Needs.beginRecovery\n__conceptModules={planning=SAO.ProceduralPlanning,locomotion=SAO.Locomotion,perception=SAO.Perception}\nSAO.Perception=__ordinaryPerception\n')
sources={k:p.read_text(encoding='utf-8')for k,p in paths.items()}
sources['controller']=sources['controller'].replace('return Ctl\n','Ctl.__placementNight=decideNightAndDrift\nCtl.__recoveryProbeTick=function(value)tickCount=value end\n'+fixture.EXPOSE)
sources['pose']=sources['pose'].replace('return P\n','__actualRecoveryPose=SAO.RecoveryPose\nreturn P\n')
sources['cases']=sources.pop('ordinary')+'\n'+sources['cases']+'\n'+sources.pop('placement')+'\n'+sources.pop('admission')
mutants={
 'drop-pending':('if reason=="native-body-not-idle" and not retrying then','if false then','arrival_holds_selected_intent'),
 'drop-live-consumer':('if Ctl.pollRecoveryAdmission(id,agent,body,tick,needs,threat) then return true end','if false then return true end','native_boundary_wait_not_new_route'),
 'drop-custody':('or not ok or not owned or not SAO.Needs.ownsRecoveryBody(id,body) then','or false then','returned_token_cannot_retry'),
 'drop-place':('elseif not SAO.Needs.recoveryPlaceAt(id,body,pending.place) then','elseif false then','changed_bed_cannot_retry'),
 'drop-threat':('elseif threat or not mayEnterBelieved(id,body:getX(),body:getY())','elseif false or not mayEnterBelieved(id,body:getX(),body:getY())','threat_interrupts_wait'),
 'drop-deadline':('elseif tick<pending.startedAt or tick>=pending.deadline then','elseif false then','bounded_idle_wait_expires'),
 'drop-state-release':('if state ~= "IDLE" and agent.recoveryAdmission then','if false and agent.recoveryAdmission then','state_change_releases_pending_choice')}
new_mutants={
 'drop-saved-producer':('needs','if type(intent)=="table" and intent.status=="preparing" then','if false then','saved_preparation_survives_without_native_pose'),
 'drop-saved-live-consumer':('controller','elseif status=="saved-preparation" then','elseif false then','actual_decide_consumes_saved_preparation'),
 'drop-deadline-copy':('controller','agent.rec.recoveryIntent.resumeWaitDeadline=pending.deadline','agent.rec.recoveryIntent.resumeWaitDeadline=nil','second_reload_reuses_original_window'),
 'drop-receiver-guard':('controller','if not agent or SAO.Identity.get(id)~=agent.rec or not SAO.Needs.ownsRecoveryBody(id,body) then','if false then','returned_token_does_not_erase_owner_choice'),
 'drop-reservation-guard':('controller','or agent.rec.worldSourceReservation~=nil','or false','source_reservation_refused'),
 'drop-saved-source-guard':('controller','source~=pending.savedPreparation or not choice','false or not choice','changed_choice_is_not_replaced_or_erased')}
route_mutants={
 'drop-rebind-tuple':('needs','if candidate[key]~=choice.place[key] then same=false;break end','if false then same=false;break end','changed_object_tuple_cannot_rebind'),
 'drop-route-deadline':('controller','local clockReason=savedPreparationClockReason(intent,tick)\n    if clockReason then return clockReason end','local clockReason=nil\n    if clockReason then return clockReason end','original_deadline_expires_during_travel'),
 'drop-route-consumer':('controller','if not route or not route.savedPreparation then return false end','if true then return false end','actual_decide_reacquires_fresh_place_at_arrival'),
 'drop-route-job':('controller','elseif job~=route.job or not job or job.body~=body or not job.goal\n        or job.goal.x~=route.place.x or job.goal.y~=route.place.y or job.goal.z~=route.place.z then reason="saved-approach-route-replaced"','elseif false then reason="saved-approach-route-replaced"','replaced_job_preserves_foreign_movement'),
 'drop-route-reservation':('controller','if savedPreparationWorkBlocked(id,agent,body) or not SAO.Needs.workAvailable(body) then return "owned-work-unavailable" end','if not SAO.Needs.workAvailable(body) then return "owned-work-unavailable" end','new_reservation_interrupts_route_without_stealing_work'),
 'drop-route-receiver':('controller','if route.body~=body or route.rec~=agent.rec or SAO.Identity.get(id)~=route.rec then return false end','if false then return false end','foreign_receiver_does_not_consume_existing_route')}
budget_mutants={
 'restore-short-travel':('controller','intent.resumeTravelDeadline or tick+1800','intent.resumeTravelDeadline or tick+120','saved_navigation_uses_existing_travel_budget'),
 'renew-travel-on-reload':('controller','intent.resumeTravelStartedAt or tick,intent.resumeTravelDeadline or tick+1800','tick,tick+1800','travel_reload_keeps_original1800'),
 'drop-travel-copy':('controller','agent.rec.recoveryIntent.resumeTravelDeadline=pending.savedPreparation.resumeTravelDeadline','agent.rec.recoveryIntent.resumeTravelDeadline=nil','fresh_queue_preserves_both_bounded_origins'),
 'renew-arrival-wait':('controller','local startedAt=route.savedPreparation.resumeWaitStartedAt or tick\n    local deadline=route.savedPreparation.resumeWaitDeadline or tick+120','local startedAt=tick\n    local deadline=tick+120','arrival_preserves_preexisting_wait120')}
receipt={'schema':'sao-recovery-admission-proof/1','status':'INCOMPLETE','inputs':pins,'compile':compileRow,'variants':[],
 'boundary':'Installed Kahlua actual Controller/Needs/adapter custody and real local decide caller. Saved preparing choice revalidates current owners; native state/geometry controlled. Fresh measured segment excludes preload interval. No rendered recovery claim.'}
for name in ['production',*mutants,*new_mutants,*route_mutants,*budget_mutants]:
    texts=dict(sources)
    if name in mutants:
        old,new,marker=mutants[name];assert texts['controller'].count(old)==1,name
        texts['controller']=texts['controller'].replace(old,new)
        if name=='drop-place':
            old='elseif not SAO.Needs.recoveryPlaceAt(id,body,place) then reason="recovery-place-unavailable"'
            assert texts['controller'].count(old)==1
            texts['controller']=texts['controller'].replace(old,'elseif false then reason="recovery-place-unavailable"')
    elif name in new_mutants:
        owner,old,new,marker=new_mutants[name];assert texts[owner].count(old)==1,name
        texts[owner]=texts[owner].replace(old,new)
    elif name in route_mutants:
        owner,old,new,marker=route_mutants[name];assert texts[owner].count(old)==1,name
        texts[owner]=texts[owner].replace(old,new)
    elif name in budget_mutants:
        owner,old,new,marker=budget_mutants[name];assert texts[owner].count(old)==1,name
        texts[owner]=texts[owner].replace(old,new)
    else:marker=None
    directory=OUT/name;directory.mkdir()
    for k,v in texts.items():(directory/(k+'.lua')).write_bytes(v.encode())
    command=[fixture.JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(OUT)]),'PhysicalMeansLuaProbe',str(OUT/'prelude.lua')]
    command += [str(directory/(k+'.lua'))if k!='capture' else str(OUT/'capture.lua')for k in ['models','cognition','needs','perception','concepts','planning','locomotion','capture','controller','pose','cases']]
    command+=['--','__result']
    code,log,row=run(command,name);row.update({'name':name,'expected':marker});receipt['variants'].append(row)
    (OUT/'receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
    expected=('PLACEMENT:withdrawn_place_cannot_start_at_arrival' if name=='drop-place' else ('BUDGET:' if name in budget_mutants else 'REBINDED:' if name in route_mutants else 'PREPARING:' if name in new_mutants else 'ADMISSION:')+str(marker))
    if name=='drop-rebind-tuple': expected='PREPARING:changed_native_place_refused'
    if name=='drop-route-consumer': expected='BUDGET:first_observed_arrival_starts_only_idle120'
    row['actualExpectedMarker']=expected if marker else None
    assert (code!=0 and expected in log)if marker else(code==0 and 'VALUE PASS recovery admission 'in log),log
    print(name+': '+next((x for x in log.splitlines()if x.startswith(('VALUE ','ERROR '))),log[-150:]),flush=True)
receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsAfter']==pins
receipt['status']='PASS';(OUT/'receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
