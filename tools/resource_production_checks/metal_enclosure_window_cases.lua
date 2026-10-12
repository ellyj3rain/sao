-- Native objects are cached reference receivers; installed producer owns every effect.
local cache={}
function __windowWrap(value)
    if type(value)~='table' or not value.__nativeId then return value end
    local id=value.__nativeId;if cache[id] then return cache[id] end
    local obj={__handle=id};cache[id]=obj
    setmetatable(obj,{__index=function(_,method)return function(self,...)
        return __windowWrap(__nativeWindow('invoke',self,method,{...}))
    end end});return obj
end
local oldInstance=instanceof
function instanceof(o,kind)
    if type(o)=='table' and rawget(o,'__handle') then return __nativeWindow('kind',o,kind) end
    if type(o)=='table' and o.shell and (kind=='IsoGameCharacter' or kind=='IsoPlayer') then return true end
    return oldInstance(o,kind)
end
function getSprite(name)return __windowWrap(__nativeWindow('sprite',name)) end
IsoGridSquare={ignoreBlockingSprites=ArrayList.new()}
GridSquareEdgeFacingDirection={NORTH_SOUTH='NORTH_SOUTH',EAST_WEST='EAST_WEST'}
setmetatable(IsoFlagType,{__index=function(_,key)return key end})
function getCore()return {getGoodHighlitedColor=function()return {}end,getBadHighlitedColor=function()return {}end,getOptionDoWindSpriteEffects=function()return false end,getGameMode=function()return 'Sandbox'end}end
function getText(s)return s end
function getItemName(s)return s end
function instanceItem(name)return __windowWrap(__nativeWindow('item',name)) end
function getScriptManager()return {getItemsTag=function(_,tag)return __windowWrap(__nativeWindow("tagItems",tag))end,FindItem=function()return nil end,
    getItem=function(_,fullType)
        if __recipeNative('script',fullType,'pages')==nil then return nil end
        return {getNumberOfPages=function()return __recipeNative('script',fullType,'pages')end,isItemType=function(_,kind)return kind==ItemType.LITERATURE and __recipeNative('script',fullType,'literature')end,
            getSkillTrained=function()return __recipeNative('script',fullType,'skill')end,getLearnedRecipes=function()return {contains=function(_,name)return __recipeNative('script',fullType,'recipe',name)end}end}
    end}end
