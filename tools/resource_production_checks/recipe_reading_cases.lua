-- Installed reading and queue; actual native item/script and ReadLiterature
-- effects. Actor, animation, clock and declared Planner callbacks are ports.
SkillBook={}
CharacterActionAnims={Read='Read'}
CharacterTrait.ILLITERATE='Illiterate';CharacterTrait.FAST_READER='FastReader';CharacterTrait.SLOW_READER='SlowReader'
CharacterTrait.HERBALIST='Herbalist';CharacterTrait.HERBALIST_PROF='HerbalistProf'
CharacterStat={BOREDOM='Boredom',UNHAPPINESS='Unhappiness',STRESS='Stress'}
ItemTag.UNINTERESTING='Uninteresting';ItemTag.FAST_READ='FastRead';ItemBodyLocation={EYES='Eyes'}
ItemType.LITERATURE='Literature'
SAO.History.literacyOf=function(id) return __records[id].literacy or 'full' end
SAO.Conditions={readingTime=function(id) return __records[id].readingTime or 1 end}
SAO.Census={JOB_PERK={}}
SAO.Needs.ownsRecoveryBody=function(id,body)
    local r=__records[id]
    return r and SAO.Body.get(id)==body and not r.dead and not r.zaoTransferPending
        and body:getModData().SAOPersonId==id and body:getModData().SAOExternalToken==r.bodyOwnerToken
end
SAO.Needs.workAvailable=function(body)
    local q=ISTimedActionQueue.getTimedActionQueue(body);return not q.current and #q.queue==0
