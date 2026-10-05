(function()
local checks = 0
local function check(name, value)
    if not value then error("CONFLICT_OBSERVATION_CHECK:" .. name) end
    checks = checks + 1
end
local function find(section, label)
    for _, item in ipairs(section.rows or {}) do if item.label == label then return item.value end end
end
local function planning(snapshot, id)
    for _, section in ipairs(snapshot.people[id].sections) do if section.id == "planning" then return section end end
end
local function contains(value, part) return type(value) == 'string' and string.find(value, part, 1, true) ~= nil end
local O = SAO.Observation
local reads, value, fails = {}, nil, false
local base = {purposes={}, spatialFacts=0, practiceDomains=0}
SAO.ProceduralPlanning = {snapshot=function() return base end,
    conflictSnapshot=function(id)
        reads[id] = (reads[id] or 0) + 1
        if fails then error("controlled unavailable conflict record") end
        return value
    end}
local function capture()
    __ms = __ms + 1000
    local result = O.capture(__ms, __hours)
    check('capture-available', result.status == 'available' and result.capturedAtUnixMs == __ms)
    return result, planning(result, result.selectedPersonId)
end
O.enable(); O.select('a')
local _, s = capture()
check('absent-old-save', find(s, 'Conflict appraisal') == 'No conflict appraisal recorded'
    and __records.a.proceduralPlanning == nil)
value = {schema=1, actorId='a', purposeId='a:conflict:1', status='maintained', atHours=2.1,
    threat={kind='zombie', key='private-track-4', distance=7.5, count=1, source='told-by-companion', at=40},
    selected='withdraw:a:offer', kind='withdraw', reason='The reported approach is close; leave room to get away',
    frameId='private-40', score=991, completedCount=17,
    alternatives={
        {id='withdraw:a:offer', kind='withdraw', available=true, selected=true,
            reason='A personally known way out may provide separation', objections={'The locked doorway may block this route'},
            expectedEffects={{concept='separation-from-threat',status='possible',basis='Movement can create distance'}}},
        {id='hold',kind='hold-distance',available=true,reason='Keep the threat in view',
            objections={'Remaining near the doorway leaves little room'},
            expectedEffects={{concept='safety',status='unresolved',basis='Future approach is unknown'}}},
        {id='fight',kind='defend',available=false,reasons={'No suitable held weapon'}, objections={'Close contact risks injury'}},
        {id='continue',kind='continue',available=true,continuing=true,reason='Keep the prior purpose while watching'},
        {id='hidden',kind='fifth-response',available=true,reason='This must be omitted'}},
    lastOutcome={status='failed',reason='FAILED_LOCKED_DOOR',offerId='previous-offer',kind='withdraw',atHours=2.05,admitted=true}}
local original = value
_, s = capture()
check('appraisal-visible', find(s,'Conflict appraisal') == 'maintained at game hour 2.1')
check('private-belief-source', find(s,'Threat belief') == 'zombie / told by companion / believed distance 7.5 tiles')
check('intent-is-intent', find(s,'Intended response') == 'withdraw'
    and find(s,'Native admission') == 'No native attempt admission recorded')
check('reason-not-score', find(s,'Response reason') == value.reason)
check('alternative-status', find(s,'Alternative 1') == 'withdraw / selected'
    and find(s,'Alternative 3') == 'defend / unavailable'
    and find(s,'Alternative 4') == 'continue / continuing')
check('alternative-objection', find(s,'Objection 1') == 'The locked doorway may block this route'
    and find(s,'Reason 3') == 'No suitable held weapon')
check('modal-effects', find(s,'Expected effect 1') == 'separation from threat (possible): Movement can create distance'
    and find(s,'Expected effect 2') == 'safety (unresolved): Future approach is unknown')
check('bounded-alternatives', find(s,'Alternative 4') ~= nil and find(s,'Alternative 5') == nil)
check('native-failure', find(s,'Last native attempt') == 'withdraw / failed at game hour 2.05'
    and find(s,'Attempt detail') == 'FAILED_LOCKED_DOOR')
check('projection-read-only', value == original and value.lastOutcome.status == 'failed'
    and value.threat.source == 'told-by-companion' and #value.alternatives == 5
    and __records.a.proceduralPlanning == nil)
for _, item in ipairs(s.rows) do
    check('no-numeric-reason-leak', not contains(item.value,'991') and not contains(item.value,'completedCount')
        and not contains(item.value,'private-track-4'))
end
value.admission={owner='Locomotion',id='exact-native-attempt',offerId='withdraw:a:offer',atHours=2.12}
value.lastOutcome={kind='withdraw',status='completed',reason='arrived',offerId='withdraw:a:offer',atHours=2.2,admitted=true}
_, s = capture()
check('admission-owner', find(s,'Native admission') == 'Locomotion admitted at game hour 2.12')
check('completion-is-attempt', find(s,'Last native attempt') == 'withdraw / completed at game hour 2.2'
    and find(s,'Threat after attempt') == 'Requires fresh perception; the attempt result does not establish that the threat is gone')
check('original-clock-retained', find(s,'Conflict appraisal') == 'maintained at game hour 2.1')
value.lastOutcome=nil; value.admission=nil
_, s = capture()
check('no-result-is-unknown', find(s,'Last native attempt') == 'No native attempt result recorded'
    and find(s,'Attempt detail') == nil and find(s,'Threat after attempt') == nil)
base=nil
_, s = capture()
check('independent-conflict-state', s.status == 'available' and find(s,'Intended response') == 'withdraw')
base={purposes={},spatialFacts=0,practiceDomains=0}
for i=1,16 do base.purposes[i]={objective='purpose '..i,status='maintained',blockers={'blocked'},nextStep='inspect'} end
_, s=capture()
check('bounded-visible-priority', #s.rows==48 and find(s,'Conflict appraisal') ~= nil
    and find(s,'Alternative 4') ~= nil)
base={purposes={},spatialFacts=0,practiceDomains=0}
value.actorId='b'
_, s=capture()
check('reject-foreign-person', find(s,'Conflict appraisal') == 'Recorded conflict appraisal unavailable'
    and find(s,'Intended response') == nil and find(s,'Response reason') == nil)
value.actorId='a';value.schema=2
_, s=capture()
check('unknown-schema-unavailable',find(s,'Conflict appraisal')=='Recorded conflict appraisal unavailable')
value.schema=1;fails=true
_, s=capture()
check('getter-failure-local',find(s,'Conflict appraisal')=='Recorded conflict appraisal unavailable'
    and find(s,'Intended response')==nil and find(s,'Remembered spatial facts')=='0')
fails=false;value=false
_, s=capture()
check('malformed-view-unavailable',find(s,'Conflict appraisal')=='Recorded conflict appraisal unavailable')
value={schema=1,actorId='a',status={},atHours=0/0,threat={kind=false,source={},distance=-1},
    kind={},reason=991,admission='invalid',lastOutcome=false,alternatives={
        {kind='hold',available='yes',reason=991,reasons=false,objections='invalid',
            expectedEffects={{concept='safety',status='confirmed',basis=false}}},false}}
_,s=capture()
check('malformed-fields-bounded',find(s,'Conflict appraisal')=='Recorded / time unavailable'
    and find(s,'Threat belief')=='Threat kind unknown / acquisition source unavailable'
    and find(s,'Response reason')=='No rationale recorded'
    and find(s,'Alternative 1')=='hold / availability unknown')
check('unknown-effect-remains-uncertain',find(s,'Expected effect 1')=='safety (unresolved)')
value.reason=string.rep('r',1200)
_,s=capture()
check('bounded-prose',#find(s,'Response reason')==384 and find(s,'Response reason'):sub(-3)=='...')
local previousGetter=SAO.ProceduralPlanning.conflictSnapshot
SAO.ProceduralPlanning.conflictSnapshot=nil
_,s=capture()
check('missing-owner-compatible',find(s,'Intended response')==nil and find(s,'Remembered spatial facts')=='0')
SAO.ProceduralPlanning.conflictSnapshot=previousGetter
value={schema=1,actorId='a',status='maintained',kind='withdraw',reason='Only a knows this reason',alternatives={}}
SAO.Body.active.b=__body
local beforeB=reads.b or 0
local snap
snap,s=capture()
check('selected-only-read',reads.b==beforeB or (reads.b==nil and beforeB==0))
check('unselected-not-reused',planning(snap,'b').status=='unavailable'
    and find(planning(snap,'b'),'Response reason')==nil)
O.select('b');value={schema=1,actorId='b',status='maintained',kind='hold',reason='Only b knows this reason',alternatives={}}
snap,s=capture()
check('selection-switch-current',find(s,'Response reason')=='Only b knows this reason'
    and find(planning(snap,'a'),'Response reason')==nil and planning(snap,'a').status=='unavailable')
return 'CONFLICT_OBSERVATION_PASS '..checks..' checks'
end)()
