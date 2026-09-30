#!/usr/bin/env python3
"""Border 218: blocked private resource goals request independently answered help.

Production Coordination and Organization run in installed Kahlua. Person-private
planning input is controlled; Borders 216/217 cover its production and execution.
This checks requests, not observed cooperation prevalence or dataset admission.
"""
from pathlib import Path
import re
import natural_cooperation_test as native

ROOT = Path(__file__).resolve().parent.parent
COORD = ROOT / 'mod/42.20/media/lua/shared/SAO_Coordination.lua'
ORG = ROOT / 'mod/42.20/media/lua/shared/SAO_Organization.lua'
NEEDS = ROOT / 'mod/42.20/media/lua/client/SAO_Needs.lua'

PRELUDE = native.FORMATION_PRELUDE + r'''
__situation.resolved=true
__situation.pressure=0
__situation.foodPressure=0
__situation.waterPressure=0
__plans={}
SAO.ProceduralPlanning={resourceDemand=function(id,category)
 return __plans[id] and __plans[id][category]
end}
'''

PROBE = r'''(function()
 local checks={}
 local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
 local function actor(id,changes)
  __records[id]={id=id,dead=false}
  __records[id..'-helper']={id=id..'-helper',dead=false}
  __contacts[id]={{id=id..'-helper',x=10,y=10,observedAtHours=100,hostile=false}}
  local plan={id='purpose:'..id,resourceCategory='food',status='blocked',assessedAt=100,
   blockers={'no-known-executable-resource-route'},demand={pressure=.5,ownedReady=0,
   ownedWater=0,basis='native-own-inventory-and-private-observations',uncertainty='helper assent unknown'}}
  for key,value in pairs(changes or {}) do plan[key]=value end
  __plans[id]={food=plan}
  return plan
 end
 local function originate(id)
  return SAO.Coordination.originatePrivateSituation(id,nil,'idle','border218')
 end
 local Org=SAO.Organization
 local plan=actor('forecast')
 local process=originate('forecast')
 local view=process and Org.viewFor('forecast',process.id,false)
 local proposal=view and view.proposal.proposal
 check('blocked_goal_prompts_native_cooperation',proposal~=nil
  and proposal.resourcePurposeId==plan.id and proposal.category=='food'
  and Org.enactedProcedure(process.id,1).steps['prepare-material']~=nil)
 check('request_never_grants_assent_or_capacity',process~=nil
  and Org.activeCommitment('forecast-helper','provisioning')==nil)
 check('forecast_preserves_current_need_observation',__situation.resolved==true
  and __situation.pressure==0 and __situation.category=='food')
 local revision=process and process.revision
 check('same_unmet_goal_retains_process',originate('forecast')==process
  and process.revision==revision)
 Org.recordReception(process.id,'forecast-helper',1,'spoken','forecast',{})
 local reply=Org.appraiseMatter(process.id,'forecast-helper',{choice='decline',owner='border218',
  executor='border218',currentActivity='idle',capabilities={acquire=true,prepare=true,carry=true,deliver=true},
  relationship=.2,ownNeed=.1,destinationKnown=true,
  constraints={executionOwnerAvailable=true,ownNeedAvailable=true},inputOwners={}})
 check('recipient_can_refuse_forecast_help',reply and reply.response=='decline'
  and Org.activeCommitment('forecast-helper','provisioning')==nil)
 actor('feasible',{status='maintained',blockers={}})
 check('available_personal_chain_does_not_request_replacement',originate('feasible')==nil)
 local stocked=actor('stocked');stocked.demand.ownedReady=1
 check('held_usable_stock_resolves_forecast_request',originate('stocked')==nil)
 actor('stale',{assessedAt=98})
 check('old_plan_does_not_propagate_pressure',originate('stale')==nil)
 actor('future',{assessedAt=101})
 check('future_dated_plan_does_not_propagate_pressure',originate('future')==nil)
 actor('admitted',{admission={correlationId='current-native-work'}})
 check('admitted_work_is_not_reassigned',originate('admitted')==nil)
 actor('tired',{blockers={'current-body-unavailable-for-work'}})
 check('body_unavailability_does_not_invent_material_shortage',originate('tired')==nil)
 local low=actor('low');low.demand.pressure=.1
 check('low_pressure_leaves_room_for_ease',originate('low')==nil)
 actor('priority');__situation.resolved=false;__situation.category='water';__situation.pressure=.9
 local immediate=originate('priority')
 local urgent=immediate and Org.viewFor('priority',immediate.id,false).proposal.proposal
 check('current_need_precedes_anticipatory_goal',urgent and urgent.category=='water'
  and urgent.resourcePurposeId==nil)
 __situation.resolved=true;__situation.category='food';__situation.pressure=0
 local stronger=actor('stronger');stronger.demand.pressure=.8
 __plans.stronger.water={id='weaker-water',status='blocked',assessedAt=100,
  blockers={'no-known-executable-resource-route'},demand={pressure=.3,ownedWater=0}}
 local chosen=originate('stronger')
 check('stronger_private_pressure_selects_request',chosen
  and Org.viewFor('stronger',chosen.id,false).proposal.proposal.resourcePurposeId==stronger.id)
 plan.status='completed'
 local ended,why=originate('forecast')
 check('resolved_goal_withdraws_existing_matter',ended==process and why=='withdrawn')
 return table.concat(checks,',')
end)()'''

