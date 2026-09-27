__transactionCase('missing_external_owner_allocates_no_shell',function()
 local rec,body=__setup()
 assert(SAO.Body.release(rec))
 rec.bodyOwner='ZAO' rec.bodyOwnerToken='owner-missing'
 local owner=SAO.Communication.executionOwners.ZAO
 SAO.Communication.executionOwners.ZAO=nil
 __now=43
 local result,reason=SAO.Body.materializeExternal(rec,'ZAO','owner-missing')
 SAO.Communication.executionOwners.ZAO=owner
 assert(not result and reason=='execution-owner-unregistered')
 assert(__spawned==0,'allocated shell escaped all owner and teardown maps')
end)

__transactionCase('foreign_invalid_drug_clock_retains_native_body',function()
 local rec,body=__setup() __foreign(rec,body)
 assert(SAO.Pharmacology.advance(rec,body,__now))
 __now=41
 local ok,result=pcall(SAO.Body.hibernateExternal,rec,body,'ZAO',rec.bodyOwnerToken)
 assert(ok and result==false and __removed==0 and not body.removed,
   'native body removed before invalid pharmacology commit was refused')
 assert(SAO.Body.foreign.p1==body and rec.hibernation=='SNAP:previous')
end)

__transactionCase('ordinary_invalid_drug_clock_retains_native_body',function()
 local rec,body=__setup()
 assert(SAO.Pharmacology.advance(rec,body,__now))
 __now=41
 assert(not SAO.Body.release(rec) and __removed==0 and not body.removed)
 assert(SAO.Body.active.p1==body and rec.hibernation=='SNAP:previous')
end)

__transactionCase('foreign_failed_removal_retries_original_snapshot',function()
 local rec,body=__setup() __foreign(rec,body)
 __remove='false'
 local ok,result=pcall(SAO.Body.hibernateExternal,rec,body,'ZAO',rec.bodyOwnerToken)
 assert(ok and result==false and SAO.Body.foreign.p1==body)
 local captured=__captures
 body.payload='partial-removal' __remove='ok'
 assert(SAO.Body.hibernateExternal(rec,body,'ZAO',rec.bodyOwnerToken))
 assert(__captures==captured and rec.hibernation=='SNAP:carried',
   'foreign retry recaptured a partly removed shell')
end)

__transactionCase('failed_native_replay_restores_record_and_retires_shell',function()
 local rec,body=__setup()
 assert(SAO.Pharmacology.advance(rec,body,__now))
 rec.pharmacology.families.sedatives.effect=40
 assert(SAO.Body.release(rec))
 local before=__copy(rec.pharmacology)
 local fatigue=rec.dormantFatigue local at=rec.dormantPhysiologyAtHours
 __now=43 __failStat='STRESS'
 local result,reason=SAO.Body.materialize(rec)
 assert(not result and reason=='pharmacology-restore-failed')
 assert(__equal(rec.pharmacology,before),'failed replay committed drug state')
 assert(rec.dormantFatigue==fatigue and rec.dormantPhysiologyAtHours==at,
   'failed replay retained advanced Rest')
 assert(not SAO.Body.active.p1 and not SAO.Body.foreign.p1 and __removed==2,
   'failed replay leaked native shell')
 __failStat=nil
 assert(SAO.Body.materialize(rec),'failed replay could not recover from immutable origin: '..tostring(__phFailure))
end)

__transactionCase('native_sleep_refusal_during_replay_is_not_published',function()
 local rec,body=__setup() body.asleep=true body.sit=true
 assert(SAO.Pharmacology.advance(rec,body,__now))
 rec.pharmacology.families.sedatives.effect=40
 assert(SAO.Body.release(rec))
 local original=SAOJavaBridge.setShellAsleep
 SAOJavaBridge.setShellAsleep=function(self,b,value)
  if value==true then original(self,b,value) end
 end
 __now=43
 local result,reason=SAO.Body.materialize(rec)
 SAOJavaBridge.setShellAsleep=original
 assert(not result and reason=='pharmacology-restore-failed',
   'published shell asleep while replay record says awake')
end)

__transactionCase('foreign_failed_replay_retains_exact_maintenance_origin',function()
 local rec,body=__setup() __foreign(rec,body)
 assert(SAO.Pharmacology.advance(rec,body,__now))
 rec.pharmacology.families.sedatives.effect=40
 assert(SAO.Body.hibernateExternal(rec,body,'ZAO',rec.bodyOwnerToken))
 local state={terminalState='crossed'}
 ZAO.Maintenance.ensure(state,42)
 local before=__copy(state)
 local owner=SAO.Communication.executionOwners.ZAO
 ZAO.Pathogen={stateOf=function(id) return id=='p1' and state or nil end}
 SAO.Communication.executionOwners.ZAO=ZAO.ExecutionOwner.adapter
 __now=43 __failStat='STRESS'
 local result,reason=SAO.Body.materializeExternal(rec,'ZAO',rec.bodyOwnerToken)
 SAO.Communication.executionOwners.ZAO=owner
 assert(not result and reason=='pharmacology-restore-failed')
 assert(__equal(state,before),'failed native replay committed external Maintenance state')
end)

