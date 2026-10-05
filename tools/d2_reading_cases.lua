local results = {}
print = __nativePrint
local function check(name, value)
    results[#results + 1] = name .. '=' .. tostring(value == true)
    print(results[#results])
    if value ~= true then error('D2_READING:' .. name) end
end
local S, P = SAO.Study, SAO.ProceduralPlanning
ItemTag = __nativeItemTag
local oldInstanceof = instanceof
instanceof = function(item, kind)
    if type(item) == 'userdata' then return kind == 'Literature' and __nativeIsLiterature(item) end
    return oldInstanceof(item, kind)
end
local carried = SAOJavaBridge.privateCarriedItems
SAOJavaBridge.privateCarriedItems = function(self, body)
    if not body.items then return carried(self, body) end
    return { size = function() return #body.items end, get = function(_, i) return body.items[i + 1] end }
end
local serial = 100
local function person()
    serial = serial + 1
    local id = 'reader-' .. serial
    __records[id] = { id = id }
    local body, book, inv = fixture(id)
    body.items = { book }
    function inv:contains(item)
        for _, value in ipairs(body.items) do if value == item then return true end end
        return false
    end
    return id, body, book, inv
end
local function novel(book, id, fullType)
    book.id, book.fullType, book.domain, book.total = id, fullType or 'Base.Novel', 'None', -1
    function book:hasTag(tag) return tag == ItemTag.UNINTERESTING and self.uninteresting == true end
    return book
end
local function finish(id, body, item)
    assert(S.beginLeisure(id, body, item), 'test reading admission')
    local action = ISTimedActionQueue.queues[body].action
    native(action, 1); action:update()
    assert(action:complete(), 'test native completion')
    action:perform()
    return action, __records[id].proceduralPlanning.purposes[action.purposeId]
end

local id, body = person()
local card, card2, book = __nativeItems.IDcard_Male, __nativeItems.IDcard_Female, __nativeItems.Book
check('installed_ids_are_pageless_uninteresting', card:getNumberOfPages() == -1
    and card:hasTag(ItemTag.UNINTERESTING) and card2:hasTag(ItemTag.UNINTERESTING))
check('installed_novel_is_pageless_meaningful', book:getNumberOfPages() == -1 and not book:hasTag(ItemTag.UNINTERESTING))
body.items = { card, card2, book }
check('offer_skips_actual_native_id_cards', S.offerLeisure(id, body) == book)
check('direct_id_admission_refused', not S.beginLeisure(id, body, card) and __records[id].studyWork == nil)
check('eligibility_query_no_planning_write', S.readingEligibility(id, body, book, 'leisure')
    and __records[id].proceduralPlanning == nil)
__nativeBody:getStats():set(__nativeCharacterStat.BOREDOM, 80)
__nativeBody:getStats():set(__nativeCharacterStat.UNHAPPINESS, 80)
body.ReadLiterature = function(_, item) __nativeBody:ReadLiterature(item) end
local nativeAction, nativePurpose = finish(id, body, book)
check('pageless_native_literature_effect_and_receipt', __nativeBody:getStats():get(__nativeCharacterStat.BOREDOM) < 80
    and nativePurpose.steps[2].status == 'completed' and __records[id].studyWork.status == 'completed')
check('completion_preserves_unfinished_share', nativePurpose.steps[3].status ~= 'completed'
    and nativePurpose.status ~= 'completed' and nativePurpose.admission == nil)
check('completed_exact_item_not_reoffered', S.offerLeisure(id, body) == nil)
body.items[#body.items + 1] = __nativeItems.ComicBook
check('completion_selects_different_native_item', S.offerLeisure(id, body) == __nativeItems.ComicBook)
check('completed_exact_item_not_readmitted', not S.beginLeisure(id, body, book))

local a, b, first, inv = person(); novel(first, 1)
local _, _, second = person(); novel(second, 2)
b.items = { first, second }
local action, purpose = finish(a, b, first)
local priorId, receipt = purpose.id, purpose.resultReceipts[1]
check('same_type_other_item_remains_eligible', S.offerLeisure(a, b) == second)
check('new_item_uses_distinct_purpose', S.beginLeisure(a, b, second)
    and __records[a].studyWork.purposeId ~= priorId)
check('old_share_and_receipt_survive_new_item', purpose.steps[2].status == 'completed'
    and purpose.steps[3].status ~= 'completed' and purpose.resultReceipts[1] == receipt)
S.interrupt(a, b, 'danger')
local interrupted = __records[a].studyWork.purposeId
check('interrupted_item_can_resume', S.offerLeisure(a, b) == second and S.beginLeisure(a, b, second)
    and __records[a].studyWork.purposeId == interrupted)
S.interrupt(a, b, 'reload')
__records[a] = __nativeRoundtrip(__records[a]); __agents[a].rec = __records[a]
check('native_roundtrip_retains_completed_choice', not P.leisureChoice(a, 'read Base.Novel', '1')
    and P.leisureChoice(a, 'read Base.Novel', '2'))
check('native_roundtrip_preserves_share', __records[a].proceduralPlanning.purposes[priorId].steps[3].status ~= 'completed'
    and __records[a].proceduralPlanning.purposes[priorId].resultReceipts[1] == receipt)
local fresh = __freshVMChoice(__records[a], 'read Base.Novel', '1', __hours)
check('fresh_vm_preserves_completed_exact_item', fresh.eligible == false
    and fresh.person.proceduralPlanning.purposes[priorId].steps[3].status ~= 'completed'
    and fresh.person.proceduralPlanning.purposes[priorId].resultReceipts[1] == receipt)
check('fresh_vm_preserves_interrupted_alternative', __freshVMChoice(__records[a], 'read Base.Novel', '2', __hours).eligible)
check('reload_interruption_resumes_same_purpose', S.beginLeisure(a, b, second)
    and __records[a].studyWork.purposeId == interrupted)
S.interrupt(a, b, 'other work')

local interruptedPurpose = __records[a].proceduralPlanning.purposes[interrupted]
check('interruption_releases_exact_admission', interruptedPurpose.admission == nil)
ISTimedActionQueue.accept = false
check('interrupted_retry_refusal_has_no_stale_admission', not S.beginLeisure(a, b, second)
    and interruptedPurpose.admission == nil and interruptedPurpose.steps[2].status ~= 'completed')
ISTimedActionQueue.accept = true

local x, y, rejected = person(); novel(rejected, 1)
local _, _, alternative = person(); novel(alternative, 2)
y.items = { rejected, alternative }
ISTimedActionQueue.accept = false
check('queue_refusal_remains_unadmitted', not S.beginLeisure(x, y, rejected)
    and __records[x].studyWork.status == 'interrupted'
    and not __records[x].proceduralPlanning.purposes[__records[x].studyWork.purposeId].admission)
ISTimedActionQueue.accept = true
check('refusal_selects_next_exact_item', S.offerLeisure(x, y) == alternative)
local refusePurpose = __records[x].studyWork.purposeId
check('foreign_refusal_work_rejected', not P.leisureRefusal(x, refusePurpose, 'study/999'))
__records[x] = __nativeRoundtrip(__records[x]); __agents[x].rec = __records[x]
check('refusal_survives_native_reload', S.offerLeisure(x, y) == alternative)
check('fresh_vm_preserves_refusal', __freshVMChoice(__records[x], 'read Base.Novel', '1', __hours).eligible == false)
__hours = __hours + 1 / 60 + 0.001
check('bounded_refusal_retry_allows_item', S.offerLeisure(x, y) == rejected)
local refusal = __records[x].proceduralPlanning.purposes[refusePurpose].leisure.refusal
refusal.at, refusal.retryAt = __hours + 1, __hours + 2
check('future_refusal_cannot_block_choice', S.offerLeisure(x, y) == rejected)

local k, c, mutable = person(); novel(mutable, 1)
check('meaningful_item_admitted', S.beginLeisure(k, c, mutable))
local owner = ISTimedActionQueue.queues[c].action
mutable.uninteresting = true
check('action_rechecks_meaningful_material', not owner:isValid())
check('tag_change_cannot_complete_reading', owner:complete() == false and c.literatureEffects == nil)
ISTimedActionQueue.clear(c)
mutable.uninteresting = false
check('interruption_keeps_meaningful_retry', S.beginLeisure(k, c, mutable))
owner = ISTimedActionQueue.queues[c].action
c.items = {}
check('exact_item_loss_invalidates_action', not owner:isValid())
c.items = { mutable }; __records[k].bodyOwnerToken = 'successor'
check('stale_body_generation_refused', not owner:isValid()
    and not S.readingEligibility(k, c, mutable, 'leisure'))
__records[k].bodyOwnerToken = 'owner-1'
check('continuing_flag_not_general_bypass', not S.readingEligibility(id, body, book, 'leisure', true))

local legacyId, lb, legacyBook = person(); novel(legacyBook, 99)
local legacy, legacyStep = P.planLeisure(legacyId, {activity='read Base.Novel',affordance='Base.Novel',
    atLocation=true,locationKey='old-place',owner='SAONeeds'})
legacy.leisure = nil
P.noteAdmission(legacyId, legacy.id, 'SAONeeds', 'old-reading')
P.recordResult(legacyId, legacy.id, {owner='SAONeeds',token='leisure:performed',status='completed',correlationId='old-reading'})
__records[legacyId].studyWork = {id='old-reading',purposeId=legacy.id,itemId='99',kind='leisure',status='completed'}
check('legacy_completed_item_keeps_share_without_repeat', not S.readingEligibility(legacyId, lb, legacyBook, 'leisure')
    and legacy.steps[3].status ~= 'completed')

local capId, capBody, capBook = person(); novel(capBook, 500)
local _, protected = finish(capId, capBody, capBook)
for i = 1, 20 do P.maintain(capId, {key='other:'..i,objective='other work'}) end
check('capacity_does_not_discard_pending_sharing', __records[capId].proceduralPlanning.suspendedLeisure
    and __records[capId].proceduralPlanning.suspendedLeisure.purposes[protected.id] == protected
    and protected.status=='suspended' and protected.steps[3].status~='completed')
local admitted = P.admitResourceOutcome(capId, { id='food',revision=1,category='food',target=1,
    unit='usable-food-item',sourceDefinition=string.rep('a',64),issuer='fixture' })
check('resource_admission_preserves_pending_sharing', admitted ~= nil
    and __records[capId].proceduralPlanning.suspendedLeisure.purposes[protected.id] == protected)
check('suspended_reading_still_blocks_completed_exact_item',not P.leisureChoice(capId,'read Base.Novel','500'))
local suspendedVM=__freshVMChoice(__records[capId],'read Base.Novel','500',__hours)
check('suspended_reading_survives_fresh_vm',suspendedVM.eligible==false
    and suspendedVM.person.proceduralPlanning.suspendedLeisure.purposes[protected.id].steps[3].status~='completed')
local otherId, otherBody, otherBook = person(); novel(otherBook, 500)
check('completion_is_person_private', S.readingEligibility(otherId, otherBody, otherBook, 'leisure'))

-- Installed writable Literature and native LuaTimedActionNew callbacks. The
-- body/custody fixture and elapsed time remain controlled; text is real native
-- customPages and no rendered attention/comprehension is inferred.
local noteSerial = 3000
local function notePerson(text)
    local who, reader = person()
    noteSerial = noteSerial + 1
    local item = __newNote(noteSerial)
    if text ~= nil then item:addPage(1, text) end
    reader.items = { item }
    return who, reader, item
end
local function startNote(who, reader, item)
    assert(S.beginLeisure(who, reader, item), 'note admission')
    local owner = ISTimedActionQueue.queues[reader].action
    __nativeNoteCallback(owner, 'start')
    return owner
end
local function completeNote(owner)
    __nativeNoteCallback(owner, 'progress', 1)
    __nativeNoteCallback(owner, 'perform')
    __nativeNoteCallback(owner, 'complete')
end
local nw, nb, ni = notePerson()
check('native_notebook_writable_metadata', ni:canBeWrite() and ni:isEmptyPages()
    and __nativeItems.Journal:canBeWrite())
local absent = __customPagesAbsent(ni)
check('blank_note_query_refused_without_allocation', not S.readingEligibility(nw, nb, ni, 'leisure')
    and absent and __customPagesAbsent(ni) and __records[nw].proceduralPlanning == nil)
ni:addPage(1, '   \n\t')
check('whitespace_note_refused', not S.readingEligibility(nw, nb, ni, 'leisure'))
ni:addPage(1, 'The key is beside the porch.')
ni:addPage(2, 'I worked here before the roads closed.')
ni:setNumberOfPages(2);ni:setAlreadyReadPages(2);nb.pages=2
check('written_note_ignores_fulltype_book_counters', S.readingEligibility(nw, nb, ni, 'leisure')
    and ni:getAlreadyReadPages()==2 and nb.pages==2)
check('written_note_is_not_a_skill_manual', not S.readingEligibility(nw, nb, ni, 'study'))
local oldPurpose = P.planLeisure(nw,{activity='read Base.Notebook',itemKey=tostring(ni:getID()),
    affordance='Base.Notebook',atLocation=true,locationKey='old-place',owner='SAONeeds'})
P.noteAdmission(nw,oldPurpose.id,'SAONeeds','old-notebook-pages')
P.recordResult(nw,oldPurpose.id,{owner='SAONeeds',token='leisure:performed',status='completed',correlationId='old-notebook-pages'})
__records[nw].studyWork={id='old-notebook-pages',purposeId=oldPurpose.id,itemId=tostring(ni:getID()),
    fullType='Base.Notebook',kind='leisure',status='completed',pagesBefore=0,pagesAfter=2,totalPages=2}
local oldReceipt=oldPurpose.resultReceipts[1]
check('legacy_pages_do_not_prove_note_exposure', S.readingEligibility(nw,nb,ni,'leisure') and S.noteOutcome(nw,1)==nil)
local no = startNote(nw,nb,ni)
local noteWork=__records[nw].studyWork
local np=__records[nw].proceduralPlanning.purposes[noteWork.purposeId]
check('note_uses_distinct_owner_and_purpose',no.Type=='SAONoteReadAction' and noteWork.purposeId~=oldPurpose.id
    and noteWork.contentKind=='written-note' and noteWork.pagesBefore==nil and noteWork.totalPages==nil)
check('note_occurrence_is_not_human_objective',np.leisure.activity=='read written notes'
    and np.leisure.activityKey~=np.leisure.activity and np.steps[2].target=='read written notes'
    and not string.find(np.objective,'exposure',1,true))
check('unread_note_text_not_durable_at_admission',noteWork.content==nil and noteWork.pages==nil
    and __records[nw].noteReadingOutcomes==nil and S.snapshot(nw).content==nil
    and S.snapshot(nw).contentPages==2 and S.snapshot(nw).exposureCompleted==false)
check('native_note_start_has_read_presentation',no.nativeStarted==true and nb:isReading()
    and no.action:getJobDelta()==0 and np.steps[2].status~='completed')
check('typed_note_admission_is_prepared_before_native_work',np.noteReading==true and np.admission.stage=='prepared'
    and np.admission.note.contentBinding==noteWork.id and np.admission.note.bodyToken=='owner-1'
    and np.admission.note.sequence==noteWork.sequence and np.admission.at<=noteWork.startedAt)
check('public_note_completion_refused',not P.recordResult(nw,np.id,{owner='SAONeeds',token='note:text-exposed',
    status='completed',correlationId=noteWork.id}) and np.steps[2].status~='completed')
check('unretained_note_receipt_refused',not P.consumeNoteOutcome(nw,noteWork.sequence))
__nativeNoteCallback(no,'progress',0.5)
check('note_progress_has_no_book_or_concept_reward',S.snapshot(nw).phase=='executing' and nb.pages==2
    and ni:getAlreadyReadPages()==2 and nb.literatureEffects==nil and nb.readTitle==nil
    and __records[nw].noteReadingOutcomes==nil and __records[nw].studyOutcomes==nil)
__nativeNoteCallback(no,'progress',1)
__nativeNoteCallback(no,'perform')
check('perform_handoff_is_not_text_receipt',not nb:isReading() and __records[nw].noteReadingOutcomes==nil
    and noteWork.status=='reading' and not ISTimedActionQueue.hasAction(no))
__nativeNoteCallback(no,'complete')
local nr=S.noteOutcome(nw,noteWork.sequence)
check('native_complete_retains_exact_text_exposure',nr~=nil and nr.content.pages[1]=='The key is beside the porch.'
    and nr.content.pages[2]=='I worked here before the roads closed.' and nr.itemId==tostring(ni:getID())
    and nr.workId==noteWork.id and nr.purposeId==np.id and nr.token=='note:text-exposed'
    and nr.nativeOwner=='SAONoteReadAction/ISBaseTimedAction' and noteWork.exposureCompleted==true)
check('note_completion_has_no_book_effects_or_shared_receipt',np.steps[2].status=='completed'
    and np.steps[3].status~='completed' and nb.pages==2 and ni:getAlreadyReadPages()==2
    and nb.literatureEffects==nil and nb.readTitle==nil and __records[nw].studyOutcomes==nil
    and oldPurpose.resultReceipts[1]==oldReceipt and oldPurpose.steps[3].status~='completed')
check('note_exposure_has_no_practice_credit',__records[nw].proceduralPlanning.practice['read written notes']==nil
    and np.sessions==nil and __records[nw].studyOutcomes==nil)
local receiptCount=#np.resultReceipts
check('canonical_note_replay_is_idempotent',P.consumeNoteOutcome(nw,noteWork.sequence)
    and #np.resultReceipts==receiptCount and np.admission==nil and np.lastAdmission.note.workId==noteWork.id)
local stored=__records[nw].noteReadingOutcomes[1]
stored.bodyToken='another-native-generation'
check('foreign_note_generation_cannot_advance_purpose',not P.consumeNoteOutcome(nw,noteWork.sequence))
stored.bodyToken='owner-1'
stored.contentBinding='study/foreign-content'
check('wrong_note_content_binding_cannot_advance_purpose',not P.consumeNoteOutcome(nw,noteWork.sequence))
stored.contentBinding=noteWork.id
stored.endedAt=stored.startedAt-1
check('reversed_note_clock_refused',not P.consumeNoteOutcome(nw,noteWork.sequence))
stored.endedAt=stored.atHours
stored.atHours=__hours+1
check('future_note_terminal_refused',not P.consumeNoteOutcome(nw,noteWork.sequence))
stored.atHours=stored.endedAt
local storedSequence=stored.sequence;stored.sequence=storedSequence+999
check('wrong_note_occurrence_refused',not P.consumeNoteOutcome(nw,stored.sequence))
stored.sequence=storedSequence
nr.content.pages[1]='tampered copy'
check('note_outcome_is_detached',S.noteOutcome(nw,noteWork.sequence).content.pages[1]=='The key is beside the porch.')
__nativeNoteCallback(no,'complete')
check('duplicate_complete_cannot_repeat_exposure',#__records[nw].noteReadingOutcomes==1)
check('same_written_text_is_not_reoffered',not S.readingEligibility(nw,nb,ni,'leisure'))
local different, db = person();db.items={ni}
check('text_exposure_is_person_private',S.readingEligibility(different,db,ni,'leisure'))
db.items={}
check('foreign_item_cannot_be_read',not S.readingEligibility(different,db,ni,'leisure'))
ni=__nativeItemRoundtrip(ni);nb.items={ni}
__records[nw]=__nativeRoundtrip(__records[nw]);__agents[nw].rec=__records[nw];__reset()
check('native_item_and_person_reload_preserve_exposure',ni:seePage(1)=='The key is beside the porch.'
    and not S.readingEligibility(nw,nb,ni,'leisure') and S.noteOutcome(nw,noteWork.sequence).content.pages[2]=='I worked here before the roads closed.')
check('serialized_note_receipt_replays_exactly_once',P.consumeNoteOutcome(nw,noteWork.sequence)
    and #__records[nw].proceduralPlanning.purposes[np.id].resultReceipts==receiptCount
    and __records[nw].proceduralPlanning.practice['read written notes']==nil)
ni:addPage(2,'A different sentence with newly written directions.')
check('edited_note_text_is_new_eligible_material',S.readingEligibility(nw,nb,ni,'leisure'))
local edited=startNote(nw,nb,ni)
check('edited_note_retains_previous_purpose_and_exposure',edited.purposeId~=np.id
    and __records[nw].proceduralPlanning.purposes[np.id].steps[3].status~='completed'
    and S.noteOutcome(nw,noteWork.sequence).content.pages[2]=='I worked here before the roads closed.')
__nativeNoteCallback(edited,'progress',0.3)
local interruptedId=edited.purposeId
__records[nw]=__nativeRoundtrip(__records[nw]);__agents[nw].rec=__records[nw];__reset()
ISTimedActionQueue.clear(nb)
check('reload_cannot_complete_cached_unread_note',not S.active(nw,nb)
    and __records[nw].studyWork.status=='interrupted' and #__records[nw].noteReadingOutcomes==1)
__nativeNoteCallback(edited,'complete')
check('retired_note_callback_cannot_expose_text',#__records[nw].noteReadingOutcomes==1 and nb.pages==2)
local resumed=startNote(nw,nb,ni)
check('note_retry_preserves_purpose_but_rebinds_current_text',resumed.purposeId==interruptedId
    and resumed.noteContent.pages[2]=='A different sentence with newly written directions.' and resumed.action:getJobDelta()==0)
completeNote(resumed)
check('edited_note_completes_new_exposure',#__records[nw].noteReadingOutcomes==2
    and not S.readingEligibility(nw,nb,ni,'leisure'))
local mw,mb,mi=notePerson('A known route.');local mo=startNote(mw,mb,mi)
__nativeNoteCallback(mo,'progress',0.8);mi:addPage(1,'A clear route.') -- equal byte count, different text
check('equal_length_text_mutation_invalidates_owner',not mo:isValid())
completeNote(mo)
check('changed_text_cannot_complete_exposure',__records[mw].studyWork.status=='interrupted'
    and __records[mw].noteReadingOutcomes==nil and mb.literatureEffects==nil)
local ew,eb,ei=notePerson('Read only with the actual item.');local eo=startNote(ew,eb,ei)
eb.items={};completeNote(eo)
check('lost_exact_note_cannot_complete',__records[ew].noteReadingOutcomes==nil)
local bw,bb,bi=notePerson('A body-specific reading.');local bo=startNote(bw,bb,bi)
bb.data.SAOExternalToken='replacement';completeNote(bo)
check('new_body_generation_cannot_complete_note',__records[bw].noteReadingOutcomes==nil)
local pw,pb,pi=notePerson('Native completion is necessary.');local po=startNote(pw,pb,pi)
__nativeNoteCallback(po,'progress',0.4);__nativeNoteCallback(po,'perform');__nativeNoteCallback(po,'complete')
check('partial_native_perform_cannot_expose_note',__records[pw].noteReadingOutcomes==nil)
local cw,cb,ci=notePerson('Native perform is necessary.');local co=startNote(cw,cb,ci)
__nativeNoteCallback(co,'progress',1);__nativeNoteCallback(co,'complete')
check('complete_without_native_perform_refused',__records[cw].noteReadingOutcomes==nil)
local sw,sb,si=notePerson('Keep other work intact.');local so=startNote(sw,sb,si)
S.interrupt(sw,sb,'urgent work');local urgent={character=sb};ISTimedActionQueue.add(urgent)
__nativeNoteCallback(so,'stop');__nativeNoteCallback(so,'perform')
check('retired_note_callbacks_preserve_foreign_queue',ISTimedActionQueue.hasAction(urgent)
    and __records[sw].noteReadingOutcomes==nil)
local fw,fb,fi=notePerson('Queue refusal does not read me.')
ISTimedActionQueue.accept=false
check('note_queue_refusal_does_not_expose_text',not S.beginLeisure(fw,fb,fi) and __records[fw].noteReadingOutcomes==nil)
check('refused_note_releases_prepared_admission',__records[fw].proceduralPlanning.purposes[__records[fw].studyWork.purposeId].admission==nil)
ISTimedActionQueue.accept=true
check('note_queue_refusal_throttles_exact_retry',not S.readingEligibility(fw,fb,fi,'leisure'))
__hours=__hours+1/60+0.001
check('note_queue_refusal_expires',S.readingEligibility(fw,fb,fi,'leisure'))
local iw,ib,ii=notePerson();ii:addPage(2,'Sparse page with no page one.')
check('sparse_note_content_refused_without_repair',not S.readingEligibility(iw,ib,ii,'leisure') and ii:getCustomPages():size()==1)
local ow,ob,oi=notePerson()
for i=1,5 do oi:addPage(i,string.rep('x',16384)) end
check('oversized_note_refused_without_truncation',not S.readingEligibility(ow,ob,oi,'leisure')
    and #oi:seePage(5)==16384 and __records[ow].studyWork==nil)
local qw,qb,qi=notePerson('Text remains private before an attempt.')
check('written_note_query_has_no_durable_content_or_purpose',S.readingEligibility(qw,qb,qi,'leisure')
    and __records[qw].studyWork==nil and __records[qw].proceduralPlanning==nil and __records[qw].noteReadingOutcomes==nil)
local jw,jb=person();local ji=__nativeItems.Journal;ji:addPage(1,'An existing, personally written journal entry.');jb.items={ji}
check('native_written_journal_remains_available',S.readingEligibility(jw,jb,ji,'leisure'))
local jo=startNote(jw,jb,ji);completeNote(jo)
check('native_journal_exposure_uses_actual_text',S.noteOutcome(jw,__records[jw].studyWork.sequence).content.pages[1]
    =='An existing, personally written journal entry.' and jb.literatureEffects==nil)
local ownOutcome=__records[jw].noteReadingOutcomes[1]
local foreignWho,foreignBody=person();foreignBody.items={ji}
__records[foreignWho].noteReadingOutcomes={__nativeRoundtrip(ownOutcome)}
check('foreign_exposure_cannot_exclude_note',S.readingEligibility(foreignWho,foreignBody,ji,'leisure'))
local future=__nativeRoundtrip(ownOutcome);future.actorId=foreignWho;future.atHours=__hours+1
__records[foreignWho].noteReadingOutcomes={future}
check('future_exposure_cannot_exclude_note',S.readingEligibility(foreignWho,foreignBody,ji,'leisure'))
local fake=__nativeRoundtrip(ownOutcome);fake.actorId=foreignWho;fake.nativeOwner='generic-table'
__records[foreignWho].noteReadingOutcomes={fake}
check('untyped_exposure_cannot_exclude_note',S.readingEligibility(foreignWho,foreignBody,ji,'leisure'))
local rw,rb,ri=notePerson('Bounded private note exposure 1.')
for i=1,18 do
    ri:addPage(1,'Bounded private note exposure '..i..'.')
    completeNote(startNote(rw,rb,ri))
end
check('completed_note_content_retention_bounded',#__records[rw].noteReadingOutcomes==16
    and __records[rw].noteReadingOutcomes[1].content.pages[1]=='Bounded private note exposure 3.'
    and S.noteOutcome(rw,__records[rw].studyWork.sequence).content.pages[1]=='Bounded private note exposure 18.')
local uw,ub,ui=notePerson('A normal SAO body has no external generation token.')
ub.data.SAOExternalToken=nil;__records[uw].bodyOwnerToken=nil
ui:setNumberOfPages(0);ub.pages=23
local uo=startNote(uw,ub,ui);completeNote(uo)
local unknownGeneration=S.noteOutcome(uw,__records[uw].studyWork.sequence)
check('ordinary_body_unknown_generation_is_honest',unknownGeneration~=nil
    and unknownGeneration.bodyGenerationKnown==false and unknownGeneration.bodyToken==nil
    and __records[uw].proceduralPlanning.purposes[uo.purposeId].steps[2].status=='completed')
check('note_duration_uses_actual_content_not_book_counter',uo.maxTime==240 and ub.pages==23
    and ui:getNumberOfPages()==0 and ui:getAlreadyReadPages()==0)
local tw,tb,ti=notePerson('Text must stay current through terminal handoff.')
local to=startNote(tw,tb,ti)
__nativeNoteCallback(to,'progress',1);__nativeNoteCallback(to,'perform')
ti:addPage(1,'Text replaced during the terminal handoff.')
__nativeNoteCallback(to,'complete')
check('terminal_handoff_rechecks_exact_current_text',__records[tw].noteReadingOutcomes==nil
    and __records[tw].studyWork.status=='interrupted')
local inlineWho,inlineBody,inlineItem=notePerson('A complete synchronous native attempt.')
local addNote=ISTimedActionQueue.add
local inlineBound=false
ISTimedActionQueue.add=function(owner)
    addNote(owner)
    local person=__records[owner.personId];local work=person.studyWork
    local admission=person.proceduralPlanning.purposes[work.purposeId].admission
    inlineBound=admission~=nil and admission.note.workId==work.id and admission.stage=='prepared'
    __nativeNoteCallback(owner,'start');completeNote(owner)
end
local inlineAccepted=S.beginLeisure(inlineWho,inlineBody,inlineItem)
ISTimedActionQueue.add=addNote
local inlineWork=__records[inlineWho].studyWork
check('inline_native_note_callbacks_have_prior_exact_binding',inlineBound and inlineAccepted
    and inlineWork.status=='completed'
    and __records[inlineWho].proceduralPlanning.purposes[inlineWork.purposeId].steps[2].status=='completed'
    and S.noteOutcome(inlineWho,inlineWork.sequence)~=nil)
local vw,vb,vi=notePerson('A rejected purpose cannot start reading.')
local admitNote=P.noteAdmission;local noteAdds=0;local beforeAdd=ISTimedActionQueue.add
P.noteAdmission=function() return false end
ISTimedActionQueue.add=function(owner) noteAdds=noteAdds+1;return beforeAdd(owner) end
local rejectedBinding=S.beginLeisure(vw,vb,vi)
P.noteAdmission=admitNote;ISTimedActionQueue.add=beforeAdd
check('refused_note_binding_never_reaches_native_queue',not rejectedBinding and noteAdds==0
    and __records[vw].noteReadingOutcomes==nil and not vb:isReading())
local lostWho,lostBody,lostItem=notePerson('This actual item will change native containers.')
local lostAction=startNote(lostWho,lostBody,lostItem);__nativeNoteCallback(lostAction,'progress',0.4)
local destination=__transferNativeNote(lostItem);lostBody.items={};lostItem:setJobDelta(0.75)
__nativeNoteCallback(lostAction,'stop')
check('transferred_note_stop_preserves_foreign_item_progress',lostItem:getContainer()==destination
    and lostItem:getJobDelta()==0.75 and not lostBody:isReading()
    and __records[lostWho].studyWork.status=='interrupted')
local lostWho2,lostBody2,lostItem2=notePerson('Only the original held item may be updated.')
local lostAction2=startNote(lostWho2,lostBody2,lostItem2);__nativeNoteCallback(lostAction2,'progress',1)
local destination2=__transferNativeNote(lostItem2);lostBody2.items={};lostItem2:setJobDelta(0.5)
__nativeNoteCallback(lostAction2,'perform');__nativeNoteCallback(lostAction2,'complete')
check('transferred_note_perform_preserves_foreign_item_progress',lostItem2:getContainer()==destination2
    and lostItem2:getJobDelta()==0.5 and not lostBody2:isReading()
    and __records[lostWho2].noteReadingOutcomes==nil)
local retiredWho,retiredBody,retiredItem=notePerson('A late callback has no new action authority.')
local retiredAction=startNote(retiredWho,retiredBody,retiredItem);__nativeNoteCallback(retiredAction,'progress',0.3)
S.interrupt(retiredWho,retiredBody,'higher priority work')
check('explicit_note_interruption_retires_owned_presentation',not retiredBody:isReading()
    and retiredItem:getJobDelta()==0 and __records[retiredWho].noteReadingOutcomes==nil)
local currentOther={character=retiredBody};ISTimedActionQueue.add(currentOther)
ISTimedActionQueue.add(retiredAction) -- delayed stale queue membership, not current Study runtime authority
retiredBody:setReading(true);retiredItem:setJobDelta(0.5)
__nativeNoteCallback(retiredAction,'perform');__nativeNoteCallback(retiredAction,'stop')
check('retired_queued_note_callbacks_preserve_current_action',ISTimedActionQueue.hasAction(currentOther)
    and retiredBody:isReading() and retiredItem:getJobDelta()==0.5
    and __records[retiredWho].noteReadingOutcomes==nil)
-- Canonical Gesture boundary is controlled here; the companion instrument
-- proof exercises its actual native sound owner. Planning never trusts a supplied result.
local iid = person()
local currentWork, outcomes = nil, {}
SAO.Gesture = {
 nextInstrumentSequence=function(who) return (__records[who].instrumentSequence or 0) + 1 end,
 instrumentWork=function(who) return currentWork and currentWork.actorId == who and currentWork end,
 instrumentOutcome=function(who, key)
  local result = outcomes[key]
  return result and result.actorId == who and result or nil
 end,
}
local ctx = {activity='blow-harmonica',itemKey='harmonica-1',affordance='Base.Harmonica',
 nativeVerb='blow-harmonica',owner='SAO.Gesture',atLocation=true,locationKey='here'}
local function admitted(purpose)
 local sequence = SAO.Gesture.nextInstrumentSequence(iid)
 __records[iid].instrumentSequence = sequence
 currentWork = {actorId=iid,workId='instrument:'..iid..':'..sequence,sequence=sequence,
  itemId='harmonica-1',itemType='Base.Harmonica',verb='blow-harmonica',bodyToken='native-1',bodyGenerationKnown=true,
  status='prepared',admittedAtHours=__hours}
 return P.admitInstrument(iid,purpose.id,currentWork.workId)
end
local function ended(status)
 local result={} for k,v in pairs(currentWork) do result[k]=v end
 result.status=status;result.atHours=__hours;result.startedAtHours=__hours;result.endedAtHours=__hours
 result.queueAdmitted=true;result.soundEmitted=true;result.worldSoundEmitted=true;result.soundEnded=true
 outcomes[result.workId]=result;currentWork=nil;return result
end
local offeredEffects
SAO.Cognition = {interpretPlans=function(who,candidates,context)
 offeredEffects={who=who,candidates=candidates,context=context};return {}
end}
local ip = P.planLeisure(iid,ctx)
check('instrument_candidates_use_exact_sound_consequence',offeredEffects.who==iid
 and offeredEffects.candidates[1].consequences[1]~=nil and offeredEffects.candidates[2].consequences[1]~=nil
 and offeredEffects.candidates[1].consequences[1].kind=='recreate'
 and offeredEffects.candidates[2].consequences[1].sourceId=='native:sound:BlowHarmonica'
 and offeredEffects.candidates[1].consequences[1].itemType=='Base.Harmonica'
 and offeredEffects.candidates[1].consequences[1].category=='leisure')
check('instrument_occurrence_planned_before_admission',ip.instrument.occurrence==1 and ip.instrument.expectedSequence==1
 and ip.admission==nil and ip.steps[2].status~='completed')
check('generic_instrument_admission_refused',not P.noteAdmission(iid,ip.id,'SAO.Gesture','forged'))
check('canonical_instrument_admission',admitted(ip))
check('prepared_binding_is_not_native_queue_admission',ip.admission.stage=='prepared' and ip.steps[2].status~='completed')
local firstWork = currentWork.workId
check('instrument_choice_refresh_keeps_exact_admission',P.planLeisure(iid,ctx)==ip and ip.admission.correlationId==firstWork)
check('generic_instrument_completion_refused',not P.recordResult(iid,ip.id,{owner='SAO.Gesture',token='leisure:performed',status='completed',correlationId=firstWork}))
local firstResult = ended('completed')
firstResult.queueAdmitted=false
check('prepared_unqueued_work_cannot_complete',not P.consumeInstrumentOutcome(iid,firstWork))
firstResult.queueAdmitted=true
firstResult.soundEnded=false
check('sound_without_observed_end_cannot_complete',not P.consumeInstrumentOutcome(iid,firstWork))
firstResult.soundEnded=true;firstResult.bodyToken='foreign'
check('foreign_sound_generation_cannot_complete',not P.consumeInstrumentOutcome(iid,firstWork))
firstResult.bodyToken='native-1'
check('canonical_sound_end_completes_only_occurrence',P.consumeInstrumentOutcome(iid,firstWork)
 and ip.steps[2].status=='completed' and ip.steps[3].status~='completed'
 and __records[iid].proceduralPlanning.practice['blow-harmonica']==nil)
local repeatPurpose = P.planLeisure(iid,ctx)
check('completed_sound_allows_new_occurrence',repeatPurpose and repeatPurpose.id~=ip.id
 and repeatPurpose.instrument.occurrence==2 and ip.steps[3].status~='completed')
check('old_sound_result_does_not_advance_next_occurrence',P.consumeInstrumentOutcome(iid,firstWork)
 and repeatPurpose.steps[2].status~='completed' and repeatPurpose.admission==nil)
check('next_occurrence_admitted',admitted(repeatPurpose))
-- Normal SAO bodies have no external-generation token. The owner reports this
-- explicitly while keeping its exact native body/record custody private.
currentWork.bodyToken=nil;currentWork.bodyGenerationKnown=false
repeatPurpose.admission=nil
check('ordinary_tokenless_native_work_admitted',P.admitInstrument(iid,repeatPurpose.id,currentWork.workId)
 and repeatPurpose.admission.bodyGenerationKnown==false and repeatPurpose.admission.bodyToken==nil)
local secondWork=currentWork.workId
local secondResult=ended('interrupted')
check('interrupted_sound_preserves_occurrence',P.consumeInstrumentOutcome(iid,secondWork)
 and repeatPurpose.admission==nil and repeatPurpose.steps[2].status=='interrupted'
 and __records[iid].proceduralPlanning.practice['blow-harmonica']==nil)
local retried=P.planLeisure(iid,ctx)
check('interrupted_occurrence_reuses_intent_new_sequence',retried==repeatPurpose
 and retried.instrument.occurrence==2 and retried.instrument.expectedSequence==3)
currentWork={actorId=iid,workId=secondWork,sequence=2,itemId='harmonica-1',itemType='Base.Harmonica',
 verb='blow-harmonica',bodyToken='native-1',bodyGenerationKnown=true,status='prepared',admittedAtHours=__hours}
check('old_admission_cannot_claim_new_attempt',not P.admitInstrument(iid,retried.id,secondWork))
currentWork=nil
check('retry_current_attempt_admitted',admitted(retried))
check('reconcile_cannot_retire_live_native_work',not P.reconcileInstrument(iid,'reload') and retried.admission~=nil)
local freshInstrument=__freshVMChoice(__records[iid],'__instrument__',ctx,__hours)
check('fresh_vm_instrument_intent_survives_without_fabricated_execution',freshInstrument.purpose.instrument.occurrence==2
 and freshInstrument.purpose.instrument.expectedSequence==4 and freshInstrument.purpose.admission==nil
 and freshInstrument.purpose.steps[2].status~='completed'
 and freshInstrument.person.proceduralPlanning.purposes[ip.id].steps[3].status~='completed')
__records[iid]=__nativeRoundtrip(__records[iid]);currentWork=nil
retried=__records[iid].proceduralPlanning.purposes[retried.id]
check('reloaded_missing_runtime_is_unobservable_not_complete',P.reconcileInstrument(iid,'runtime-adopted')
 and retried.admission==nil and retried.steps[2].status~='completed')
local reloaded=P.planLeisure(iid,ctx)
check('reload_keeps_occurrence_and_renews_physical_attempt',reloaded==retried
 and reloaded.instrument.occurrence==2 and reloaded.instrument.expectedSequence==4)
check('old_interrupted_result_cannot_advance_reloaded_intent',not P.consumeInstrumentOutcome(iid,secondWork)
 and reloaded.steps[2].status~='completed')
__d2ReadingResults = table.concat(results, '\n')
