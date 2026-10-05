local checks=0
local function check(name,ok) if not ok then error("OUTCOME:"..name) end;checks=checks+1 end
local C,S=SAO.Cognition,SAO.Study
C.configure(1,12,3)
local body,book=fixture('a')
check('native_reading_admitted',S.begin('a',body,book))
local action=ISTimedActionQueue.queues[body].action
check('admission_does_not_teach_reading',__records.a.studyOutcomes==nil and __records.a.cognition==nil)
native(action,.4);action:update();S.interrupt('a',body,'observed danger')
check('partial_interruption_keeps_pages_without_success',body.pages==40 and __records.a.studyOutcomes==nil and __records.a.cognition==nil)
check('native_reading_resumes',S.begin('a',body,book))
action=ISTimedActionQueue.queues[body].action;native(action,1);action:update()
check('native_reading_completes',action:complete()==true)
local receipt=S.outcome('a',2)
check('native_pages_publish_exact_receipt',receipt and receipt.pagesBefore==40 and receipt.pagesAfter==100
    and receipt.nativeOwner=='ISReadABook.complete' and receipt.itemId==7 and receipt.workId=='study/2')
local cog=__records.a.cognition
check('native_callback_revises_private_expectation',cog and #cog.experiences==1
    and cog.experiences[1].id=='study/a/2' and cog.experiences[1].sourceId=='manual:Cooking')
local prediction=SAO.CognitiveModels.planPrediction('associative',
    {id='read-next',evidence=1,continuity=0,novelty=0,informationGain=0,blockers=0,
      consequences={{kind='study',category='learning',sourceId='manual:Cooking',itemType='Base.BookCooking2',value=.6}}},
    cog.models.associative,{actorId='a',atHours=10,pressure=0})
check('performed_reading_informs_later_title',prediction and prediction.predictions[1].basis=='related-experience'
    and prediction.predictions[1].evidenceIds[1]=='study/a/2')
check('pages_do_not_claim_assessed_skill',body.level==0 and SAO.ProceduralPlanning.techniqueProfile('a').practice.Cooking.completed==0)
action:complete();C.studyOutcome('a',receipt)
check('duplicate_native_completion_is_exact_once',#cog.experiences==1 and #__records.a.studyOutcomes==1)
receipt.pagesAfter=101
check('receipt_getter_is_detached',S.outcome('a',2).pagesAfter==100 and not C.studyOutcome('a',receipt))
__records.a=__nativeRoundtrip(__records.a)
check('native_record_reload_keeps_pages_and_evidence',S.outcome('a',2).pagesAfter==100
    and __records.a.cognition.nativeExperienceCursors.study==2
    and __records.a.cognition.models.associative.actorId=='a')
check('other_person_has_no_reading_knowledge',__records.b.cognition==nil and S.outcome('b',2)==nil)
__result='PASS study outcomes '..checks
