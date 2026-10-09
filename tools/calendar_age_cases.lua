-- Production History/Conditions/Neuro; controlled identity, native start,
-- replay state, source profiles and moodle receivers. No candidate person.
local checks=0
local function check(name,value)
    if not value then error('CALENDAR_AGE:'..name) end
    checks=checks+1
end
local function close(a,b)return math.abs(a-b)<.0000001 end
local records={['fixture-person']={id='fixture-person'},['fixture-child']={id='fixture-child'},
    ['sao-91001']={id='sao-91001'},['sao-91002']={id='sao-91002'},
    ['sao-91003']={id='sao-91003'},
    ['sao-91004']={id='sao-91004'},
    ['sao-91005']={id='sao-91005'}}
local state={yearsAsked=true,yearsOwed=100000,yearsRun=0,yearsTicks=0}
local startYear,startMonth,startDay,behind,nativeHours,nativeCivil=1993,0,0,0,0,9
local ageStartYear=1993
local profile,instantOverride,profileThrows=nil,nil,false
local readiness=0
SAO.Identity={get=function(id)return records[id]end}
ModData={getOrCreate=function()return state end}
GameTime={getInstance=function()return {
    getStartYear=function()return ageStartYear end,
    getWorldAgeHours=function()return nativeHours end,
    getTimeOfDay=function()return nativeCivil end,
    getMonth=function()return startMonth end
}end}
SAOJavaBridge={daysBehindAtStart=function()return behind end,
    countyInstant=function(_,hours)
        if instantOverride~=nil then return instantOverride end
        return __countyCalendar(startYear,startMonth,startDay,hours,behind)
    end,
    countyMonth=function(_,hours)
        return __countyMonth(startYear,startMonth,startDay,hours,behind)
    end}
SAO.EducationRegistry={profile=function(id)
    if profileThrows then error('controlled profile reader failure') end
    return profile
end}
SAO.Disposition={traits=function()return {
    nerve=.5,aggression=.5,compassion=.5,discipline=.5,
    initiative=.5,selfPreservation=.5
}end}
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
    and first.precision=='birth-year' and first.birthdayKnown==false and first.baselineAge==74
    and first.simulationAgePolicy=='generated-transition-day')
check('owned_sources_named',first.actorId=='fixture-person' and first.birthYear==1919
    and first.source=='SAO.History.countyInstant+birthYearOf')
local factor,meta=C.memoryFactor('fixture-person','autobiographical')
check('baseline_factor_available',factor==1 and meta.status=='available' and meta.ageProjection.nominalAge==74)
at(1993,0,0,365*24)
local advanced=view()
check('calendar_advance_changes_age',advanced.currentInstant=='1994-01-01T00:00:00' and advanced.nominalAge==75)
check('january_first_waits_for_policy_day',H.ageOf('fixture-person')==74
    and H.birthYearOf('fixture-person')==1919)
local transition=(SAO.Hash.of('fixture-person','age-transition')%365)+1
at(1993,0,0,(365+transition-2)*24)
check('generated_attained_age_before_policy_day',H.ageOf('fixture-person')==74
    and view().nominalAge==75 and view().baselineAge==74)
at(1993,0,0,(365+transition-1)*24)
check('generated_attained_age_transition',H.ageOf('fixture-person')==75
    and H.birthYearOf('fixture-person')==1919 and view().baselineAge==74)
at(1993,0,0,365*24)
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
check('native_after_replay_same_date',H.countyHours()==264
    and view().currentInstant=='1994-01-06T09:00:00'
    and H.countyDate(264)=='January 6, 1994')
nativeHours=2;nativeCivil=11
check('native_phase_follows_live_time',H.countyHours()==266
    and H.countyInstant(266)=='1994-01-06T11:00:00')
state.yearsAsked=true;state.yearsOwed=1;state.yearsRun=0
at(1993,1,0,0,1)
check('mature_history_hour_zero',H.countyInstant(0)=='1993-01-31T00:00:00'
    and H.countyDate(0)=='January 31, 1993' and H.countyMonth()==0)
state.yearsTicks=23*H.TICKS_PER_HOUR
check('historical_final_night',H.countyInstant(23)=='1993-01-31T23:00:00'
    and H.countyMonth()==0)
