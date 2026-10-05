-- SAO custody around installed LeanAndLie animation contracts. No source action or media is carried.
SAO = SAO or {}
SAO.RecoveryPose = SAO.RecoveryPose or {}
local P = SAO.RecoveryPose
P.verbose = false
P.leanCorrection = 0.40
P.stateVariableOnGround = "SleepStateOnGround"
P.appliedOffset = P.appliedOffset or {}
P.bedUsers = P.bedUsers or {}
P.pendingExits = P.pendingExits or {}
P.exitQueue = P.exitQueue or {}

local function recoveryActor(body)
    local ok, owned = pcall(function()
        local id = body:getModData().SAOPersonId
        return type(id) == "string" and SAO.Needs.ownsRecoveryBody(id, body)
    end)
    return ok and owned == true
end
function P.captureCustody(body)
    if not recoveryActor(body) then return nil end
    local ok, custody = pcall(function()
        local data = body:getModData()
        local rec = SAO.Identity.get(data.SAOPersonId)
        if not rec then return nil end
        return { body=body, rec=rec, id=data.SAOPersonId, owner=rec.bodyOwner,
            token=rec.bodyOwnerToken, externalOwner=data.SAOExternalOwner,
            externalToken=data.SAOExternalToken, zaoOwned=data.ZAOOwned }
    end)
    return ok and custody or nil
end
function P.ownsCustody(custody)
    if not custody then return false end
    local current = P.captureCustody(custody.body)
    return current ~= nil and current.rec == custody.rec and current.id == custody.id
        and current.owner == custody.owner and current.token == custody.token
        and current.externalOwner == custody.externalOwner
        and current.externalToken == custody.externalToken and current.zaoOwned == custody.zaoOwned
end
local function audit(receipt, status)
    -- The saved audit contains no disposable native receiver or record pointer.
    if SAO.Identity.get(receipt.custody.id) ~= receipt.custody.rec then return end
    local ok, hours = pcall(function() return SAO.History.countyHours() end)
    local value = { schema="sao-recovery-pose-exit/1", actorId=receipt.custody.id,
        status=status, offsetX=receipt.x, offsetY=receipt.y,
        appliedX=receipt.atX, appliedY=receipt.atY, appliedZ=receipt.atZ,
        ownerToken=receipt.custody.token, continuity="runtime-exact-body" }
    if ok and type(hours)=="number" and hours==hours and math.abs(hours)<math.huge then value.atHours=hours end
    receipt.custody.rec.recoveryPoseExit=value
end
local function receiptOwned(body)
    local receipt=P.appliedOffset[body]
    return not receipt or P.ownsCustody(receipt.custody)
end
local function atAppliedPosition(body, receipt)
    return math.abs(body:getX()-receipt.atX)<0.0001 and math.abs(body:getY()-receipt.atY)<0.0001
        and math.abs(body:getZ()-receipt.atZ)<0.0001
end
function P.available()
    local ok, available = pcall(function()
        local mods = getActivatedMods()
        return not isClient() and not isServer() and mods:contains("LeanAndLie")
            and mods:contains("TchernoLib") and type(TchAL) == "table"
            and TchAL.stateVariableOnGround == P.stateVariableOnGround
    end)
    return ok and available == true
end
function P.getAppliedOffset(body)
    local receipt = P.appliedOffset[body]
    if not receipt then return 0, 0 end
    if not P.ownsCustody(receipt.custody) then return 0, 0 end
    return receipt.x, receipt.y
end
function P.storeAppliedOffset(body, x, y)
    local custody=P.captureCustody(body)
    if not custody or not receiptOwned(body) then return false end
    if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y
        or math.abs(x) > 1 or math.abs(y) > 1 then return false end
    if x == 0 and y == 0 then
        local receipt=P.appliedOffset[body]
        if receipt then audit(receipt,"offset-reversed") end
        P.appliedOffset[body] = nil
    else
        P.appliedOffset[body] = { x=x, y=y, custody=custody,
            atX=body:getX(), atY=body:getY(), atZ=body:getZ() }
        audit(P.appliedOffset[body],"offset-applied")
    end
    return true