__transactionCase('foreign_replay_commits_actual_maintenance_once',function()
 local rec,body=__setup() __foreign(rec,body)
 assert(SAO.Pharmacology.advance(rec,body,__now))
 rec.pharmacology.families.sedatives.effect=40
 assert(SAO.Body.hibernateExternal(rec,body,'ZAO',rec.bodyOwnerToken))
 local state={terminalState='crossed'}
 ZAO.Maintenance.ensure(state,42)
 ZAO.Pathogen={stateOf=function(id) return id=='p1' and state or nil end}
 local owner=SAO.Communication.executionOwners.ZAO
 SAO.Communication.executionOwners.ZAO=ZAO.ExecutionOwner.adapter
 __now=43
 local result,reason=SAO.Body.materializeExternal(rec,'ZAO',rec.bodyOwnerToken)
 SAO.Communication.executionOwners.ZAO=owner
 assert(result,reason)
 assert(SAO.Body.foreign.p1==result and not SAO.Body.active.p1 and not SAO.Controller.agents.p1)
 assert(math.abs(state.maintenance.predatory.pressure-.012)<.0000001
   and state.maintenance.lastAdvancedHours==43,'foreign elapsed pressure was duplicated or omitted')
 assert(math.abs(result:getStats():get(CharacterStat.HUNGER)-.212)<.0000001,
   'foreign native hunger lost its exact elapsed interval')
 assert(not rec.pharmacology.saved and not rec.pharmacology.dormant)
end)

__transactionCase('foreign_pending_release_replays_after_reload',function()
 local rec,body=__setup() __foreign(rec,body)
 __remove='false'
 assert(not SAO.Body.hibernateExternal(rec,body,'ZAO',rec.bodyOwnerToken))
 local captured=rec.bodyRelease local captures=__captures
 assert(captured and captured.releaseOwner=='ZAO' and captured.releaseToken==rec.bodyOwnerToken)
 SAO.Body.foreign={} __remove='ok'
 assert(SAO.Body.recover(rec),'foreign journal did not recover without old native body')
 assert(rec.bodyRelease==nil and rec.hibernation=='SNAP:carried' and __captures==captures)
 assert(rec.bodyOwner=='ZAO' and rec.bodyOwnerToken=='transaction-owner')
end)

__transactionCase('foreign_pending_release_refuses_replaced_owner',function()
 local rec,body=__setup() __foreign(rec,body)
 __remove='false'
 assert(not SAO.Body.hibernateExternal(rec,body,'ZAO',rec.bodyOwnerToken))
 local count=__removed
 rec.bodyOwnerToken='replacement-owner' __remove='ok'
 assert(not SAO.Body.recover(rec) and __removed==count and SAO.Body.foreign.p1==body,
   'saved foreign journal removed replacement owner')
end)

__transactionCase('foreign_pending_release_is_not_checkpointed_again',function()
 local rec,body=__setup() __foreign(rec,body)
 __remove='false'
 assert(not SAO.Body.hibernateExternal(rec,body,'ZAO',rec.bodyOwnerToken))
 local captures=__captures
 body.payload='partial-removal'
 local report=SAO.Body.checkpointActive()
 assert(report.saved==0 and __captures==captures and rec.hibernation=='SNAP:previous',
   'save checkpoint replaced a pending foreign journal')
end)

__transactionCase('native_posture_refusal_during_replay_is_not_published',function()
 local rec,body=__setup() body.asleep=true body.sit=true
 assert(SAO.Pharmacology.advance(rec,body,__now))
 rec.pharmacology.families.sedatives.effect=40
 assert(SAO.Body.release(rec))
 local spawn=SAOJavaBridge.spawnShellNamed
 SAOJavaBridge.spawnShellNamed=function(...)
  local result=spawn(...)
  local set=result.setSitOnGround
  result.setSitOnGround=function(self,value) if value==true then set(self,value) end end
  return result
 end
 __now=43
 local result,reason=SAO.Body.materialize(rec)
 SAOJavaBridge.spawnShellNamed=spawn
 assert(not result and reason=='pharmacology-restore-failed',
   'published sitting shell after replay record stopped resting')
end)