state.yearsTicks=24*H.TICKS_PER_HOUR
check('join_historical_owner',H.countyInstant(24)=='1993-02-01T00:00:00')
state.yearsRun=1;nativeHours=0;nativeCivil=9
check('join_native_owner',H.countyHours()==24
    and H.countyInstant(24)=='1993-02-01T09:00:00'
    and H.countyMonth()==1)
state.yearsAsked=false;state.yearsOwed=100000;state.yearsRun=0
at(1993,0,30,0,0)
nativeHours=14;nativeCivil=23
check('live_month_before_midnight',H.countyInstant(14)=='1993-01-31T23:00:00'
    and H.countyMonth()==0)
nativeHours=15;nativeCivil=0
check('live_month_crosses_midnight',H.countyInstant(15)=='1993-02-01T00:00:00'
    and H.countyMonth()==1)
check('live_month_midnight_date',H.countyDate(15)=='February 1, 1993')
nativeHours=18;nativeCivil=3
check('live_origin_at_03_current',H.civilTimeAtCountyHours(0)==9
    and H.countyInstant(0)=='1993-01-31T09:00:00'
    and H.countyDate(0)=='January 31, 1993')
nativeCivil=nil
check('missing_native_civil_no_date',H.countyInstant(18)==nil
    and H.countyDate(18)==nil)
nativeCivil=0
check('negative_record_hour_stays_historical',H.countyInstant(-1)=='1993-01-30T23:00:00')
state.yearsAsked=true;state.yearsOwed=1095;state.yearsRun=0
nativeHours=0;nativeCivil=9
ageStartYear=1996
at(1996,0,0,0,1095)
local mature=records['sao-91001']
check('mature_replay_age_matches_birth_year',H.countyInstant(0)=='1993-01-01T00:00:00'
    and H.birthYearOf('sao-91001')==1978 and H.ageOf('sao-91001')==15
    and view('sao-91001').nominalAge==15 and view('sao-91001').baselineAge==18)
check('historical_child_work_and_physiology',H.stageOf(H.ageOf('sao-91001'))=='child'
    and H.heightScaleOf('sao-91001')<1
    and select(1,H.perkFloorsOf(H.ageOf('sao-91001')))==3)
mature.occupation='police';mature.workX,mature.workY=10,20
H.generate('sao-91001',mature,0.1)
check('historical_child_cannot_keep_adult_job',mature.occupation=='student'
    and mature.ageBoundOccupation=='school' and mature.epistemicMonths~=nil
    and mature.workX==nil and mature.workY==nil)
local knox={id='ks:kid-42',heldBy='KnoxSurvivors',occupation='police',
    workX=71,workY=72}
records[knox.id]=knox
local knoxChanged,knoxReason=H.advanceLifeStage(knox)
check('knox_import_preserves_school_and_work',knoxChanged==false
    and knoxReason=='source-owned' and H.ageOf(knox.id)==12
    and knox.occupation=='police' and knox.workX==71 and knox.workY==72
    and knox.ageBoundOccupation==nil)
H.generate(knox.id,knox,0.1)
check('knox_import_history_still_settles',knox.epistemicMonths~=nil
    and knox.monthsAlive==0.1 and knox.occupation=='police'
    and knox.workX==71 and knox.workY==72)
local ksPresent,ksReason=H.generatedPresentAtCountyTime(knox.id)
check('knox_not_generated_candidate',ksPresent==nil and ksReason=='not-generated')
for _,alias in ipairs({'sao-0','sao-01','sao-1x'}) do
    local value,why=H.generatedPresentAtCountyTime(alias)
    check('noncanonical_generated_alias_'..alias,value==nil and why=='not-generated')
end
local worker=records['sao-91002']
H.generate('sao-91002',worker,0.1)
check('historical_child_has_no_future_trade_draw',worker.occupation=='student'
    and worker.ageBoundOccupation=='school')
state.yearsTicks=365*24*H.TICKS_PER_HOUR
check('mature_replay_1994_age',H.countyInstant(H.countyHours())=='1994-01-01T00:00:00'
    and H.ageOf('sao-91001')==16)
