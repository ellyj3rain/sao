-- Existing native scene and actual registered floor recipe/build callback.
function __runShelterSurfaceFirst(grade)
    grade=grade or 1;local metal=grade=='metal';local entity=metal and 'Base.MetalFloorLvl1' or 'Base.WoodFloorLvl'..grade
    if metal then __nativeShelter('known',true);__nativeShelter('skill',0) end
    local f=__shelterFixture('surface-first-'..grade,'W',entity)
    if metal then for _,item in ipairs(f.materials) do function item:getCurrentUses()return __nativeShelter('uses',self:getID()) end end;function f.body:isRecipeActuallyKnown(name)return __nativeShelter('actualKnown',name) end;function f.body:getPerkLevel()return 0 end end
    local function floorCheck(name,result)__shelterCheck(name..'_grade'..grade,result) end
    assert(__nativeShelter('surfaceSceneSetup',f.id))
    f.siteSquare=__shelterSquare(f,12,21);f.approach=__shelterSquare(f,11,21)
    local actual=__nativeShelter('scenePosition');f.body.x,f.body.y,f.body.z=actual.x,actual.y,actual.z;f.body.here=f.approach
    function f.siteSquare:getCell()return f.cell end
    function f.siteSquare:HasStairsBelow()return __nativeShelter('surfaceStairsBelow') end
    function f.siteSquare:connectedWithFloor()return __nativeShelter('surfaceConnected') end
    function f.siteSquare:EnsureSurroundNotNull()return __nativeShelter('surfaceEnsure') end
    function f.siteSquare:RecalcProperties()return __nativeShelter('surfaceRecalc') end
    function f.siteSquare:clearWater()return __nativeShelter('surfaceClearWater') end
    function f.siteSquare:disableErosion()return __nativeShelter('surfaceDisableErosion') end
    function f.siteSquare:setSquareChanged()return __nativeShelter('surfaceChanged') end
    function f.cell:checkHaveRoof(x,y)return __nativeShelter('surfaceCheckRoof',x,y) end
    DesignationZoneAnimal={addNewRoof=function()end};FBORenderChunk={DIRTY_OBJECT_ADD=1}
    function sendServerCommand()end;function invalidateLighting()end
    function string.contains(s,part)return s:find(part,1,true)~=nil end
    SAOJavaBridge.worldShelterSurfaces=function(_,body)return body==f.body and __nativeShelter('surfaceSites') or {} end
    SAOJavaBridge.worldShelterCoverNeeds=function()return {} end
    SAOJavaBridge.worldShelterAccess=function()return {} end
    SAOJavaBridge.worldShelterSurfacePlacementSquare=function(_,body,key,revision)
        return body==f.body and __nativeShelter('surfacePlacement',key,revision) and f.siteSquare or nil
    end
    SAOJavaBridge.worldShelterSurfaceCreated=function(_,body,object,entity,x,y,z)
        return body==f.body and object==f.created and entity==f.entityId and x==12 and y==21 and z==0
            and __nativeShelter('surfaceCreated')
    end
    SAO.Cognition.ensureGameDefaults();assert(SAO.Perception.observeShelterSurfaces(f.id,f.body))
    local options=SAO.ResourceProduction.shelterOptions(f.id,f.body)
    local chosen={} for _,option in ipairs(options) do if option.entityId==entity then chosen[#chosen+1]=option end end
    local purpose,step=SAO.ProceduralPlanning.planShelterConstruction(f.id,{recoveryKind='sleep',fatigue=.65,atHours=__hours,options=chosen,materialSources={}})
    print('SURFACE_OPTION count='..#chosen..' purpose='..tostring(purpose and purpose.id)..' step='..tostring(step and step.productionKind))
    f.purpose,f.step=purpose,step
    floorCheck('first_native_floor_admitted',purpose and step and __shelterBegin(f)==true)
    local row=__shelterFinish(f)
    print('SURFACE_RESULT status='..tostring(row and row.status)..' detail='..tostring(row and row.detail))
    floorCheck('first_native_floor_created_paid_and_retained',row and row.status=='completed' and row.kind=='build-shelter-surface'
        and row.inputsConsumed and row.toolRetained and #row.parts==1 and f.nativePayments==1 and __nativeShelter('surfaceFloor'))
    floorCheck('actual_existing_native_cover_stays_independent',__nativeShelter('surfaceRoof') and purpose and purpose.status~='completed' and not f.rec.recoveryExperiences)
    floorCheck('first_native_floor_has_independent_feedback',#f.rec.cognition.experiences==1
        and f.rec.cognition.experiences[1].entityId==entity and f.rec.cognition.models.ordinary.revision==1
        and f.rec.cognition.models.associative.revision==1)
end

local function square(f,x,y,z)
    local key=x..':'..y..':'..z;local prior=f.cell.squares[x..':'..y..':0']
    local sq=f.cell.squares[key]
    if not sq then sq=__shelterSquare(f,x,y);sq.z=z;f.cell.squares[x..':'..y..':0']=prior;f.cell.squares[key]=sq end
    function sq:getCell()return f.cell end
    local coordinates=x..','..y..','..z
    function sq:HasStairsBelow()return __nativeShelter('surfaceStairsBelow') end
    function sq:connectedWithFloor()return __nativeShelter('surfaceConnected') end
    function sq:EnsureSurroundNotNull()return __nativeShelter('surfaceEnsure',coordinates) end
    function sq:RecalcProperties()return __nativeShelter('surfaceRecalc',coordinates) end
    function sq:RecalcAllWithNeighbours()return __nativeShelter('surfaceRecalcNeighbours',coordinates) end
    function sq:clearWater()return __nativeShelter('surfaceClearWater') end
    function sq:disableErosion()return __nativeShelter('surfaceDisableErosion') end
    function sq:setSquareChanged()return __nativeShelter('surfaceChanged') end
    return sq
end
local function measuredPosition(f)
    local p=__nativeShelter('scenePosition');f.body.x,f.body.y,f.body.z=p.x,p.y,p.z
    f.body.here=square(f,math.floor(p.x),math.floor(p.y),math.floor(p.z));return p
end
function __runShelterSurfaceUpper(provided)
    local Ctl,R,P=SAO.Controller,SAO.ResourceProduction,SAO.ProceduralPlanning
    DesignationZoneAnimal={addNewRoof=function()end};FBORenderChunk={DIRTY_OBJECT_ADD=1}
    function sendServerCommand()end;function invalidateLighting()end
    function string.contains(s,part)return s:find(part,1,true)~=nil end
    local f=provided or __shelterFixture('surface-upper','W','Base.WoodFloorLvl1');local surfaceEntity=f.entityId;local reader=SAO.Study;__shelterControllerSetup(f);SAO.Study=reader
    local function upperCheck(name,value)__shelterCheck((f.checkPrefix or "")..name,value) end
    local paid=f.nativePayments or 0;local learned=#(f.rec.cognition and f.rec.cognition.experiences or {})
    if not provided or provided.surfaceNeedsSetup then assert(__nativeShelter('surfaceRoofSceneSetup',f.id)) end;measuredPosition(f)
    f.siteSquare=square(f,12,21,1);square(f,12,21,0)
    function f.cell:checkHaveRoof(x,y)return __nativeShelter('surfaceCheckRoof',x,y) end
    SAOJavaBridge.worldShelterSurfaces=function(_,body)return body==f.body and __nativeShelter('surfaceSites') or {} end
    SAOJavaBridge.worldShelterCoverNeeds=function(_,body)return body==f.body and __nativeShelter('surfaceCoverNeeds') or {} end
    SAOJavaBridge.worldShelterAccess=function(_,body)return body==f.body and __nativeShelter('surfaceAccess') or {} end
    SAOJavaBridge.worldShelterSites=function(_,body,x,y,z)return body==f.body and __nativeShelter('sceneSites',x..','..y..','..z) or {} end
    SAOJavaBridge.worldShelterSurfacePlacementSquare=function(_,body,key,revision)
        return body==f.body and __nativeShelter('surfacePlacement',key,revision) and f.siteSquare or nil
    end
    SAOJavaBridge.worldShelterSurfaceCreated=function(_,body,object,entity,x,y,z)
        return body==f.body and object==f.created and entity==f.entityId and x==12 and y==21 and z==1 and __nativeShelter('surfaceCreated')
    end
    SAO.Locomotion.tick=function(id)
        local job=SAO.Locomotion.jobs[id];local arrived=__nativeShelter('sceneMove',job.goal.x..','..job.goal.y..','..job.goal.z)
        measuredPosition(f);job.done,job.result=true,arrived and 'arrived' or 'failed'
    end
    SAO.Cognition.ensureGameDefaults()
    local before={} for _,row in ipairs(__nativeShelter('surfaceCoverNeeds')) do if row.roof==false then before[#before+1]=row end end
    local access=__nativeShelter('surfaceAccess')
    print('UPPER_PREFLIGHT need='..#before..' access='..#access..' lowerRoof='..tostring(__nativeShelter('surfaceLowerRoof')))
    upperCheck('native_missing_cover_and_visible_stair_are_real',#before==1 and #access==1 and not __nativeShelter('surfaceLowerRoof')
        and access[1].landingObserved==false and access[1].landingZ==1 and #__nativeShelter('surfaceSites')==0)
    local admitted=Ctl.offerRecovery(f.id,f.agent,f.body,100,SAO.Needs.read(f.body),'sleep')
    local purpose,step=P.shelterPurpose(f.id);print('UPPER_PLAN admitted='..tostring(admitted)..' state='..f.agent.state..' verb='..tostring(step and step.verb))
    upperCheck('ordinary_shelter_concern_inquires_without_upper_truth',admitted and f.agent.shelterRoute and step.verb=='inspect'
        and purpose.shelterConstruction.origin.z==0 and not f.rec.resourceProductionWork)
    if f.agent.shelterRoute then SAO.Locomotion.tick(f.id);__shelterControllerTick(101);Ctl.finishShelterMovement(f.id,f.agent,f.body) end
    upperCheck('same_body_native_stairs_reach_actual_upper_level',f.body.z>=1 and f.body:getCurrentSquare():getZ()==1
        and f.agent.state=='IDLE' and purpose.status~='completed' and purpose.shelterConstruction.origin.z==0)
    local native=__nativeShelter('surfaceSites');local selected
    for _,row in ipairs(native) do if row.x==12 and row.y==21 and row.z==1 then selected=row end end
    print('UPPER_OBSERVED rows='..#native..' target='..tostring(selected and selected.key)..' approach='..tostring(selected and selected.approachX)..','..tostring(selected and selected.approachY))
    if selected then assert(__nativeShelter('sceneMove',(selected.approachX+.5)..','..(selected.approachY+.5)..',1'));measuredPosition(f);f.approach=f.body.here end
    admitted=Ctl.offerRecovery(f.id,f.agent,f.body,200,SAO.Needs.read(f.body),'sleep')
    local row=f.rec.resourceProductionWork and __shelterFinish(f)
    print('UPPER_RESULT admitted='..tostring(admitted)..' row='..tostring(row and row.status)..' detail='..tostring(row and row.detail))
    upperCheck('native_upper_floor_creates_lower_cover_under_same_purpose',admitted and row and row.status=='completed'
        and row.kind=='build-shelter-surface' and row.purposeId==purpose.id and row.inputsConsumed and row.toolRetained
        and f.nativePayments==paid+1 and __nativeShelter('surfaceFloor') and __nativeShelter('surfaceLowerRoof')
        and purpose.status~='completed' and purpose.shelterConstruction.origin.z==0 and not f.rec.recoveryExperiences)
    if f.stopAfterFloor then f.purpose=purpose;return f end
    f.agent.state='IDLE';admitted=Ctl.offerRecovery(f.id,f.agent,f.body,300,SAO.Needs.read(f.body),'sleep')
    local _,returnStep=P.shelterPurpose(f.id)
    upperCheck('ordinary_shelter_work_returns_to_original_use_level',admitted and f.agent.shelterRoute and returnStep.verb=='return'
        and returnStep.z==0 and purpose.shelterConstruction.origin.z==0)
    if f.agent.shelterRoute then SAO.Locomotion.tick(f.id);__shelterControllerTick(301);Ctl.finishShelterMovement(f.id,f.agent,f.body) end
    upperCheck('native_stairs_return_same_body_without_recovery_credit',f.body:getCurrentSquare():getZ()==0 and f.agent.state=='IDLE'
        and purpose.status~='completed' and not f.rec.recoveryExperiences and __nativeShelter('surfaceLowerRoof'))
    __nativeShelter('surfaceBuildAt','10,20,0');f.orientation='N';f.siteSquare=square(f,10,20,0);f.approach=f.siteSquare;f.previous=nil
    SAOJavaBridge.worldShelterPlacementSquare=function(_,body,key,revision)
        return body==f.body and __nativeShelter('scenePlacement',key,revision) and f.siteSquare or nil
    end
    SAOJavaBridge.worldShelterPreviousStage=function(_,body,key,revision)
        local entity=body==f.body and __nativeShelter('scenePrevious',key,revision)
        return f.previous and f.previous.entityId==entity and f.previous or nil
    end
    SAOJavaBridge.worldShelterCreated=function(_,body,object,previous,entity,x,y,z,face)
        return body==f.body and object==f.created and object.nativeFactory and object.entityId==entity and x==10 and y==20 and z==0
            and __nativeShelter('createdCount')==1 and __nativeShelter('createdEntity')==entity and face==f.orientation
    end
    for index,entity in ipairs({'Base.WoodDoorFrameLvl1','Base.WoodenDoorLvl1'}) do
        __shelterControllerMaterials(f,entity);f.agent.state='IDLE'
        local context=Ctl.shelterConstructionContext(f.id,f.agent,f.body,SAO.Needs.read(f.body),'sleep')
        print('LOWER_CONTEXT needs='..#context.coverNeeds..' sites='..#context.sites..' options='..#context.options..' blockers='..tostring(purpose.blockers[1]))
        admitted=Ctl.offerRecovery(f.id,f.agent,f.body,400+index,SAO.Needs.read(f.body),'sleep')
        row=f.rec.resourceProductionWork and __shelterFinish(f)
        print('LOWER_EDGE entity='..entity..' admitted='..tostring(admitted)..' row='..tostring(row and row.status)..' detail='..tostring(row and row.detail))
        assert(admitted and row and row.status=='completed' and row.purposeId==purpose.id,'original shelter edge successor refused')
    end
    local door=f.created
    function door:ToggleDoor()__nativeShelter('sceneToggle');self.open=__nativeShelter('sceneOpen') end
    SAOJavaBridge.worldShelterDoor=function(_,body,key,revision)return body==f.body and __nativeShelter('sceneDoorLookup',key,revision) and door or nil end
    SAOJavaBridge.worldShelterBeginPassage=function(_,body,target,key,revision,inward)
        return body==f.body and target==door and __nativeShelter('sceneBeginPassage',inward) or nil
    end
    SAOJavaBridge.worldShelterPassage=function(_,body,token)return body==f.body and __nativeShelter('scenePassageReceipt',token) end
    SAOJavaBridge.worldShelterForgetPassage=function(_,body,token)return __nativeShelter('sceneForgetPassage',token) end
    SAOJavaBridge.worldShelterCover=function(_,body,x,y,z)return body==f.body and __nativeShelter('sceneCover',x..','..y..','..z) or nil end
    SAOJavaBridge.recoveryPlaces=function(_,body)return body==f.body and __nativeShelter('sceneRecoveryPlaces') or nil end
    SAOJavaBridge.worldShelterRecoveryValid=function(_,body,key,revision,x,y,z,reached)
        return body==f.body and __nativeShelter('sceneRecoveryValid',x..','..y..','..z,reached) or false
    end
    SAO.Locomotion.tick=function(id)
        local job=SAO.Locomotion.jobs[id];local doorway=math.floor(job.goal.x)==10 and (math.floor(job.goal.y)==19 or math.floor(job.goal.y)==20)
        local arrived=doorway and __nativeShelter('scenePass',math.floor(job.goal.y)==20)
            or __nativeShelter('sceneMove',job.goal.x..','..job.goal.y..','..job.goal.z)
        measuredPosition(f);job.done,job.result=true,arrived and 'arrived' or 'failed'
    end
    f.agent.state='IDLE';admitted=Ctl.offerRecovery(f.id,f.agent,f.body,500,SAO.Needs.read(f.body),'sleep')
    local reobserved=0
    for count=1,8 do
        if f.agent.shelterRoute then
            SAO.Locomotion.tick(f.id);__shelterControllerTick(500+count);Ctl.finishShelterMovement(f.id,f.agent,f.body);reobserved=reobserved+1
            admitted=Ctl.offerRecovery(f.id,f.agent,f.body,510+count,SAO.Needs.read(f.body),'sleep')
        elseif f.rec.resourceProductionWork then __shelterFinish(f) else break end
    end
    local used=f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
    local sp,ss=SAO.ProceduralPlanning.shelterPurpose(f.id);print('SURFACE_USE_PLAN status='..tostring(sp and sp.status)..' verb='..tostring(ss and ss.verb)..' kind='..tostring(ss and ss.productionKind)..' blockers='..tostring(sp and sp.blockers[1]))
    for _,site in ipairs(SAO.Perception.shelterSites(f.id,f.body)) do print('SURFACE_USE_SITE '..site.key..' '..site.mode..' '..site.originX..','..site.originY) end
    print('UPPER_USE admitted='..tostring(admitted)..' status='..tostring(used and used.status)..' detail='..tostring(used and used.detail)
        ..' enclosed='..tostring(__nativeShelter('sceneEnclosed'))..' roofed='..tostring(__nativeShelter('sceneRoofed')))
    upperCheck('upper_cover_repair_reaches_ordinary_native_shelter_use',admitted and used.kind=='use-shelter' and used.status=='completed'
        and used.purposeId==purpose.id and used.opened and used.crossedOut and used.crossedIn and used.closedDoor and used.enclosureConfirmed
        and __nativeShelter('scenePassages')==2 and not __nativeShelter('sceneOpen') and purpose.shelterConstruction.origin.z==0
        and not f.rec.recoveryExperiences and f.nativePayments==paid+3)
    f.agent.state='IDLE';admitted=Ctl.offerRecovery(f.id,f.agent,f.body,600,SAO.Needs.read(f.body),'sleep')
    if admitted and f.agent.recoveryRoute then SAO.Locomotion.tick(f.id);__shelterControllerTick(601);Ctl.finishRecoveryPlaceMovement(f.id,f.agent,f.body) end
    local place=f.rec.recoveryIntent and f.rec.recoveryIntent.place;local preparing=SAO.Needs.pollRecovery(f.id,f.body)
    local beforeFatigue=SAO.Needs.read(f.body).fatigue
    local measured=preparing=='running' and __nativeShelter('sceneSleepTicks');__hours=__hours+.1
    local result=SAO.Needs.pollRecovery(f.id,f.body)
    upperCheck('surface_repair_finishes_original_lower_shelter_recovery',admitted and place and place.z==0 and place.key~='ground:10:20:0'
        and measured and result=='completed' and purpose.status=='completed' and #f.rec.recoveryExperiences==1
        and f.rec.recoveryExperiences[1].sourceId==place.key and f.rec.recoveryExperiences[1].beforeValue==beforeFatigue
        and f.rec.recoveryExperiences[1].afterValue<beforeFatigue and __nativeShelter('sceneGroundClear',place.x..','..place.y..','..place.z))
    local pendingMovement=0
    for _,movement in ipairs(f.rec.proceduralPlanning.shelterMovementResults or {}) do if not movement.experienceDelivered then pendingMovement=pendingMovement+1 end end
    upperCheck('surface_construction_use_and_recovery_feedback_stay_independent',#f.rec.cognition.experiences==learned+7+reobserved-pendingMovement
        and f.rec.cognition.experiences[learned+1].kind=='shelter-movement'
        and f.rec.cognition.experiences[learned+2].entityId==surfaceEntity
        and f.rec.cognition.experiences[learned+2].kind=='shelter-construction'
        and f.rec.cognition.experiences[learned+3].kind=='shelter-movement'
        and f.rec.cognition.experiences[learned+6+reobserved-pendingMovement].kind=='shelter-use' and f.rec.cognition.experiences[learned+7+reobserved-pendingMovement].kind=='recovery-outcome'
        and f.rec.cognition.models.ordinary.revision==learned+7+reobserved-pendingMovement and f.rec.cognition.models.associative.revision==learned+7+reobserved-pendingMovement)
end

local function focusedFixture(id)
    local f=__shelterFixture(id,'W','Base.WoodFloorLvl1');__shelterControllerSetup(f)
    assert(__nativeShelter('surfaceRoofSceneSetup',id));measuredPosition(f)
    SAOJavaBridge.worldShelterSurfaces=function(_,body)return body==f.body and __nativeShelter('surfaceSites') or {} end
    SAOJavaBridge.worldShelterCoverNeeds=function(_,body)return body==f.body and __nativeShelter('surfaceCoverNeeds') or nil end
    SAOJavaBridge.worldShelterAccess=function(_,body)return body==f.body and __nativeShelter('surfaceAccess') or nil end
    SAOJavaBridge.worldShelterSites=function(_,body,x,y,z)return body==f.body and __nativeShelter('sceneSites',x..','..y..','..z) or {} end
    SAOJavaBridge.worldShelterCover=function(_,body,x,y,z)return body==f.body and __nativeShelter('sceneCover',x..','..y..','..z) or nil end
    SAO.Cognition.ensureGameDefaults();return f
end
function __runShelterSurfaceFocused()
    local Ctl,P,R,V=SAO.Controller,SAO.ProceduralPlanning,SAO.ResourceProduction,SAO.Perception
    local f=focusedFixture('surface-roomless');local noRoom=__nativeShelter('surfaceRoomless')
    local admitted=Ctl.offerRecovery(f.id,f.agent,f.body,100,SAO.Needs.read(f.body),'sleep');local p,step=P.shelterPurpose(f.id)
    print('ROOMLESS noRoom='..tostring(noRoom)..' enclosed='..tostring(__nativeShelter('sceneEnclosed'))..' roofed='..tostring(__nativeShelter('sceneRoofed'))..' lowerRoof='..tostring(__nativeShelter('surfaceLowerRoof'))..' admitted='..tostring(admitted)..' need='..tostring(p and #p.shelterConstruction.coverNeeds)..' verb='..tostring(step and step.verb))
    __shelterCheck('actual_unroofed_enclosure_without_room_admits_roof_inquiry',noRoom and __nativeShelter('sceneEnclosed')
        and not __nativeShelter('sceneRoofed') and not __nativeShelter('surfaceLowerRoof') and admitted and step.verb=='inspect'
        and p.shelterConstruction.origin.z==0 and #p.shelterConstruction.coverNeeds>0 and not f.rec.resourceProductionWork
        and not f.rec.recoveryExperiences and #(f.rec.cognition and f.rec.cognition.experiences or {})==0)

    f=focusedFixture('surface-cap')
    local context=Ctl.shelterConstructionContext(f.id,f.agent,f.body,SAO.Needs.read(f.body),'sleep')
    p=P.planShelterConstruction(f.id,context);local edge=context.sites[1]
    assert(edge and __nativeShelter('sceneMove','11.5,19.5,1'));measuredPosition(f);V.observeShelterSurfaces(f.id,f.body)
    local actualSites=V.shelterSites;V.shelterSites=function(id,body)
        if id~=f.id or body~=f.body then return actualSites(id,body) end
        local rows={} for index=1,12 do rows[#rows+1]=edge end;return rows
    end
    local options=R.shelterOptions(f.id,f.body,p.shelterConstruction)
    local current=P.planShelterConstruction(f.id,{recoveryKind='sleep',fatigue=.65,atHours=__hours,options=options,
        materialSources={},sites={},position={x=f.body.x,y=f.body.y,z=f.body.z},coverNeeds=V.shelterCoverNeeds(f.id),access=V.shelterAccess(f.id)})
    local chosen=current and current.steps[current.cursor]
    __shelterCheck('needed_upper_surface_survives_more_than_32_stale_edge_alternatives',#options==3 and chosen
        and chosen.productionKind=='build-shelter-surface' and chosen.site.x==12 and chosen.site.y==21 and chosen.site.z==1
        and current.id==p.id and current.shelterConstruction.origin.z==0)
    V.shelterSites=actualSites

    f=focusedFixture('surface-cover-memory');context=Ctl.shelterConstructionContext(f.id,f.agent,f.body,SAO.Needs.read(f.body),'sleep')
    p=P.planShelterConstruction(f.id,context);local nativeCoverPort=SAOJavaBridge.worldShelterCoverNeeds
    SAOJavaBridge.worldShelterCoverNeeds=function()return nil end;V.observeShelterSurfaces(f.id,f.body);P.refreshShelterCover(f.id,f.body)
    local unavailable=#V.shelterCoverNeeds(f.id)==1 and #p.shelterConstruction.coverNeeds==1
    SAOJavaBridge.worldShelterCoverNeeds=function()return {} end;V.observeShelterSurfaces(f.id,f.body);P.refreshShelterCover(f.id,f.body)
    __shelterCheck('acquired_lower_cover_need_survives_unavailable_and_hidden_reads',unavailable and #V.shelterCoverNeeds(f.id)==1
        and #p.shelterConstruction.coverNeeds==1 and p.status~='completed' and not f.rec.resourceProductionWork)
    SAOJavaBridge.worldShelterCoverNeeds=nativeCoverPort;assert(__nativeShelter('surfaceRestoreCover'))
    V.observeShelterSurfaces(f.id,f.body);P.refreshShelterCover(f.id,f.body)
    __shelterCheck('actual_visible_positive_roof_alone_retires_exact_cover_need',__nativeShelter('surfaceLowerRoof')
        and #V.shelterCoverNeeds(f.id)==0 and #p.shelterConstruction.coverNeeds==0 and p.status~='completed'
        and #(f.rec.cognition and f.rec.cognition.experiences or {})==0 and not f.rec.recoveryExperiences)

    f=focusedFixture('surface-timeout');SAO.Locomotion.cancel=__shelterActualCancel
    local ack=false;SAOJavaBridge.cancelMove=function()return ack and __nativeShelter('sceneCancelMove') or 'pending' end
    admitted=Ctl.offerRecovery(f.id,f.agent,f.body,1,SAO.Needs.read(f.body),'sleep');p,step=P.shelterPurpose(f.id)
    local job=SAO.Locomotion.jobs[f.id];__shelterControllerTick(2000);Ctl.finishShelterMovement(f.id,f.agent,f.body)
    __shelterCheck('shelter_access_deadline_preserves_owner_until_native_ack',admitted and f.agent.shelterRoute and p.admission
        and SAO.Locomotion.jobs[f.id]==job and not job.done and f.agent.state=='TRAVEL')
    ack=true;Ctl.finishShelterMovement(f.id,f.agent,f.body)
    __shelterCheck('native_ack_retires_exact_timeout_without_arrival_credit',f.agent.state=='IDLE' and not f.agent.shelterRoute
        and not p.admission and not SAO.Locomotion.jobs[f.id] and job.done and job.result=='shelter-access-expired'
        and step.status=='available' and p.status~='completed' and not p.shelterConstruction.accessAttempts[step.target].arrived
        and #(f.rec.cognition and f.rec.cognition.experiences or {})==0 and not f.rec.recoveryExperiences)
    __hours=__hours+.3;admitted=Ctl.offerRecovery(f.id,f.agent,f.body,2100,SAO.Needs.read(f.body),'sleep')
    local successor=SAO.Locomotion.jobs[f.id]
    __shelterCheck('shelter_access_successor_owns_distinct_job_and_original_purpose',admitted and successor and successor~=job
        and successor.shelterPurposeId==p.id and p.shelterConstruction.origin.z==0 and f.agent.shelterRoute.job==successor)
    local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;f.agent.shelterRoute=nil
    p=P.shelterPurpose(f.id);ack=false;local pending=P.reconcileShelterMovement(f.id,f.body)
    local held=pending==false and p.admission and SAO.Locomotion.jobs[f.id]==successor
    ack=true;P.reconcileShelterMovement(f.id,f.body);local quiet=P.reconcileShelterMovement(f.id,f.body)
    __shelterCheck('saved_shelter_access_waits_ack_and_reobserves_original_concern',held and quiet and not p.admission
        and not SAO.Locomotion.jobs[f.id] and p.status~='completed' and p.shelterConstruction.origin.z==0
        and #p.shelterConstruction.coverNeeds==1 and #(f.rec.cognition and f.rec.cognition.experiences or {})==0 and not f.rec.recoveryExperiences)
end

function __runMetalFloorUpper()
    __nativeShelter('known',true);__nativeShelter('skill',0)
    local f=__shelterFixture('metal-floor-upper','W','Base.MetalFloorLvl1');f.surfaceNeedsSetup=true
    for _,item in ipairs(f.materials) do function item:getCurrentUses()return __nativeShelter('uses',self:getID()) end end
    function f.body:isRecipeActuallyKnown(name)return __nativeShelter('actualKnown',name) end
    __runShelterSurfaceUpper(f)
end

local function floorBook(f,fullType)
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

local function metalFloorFixture(id,known)
    __nativeShelter('known',known~=false);__nativeShelter('skill',0)
    local f=__shelterFixture(id,'W','Base.MetalFloorLvl1');assert(__nativeShelter('surfaceSceneSetup',id))
    f.siteSquare=square(f,12,21,0);f.approach=square(f,11,21,0);measuredPosition(f)
    for _,item in ipairs(f.materials) do function item:getCurrentUses()return __nativeShelter('uses',self:getID()) end end
    function f.body:isRecipeActuallyKnown(name)return __nativeShelter('actualKnown',name) end
    function f.body:isRecipeKnown(name)return true end
    function f.body:getPerkLevel()return 0 end
    DesignationZoneAnimal={addNewRoof=function()end};FBORenderChunk={DIRTY_OBJECT_ADD=1}
    function sendServerCommand()end;function invalidateLighting()end
    function string.contains(value,part)return value:find(part,1,true)~=nil end
    function f.cell:checkHaveRoof(x,y)return __nativeShelter('surfaceCheckRoof',x,y) end
    SAOJavaBridge.worldShelterSurfaces=function(_,body)return body==f.body and __nativeShelter('surfaceSites') or {} end
    SAOJavaBridge.worldShelterCoverNeeds=function()return {} end;SAOJavaBridge.worldShelterAccess=function()return {} end
    SAOJavaBridge.worldShelterSites=function()return {} end
    SAOJavaBridge.worldShelterSurfacePlacementSquare=function(_,body,key,revision)return body==f.body and __nativeShelter('surfacePlacement',key,revision) and f.siteSquare or nil end
    SAOJavaBridge.worldShelterSurfaceCreated=function(_,body,object,entity,x,y,z)return body==f.body and object==f.created and entity==f.entityId and x==12 and y==21 and z==0 and __nativeShelter('surfaceCreated') end
    SAO.Cognition.ensureGameDefaults();assert(SAO.Perception.observeShelterSurfaces(id,f.body))
    SAO.Perception.believedThreatCount=function()return 0 end;SAO.Needs.bleeding=function()return 0 end;SAO.Needs.cold=function()return 0 end
    SAO.Needs.recoveryPreference=function()return 'sleep',{} end;SAO.Needs.recoveryAlternatives=function()return {{id='sleep'}} end
    SAO.Standing.insideClaim=function()return true end
    return f
end
local function floorPlan(f,extra)
    local context=extra or {};context.options=SAO.ResourceProduction.shelterOptions(f.id,f.body,f.purpose and f.purpose.shelterConstruction);context.recoveryKind='sleep';context.fatigue=.65;context.atHours=__hours
    context.position={x=f.body:getX(),y=f.body:getY(),z=f.body:getZ()};context.materialSources=context.materialSources or {}
    local p,step=SAO.ProceduralPlanning.planShelterConstruction(f.id,context);f.purpose,f.step=p,step;return p,step
end
local function floorBuildAction(f)
    local p,s=floorPlan(f);if not s or not SAO.ResourceProduction.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id}) then return nil end
    local q=ISTimedActionQueue.getTimedActionQueue(f.body)
    if q.current and q.current.Type=='ISEquipWeaponAction' then local a=q.current;a:start();a.action.nativeFinished=true;a:perform();a:complete() end
    return q.current,q
end
local function floorAttempt(a)if a then a:start();a.action.nativeFinished=true;a:perform() end end
local function removeFloor(f)
    local removed=__nativeShelter('removeSurface')
    if removed then for index=#f.siteSquare.objects,1,-1 do if f.siteSquare.objects[index]==f.created then table.remove(f.siteSquare.objects,index) end end;f.created=nil end
    return removed
end
function __runMetalFloorKnowledge()
    local R,P,Ctl=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.Controller
    local f=metalFloorFixture('metal-floor-private-reader',false);local b=floorBook(f)
    local context=Ctl.shelterConstructionContext(f.id,f.agent,f.body,{fatigue=.65,hunger=.1,thirst=.1},'sleep')
    local p,step=P.planShelterConstruction(f.id,context);f.purpose,f.step=p,step
    __shelterCheck('floor_actual_unknown_visible_recipe_selects_exact_native_reader',p and step and step.owner=='SAO.Study' and step.recipeName=='MetalFloorLvl1' and step.inputItemId==tostring(b.id) and not __recipeNative('known','MetalFloorLvl1') and not f.nativePayments)
    if not step or step.owner~='SAO.Study' then return end
    local begin=SAO.Study.beginRecipe(f.id,f.body,b,p.id,step.id,step.recipeName)
    __shelterCheck('floor_native_magazine_admission_retains_same_purpose_and_item',begin and f.rec.studyWork and f.rec.studyWork.purposeId==p.id and f.rec.studyWork.itemId==tostring(b.id) and not f.rec.resourceProductionWork)
    if not begin then return end
    local q=ISTimedActionQueue.getTimedActionQueue(f.body);local a=q.current;a:start();a.action.jobDelta=.5;a:update()
    local claim=f.rec.studyWork.id;local kept=Ctl.offerRecovery(f.id,f.agent,f.body,101,{fatigue=.65,hunger=.1,thirst=.1},'sleep')
    __shelterCheck('floor_ordinary_recovery_tick_preserves_actual_owned_read',not kept and q.current==a and f.rec.studyWork.id==claim and not __recipeNative('known','MetalFloorLvl1'))
    if q.current~=a then return end
    a.action.jobDelta=1;a:update();a.action.nativeFinished=true;a:complete();a:perform()
    local reading=SAO.Study.recipeOutcome(f.id,claim)
    __shelterCheck('floor_actual_native_read_effect_teaches_same_person_without_skill_grant',reading and reading.status=='completed' and reading.purposeId==p.id and __recipeNative('known','MetalFloorLvl1') and __recipeNative('reads')==1 and __nativeShelter('skillValue')==0)
    local same,next=floorPlan(f);local started=next and R.begin(f.id,f.body,next,{purposeId=same.id,purposeStepId=next.id});local row=started and __shelterFinish(f)
    __shelterCheck('floor_learned_recipe_returns_to_original_native_construction',same==p and row and row.status=='completed' and row.entityId=='Base.MetalFloorLvl1' and row.purposeId==p.id and f.nativePayments==1)
end
function __runMetalFloorGuards()
    local R,P=SAO.ResourceProduction,SAO.ProceduralPlanning
    local f=metalFloorFixture('metal-floor-policy');local policies=R.shelterOptions(f.id,f.body);local option
    for _,o in ipairs(policies) do if o.entityId=='Base.MetalFloorLvl1' then option=o end end
    __shelterCheck('floor_exact_native_one_charge_policy_is_available_without_skill_gate',option and #option.requirements==3 and option.requirements[1].quantity==1 and option.requirements[2].count==1 and option.requirements[3].quantity==1 and option.requirements[1].recordInput==false and option.requirements[3].recordInput==false and __nativeShelter('skillValue')==0)
    if not option then return end
    local p,s=floorPlan(f);local held=__nativeRoundtrip(s)
    __shelterCheck('floor_saved_exact_three_objects_and_charge_units_survive',#held.inputs==3 and held.inputs[1].quantity==1 and held.inputs[2].mode=='consume' and held.inputs[3].quantity==1)
    local original=s.site.revision;s.site.revision='foreign-current-site';local wrong=R.begin(f.id,f.body,s,{purposeId=p.id,purposeStepId=s.id});s.site.revision=original
    __shelterCheck('floor_stale_placement_revision_cannot_start_native_work',not wrong and not f.nativePayments)
    local a,q=floorBuildAction(f);__nativeShelter('known',false);floorAttempt(a)
    __shelterCheck('floor_actual_knowledge_revocation_before_effect_prevents_payment_attempt',not f.nativePayments and not __nativeShelter('surfaceFloor'))
    __nativeShelter('known',true);R.interrupt(f.id,f.body,'guard-cleanup')
    f=metalFloorFixture('metal-floor-standing');a,q=floorBuildAction(f);local current=SAO.Standing.mayTakeCurrent;SAO.Standing.mayTakeCurrent=function()return false end;floorAttempt(a)
    __shelterCheck('floor_current_standing_revocation_prevents_native_payment',not f.nativePayments and not __nativeShelter('surfaceFloor'));SAO.Standing.mayTakeCurrent=current;R.interrupt(f.id,f.body,'guard-cleanup')
    f=metalFloorFixture('metal-floor-payment');a,q=floorBuildAction(f);floorAttempt(a);local row=f.rec.resourceProductionOutcomes and f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
    __shelterCheck('floor_measured_native_payment_spends_one_charge_and_exact_sheet',row and row.status=='completed' and row.usesBefore['100']==10 and row.usesAfter['100']==9 and row.usesBefore['102']==20 and row.usesAfter['102']==19 and not __nativeShelter('held',101) and __nativeShelter('held',100) and __nativeShelter('held',102))
    __shelterCheck('floor_real_native_part_credit_matches_created_floor',row and row.status=='completed' and #row.parts==1 and row.entityId=='Base.MetalFloorLvl1' and __nativeShelter('surfaceFloor'))
    assert(SAO.Perception.observeShelterSurfaces(f.id,f.body))
    __shelterCheck('floor_healthy_existing_native_surface_is_not_reoffered',#R.shelterOptions(f.id,f.body)==0)
    if row then local face=row.face;row.face,row.site.face='N','N';__shelterCheck('floor_saved_native_north_face_cannot_authenticate_w_only_family',R.outcome(f.id,row.id)==nil);row.face,row.site.face=face,face end
    if row then local flag=row.requirements[1].recordInput;row.requirements[1].recordInput=true
        __shelterCheck('floor_changed_saved_dontrecordinput_cannot_authenticate_result',R.outcome(f.id,row.id)==nil);row.requirements[1].recordInput=flag
    end
    local key=row and row.site.key;local removed=removeFloor(f);SAO.Perception.observeShelterSurfaces(f.id,f.body)
    local fresh=SAO.Perception.shelterSurfaces(f.id,f.body);local found=false;for _,site in ipairs(fresh) do if site.key==key and row and site.revision~=row.site.revision and site.observedAtHours==row.atHours then found=true end end
    __shelterCheck('floor_genuine_fresh_visible_gap_reenters_without_consumed_tombstone',removed and found and #R.shelterOptions(f.id,f.body)>0)
    local preserved=row and not SAO.Perception.consumeShelterSurface(f.id,row);local hidden=SAOJavaBridge.worldShelterSurfaces;SAOJavaBridge.worldShelterSurfaces=function()return nil end;SAO.Perception.observeShelterSurfaces(f.id,f.body);SAOJavaBridge.worldShelterSurfaces=hidden
    __shelterCheck('floor_late_old_receipt_and_unavailable_observation_preserve_fresh_fact',removed and preserved and #SAO.Perception.shelterSurfaces(f.id,f.body)==#fresh)
    f=metalFloorFixture('metal-floor-depletion');__nativeShelter('setUses',100,1);__nativeShelter('setUses',102,1);a,q=floorBuildAction(f);floorAttempt(a);row=f.rec.resourceProductionOutcomes and f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
    __shelterCheck('floor_actual_last_charge_keeps_empty_torch_removes_rods_and_sheet',row and row.status=='completed' and row.usesAfter['100']==0 and row.usesAfter['102']==0 and __nativeShelter('held',100) and not __nativeShelter('held',101) and not __nativeShelter('held',102))
end
function __runMetalFloorLifecycle()
    local R=SAO.ResourceProduction
    local f=metalFloorFixture('floor-saved-interruption');local a,q=floorBuildAction(f);if not a then __shelterCheck('floor_saved_native_work_holds_owned_cancellation_ack',false);return end
    a:start();f.body.holdCancellation=true;local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;f.purpose=saved.proceduralPlanning.purposes[f.purpose.id];__reloadProduction()
    local retired=R.reconcileSaved(f.id,f.body)
    __shelterCheck('floor_saved_native_work_holds_owned_cancellation_ack',not retired and saved.resourceProductionWork and q.current==a and f.purpose.admission and not f.nativePayments)
    f.body.holdCancellation=false;retired=R.reconcileSaved(f.id,f.body);local row=saved.resourceProductionOutcomes and saved.resourceProductionOutcomes[#saved.resourceProductionOutcomes]
    __shelterCheck('floor_saved_native_ack_retires_truthful_interruption',retired and row and row.status=='interrupted' and #row.parts==0 and not row.nativeCompleted and not f.purpose.admission)
    f=metalFloorFixture('floor-effect-before-ack');a,q=floorBuildAction(f);local completed=q.onCompleted;function q:onCompleted(action)if action==a then return end;return completed(self,action) end;floorAttempt(a)
    print('FLOOR_ACK payment='..tostring(f.nativePayments)..' floor='..tostring(__nativeShelter('surfaceFloor'))..' claim='..tostring(f.rec.resourceProductionWork~=nil)..' current='..tostring(q.current==a)..' admission='..tostring(f.purpose.admission~=nil))
    __shelterCheck('floor_paid_measured_effect_keeps_exact_claim_until_ack',f.nativePayments==1 and __nativeShelter('surfaceFloor') and f.rec.resourceProductionWork and q.current==a and f.purpose.admission~=nil)
    __nativeShelter('known',false);R.tick(f.id,f.body);q.onCompleted=completed;completed(q,a);R.tick(f.id,f.body);row=f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
    __shelterCheck('floor_delayed_ack_retires_actual_effect_without_new_knowledge_gate',row and row.status=='completed' and not f.rec.resourceProductionWork and not f.purpose.admission and f.nativePayments==1)
    f=metalFloorFixture('floor-saved-feedback');a,q=floorBuildAction(f);local feedback=SAO.Cognition.shelterOutcome;SAO.Cognition.shelterOutcome=function()return false,'temporary-private-refusal' end;floorAttempt(a);row=f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes]
    __shelterCheck('floor_physical_result_and_purpose_retire_without_private_feedback',row and row.status=='completed' and row.purposeDelivered and not row.experienceDelivered and not f.rec.resourceProductionWork and not f.purpose.admission)
    saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;SAO.Cognition.shelterOutcome=feedback;__reloadProduction();R.reconcileSaved(f.id,f.body);R.reconcileSaved(f.id,f.body)
    __shelterCheck('floor_saved_private_feedback_delivers_actual_build_once',saved.cognition and #saved.cognition.experiences==1 and saved.cognition.experiences[1].entityId=='Base.MetalFloorLvl1' and saved.cognition.models.ordinary.revision==1 and saved.cognition.models.associative.revision==1)
    f=metalFloorFixture('floor-foreign-successor');a,q=floorBuildAction(f);a:start();local successor={character=f.body,Type='foreign-successor',isValidStart=function()return true end,begin=function()end};q.queue={successor};q.current=successor;R.interrupt(f.id,f.body,'successor')
    __shelterCheck('floor_saved_claim_cannot_cancel_foreign_successor_queue',q.current==successor and q.queue[1]==successor and not f.nativePayments)
end

local floorResourceContext=SAO.Controller.resourceContext
local function floorAcquisitionFixture(id,manual)
    local f=metalFloorFixture(id);f.agent.state='IDLE';if manual then __nativeShelter('known',false) end;f.material=manual and floorBook(f) or f.materialById[101]
    local materialId=manual and 901 or 101;local materialType=manual and 'Base.MetalworkMag1' or 'Base.SmallSheetMetal';local category=manual and 'shelter-manual' or 'small-sheet-metal'
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
    SAO.Controller.resourceContext=floorResourceContext;SAO.Standing.insideClaim=function()return true end
    SAO.Locomotion.tick=function(pid)
        local job=SAO.Locomotion.jobs[pid];local arrived=__nativeShelter('sceneMove',job.goal.x..','..job.goal.y..','..job.goal.z)
        local pos=__nativeShelter('scenePosition');f.body.x,f.body.y,f.body.z=pos.x,pos.y,pos.z;f.body.here=f.cell:getGridSquare(math.floor(pos.x),math.floor(pos.y),pos.z) or __shelterSquare(f,math.floor(pos.x),math.floor(pos.y))
        if arrived or (pos.x-job.goal.x)^2+(pos.y-job.goal.y)^2<=.35^2 and pos.z==job.goal.z then job.done,job.result=true,'arrived' end
    end
    assert(SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(f.snapshot())));return f
end


function __runMetalFloorAcquisition()
    local Ctl,P,WS,SU,R=SAO.Controller,SAO.ProceduralPlanning,SAO.WorldSources,SAO.SourceUse,SAO.ResourceProduction
    for _,manual in ipairs({false,true}) do
        local prefix=manual and 'manual' or 'sheet';local f=floorAcquisitionFixture('floor-source-'..prefix,manual)
        local category=manual and 'shelter-manual' or 'small-sheet-metal';local itemId=manual and 901 or 101;local itemType=manual and 'Base.MetalworkMag1' or 'Base.SmallSheetMetal'
        assert(SAO.Perception.learnInspectedSource(f.id,f.place,f.sourceId,100,'native-container-inspection'))
        local begun=Ctl.tryShelterConstruction(f.id,f.agent,f.body,100,{fatigue=.65,hunger=.1,thirst=.1},'sleep');local p,step=P.shelterPurpose(f.id);f.purpose,f.step=p,step
        local reservation=WS.pendingActionFor(f.id)
        local function sourceCheck(name,value)__shelterCheck('floor_'..prefix..'_'..name,value) end
        sourceCheck('ordinary_private_source_admission_keeps_exact_native_item',begun and reservation and reservation.category==category and reservation.itemId==itemId and reservation.itemType==itemType and reservation.purposeId==p.id and not f.nativePayments)
        if reservation then
            SAO.Locomotion.tick(f.id);local movement=SU.onMovementDone(f.id,f.body,'arrived')
            local a=ISTimedActionQueue.getTimedActionQueue(f.body).current;if a then a.getNotFullFloorSquare=function()return nil end;a.playTransferCompleteSound=function()end;a:start();a.action.nativeFinished=true;a:perform() end
            local completed=SU.tick(f.id,f.body);local receipt=WS.actionOutcome(reservation.id,f.id)
            sourceCheck('native_transfer_preserves_actor_object_quantity_and_unit',movement=='using' and completed=='completed' and receipt and receipt.itemId==itemId and receipt.itemType==itemType and receipt.quantityUnit=='item' and receipt.observedQuantity==1 and f.inventory:contains(f.material) and not f.source:contains(f.material) and (manual and __nativeShelter('manualHeld') or not manual and __nativeShelter('held',itemId)))
            sourceCheck('canonical_acquisition_continues_retained_floor_concern',receipt and P.consumeSourceResult(receipt) and not p.admission and p.status~='completed')
            f.agent.state='IDLE'
            if manual then
                begun=Ctl.tryShelterConstruction(f.id,f.agent,f.body,101,{fatigue=.65,hunger=.1,thirst=.1},'sleep');a=ISTimedActionQueue.getTimedActionQueue(f.body).current
                if a then a:start();a.action.jobDelta=1;a:update();a.action.nativeFinished=true;a:complete();a:perform() end
                local reading=f.rec.studyWork and SAO.Study.recipeOutcome(f.id,f.rec.studyWork.id)
                sourceCheck('actual_acquired_magazine_teaches_original_floor_recipe',begun and reading and reading.status=='completed' and reading.purposeId==p.id and __recipeNative('known','MetalFloorLvl1') and __recipeNative('reads')==1)
            end
            assert(__nativeShelter('sceneMove','11.5,21.5,0'));measuredPosition(f);f.agent.state='IDLE'
            begun=Ctl.tryShelterConstruction(f.id,f.agent,f.body,102,{fatigue=.65,hunger=.1,thirst=.1},'sleep');local row=begun and f.rec.resourceProductionWork and __shelterFinish(f)
            sourceCheck('private_acquisition_unlocks_original_native_floor_payment',row and row.status=='completed' and row.purposeId==p.id and row.entityId=='Base.MetalFloorLvl1' and f.nativePayments==1)
        end
    end
end

local function repeatSheet(f)
    local id=__nativeShelter('addRepeatSheet');local sheet=__boardingItem('SmallSheetMetal',id,f.inventory)
    function sheet:getFluidContainer()return nil end;function sheet:getFluidContainerFromSelfOrWorldItem()return nil end;function sheet:hasTag()return false end
    f.inventory.items[#f.inventory.items+1]=sheet;f.materialById[id]=sheet;f.materials={f.materialById[100],sheet,f.materialById[102]}
    return sheet
end
function __runMetalFloorRepeat()
    local R,P=SAO.ResourceProduction,SAO.ProceduralPlanning
    for _,upper in ipairs({false,true}) do
        local mode=upper and 'upper' or 'ground';local function repeatCheck(name,value)__shelterCheck('floor_repeat_'..mode..'_'..name,value) end
        local f
        if upper then
            __nativeShelter('known',true);__nativeShelter('skill',0);f=__shelterFixture('floor-repeat-upper','W','Base.MetalFloorLvl1');f.surfaceNeedsSetup=true;f.stopAfterFloor=true;f.checkPrefix='floor_repeat_upper_'
            for _,item in ipairs(f.materials) do function item:getCurrentUses()return __nativeShelter('uses',self:getID()) end end;function f.body:isRecipeActuallyKnown(name)return __nativeShelter('actualKnown',name) end
            __runShelterSurfaceUpper(f)
        else f=metalFloorFixture('floor-repeat-ground');local a=floorBuildAction(f);floorAttempt(a) end
        local first=f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes];local purposeId=f.purpose.id
        repeatCheck('first_authentic_floor_retains_original_unfinished_purpose',first and first.status=='completed' and first.purposeId==purposeId and f.purpose.status~='completed')
        local removed=removeFloor(f);SAO.Perception.observeShelterSurfaces(f.id,f.body);local nextSite
        for _,site in ipairs(SAO.Perception.shelterSurfaces(f.id,f.body)) do if site.key==first.siteKey then nextSite=site end end
        repeatCheck('same_clock_destroyed_gap_has_distinct_personal_revision',removed and nextSite and nextSite.revision~=first.siteRevision and nextSite.observedAtHours==first.atHours and not SAO.Perception.consumeShelterSurface(f.id,first))
        repeatSheet(f);local saved=__nativeRoundtrip(f.rec);__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;f.purpose=saved.proceduralPlanning.purposes[purposeId]
        local p,step=floorPlan(f);local started=step and step.owner=='SAO.ResourceProduction' and R.begin(f.id,f.body,step,{purposeId=p.id,purposeStepId=step.id})
        repeatCheck('saved_retained_purpose_admits_fresh_exact_floor_work',p==f.purpose and p.id==purposeId and step and step.site and nextSite and step.site.revision==nextSite.revision and started and f.rec.resourceProductionWork.sequence==2)
        local row=started and __shelterFinish(f)
        repeatCheck('second_native_payment_preserves_history_and_once_feedback',row and row.status=='completed' and row.purposeId==purposeId and row.id~=first.id and f.nativePayments==2 and #p.shelterConstruction.constructionResults==2 and row.usesBefore['100']==9 and row.usesAfter['100']==8 and row.usesBefore['102']==19 and row.usesAfter['102']==18 and first.experienceDelivered and row.experienceDelivered)
    end
end
function __runMetalFloorCapacity()
    local R=SAO.ResourceProduction;local f=metalFloorFixture('floor-capacity');local feedback=SAO.Cognition.shelterOutcome;local pendingId
    SAO.Cognition.shelterOutcome=function(id,row)if row.id==pendingId or not pendingId then return false,'oldest-private-feedback-refusal' end;return feedback(id,row) end
    local a,q=floorBuildAction(f);pendingId=f.rec.resourceProductionWork.id;floorAttempt(a);local oldest=f.rec.resourceProductionOutcomes[1]
    assert(oldest and oldest.status=='completed' and oldest.purposeDelivered and not oldest.experienceDelivered)
    assert(removeFloor(f));SAO.Perception.observeShelterSurfaces(f.id,f.body);repeatSheet(f)
    -- Thirty-one genuine admitted native attempts retire on their exact cancellation ACK.
    -- They add capacity pressure without manufactured completed physical effects.
    for n=1,31 do a,q=floorBuildAction(f);assert(a,'capacity admission '..n);assert(R.interrupt(f.id,f.body,'capacity-native-cancellation-'..n));end
    __shelterCheck('floor_capacity_has_authentic_oldest_pending_and_31_native_interruptions',#f.rec.resourceProductionOutcomes==32 and f.rec.resourceProductionOutcomes[1]==oldest and not oldest.experienceDelivered and f.nativePayments==1)
    a,q=floorBuildAction(f);floorAttempt(a);R.tick(f.id,f.body)
    local saved=__nativeRoundtrip(f.rec)
    __shelterCheck('floor_capacity_paid_ack_preserves_pending_oldest_and_live_claim',#f.rec.resourceProductionOutcomes==32 and f.rec.resourceProductionOutcomes[1]==oldest and not oldest.experienceDelivered and f.rec.resourceProductionWork and f.purpose.admission and q.current~=a and f.nativePayments==2 and saved.resourceProductionOutcomes[1].id==pendingId and saved.resourceProductionOutcomes[1].experienceDelivered~=true)
    SAO.Cognition.shelterOutcome=feedback;R.tick(f.id,f.body);R.tick(f.id,f.body)
    local row=f.rec.resourceProductionOutcomes[#f.rec.resourceProductionOutcomes];local count=0;for _,event in ipairs(f.rec.cognition.experiences) do if event.sourceId==pendingId or event.id==pendingId or event.outcomeId==pendingId then count=count+1 end end
    __shelterCheck('floor_capacity_once_feedback_replay_releases_truthful_native_publication',oldest.experienceDelivered and not f.rec.resourceProductionWork and not f.purpose.admission and row.status=='completed' and row.sequence==33 and f.nativePayments==2 and #f.rec.resourceProductionOutcomes==32 and #f.rec.cognition.experiences==2 and f.rec.cognition.models.ordinary.revision==2 and f.rec.cognition.models.associative.revision==2)
end

function __runMetalFloorMixed(legacyOnly)
    local R,P,W=SAO.ResourceProduction,SAO.ProceduralPlanning,SAO.WorldSources
    local function mixedCheck(name,value)if not legacyOnly then __shelterCheck(name,value) end end
    local f=metalFloorFixture(legacyOnly and 'floor-mixed-water-legacy' or 'floor-mixed-water');local feedback=SAO.Cognition.shelterOutcome;local pendingId
    SAO.Cognition.shelterOutcome=function(id,row)if row.id==pendingId or not pendingId then return false,'oldest-floor-feedback-refusal' end;return feedback(id,row) end
    local a,q=floorBuildAction(f);pendingId=f.rec.resourceProductionWork.id;floorAttempt(a);local oldest=f.rec.resourceProductionOutcomes[1]
    assert(oldest and oldest.status=='completed' and oldest.purposeDelivered and not oldest.experienceDelivered)
    assert(removeFloor(f));SAO.Perception.observeShelterSurfaces(f.id,f.body);repeatSheet(f)
    for n=1,31 do a,q=floorBuildAction(f);assert(a);assert(R.interrupt(f.id,f.body,'mixed-native-cancellation-'..n)) end
    mixedCheck('mixed_actual_floor_and_31_native_cancellations_fill_ledger',#f.rec.resourceProductionOutcomes==32 and not oldest.experienceDelivered and f.nativePayments==1)
    assert(__nativeShelter('waterSetup'))
    local bottle=__boardingItem('WaterBottle',4000,f.inventory);local fluid={}
    function fluid:getAmount()return __nativeShelter('waterAmount') end;function fluid:getCapacity()return __nativeShelter('waterCapacity') end
    function fluid:isWaterSource()return __nativeShelter('waterClean') end;function fluid:isPoisonous()return false end;function fluid:isTainted()return false end
    function bottle:getFluidContainer()return fluid end;function bottle:getFluidContainerFromSelfOrWorldItem()return fluid end;function bottle:canStoreWater()return true end
    function bottle:isEquipped()return false end;function bottle:syncItemFields()end;function bottle:setBeingFilled(value)self.beingFilled=value end
    function bottle:getFillFromTapSound()return nil end;function bottle:getPourType()return 'bottle' end;function bottle:getStaticModel()return 'WaterBottle' end
    f.inventory.items[#f.inventory.items+1]=bottle
    for _,item in ipairs(f.inventory.items) do if item~=bottle then function item:canStoreWater()return false end end end
    function f.body:getFreeInventoryCapacity()return 10 end;function f.body:hasFullInventory()return false end
    function f.body:isEquipped()return false end;function f.body:isEquippedClothing()return false end;function f.body:isSecondaryHandItem()return false end
    function f.body:playSound(sound)return f.emitter:playSound(sound) end;function f.body:stopOrTriggerSound(sound)f.emitter:stopOrTriggerSound(sound) end
    local tap={};function tap:getProperties()return nil end;function tap:getFluidAmount()return __nativeShelter('waterSource') end;function tap:hasFluid()return self:getFluidAmount()>0 end
    function tap:transferFluidTo(destination,amount)assert(destination==fluid);return __nativeShelter('waterTransfer',amount) end
    function tap:getSquare()return f.body:getCurrentSquare() end
    local sourceId='F:'..f.id..'-native-tap';local sourceX,sourceY=math.floor(f.body:getX()),math.floor(f.body:getY());local revision='water-before'
    local function snapshot()
        local amount=__nativeShelter('waterSource');return 'H|protocol=SAOWS1|status=OBSERVED|mode=loaded|cx=1|cy=2|sources=1\nS|id='..sourceId..'|fp=native-mixed-tap|rev='..revision..'|kind=fluid|x='..sourceX..'|y='..sourceY..'|z=0|building=1|explored=1|state=available|access=unknown|container=sink|plumbing=connected|q:water='..amount..'\nI|source='..sourceId..'|id=0|type=|uses=0|amount='..amount..'|fluid=Water|poison=0|rotten=0|cats=water\nE'
    end
    SAOJavaBridge.observeWorldChunk=function()return snapshot() end;assert(W.observeChunk(1,2))
    local place={id='source:'..sourceId,sourceId=sourceId,cx=sourceX+.5,cy=sourceY+.5,z=0,minX=sourceX,minY=sourceY,maxX=sourceX+1,maxY=sourceY+1}
    print('MIXED_SOURCE fact='..tostring(W.beliefFact(sourceId))..' parsed='..tostring(#W.parse(snapshot()).ordered)..' source='..sourceId..' placeSource='..place.sourceId);for k,v in pairs(W.parse(snapshot()).sources) do print('MIXED_PARSED '..k) end
    assert(SAO.Perception.learnInspectedSource(f.id,place,sourceId,100,'native-fluid-inspection'))
    SAOJavaBridge.worldRefillTarget=function(_,body,id,fp,rev,x,y,z)return body==f.body and id==sourceId and fp=='native-mixed-tap' and rev==revision and x==sourceX and y==sourceY and z==0 and 'READY:'..sourceX..':'..sourceY..':0' or 'SOURCE_CHANGED' end
    SAOJavaBridge.worldRefillObject=function(_,body,id,fp,rev,x,y,z)return SAOJavaBridge:worldRefillTarget(body,id,fp,rev,x,y,z):sub(1,6)=='READY:' and tap or nil end
    SAOJavaBridge.worldRefillValid=function(_,body,target,id,fp,x,y,z)return body==f.body and target==tap and id==sourceId and fp=='native-mixed-tap' and x==sourceX and y==sourceY and z==0 and tap:hasFluid() end
    local wp,step=P.planResource(f.id,{category='water',pressure=.7,atHours=__hours,needs={fatigue=.1,health=1},carriedWater=0,carriedReady=0,carriedRaw=0,sources={},productionOptions=R.options(f.id,f.body,'water')})
    assert(wp and step and step.productionKind=='refill-water','actual mixed refill plan');assert(R.begin(f.id,f.body,step,{purposeId=wp.id,purposeStepId=step.id}))
    q=ISTimedActionQueue.getTimedActionQueue(f.body);a=q.current;local completed=q.onCompleted;function q:onCompleted(action)if action==a then return end;return completed(self,action) end
    a:start();a.action.nativeFinished=true;assert(a:complete());a:perform();R.tick(f.id,f.body)
    mixedCheck('mixed_native_refill_measures_water_and_holds_exact_ack',__nativeShelter('waterAmount')==1 and __nativeShelter('waterSource')==1 and __nativeShelter('waterTransfers')==1 and __nativeShelter('waterHeld') and q.current==a and f.rec.resourceProductionWork and wp.admission~=nil and #f.rec.resourceProductionOutcomes==32)
    q.onCompleted=completed;completed(q,a);local status=R.tick(f.id,f.body)
    mixedCheck('mixed_water_preserves_pending_floor_and_claim_at_capacity',status=='awaiting-outcome-capacity' and f.rec.resourceProductionOutcomes[1]==oldest and not oldest.experienceDelivered and #f.rec.resourceProductionOutcomes==32 and f.rec.resourceProductionWork and wp.admission~=nil and q.current~=a and __nativeShelter('waterTransfers')==1)
    if not f.rec.resourceProductionWork then SAO.Cognition.shelterOutcome=feedback;return end
    local work=f.rec.resourceProductionWork;local checkpoint=work.terminalReceipt;assert(checkpoint)
    if not legacyOnly then local used=__nativeShelter('waterPostTerminalUse');mixedCheck('mixed_native_post_terminal_volume_change_preserves_original_measurement',used and __nativeShelter('waterAmount')==.75 and checkpoint.receipt.afterAmount==1 and checkpoint.receipt.nativeGain==1 and __nativeShelter('waterTransfers')==1) end
    __hours=__hours+.6;local interrupted=R.interrupt(f.id,f.body,'after-terminal-time-limit')
    mixedCheck('mixed_completed_refill_refuses_false_retirement_while_capacity_blocked',not interrupted and f.rec.resourceProductionWork==work and checkpoint.receipt.atHours==work.startedAt and checkpoint.receipt.afterAmount==1 and checkpoint.receipt.nativeGain==1)
    local saved=__nativeRoundtrip(f.rec);if legacyOnly then saved.resourceProductionWork.terminalReceipt=nil end;__records[f.id]=saved;f.rec=saved;f.agent.rec=saved;wp=saved.proceduralPlanning.purposes[wp.id];__reloadProduction()
    local reconciled=R.reconcileSaved(f.id,f.body)
    if legacyOnly then
        SAO.Cognition.shelterOutcome=feedback;R.tick(f.id,f.body);R.tick(f.id,f.body)
        local uncertain=saved.resourceProductionOutcomes[#saved.resourceProductionOutcomes]
        print('MIXED_LEGACY status='..tostring(uncertain.status)..' detail='..tostring(uncertain.detail)..' gain='..tostring(uncertain.nativeGain)..' work='..tostring(saved.resourceProductionWork)..' transfers='..tostring(__nativeShelter('waterTransfers')))
        __shelterCheck('mixed_older_saved_work_without_checkpoint_retires_without_invented_fill_credit',not saved.resourceProductionWork and uncertain.kind=='refill-water' and uncertain.status=='failed' and uncertain.detail=='native-resource-attempt-unavailable-after-reload' and uncertain.nativeCredit==nil and uncertain.nativeGain==0 and __nativeShelter('waterTransfers')==1)
        __hours=100;return
    end
    mixedCheck('mixed_saved_acknowledged_terminal_checkpoint_retains_exact_paid_result',not reconciled and saved.resourceProductionWork and saved.resourceProductionWork.terminalReceipt.nativeAcknowledged and saved.resourceProductionWork.terminalReceipt.receipt.afterAmount==1 and saved.resourceProductionOutcomes[1].id==pendingId and __nativeShelter('waterTransfers')==1)
    local successor={character=f.body,Type='foreign-successor',isValidStart=function()return true end,begin=function()end};q.queue={successor};q.current=successor;reconciled=R.reconcileSaved(f.id,f.body)
    mixedCheck('mixed_rehydrated_claim_does_not_retire_foreign_current_action',not reconciled and q.current==successor and q.queue[1]==successor and saved.resourceProductionWork~=nil and __nativeShelter('waterTransfers')==1);q.queue={};q.current=nil
    checkpoint=saved.resourceProductionWork.terminalReceipt;local guarded=true
    for _,key in ipairs({'bodyToken','world','nativeOwner'}) do local before=checkpoint[key];checkpoint[key]='foreign';guarded=guarded and not R.reconcileSaved(f.id,f.body) and saved.resourceProductionWork~=nil;checkpoint[key]=before end
    for _,key in ipairs({'actorId','purposeId','purposeStepId','sourceId','sourceRevision','fingerprint','itemId','itemType','startedAt','beforeAmount'}) do local before=checkpoint.receipt[key];checkpoint.receipt[key]=type(before)=='number' and before+1 or 'foreign';guarded=guarded and not R.reconcileSaved(f.id,f.body) and saved.resourceProductionWork~=nil;checkpoint.receipt[key]=before end
    mixedCheck('mixed_saved_checkpoint_rejects_foreign_actor_world_admission_source_and_item',guarded and #saved.resourceProductionOutcomes==32 and __nativeShelter('waterTransfers')==1)
    SAO.Cognition.shelterOutcome=feedback;R.reconcileSaved(f.id,f.body);R.tick(f.id,f.body);R.tick(f.id,f.body)
    local row=saved.resourceProductionOutcomes[#saved.resourceProductionOutcomes]
    mixedCheck('mixed_old_floor_feedback_replay_releases_saved_water_once',not saved.resourceProductionWork and not wp.admission and wp.status=='completed' and row.kind=='refill-water' and row.sequence==33 and row.status=='completed' and row.beforeAmount==0 and row.afterAmount==1 and row.nativeGain==1 and __nativeShelter('waterAmount')==.75 and row.held and row.clean and row.atHours==100 and __nativeShelter('waterTransfers')==1 and #saved.cognition.experiences==2 and saved.cognition.models.ordinary.revision==2 and saved.cognition.models.associative.revision==2)
    __hours=100;__runMetalFloorMixed(true)
end
