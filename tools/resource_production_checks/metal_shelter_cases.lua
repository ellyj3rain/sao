-- Current production over installed recipes, exact native payment and actual world parts.
-- Actor dispatch/animation are ports shared with D3.9; native scene shell owns motion/regions/recovery.
local R,P,Ctl,N=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Controller,SAO.Needs
local resourceContext=Ctl.resourceContext
SAO.Locomotion.cancel=function(id)local job=SAO.Locomotion.jobs[id];if job then __nativeShelter('sceneCancelMove');SAO.Locomotion.jobs[id]=nil end;return true end
local nativeValid=ISBuildIsoEntity.isValid
function ISBuildIsoEntity:isValid(square)local result=nativeValid(self,square);print('METAL_VALID '..tostring(result)..' prior='..tostring(self.previousStageObject));return result end
local families={'Base.MetalWallFrame','Base.MetalWallLvl1','Base.MetalWallLvl2','Base.MetalDoorFrameLvl1','Base.MetalDoorFrameLvl2','Base.MetalDoorLvl1','Base.MetalDoorLvl2'}
local function check(name,value)print('METAL '..name..'='..tostring(value==true)) end
local function adaptMaterials(f)
    for _,item in ipairs(f.materials) do function item:getCurrentUses()return __nativeShelter('uses',self:getID()) end end
    function f.body:getPerkLevel()return __nativeShelter('skillValue') end
    function f.body:isRecipeActuallyKnown(name)return __nativeShelter('actualKnown',name) end
    function f.body:isRecipeKnown(name)return true end -- installed visibility-permissive convenience query
end
local function fixture(id,entity,face,prior)
    __nativeShelter('known',true);__nativeShelter('skill',entity:find('Lvl1',1,true) and 3 or 5)
    local f=__shelterFixture(id,face,entity);assert(__nativeShelter('scene',id,face));adaptMaterials(f)
    f.siteSquare.objects={};f.previous=nil;f.initialStage=nil
    if entity:find('Wall',1,true) then assert(__nativeShelter('wallScene')) end
    prior=prior or (entity:find('WallLvl',1,true) and 'Base.MetalWallFrame' or entity:find('DoorLvl',1,true) and 'Base.MetalDoorFrameLvl1')
    if prior then
        assert(__nativeShelter('seed',prior))
        local object=IsoThumpable.new(f.cell,f.siteSquare,__nativeShelter('otherSprite',prior..'|'..face),face=='N',{})
        object.entityId,object.nativeFactory,object.health=prior,true,500
        f.siteSquare.objects[1]=object;f.previous,f.initialStage=object,object
    end
    SAOJavaBridge.worldShelterSites=function(_,body)return body==f.body and __nativeShelter('sceneSites','10,20,0') or {} end
    SAOJavaBridge.worldShelterPlacementSquare=function(_,body,key,revision)
        return body==f.body and not f.placementRefused and __nativeShelter('scenePlacement',key,revision) and f.siteSquare or nil
    end
    SAOJavaBridge.worldShelterPreviousStage=function(_,body,key,revision)
        return body==f.body and __nativeShelter('scenePrevious',key,revision)==(f.previous and f.previous.entityId) and f.previous or nil
    end
    SAOJavaBridge.worldShelterCreated=function(_,body,object,old,target,x,y,z,orientation)
        return body==f.body and object==f.created and object.entityId==target and __nativeShelter('createdMeasured') and not f.createdRefused
    end
    SAOJavaBridge.worldShelterDoor=function(_,body,key,revision)
        return body==f.body and __nativeShelter('sceneDoorLookup',key,revision) and f.created and f.created:isDoor() and f.created or nil
    end
    SAOJavaBridge.worldShelterCover=function(_,body,x,y,z)return body==f.body and __nativeShelter('sceneCover',x..','..y..','..z) or nil end
    for _,site in ipairs(__nativeShelter('sceneSites','10,20,0')) do print('NATIVE_METAL_SITE '..site.key..' '..site.mode..' '..site.previousEntity) end
    assert(SAO.Perception.observeShelterSites(id,f.body))
    return f
