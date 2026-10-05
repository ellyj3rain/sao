"""Real Lua placement and directed inquiry owners; native geometry/actions separately probed."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess
import concept_knowledge_test as base
from native_proof_preflight import installed_presence

ROOT=base.ROOT
OUT=ROOT/'_scratch/d1-shared-reasoning/means-feedback/lua'
OUT=Path(os.environ.get('SAO_RECOVERY_PLACEMENT_OUTPUT',OUT))
FILES={**base.FILES,'placement':ROOT/'tools/recovery_placement_cases.lua'}
RUNNER=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java'

def run(selected_variants=None):
    OUT.mkdir(parents=True,exist_ok=True)
    fixture=base.fixture;jar=fixture.GAME/'projectzomboid.jar'
    paths=[*FILES.values(),Path(__file__),Path(base.__file__),Path(fixture.__file__),RUNNER,jar,fixture.GAME/'stdlib.lua']
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, fixture.GAME, fixture.JDK, "recovery placement")
    if preflight is not None:
        raise SystemExit(preflight)
    pins=lambda:{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    receipt={'schema':'sao-recovery-placement-proof/1','status':'INCOMPLETE','inputs':pins(),'boundary':__doc__,'variants':[]}
    def save(): (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    def invoke(command):
        p=subprocess.run(list(map(str,command)),cwd=OUT,capture_output=True,text=True,timeout=120)
        return p.returncode,p.stdout+p.stderr
    command=[fixture.JDK/'javac.exe','-cp',jar,'-d',OUT,RUNNER]
    code,log=invoke(command);receipt['compile']={'command':list(map(str,command)),'exit':code};save();assert code==0,log
    shutil.copy2(fixture.GAME/'stdlib.lua',OUT/'stdlib.lua')
    (OUT/'prelude.lua').write_text(fixture.PRELUDE+'\nrequire=function()end\nISInventoryTransferAction={derive=function()return {}end}\n__ordinaryPerception={} for k,v in pairs(SAO.Perception) do __ordinaryPerception[k]=v end\n')
    (OUT/'capture.lua').write_text('__actualBeginRecovery=SAO.Needs.beginRecovery\n__conceptModules={planning=SAO.ProceduralPlanning,locomotion=SAO.Locomotion,perception=SAO.Perception}\nSAO.Perception=__ordinaryPerception\n')
    sources={key:path.read_text(encoding='utf-8') for key,path in FILES.items()}
    variants=[('production',None,None,None,None),
        ('floor-before-bed','controller','if a.kind~=b.kind then return a.kind=="bed" end',
            'if a.kind~=b.kind then return a.kind=="ground" end','bed_precedes_nearby_floor'),
        ('ignore-arrival-permission','controller','elseif not SAO.Standing.mayAttemptBelieved(id,place.x,place.y,"standing") then reason="standing-refused"',
            'elseif false then reason="standing-refused"','standing_change_refuses_arrival'),
        ('accept-replacement-placement-job','controller','or job~=binding.job or not job or job.body~=body then',
            'or not job or job.body~=body then','replacement_job_cannot_admit'),
        ('ignore-physical-arrival','needs','(body:getX()-candidate.x)^2+(body:getY()-candidate.y)^2<=0.35^2',
            'true','bed_precedes_nearby_floor'),
        ('ignore-changed-bed-object','needs','"key","kind","x","y","z","objectX","objectY","objectZ","objectIndex"',
            '"key","kind","x","y","z","objectX","objectY","objectZ"','changed_bed_object_cannot_inherit_target'),
        ('discard-bed-on-resume','needs','place=intent.place,bed=bed,started=true',
            'place=intent.place,started=true','bed_reload_retains_exact_native_binding'),
        ('collapse-door-direction','planning','return tostring(frontier.key).."@"..tostring(frontier.roomId)',
            'return tostring(frontier.key)','return_through_same_door_is_available'),
        ('prefer-return-over-new-door','planning','selected=selected or backtrack',
            'selected=backtrack or selected','untried_door_precedes_backtracking'),
        ('accept-stale-door-direction','planning','current.key~=target.key',
            'false','stale_frontier_direction_refused'),
        ('night-bypasses-placement','controller','return Ctl.offerRecovery(id,agent,body,tick,needs,"sleep")',
            'agent.sleeping=true;return true','night_requires_suitable_place'),
        ('reuse-nearby-old-route','controller','if not live.goal or live.goal.x~=place.x or live.goal.y~=place.y or live.goal.z~=place.z then',
            'if false then','nearby_old_goal_is_replaced_exactly'),
        ('discard-active-bed-binding','needs','local function recoveryBedBound(work)',
            'local function recoveryBedBound(work)\n    if true then return true end','bed_swap_before_reacknowledgment_refuses_credit'),
        ('ignore-pending-crossing','controller','or tostring(live.lastVerdict):sub(1,11)=="Transition:"',
            'or false','pending_crossing_is_not_cancelled_for_place'),
        ('discard-query-error','needs','if not ok then report.status,report.reason="error","native-query-error"',
            'if not ok then report.status,report.reason="unavailable","native-query-error"','query_error_distinguished'),
        ('retain-live-diagnostics','needs','report.diagnostics=copy','report.diagnostics=diagnostics','diagnostics_only_copy_whitelisted_scalars'),
        ('discard-remembered-means','planning','if direct then','if false then','remembered_means_supplies_occupied_approach'),
        ('route-onto-remembered-object','planning','out.observedMeans,out.approach,out.path=dataCopy(fact),dataCopy(room),path',
            'out.observedMeans,out.approach,out.path=dataCopy(fact),dataCopy(fact),path','remembered_means_supplies_occupied_approach'),
        ('forget-away-recovery-concern','controller','localRecovery or rememberedRecoveryInquiry(id,option.id,tick)',
            'localRecovery','away_from_home_choice_approaches_memory'),
        ('discard-urgent-memory-consumer','controller','return remembered and Ctl.beginConceptInquiry(id,agent,body,tick,remembered) or false',
            'return false','extreme_recovery_uses_same_memory_consumer'),
        ('ignore-inquiry-native-admission','controller','or not SAO.Needs.workAvailable(body) or not planning',
            'or not planning','remembered_means_respects_native_work_admission'),
        ('omit-native-means-refusal','needs','retainMeansResult(id,rec,place,"geometry",false,place.reason)',
            '-- omitted native refusal','failed_visible_means_reopens_actual_inquiry'),
        ('forget-visible-source-join','perception','copy.recoverySourceId=type(row.recoverySourceId)=="string"',
            'copy.recoverySourceId=false and type(row.recoverySourceId)=="string"','failed_visible_means_reopens_actual_inquiry'),
        ('ignore-failed-visible-means','planning','fact.roomId==context.roomId and not excludedMeans(id,goal,fact)',
            'fact.roomId==context.roomId','failed_visible_means_reopens_actual_inquiry'),
        ('revisit-failed-memory','planning','fact.roomId and fact.buildingId and not excludedMeans(id,goal,fact)',
            'fact.roomId and fact.buildingId','failed_visible_means_reopens_actual_inquiry'),
        ('failed-presence-stops-room-search','planning','fact.concept==means and not excludedMeans(id,goal,fact)',
            'fact.concept==means','failed_visible_means_reopens_actual_inquiry'),
        ('only-remembered-fallback','controller','(includeSearch or offer.mode=="remembered-means")',
            '(offer.mode=="remembered-means")','no_place_refuses_arbitrary_floor'),
        ('failure-spreads-to-other-source','planning','failure.sourceId==sourceId',
            'true','unknown_source_is_not_excluded'),
        ('failure-spreads-to-other-goal','planning','failure.goal==goal',
            'true','other_goal_is_not_excluded'),
        ('failure-spreads-to-other-person','planning','failure.actorId==id and failure.goal',
            'true and failure.goal','foreign_failure_does_not_transfer'),
        ('permanent-means-failure','planning','and at<failure.retryAtHours',
            'and true','failure_retry_uses_persisted_county_clock'),
        ('ignore-changed-native-geometry','planning','s.meansFailures[key]=nil\n            for index=#s.meansFailureOrder,1,-1 do\n                if s.meansFailureOrder[index]==key then table.remove(s.meansFailureOrder,index) end\n            end',
            '-- retained refusal despite positive native geometry','changed_native_geometry_reopens_exact_means'),
        ('geometry-erases-route-refusal','planning','s.meansFailures[key]=nil\n            for index=',
            's.meansFailures={}\n            for index=','visible_geometry_cannot_erase_failed_route'),
        ('drop-authenticated-route-refusal','controller','if not arrived then SAO.Needs.recoveryRouteResult(id,body,binding.place,binding.kind,job) end',
            '-- route refusal omitted','actual_failed_route_feeds_exact_means'),
        ('route-failure-spreads-to-other-approach','planning','or failure.candidateId==candidateId)',
            'or true)','failed_route_does_not_exclude_new_exact_approach'),
        ('replacement-route-supplies-refusal','needs','SAO.Locomotion.jobs[id]~=job',
            'false','replacement_route_cannot_supply_refusal'),
        ('queue-refusal-as-furniture-failure','needs','reason=="native-ground-clearance-refused")',
            'reason=="native-ground-clearance-refused" or reason=="native-bed-queue-refused")','queue_refusal_is_not_bad_furniture'),
        ('future-refusal-changes-inquiry','planning','finite(failure.atHours) and failure.atHours<=at and finite(failure.retryAtHours)',
            'finite(failure.atHours) and true and finite(failure.retryAtHours)','future_refusal_cannot_change_current_inquiry'),
        ('legacy-source-cooldown-blocks-new-approach','needs','function N.recoveryApproachKey(place)\n    return meansCandidate(place)',
            'function N.recoveryApproachKey(place)\n    return place.key','changed_approach_reaches_actual_controller_route')]
    if selected_variants is not None:
        variants=[v for v in variants if v[0] in selected_variants]
        assert len(variants)==len(selected_variants),'unknown placement variant'
    for name,key,old,new,marker in variants:
        texts=dict(sources)
        if key:
            assert texts[key].count(old)==1,name
            texts[key]=texts[key].replace(old,new,1)
        texts['controller']=texts['controller'].replace('return Ctl\n','Ctl.__placementNight=decideNightAndDrift\n'+fixture.EXPOSE)
        texts['cases']=texts.pop('ordinary')+'\n'+texts['cases']+'\n'+texts.pop('placement')
        for key,value in texts.items(): (OUT/(key+'.lua')).write_text(value,encoding='utf-8')
        command=[fixture.JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(OUT)]),'PhysicalMeansLuaProbe',
            'prelude.lua','models.lua','cognition.lua','needs.lua','perception.lua','concepts.lua','planning.lua',
            'locomotion.lua','capture.lua','controller.lua','cases.lua','--','__result']
        code,log=invoke(command);(OUT/(name+'.log')).write_bytes(log.encode('utf-8'))
        receipt['variants'].append({'name':name,'command':list(map(str,command)),'cwd':str(OUT),'exit':code,
            'expected':marker,'logSha256':hashlib.sha256(log.encode()).hexdigest(),
            'mutation':{'source':key,'before':old,'after':new} if old else None});save()
        assert (code!=0 and 'PLACEMENT:'+marker in log) if marker else (code==0 and 'VALUE PASS recovery placement' in log),log
        print(name+': '+next((line for line in log.splitlines() if line.startswith(('VALUE ','ERROR '))),log.strip()),flush=True)
    receipt['inputsAfter']=pins();assert receipt['inputsAfter']==receipt['inputs'],'inputs changed'
    receipt['status']='PASS';save()

if __name__=='__main__':
    try:run()
    except Exception as error:print('FAIL recovery placement:',error,flush=True);raise SystemExit(1)