end
SAOJavaBridge.privateCarriedItems=function(_,body)
    local items=body:getInventory().items
    return {size=function() return #items end,get=function(_,i) return items[i+1] end}
end
function getSandboxOptions() return {getOptionByName=function() return {getValue=function() return 1 end} end} end
function getGameTime() return {getMinutesPerDay=function() return 1440 end,getMultiplier=function() return 1 end} end
function sendServerCommand() end
function sendSyncPlayerFields() end
function syncItemFields() end
HaloTextHelper={addBadText=function() end}
local originalInstance=instanceof
function instanceof(o,kind) return originalInstance(o,kind) or type(o)=='table' and kind=='Literature' and o.nativeLiterature==true end
local originalTimed=LuaTimedActionNew.new
LuaTimedActionNew.new=function(action,body)
    local a=originalTimed(action,body)
    function a:setOverrideHandModelsObject() end
    function a:setAnimVariable() end
    function a:setCurrentTime() end
    return a
end
function getScriptManager()
    return {getItem=function(_,fullType)
        if __recipeNative('script',fullType,'pages')==nil then return nil end
        return {getNumberOfPages=function() return __recipeNative('script',fullType,'pages') end,
            isItemType=function(_,kind) return kind==ItemType.LITERATURE and __recipeNative('script',fullType,'literature') end,
            getSkillTrained=function() return __recipeNative('script',fullType,'skill') end,
            getLearnedRecipes=function() return {contains=function(_,name) return __recipeNative('script',fullType,'recipe',name) end} end}
    end}
end
local checks={}
local metalRecipes={'MetalWallFrame','MetalWallLvl1','MetalWallLvl2','MetalDoorFrameLvl1','MetalDoorFrameLvl2'}
local metalReading={};for _,name in ipairs(metalRecipes) do metalReading[name]=true end
local function check(name,value) checks[#checks+1]=name;print('CHECK '..name..'='..tostring(value==true)) end
local function current(f) return ISTimedActionQueue.getTimedActionQueue(f.body).current end
local function outcome(f)
    return f.recipe=='Generator' and SAO.Study.generatorOutcome(f.id,f.rec.studyWork.id)
        or SAO.Study.recipeOutcome(f.id,f.rec.studyWork.id)
end
local function purpose(f) return __records[f.id].proceduralPlanning.purposes[f.purpose.id] end
local function fixture(id,recipe,fullType)
    __recipeNative('reset');__reloadReadingOwner()
    local f=__boardingFixture(id,false);f.inventory.items={};f.recipe=recipe or 'DoubleFenceGate'
    local literature=fullType or (metalReading[f.recipe] and 'Base.MetalworkMag1' or 'Base.MetalworkMag3')
    f.book=__boardingItem(literature:match('%.(.+)$'),__recipeNative('new-item',literature),f.inventory)
    f.book.nativeLiterature=true;f.inventory.items={f.book}
    function f.book:getNumberOfPages() return __recipeNative('item',self.id,'pages') end
    function f.book:getSkillTrained() return nil end
    function f.book:getReadType() return nil end
    function f.book:canBeWrite() return false end
    function f.book:hasTag(tag) return self.uninteresting==true and tag==ItemTag.UNINTERESTING end
    function f.book:getLearnedRecipes() return {contains=function(_,name) return not f.book.recipesChanged and __recipeNative('item',f.book.id,'recipe',name) end,
        isEmpty=function() return false end} end
    function f.book:hasModData() return self.printMedia==true end
    function f.book:getModData() return self.printMedia and {printMedia={}} or {} end
    function f.book:getAlreadyReadPages() return self.pages or 0 end
    function f.book:setAlreadyReadPages(value) self.pages=value end
    function f.book:getUnhappyChange() return 0 end
    function f.body:isRecipeActuallyKnown(name) return __recipeNative('known',name) end
    function f.body:isRecipeKnown(name) return __recipeNative('visible-known',name) end
    function f.body:hasTrait(trait) return trait==CharacterTrait.ILLITERATE and self.illiterate==true end
    function f.body:tooDarkToRead() return self.dark==true end
    function f.body:getAlreadyReadPages() return 0 end
    function f.body:setAlreadyReadPages() end
    function f.body:getWornItems() return {getItem=function() return nil end} end
    function f.body:isSitting() return false end
    function f.body:getVehicle() return nil end
    function f.body:getStats() return {get=function() return 0 end} end
    function f.body:setReading(value) self.reading=value end
    function f.body:playSound() end
    function f.body:isReading() return self.reading==true end
    function f.body:getAlreadyReadBook() return {add=function() end} end
    function f.body:ReadLiterature(value) if not self.noReadEffect then __recipeNative('read',value:getID()) end end
    function f.body:learnRecipe() error('manual recipe grant is unavailable') end
    function f.body:getOnlineID() return 0 end
    f.purpose={id=(metalReading[f.recipe] and 'shelter-purpose:' or 'gate-purpose:')..id,cursor=1,
        gateAccess=f.recipe~='Generator' and not metalReading[f.recipe],shelterConstruction=metalReading[f.recipe] or nil,
        generatorPower=f.recipe=='Generator',status='active',steps={}}
    f.step={id='read-step:'..id,owner='SAO.Study',operation=f.recipe=='Generator' and 'learn-generator' or 'learn-recipe',
        token=f.recipe=='Generator' and 'utility:generator-known' or 'recipe:knowledge-acquired',target=f.recipe,
        recipeName=f.recipe~='Generator' and f.recipe or nil,inputItemId=tostring(f.book:getID()),inputItemType=f.book:getFullType(),status='available'}
    f.purpose.steps={f.step,{id='build:'..id,owner='SAO.ResourceProduction',status='waiting'}}
    f.rec.proceduralPlanning={purposes={[f.purpose.id]=f.purpose},active=f.purpose.id}
    return f
end
-- The reader is qualified independently of the coupled construction
-- planner. These declared callbacks validate/requery its agreed exact contract.
SAO.ProceduralPlanning={}
local P=SAO.ProceduralPlanning
local function activePurpose(id)
    local state=__records[id].proceduralPlanning;local p=state.purposes[state.active]
    return p,p.steps[p.cursor]
end
P.recipeReadingPurpose=activePurpose
local function admit(id,w)
    local p,s=activePurpose(id)
    if p.admission or s.status~='available' or s.id~=w.purposeStepId or p.id~=w.purposeId or w.actorId~=id
        or w.requestedPurposeId~=p.id or w.requestedPurposeStepId~=s.id or s.owner~=w.owner or s.operation~=w.operation
        or s.token~=w.token or s.inputItemId~=w.itemId or s.inputItemType~=w.itemType
        or w.kind=='recipe-reading' and (not(p.gateAccess or p.shelterConstruction) or s.recipeName~=w.recipeName or s.target~=w.target) then return false end
    p.admission={owner=w.owner,stepId=s.id,correlationId=w.id,target=s.target};return true
end
P.admitRecipeReading=admit;P.admitGeneratorReading=admit
local function consume(id,outcomeId,generator)
    local r=__records[id]
    if r.refuseFeedback then return false end
    local row=generator and SAO.Study.generatorOutcome(id,outcomeId) or SAO.Study.recipeOutcome(id,outcomeId)
    if not row then return false end
    local p=r.proceduralPlanning.purposes[row.purposeId];local s=p and p.steps[p.cursor]
    if not p then return false end
    p.seen=p.seen or {};if p.seen[row.id] then return true end
    if not p or not s or not p.admission or p.admission.correlationId~=row.id or p.admission.stepId~=row.purposeStepId
        or s.id~=row.purposeStepId or s.operation~=row.operation or s.token~=row.token or s.inputItemId~=row.itemId
        or s.inputItemType~=row.itemType or not generator and (s.recipeName~=row.recipeName or s.target~=row.target) then return false end
    p.seen[row.id]=true;p.admission=nil
    if row.status=='completed' and row.recipeKnown and row.nativeStarted and row.nativeCompleted then
        p.cursor=p.cursor+1;p.completions=(p.completions or 0)+1
    else p.interruptions=(p.interruptions or 0)+1 end
    return true
end
P.consumeRecipeReading=function(id,readingId) return consume(id,readingId,false) end
P.consumeGeneratorReading=function(id,readingId) return consume(id,readingId,true) end
local function begin(f)
    if f.recipe=='Generator' then return SAO.Study.beginGenerator(f.id,f.body,f.book,f.purpose.id,f.step.id) end
    return SAO.Study.beginRecipe(f.id,f.body,f.book,f.purpose.id,f.step.id,f.recipe)
end
local function progress(f,value)
    local a=current(f);a:start();a.action.jobDelta=value;a:update();return a
end
local function finish(f,performFirst)
    local a=progress(f,1);a.action.nativeFinished=true
    if performFirst then a:perform();a:complete() else a:complete();a:perform() end
    return outcome(f),a
end
local function learnedCase()
    local f=fixture('native-learn');if not begin(f) then return false end
    local row,a=finish(f)
    return row and row.status=='completed' and row.recipeName=='DoubleFenceGate' and row.recipeKnown
        and __recipeNative('known','DoubleFenceGate') and __recipeNative('reads')==1 and purpose(f).cursor==2
end
local function progressCase()
    local f=fixture('partial');assert(begin(f));local a=progress(f,.4);a.action.nativeFinished=true
    local refused=a:complete()==false and not outcome(f) and __recipeNative('reads')==0
    SAO.Study.interrupt(f.id,f.body,'partial')
    return refused and outcome(f).status=='interrupted' and purpose(f).cursor==1
end
local function changedRecipeCase()
    local f=fixture('recipe-changed');assert(begin(f));local a=progress(f,1);a.action.nativeFinished=true
    f.step.recipeName='DoubleWireGate';f.step.target='DoubleWireGate';f.purpose.admission.target='DoubleWireGate'
    return a:complete()==false and __recipeNative('reads')==0 and not outcome(f)
end
local function queueCase()
    local f=fixture('queue-replaced');assert(begin(f));local a=progress(f,1);a.action.nativeFinished=true
    local old=ISTimedActionQueue.queues[f.body];f.body.holdCancellation=true
    local successor={character=f.body,kept=true};local replacement=ISTimedActionQueue:new(f.body)
    replacement.queue={successor};replacement.current=successor
    local refused=a:complete()==false and a:perform()==false and __recipeNative('reads')==0
    local retained=SAO.Study.active(f.id,f.body) and f.rec.studyWork.status=='reading' and old.current==a
    f.body.holdCancellation=false
    local retired=SAO.Study.interrupt(f.id,f.body,'replacement')
    return refused and retained and retired and outcome(f).status=='interrupted'
        and old.current==nil and #old.queue==0 and replacement.current==successor and replacement.queue[1]==successor
end
local function pendingCase(saved,recipe)
    local f=fixture((saved and 'saved-pending' or 'pending')..(recipe or ''),recipe);assert(begin(f));local a=progress(f,.2)
    f.body.holdCancellation=true
    if saved then
        f.rec=__nativeRoundtrip(f.rec);__records[f.id]=f.rec;__reloadReadingOwner()
    end
    local blocked=saved and SAO.Study.reconcileRecipe(f.id,f.body)==false or not saved and SAO.Study.interrupt(f.id,f.body,'danger')==false
    local retained=f.rec.studyWork.status=='reading' and purpose(f).admission~=nil and not outcome(f)
    f.body.holdCancellation=false
    local retired=saved and SAO.Study.reconcileRecipe(f.id,f.body) or SAO.Study.interrupt(f.id,f.body,'danger')
    local row=outcome(f);a.action.nativeFinished=true;a.action.jobDelta=1
    local late=a:complete()==false and a:perform()==false
    return blocked and retained and retired and row and row.status=='interrupted' and not row.recipeKnown
        and purpose(f).cursor==1 and not purpose(f).admission and late and __recipeNative('reads')==0
end
local function noLearnCase()
    local f=fixture('no-learn');assert(begin(f));f.body.noReadEffect=true
    local row=finish(f)
    return row and row.status=='interrupted' and row.nativeCompleted and not row.recipeKnown
        and purpose(f).cursor==1 and not __recipeNative('known',f.recipe)
end
local function nativeValidityCase()
    local f=fixture('dark-after-start');assert(begin(f));local a=progress(f,1);a.action.nativeFinished=true;f.body.dark=true
    return a:complete()==false and a:perform()==false and __recipeNative('reads')==0
end
local function metalReaderCase(recipe,performFirst)
    local f=fixture('metal-native-'..recipe,recipe)
    local unknown=not __recipeNative('known',recipe) and __recipeNative('visible-known',recipe)
    local creations=__recipeNative('creations')
    local metadata=SAO.Study.usefulRecipeType(f.body,'Base.MetalworkMag1',recipe)
        and __recipeNative('creations')==creations and not SAO.Study.usefulRecipeType(f.body,'Base.MetalworkMag3',recipe)
    if not begin(f) then return false end
    local work=f.rec.studyWork
    local preparing=work.phase=='preparing' and work.progress==0 and not outcome(f) and purpose(f).cursor==1
        and purpose(f).shelterConstruction and not purpose(f).gateAccess and work.recipeName==recipe and work.target==recipe
        and work.purposeId==f.purpose.id and work.purposeStepId==f.step.id and work.requestedPurposeId==f.purpose.id
        and work.requestedPurposeStepId==f.step.id and work.itemId==tostring(f.book:getID()) and work.itemType=='Base.MetalworkMag1'
    local row,a=finish(f,performFirst)
    local native=row and row.status=='completed' and row.nativeStarted and row.nativeCompleted and row.recipeKnown
        and row.recipeName==recipe and row.target==recipe and row.kind=='recipe-reading' and row.operation=='learn-recipe'
        and row.token=='recipe:knowledge-acquired' and row.nativeOwner=='ISReadABook.complete' and row.progress==1
        and row.purposeId==f.purpose.id and row.purposeStepId==f.step.id and row.itemId==tostring(f.book:getID())
        and row.itemType=='Base.MetalworkMag1' and __recipeNative('reads')==1
    for _,name in ipairs(metalRecipes) do native=native and __recipeNative('known',name) end
    native=native and not __recipeNative('known','MetalDoorLvl1') and not __recipeNative('known','MetalDoorLvl2')
    if not row then return false end
    row.recipeName='foreign';row.status='interrupted'
    local detached=SAO.Study.recipeOutcome(f.id,work.id).recipeName==recipe and SAO.Study.recipeOutcome(f.id,work.id).status=='completed'
    f.rec=__nativeRoundtrip(f.rec);__records[f.id]=f.rec;__reloadReadingOwner()
    local saved=SAO.Study.reconcileRecipe(f.id,f.body) and SAO.Study.reconcileRecipe(f.id,f.body)
        and SAO.Study.recipeOutcome(f.id,work.id).delivered and purpose(f).completions==1 and purpose(f).cursor==2
        and a:complete()==false and a:perform()==false and __recipeNative('reads')==1
        and not SAO.Study.usefulRecipeType(f.body,'Base.MetalworkMag1',recipe)
    return unknown and metadata and preparing and native and detached and saved
end
local function metalScopeCase()
    local f=fixture('metal-scope-change','MetalWallLvl1')
    if not begin(f) then return false end
    local a=progress(f,1);a.action.nativeFinished=true;f.purpose.shelterConstruction=nil
    return a:complete()==false and a:perform()==false and not outcome(f) and __recipeNative('reads')==0
        and not __recipeNative('known',f.recipe)
end
local function metalNoLearnCase()
    local f=fixture('metal-no-learn','MetalDoorFrameLvl2')
    if not begin(f) then return false end
    f.body.noReadEffect=true;local row=finish(f)
    return row and row.status=='interrupted' and row.nativeCompleted and not row.recipeKnown
        and purpose(f).cursor==1 and not __recipeNative('known',f.recipe)
end
local function metalFeedbackCase()
    local f=fixture('metal-feedback','MetalWallLvl2')
    if not begin(f) then return false end
    f.rec.refuseFeedback=true;local row=finish(f,true)
    if not row then return false end
    local retained=not row.delivered and row.recipeKnown and purpose(f).cursor==1 and purpose(f).admission~=nil
    f.rec=__nativeRoundtrip(f.rec);__records[f.id]=f.rec;f.rec.refuseFeedback=nil;__reloadReadingOwner()
    return retained and SAO.Study.reconcileRecipe(f.id,f.body) and SAO.Study.reconcileRecipe(f.id,f.body)
        and purpose(f).cursor==2 and purpose(f).completions==1 and __recipeNative('reads')==1
        and SAO.Study.recipeOutcome(f.id,row.id).delivered
end
local function metalSavedResumptionCase()
    local f=fixture('metal-saved-resume','MetalDoorFrameLvl1')
    if not begin(f) then return false end
    local old=progress(f,.25);local oldId=f.rec.studyWork.id
    f.rec=__nativeRoundtrip(f.rec);__records[f.id]=f.rec;__reloadReadingOwner();f.body.holdCancellation=true
    local held=SAO.Study.reconcileRecipe(f.id,f.body)==false and f.rec.studyWork.status=='reading' and purpose(f).admission~=nil
    f.body.holdCancellation=false
    local retired=SAO.Study.reconcileRecipe(f.id,f.body)
    local interruption=SAO.Study.recipeOutcome(f.id,oldId)
    local truthful=retired and interruption and interruption.status=='interrupted' and not interruption.recipeKnown
        and __recipeNative('reads')==0 and not __recipeNative('known',f.recipe) and purpose(f).cursor==1
    if not truthful or not begin(f) then return false end
    local resumed=f.rec.studyWork;local row=finish(f,true)
    old.action.nativeFinished=true;old.action.jobDelta=1
    return held and row and row.status=='completed' and row.recipeKnown and resumed.id~=oldId
        and resumed.purposeId==f.purpose.id and resumed.purposeStepId==f.step.id and resumed.itemId==tostring(f.book:getID())
        and purpose(f).cursor==2 and purpose(f).completions==1 and #f.rec.recipeReadingOutcomes==2
        and old:complete()==false and old:perform()==false and __recipeNative('reads')==1
end
function __runRecipeReadingCases()
    local S=SAO.Study
    local f=fixture('metadata');local creations=__recipeNative('creations')
    check('actual_script_both_exact_gate_names',S.usefulRecipeType(f.body,'Base.MetalworkMag3','DoubleFenceGate')
        and S.usefulRecipeType(f.body,'Base.MetalworkMag3','DoubleWireGate') and __recipeNative('creations')==creations)
    check('wrong_unknown_metadata_refused',not S.usefulRecipeType(f.body,'Base.MetalworkMag1','DoubleFenceGate')
        and not S.usefulRecipeType(f.body,'Base.Absent','DoubleWireGate') and not S.usefulRecipeType(f.body,'Base.MetalworkMag3','Generator'))
    check('native_named_knowledge_effect',learnedCase())
    for i,recipe in ipairs({'DoubleFenceGate','DoubleWireGate'}) do
        f=fixture('ordered-'..i,recipe);f.rec.readingTime=.5;assert(begin(f));local a=current(f)
        check('queue_is_preparation_'..i,f.rec.studyWork.phase=='preparing' and f.rec.studyWork.progress==0
            and not f.body:isRecipeActuallyKnown(recipe) and not outcome(f) and purpose(f).cursor==1 and a.maxTime==7200)
        local row,finished=finish(f,i==2)
        check('actual_completion_order_'..i,row and row.status=='completed' and row.nativeOwner=='ISReadABook.complete'
            and row.nativeStarted and row.nativeCompleted and row.progress==1 and row.recipeKnown
            and __recipeNative('known',recipe) and __recipeNative('known',recipe=='DoubleFenceGate' and 'DoubleWireGate' or 'DoubleFenceGate'))
        local canonical=row.id;row.status='interrupted';row.recipeName='foreign'
        check('detached_exact_receipt_'..i,S.recipeOutcome(f.id,canonical).status=='completed' and S.recipeOutcome(f.id,canonical).recipeName==recipe)
        f.rec=__nativeRoundtrip(f.rec);__records[f.id]=f.rec
        check('saved_completed_once_'..i,S.recipeOutcome(f.id,canonical).recipeKnown and S.reconcileRecipe(f.id,f.body)
            and purpose(f).completions==1 and finished:complete()==false and finished:perform()==false and __recipeNative('reads')==1)
        check('known_recipe_no_repeat_'..i,not S.usefulRecipeType(f.body,'Base.MetalworkMag3',recipe))
    end
    f=fixture('wrong-native-manual',nil,'Base.MetalworkMag1')
    check('actual_wrong_manual_admission_refused',not begin(f) and not f.purpose.admission and __recipeNative('reads')==0)
    check('partial_completion_refused',progressCase())
    check('changed_recipe_identity_refused',changedRecipeCase())
    check('replacement_queue_preserved',queueCase())
    check('pending_ack_retained',pendingCase(false))
    check('saved_native_ack_no_learning',pendingCase(true))
    check('native_complete_without_learning_refused',noLearnCase())
    check('native_darkness_after_start_refused',nativeValidityCase())
    local refusals={
        {'illiterate',function(x) x.body.illiterate=true end},
        {'literacy',function(x) x.rec.literacy='none' end},
        {'dark',function(x) x.body.dark=true end},
        {'not-held',function(x) x.inventory.items={} end},
        {'consumed',function(x) x.book.consumed=true end},
        {'uninteresting',function(x) x.book.uninteresting=true end},
        {'printmedia',function(x) x.book.printMedia=true end},
        {'foreign-body',function(x) SAO.Body.active[x.id]={} end},
        {'foreign-actor',function(x) x.body.md.SAOPersonId='other' end},
        {'item-target',function(x) x.step.inputItemId='wrong' end},
        {'purpose-target',function(x) x.step.target='DoubleWireGate' end},
        {'purpose-recipe',function(x) x.step.recipeName='DoubleWireGate' end},
        {'other-owner',function(x) x.rec.resourceProductionWork={status='working'} end},
    }
    for _,row in ipairs(refusals) do f=fixture('begin-'..row[1]);row[2](f)
        check('begin_refuses_'..row[1]:gsub('-','_'),not begin(f) and __recipeNative('reads')==0 and not f.purpose.admission)
    end
    local changes={
        {'body',function(x) SAO.Body.active[x.id]={} end},
        {'actor',function(x) x.body.md.SAOPersonId='other' end},
        {'token',function(x) x.body.md.SAOExternalToken='other' end},
        {'item',function(x) local copy={};for k,v in pairs(x.book) do copy[k]=v end;x.inventory.items={copy} end},
        {'source',function(x) x.book.recipesChanged=true end},
        {'world',function(x) __world.name='other-world' end},
        {'clock',function(x) __hours=x.rec.studyWork.beganAt-1 end},
        {'admission',function(x) x.purpose.admission.correlationId='other' end},
        {'step',function(x) x.purpose.steps[1].id='other' end},
        {'record',function(x) __records[x.id]=__nativeRoundtrip(x.rec) end},
    }
    for _,row in ipairs(changes) do f=fixture('changed-'..row[1]);assert(begin(f));local a=progress(f,1);a.action.nativeFinished=true
        row[2](f);check('completion_refuses_'..row[1],a:complete()==false and a:perform()==false and __recipeNative('reads')==0)
        __hours=100
    end
    f=fixture('queue-refused');f.body.queueRefused=true
    check('refused_admission_retires_exact_work',not begin(f) and f.rec.studyWork.status=='interrupted'
        and not f.purpose.admission and outcome(f).status=='interrupted' and __recipeNative('reads')==0)
    f=fixture('feedback');assert(begin(f));f.rec.refuseFeedback=true;local row=finish(f)
    local undelivered=row and not row.delivered and f.rec.studyWork.status=='completed' and purpose(f).cursor==1
    f.rec=__nativeRoundtrip(f.rec);__records[f.id]=f.rec;f.rec.refuseFeedback=nil;__reloadReadingOwner()
    check('saved_feedback_requery_once',undelivered and S.reconcileRecipe(f.id,f.body) and S.reconcileRecipe(f.id,f.body)
        and purpose(f).completions==1 and S.recipeOutcome(f.id,row.id).delivered and __recipeNative('reads')==1)
    local mutations={actorId='other',kind='generator-reading',recipeName='Generator',target='DoubleWireGate',operation='learn-generator',
        nativeOwner='foreign',nativeStarted=false,nativeCompleted=false,progress=0,recipeKnown=false,atHours=999,sequence=999,workId='other',outcomeId='other'}
    local canonical=f.rec.recipeReadingOutcomes[1]
    for key,value in pairs(mutations) do local old=canonical[key];canonical[key]=value
        check('saved_receipt_refuses_'..key:gsub('(%u)',function(c) return '_'..c:lower() end),S.recipeOutcome(f.id,row.id)==nil)
        canonical[key]=old
    end
    check('foreign_outcome_query_refused',S.recipeOutcome('other',row.id)==nil and S.generatorOutcome(f.id,row.id)==nil)
    f=fixture('legacy-generator','Generator','Base.ElectronicsMag4');assert(begin(f));row=finish(f,true)
    check('legacy_generator_shape_and_native_effect',row and row.kind=='generator-reading' and row.operation=='learn-generator'
        and row.token=='utility:generator-known' and row.recipeName==nil and row.recipeKnown and __recipeNative('known','Generator')
        and f.rec.recipeReadingOutcomes==nil and S.reconcileGeneratorReading(f.id,f.body) and purpose(f).completions==1)
    for index,recipe in ipairs(metalRecipes) do check('metal_native_recipe_'..index,metalReaderCase(recipe,index%2==0)) end
    check('metal_shelter_scope_change_refused',metalScopeCase())
    check('metal_native_complete_without_learning_refused',metalNoLearnCase())
    check('metal_saved_feedback_once',metalFeedbackCase())
    check('metal_pending_ack_retained',pendingCase(false,'MetalWallFrame'))
    check('metal_saved_native_ack_no_learning',pendingCase(true,'MetalDoorFrameLvl1'))
    check('metal_saved_reading_resumes_same_purpose',metalSavedResumptionCase())
    f=fixture('metal-wrong-manual','MetalWallLvl2','Base.MetalworkMag3')
    check('metal_wrong_native_manual_refused',not begin(f) and not f.purpose.admission and __recipeNative('reads')==0)
    f=fixture('intrinsic-door','MetalDoorLvl2')
    check('intrinsic_door_not_a_reader_target',not begin(f) and not S.usefulRecipeType(f.body,'Base.MetalworkMag1','MetalDoorLvl2')
        and not f.purpose.admission and __recipeNative('reads')==0)
    print('PASS recipe reading '..#checks)
end
function __runRecipeReadingControl(name)
    local cases={native_named_knowledge_effect=learnedCase,partial_completion_refused=progressCase,
        changed_recipe_identity_refused=changedRecipeCase,replacement_queue_preserved=queueCase,
        pending_ack_retained=function() return pendingCase(false) end,saved_native_ack_no_learning=function() return pendingCase(true) end,
        native_complete_without_learning_refused=noLearnCase,native_darkness_after_start_refused=nativeValidityCase,
        metal_native_named_knowledge_effect=function() return metalReaderCase('MetalWallFrame',true) end,
        metal_shelter_scope_change_refused=metalScopeCase,metal_native_complete_without_learning_refused=metalNoLearnCase}
    if not cases[name] then error('unknown recipe-reading control '..name) end
    check(name,cases[name]())
    print('NATIVE_READS '..tostring(__recipeNative('reads')))
end