end
function P.setAppliedOffset(body, x, y)
    if not recoveryActor(body) or not receiptOwned(body) then return false end
    if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y
        or math.abs(x) > 1 or math.abs(y) > 1 then return false end
    local beforeX, beforeY = P.getAppliedOffset(body)
    local receipt=P.appliedOffset[body]
    if receipt and not atAppliedPosition(body,receipt) then return false end
    if x==beforeX and y==beforeY then return true end
    local destination = { body:getX() + x - beforeX, body:getY() + y - beforeY, body:getZ() }
    -- Returning a tracked nudge uses the same real collision/footprint admission.
    if not SAOJavaBridge:recoveryGroundClear(body, destination[1], destination[2], destination[3]) then return false end
    for axis, target in ipairs({x, y}) do
        local getter = axis == 1 and "getX" or "getY"
        local setter = axis == 1 and "setX" or "setY"
        local before = axis == 1 and beforeX or beforeY
        if target ~= before then body[setter](body, body[getter](body) + target - before) end
    end
    return P.storeAppliedOffset(body, x, y)
end
function P.clearAppliedOffset(body) return P.setAppliedOffset(body, 0, 0) end
function P.setVariable(body, name, value)
    if not recoveryActor(body) or not receiptOwned(body) then return false end
    body:setVariable(name, value)
    return true
