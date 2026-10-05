-- Production History/Conditions/Neuro; controlled identity, native start,
-- replay state, source profiles and moodle receivers. No candidate person.
local checks=0
local function check(name,value)
    if not value then error('CALENDAR_AGE:'..name) end
    checks=checks+1
end
local function close(a,b)return math.abs(a-b)<.0000001 end
local records={['fixture-person']={id='fixture-person'},['fixture-child']={id='fixture-child'}}
local state={yearsAsked=true,yearsOwed=100000,yearsRun=0,yearsTicks=0}
local startYear,startMonth,startDay,behind,nativeHours=1993,0,0,0,0
local profile,instantOverride,profileThrows=nil,nil,false
local readiness=0
SAO.Identity={get=function(id)return records[id]end}
ModData={getOrCreate=function()return state end}
GameTime={getInstance=function()return {
    getStartYear=function()return 1993 end,
    getWorldAgeHours=function()return nativeHours end
}end}
SAOJavaBridge={daysBehindAtStart=function()return behind end,
    countyInstant=function(_,hours)
        if instantOverride~=nil then return instantOverride end
        return __countyCalendar(startYear,startMonth,startDay,hours,behind)
    end}
SAO.EducationRegistry={profile=function(id)
    if profileThrows then error('controlled profile reader failure') end
    return profile
end}
MoodleType={TIRED='tired',DRUNK='drunk',PAIN='pain'}
SAO.Body={get=function(id)return {
    getMoodles=function()return {getMoodleLevel=function(_,kind)
        return kind=='tired' and readiness or 0
    end}end
}end}
local H,C=SAO.History,SAO.Conditions
local function at(year,month,day,hours,offset)
    startYear,startMonth,startDay,behind=year,month,day,offset or 0
    state.yearsTicks=hours*H.TICKS_PER_HOUR
    H.rebindWorld()
end
local function view(id,hours)return H.calendarAgeOf(id or 'fixture-person',hours)end
C.assert('fixture-person',{})
C.assert('fixture-child',{})
check('production_baseline_age',H.ageOf('fixture-person')==74)
check('production_birth_identity',H.birthYearOf('fixture-person')==1919)
local drawnBefore={}
for _,key in ipairs(C.ORDER) do drawnBefore[key]=C.has('fixture-drawn',key) end
local first=view()
check('owned_calendar_available',first.status=='available' and first.currentInstant=='1993-01-01T00:00:00')
check('unknown_birthday_bounds',first.nominalAge==74 and first.minimumAge==73 and first.maximumAge==74
    and first.precision=='birth-year' and first.birthdayKnown==false and first.baselineAge==74)
check('owned_sources_named',first.actorId=='fixture-person' and first.birthYear==1919
    and first.source=='SAO.History.countyInstant+birthYearOf')
local factor,meta=C.memoryFactor('fixture-person','autobiographical')
check('baseline_factor_available',factor==1 and meta.status=='available' and meta.ageProjection.nominalAge==74)
at(1993,0,0,365*24)
local advanced=view()
check('calendar_advance_changes_age',advanced.currentInstant=='1994-01-01T00:00:00' and advanced.nominalAge==75)
check('immutable_baseline_identity',H.ageOf('fixture-person')==74 and H.birthYearOf('fixture-person')==1919)
factor,meta=C.memoryFactor('fixture-person','autobiographical')
check('current_age_modifies_retention',close(factor,.8) and meta.status=='available'
    and meta.ageSource=='SAO.History.calendarAgeOf' and meta.ageProjection.minimumAge==74)