check('school_status_stays_through_childhood',H.advanceLifeStage(mature)==false
    and mature.occupation=='student' and mature.ageBoundOccupation=='school')
state.yearsTicks=730*24*H.TICKS_PER_HOUR
check('mature_replay_1995_age',H.ageOf('sao-91001')==17)
state.yearsTicks=1095*24*H.TICKS_PER_HOUR
check('mature_historical_join_age',H.ageOf('sao-91001')==18
    and H.countyInstant(H.countyHours())=='1996-01-01T00:00:00')
knoxChanged,knoxReason=H.advanceLifeStage(knox)
check('knox_daily_age_pass_preserves_source_work',knoxChanged==false
    and knoxReason=='source-owned' and knox.occupation=='police'
    and knox.workX==71 and knox.workY==72 and knox.epistemicMonths~=nil)
mature.workX,mature.workY=11,12
local changed,stageWhy=H.advanceLifeStage(mature)
local workCalls=0
SAO.Standing={groupOf=function()return nil end}
SAO.Perception={beliefs={}}
SAO.Places={around=function()return {} end}
SAO.PopulationAdmissions={workplaceFor=function()
    workCalls=workCalls+1;return {x=40,y=40}
end}
local today=math.floor(H.countyHours()/24)
mature.homeX,mature.homeY,mature.x,mature.y=0,0,0,0
mature.lastWaterDay,mature.lastFoodDay=today,today
local dormantGoal=SAO.DormantPopulation.probeChooseDayGoal(
    mature.id,mature,24,0,true)
check('former_student_skips_dormant_work_goal',dormantGoal==nil and workCalls==0)
check('mature_school_exit_has_no_false_workplace',changed==true
    and stageWhy=='school-ended' and mature.occupation==nil
    and mature.ageBoundOccupation==nil and mature.workX==nil
    and mature.workY==nil and SAO.Census.rowOf(mature.occupation)==nil
    and SAO.Census.describe(mature)==nil)
local missingWork=records['sao-91003']
missingWork.ageBoundOccupation='school';missingWork.workX,missingWork.workY=15,16
changed,stageWhy=H.advanceLifeStage(missingWork)
check('nil_school_role_clears_stale_worksite',changed==true
    and stageWhy=='school-ended' and missingWork.occupation==nil
    and missingWork.ageBoundOccupation==nil and missingWork.workX==nil
    and missingWork.workY==nil)
worker.occupation='farmer';worker.workX,worker.workY=25,35
changed,stageWhy=H.advanceLifeStage(worker)
check('earned_adult_work_preserved',changed==true and stageWhy=='age-bound-status-ended'
    and worker.occupation=='farmer' and worker.workX==25 and worker.workY==35
    and worker.ageBoundOccupation==nil)
worker.homeX,worker.homeY,worker.x,worker.y=0,0,0,0
worker.lastWaterDay,worker.lastFoodDay=today,today
dormantGoal=SAO.DormantPopulation.probeChooseDayGoal(
    worker.id,worker,24,0,true)
check('earned_trade_keeps_dormant_work_goal',dormantGoal~=nil
    and dormantGoal.x==40 and dormantGoal.y==40 and workCalls==1)
local adultStudent={id='sao-91006',occupation='student'}
records[adultStudent.id]=adultStudent
changed=H.advanceLifeStage(adultStudent)
check('independent_adult_student_preserved',changed==false
    and adultStudent.occupation=='student' and adultStudent.ageBoundOccupation==nil)
local sourceAdult={id='sao-91007',occupation='student',workX=4,
    chronology={schema='source-owned'}}
changed,stageWhy=H.advanceLifeStage(sourceAdult)
check('imported_adult_identity_unchanged',changed==false and stageWhy=='source-owned'
    and sourceAdult.occupation=='student' and sourceAdult.workX==4)
local deadChild={id='sao-91004',dead=true,occupation='student'}
changed,stageWhy=H.advanceLifeStage(deadChild)
check('dead_person_stage_not_rewritten',changed==false and stageWhy=='dead'
    and deadChild.occupation=='student')
state.yearsRun=1095
check('mature_live_join_age',H.ageOf('sao-91001')==18
    and H.countyInstant(H.countyHours())=='1996-01-01T09:00:00')
