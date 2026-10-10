-- Installed action/queue execution with controlled geometry, bodies and clock.
-- The optional last treatment forwards material/window effects to real Java receivers.
SAO = { History = {countyHours=function() return __hours end},
    Identity = {get=function(id) return __records[id] end},
    Body = {active={}, foreign={}}, Needs={}, Standing={} }
__hours, __records, __checks = 100, {}, {}
Events = setmetatable({}, {__index=function(t,k)
    local callbacks={}
    local event={callbacks=callbacks,Add=function(f) callbacks[#callbacks+1]=f end,
        Remove=function(f) for i=#callbacks,1,-1 do if callbacks[i]==f then table.remove(callbacks,i) end end end}
    rawset(t,k,event); return event end})
function __fireWindowRetry()
    for _,f in ipairs(Events.OnTick.callbacks) do if f==SAO.WindowRepair.retryCancellations then f() end end
end
function require(name)
    if name=='RepairableWindows/AddWindowAction' then return RepairableWindowsAddWindowAction end
    return {}
end
function instanceof(o,name) return type(o)=='table' and o.kind==name end
function getWorld() return __world end
function getCell() return __world:getCell() end
IsoDirections={N='N',W='W',NW='NW',NE='NE',SW='SW',SE='SE'}
IsoFlagType={cutN='cutN',cutW='cutW',collideN='collideN',collideW='collideW'}
function sendRemoveItemFromContainer(inv,item) inv.sent=(inv.sent or 0)+1 end
ISLogSystem={logAction=function() end}
GameTime={getInstance=function() return {getTimeOfDay=function() return 12 end} end}
MoodleType={UNHAPPY=1,DRUNK=2}
BodyPartType={Hand_L=1,ForeArm_R=2,ToIndex=function(n) return n end,FromIndex=function(n) return n end}
LuaTimedActionNew={new=function(action,body)
    return {valid=function() return action:isValid()==true end,
        waitToStart=function() return action:waitToStart() end,
        isStarted=function() return true end,forceStop=function()
        body.stopRequests=(body.stopRequests or 0)+1
        if body.holdCancellation then return end
        action:stop()
    end}
end}
function table.wipe(t) for key in pairs(t) do t[key]=nil end end
for _,name in ipairs({'ClimbThroughWindowState','ClimbOverFenceState','ClimbOverWallState',
    'ClimbSheetRopeState','ClimbDownSheetRopeState','CloseWindowState','OpenWindowState'}) do
    local state={};_G[name]={instance=function() return state end}
end
SAO.Body.get=function(id) return SAO.Body.active[id] end
SAO.Body.isTransitioning=function(rec) return rec.zaoTransferPending~=nil or rec.crossedTransferPending~=nil end
SAO.Standing.fallHasCome=function() return __fall~=false end
SAO.Standing.claimOf=function(id) return __records[id] and __records[id].claim end
SAO.Standing.groupOf=function(id) return 'home' end
SAO.Standing.insideClaim=function(id,x,y)
    local c=SAO.Standing.claimOf(id)
    return c and x>=c.minX and x<=c.maxX and y>=c.minY and y<=c.maxY
end
SAOJavaBridge={isShell=function(_,body) return body.shell~=false end,
    hasPendingActions=function(_,body) return #ISTimedActionQueue.getTimedActionQueue(body).queue>0 end,
    carriesTheMakings=function(_,body) return body.boardKit==true end,
    findBoardable=function() return '0,0,0' end,
    boardWindow=function() error('eager boarding is retired') end,
    constructionMaterialCount=function(_,body,category)
        if category=='glass-pane' then return body:getInventory():getFirstType('RepairableWindows.LargeGlassPane') and 1 or 0 end
        return body.boardKit and (category=='nails' and 2 or 1) or 0
    end}
SAO.Build={offer=function(id,body,key)
    local entry='barricade:0:0:0:0:true'
    if body.boardKit and (key==nil or key==entry) then return {entryKey=entry} end
end,destination=function(id,body,offer) return {key=offer.entryKey,x=0,y=0,z=0} end,
    begin=function(id,body,offer,purposeId,stepId)
        body.boardingAdmitted={purposeId=purposeId,stepId=stepId,entryKey=offer.entryKey};return true
    end,interrupt=function() return true end,forget=function() return true end}
SAO.Needs.queueVerified=function(action)
    if action.character.queueRefused then return false end
    ISTimedActionQueue.add(action)
    return ISTimedActionQueue.hasAction(action)
end
SAO.Needs.needsAmmo=function() return false end
SAO.Needs.findGear=function() return nil end
SAO.Needs.approach=function() return nil end
SAO.Perception={nearestBelievedZombie=function(id) return __records[id] and __records[id].threat end}
SAO.Disposition={fleeDistance=function() return 5 end}

local function list(values)
    return {size=function() return #values end,get=function(_,i) return values[i+1] end,
        contains=function(_,v) for _,x in ipairs(values) do if x==v then return true end end return false end}
end
local function check(name,value)
    __checks[#__checks+1]=name..'='..tostring(value==true)
end
local function fixture(id)
    local r={id=id,bodyOwnerToken='token:'..id,
        claim={minX=-2,minY=-2,maxX=3,maxY=3,z=0}}
    __records[id]=r
    local cell={squares={},objects={},added={}}
    function cell:getGridSquare(x,y,z) return self.squares[x..':'..y..':'..z] end
    function cell:getObjectList() return list(self.objects) end
    function cell:getAddList() return list(self.added) end
    local function square(x,y,z)
        local s={x=x,y=y,z=z,objects={},stand=true}
        function s:getX() return self.x end
        function s:getY() return self.y end
        function s:getZ() return self.z end
        function s:canStand() return self.stand end
        function s:getObjects() return list(self.objects) end
        function s:getN() return cell:getGridSquare(x,y-1,z) end
        function s:getW() return cell:getGridSquare(x-1,y,z) end
        function s:getRoom() return nil end
        function s:has(flag) return false end
        function s:DistToProper(body) return (self.x+.5-body:getX())^2+(self.y+.5-body:getY())^2 end
        function s:getAdjacentSquare(dir)
            local offsets={N={0,-1},W={-1,0},NW={-1,-1},NE={1,-1},SW={-1,1},SE={1,1}}
            local offset=offsets[dir];return offset and cell:getGridSquare(x+offset[1],y+offset[2],z)
        end
        cell.squares[x..':'..y..':'..z]=s
        return s
    end
    local here=square(0,0,0)
    square(0,1,0); square(1,0,0); square(0,0,1); square(-1,0,0); square(0,-1,0)
    square(1,1,0)
    local inv={items={},mirror=false}
    function inv:getFirstType(t)
        for _,item in ipairs(self.items) do if item:getFullType()==t then return item end end
    end
    function inv:getFirstTypeEval(t,predicate)
        for _,item in ipairs(self.items) do if item:getFullType()==t and predicate(item) then return item end end
    end
    function inv:contains(item) return list(self.items):contains(item) end
    function inv:containsType(t) return self:getFirstType(t)~=nil end
    function inv:containsTypeRecurse(t) return self:containsType(t) end
    function inv:Remove(item)
        for i,v in ipairs(self.items) do if v==item then table.remove(self.items,i);item.container=nil;break end end
        if self.mirror then __nativeOp('remove') end
    end
    local pane={id=713,container=inv}
    function pane:getID() return self.id end
    function pane:getFullType() return 'RepairableWindows.LargeGlassPane' end
    function pane:getContainer() return self.container end
    function pane:getIsCraftingConsumed() return self.consumed==true end
    inv.items={pane}
    local w={kind='IsoWindow',sq=here,smashed=true,glass=true,index=0,north=true,mirror=false}
    function w:getSquare() return self.sq end
    function w:getObjectIndex() return self.index end
    function w:getNorth() return self.north end
    function w:isSmashed() return self.mirror and __nativeOp('smashed') or self.smashed end
    function w:isGlassRemoved() return self.mirror and __nativeOp('glass') or self.glass end
    function w:setSmashed(v) self.smashed=v;if self.mirror then __nativeOp('setSmashed',v) end end
    function w:setGlassRemoved(v) self.glass=v;if self.mirror then __nativeOp('setGlass',v) end end
    function w:sync() self.synced=(self.synced or 0)+1 end
    here.objects={w}
    local b={kind='IsoGameCharacter',md={SAOPersonId=id,SAOExternalToken=r.bodyOwnerToken},
        inv=inv,here=here,cell=cell,x=.5,y=.5,z=0,dx=1,dy=0,visible=true,exists=true}
    function b:getModData() return self.md end
    function b:getInventory() return self.inv end
    function b:getCell() return self.cell end
    function b:getCurrentSquare() return self.here end
    function b:getX() return self.x end
    function b:getY() return self.y end
    function b:getZ() return self.z end
    function b:getForwardDirectionX() return self.dx end
    function b:getForwardDirectionY() return self.dy end
    function b:CanSee(o) return self.visible end
    function b:isExistInTheWorld() return self.exists end
    function b:isDead() return self.dead==true end
    function b:StopAllActionQueue()
        if self.stopAllThrows then error('controlled native clear failure') end
        if self.started then self.started:forceStop() end
    end
    function b:isAsleep() return false end
    function b:isFarming() return false end
    function b:isTimedActionInstant() return false end
    function b:setIsFarming(v) self.farming=v end
    function b:setTimedActionToRetrigger(v) end
    function b:StartAction(action)
        self.started=action;self.firstNativeValid=action:valid()
        if self.firstNativeValid then action:waitToStart() end
    end
    function b:getMoodles() return {getMoodleLevel=function() return 0 end} end
    function b:getBodyDamage() return {getBodyPart=function() return {getPain=function() return 0 end} end} end
    function b:getTimedActionTimeModifier() return 1 end
    function b:faceThisObject(o) end
    function b:shouldBeTurning() return false end
    cell.objects={b}
    SAO.Body.active[id]=b
    __world={name='controlled-'..id,getWorld=function(self) return self.name end,getCell=function() return cell end}
    return {id=id,rec=r,body=b,window=w,inventory=inv,pane=pane,cell=cell,square=here,
        agent={state='IDLE',rec=r,nextGearAt=99999,nextAmmoAt=99999}}
end
__windowFixture=fixture
__windowCheck=check
local function admitted(f)
    local offer=SAO.WindowRepair.offer(f.id,f.body)
    if not offer or not SAO.WindowRepair.begin(f.id,f.body,offer) then error('admission failed '..f.id) end
    return ISTimedActionQueue.getTimedActionQueue(f.body).current
end
__windowAdmitted=admitted
local function interrupted(f,action)
    local noEffect=action:complete()==false and f.window.smashed and f.inventory:contains(f.pane)
    local row=SAO.WindowRepair.outcome(f.id,1)
    return noEffect and row and row.status=='interrupted' and not row.paneConsumed
end
local function plain(value,seen)
    local t=type(value)
    if t~='table' then return t=='string' or t=='number' or t=='boolean' or t=='nil' end
    if getmetatable(value) or seen[value] then return false end
    seen[value]=true
    for k,v in pairs(value) do if not plain(k,seen) or not plain(v,seen) then return false end end
    return true
end

function __runWindowCases()
    local W,P,A=SAO.WindowRepair,SAO.ProceduralPlanning,RepairableWindowsAddWindowAction
    local old=fixture('installed-bad')
    old.inventory.items={}
    local original=A:new(old.body,old.window)
    check('installed_missing_pane_completes_before_material',original:complete()==true
        and not old.window.smashed and old.window.synced==1)
    check('guard_installs_optional_native_api',W.install()==true)
    local f=fixture('controller')
    check('production_fortification_caller_admits',__decideHome(f.id,f.agent,f.body,50,f.rec)==true
        and f.agent.state=='WINDOWREPAIR' and f.agent.taskDeadline>50)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body)
    local a=q.current
    if not a then __windowResults=table.concat(__checks,'\n');return end
    local purpose=f.rec.proceduralPlanning.purposes[f.rec.windowRepairWork.purposeId]
    check('admission_not_completion_or_practice',purpose.cursor==1 and f.window.smashed
        and P.techniqueProfile(f.id).practice[f.rec.windowRepairWork.entryKey]==nil)
    check('planner_rejects_forged_completion',P.recordResult(f.id,purpose.id,{owner='SAO.WindowRepair',
        token='construction:window-repaired',correlationId=f.rec.windowRepairWork.id,status='completed'})==false)
    check('installed_action_start_valid',a:isValidStart()==true and a:isValid()==true and a.maxTime==192)
    __hours=101
    check('native_complete_measured',a:complete()==true and not f.window.smashed and not f.window.glass
        and not f.inventory:contains(f.pane) and f.inventory.sent==1 and f.window.synced==1)
    a:perform()
    local row=W.outcome(f.id,1)
    check('durable_exact_native_outcome',row and row.actorId==f.id and row.sequence==1
        and row.status=='completed' and row.paneConsumed and row.startedAt==100 and row.endedAt==101
        and row.bodyToken==f.rec.bodyOwnerToken and row.workId==f.rec.windowRepairWork.id
        and row.entryKey==f.rec.windowRepairWork.entryKey and row.planningAcknowledged)
    check('native_completion_advances_once',purpose.status=='completed' and purpose.cursor==2
        and P.techniqueProfile(f.id).practice[row.entryKey].completed==1)
    row.status='interrupted'
    check('outcome_detached_and_retained',W.outcome(f.id,1).status=='completed'
        and plain(f.rec.windowRepair,{}) and plain(f.rec.windowRepairWork,{}))
    check('duplicate_requery_exact_once',P.consumeWindowRepairOutcome(f.id,1)==true
        and P.techniqueProfile(f.id).practice[row.entryKey].completed==1)
    check('duplicate_native_complete_refuses',a:complete()==false and f.rec.windowRepair.nextResult==1)
    __windowHold(f.id,f.agent,f.body,60)
    check('production_completed_hold_releases',f.agent.state=='IDLE' and #q.queue==0)
    __records[f.id]=__nativeRoundtrip(f.rec)
    check('native_save_reload_preserves_outcome',W.outcome(f.id,1).status=='completed'
        and P.consumeWindowRepairOutcome(f.id,1)==true
        and P.techniqueProfile(f.id).practice[row.entryKey].completed==1)
    local missing=fixture('missing');local ma=admitted(missing);missing.inventory:Remove(missing.pane)
    check('removed_pane_prevents_native_effect',ma:complete()==false and missing.window.smashed
        and not missing.window.synced and W.outcome(missing.id,1).status=='interrupted')
    local replacement=fixture('replacement');local ra=admitted(replacement)
    replacement.inventory.items[1]={getID=function() return 713 end,getFullType=function() return 'RepairableWindows.LargeGlassPane' end,
        getContainer=function() return replacement.inventory end}
    check('same_id_material_substitution_refuses',ra:complete()==false and replacement.window.smashed)
    local swaps={
        {'body',function(x) SAO.Body.active[x.id]={} end},
        {'token',function(x) x.body.md.SAOExternalToken='changed' end},
        {'record',function(x) __records[x.id]={id=x.id} end},
        {'world',function(x) __world.name='changed' end},
        {'floor',function(x) x.body.z=1 end},
        {'distance',function(x) x.body.x=20 end},
        {'window',function(x) x.square.objects={} end},
        {'standing',function(x) x.rec.claim.minX=1 end},
        {'death',function(x) x.body.dead=true end},
        {'ledger',function(x) x.rec.windowRepair.schema=99 end},
        {'saved_work',function(x) x.rec.windowRepairWork.entryKey='forged' end},
        {'cell_membership',function(x) x.cell.objects={};x.cell.added={} end},
    }
    for _,case in ipairs(swaps) do
        local x=fixture('changed-'..case[1]);local action=admitted(x);case[2](x)
        check('changed_'..case[1]..'_cannot_mutate',action:complete()==false and x.window.smashed and x.inventory:contains(x.pane))
    end
    local redirected=fixture('redirected');local redirect=admitted(redirected);local originalWorld=__world
    local target=fixture('other-target');redirect.window=target.window;__world=originalWorld
    check('action_target_shadow_refuses',redirect:complete()==false and redirected.window.smashed and target.window.smashed)
    local actorShadow=fixture('actor-shadow');local asa=admitted(actorShadow);local actorWorld=__world
    local actorOther=fixture('actor-other');__world=actorWorld;asa.character=actorOther.body
    check('different_inventory_action_shadow_refuses',asa:complete()==false and actorShadow.window.smashed
        and actorShadow.inventory:contains(actorShadow.pane) and actorOther.inventory:contains(actorOther.pane))
    local unseen=fixture('unseen');unseen.body.visible=false
    check('unseen_window_not_offered',W.offer(unseen.id,unseen.body)==nil)
    local behind=fixture('behind');behind.body.y=.25;behind.body.dx=0;behind.body.dy=1
    check('behind_window_not_offered',W.offer(behind.id,behind.body)==nil)
    local northSame=fixture('native-north-same');northSame.body.y=.25;northSame.body.dx=0;northSame.body.dy=-1
    check('native_edge_facing_north_same_offered',W.offer(northSame.id,northSame.body)~=nil)
    local westSame=fixture('native-west-same');westSame.window.north=false;westSame.body.x=.25;westSame.body.dx=-1;westSame.body.dy=0
    check('native_edge_facing_west_same_offered',W.offer(westSame.id,westSame.body)~=nil)
    local northOpposite=fixture('native-north-opposite');northOpposite.body.here=northOpposite.cell:getGridSquare(0,-1,0)
    northOpposite.body.y=-.25;northOpposite.body.dx=0;northOpposite.body.dy=1
    check('native_edge_facing_north_opposite_offered',W.offer(northOpposite.id,northOpposite.body)~=nil)
    local westOpposite=fixture('native-west-opposite');westOpposite.window.north=false;westOpposite.body.here=westOpposite.cell:getGridSquare(-1,0,0)
    westOpposite.body.x=-.25;westOpposite.body.dx=1;westOpposite.body.dy=0
    check('native_edge_facing_west_opposite_offered',W.offer(westOpposite.id,westOpposite.body)~=nil)
    local hidden=fixture('hidden');hidden.square.objects={};local far=hidden.cell:getGridSquare(1,0,0)
    hidden.window.sq=far;far.objects={hidden.window};hidden.window.north=true
    check('noninteraction_side_not_offered',W.offer(hidden.id,hidden.body)==nil)
    local foreign=fixture('foreign');SAO.Body.foreign[foreign.id]=true
    check('foreign_owner_not_admitted',W.offer(foreign.id,foreign.body)==nil)
    local civilian=fixture('before-fall');__fall=false
    check('standing_before_fall_refuses',W.offer(civilian.id,civilian.body)==nil);__fall=true
    local opaque=fixture('opaque');local offer=W.offer(opaque.id,opaque.body);offer.entryKey='changed'
    check('modified_public_offer_refuses',W.begin(opaque.id,opaque.body,offer)==false)
    local ordinary=fixture('ordinary');ordinary.body.md.SAOExternalToken=nil;ordinary.rec.bodyOwnerToken=nil
    check('ordinary_body_without_external_token_admits',W.offer(ordinary.id,ordinary.body)~=nil)
    local pendingAdd=fixture('pending-add');pendingAdd.cell.objects={};pendingAdd.cell.added={pendingAdd.body}
    check('native_pending_add_membership_admits',W.offer(pendingAdd.id,pendingAdd.body)~=nil)
    local player=fixture('player');player.body.md={}
    local pa=A:new(player.body,player.window)
    check('native_first_validity_query_pins_player_pane',pa:isValid()==true and pa:isValidStart()==true)
    check('player_native_start_preserved',pa:isValidStart()==true)
    check('player_native_complete_preserved',pa:complete()==true and not player.window.smashed
        and player.rec.windowRepair==nil and not player.inventory:contains(player.pane))
    local late=fixture('player-transfer');late.body.md={};late.inventory.items={}
    local la=A:new(late.body,late.window);late.inventory.items={late.pane}
    check('player_transfer_before_start_preserved',la:isValidStart()==true and la:complete()==true)
    local pm=fixture('player-missing');pm.body.md={};local pma=A:new(pm.body,pm.window)
    pma:isValidStart();pm.inventory:Remove(pm.pane)
    check('player_missing_pane_race_closed',pma:complete()==false and pm.window.smashed and not pm.window.synced)
    local playerRemoved=fixture('player-removed');playerRemoved.body.md={}
    local prAction=A:new(playerRemoved.body,playerRemoved.window);prAction:isValidStart()
    playerRemoved.cell.objects={};playerRemoved.cell.added={}
    check('retained_removed_player_body_refuses',prAction:complete()==false and playerRemoved.window.smashed)
    local diagonal=fixture('player-diagonal');diagonal.body.md={};diagonal.square.stand=false
    diagonal.cell:getGridSquare(0,-1,0).stand=false
    diagonal.body.here=diagonal.cell:getGridSquare(1,1,0);diagonal.body.x=1.75;diagonal.body.y=1.75
    local da=A:new(diagonal.body,diagonal.window)
    check('installed_player_diagonal_fallback_preserved',AdjacentFreeTileFinder.FindWindowOrDoor(diagonal.square,
        diagonal.window,diagonal.body)==diagonal.body.here and da:isValidStart()==true and da:complete()==true)
    local cancel=fixture('cancel');local ca=admitted(cancel)
    local nextAction=ISBaseTimedAction:new(cancel.body);nextAction.maxTime=1
    ISTimedActionQueue.add(nextAction)
    check('controller_owner_change_cancels_exact_work',__setState(cancel.agent,cancel.id,'GEARWARD','replacement')==true
        and not ISTimedActionQueue.hasAction(ca) and ISTimedActionQueue.hasAction(nextAction)
        and W.outcome(cancel.id,1).status=='interrupted' and cancel.window.smashed)
    local hold=fixture('hold');local ha=admitted(hold);hold.agent.state='WINDOWREPAIR';hold.body.holdCancellation=true
    check('pending_native_cancellation_blocks_owner_change',__setState(hold.agent,hold.id,'GEARWARD','replacement')==false
        and hold.agent.state=='WINDOWREPAIR' and ISTimedActionQueue.hasAction(ha))
    hold.body.holdCancellation=false;W.interrupt(hold.id,hold.body,'retired')
    for _,kind in ipairs({'threat','deadline'}) do
        local exiting=fixture('hold-'..kind)
        __decideHome(exiting.id,exiting.agent,exiting.body,50,exiting.rec)
        if kind=='threat' then exiting.rec.threat={dist=3} end
        __windowHold(exiting.id,exiting.agent,exiting.body,kind=='deadline' and exiting.agent.taskDeadline or 60)
        check('production_'..kind..'_hold_interrupts',exiting.agent.state=='IDLE' and exiting.window.smashed
            and exiting.inventory:contains(exiting.pane) and W.outcome(exiting.id,1).status=='interrupted')
    end
    local denied=fixture('queue-refused');denied.body.queueRefused=true
    check('queue_refusal_no_native_effect',W.begin(denied.id,denied.body,W.offer(denied.id,denied.body))==false
        and denied.window.smashed and denied.inventory:contains(denied.pane)
        and W.outcome(denied.id,1).status=='interrupted')
    local partial=fixture('partial');local partialAction=admitted(partial)
    local nativeSend=sendRemoveItemFromContainer
    sendRemoveItemFromContainer=function() error('controlled native send failure after Remove') end
    local partialResult=partialAction:complete();sendRemoveItemFromContainer=nativeSend
    local partialRow=W.outcome(partial.id,1)
    check('partial_native_effect_recorded_without_completion',partialResult==false and partialRow.status=='interrupted'
        and partialRow.nativeAttempted and partialRow.paneConsumed and partialRow.smashedAfter==false
        and P.techniqueProfile(partial.id).practice[partialRow.entryKey].completed==0)
    partial.rec.windowRepair.outcomes['1'].extra={native=partial.body}
    check('nonplain_saved_outcome_refuses_requery',W.outcome(partial.id,1)==nil)
    local rewind=fixture('clock');local coa=admitted(rewind);__hours=0
    check('clock_rewind_refuses_without_fabricated_time',coa:complete()==false and rewind.window.smashed
        and rewind.rec.windowRepair.nextResult==0 and rewind.rec.windowRepairWork.status=='interrupted')
    __hours=101
    local saved=fixture('saved');saved.rec.windowRepairWork={status='repairing',purposeId='gone'}
    check('saved_active_work_does_not_replay_effect',W.active(saved.id,saved.body)==true
        and saved.rec.windowRepairWork.status=='repairing' and saved.window.smashed
        and saved.rec.windowRepairWork.purposeId=='gone')
    for _,kind in ipairs({'sparse','duplicate','future'}) do
        local malformed=fixture('malformed-'..kind)
        malformed.rec.windowRepair={schema=1,nextWork=1,nextResult=1,outcomes={['1']={}},order={1}}
        if kind=='sparse' then malformed.rec.windowRepair.order[3]=1 end
        if kind=='duplicate' then malformed.rec.windowRepair.order[2]=1 end
        if kind=='future' then malformed.rec.windowRepair.nextResult=0 end
        check('malformed_'..kind..'_ledger_refuses',W.begin(malformed.id,malformed.body,W.offer(malformed.id,malformed.body))==false
            and malformed.window.smashed and malformed.inventory:contains(malformed.pane))
    end
    local repeated=fixture('repeated');local allRepeated=true
    for i=1,34 do
        repeated.window.smashed=true;repeated.window.glass=true
        repeated.inventory.items={repeated.pane};repeated.pane.container=repeated.inventory
        local action=admitted(repeated)
        allRepeated=allRepeated and action:complete()==true
        action:perform();W.active(repeated.id,repeated.body)
    end
    check('bounded_ledger_and_planner_retirement',allRepeated and repeated.rec.windowRepair.nextResult==34
        and #repeated.rec.windowRepair.order==32 and W.outcome(repeated.id,1)==nil
        and W.outcome(repeated.id,34).planningAcknowledged==true
        and #repeated.rec.proceduralPlanning.order<=12)
    for _,sequence in ipairs(repeated.rec.windowRepair.order) do
        repeated.rec.windowRepair.outcomes[tostring(sequence)].planningAcknowledged=nil
    end
    repeated.window.smashed=true;repeated.window.glass=true
    repeated.inventory.items={repeated.pane};repeated.pane.container=repeated.inventory
    check('unacknowledged_full_ledger_refuses_new_work',W.begin(repeated.id,repeated.body,W.offer(repeated.id,repeated.body))==false
        and repeated.window.smashed and repeated.inventory:contains(repeated.pane) and repeated.rec.windowRepair.nextResult==34)
    local board=fixture('board');board.inventory.items={};board.body.boardKit=true
    check('production_native_boarding_still_available',__decideHome(board.id,board.agent,board.body,50,board.rec)==true
        and board.body.boardingAdmitted~=nil and board.body.boarded==nil
        and board.agent.state=='BOARDING' and board.rec.windowRepair==nil)
    local mirror=fixture('native-receivers');__nativeOp('reset');mirror.window.mirror=true;mirror.inventory.mirror=true
    check('actual_native_material_present',__nativeOp('contains') and __nativeOp('first') and __nativeOp('smashed') and __nativeOp('glass'))
    local na=admitted(mirror)
    check('installed_complete_real_native_poststate',na:complete()==true and __nativeOp('poststate')==true
        and W.outcome(mirror.id,1).status=='completed')
    __windowResults=table.concat(__checks,'\n')
end

function __runWindowLifecycle()
    local W,P,C=SAO.WindowRepair,SAO.ProceduralPlanning,SAO.Controller
    W.reset('controlled-prior-case-retirement');__fireWindowRetry()
    local function life(id)
        local f=fixture(id)
        f.rec.forename,f.rec.surname,f.rec.x,f.rec.y='Control','Actor',0,0
        C.agents[id]=f.agent
        return f
    end
    local eager=life('lifecycle-eager');local ea=admitted(eager)
    local before=W.runtimeCount()-1
    eager.body.dead=true;__updateAgent(eager.id,eager.agent)
    check('ordinary_death_acknowledged_runtime_retires',eager.rec.dead and C.agents[eager.id]==nil
        and SAO.Body.active[eager.id]==nil and not ISTimedActionQueue.hasAction(ea) and W.runtimeCount()==before)

    local d=life('lifecycle-death');local da=admitted(d)
    before=W.runtimeCount()-1
    d.body.holdCancellation=true;d.body.stopAllThrows=true;d.body.dead=true
    __updateAgent(d.id,d.agent)
    check('ordinary_death_retains_pending_native_owner',d.rec.dead and C.agents[d.id]==nil
        and SAO.Body.active[d.id]==nil and ISTimedActionQueue.hasAction(da) and W.runtimeCount()==before+1
        and d.rec.windowRepairWork.status=='interrupted')
    d.body.holdCancellation=false;da:stop()
    check('late_native_stop_retires_without_agent',not ISTimedActionQueue.hasAction(da) and W.runtimeCount()==before)
    local fresh=life(d.id)
    check('new_body_after_native_ack_is_not_blocked',W.offer(fresh.id,fresh.body)~=nil)

    local retry=life('lifecycle-retry');local retryAction=admitted(retry)
    before=W.runtimeCount()-1
    retry.body.holdCancellation=true;retry.body.stopAllThrows=true;retry.body.dead=true
    __updateAgent(retry.id,retry.agent)
    local q=ISTimedActionQueue.getTimedActionQueue(retry.body)
    q:resetQueue();__fireWindowRetry()
    check('queue_absence_without_native_ack_retains',W.runtimeCount()==before+1 and not ISTimedActionQueue.hasAction(retryAction)
        and retry.body.stopRequests>=2 and C.agents[retry.id]==nil)
    retry.body.holdCancellation=false;__fireWindowRetry()
    check('independent_tick_retry_retires_after_agent_removal',W.runtimeCount()==before and retry.window.smashed
        and retry.inventory:contains(retry.pane) and W.outcome(retry.id,1).status=='interrupted')

    local r=life('lifecycle-reset');local ra=admitted(r)
    before=W.runtimeCount()-1;r.body.holdCancellation=true
    for _,callback in ipairs(Events.OnInitGlobalModData.callbacks) do callback() end
    check('world_reset_retains_until_native_ack',W.runtimeCount()==before+1 and ISTimedActionQueue.hasAction(ra))
    r.body.holdCancellation=false;ra:stop()
    local replacement=life(r.id)
    check('world_reset_late_ack_releases_new_world_offer',W.runtimeCount()==before
        and W.offer(replacement.id,replacement.body)~=nil)

    local t=life('lifecycle-transfer');local ta=admitted(t)
    __transferRetries=0;t.body.holdCancellation=true;t.rec.zaoTransferPending={token='controlled-transfer'}
    __updateAgent(t.id,t.agent)
    check('transfer_pending_cancels_before_resume',__transferRetries==0 and t.rec.windowRepairWork.status=='interrupted'
        and ISTimedActionQueue.hasAction(ta))
    local result=ta:complete();local row=W.outcome(t.id,1)
    check('transfer_pending_complete_cannot_consume_or_credit',result==false and t.window.smashed and t.inventory:contains(t.pane)
        and row.status=='interrupted' and not row.nativeAttempted and P.techniqueProfile(t.id).practice[row.entryKey].completed==0)
    t.body.holdCancellation=false;__fireWindowRetry();__updateAgent(t.id,t.agent)
    check('transfer_pending_retries_before_resume',__transferRetries==1 and not ISTimedActionQueue.hasAction(ta))

    local dormant=life('lifecycle-bodyless');local dormantAction=admitted(dormant)
    dormant.body.holdCancellation=true;dormant.rec.crossedTransferPending={token='controlled-transfer'}
    SAO.Body.active[dormant.id]=nil;__transferRetries=0;__updateAgent(dormant.id,dormant.agent)
    local blocked=__transferRetries==0 and dormant.rec.windowRepairWork.status=='interrupted'
    dormant.body.holdCancellation=false;__fireWindowRetry();__updateAgent(dormant.id,dormant.agent)
    check('bodyless_transfer_waits_for_native_ack',blocked and __transferRetries==1 and not ISTimedActionQueue.hasAction(dormantAction))

    local pending=life('lifecycle-direct');local pa=admitted(pending)
    pending.rec.crossedTransferPending={token='controlled-transfer'}
    local direct=pa:complete();local pr=W.outcome(pending.id,1)
    check('transfer_pending_without_controller_tick_refuses_effect',direct==false and pending.window.smashed
        and pending.inventory:contains(pending.pane) and pr.status=='interrupted' and not pr.nativeAttempted)
    check('transfer_pending_not_offered',W.offer(pending.id,pending.body)==nil)
    W.interrupt(pending.id,pending.body,'controlled-retire')

    local retained={};local requests=0
    for i=1,33 do
        local f=life('lifecycle-fair-'..i);admitted(f);f.body.holdCancellation=true
        W.forget(f.id);retained[#retained+1]=f
        requests=requests+f.body.stopRequests
    end
    __fireWindowRetry()
    local afterRequests=0
    for _,f in ipairs(retained) do afterRequests=afterRequests+f.body.stopRequests end
    local bounded=afterRequests-requests==32 and retained[33].body.stopRequests==1
    __fireWindowRetry()
    check('bounded_cancellation_retry_is_fair',bounded and retained[33].body.stopRequests==2)
    for _,f in ipairs(retained) do f.body.holdCancellation=false end
    __fireWindowRetry();__fireWindowRetry()
    __windowResults=table.concat(__checks,'\n')
end