CONTROLS = [
 ('held stock', 'and owned == 0', 'and true', 'held_usable_stock_resolves_forecast_request'),
 ('fresh evidence', 'and now - assessedAt <= 1', 'and true', 'old_plan_does_not_propagate_pressure'),
 ('current admission', 'and not purpose.admission', 'and true', 'admitted_work_is_not_reassigned'),
 ('missing means', 'and missingMeans', 'and true', 'body_unavailability_does_not_invent_material_shortage'),
 ('low pressure', 'pressure >= 0.2', 'pressure >= 0', 'low_pressure_leaves_room_for_ease'),
]

WATER_PRELUDE = r'''
SAO={Needs={},SourceUse={beginTransfer=function(id,body,category,admission,item,container,operation,context)
 __selected=item;__calls=__calls+1;return true,{itemId=item.id}
end}}
__calls=0
SAOJavaBridge={findNearbyContainer=function() return __container end,
 privateContainerItems=function() return {size=function() return #__items end,get=function(_,i) return __items[i+1] end} end}
local N=SAO.Needs
local function carriedVessels() return {} end
'''
WATER_PROBE = r'''(function()
 local checks={}
 local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
 local function vessel(id,amount,water,poison,taint)
  return {id=id,getFluidContainerFromSelfOrWorldItem=function()
   return {getAmount=function() return amount end,isWaterSource=function() return water end,
    isPoisonous=function() return poison end,isTainted=function() return taint end}
  end}
 end
 local petrol=vessel('petrol',1,false,false,false)
 local tainted=vessel('tainted',1,true,false,true)
 local poisoned=vessel('poisoned',1,true,true,false)
 local empty=vessel('empty',0,true,false,false)
 local water=vessel('water',1,true,false,false)
 __container={};__items={petrol,tainted,poisoned,empty,water}
 check('collection_skips_unusable_fluids_for_real_water',SAO.Needs.collectStoredWater('a',{}, {})==true and __selected==water)
 __selected=nil
 check('personal_water_collection_uses_same_potable_predicate',SAO.Needs.takeStoredWater('a',{})==true and __selected==water)
 __items={petrol};__selected=nil;local calls=__calls
 check('nonwater_is_not_portable_provisioning',not SAO.Needs.collectStoredWater('a',{}, {}) and __calls==calls)
 __items={tainted};__selected=nil
 check('tainted_water_is_not_portable_provisioning',not SAO.Needs.collectStoredWater('a',{}, {}) and __calls==calls)
 __items={poisoned};__selected=nil
 check('poisoned_water_is_not_portable_provisioning',not SAO.Needs.collectStoredWater('a',{}, {}) and __calls==calls)
 __items={empty};__selected=nil
 check('empty_vessel_is_not_portable_provisioning',not SAO.Needs.collectStoredWater('a',{}, {}) and __calls==calls)
 check('missing_native_fluid_is_unknown',not SAO.Needs.portableWaterItem({}))
 return table.concat(checks,',')
end)()'''
WATER_CONTROLS = [
 ('fluid:isWaterSource()', 'true', 'nonwater_is_not_portable_provisioning'),
 ('not fluid:isTainted()', 'true', 'tainted_water_is_not_portable_provisioning'),
 ('not fluid:isPoisonous()', 'true', 'poisoned_water_is_not_portable_provisioning'),
]

def main():
    if not all(p.is_file() for p in (native.PZ, native.STDLIB, native.JDK/'java.exe', native.JDK/'javac.exe')):
        print('Border 218 SKIPPED: installed game VM or JDK absent'); return 0
    built, detail = native.compile_runner()
    if not built:
        print('FAULT Border 218 runner:', detail[-1500:]); return 1
    coord = COORD.read_text(encoding='utf-8-sig')
    org = ORG.read_text(encoding='utf-8-sig')
    expected = set(re.findall(r"check\('([a-z0-9_]+)'", PROBE))
    def run(source):
        value, output = native.run_probe(PRELUDE, [('organization.lua',org),('coordination.lua',source)], PROBE)
        result = native.verdicts(value)
        if set(result) != expected: raise RuntimeError(output[-3500:])
        return result
    try:
        result = run(coord)
        failures = [key for key,value in result.items() if value!='true']
        if failures: raise RuntimeError(', '.join(failures))
        for name,before,after,target in CONTROLS:
            if coord.count(before)!=1: raise RuntimeError(name+': mutation anchor differs')
            if run(coord.replace(before,after,1))[target]!='false': raise RuntimeError(name+': mutation survived')
        needs=NEEDS.read_text(encoding='utf-8-sig')
        water_source=needs.split('function N.portableWaterItem',1)[1].split('function N.depositWater',1)[0]
        water_source='function N.portableWaterItem'+water_source
        water_source+='function N.takeStoredWater'+needs.split('function N.takeStoredWater',1)[1].split('function N.depositSpareFood',1)[0]
        water_expected=set(re.findall(r"check\('([a-z0-9_]+)'",WATER_PROBE))
        def water_run(source):
            value,output=native.run_probe('',[('water.lua',WATER_PRELUDE+source)],WATER_PROBE)
            found=native.verdicts(value)
            if set(found)!=water_expected: raise RuntimeError(output[-3500:])
            return found
        failures=[key for key,value in water_run(water_source).items() if value!='true']
        if failures: raise RuntimeError(', '.join(failures))
        for before,after,target in WATER_CONTROLS:
            if water_source.count(before)!=1: raise RuntimeError(target+': water mutation anchor differs')
            if water_run(water_source.replace(before,after,1))[target]!='false': raise RuntimeError(target+': water mutation survived')
        print(f'Border 218 PASS: {len(expected)+len(water_expected)} installed Kahlua cases; {len(CONTROLS)+len(WATER_CONTROLS)} causal controls')
        return 0
    except Exception as error:
        print('FAULT Border 218:',error); return 1

if __name__=='__main__': raise SystemExit(main())