end
local function option(f)
    local options=R.shelterOptions(f.id,f.body,f.purpose and f.purpose.shelterConstruction)
    print('METAL_OPTIONS '..f.entityId..' '..f.orientation..' '..#options)
    for _,site in ipairs(SAO.Perception.shelterSites(f.id,f.body)) do print('METAL_SITE '..site.key..' '..site.mode..' '..site.previousEntity..' '..site.face) end
    for _,row in ipairs(options) do print('METAL_OPTION '..row.entityId..' '..row.site.key..' inputs='..#row.inputs);if row.entityId==f.entityId and row.site.x==10 and row.site.y==20 and row.site.face==f.orientation then return row end end
end
local function plan(f,context)
    local offered=option(f);assert(offered,'native metal option missing '..f.entityId..' '..f.orientation)
    context=context or {};context.options={offered};context.recoveryKind='sleep';context.fatigue=.65;context.atHours=__hours
    context.position={x=f.body:getX(),y=f.body:getY(),z=f.body:getZ()};context.sites=SAO.Perception.shelterSites(f.id,f.body);context.materialSources=context.materialSources or {}
    local p,s=P.planShelterConstruction(f.id,context);f.purpose,f.step=p,s;return p,s
end
function __runMetalFamilies()
    for index,entity in ipairs(families) do for _,face in ipairs({'N','W'}) do
        local f=fixture('metal-family-'..index..face,entity,face);local p,s=plan(f);local prefix='family'..index..'_'..face..'_'
        local begun=s and R.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id})
        print('METAL_BEGIN_STAGE '..tostring(f.rec.resourceProductionWork and f.rec.resourceProductionWork.stage))
        check(prefix..'native_admission',begun and f.rec.resourceProductionWork and f.rec.resourceProductionWork.entityId==entity)
        if begun then
            local work=__nativeRoundtrip(f.rec.resourceProductionWork)
            check(prefix..'saved_exact_use_inputs',#work.inputs==#f.materials and work.entityId==entity and work.toolCategory=='welding-torch')
            local row=__shelterFinish(f)
            check(prefix..'native_payment_and_grade',row and row.status=='completed' and row.entityId==entity and row.inputsConsumed
                and row.nativeCompleted and __nativeShelter('createdMeasured') and __nativeShelter('createdNorth')==(face=='N')
                and row.usesBefore and row.usesAfter and f.nativePayments==1)
            check(prefix..'native_stage_index',not f.initialStage or __nativeShelter('stageReplaced') or entity:find('DoorLvl',1,true)~=nil)
            check(prefix..'independent_private_build_feedback',row and row.experienceDelivered and row.purposeDelivered and f.rec.cognition
                and #f.rec.cognition.experiences==1 and f.rec.cognition.experiences[1].kind=='shelter-construction'
                and p.status~='completed' and not f.rec.recoveryExperiences)
        end
    end end
end
local function materials(f,entity,pooled)
    __nativeShelter('reset',entity);if pooled then __nativeShelter('split') end;__nativeShelter('face',f.orientation);f.entityId=entity
    f.inventory.items={};f.materials={};f.materialById={}
    for itemId=100,99+__nativeShelter('count') do
        local item=__boardingItem(__nativeShelter('type',itemId):sub(6),itemId,f.inventory)
        item.condition=__nativeShelter('condition',itemId)
        function item:getFluidContainer()return nil end;function item:getFluidContainerFromSelfOrWorldItem()return nil end
        function item:hasTag()return false end
        f.inventory.items[#f.inventory.items+1]=item;f.materials[#f.materials+1]=item;f.materialById[itemId]=item
    end
    f.tool=f.materials[1];f.hammer=f.tool;adaptMaterials(f)
end
local function chain(grade,face,wall,refusal)
    local function chainCheck(name,value)check((refusal and 'refusal_'..refusal..'_chain' or wall and 'wallchain' or 'chain')..grade..'_'..face..'_'..name,value) end

    local Ctl,R,P,N=SAO.Controller,SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Needs
    local f=fixture((wall and 'ordinary-metal-wall-' or 'ordinary-metal-')..grade..face,wall and 'Base.MetalWallFrame' or 'Base.MetalDoorFrameLvl'..grade,face);__nativeShelter('skill',grade==1 and 3 or 5);local reader=SAO.Study;__shelterControllerSetup(f);SAO.Study=reader
    local admitted=Ctl.offerRecovery(f.id,f.agent,f.body,100,{hunger=.1,thirst=.1,fatigue=.65,endurance=.8},'sleep')
    chainCheck('ordinary_shelter_concern_admits_native_stage',admitted and f.agent.state=='RESOURCE' and f.rec.resourceProductionWork~=nil)
    local purposeId=f.rec.resourceProductionWork and f.rec.resourceProductionWork.purposeId
    local row=__shelterFinish(f)
    chainCheck('native_frame_keeps_original_shelter_concern',row and row.status=='completed'
        and f.rec.proceduralPlanning.purposes[purposeId].status~='completed' and not f.rec.recoveryExperiences)
    materials(f,(wall and 'Base.MetalWallLvl' or 'Base.MetalDoorLvl')..grade);f.agent.state='IDLE'
    admitted=Ctl.offerRecovery(f.id,f.agent,f.body,200,{hunger=.1,thirst=.1,fatigue=.65,endurance=.8},'sleep')
    row=__shelterFinish(f)
    chainCheck('native_leaf_continues_same_concern',admitted and row and row.status=='completed' and row.purposeId==purposeId
        and f.nativePayments==2 and (wall or f.created:isDoor()) and not f.rec.recoveryExperiences)
    local door=f.created
    if wall then
        local sq=f.cell:getGridSquare(11,20,0) or __shelterSquare(f,11,20)
        door=IsoThumpable.new(f.cell,sq,__nativeShelter('otherSprite','Base.WoodenDoorLvl1|N'),true,{})
        door.entityId,door.nativeFactory,door.health='Base.WoodenDoorLvl1',true,500;sq.objects[#sq.objects+1]=door
        SAOJavaBridge.worldShelterDoor=function(_,body,key,revision)return body==f.body and __nativeShelter('sceneDoorLookup',key,revision) and door or nil end
    end
    function door:ToggleDoor(body)
        __nativeShelter('sceneToggle');self.open=__nativeShelter('sceneOpen')
    end
    SAOJavaBridge.worldShelterBeginPassage=function(_,body,target,key,revision,inward)
        return body==f.body and target==door and __nativeShelter('captureDoor',key..'|'..revision,inward) or nil
    end
    SAOJavaBridge.worldShelterPassage=function(_,body,token)
        return body==f.body and __nativeShelter('scenePassageReceipt',token)
    end
    SAOJavaBridge.worldShelterForgetPassage=function(_,body,token)
        return __nativeShelter('sceneForgetPassage',token)
    end
    SAO.Locomotion.tick=function(id)
        local job=SAO.Locomotion.jobs[id]
        local doorway=wall and math.floor(job.goal.x)==11 and (math.floor(job.goal.y)==20 or math.floor(job.goal.y)==19) or not wall and face=='N' and math.floor(job.goal.x)==10 and (math.floor(job.goal.y)==20 or math.floor(job.goal.y)==19) or not wall and face=='W' and math.floor(job.goal.y)==20 and (math.floor(job.goal.x)==10 or math.floor(job.goal.x)==9)
        local already=(f.body:getX()-job.goal.x)^2+(f.body:getY()-job.goal.y)^2<=.35^2
        local arrived=already or doorway and __nativeShelter('doorPass',math.floor(job.goal.y)==20 and math.floor(job.goal.x)==(wall and 11 or 10))
            or __nativeShelter('sceneMove',job.goal.x..','..job.goal.y..','..job.goal.z)
        local position=__nativeShelter('scenePosition')
        f.body.x,f.body.y,f.body.z=position.x,position.y,position.z
        local x,y=math.floor(position.x),math.floor(position.y)
        f.body.here=f.cell:getGridSquare(x,y,position.z) or __shelterSquare(f,x,y)
        if arrived then
            job.done,job.result=true,'arrived'
        end
    end
    SAOJavaBridge.worldShelterCover=function(_,body,x,y,z)
        return body==f.body and __nativeShelter('sceneCover',x..','..y..','..z) or nil
    end
    SAOJavaBridge.recoveryPlaces=function(_,body)
        return body==f.body and __nativeShelter('sceneRecoveryPlaces') or nil
    end
    SAOJavaBridge.worldShelterRecoveryValid=function(_,body,key,revision,x,y,z,reached)
        return body==f.body and __nativeShelter('sceneRecoveryValid',x..','..y..','..z,reached) or false
    end
    if refusal then
        if refusal=='barricade' then assert(__nativeShelter('nativeBarricade'))
        elseif refusal=='obstruction' then assert(__nativeShelter('nativeObstruct'))
        elseif refusal=='lock' then assert(__nativeShelter('sceneToggle'));assert(__nativeShelter('doorPass',false));assert(__nativeShelter('sceneToggle'));assert(__nativeShelter('nativeLock',true))
            local pos=__nativeShelter('scenePosition');f.body.x,f.body.y,f.body.z=pos.x,pos.y,pos.z;f.body.here=f.secondSquare
        end
        local toggled=__nativeShelter('sceneToggle');check('native_'..refusal..'_authority_refuses_'..grade..'_'..face,not toggled and not __nativeShelter('sceneOpen'))
    end
    f.agent.state='IDLE'
    admitted=Ctl.offerRecovery(f.id,f.agent,f.body,300,{hunger=.1,thirst=.1,fatigue=.65,endurance=.8},'sleep')
    if not refusal then chainCheck('construction_only_unlocks_separate_use',admitted and f.rec.resourceProductionWork
        and f.rec.resourceProductionWork.kind=='use-shelter' and not f.rec.recoveryExperiences) end
    for count=1,8 do
        local q=ISTimedActionQueue.getTimedActionQueue(f.body)
        local drained=0
        while q.current do
            drained=drained+1;if drained>5 then print("door drain stalled");break end
            local a=q.current;print('door before '..tostring(a.Type)..' valid '..tostring(a:isValid())..' stage '..tostring(f.rec.resourceProductionWork and f.rec.resourceProductionWork.stage))
            local started=a:start();a.action.nativeFinished=true;print('door guards current='..tostring(q.current==a)..' first='..tostring(q.queue[1]==a)..' index='..tostring(q:indexOf(a))..' started='..tostring(a.action:isStarted())..' ended='..tostring(a.action:finished())..' valid='..tostring(a:isValid())..' actor='..tostring(a.character==f.body)..' registry='..tostring(ISTimedActionQueue.queues[f.body]==q));local performed=a:perform();print('door callbacks '..tostring(started)..' '..tostring(performed))
            if a.Type=='ISOpenCloseDoor' then print('door complete '..tostring(a:complete())) end
        end
        local status=R.tick(f.id,f.body);print('ordinary native use '..tostring(status))
        if not f.rec.resourceProductionWork then break end
    end
    local results=f.rec.resourceProductionOutcomes;local used=results[#results]
    print('use outcome '..tostring(used.status)..' '..tostring(used.detail)..' opened='..tostring(used.opened)..' nativeopen='..tostring(__nativeShelter('sceneOpen')))
    if refusal then
        check('ordinary_'..refusal..'_keeps_original_unfinished_shelter_'..grade..'_'..face,not __nativeShelter('sceneOpen') and (not used or used.kind~='use-shelter' or used.status~='completed') and f.rec.proceduralPlanning.purposes[purposeId].status~='completed' and not f.rec.recoveryExperiences)
        return
    end
    chainCheck('same_body_native_open_cross_close_and_enclosure',used and used.status=='completed' and used.kind=='use-shelter'
        and used.opened and used.crossedOut and used.crossedIn and used.closedDoor and used.enclosureConfirmed
        and __nativeShelter('scenePassages')==2 and not __nativeShelter('sceneOpen') and f.nativePayments==2)
    local purpose=f.rec.proceduralPlanning.purposes[purposeId]
    chainCheck('usable_shelter_promotes_ordinary_recovery_without_relief',purpose.shelterConstruction.usedWorkId==used.id
        and purpose.steps[purpose.cursor].status=='available' and not f.rec.recoveryExperiences)
    chainCheck('native_doorway_circulation_cannot_supply_ground_place',not __nativeShelter('sceneGroundClear','10.5,20.5,0'))
    chainCheck('native_outside_place_cannot_admit_shelter_recovery',not __nativeShelter('sceneRecoveryValid',face=='N' and '10.5,19.5,0' or '9.5,20.5,0',false))
    f.agent.state='IDLE';admitted=Ctl.offerRecovery(f.id,f.agent,f.body,400,N.read(f.body),'sleep')
    print('RECOVERY offered='..tostring(admitted)..' state='..tostring(f.agent.state)..' observation='..tostring(f.rec.recoveryPlaceObservation and f.rec.recoveryPlaceObservation.status))
    local route=f.agent.recoveryRoute
    if admitted and route then
        SAO.Locomotion.tick(f.id);__shelterControllerTick(401);Ctl.finishRecoveryPlaceMovement(f.id,f.agent,f.body)
    end
    chainCheck('original_concern_admits_ordinary_ground_recovery',admitted and purpose.admission and purpose.admission.owner=='SAONeeds')
    local place=f.rec.recoveryIntent and f.rec.recoveryIntent.place
    chainCheck('native_recovery_place_is_safe_interior',place and place.kind=='ground' and place.key~='ground:10:20:0'
        and __nativeShelter('sceneGroundClear',place.x..','..place.y..','..place.z)
        and __nativeShelter('sceneRecoveryValid',place.x..','..place.y..','..place.z,true))
    local preparing=N.pollRecovery(f.id,f.body)
    local before=N.read(f.body).fatigue
    local nativeMeasured=preparing=='running' and __nativeShelter('sceneSleepTicks')
    __hours=__hours+.1
    local actualConsume=P.consumeShelterRecovery
    P.consumeShelterRecovery=function(id,sequence)
        local canonical=f.rec.recoveryExperiences[#f.rec.recoveryExperiences];local key=canonical.sourceId
        canonical.sourceId='ground:wrong:canonical:key'
        local refused=actualConsume(id,sequence)==false and purpose.status~='completed'
        canonical.sourceId=key
        chainCheck('canonical_ground_key_mismatch_cannot_finish',refused)
        P.consumeShelterRecovery=actualConsume
        return actualConsume(id,sequence)
    end
    local recovered=N.pollRecovery(f.id,f.body)
    chainCheck('native_sleep_finishes_original_shelter_concern',nativeMeasured and recovered=='completed'
        and purpose.status=='completed' and f.nativeEntries==1 and #f.rec.recoveryExperiences==1
        and f.rec.recoveryExperiences[1].sourceId==place.key and f.rec.recoveryExperiences[1].beforeValue==before)
    print('FEEDBACK count='..#f.rec.cognition.experiences..' ordinary='..f.rec.cognition.models.ordinary.revision..' associative='..f.rec.cognition.models.associative.revision)
    for _,experience in ipairs(f.rec.cognition.experiences) do print('FEEDBACK kind='..tostring(experience.kind)) end
    chainCheck('construction_use_and_recovery_keep_independent_feedback',#f.rec.cognition.experiences==4
        and f.rec.cognition.experiences[1].kind=='shelter-construction' and f.rec.cognition.experiences[2].kind=='shelter-construction'
        and f.rec.cognition.experiences[3].kind=='shelter-use' and f.rec.cognition.experiences[4].kind=='recovery-outcome'
        and f.rec.cognition.models.ordinary.revision==4 and f.rec.cognition.models.associative.revision==4)
    local count=#f.rec.cognition.experiences
    R.reconcileSaved(f.id,f.body);R.reconcileSaved(f.id,f.body)
    chainCheck('canonical_shelter_feedback_replay_is_once',#f.rec.cognition.experiences==count)
end

function __runMetalChains()for grade=1,2 do for _,face in ipairs({'N','W'}) do chain(grade,face);chain(grade,face,true) end end end

local function book(f,fullType)
    fullType=fullType or 'Base.MetalworkMag1';local b=__boardingItem(fullType:sub(6),__recipeNative('new-item',fullType),f.inventory);b.nativeLiterature=true
    function b:getNumberOfPages()return __recipeNative('item',self.id,'pages') end
    function b:getSkillTrained()return nil end;function b:getReadType()return nil end;function b:canBeWrite()return false end;function b:hasTag()return false end
    function b:getLearnedRecipes()return {contains=function(_,name)return __recipeNative('item',b.id,'recipe',name) end,isEmpty=function()return false end} end
    function b:hasModData()return false end;function b:getModData()return {} end
    function b:getAlreadyReadPages()return self.pages or 0 end;function b:setAlreadyReadPages(value)self.pages=value end;function b:getUnhappyChange()return 0 end
    function b:getFluidContainer()return nil end;function b:getFluidContainerFromSelfOrWorldItem()return nil end
    function f.body:hasTrait()return false end;function f.body:tooDarkToRead()return false end
    function f.body:getAlreadyReadPages()return 0 end;function f.body:setAlreadyReadPages()end
    function f.body:getWornItems()return {getItem=function()return nil end} end
    function f.body:isSitting()return false end;function f.body:getVehicle()return nil end;function f.body:getStats()return {get=function()return 0 end} end
    function f.body:setReading(value)self.reading=value end;function f.body:playSound()end;function f.body:isReading()return self.reading==true end
    function f.body:getAlreadyReadBook()return {add=function()end} end;function f.body:ReadLiterature(value)__recipeNative('read',value.id) end
    function f.body:learnRecipe()error('no fabricated recipe grant') end;function f.body:getOnlineID()return 0 end
    f.inventory.items[#f.inventory.items+1]=b;return b
end
function __runMetalDoorGuards()for _,kind in ipairs({'lock','barricade','obstruction'}) do for _,face in ipairs({'N','W'}) do chain(kind=='lock' and 1 or 2,face,false,kind) end end end
function __runMetalKnowledge()
    SAO.Perception.believedThreatCount=function()return 0 end
    SAO.Needs.bleeding=function()return 0 end;SAO.Needs.cold=function()return 0 end
    SAO.Needs.recoveryPreference=function()return 'sleep',{} end;SAO.Needs.recoveryAlternatives=function()return {{id='sleep'}} end
    local f=fixture('metal-private-knowledge','Base.MetalDoorFrameLvl1','N');__nativeShelter('known',false);local b=book(f)
    SAO.Standing.insideClaim=function()return true end;Ctl.resourceContext=resourceContext
    local context=Ctl.shelterConstructionContext(f.id,f.agent,f.body,{hunger=.1,thirst=.1,fatigue=.65},'sleep')
    for _,o in ipairs(context.options) do print('KNOW_OPTION '..o.entityId..' known='..tostring(o.recipeKnown)..' ready='..tostring(P.collectorReady(o))) end
    local p,s=P.planShelterConstruction(f.id,context);f.purpose,f.step=p,s
    print('METAL_KNOWLEDGE_PLAN '..tostring(p and p.id)..' owner='..tostring(s and s.owner)..' entity='..tostring(s and s.entityId)..' recipe='..tostring(s and s.recipeName)..' book='..tostring(context.recipeBooks.MetalDoorFrameLvl1)..' useful='..tostring(SAO.Study.usefulRecipeType(f.body,b:getFullType(),'MetalDoorFrameLvl1')))
    check('ordinary_shelter_planner_selects_actual_native_recipe_reading',p and s and s.owner=='SAO.Study' and s.recipeName=='MetalDoorFrameLvl1'
        and s.inputItemId==tostring(b.id) and not __recipeNative('known',s.recipeName) and not f.nativePayments)
    if not s or s.owner~='SAO.Study' then return end
    -- A separately maintained gate-reading concern is a legitimate saved
    -- competing purpose, not a current gate-placement or completion claim.
    local gateBook=book(f,'Base.MetalworkMag3')
    local gate=P.maintain(f.id,{key='retained-gate-reading',domain='construction',objective='learn native gate recipe for retained boundary concern',origin='gate-concern',atHours=__hours})
    gate.gateAccess={entityId='Base.DoubleFenceGate',recipeName='DoubleFenceGate'}
    gate.steps={{id='gate-read',owner='SAO.Study',verb='study',operation='learn-recipe',token='recipe:knowledge-acquired',recipeName='DoubleFenceGate',target='DoubleFenceGate',inputItemId=tostring(gateBook.id),inputItemType=gateBook:getFullType(),status='available'},
        {id='gate-build',owner='SAO.ResourceProduction',verb='produce',token='resource:gate-built',target='Base.DoubleFenceGate',status='dependent'}};gate.cursor=1
    local admitted=SAO.Study.beginRecipe(f.id,f.body,b,p.id,s.id,s.recipeName)
    check('actual_unknown_visible_recipe_cannot_build_before_reading',admitted and not f.rec.resourceProductionWork and not __recipeNative('known',s.recipeName))
    if not admitted then check('exact_chosen_shelter_read_leaves_unrelated_available_gate_untouched',false);return end
    local a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start();a.action.jobDelta=.5;a:update()
    local originalClaim=f.rec.studyWork.id;local beforeQueue=ISTimedActionQueue.getTimedActionQueue(f.body);local beforeState=f.rec.studyWork.status
    local recovery=Ctl.offerRecovery(f.id,f.agent,f.body,101,{fatigue=.65,hunger=.1,thirst=.1,endurance=.8},'sleep')
    check('ordinary_controller_recovery_tick_preserves_current_native_shelter_read',not recovery and beforeQueue.current==a and f.rec.studyWork.id==originalClaim and f.rec.studyWork.status==beforeState and f.purpose.admission and f.purpose.admission.correlationId==originalClaim and not __recipeNative('known','MetalDoorFrameLvl1'))
    if beforeQueue.current~=a then return end
    a.action.jobDelta=1;a:update();a.action.nativeFinished=true;a:complete();a:perform()
    local reading=SAO.Study.recipeOutcome(f.id,f.rec.studyWork.id)
    check('actual_native_reading_teaches_same_body_and_advances_retained_shelter',reading and reading.status=='completed' and reading.purposeId==p.id
        and __recipeNative('known','MetalWallFrame') and __recipeNative('known','MetalWallLvl1') and __recipeNative('known','MetalWallLvl2')
        and __recipeNative('known','MetalDoorFrameLvl1') and __recipeNative('known','MetalDoorFrameLvl2') and __recipeNative('reads')==1 and not p.admission)
    check('exact_chosen_shelter_read_leaves_unrelated_available_gate_untouched',reading and reading.purposeId==p.id and gate.steps[1].status=='available' and not gate.admission and not __recipeNative('known','DoubleFenceGate'))
    f.agent.state='IDLE';context=Ctl.shelterConstructionContext(f.id,f.agent,f.body,{hunger=.1,thirst=.1,fatigue=.65},'sleep')
    local same,next=P.planShelterConstruction(f.id,context);local started=next and R.begin(f.id,f.body,next,{purposeId=same.id,purposeStepId=next.id})
    local row=started and __shelterFinish(f)
    check('native_learned_prerequisite_unlocks_exact_same_shelter_construction',same==p and row and row.status=='completed' and row.purposeId==p.id
        and row.entityId=='Base.MetalDoorFrameLvl1' and f.nativePayments==1)
    local gateRead=SAO.Study.beginRecipe(f.id,f.body,gateBook,gate.id,'gate-read','DoubleFenceGate')
    if gateRead then a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start();a.action.jobDelta=1;a:update();a.action.nativeFinished=true;a:complete();a:perform() end
    local gateOutcome=gateRead and SAO.Study.recipeOutcome(f.id,f.rec.studyWork.id)
    check('exact_chosen_gate_reader_remains_compatible_after_shelter_read',gateOutcome and gateOutcome.status=='completed' and gateOutcome.purposeId==gate.id and gate.steps[1].status=='completed' and __recipeNative('known','DoubleFenceGate') and __recipeNative('reads')==2)
end
function __runMetalUrgentReading()
    local f=fixture('urgent-metal-reading','Base.MetalDoorFrameLvl1','N');__nativeShelter('known',false);local b=book(f)
    local p,s=plan(f,{recipeBooks={MetalDoorFrameLvl1={itemId=b.id,itemType=b:getFullType()}}});assert(SAO.Study.beginRecipe(f.id,f.body,b,p.id,s.id,s.recipeName))
    local q=ISTimedActionQueue.getTimedActionQueue(f.body);local a=q.current;a:start();a.action.jobDelta=.5;a:update();f.body.holdCancellation=true
    SAO.Needs.recoveryPreference=function()return 'sleep',{} end;SAO.Needs.recoveryAlternatives=function()return {{id='sleep'}} end
    SAO.Needs.bleeding=function()return 0 end;SAO.Needs.cold=function()return 0 end;SAO.Perception.believedThreatCount=function()return 0 end
    local offered=Ctl.offerRecovery(f.id,f.agent,f.body,101,{fatigue=.9,hunger=.1,thirst=.1,endurance=.8},'sleep')
    check('urgent_need_requests_native_reader_interruption_and_keeps_pending_ack',not offered and q.current==a and f.rec.studyWork and f.rec.studyWork.status=='reading' and f.purpose.admission and not __recipeNative('known','MetalDoorFrameLvl1'))
    f.body.holdCancellation=false;SAO.Study.interrupt(f.id,f.body,'urgent-native-reader-ack');local row=SAO.Study.recipeOutcome(f.id,f.rec.studyWork.id)
    check('urgent_native_reader_ack_retires_without_fabricated_knowledge',row and row.status=='interrupted' and not row.recipeKnown and q.current~=a and not p.admission and __recipeNative('reads')==0)
end
local function metalAcquisitionFixture(id,manual)
    local f=fixture(id,'Base.MetalDoorFrameLvl1','N');f.agent.state='IDLE';if manual then __nativeShelter('known',false) end;f.material=manual and book(f) or f.materialById[101]
    local materialId=manual and 901 or 101;local materialType=manual and 'Base.MetalworkMag1' or 'Base.MetalBar';local category=manual and 'shelter-manual' or 'metal-bar'
    assert(__nativeShelter(manual and 'withdrawManual' or 'withdraw',materialId));f.inventory:Remove(f.material);f.source=__boardingInventory({items={f.material},contains=function(self,item)return self.items[1]==item end,
        Remove=function(self,item)if self.items[1]==item then self.items={};item.container=nil end end},nil);f.material.container=f.source
    f.sourceId='C:gate-material-'..id..':0';f.materialRevision='material-before';f.place={id='source:'..f.sourceId,sourceId=f.sourceId,cx=12,cy=23,z=0,minX=12,minY=23,maxX=13,maxY=24}
    function f.snapshot()
        local present=not f.inventory:contains(f.material);local revision=present and 'material-before' or 'material-after'
        return 'H|protocol=SAOWS1|status=OBSERVED|mode=loaded|cx=1|cy=2|sources=1\nS|id='..f.sourceId..'|fp=exact-metal-container|rev='..revision
            ..'|kind=container|x=12|y=23|z=0|building=-1|explored=1|state='..(present and 'available' or 'spent')..'|access=unknown|container=counter'
            ..(present and '|q:'..category..'=1\nI|source='..f.sourceId..'|id='..materialId..'|type='..materialType..'|uses=1|amount=0|fluid=|poison=0|rotten=0|cats='..category or '')..'\nE'
    end
    local bridge=SAOJavaBridge
    bridge.observeWorldChunk=function()return f.snapshot() end
    bridge.worldSourceActionTarget=function(_,body,sourceId,fp,revision,itemId,itemType)
        return body==f.body and sourceId==f.sourceId and fp=='exact-metal-container' and revision=='material-before' and tostring(itemId)==tostring(materialId) and itemType==materialType and 'READY:12:23:0:12:23:0' or 'ITEM_MISSING' end
    bridge.bindWorldSourceAction=function()return 'BOUND:12:23:0' end
    bridge.worldSourceActionItem=function()return f.material end;bridge.worldSourceActionContainer=function()return f.source end;bridge.worldSourceActionPermissionContainer=function()return f.source end
    bridge.containerAccessibleNow=function()return true end;bridge.worldTransferPosition=function()return 'AT:12:23:0' end
    bridge.carriedWorldSourceItem=function(_,body,itemId,itemType)return body==f.body and tostring(itemId)==tostring(materialId) and itemType==materialType and f.inventory:contains(f.material) and f.material or nil end
    bridge.carriedWorldTransferItem=function()return f.inventory:contains(f.material) and 'T|id='..materialId..'|type='..materialType..'|uses=1|amount=0|fluid=|poison=0|rotten=0|cats='..category or nil end
    bridge.clearWorldSourceAction=function()end;SAO.Standing.provisioningContextAt=function()return 'unheld',nil end
    local nativeTransfer=ISTransferAction.transferItem
    ISTransferAction.transferItem=function(self,body,item,source,destination,square)
        if body==f.body and item==f.material then assert(__nativeShelter(manual and 'reclaimManual' or 'reclaim',materialId)) end
        return nativeTransfer(self,body,item,source,destination,square)
    end
    SAO.Controller.resourceContext=resourceContext;SAO.Standing.insideClaim=function()return true end
    SAO.Locomotion.tick=function(pid)
        local job=SAO.Locomotion.jobs[pid];local arrived=__nativeShelter('sceneMove',job.goal.x..','..job.goal.y..','..job.goal.z)
        local pos=__nativeShelter('scenePosition');f.body.x,f.body.y,f.body.z=pos.x,pos.y,pos.z;f.body.here=f.cell:getGridSquare(math.floor(pos.x),math.floor(pos.y),pos.z) or __shelterSquare(f,math.floor(pos.x),math.floor(pos.y))
        if arrived or (pos.x-job.goal.x)^2+(pos.y-job.goal.y)^2<=.35^2 and pos.z==job.goal.z then job.done,job.result=true,'arrived' end
    end
    assert(SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(f.snapshot())));return f
end

function __runMetalAcquisition()
    local Ctl,P,WS,SU=SAO.Controller,SAO.ProceduralPlanning,SAO.WorldSources,SAO.SourceUse
    local f=metalAcquisitionFixture('ordinary-metal-material')
    Ctl.resourceContext=function(pid,agent,body,needs,category)return {sources=category=='metal-bar' and {{known=true,category=category,sourceId=f.sourceId,revision='material-before',itemId=101,itemType='Base.MetalBar',place=f.place}} or {}} end
    local started=Ctl.tryShelterConstruction(f.id,f.agent,f.body,100,{fatigue=.65,hunger=.1,thirst=.1},'sleep');local p,step=P.shelterPurpose(f.id);f.purpose,f.step=p,step
    print('GATE_ACQUISITION_INITIAL started='..tostring(started)..' p='..tostring(p and p.id)..' kind='..tostring(step and step.verb)..' status='..tostring(step and step.status)..' blocker='..tostring(p and p.blockers[1])..' state='..tostring(f.agent.state))
    check('unacquired_material_refuses_actual_source_owner_and_records_retry',not started and p and step.verb=='acquire' and step.status=='blocked'
        and p.routeFailures and #p.routeFailures==1 and not f.rec.worldSourceReservation and not __nativeShelter('held',101))
    local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;f.purpose=saved.proceduralPlanning.purposes[p.id]
    assert(SAO.Perception.learnInspectedSource(f.id,f.place,f.sourceId,100,'native-container-inspection'))
    Ctl.resourceContext=resourceContext
    local debug=resourceContext(f.id,f.agent,f.body,{fatigue=.65},'metal-bar',.5)
    print('METAL_PRIVATE_ACQUIRED_OPTIONS '..#debug.sources..' knows='..tostring(SAO.WorldSources.privatelyKnowsItem(f.id,f.sourceId,101)))
    local before=f.purpose.routeFailures[1].retryAt
    started=Ctl.tryShelterConstruction(f.id,f.agent,f.body,101,{fatigue=.65,hunger=.1,thirst=.1},'sleep')
    check('saved_acquisition_refusal_waits_existing_exact_retry_clock',not started and not saved.worldSourceReservation and f.purpose.selectedStrategy==step.id and before>__hours)
    if started or f.purpose.selectedStrategy~=step.id then return end
    __hours=before+.001;started=Ctl.tryShelterConstruction(f.id,f.agent,f.body,102,{fatigue=.65,hunger=.1,thirst=.1},'sleep');local reservation=WS.pendingActionFor(f.id)
    check('ordinary_controller_admits_exact_private_metal_shelter_material_to_sourceuse',started and f.agent.state=='SOURCEWARD' and reservation
        and reservation.operation=='acquire' and reservation.sourceId==f.sourceId and reservation.itemId==101 and reservation.itemType=='Base.MetalBar'
        and reservation.quantity==1 and reservation.quantityUnit=='item' and reservation.purposeId==p.id and not f.nativePayments)
    assert(reservation);SAO.Locomotion.tick(f.id);assert(SU.onMovementDone(f.id,f.body,'arrived')=='using')
    local queue=ISTimedActionQueue.getTimedActionQueue(f.body);local action=queue.current;action.getNotFullFloorSquare=function()return nil end;action.playTransferCompleteSound=function()end
    action:start();action.action.nativeFinished=true;action:perform();local status=SU.tick(f.id,f.body);local receipt=WS.actionOutcome(reservation.id,f.id)
    check('actual_verified_transfer_retains_exact_native_material_and_item_unit',status=='completed' and receipt and receipt.measurement=='native-item-transfer'
        and receipt.observedQuantity==1 and receipt.quantityUnit=='item' and __nativeShelter('held',101) and f.inventory:contains(f.material) and not f.source:contains(f.material))
    assert(receipt);local raw=ModData.get('SurvivorAwareness_WorldSources').results[reservation.id];local fields={'sourceId','preRevision','itemId','itemType','category','actorId','quantityUnit','requestedQuantity','observedQuantity'};local refused=true
    for _,key in ipairs(fields) do local original=raw[key];raw[key]=type(original)=='number' and original+1 or 'foreign-'..tostring(original)
        refused=refused and P.consumeSourceResult(receipt)==false and f.purpose.admission~=nil;raw[key]=original end
    check('changed_authoritative_source_item_actor_quantity_cannot_advance_metal_shelter',refused)
    check('exact_canonical_acquisition_continues_original_metal_shelter_purpose',P.consumeSourceResult(receipt) and not f.purpose.admission and f.purpose.status~='completed')
    f.agent.state='IDLE';assert(__nativeShelter('sceneMove','10.5,20.5,0'));local pos=__nativeShelter('scenePosition');f.body.x,f.body.y,f.body.z=pos.x,pos.y,pos.z;f.body.here=f.siteSquare;started=Ctl.tryShelterConstruction(f.id,f.agent,f.body,103,{fatigue=.65,hunger=.1,thirst=.1},'sleep')
    while f.rec.resourceProductionWork and f.rec.resourceProductionWork.stage=='approaching' do R.tick(f.id,f.body) end;local row=started and __shelterFinish(f)
    check('ordinary_private_acquisition_unlocks_exact_native_metal_shelter_payment',row and row.status=='completed' and row.purposeId==p.id and #row.parts==1 and f.nativePayments==1)

    __hours=100
end
local function buildAction(f)
    local p,s=plan(f);assert(s and R.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id}))
    local q=ISTimedActionQueue.getTimedActionQueue(f.body)
    if q.current.Type=='ISEquipWeaponAction' then local a=q.current;a:start();a.action.nativeFinished=true;a:perform();assert(a:complete()) end
    assert(q.current and q.current.Type=='ISBuildAction');return q.current,q
end
local function attempt(a)a:start();a.action.nativeFinished=true;a:perform() end
function __runMetalManualAcquisition()
    local f=metalAcquisitionFixture('ordinary-metal-manual',true)
    assert(SAO.Perception.learnInspectedSource(f.id,f.place,f.sourceId,100,'native-container-inspection'))
    local begun=Ctl.tryShelterConstruction(f.id,f.agent,f.body,100,{fatigue=.65,hunger=.1,thirst=.1},'sleep');local p,step=P.shelterPurpose(f.id)
    local reservation=SAO.WorldSources.pendingActionFor(f.id)
    check('ordinary_retained_shelter_acquires_exact_native_recipe_magazine',begun and reservation and reservation.category=='shelter-manual' and reservation.itemId==901 and reservation.itemType=='Base.MetalworkMag1' and not __recipeNative('known','MetalDoorFrameLvl1'))
    assert(reservation);SAO.Locomotion.tick(f.id);assert(SAO.SourceUse.onMovementDone(f.id,f.body,'arrived')=='using')
    local a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a.getNotFullFloorSquare=function()return nil end;a.playTransferCompleteSound=function()end
    a:start();a.action.nativeFinished=true;a:perform();assert(SAO.SourceUse.tick(f.id,f.body)=='completed')
    local receipt=SAO.WorldSources.actionOutcome(reservation.id,f.id);assert(P.consumeSourceResult(receipt))
    check('native_magazine_transfer_preserves_exact_item_actor_and_unit',receipt.itemId==901 and receipt.itemType=='Base.MetalworkMag1' and receipt.quantityUnit=='item' and receipt.observedQuantity==1 and __nativeShelter('manualHeld') and f.inventory:contains(f.material))
    f.agent.state='IDLE';assert(Ctl.tryShelterConstruction(f.id,f.agent,f.body,101,{fatigue=.65,hunger=.1,thirst=.1},'sleep'))
    a=ISTimedActionQueue.getTimedActionQueue(f.body).current;a:start();a.action.jobDelta=1;a:update();a.action.nativeFinished=true;a:complete();a:perform()
    local reading=SAO.Study.recipeOutcome(f.id,f.rec.studyWork.id)
    check('ordinary_source_acquisition_then_native_reader_teaches_same_shelter_actor',reading and reading.status=='completed' and reading.purposeId==p.id and __recipeNative('known','MetalDoorFrameLvl1') and __recipeNative('reads')==1)
    assert(__nativeShelter('sceneMove','10.5,20.5,0'));local pos=__nativeShelter('scenePosition');f.body.x,f.body.y,f.body.z=pos.x,pos.y,pos.z;f.body.here=f.siteSquare;f.agent.state='IDLE'
    begun=Ctl.tryShelterConstruction(f.id,f.agent,f.body,102,{fatigue=.65,hunger=.1,thirst=.1},'sleep');local row=begun and __shelterFinish(f)
    check('acquired_native_knowledge_unlocks_original_exact_metal_work',row and row.status=='completed' and row.purposeId==p.id and f.nativePayments==1 and __recipeNative('reads')==1)
end
function __runMetalCategories()
    local f=fixture('metal-native-categories','Base.MetalDoorFrameLvl1','N');local good=true
    for _,item in ipairs(f.materials) do local category=({['Base.MetalBar']='metal-bar',['Base.BlowTorch']='welding-torch',['Base.WeldingRods']='welding-rods'})[item:getFullType()]
        if category then good=good and __nativeShelter('materialCategory',item.id,category) and __nativeShelter('sourceCategories',item.id):find(category,1,true)~=nil end
    end
    check('native_exact_bar_torch_rods_categories_match_source_projection',good)
    f=fixture('metal-native-sheet','Base.MetalDoorLvl1','N');good=true
    for _,item in ipairs(f.materials) do if item:getFullType()=='Base.SmallSheetMetal' then good=good and __nativeShelter('materialCategory',item.id,'small-sheet-metal') and __nativeShelter('sourceCategories',item.id):find('small-sheet-metal',1,true)~=nil end end
    check('native_exact_small_sheet_category_matches_source_projection',good)
    __nativeShelter('known',false);local b=book(f)
    check('actual_native_shelter_manual_category_matches_source_projection',__nativeShelter('manualCategory','shelter-manual') and __nativeShelter('sourceCategories','manual'):find('shelter-manual',1,true)~=nil)
    local snapshot=__nativeShelter('manualPool');local place={id='metal-manuals',sourceId='C:metal-manuals:0',cx=12,cy=23,z=0,minX=12,minY=23,maxX=13,maxY=24}
    assert(SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(snapshot)));assert(SAO.Perception.learnInspectedSource(f.id,place,place.sourceId,100,'native-container-inspection'))
    local offers,reason=SAO.WorldSources.actionOptions(place,'weapons',f.id,f.body,1,'standing','acquire',nil,function(type)return type=='Base.MetalBar' and __nativeShelter('poolInputMatch') end)
    print('NATIVE_MANUAL_FILTER reason='..tostring(reason)..' offers='..tostring(offers and #offers.options)..' id='..tostring(offers and offers.options[1] and offers.options[1].parameters.itemId))
    check('native_exact_material_predicate_filters_before_private_action_capacity',offers and #offers.options==1 and offers.options[1].parameters.itemId==2328 and offers.options[1].parameters.itemType=='Base.MetalBar')
    local context=resourceContext(f.id,f.agent,f.body,{fatigue=.65},'shelter-manual',.5,nil,nil,'MetalWallFrame')
    check('ordinary_controller_keeps_exact_native_manual_category_and_recipe_filter',#context.sources==1 and context.sources[1].itemId==2128 and context.sources[1].category=='shelter-manual')
end
function __runMetalPolicy()
    local f=fixture('metal-native-policy','Base.MetalWallFrame','N');local o=option(f)
    check('complete_native_metal_recipe_policy_is_available',o and o.requirements[1].mode=='use' and o.requirements[1].quantity==1 and o.requirements[2].count==3 and o.requirements[3].quantity==2)
end
function __runMetalGuards()
    local f=fixture('metal-unknown-admit','Base.MetalDoorFrameLvl1','N');local p,s=plan(f);__nativeShelter('known',false)
    print('ACTUAL_NATIVE_KNOWLEDGE '..__nativeShelter('knownFlags',f.entityId))
    print('LUA_NATIVE_VISIBLE '..tostring(CraftRecipeManager.hasPlayerLearnedRecipe(__shelterPolicies[f.entityId].recipe,f.body))..' unknownFlag='..tostring(f.body.recipeUnknown))
    local admitted=R.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id})
    check('actual_unknown_visible_recipe_refuses_native_admission',not admitted and not f.nativePayments and not f.created)
    if f.rec.resourceProductionWork then R.interrupt(f.id,f.body,'control-cleanup') end
    f=fixture('metal-knowledge-revoked','Base.MetalDoorFrameLvl1','N');local a,q=buildAction(f);__nativeShelter('known',false);attempt(a)
    check('actual_knowledge_revocation_before_effect_prevents_native_payment',not f.nativePayments and not f.created)
    f=fixture('metal-standing-revoked','Base.MetalDoorFrameLvl1','N');a,q=buildAction(f);f.rec.permissionDenied=true;attempt(a)
    check('current_standing_revocation_before_effect_prevents_native_payment',not f.nativePayments and not f.created)
    f=fixture('metal-torch-changed','Base.MetalDoorFrameLvl1','N');a,q=buildAction(f);__nativeShelter('setUses',100,8);attempt(a)
    check('changed_exact_torch_charge_custody_prevents_native_payment',not f.nativePayments and not f.created)
    f=fixture('metal-paid','Base.MetalDoorFrameLvl1','N');a,q=buildAction(f);attempt(a);local rows=f.rec.resourceProductionOutcomes;local row=rows and rows[#rows]
    check('native_metered_payment_measures_current_charge_decrement',row and row.status=='completed' and row.usesBefore['100']==10 and row.usesAfter['100']==6
        and row.usesBefore['105']==20 and row.usesAfter['105']==16 and f.nativePayments==1)
    local recipe=row.recipeId;row.recipeId='Base.ForeignRecipe';check('foreign_saved_recipe_identity_cannot_earn_build_credit',R.outcome(f.id,row.id)==nil);row.recipeId=recipe
    local recorded=row.requirements[1].recordInput;row.requirements[1].recordInput=true;check('changed_saved_dontrecordinput_contract_cannot_earn_build_credit',R.outcome(f.id,row.id)==nil);row.requirements[1].recordInput=recorded
    local delivered=f.rec.cognition and #f.rec.cognition.experiences or 0;__nativeShelter('known',false);R.reconcileSaved(f.id,f.body)
    check('measured_paid_retirement_survives_later_knowledge_change',R.outcome(f.id,row.id).status=='completed' and (f.rec.cognition and #f.rec.cognition.experiences or 0)==delivered and not f.rec.resourceProductionWork)
    for _,face in ipairs({'N','W'}) do
        for _,entity in ipairs({'Base.MetalWallLvl1','Base.MetalWallLvl2'}) do
            f=fixture('metal-cross-frame-'..entity..face,entity,face,'Base.WoodenWallFrame');a,q=buildAction(f);attempt(a);row=f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
            check(entity:sub(6)..'_'..face..'_native_wood_frame_substitution',row and row.status=='completed' and __nativeShelter('stageReplaced'))
        end
        f=fixture('metal-cross-door-'..face,'Base.MetalDoorLvl1',face,'Base.WoodDoorFrameLvl1');a,q=buildAction(f);attempt(a);row=f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
        check('MetalDoor_'..face..'_native_wood_doorframe_substitution',row and row.status=='completed' and f.initialStage:getObjectIndex()>=0)
        f=fixture('wood-cross-frame-'..face,'Base.WoodenWallLvl1',face,'Base.MetalWallFrame');a,q=buildAction(f);attempt(a);row=f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
        check('WoodWall_'..face..'_native_metal_frame_substitution',row and row.status=='completed' and __nativeShelter('stageReplaced'))
    end
    f=fixture('metal-retained-completed-edge','Base.MetalWallLvl1','N');a,q=buildAction(f);attempt(a);row=f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
    check('successful_native_metal_wall_enters_retained_completed_edges',row and f.purpose.shelterConstruction.completedEdges[row.siteKey]=='Base.MetalWallLvl1')
    f=fixture('metal-intrinsic-grade2','Base.MetalDoorLvl2','N');p,s=plan(f);__nativeShelter('known',false);__nativeShelter('skill',3)
    admitted=R.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id});row=admitted and __shelterFinish(f)
    check('intrinsic_grade2_door_uses_actual_native_skill3_without_manual',row and row.status=='completed' and __recipeNative('reads')==0)
    f=fixture('metal-healthy-grade1','Base.MetalWallLvl2','N','Base.MetalWallLvl1')
    local hasUpgrade=false;for _,o in ipairs(R.shelterOptions(f.id,f.body)) do if o.site.previousEntity=='Base.MetalWallLvl1' and o.entityId=='Base.MetalWallLvl2' then hasUpgrade=true end end
    check('healthy_grade1_wall_is_not_a_new_shelter_breach_or_forced_upgrade',not hasUpgrade and __nativeShelter('sceneEnclosed') and not f.nativePayments)
    f=fixture('metal-pooled-use','Base.MetalDoorFrameLvl2','N');materials(f,'Base.MetalDoorFrameLvl2',true);a,q=buildAction(f)
    local pooled=__nativeRoundtrip(f.rec.resourceProductionWork);local heldCount=#f.materials
    attempt(a);row=f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
    check('all_exact_pooled_charge_objects_survive_save_and_native_payment',heldCount==12 and #pooled.inputs==12 and row and row.status=='completed' and #row.inputs==12)
    f=fixture('metal-intended-upgrade','Base.MetalWallLvl2','N');p,s=plan(f);local purposeId=p.id
    assert(__nativeShelter('replaceSeed','Base.MetalWallLvl1'));local previous=IsoThumpable.new(f.cell,f.siteSquare,__nativeShelter('otherSprite','Base.MetalWallLvl1|N'),true,{})
    previous.entityId,previous.nativeFactory,previous.health='Base.MetalWallLvl1',true,500;f.siteSquare.objects={previous};f.previous,f.initialStage=previous,previous
    assert(SAO.Perception.observeShelterSites(f.id,f.body));local offered=option(f);local retained,step
    if offered then retained,step=P.planShelterConstruction(f.id,{recoveryKind='sleep',fatigue=.65,atHours=__hours,options={offered},materialSources={},sites=SAO.Perception.shelterSites(f.id,f.body),position={x=10.5,y=20.5,z=0}}) end
    if not step then check('retained_actual_grade2_intention_accepts_native_grade1_replacement',false);return end
    local intention=retained.shelterConstruction.intendedEdges[step.site.key];local guarded=true
    for _,key in ipairs({'actorId','world','purposeId','stepId','entityId','priorEntity','priorRevision','observedAtHours','selectedAt','x'}) do local before=intention[key]
        intention[key]=type(before)=='number' and before+1 or 'foreign-'..tostring(before)
        local offered=false;for _,o in ipairs(R.shelterOptions(f.id,f.body,retained.shelterConstruction)) do if o.site.key==step.site.key and o.site.upgradeOpportunity then offered=true end end
        guarded=guarded and not offered;intention[key]=before
    end
    check('foreign_saved_actor_world_site_intention_cannot_admit_upgrade',guarded and not f.nativePayments)
    local acquiredAt,selectedAt=intention.observedAtHours,intention.selectedAt;intention.observedAtHours=-2;intention.selectedAt=-1
    local negative=false;for _,o in ipairs(R.shelterOptions(f.id,f.body,retained.shelterConstruction)) do if o.site.key==step.site.key and o.site.upgradeOpportunity then negative=true end end
    intention.observedAtHours,intention.selectedAt=acquiredAt,selectedAt
    check('negative_original_selection_clocks_refuse_upgrade',not negative)

    local raw=intention;retained.shelterConstruction.intendedEdges[step.site.key]='Base.MetalWallLvl2';local forged=false
    for _,o in ipairs(R.shelterOptions(f.id,f.body,retained.shelterConstruction)) do if o.site.key==step.site.key and o.entityId=='Base.MetalWallLvl2' then forged=true end end
    retained.shelterConstruction.intendedEdges[step.site.key]=raw
    check('bare_forged_grade_name_is_not_an_acquired_person_intention',not forged and not f.nativePayments)
    assert(__nativeShelter('sceneSleep',true));local observation=SAO.Perception.shelterSites(f.id,f.body);local before=observation[1]
    assert(SAO.Perception.observeShelterSites(f.id,f.body));local retainedFact=SAO.Perception.shelterSites(f.id,f.body)[1]
    check('unavailable_owning_predecessor_preserves_acquired_fact_without_placement',#__nativeShelter('sceneSites','10,20,0')==0 and before and retainedFact and before.revision==retainedFact.revision and not SAOJavaBridge:worldShelterPlacementSquare(f.body,step.site.key,step.site.revision) and not f.nativePayments)
    assert(not __nativeShelter('sceneSleep',false))
    local oldActor=intention.actorId;intention.actorId='foreign';local bad=R.begin(f.id,f.body,step,{purposeId=retained.id,purposeStepId=step.id});intention.actorId=oldActor
    check('foreign_grade_intention_refuses_actual_native_admission',not bad and not f.nativePayments)
    if bad then R.interrupt(f.id,f.body,'negative-intention-cleanup');step.status='available' end
    local savedIntention=__nativeRoundtrip(f.rec);check('grade_intention_survives_actual_saved_person_roundtrip',savedIntention.proceduralPlanning.purposes[retained.id].shelterConstruction.intendedEdges[step.site.key].world==intention.world)
    admitted=step and R.begin(f.id,f.body,step,{purposeId=retained.id,purposeStepId=step.id});row=admitted and __shelterFinish(f)
    check('retained_actual_grade2_intention_accepts_native_grade1_replacement',retained==p and row and row.status=='completed' and row.purposeId==purposeId and row.site.previousEntity=='Base.MetalWallLvl1' and __nativeShelter('stageReplaced'))
    f=fixture('metal-saved-interruption','Base.MetalDoorFrameLvl1','N');a,q=buildAction(f);a:start();f.body.holdCancellation=true
    local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;f.purpose=saved.proceduralPlanning.purposes[f.purpose.id];__reloadProduction()
    local reconciled=R.reconcileSaved(f.id,f.body)
    check('saved_native_construction_holds_exact_cancellation_ack',not reconciled and saved.resourceProductionWork and f.purpose.admission and q.current==a and not f.nativePayments)
    f.body.holdCancellation=false;reconciled=R.reconcileSaved(f.id,f.body);row=saved.resourceProductionOutcomes and saved.resourceProductionOutcomes[#saved.resourceProductionOutcomes]
    check('saved_native_construction_ack_retires_truthfully_without_parts',reconciled and row and row.status=='interrupted' and #row.parts==0 and not row.nativeCompleted and not saved.resourceProductionWork and not f.purpose.admission)
    f=fixture('metal-effect-before-ack','Base.MetalDoorFrameLvl1','N');a,q=buildAction(f)
    local completed=q.onCompleted;function q:onCompleted(action)if action==a then return end;return completed(self,action) end
    attempt(a)
    check('measured_native_effect_holds_claim_until_exact_queue_ack',f.nativePayments==1 and f.created and f.rec.resourceProductionWork and f.purpose.admission and q.current==a)
    __nativeShelter('known',false);R.tick(f.id,f.body);q.onCompleted=completed;completed(q,a);R.tick(f.id,f.body)
    row=f.rec.resourceProductionOutcomes and f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
    check('ordinary_tick_retires_paid_effect_after_ack_without_new_knowledge_gate',row and row.status=='completed' and not f.rec.resourceProductionWork and not f.purpose.admission and f.nativePayments==1)
    f=fixture('metal-delayed-private-feedback','Base.MetalDoorFrameLvl1','N');a,q=buildAction(f);local feedback=SAO.Cognition.shelterOutcome
    SAO.Cognition.shelterOutcome=function()return false,'temporary-private-model-refusal' end;attempt(a);row=f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
    check('physical_native_result_retires_independently_of_private_feedback',row and row.status=='completed' and row.purposeDelivered and not row.experienceDelivered and not f.rec.resourceProductionWork and not f.purpose.admission)
    local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;SAO.Cognition.shelterOutcome=feedback;__reloadProduction();R.reconcileSaved(f.id,f.body);R.reconcileSaved(f.id,f.body)
    check('saved_private_feedback_replays_actual_build_once',saved.cognition and #saved.cognition.experiences==1 and saved.cognition.experiences[1].kind=='shelter-construction')
    f=fixture('metal-successor-custody','Base.MetalDoorFrameLvl1','N');a,q=buildAction(f);a:start();local successor={character=f.body,Type='foreign-successor',isValidStart=function()return true end,begin=function()end}
    q.queue={successor};q.current=successor;R.interrupt(f.id,f.body,'replacement')
    check('foreign_successor_queue_cannot_be_retired_by_metal_claim',q.current==successor and q.queue[1]==successor and not f.nativePayments)
end
__metalFixture,__metalPlan,__metalOption,__metalAdaptMaterials=fixture,plan,option,adaptMaterials