__transactionCase('missing_external_replay_hooks_allocate_no_shell',function()
 local rec,body=__setup() __foreign(rec,body)
 assert(SAO.Body.hibernateExternal(rec,body,'ZAO',rec.bodyOwnerToken))
 __now=43
 local result,reason=SAO.Body.materializeExternal(rec,'ZAO',rec.bodyOwnerToken)
 assert(not result and reason=='dormant-owner-rollback-unavailable' and __spawned==0,
   'foreign replay allocated before rollback capability admission')
end)

__transactionCase('failed_replay_teardown_retains_exact_handle_until_retry',function()
 local rec,body=__setup()
 assert(SAO.Pharmacology.advance(rec,body,__now))
 rec.pharmacology.families.sedatives.effect=40
 assert(SAO.Body.release(rec))
 __now=43 __failStat='STRESS' __remove='false'
 local result,reason=SAO.Body.materialize(rec)
 local partial=SAO.Body.active.p1
 assert(not result and reason=='pharmacology-restore-failed' and partial
   and SAO.Body.failedRestore.p1 and not SAO.Body.get('p1'),
   'failed native teardown exposed or dropped partial restoration handle')
 __remove='ok' __failStat=nil
 assert(SAO.Body.recover(rec) and partial.removed and not SAO.Body.active.p1)
 assert(SAO.Body.materialize(rec),'failed native teardown could not retry')
end)

__transactionCase('failed_external_rollback_blocks_future_materialization',function()
 local rec,body=__setup() __foreign(rec,body)
 assert(SAO.Pharmacology.advance(rec,body,__now))
 rec.pharmacology.families.sedatives.effect=40
 assert(SAO.Body.hibernateExternal(rec,body,'ZAO',rec.bodyOwnerToken))
 local state={terminalState='crossed'}
 ZAO.Maintenance.ensure(state,42)
 ZAO.Pathogen={stateOf=function(id) return id=='p1' and state or nil end}
 local owner=SAO.Communication.executionOwners.ZAO
 local adapter=ZAO.ExecutionOwner.adapter
 local rollback=adapter.rollbackDormancy
 SAO.Communication.executionOwners.ZAO=adapter
 adapter.rollbackDormancy=function() return false end
 __now=43 __failStat='STRESS'
 local result,reason=SAO.Body.materializeExternal(rec,'ZAO',rec.bodyOwnerToken)
 adapter.rollbackDormancy=rollback
 assert(not result and reason=='dormant-owner-rollback-failed'
   and rec.bodyCheckpointFailure and not SAO.Body.foreign.p1,
   'failed external rollback lost explicit unknown-state boundary')
 local allocated=__spawned __failStat=nil
 result,reason=SAO.Body.materializeExternal(rec,'ZAO',rec.bodyOwnerToken)
 SAO.Communication.executionOwners.ZAO=owner
 assert(not result and reason=='checkpoint-state-unavailable' and __spawned==allocated,
   'failed rollback silently replayed already-advanced external state')
end)

__transactionCase('replaced_execution_adapter_cannot_advance_restore',function()
 local rec,body=__setup() __foreign(rec,body)
 assert(SAO.Pharmacology.advance(rec,body,__now))
 rec.pharmacology.families.sedatives.effect=40
 assert(SAO.Body.hibernateExternal(rec,body,'ZAO',rec.bodyOwnerToken))
 local state={terminalState='crossed'}
 ZAO.Maintenance.ensure(state,42)
 ZAO.Pathogen={stateOf=function(id) return id=='p1' and state or nil end}
 local before=__copy(state)
 local owner=SAO.Communication.executionOwners.ZAO
 local adapter=ZAO.ExecutionOwner.adapter
 local begin=adapter.beginDormancy local wrongAdvances=0
 SAO.Communication.executionOwners.ZAO=adapter
 adapter.beginDormancy=function(...)
  local token=begin(...)
  SAO.Communication.executionOwners.ZAO={advanceDormant=function()
   wrongAdvances=wrongAdvances+1 return false
  end}
  return token
 end
 __now=43
 local result,reason=SAO.Body.materializeExternal(rec,'ZAO',rec.bodyOwnerToken)
 adapter.beginDormancy=begin
 SAO.Communication.executionOwners.ZAO=owner
 assert(not result and reason=='pharmacology-restore-failed' and wrongAdvances==0
   and __equal(state,before) and not SAO.Body.foreign.p1,
   'replacement execution adapter entered an already-owned restoration')
end)

local lines={}
for key,value in pairs(__transactionResults) do lines[#lines+1]=key..'='..tostring(value) end
table.sort(lines)
__transactionReport=table.concat(lines,'\n')
