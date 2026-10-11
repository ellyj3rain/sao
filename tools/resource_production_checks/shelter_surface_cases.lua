-- Existing native scene and actual registered floor recipe/build callback.
function __runShelterSurfaceFirst(grade)
    grade=grade or 1;local entity='Base.WoodFloorLvl'..grade
    local f=__shelterFixture('surface-first-'..grade,'W',entity)
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
    local f=provided or __shelterFixture('surface-upper','W','Base.WoodFloorLvl1');__shelterControllerSetup(f)
    local paid=f.nativePayments or 0;local learned=#(f.rec.cognition and f.rec.cognition.experiences or {})
    if not provided then assert(__nativeShelter('surfaceRoofSceneSetup',f.id)) end;measuredPosition(f)
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
    __shelterCheck('native_missing_cover_and_visible_stair_are_real',#before==1 and #access==1 and not __nativeShelter('surfaceLowerRoof')
        and access[1].landingObserved==false and access[1].landingZ==1 and #__nativeShelter('surfaceSites')==0)
    local admitted=Ctl.offerRecovery(f.id,f.agent,f.body,100,SAO.Needs.read(f.body),'sleep')
    local purpose,step=P.shelterPurpose(f.id);print('UPPER_PLAN admitted='..tostring(admitted)..' state='..f.agent.state..' verb='..tostring(step and step.verb))
    __shelterCheck('ordinary_shelter_concern_inquires_without_upper_truth',admitted and f.agent.shelterRoute and step.verb=='inspect'
        and purpose.shelterConstruction.origin.z==0 and not f.rec.resourceProductionWork)
    if f.agent.shelterRoute then SAO.Locomotion.tick(f.id);__shelterControllerTick(101);Ctl.finishShelterMovement(f.id,f.agent,f.body) end
    __shelterCheck('same_body_native_stairs_reach_actual_upper_level',f.body.z>=1 and f.body:getCurrentSquare():getZ()==1
        and f.agent.state=='IDLE' and purpose.status~='completed' and purpose.shelterConstruction.origin.z==0)
    local native=__nativeShelter('surfaceSites');local selected
    for _,row in ipairs(native) do if row.x==12 and row.y==21 and row.z==1 then selected=row end end
    print('UPPER_OBSERVED rows='..#native..' target='..tostring(selected and selected.key)..' approach='..tostring(selected and selected.approachX)..','..tostring(selected and selected.approachY))
    if selected then assert(__nativeShelter('sceneMove',(selected.approachX+.5)..','..(selected.approachY+.5)..',1'));measuredPosition(f);f.approach=f.body.here end
    admitted=Ctl.offerRecovery(f.id,f.agent,f.body,200,SAO.Needs.read(f.body),'sleep')
    local row=f.rec.resourceProductionWork and __shelterFinish(f)
    print('UPPER_RESULT admitted='..tostring(admitted)..' row='..tostring(row and row.status)..' detail='..tostring(row and row.detail))
    __shelterCheck('native_upper_floor_creates_lower_cover_under_same_purpose',admitted and row and row.status=='completed'
        and row.kind=='build-shelter-surface' and row.purposeId==purpose.id and row.inputsConsumed and row.toolRetained
        and f.nativePayments==paid+1 and __nativeShelter('surfaceFloor') and __nativeShelter('surfaceLowerRoof')
        and purpose.status~='completed' and purpose.shelterConstruction.origin.z==0 and not f.rec.recoveryExperiences)
    f.agent.state='IDLE';admitted=Ctl.offerRecovery(f.id,f.agent,f.body,300,SAO.Needs.read(f.body),'sleep')
    local _,returnStep=P.shelterPurpose(f.id)
    __shelterCheck('ordinary_shelter_work_returns_to_original_use_level',admitted and f.agent.shelterRoute and returnStep.verb=='return'
        and returnStep.z==0 and purpose.shelterConstruction.origin.z==0)
    if f.agent.shelterRoute then SAO.Locomotion.tick(f.id);__shelterControllerTick(301);Ctl.finishShelterMovement(f.id,f.agent,f.body) end
    __shelterCheck('native_stairs_return_same_body_without_recovery_credit',f.body:getCurrentSquare():getZ()==0 and f.agent.state=='IDLE'
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
    __shelterCheck('upper_cover_repair_reaches_ordinary_native_shelter_use',admitted and used.kind=='use-shelter' and used.status=='completed'
        and used.purposeId==purpose.id and used.opened and used.crossedOut and used.crossedIn and used.closedDoor and used.enclosureConfirmed
        and __nativeShelter('scenePassages')==2 and not __nativeShelter('sceneOpen') and purpose.shelterConstruction.origin.z==0
        and not f.rec.recoveryExperiences and f.nativePayments==paid+3)
    f.agent.state='IDLE';admitted=Ctl.offerRecovery(f.id,f.agent,f.body,600,SAO.Needs.read(f.body),'sleep')
    if admitted and f.agent.recoveryRoute then SAO.Locomotion.tick(f.id);__shelterControllerTick(601);Ctl.finishRecoveryPlaceMovement(f.id,f.agent,f.body) end
    local place=f.rec.recoveryIntent and f.rec.recoveryIntent.place;local preparing=SAO.Needs.pollRecovery(f.id,f.body)
    local beforeFatigue=SAO.Needs.read(f.body).fatigue
    local measured=preparing=='running' and __nativeShelter('sceneSleepTicks');__hours=__hours+.1
    local result=SAO.Needs.pollRecovery(f.id,f.body)
    __shelterCheck('surface_repair_finishes_original_lower_shelter_recovery',admitted and place and place.z==0 and place.key~='ground:10:20:0'
        and measured and result=='completed' and purpose.status=='completed' and #f.rec.recoveryExperiences==1
        and f.rec.recoveryExperiences[1].sourceId==place.key and f.rec.recoveryExperiences[1].beforeValue==beforeFatigue
        and f.rec.recoveryExperiences[1].afterValue<beforeFatigue and __nativeShelter('sceneGroundClear',place.x..','..place.y..','..place.z))
    local pendingMovement=0
    for _,movement in ipairs(f.rec.proceduralPlanning.shelterMovementResults or {}) do if not movement.experienceDelivered then pendingMovement=pendingMovement+1 end end
    __shelterCheck('surface_construction_use_and_recovery_feedback_stay_independent',#f.rec.cognition.experiences==learned+7+reobserved-pendingMovement
        and f.rec.cognition.experiences[learned+1].kind=='shelter-movement'
        and f.rec.cognition.experiences[learned+2].entityId=='Base.WoodFloorLvl1'
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