for _,key in ipairs(C.ORDER) do check('condition_draw_unchanged_'..key,C.has('fixture-drawn',key)==drawnBefore[key]) end
C.assert('fixture-person',{dementia=true,ptsd=true})
check('owned_dementia_composes',close(C.memoryFactor('fixture-person','autobiographical'),.4))
check('owned_threat_trait_composes',close(C.memoryFactor('fixture-person','zombies'),.6))
readiness=2
check('actual_neuro_composes_once',close(C.memoryFactor('fixture-person','autobiographical'),.2))
readiness=0;C.assert('fixture-person',{})
first.nominalAge=999;meta.ageProjection.nominalAge=999
check('views_detached',view().nominalAge==75 and select(2,C.memoryFactor('fixture-person')).ageProjection.nominalAge==75)
local past=view('fixture-person',0)
check('past_coordinate_allowed',past.currentInstant=='1993-01-01T00:00:00' and past.nominalAge==74)
check('future_coordinate_refused',view('fixture-person',H.countyHours()+1).status=='unavailable')
check('text_coordinate_refused',view('fixture-person','0').status=='unavailable')
check('nan_coordinate_refused',view('fixture-person',0/0).status=='unavailable')
check('infinite_coordinate_refused',view('fixture-person',math.huge).status=='unavailable')
check('foreign_person_refused',view('foreign-person').reason=='person-unavailable')
check('caller_record_not_identity',H.calendarAgeOf({id='fixture-person',birthYear=1990}).status=='unavailable')
records['mismatched-key']={id='another-person'}
check('foreign_identity_receiver_refused',view('mismatched-key').status=='unavailable')
profile={personId='fixture-person',birthYear=1920}
check('education_birth_conflict_refused',view().reason=='education-birth-mismatch' and H.birthYearOf('fixture-person')==1919)
profile={personId='foreign-person',birthYear=1919}
check('education_foreign_person_refused',view().reason=='education-birth-mismatch')
profileThrows=true
check('profile_read_failure_unavailable',view().status=='unavailable')
profileThrows=false;profile={personId='fixture-person',birthYear=1919}
check('matching_education_is_not_override',view().nominalAge==75)
profile=nil
for _,bad in ipairs({'1900-02-29T00:00:00','1993-02-29T00:00:00','1993-04-31T00:00:00',
    '1993-00-01T00:00:00','1993-13-01T00:00:00','1993-01-00T00:00:00',
    '1993-01-01T24:00:00','1993-01-01T00:60:00','1993-01-01T00:00:60',
    '0000-01-01T00:00:00','1993-01-01','1993-01-01T00:00:00Z'}) do
    instantOverride=bad
    check('strict_calendar_'..bad,view().reason=='calendar-unavailable')
end
instantOverride='2000-02-29T23:59:59'
check('gregorian_century_leap_allowed',view().status=='available' and view().nominalAge==81)
instantOverride='1918-12-31T23:59:59'
check('future_born_unavailable',view().reason=='not-yet-born' and view().nominalAge==nil)
instantOverride=''
factor,meta=C.memoryFactor('fixture-person')
check('missing_calendar_no_fabricated_date',view().currentInstant==nil and meta.status=='unavailable'
    and meta.ageProjection.currentInstant==nil)
check('legacy_numeric_contract_preserved',factor==1 and meta.reason=='calendar-unavailable')
instantOverride=nil
at(1994,0,5,0,11)
local replay=view()
check('behind_offset_uses_county_calendar',replay.currentInstant=='1993-12-26T00:00:00'
    and replay.nominalAge==74 and C.memoryFactor('fixture-person')==1)
at(1994,0,5,11*24,11)
check('replay_crosses_calendar_year_once',view().currentInstant=='1994-01-06T00:00:00'
    and view().nominalAge==75 and close(C.memoryFactor('fixture-person'),.8))
state.yearsAsked=false;nativeHours=0;H.rebindWorld()
check('native_after_replay_same_date',H.countyHours()==264 and view().currentInstant=='1994-01-06T00:00:00')
at(1980,0,0,0,0);state.yearsAsked=true
local child=view('fixture-child')
check('birth_year_zero_bounds',child.birthYear==1980 and child.nominalAge==0 and child.minimumAge==0 and child.maximumAge==0)
local retained=H.calendarAgeOf
H.calendarAgeOf=nil
factor,meta=C.memoryFactor('fixture-person')
check('absent_api_legacy_explicit',factor==1 and meta.status=='legacy' and meta.ageProjection==nil)
H.calendarAgeOf=function()error('controlled calendar owner failure')end
factor,meta=C.memoryFactor('fixture-person')
check('owner_failure_numeric_unavailable',factor==1 and meta.status=='unavailable')
H.calendarAgeOf=retained
at(1993,0,0,0)
local saved=__nativeRoundtrip(records)
records=saved;state=__nativeRoundtrip(state);H.rebindWorld()
check('native_state_reload_projection',view().nominalAge==74 and saved['fixture-person'].birthYear==nil)
__calendarFixture={check=check,records=records,result=function()return 'PASS calendar age: '..checks..' assertions' end}
__result=__calendarFixture.result()
