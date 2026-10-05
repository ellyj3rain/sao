(function()
local checks = 0
local function check(name, value)
    if not value then error('CONFLICT_OBSERVATION_JOIN_CHECK:'..name) end
    checks=checks+1
end
local P,O=SAO.ProceduralPlanning,SAO.Observation
SAO.Identity.get=function(id) return __records[id] end
-- Appraisal deliberation is controlled here. The actual Planning writer,
-- admission/result owner, detached getter and Observation consumer all run.
SAO.Cognition={appraiseConflict=function(id,frame,offers)
    return {actorId=id,selected='leave',kind='withdraw',reason='The observed approach leaves little space',
        frameId='observation-40',evidenceKey='private-track',alternatives={{id='leave',kind='withdraw',
        available=true,selected=true,reason='The personally known passage may provide distance',
        objections={'Its present access is uncertain'},expectedEffects={{concept='separation',status='possible',
        basis='Travel can increase distance'}}}}}
end}
local function rows()
    __ms=__ms+1000
    local snapshot=O.capture(__ms,__hours)
    check('capture-available',snapshot.status=='available' and snapshot.capturedAtUnixMs==__ms)
    for _,section in ipairs(snapshot.people.a.sections) do
        if section.id=='planning' then
            local out={}
            for _,row in ipairs(section.rows) do out[row.label]=row.value end
            return out
        end
    end
    error('CONFLICT_OBSERVATION_JOIN_CHECK:missing-planning')
end
check('old-save-read-only',P.conflictSnapshot('a')==nil and __records.a.proceduralPlanning==nil)
local frame={actorId='a',atHours=SAO.History.countyHours(),threat={kind='zombie',source='observed',distance=4.5,count=1,key='private-track'}}
local offer={id='leave',kind='withdraw',available=true,routeKey='known-doorway'}
local choice=P.planConflict('a',frame,{offer})
check('real-planner-formed',choice~=nil and choice.kind=='withdraw')
local view=P.conflictSnapshot('a')
check('producer-schema',view.schema==1 and view.actorId=='a' and view.purposeId==choice.purposeId
    and view.alternatives[1].objections[1]=='Its present access is uncertain')
view.reason='altered detached copy'
check('producer-detached',P.conflictSnapshot('a').reason=='The observed approach leaves little space')
O.enable();O.select('a')
local shown=rows()
check('actual-getter-joined',shown['Intended response']=='withdraw'
    and shown['Response reason']=='The observed approach leaves little space'
    and shown['Threat belief']=='zombie / observed / believed distance 4.5 tiles')
check('actual-unadmitted-intent',shown['Native admission']=='No native attempt admission recorded'
    and shown['Last native attempt']=='No native attempt result recorded')
local token={owner='Locomotion',id='route-1'}
check('real-owner-admission',P.conflictAdmission('a',choice.purposeId,token,'leave'))
shown=rows()
check('actual-admission-joined',shown['Native admission']=='Locomotion admitted at game hour 26')
check('real-owner-result',P.conflictResult('a',choice.purposeId,token,
    {status='completed',reason='arrived',routeKey='known-doorway'}))
shown=rows()
check('actual-result-joined',shown['Last native attempt']=='withdraw / completed at game hour 26'
    and shown['Attempt detail']=='arrived'
    and shown['Threat after attempt']=='Requires fresh perception; the attempt result does not establish that the threat is gone')
local durable=__records.a.proceduralPlanning.purposes[choice.purposeId]
check('inspection-did-not-resolve-conflict',durable.status=='maintained'
    and durable.conflict.lastOutcome.status=='completed' and durable.conflict.needsReappraisal==true)
check('other-person-untouched',P.conflictSnapshot('b')==nil and __records.b.proceduralPlanning==nil)
return 'CONFLICT_OBSERVATION_JOIN_PASS '..checks..' checks'
end)()
