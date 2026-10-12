-- First phase executes committed historical WindowRepair and actual installed
-- AddWindowAction.complete. Owner literal is never rewritten or manufactured.
local function check(name,value)__windowCheck(name,value)end
local store={}
ModData={get=function(key)return store[key] end,getOrCreate=function(key)store[key]=store[key] or {};return store[key]end}
SAO.Identity.all=function()return __records end
store.SurvivorAwareness_Cognition={settings={enabled=false}}
local function equal(a,b)
    if type(a)~=type(b)then return false end
    if type(a)~='table'then return a==b end
    for k,v in pairs(a)do if not equal(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
end
function __produceAuthenticLegacyPaneOutcome()
    __hours=400
    local f=__windowFixture('genuine-legacy-pane')
    local W=SAO.WindowRepair
    local a=__windowAdmitted(f)
    __nativeOp('reset');f.window.mirror=true;f.inventory.mirror=true
    check('legacy_installed_action_actual_completion',a:complete()==true and __nativeOp('poststate'))
    a:perform();W.active(f.id,f.body)
    local row=W.outcome(f.id,1)
    check('legacy_authentic_owner_kept',row and row.nativeOwner=='AddWindowAction.complete'
        and row.paneConsumed and row.nativeAttempted and row.planningAcknowledged and row.learningAcknowledged~=true)
    check('legacy_original_owner_runtime_retired',W.runtimeCount()==0 and #ISTimedActionQueue.getTimedActionQueue(f.body).queue==0)
    f.rec=__nativeRoundtrip(f.rec);__records[f.id]=f.rec
    check('legacy_native_saved_receipt_preserved',f.rec.windowRepair.outcomes['1'].nativeOwner=='AddWindowAction.complete')
    __legacyFixture=f
    -- Real owner is terminal, all handles retired. Reconstruct current module
    -- from source rather than accepting the old module's reload early-return.
    SAO.WindowRepair=nil
end
function __replayAuthenticLegacyPaneOutcome()
    local f=__legacyFixture
    local W,P,C=SAO.WindowRepair,SAO.ProceduralPlanning,SAO.Cognition
    C.configure(.5,12,3)
    local row=W.outcome(f.id,1)
    check('legacy_current_reader_accepts_saved_owner',row and row.nativeOwner=='AddWindowAction.complete')
    if not row then __windowResults=table.concat(__checks,'\n');return end
    local practice=P.techniqueProfile(f.id).practice[row.entryKey].completed
    local payment=f.inventory.sent
    local sync=f.window.synced
    check('legacy_current_learning_delivers_once',W.deliverLearning(f.id)==1 and #f.rec.cognition.experiences==1
        and f.rec.cognition.experiences[1].id==row.id)
    if not f.rec.cognition then __windowResults=table.concat(__checks,'\n');return end
    local first=__nativeRoundtrip(f.rec.cognition)
    check('legacy_same_owner_second_replay_inert',W.deliverLearning(f.id)==0
        and P.consumeWindowRepairOutcome(f.id,1)==true and equal(first,f.rec.cognition))
    f.rec=__nativeRoundtrip(f.rec);__records[f.id]=f.rec;C.rebindWorld()
    f.rec.windowRepair.outcomes['1'].learningAcknowledged=nil
    __hours=401
    check('legacy_saved_ack_loss_replay_once_only',W.deliverLearning(f.id)==1 and equal(first,f.rec.cognition)
        and W.outcome(f.id,1).learningAcknowledged==true)
    check('legacy_no_repeat_payment_effect_credit',f.inventory.sent==payment and f.window.synced==sync
        and __nativeOp('poststate') and P.techniqueProfile(f.id).practice[row.entryKey].completed==practice
        and f.rec.cognition.models.ordinary.revision==1 and f.rec.cognition.models.associative.revision==1)
    local oldOwner=f.rec.windowRepair.outcomes['1'].nativeOwner
    f.rec.windowRepair.outcomes['1'].nativeOwner='Foreign.complete'
    check('legacy_foreign_owner_refuses',W.outcome(f.id,1)==nil and C.windowRepairOutcome(f.id,row)==false)
    f.rec.windowRepair.outcomes['1'].nativeOwner=oldOwner
    check('legacy_identity_remains_historical',W.outcome(f.id,1).nativeOwner=='AddWindowAction.complete')
    __windowResults=table.concat(__checks,'\n')
end