local matureTransition=(SAO.Hash.of('sao-91001','age-transition')%365)+1
nativeHours=(366+matureTransition-2)*24
check('mature_next_policy_day_pending',H.ageOf('sao-91001')==18)
nativeHours=(366+matureTransition-1)*24
check('mature_next_policy_day_accrues',H.ageOf('sao-91001')==19)
state.yearsAsked=true;state.yearsOwed=4383;state.yearsRun=0
nativeHours=0
ageStartYear=2005
at(2005,0,0,0,4383)
local young=records['sao-91004']
local present,why=H.generatedPresentAtCountyTime('sao-91004')
check('generated_not_yet_born_refused',H.countyInstant(0)=='1993-01-01T00:00:00'
    and H.birthYearOf('sao-91004')==1999 and H.ageOf('sao-91004')==nil
    and view('sao-91004').reason=='not-yet-born'
    and present==false and why=='not-yet-born')
records['sao-91004']=nil
present,why=H.generatedPresentAtCountyTime('sao-91004')
check('prospective_id_checked_before_identity_write',present==false and why=='not-yet-born')
records['sao-91004']=young
young.occupation='police'
local generated,whyGenerate=H.generate('sao-91004',young,0.1)
check('prenatal_history_not_settled',generated==false and whyGenerate=='not-yet-born'
    and young.occupation=='police' and young.epistemicMonths==nil)
state.yearsTicks=2191*24*H.TICKS_PER_HOUR
present=H.generatedPresentAtCountyTime('sao-91004')
check('young_birth_year_admitted',H.countyInstant(H.countyHours())=='1999-01-01T00:00:00'
    and H.ageOf('sao-91004')==0 and present==true)
check('newborn_world_clock_exceeds_life',H.clockMonths()>70)
H.generate('sao-91004',young)
check('newborn_has_no_school_or_six_year_history',young.occupation==nil
    and young.ageBoundOccupation=='early-childhood'
    and young.monthsAlive==0 and young.contactMonths==0
    and young.epistemicMonths==0 and SAO.Census.describe(young)==nil)
local override=records['sao-91005']
H.generate('sao-91005',override,0.1)
check('explicit_history_month_override_preserved',override.monthsAlive==0.1
    and override.contactMonths<=override.monthsAlive)
state.yearsTicks=4383*24*H.TICKS_PER_HOUR;state.yearsRun=4383
check('young_live_join_baseline',H.ageOf('sao-91004')==6
    and H.countyInstant(H.countyHours())=='2005-01-01T09:00:00')
changed,stageWhy=H.advanceLifeStage(young)
check('early_childhood_enters_school',changed==true and stageWhy=='school'
    and young.occupation=='student' and young.ageBoundOccupation=='school')
instantOverride=''
present,why=H.generatedPresentAtCountyTime('sao-91004')
check('generated_calendar_missing_unavailable',present==nil and why=='calendar-unavailable')
changed,stageWhy=H.advanceLifeStage(young)
check('life_stage_holds_without_calendar',changed==nil and stageWhy=='calendar-unavailable'
    and young.occupation=='student' and young.ageBoundOccupation=='school')
instantOverride=nil
local originalHash=SAO.Hash.of
SAO.Hash.of=function()error('controlled age source failure')end
present,why=H.generatedPresentAtCountyTime('sao-91004')
check('generated_age_source_failure_is_distinct',present==nil and why=='age-source-unavailable')
SAO.Hash.of=originalHash
present,why=H.generatedPresentAtCountyTime('')
check('generated_invalid_id_is_unavailable',present==nil and why=='invalid-id')
local originalGet=SAO.Identity.get
SAO.Identity.get=function()error('controlled identity source failure')end
present,why=H.generatedPresentAtCountyTime('sao-91004')
check('generated_identity_reader_is_nonthrowing',present==nil and why=='identity-unavailable')
SAO.Identity.get=originalGet
young.weekOne={source='BanditsWeekOne'}
present,why=H.generatedPresentAtCountyTime('sao-91004')
check('source_person_not_generated_candidate',present==nil and why=='not-generated')
young.weekOne=nil
state.yearsOwed=100000;state.yearsRun=0;nativeHours=0;nativeCivil=9
ageStartYear=1993
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