ScriptManager={instance={FindItem=function()return nil end}};PerkFactory={getPerkName=function(perk)return perk end};function getDebug()return false end
for _,tag in ipairs({"HAMMER","SAW","SCREWDRIVER","DIG_PLOW","CROWBAR","SHARP_KNIFE","SCISSORS","WELDING_MASK","SEWING_NEEDLE","ROPE"})do ItemTag[tag]=tag end
function string.contains(s,sub)return s:find(sub,1,true)~=nil end
Perks.Woodwork='Woodwork';Perks.Electricity='Electricity';Perks.MetalWelding='MetalWelding';Perks.Farming='Farming';Perks.Masonry='Masonry'
function triggerEvent()end
function getTileOverlays()return {fixTableTopOverlays=function()end}end
ISMoveableCursor={clearCacheForAllPlayers=function()end}
function getSoundManager()return {playUISound=function()end}end
ItemPicker={updateOverlaySprite=function()end} -- Cosmetic receiver; native transfer is measured separately.
function sendRemoveItemFromContainer()end -- Offline native inventory removal is already measured.
IsoWindow={new=function(_,square,sprite,north)return __windowWrap(__nativeWindow('windowNew',square,sprite,north))end}
IsoGenerator={updateGenerator=function(square)return __nativeWindow('generator',square)end}
GameEntityFactory.CreateIsoEntityFromCellLoading=function(object)return __nativeWindow('factoryLoading',object)end
GameEntityFactory.TransferComponents=function(item,object)return __nativeWindow('factoryTransfer',item,object)end
__windowOriginalCarried=SAOJavaBridge.privateCarriedItems
local R,P,Ctl,N
local function check(name,value)print('WINDOW '..name..'='..tostring(value==true))end
local function prepare(grade,face,name)
    R,P,Ctl,N=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Controller,SAO.Needs
    SAOJavaBridge.privateCarriedItems=__windowOriginalCarried;ISMoveableDefinitions.load()
    local f=__enclosureFixture(name or 'window-chain-'..grade..face,'Base.MetalWindowFrameLvl'..grade,face)
    function f.siteSquare:getZone()return nil end
    __shelterControllerSetup(f)
    local p,s=__enclosurePlan(f);assert(R.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id}));local row=__shelterFinish(f)
    assert(row.status=='completed','real frame build failed')
    f.frame=__windowWrap(__nativeWindow('frame'));f.nativeSquare=__windowWrap(__nativeWindow('square'))
    f.inventory=__windowWrap(__nativeWindow('inventory'));function f.body:getInventory()return f.inventory end
    function f.body:getSquare()return __windowWrap(__nativeWindow('bodySquare'))end
    function f.body:isMovablesCheat()return false end
    function f.body:getPerkLevel()return f.skill or 5 end
    function f.body:isTimedActionInstant()return false end
    function f.body:hasTrait()return false end
    function f.body:clearVariable()end;function f.body:reportEvent()end
    function f.body:getVariableString()return '' end
    f.rec.bodyOwnerToken="window-token:"..f.id;f.body:getModData().SAOExternalToken=f.rec.bodyOwnerToken;f.body.primary,f.body.secondary=nil,nil
    function f.body:getPrimaryHandItem()return self.primary end;function f.body:getSecondaryHandItem()return self.secondary end
    local sprite=grade==1 and (face=='N' and 'fixtures_windows_01_1' or 'fixtures_windows_01_0') or (face=='N' and 'fixtures_windows_01_25' or 'fixtures_windows_01_24')
    f.glass=assert(ISMoveableSpriteProps.new(sprite):instanceItem(),'actual native movable item factory')
    f.inventory:AddItem(f.glass);__nativeWindow("hammer")
    -- Native hammer is the already carried construction-receiver inventory item.
    assert(f.inventory:getFirstTypeRecurse('Base.Hammer'),'actual carried native hammer')
    SAOJavaBridge.privateCarriedItems=function(_,body)return body==f.body and f.inventory:getItems() or ArrayList.new()end
    SAOJavaBridge.worldShelterPlacementSquare=function(_,body,key,revision)return body==f.body and __nativeShelter('scenePlacement',key,revision) and f.nativeSquare or nil end
    SAOJavaBridge.worldShelterWindowFrame=function(_,body,key,revision)return body==f.body and __windowWrap(__nativeWindow('windowFrame',key,revision)) or nil end
    SAOJavaBridge.worldShelterGlazed=function(_,body,frame,object,spriteName,north)return body==f.body and __nativeWindow('glazed',frame,object,{spriteName,north})end
    assert(SAO.Perception.observeShelterSites(f.id,f.body))
    local offers=R.windowGlazingOptions(f.id,f.body)
    for _,offer in ipairs(offers)do if offer.site.x==10 and offer.site.y==20 and offer.site.face==face then f.offer=offer end end
    assert(f.offer and f.offer.item,'native acquired frame and carried glass offer')
    p,s=P.planShelterConstruction(f.id,{windowGlazing={f.offer},recoveryKind="sleep",fatigue=.65,options={},sites=SAO.Perception.shelterSites(f.id,f.body),materialSources={},atHours=__hours})
    f.purpose,f.step=p,s;print('WINDOW_PLAN '..tostring(s and s.productionKind)..' admit='..tostring(p and p.admission)..' origin='..tostring(p and p.shelterConstruction and p.shelterConstruction.origin.originX)..','..tostring(p and p.shelterConstruction and p.shelterConstruction.origin.originY)..' siteorigin='..tostring(f.offer.site.originX)..','..tostring(f.offer.site.originY)..' purpose='..tostring(p and p.status));assert(s and s.productionKind=='glaze-shelter-window')
    return f
end
local function begin(f)
    local a=ISMoveablesAction:new(f.body,f.nativeSquare,'place',f.glass:getWorldSprite(),nil,f.orientation,f.glass,nil)
    print('WINDOW_NATIVE_VALID',a:isValid(),a.moveProps.facing,a.moveProps:canPlaceMoveable(f.body,f.nativeSquare,f.glass),a.moveProps:findInInventory(f.body,f.glass:getWorldSprite())==f.glass,f.nativeSquare:has('WindowN'),f.nativeSquare:has('WindowW'))
    return R.begin(f.id,f.body,f.step,{purposeId=f.purpose.id,purposeStepId=f.step.id})