end
function P.getVariable(body, name) return body:getVariableString(name) end
function P.clearVariable(body, name)
    if not recoveryActor(body) or not receiptOwned(body) then return false,"custody-unavailable" end
    local cleared=P.clearAppliedOffset(body)
    -- An obstructed reversal must not strand the installed lying animation.
    body:clearVariable(name)
    if not cleared then
        local receipt=P.appliedOffset[body]
        if receipt and not P.pendingExits[body] then
            P.pendingExits[body]=receipt;P.exitQueue[#P.exitQueue+1]=body
        end
        if receipt then audit(receipt,"pending-safe-exit") end
        body:setVariable("forceGetUp",true)
        return false,"pending-safe-exit"
    end
    return true,"offset-reversed"
end
function P.pollPendingExits()
    local count=math.min(16,#P.exitQueue)
    for i=1,count do
        local body=table.remove(P.exitQueue,1)
        local receipt=P.pendingExits[body]
        local pending=false
        if receipt then
            if P.appliedOffset[body]~=receipt or not P.ownsCustody(receipt.custody) then
                audit(receipt,"custody-unavailable")
                if P.appliedOffset[body]==receipt then P.appliedOffset[body]=nil end
            elseif not atAppliedPosition(body,receipt) then
                -- Actual owned native movement has exited the old posed location.
                -- Do not subtract the old nudge from a new native position.
                audit(receipt,"observed-native-exit")
                P.appliedOffset[body]=nil
            elseif P.clearAppliedOffset(body) then
                audit(receipt,"offset-reversed")
            else pending=true end
        end
        if pending then P.exitQueue[#P.exitQueue+1]=body else P.pendingExits[body]=nil end
    end
end
if Events and Events.OnTick then
    if P._exitTick then Events.OnTick.Remove(P._exitTick) end
    P._exitTick=P.pollPendingExits
    Events.OnTick.Add(P._exitTick)
end
function P.setupLieDownOnGround(body, bed, state)
    return P.available() and P.setVariable(body, P.stateVariableOnGround, state)
end
function P.stopLyingOnGround(body, bed) return P.clearVariable(body, P.stateVariableOnGround) end
function P.settle(body)
    -- Terminal cleanup is owned by the exact work receipt, rather than a source player-key callback.
    return P.stopLyingOnGround(body, nil)
end
local function seated(body)
    return body:getCurrentStateName() == "PlayerSitOnGroundState"
        and body:isSitOnGround() and body:getVariableBoolean("SitGroundStarted")
end
function P.observed(body, kind)
    local ok, actual = pcall(function()
        local expected = kind == "sleep" and "Asleep" or "Awake"
        local posed = body:isOnBed() and body:getVariableBoolean("OnBedStarted")
            and body:getVariableString("OnBedAnim") == expected
            or P.available() and seated(body) and body:getVariableString(P.stateVariableOnGround) == expected
        return posed and SAOJavaBridge:isRecoveryPose(body, kind) == true
    end)
    return ok and actual == true
end
local function loadActions()
    require "TimedActions/ISSitOnGround"
    require "TimedActions/SAORecoveryTransitionAction"
    require "TimedActions/ISGetOnBedAction"
end

-- Every callback revalidates the receiver; ownership may change between polls.
-- Retiring this exact action never resets a foreign queue or starts its sibling.
function P.retire(work, forgetOffset)
    if not work then return end
    if work.bed and P.bedUsers[work.bed]==work then P.bedUsers[work.bed]=nil end
    if forgetOffset then
        local receipt=P.appliedOffset[work.body]
        if receipt then audit(receipt,"custody-unavailable") end
        P.appliedOffset[work.body] = nil
    end
    if work.retired then return end
    work.retired = true
    local action = work.action
    if action and ISTimedActionQueue.hasAction(action) then
        local q = ISTimedActionQueue.queues[work.body]
        if q then
            q:removeFromQueue(action)
            if q.current == action then q.current = nil end
        end
        if action.action then action:forceStop() end
    end
end
local function owns(work)
    if work.retired then return false end
    if SAO.Identity.get(work.id) ~= work.rec or not SAO.Needs.ownsRecoveryBody(work.id,work.body)
        or not P.ownsCustody(work.custody) then
        P.retire(work); return false
    end
    if work.bed and (work.bed:getObjectIndex()<0 or work.started
        and work.body:getSitOnFurnitureObject()~=work.bed) then P.retire(work);return false end
    return true
end
local function queue(work, action, phase)
    work.action, work.phase, work.finished, work.started = action, phase, false, false
    local start, perform, stop, cancel, interrupted, event, update, valid, complete, wait =
        action.start, action.perform, action.stop, action.forceCancel,
        action.interruptWaitToStart, action.animEvent, action.update, action.isValid, action.complete, action.waitToStart
    function action:isValid() return owns(work) and valid(self) end
    function action:start()
        if not owns(work) then return end
        if work.bed and SAOJavaBridge:recoveryBed(work.body,work.place.key)~=work.bed then
            work.cancelled=true;self:forceStop();return
        end
        work.started = true
        return start(self)
    end
    function action:waitToStart()
        if not owns(work) then return true end
        if work.bed and not work.started and SAOJavaBridge:recoveryBed(work.body,work.place.key)~=work.bed then
            work.cancelled=true;self:forceStop();return true
        end
        return wait and wait(self) or false
    end
    function action:update()
        if not owns(work) then return end
        return update(self)
    end
    function action:complete()
        if not owns(work) then return false end
        -- Installed bed entry has no server-side complete callback.
        -- Native perform still owns finished/queue advancement; this supplies
        -- only a successful empty callback while exact custody remains valid.
        if complete then return complete(self) end
        return true
    end
    function action:perform()
        if not owns(work) then return end
        work.finished = true
        return perform(self)
    end
    function action:stop()
        if not owns(work) then return end
        work.cancelled = true
        return stop(self)
    end
    function action:forceCancel()
        if not owns(work) then return end
        work.cancelled = true
        if cancel then return cancel(self) end
    end
    function action:interruptWaitToStart()
        if not owns(work) then return end
        work.cancelled = true
        if interrupted then return interrupted(self) end
    end
    function action:animEvent(name, value)
        if not owns(work) then return end
        if phase == "sleep-transition" and name == "AsleepEvent" then work.sleepEvent = true end
        if event then return event(self, name, value) end
    end
    return SAO.Needs.queueVerified(action)
end
-- Installed ISGetOnBedAction geometry, bound per owned action to the physical bed Facing.
-- SeatingManager prefers chair seating positions on double-bed parts; those directions
-- can disagree with the bed grid. Native queue, events, entry alignment and getup remain owners.
local function bedBeforeSitDirection(self)
	local facing = self.bed:getProperties():get("Facing")
	local x = self.bed:getX()
	local y = self.bed:getY()
	local cx = self.character:getX()
	local cy = self.character:getY()
	if facing == "N" then
		if cy < y - 1.0 then
			-- Foot
			x = x + 0.5
			y = y - 2.0 -- TEMP: anim should start facing bed, turn 180 before ending in sitting position
			self.character:setVariable("OnBedDirection", "Foot")
		elseif cx < x + 0.25 then
			if cy > y then
				-- W head
				x = x + 2.0
				y = y + 0.5
				self.character:setVariable("OnBedDirection", "HeadLeft")
			else
				-- W foot
				x = x + 2.0
				y = y - 0.5
				self.character:setVariable("OnBedDirection", "FootLeft")
			end
		else
			if cy > y then
				-- E head
				x = x - 2.0
				y = y + 0.5
				self.character:setVariable("OnBedDirection", "HeadRight")
			else
				-- E foot
				x = x - 2.0
				y = y - 0.5
				self.character:setVariable("OnBedDirection", "FootRight")
			end
		end
	elseif facing == "S" then
		if cy > y + 2.0 then
			-- Foot
			x = x + 0.5
			y = y + 3.0 -- TEMP: anim should start facing bed, turn 180 before ending in sitting position
			self.character:setVariable("OnBedDirection", "Foot")
		elseif cx < x + 0.25 then
			if cy < y + 1.0 then
				-- W head
				x = x + 2.0
				y = y + 0.5
				self.character:setVariable("OnBedDirection", "HeadRight")
			else
				-- W foot
				x = x + 2.0
				y = y + 1.5
				self.character:setVariable("OnBedDirection", "FootRight")
			end
		else
			if cy < y + 1.0 then
				-- E head
				x = x - 2.0
				y = y + 0.5
				self.character:setVariable("OnBedDirection", "HeadLeft")
			else
				-- E foot
				x = x - 2.0
				y = y + 1.5
				self.character:setVariable("OnBedDirection", "FootLeft")
			end
		end
	elseif facing == "W" then
		if cx < x - 1 then
			-- Foot
			x = x - 2.0 -- TEMP: anim should start facing bed, turn 180 before ending in sitting position
			y = y + 0.5
			self.character:setVariable("OnBedDirection", "Foot")
		elseif cy < y + 0.25 then
			if cx > x then
				-- N head
				x = x + 0.5
				y = y + 2.0
				self.character:setVariable("OnBedDirection", "HeadRight")
			else
				-- N foot
				x = x - 0.5
				y = y + 2.0
				self.character:setVariable("OnBedDirection", "FootRight")
			end
		else
			if cx > x then
				-- S head
				x = x + 0.5
				y = y - 2.0
				self.character:setVariable("OnBedDirection", "HeadLeft")
			else
				-- S foot
				x = x - 0.5
				y = y - 2.0
				self.character:setVariable("OnBedDirection", "FootLeft")
			end
		end
	elseif facing == "E" then
		if cx > x + 2 then
			-- Foot
			x = x + 3.0 -- TEMP: anim should start facing bed, turn 180 before ending in sitting position
			y = y + 0.5
			self.character:setVariable("OnBedDirection", "Foot")
		elseif cy < y + 0.25 then
			if cx < x + 1.0 then
				-- N head
				x = x + 0.5
				y = y + 2.0
				self.character:setVariable("OnBedDirection", "HeadLeft")
			else
				-- N foot
				x = x + 1.5
				y = y + 2.0
				self.character:setVariable("OnBedDirection", "FootLeft")
			end
		else
			if cx < x + 1.0 then
				-- S head
				x = x + 0.5
				y = y - 2.0
				self.character:setVariable("OnBedDirection", "HeadRight")
			else
				-- S foot
				x = x + 1.5
				y = y - 2.0
				self.character:setVariable("OnBedDirection", "FootRight")
			end
		end
	end
	self.character:faceLocationF(x, y)
end

local function bedWhileSittingDirection(self)
	local facing = self.bed:getProperties():get("Facing")
	local x = self.bed:getX()
	local y = self.bed:getY()
	local cx = self.character:getX()
	local cy = self.character:getY()
	if facing == "N" then
		x = cx
		y = cy - 2.0
	elseif facing == "S" then
		x = cx
		y = cy + 2.0
	elseif facing == "W" then
		x = cx - 2.0
		y = cy
	elseif facing == "E" then
		x = cx + 2.0
		y = cy
	end
	self.character:faceLocationF(x, y)
end

function P.newBedEntry(body, bed)
    local facing=bed:getProperties():get("Facing")
    if facing~="N" and facing~="S" and facing~="W" and facing~="E" then return nil end
    local action=ISGetOnBedAction:new(body,bed)
    action.setBeforeSitDirection=bedBeforeSitDirection
    action.setWhileSittingDirection=bedWhileSittingDirection
    return action
end

function P.begin(body, kind, id, place)
    if not SAO.Needs.ownsRecoveryBody(id,body) then return nil,"recovery-owner-unavailable" end
    local ok = pcall(loadActions)
    if not ok then return nil, "recovery-source-unavailable" end
    if type(place)~="table" or type(place.key)~="string" then return nil,"recovery-place-unavailable" end
    local custody=P.captureCustody(body)
    if not custody then return nil,"recovery-custody-unavailable" end
    if P.pendingExits[body] or not receiptOwned(body) then return nil,"recovery-exit-unresolved" end
    local work = { body=body, custody=custody, kind=kind, id=id, rec=SAO.Identity.get(id), requestedAt=SAO.History.countyHours(),place=place }
    if place.kind=="bed" then
        work.bed=SAOJavaBridge:recoveryBed(body,place.key)
        if not work.bed then return nil,"native-bed-unavailable" end
        if P.bedUsers[work.bed] and not P.bedUsers[work.bed].retired then return nil,"native-bed-entry-occupied" end
        P.bedUsers[work.bed]=work
    elseif not P.available() then return nil,"installed-ground-source-unavailable"
    elseif place.kind~="ground" or type(place.x)~="number" or type(place.y)~="number"
        or math.abs(body:getZ()-(place.z or -99))>.1
        or (body:getX()-place.x)^2+(body:getY()-place.y)^2>.35^2
        or not SAOJavaBridge:recoveryGroundClear(body,body:getX(),body:getY(),body:getZ())
        or not SAOJavaBridge:recoveryGroundClear(body,body:getX()+.4,body:getY()+.4,body:getZ()) then
        return nil,"native-ground-clearance-refused"
    end
    body:clearVariable("SAOSeat")
    body:clearVariable("forceGetUp")
    if work.bed then
        local action=P.newBedEntry(body,work.bed)
        if not action or not queue(work,action,"bed-entry") then
            P.cancel(work);return nil,"native-bed-queue-refused"
        end
        return work
    end
    if not queue(work, ISSitOnGround:new(body, nil), "seating") then
        P.cancel(work); return nil, "native-seat-queue-refused"
    end
    return work
end
function P.poll(work)
    if not work or work.retired or work.cancelled then return "failed" end
    if not owns(work) then return "failed" end
    local body, now = work.body, SAO.History.countyHours()
    if now < work.requestedAt or now-work.requestedAt > 0.25 then return "failed" end
    if ISTimedActionQueue.hasAction(work.action) then return "preparing" end
    if not work.finished then return "failed" end
    if work.phase == "bed-entry" then
        if not P.observed(body,"rest") then return "preparing" end
        body:setBed(work.bed)
        body:setBedType(work.bed:getProperties():get("BedType") or "badBed")
        if work.kind=="rest" then return "admitted" end
        body:setVariable("OnBedAnim","Asleep")
        work.phase="bed-sleep-transition"
    elseif work.phase=="bed-sleep-transition" then
        if P.observed(body,"sleep") then return "admitted" end
    elseif work.phase == "seating" then
        if not seated(body) then return "preparing" end
        if not queue(work, SAORecoveryTransitionAction:new(body,"rest"), "lying-awake") then return "failed" end
    elseif work.phase == "lying-awake" then
        if not P.observed(body,"rest") then return "preparing" end
        if work.kind == "rest" then return "admitted" end
        -- Native BaseAction waits for sit_action before invoking start(). The
        -- higher-priority Awake node otherwise prevents that node from entering.
        -- Yield its selection while retaining the lying offset; only the queued
        -- source action's native start may request the sleep transition.
        body:clearVariable(P.stateVariableOnGround)
        if not queue(work, SAORecoveryTransitionAction:new(body,"sleep"), "sleep-transition") then return "failed" end
    elseif work.phase == "sleep-transition" then
        if work.sleepEvent and P.observed(body,"sleep") then return "admitted" end
    end
    return "preparing"
end
function P.cancel(work)
    if not work then return end
    local current=P.ownsCustody(work.custody)
    P.retire(work)
    if not current then return false,"custody-unavailable" end
    -- Physical exit remains bound to the exact capture, including a returned owner token.
    if work.bed then
        if work.body:getBed()==work.bed then work.body:setBed(nil);work.body:setBedType("floor") end
    else
        local cleared,reason=P.stopLyingOnGround(work.body,nil)
        work.body:setVariable("forceGetUp",true)
        return cleared,reason
    end
    work.body:setVariable("forceGetUp",true)
    return true,"native-bed-exit"
end
return P