end
local function drain(f)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body);local n=0
    while q.current do
        n=n+1;assert(n<8,'window queue bound');local a=q.current
        a.setActionSound=function()end;a:start();a.action.nativeFinished=true;local result=a:perform();print('WINDOW_ACTION '..a.Type..' performed='..tostring(result))
        if a.Type=='ISOpenCloseWindow' or a.Type=='ISMoveablesAction' then
            local completed=a:complete();print('WINDOW_NATIVE_COMPLETE '..tostring(completed))
            if a.Type=='ISOpenCloseWindow' and completed and f.pendingToggle~=nil then
                -- Controlled animation completion preserves the real action request and native toggle.
                __nativeWindow('toggle',f.nativeSquare,f.orientation=='N');f.pendingToggle=nil
            end
        end
        if q.current==a then break end
    end
    R.tick(f.id,f.body);local rows=f.rec.resourceProductionOutcomes;return rows[#rows]
end
function __runWindowInstall()
    for grade=1,2 do for _,face in ipairs({'N','W'})do
        local f=prepare(grade,face);local prefix='grade'..grade..'_'..face..'_'
        check(prefix..'native_item_and_orientation',instanceof(f.glass,'Moveable') and f.glass:getScriptItem()~=nil and f.glass:getFullType()==(grade==1 and 'Base.Mov_WindowWooden' or 'Base.Mov_WindowWhite') and f.offer.item.placedSprite==(grade==1 and (face=='N' and 'fixtures_windows_01_1' or 'fixtures_windows_01_0') or (face=='N' and 'fixtures_windows_01_25' or 'fixtures_windows_01_24')))
        local admitted=begin(f);check(prefix..'actual_private_purpose_admission',admitted and f.rec.resourceProductionWork.purposeId==f.purpose.id)
        if admitted then
            local row=drain(f);f.window=f.nativeSquare:getWindow(face=='N' and GridSquareEdgeFacingDirection.NORTH_SOUTH or GridSquareEdgeFacingDirection.EAST_WEST)
            print('WINDOW_EFFECT',row.status,row.kind,row.detail,row.itemConsumed,row.frameRetained,row.windowCreated,row.nativeCompleted,f.inventory:contains(f.glass),f.window~=nil)
            print('WINDOW_FEEDBACK',row.purposeDelivered,row.experienceDelivered,#f.rec.cognition.experiences,SAO.Cognition.windowInstallationOutcome(f.id,row),f.purpose.admission,f.purpose.status)
            print('WINDOW_CANONICAL',row.id,R.outcome(f.id,row.id),R==SAO.ResourceProduction,SAO.Identity.get(f.id)==f.rec)
            check(prefix..'native_exact_payment_and_glazing',row and row.status=='completed' and row.itemConsumed and row.frameRetained and row.windowCreated and row.nativeCompleted and f.window~=nil and not f.inventory:contains(f.glass) and f.frame:getObjectIndex()>=0 and not f.window:isSmashed() and not f.window:isLocked())
            check(prefix..'independent_feedback_and_unfinished_recovery',row.purposeDelivered and row.experienceDelivered and #f.rec.cognition.experiences==2 and not f.rec.recoveryExperiences and f.purpose.status~='completed')
            local count=#f.rec.cognition.experiences;R.reconcileSaved(f.id,f.body);R.reconcileSaved(f.id,f.body)
            check(prefix..'feedback_replay_once',#f.rec.cognition.experiences==count)
            if row.status=='completed' then __windowUse(f,prefix) end
        end
    end end
end
__windowPrepare=prepare;__windowBegin=begin;__windowDrain=drain;__windowCheck=check

function __windowUse(f,prefix)
    local face=f.orientation
    SAOJavaBridge.worldShelterWindow=function(_,body,key,revision)return body==f.body and __windowWrap(__nativeWindow('windowLookup',key,revision)) or nil end
    SAOJavaBridge.worldShelterBeginPassage=function(_,body,target,key,revision,inward)return body==f.body and target==f.window and __nativeWindow('passageBegin',target,key,{revision,inward}) or nil end
    SAOJavaBridge.worldShelterPassage=function(_,body,token)return body==f.body and __nativeShelter('scenePassageReceipt',token)end
    SAOJavaBridge.worldShelterForgetPassage=function(_,body,token)return body==f.body and __nativeShelter('sceneForgetPassage',token)end
    function f.body:openWindow(object)assert(object==f.window);__nativeWindow('requestToggle',object,true);f.pendingToggle=true end
    function f.body:closeWindow(object)assert(object==f.window);__nativeWindow('requestToggle',object,false);f.pendingToggle=false end
    SAO.Locomotion.tick=function(id)
        local job=SAO.Locomotion.jobs[id];local targetX,targetY=math.floor(job.goal.x),math.floor(job.goal.y)
        local edge=face=='N' and targetX==10 and (targetY==19 or targetY==20) or face=='W' and targetY==20 and (targetX==9 or targetX==10)
        local already=(f.body:getX()-job.goal.x)^2+(f.body:getY()-job.goal.y)^2<=.35^2
        local arrived=already or edge and __nativeWindow('windowPass',f.window,targetX==10 and targetY==20) or not edge and __nativeShelter('sceneMove',job.goal.x..','..job.goal.y..','..job.goal.z)
        local position=__nativeShelter('scenePosition');f.body.x,f.body.y,f.body.z=position.x,position.y,position.z
        f.body.here=f.cell:getGridSquare(math.floor(position.x),math.floor(position.y),position.z) or __shelterSquare(f,math.floor(position.x),math.floor(position.y))
        if arrived then job.done,job.result=true,'arrived' end
    end
    SAOJavaBridge.recoveryPlaces=function(_,body)return body==f.body and __nativeShelter('sceneRecoveryPlaces') or nil end
    SAOJavaBridge.worldShelterRecoveryValid=function(_,body,key,revision,x,y,z,reached)return body==f.body and __nativeShelter('sceneRecoveryValid',x..','..y..','..z,reached)or false end
    f.agent.state='IDLE';local admitted=Ctl.offerRecovery(f.id,f.agent,f.body,300,N.read(f.body),'sleep');print('WINDOW_USE_ADMISSION',admitted,f.agent.state,f.rec.resourceProductionWork and f.rec.resourceProductionWork.kind,f.purpose.admission,f.purpose.steps[f.purpose.cursor] and f.purpose.steps[f.purpose.cursor].productionKind)
    check(prefix..'ordinary_window_use_keeps_original_purpose',admitted and f.rec.resourceProductionWork and f.rec.resourceProductionWork.kind=='use-shelter' and f.rec.resourceProductionWork.purposeId==f.purpose.id and not f.rec.recoveryExperiences)
    for n=1,12 do if not f.rec.resourceProductionWork then break end;drain(f);print('WINDOW_USE_STAGE',f.rec.resourceProductionWork and f.rec.resourceProductionWork.stage)end
    local rows=f.rec.resourceProductionOutcomes;local used=rows[#rows]
    print('WINDOW_USE_RESULT',used.status,used.detail,used.opened,used.crossedOut,used.crossedIn,f.window:IsOpen())
    check(prefix..'native_window_open_cross_close',used.kind=='use-shelter' and used.status=='completed' and used.opened and used.crossedOut and used.crossedIn and used.closedDoor and used.enclosureConfirmed and __nativeShelter('scenePassages')==2 and not f.window:IsOpen())
    if used.kind~='use-shelter' or used.status~='completed' then return end
    f.agent.state='IDLE';admitted=Ctl.offerRecovery(f.id,f.agent,f.body,400,N.read(f.body),'sleep')
    if admitted and f.agent.recoveryRoute then SAO.Locomotion.tick(f.id);__shelterControllerTick(401);Ctl.finishRecoveryPlaceMovement(f.id,f.agent,f.body)end
    check(prefix..'ordinary_recovery_admission_is_separate',admitted and f.purpose.admission and f.purpose.admission.owner=='SAONeeds' and not f.rec.recoveryExperiences)
    local preparing=N.pollRecovery(f.id,f.body);local before=N.read(f.body).fatigue;local measured=preparing=='running' and __nativeShelter('sceneSleepTicks');__hours=__hours+.1
    local recovered=N.pollRecovery(f.id,f.body)
    check(prefix..'actual_native_sleep_finishes_original_concern',measured and recovered=='completed' and f.purpose.status=='completed' and #f.rec.recoveryExperiences==1 and f.rec.recoveryExperiences[1].beforeValue==before)
    check(prefix..'install_use_and_recovery_independent_feedback',#f.rec.cognition.experiences==4 and f.rec.cognition.experiences[2].kind=='window-installation' and f.rec.cognition.experiences[3].kind=='shelter-use' and f.rec.cognition.experiences[4].kind=='recovery-outcome' and f.rec.cognition.models.ordinary.revision==4 and f.rec.cognition.models.associative.revision==4)
end

function __runWindowGuards()
    local f=prepare(1,'N','window-standing');assert(begin(f));local a=ISTimedActionQueue.getTimedActionQueue(f.body).current;f.rec.permissionDenied=true
    drain(f);local rows=f.rec.resourceProductionOutcomes;local row=rows[#rows]
    check('current_standing_blocks_native_glazing_effect',f.inventory:contains(f.glass) and f.nativeSquare:getWindow('NORTH_SOUTH')==nil and row.status~='completed')
    f=prepare(1,'N','window-item-identity');assert(begin(f));f.step.itemId='foreign-item';a=ISTimedActionQueue.getTimedActionQueue(f.body).current
    check('foreign_step_item_identity_refuses_current_action',a:isValid()==false and f.inventory:contains(f.glass) and f.nativeSquare:getWindow('NORTH_SOUTH')==nil)
    f.step.itemId=tostring(f.glass:getID());R.interrupt(f.id,f.body,'identity-test-ended')
    f=prepare(1,'N','window-generation');assert(begin(f));f.body:getModData().SAOExternalToken='foreign-generation';a=ISTimedActionQueue.getTimedActionQueue(f.body).current
    check('foreign_generation_refuses_current_action',a:isValid()==false and f.inventory:contains(f.glass));f.body:getModData().SAOExternalToken=f.rec.bodyOwnerToken;R.interrupt(f.id,f.body,'generation-test-ended')
    f=prepare(1,'N','window-no-payment');assert(begin(f));local remove=f.inventory.Remove;f.inventory.Remove=function()end;row=drain(f);f.inventory.Remove=remove
    check('unpaid_native_window_cannot_earn_installation',row.status=='failed' and row.windowCreated and not row.itemConsumed and f.inventory:contains(f.glass) and not row.nativeCredit)
    f=prepare(1,'N','window-no-effect');assert(begin(f));local insert=f.nativeSquare.AddSpecialObject;f.nativeSquare.AddSpecialObject=function()end;row=drain(f);f.nativeSquare.AddSpecialObject=insert
    check('absent_native_window_cannot_earn_installation',row.status=='failed' and row.itemConsumed and not row.windowCreated and not row.nativeCredit and f.nativeSquare:getWindow('NORTH_SOUTH')==nil)
    f=prepare(1,'N','window-save');assert(begin(f));local q=ISTimedActionQueue.getTimedActionQueue(f.body);a=q.current;a.setActionSound=function()end;a:start();local saved=__nativeRoundtrip(f.rec)
    __records[f.id]=saved;f.rec=saved;f.agent.rec=saved;__reloadProduction();R=SAO.ResourceProduction
    local reconciled=R.reconcileSaved(f.id,f.body);row=saved.resourceProductionOutcomes[#saved.resourceProductionOutcomes]
    check('saved_exact_queue_retires_without_native_credit',not q.current and #q.queue==0 and not saved.resourceProductionWork and row.kind=='glaze-shelter-window' and row.status=='interrupted' and not row.nativeCredit and f.inventory:contains(f.glass) and f.nativeSquare:getWindow('NORTH_SOUTH')==nil)
    local count=#saved.cognition.experiences;R.reconcileSaved(f.id,f.body);R.reconcileSaved(f.id,f.body)
    check('saved_interruption_feedback_replays_once',#saved.cognition.experiences==count and a:complete()==false)
    f=prepare(1,'N','window-foreign-successor');assert(begin(f));q=ISTimedActionQueue.getTimedActionQueue(f.body);local successor={character=f.body,Type='foreign-successor',isValidStart=function()return true end,begin=function()end};q.queue={successor};q.current=successor;R.interrupt(f.id,f.body,'successor-test')
    check('foreign_successor_queue_survives_window_retirement',q.current==successor and q.queue[1]==successor and f.inventory:contains(f.glass))
    f=prepare(1,'N','window-null-generation');f.rec.bodyOwnerToken=nil;f.body:getModData().SAOExternalToken=nil
    local admitted=begin(f);row=admitted and drain(f)
    check('ordinary_nullable_generation_has_authenticated_window_completion',admitted and row.status=='completed' and row.bodyToken==nil and row.purposeDelivered and row.experienceDelivered)
end

function __runWindowChooser()
    for _,face in ipairs({'N','W'})do
        local f=prepare(2,face,'window-chooser-'..face);assert(begin(f));local row=drain(f)
        assert(row.status=='completed');f.window=f.nativeSquare:getWindow(face=='N' and 'NORTH_SOUTH' or 'EAST_WEST')
        check('chooser_'..face..'_real_hoppable_frame_retained',__windowWrap(__nativeWindow('nativeHoppable',f.window))==f.frame)
        __nativeWindow('chooserSetup',f.window,false);local verdict=__nativeWindow('chooserTick')
        print('WINDOW_CHOOSER_CLOSED',face,verdict)
        check('chooser_'..face..'_closed_glazing_chooses_window_opening',verdict=='Transition:STARTED_WINDOW_OPEN' and __nativeWindow('chooserAperture',f.window) and not __nativeWindow('chooserFenceEvent'))
        verdict=__nativeWindow('chooserTick');print('WINDOW_CHOOSER_CLOSED_REPEAT',face,verdict)
        check('chooser_'..face..'_closed_glazing_refuses_unpermitted_breaking',verdict=='FailedObstacle:FAILED_WINDOW_DECLINED' and not f.window:isSmashed() and not __nativeWindow('chooserFenceEvent'))
        __nativeWindow('chooserSetup',f.window,true);verdict=__nativeWindow('chooserTick');print('WINDOW_CHOOSER_OPEN',face,verdict)
        check('chooser_'..face..'_open_glazing_chooses_native_window_climb',verdict=='Transition:STARTED_WINDOW_CLIMB' and __nativeWindow('chooserAperture',f.window) and __nativeWindow('chooserWindowEvent') and not __nativeWindow('chooserFenceEvent'))
        assert(__nativeWindow('windowBarricade',f.window));__nativeWindow('chooserSetup',f.window,true);verdict=__nativeWindow('chooserTick');print('WINDOW_CHOOSER_BARRICADE',face,verdict)
        check('chooser_'..face..'_barricaded_glazing_blocks_native_route',verdict=='FailedObstacle:FAILED_BARRICADED_WINDOW' and not __nativeWindow('chooserWindowEvent') and not __nativeWindow('chooserFenceEvent'))
    end
end

local correctionStudy=SAO.Study
local correctionContext=SAO.Controller.resourceContext
local function correctionBook(f,fullType)
    local b=__boardingItem(fullType:sub(6),__recipeNative('new-item',fullType),f.inventory);b.nativeLiterature=true
    function b:getNumberOfPages()return __recipeNative('item',self.id,'pages')end
    function b:getSkillTrained()return nil end;function b:getReadType()return nil end;function b:canBeWrite()return false end;function b:hasTag()return false end
    function b:getLearnedRecipes()return {contains=function(_,name)return __recipeNative('item',b.id,'recipe',name)end,isEmpty=function()return false end}end
    function b:hasModData()return false end;function b:getModData()return {}end
    function b:getAlreadyReadPages()return self.pages or 0 end;function b:setAlreadyReadPages(value)self.pages=value end;function b:getUnhappyChange()return 0 end
    function b:getFluidContainer()return nil end;function b:getFluidContainerFromSelfOrWorldItem()return nil end
    function f.body:hasTrait()return false end;function f.body:tooDarkToRead()return false end
    function f.body:getAlreadyReadPages()return 0 end;function f.body:setAlreadyReadPages()end
    function f.body:getWornItems()return {getItem=function()return nil end}end
    function f.body:isSitting()return false end;function f.body:getVehicle()return nil end;function f.body:getStats()return {get=function()return 0 end}end
    function f.body:setReading(value)self.reading=value end;function f.body:playSound()end;function f.body:isReading()return self.reading==true end
    function f.body:getAlreadyReadBook()return {add=function()end}end
    function f.body:ReadLiterature(value)__recipeNative('read',value.id)end
    function f.body:learnRecipe()error('fabricated knowledge unavailable')end;function f.body:getOnlineID()return 0 end
    f.inventory.items[#f.inventory.items+1]=b;return b
end
function __runWindowNewReading()
    R,P,Ctl,N=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Controller,SAO.Needs
    for _,kind in ipairs({'window','boundary'})do
        SAOJavaBridge.privateCarriedItems=__windowOriginalCarried
        local entity=kind=='window' and 'Base.MetalWindowFrameLvl1' or 'Base.MetalPoleFenceGate'
        local f=(kind=='window' and __enclosureFixture or __enclosureBoundaryFixture)('new-native-reading-'..kind,entity,'N')
        __shelterControllerSetup(f);SAO.Study=correctionStudy;SAO.Controller.resourceContext=correctionContext
        __nativeShelter('known',false);local book=correctionBook(f,kind=='window' and 'Base.MetalworkMag1' or 'Base.MetalworkMag3')
        local context=kind=='window' and Ctl.shelterConstructionContext(f.id,f.agent,f.body,{fatigue=.65,hunger=.1,thirst=.1},'sleep') or Ctl.doubleGateContext(f.id,f.agent,f.body)
        local recipe=entity:sub(6);local discovery=context.recipeBooks[recipe]
        check('reading_'..kind..'_ordinary_context_discovers_exact_native_manual',discovery and discovery.itemId==book.id and discovery.itemType==book:getFullType() and SAO.Study.usefulRecipeType(f.body,book:getFullType(),recipe))
        local selected={};for _,option in ipairs(context.options)do if option.entityId==entity then selected[1]=option;break end end;context.options=selected
        local p,s=(kind=='window' and P.planShelterConstruction or P.planDoubleGate)(f.id,context);f.purpose,f.step=p,s
        check('reading_'..kind..'_native_unknown_recipe_selects_guarded_study',p and s and s.owner=='SAO.Study' and s.recipeName==recipe and s.inputItemId==tostring(book.id) and not __recipeNative('known',recipe))
        local admitted=s and s.owner=='SAO.Study' and SAO.Study.beginRecipe(f.id,f.body,book,p.id,s.id,recipe)
        check('reading_'..kind..'_actual_guarded_reading_admits_same_purpose',admitted and f.rec.studyWork.purposeId==p.id and not __recipeNative('known',recipe))
        if admitted then
            local a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start();a.action.jobDelta=1;a:update();a.action.nativeFinished=true;a:complete();a:perform()
            local row=SAO.Study.recipeOutcome(f.id,f.rec.studyWork.id)
            check('reading_'..kind..'_native_readliterature_teaches_and_retires_exact_claim',row and row.status=='completed' and row.purposeId==p.id and row.recipeName==recipe and row.nativeStarted and row.nativeCompleted and row.recipeKnown and __recipeNative('known',recipe) and __recipeNative('reads')==1 and not p.admission)
        else check('reading_'..kind..'_native_readliterature_teaches_and_retires_exact_claim',false) end
    end
end
function __runWindowCorrection()__runWindowChooser();__runWindowNewReading();if __runWindowToolAcquisition then __runWindowToolAcquisition()end end

function __runWindowToolAcquisition()
    local f=prepare(1,'N','window-native-tool-acquisition');SAO.Study=correctionStudy
    local originalWindowId=f.glass:getID();local purposeId=f.purpose.id
    f.material=__windowWrap(__nativeWindow('withdrawHammer'));f.source=__windowWrap(__nativeWindow('hammerSource'))
    local materialId=f.material:getID();f.sourceId='C:window-placing-tool:0'
    f.place={id='window-placing-tool-place',sourceId=f.sourceId,cx=10,cy=20,z=0,minX=10,maxX=11,minY=20,maxY=21}
    function f.snapshot()
        local present=f.source:contains(f.material)
        return 'H|protocol=SAOWS1|status=OBSERVED|mode=loaded|cx=1|cy=2|sources=1\nS|id='..f.sourceId..'|fp=exact-window-tool-container|rev='..(present and 'tool-before' or 'tool-after')..'|kind=container|x=10|y=20|z=0|building=-1|explored=1|state='..(present and 'available' or 'spent')..'|access=unknown|container=counter'
            ..(present and '|q:hammer=1|q:tools=1\nI|source='..f.sourceId..'|id='..materialId..'|type=Base.Hammer|uses=1|amount=0|fluid=|poison=0|rotten=0|cats=hammer,tools' or '')..'\nE'
    end
    local bridge=SAOJavaBridge
    bridge.observeWorldChunk=function()return f.snapshot()end
    bridge.worldSourceActionTarget=function(_,body,sourceId,fp,revision,itemId,itemType)
        return body==f.body and sourceId==f.sourceId and fp=='exact-window-tool-container' and revision=='tool-before' and tostring(itemId)==tostring(materialId) and itemType=='Base.Hammer' and f.source:contains(f.material) and 'READY:10:20:0:10:20:0' or 'ITEM_MISSING'
    end
    bridge.bindWorldSourceAction=function()return 'BOUND:10:20:0'end
    bridge.worldSourceActionItem=function()return f.material end;bridge.worldSourceActionContainer=function()return f.source end;bridge.worldSourceActionPermissionContainer=function()return f.source end
    bridge.containerAccessibleNow=function()return true end;bridge.worldTransferPosition=function()return 'AT:10:20:0'end
    bridge.carriedWorldSourceItem=function(_,body,itemId,itemType)return body==f.body and tostring(itemId)==tostring(materialId) and itemType=='Base.Hammer' and f.inventory:contains(f.material) and f.material or nil end
    bridge.carriedWorldTransferItem=function()return f.inventory:contains(f.material) and 'T|id='..materialId..'|type=Base.Hammer|uses=1|amount=0|fluid=|poison=0|rotten=0|cats=hammer,tools' or nil end
    bridge.clearWorldSourceAction=function()end;SAO.Standing.provisioningContextAt=function()return 'unheld',nil end
    assert(SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(f.snapshot())));assert(SAO.Perception.learnInspectedSource(f.id,f.place,f.sourceId,__hours,'native-container-inspection'))
    SAO.Controller.resourceContext=correctionContext
    local context=Ctl.shelterConstructionContext(f.id,f.agent,f.body,{fatigue=.65,hunger=.1,thirst=.1},'sleep');local offer
    for _,candidate in ipairs(context.windowGlazing)do if candidate.site.key==f.offer.site.key then offer=candidate end end
    check('ordinary_context_retains_exact_window_when_native_hammer_missing',offer and offer.item and offer.item.itemId==tostring(originalWindowId) and offer.item.placeToolAvailable==false and offer.item.placingSkillAvailable and f.inventory:contains(f.glass))
    local source;for _,row in ipairs(context.materialSources)do if row.category=='hammer' and row.itemId==materialId and row.itemType=='Base.Hammer' then source=row end end
    check('ordinary_context_discovers_exact_private_native_placing_tool',source and source.sourceId==f.sourceId and not f.inventory:contains(f.material))
    local p,s=P.planShelterConstruction(f.id,context);f.purpose,f.step=p,s
    check('ordinary_planner_acquires_hammer_under_original_window_purpose',p and p.id==purposeId and s and s.owner=='SAO.SourceUse' and s.verb=='acquire' and s.category=='hammer' and s.itemId==materialId and s.itemType=='Base.Hammer' and f.inventory:contains(f.glass))
    if not s or s.owner~='SAO.SourceUse' then return end
    f.agent.state='IDLE';local started=Ctl.tryShelterConstruction(f.id,f.agent,f.body,100,{fatigue=.65,hunger=.1,thirst=.1},'sleep');local reservation=SAO.WorldSources.pendingActionFor(f.id)
    check('ordinary_controller_admits_native_placing_tool_to_sourceuse',started and f.agent.state=='SOURCEWARD' and reservation and reservation.purposeId==purposeId and reservation.itemId==materialId and reservation.itemType=='Base.Hammer' and reservation.quantityUnit=='item')
    if not reservation then return end
    SAO.Locomotion.tick=function(id)local job=SAO.Locomotion.jobs[id];if (f.body:getX()-job.goal.x)^2+(f.body:getY()-job.goal.y)^2<=.35^2 then job.done,job.result=true,'arrived' end end
    SAO.Locomotion.tick(f.id);local ready=SAO.SourceUse.onMovementDone(f.id,f.body,'arrived');print('WINDOW_TOOL_MOVEMENT',ready)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body);local a=q.current
    if a then a.getNotFullFloorSquare=function()return nil end;a.playTransferCompleteSound=function()end;a:start();a.action.nativeFinished=true;a:perform()end
    local status=SAO.SourceUse.tick(f.id,f.body);local receipt=SAO.WorldSources.actionOutcome(reservation.id,f.id)
    check('installed_native_transfer_acquires_exact_hammer_and_keeps_window',status=='completed' and receipt and receipt.observedQuantity==1 and receipt.quantityUnit=='item' and receipt.measurement=='native-item-transfer' and f.inventory:contains(f.material) and not f.source:contains(f.material) and f.inventory:contains(f.glass) and f.glass:getID()==originalWindowId)
    if not receipt then return end
    local consumed=P.consumeSourceResult(receipt);print('WINDOW_TOOL_CONSUMER',consumed,p.status,p.cursor,#p.steps,p.admission);check('canonical_tool_acquisition_retires_only_original_claim',consumed and not p.admission and p.id==purposeId and p.status~='completed')
    f.agent.state='IDLE';started=Ctl.tryShelterConstruction(f.id,f.agent,f.body,101,{fatigue=.65,hunger=.1,thirst=.1},'sleep')
    local same,step=P.shelterPurpose(f.id);print('WINDOW_TOOL_CONTINUE',started,f.agent.state,same and same.id,step and step.owner,step and step.productionKind,f.rec.worldSourceReservation,f.rec.resourceProductionWork and f.rec.resourceProductionWork.stage,N.busy(f.body),f.body:getX(),f.body:getY())
    check('acquired_placing_tool_continues_exact_original_window_installation',started and f.rec.resourceProductionWork and f.rec.resourceProductionWork.kind=='glaze-shelter-window' and f.rec.resourceProductionWork.purposeId==purposeId and f.rec.resourceProductionWork.itemId==tostring(originalWindowId))
    local row=started and drain(f)
    check('native_glazing_uses_acquired_hammer_and_original_carried_window',row and row.kind=='glaze-shelter-window' and row.status=='completed' and row.purposeId==purposeId and row.itemId==tostring(originalWindowId) and row.itemConsumed and row.windowCreated and f.inventory:contains(f.material))
end
