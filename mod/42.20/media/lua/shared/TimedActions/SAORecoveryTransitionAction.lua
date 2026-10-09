-- SAO-owned native queue lifecycle over packaged source-derived ground animation.
-- Source mechanics: Lean & Lie 1.27; original callbacks/UI are outside this exact actor owner.
require "TimedActions/ISBaseTimedAction"
SAORecoveryTransitionAction = ISBaseTimedAction:derive("SAORecoveryTransitionAction")
local Action = SAORecoveryTransitionAction
function Action:new(body, kind)
    local action = ISBaseTimedAction.new(self, body)
    action.kind = kind
    action.maxTime = kind == "sleep" and -1 or 2
    action.stopOnAim, action.stopOnWalk, action.stopOnRun = false, false, false
    action.useProgressBar = false
    return action
end
function Action:isValid() return self.kind == "sleep" or self.kind == "rest" end
function Action:waitToStart() return self.kind == "rest" and self.character:shouldBeTurning() end
function Action:start()
    local pose = SAO.RecoveryPose
    local target = self.kind == "sleep" and "AwakeToAsleep" or "Awake"
    if not pose.setupLieDownOnGround(self.character, nil, target) then self:forceStop() end
end
function Action:update()
    if self.kind == "rest" and not self.nudgeApplied then
        local pose = SAO.RecoveryPose
        if not pose.setAppliedOffset(self.character, pose.leanCorrection, pose.leanCorrection) then self:forceStop(); return end
        self.nudgeApplied = true
        self.character:setLastX(self.character:getX())
        self.character:setLastY(self.character:getY())
    end
end
function Action:animEvent(name)
    if self.kind == "sleep" and name == "AsleepEvent" then self:forceComplete() end
end
function Action:complete() return true end
function Action:perform()
    local target = self.kind == "sleep" and "Asleep" or "Awake"
    SAO.RecoveryPose.setupLieDownOnGround(self.character, nil, target)
    ISBaseTimedAction.perform(self)
end
function Action:stop() ISBaseTimedAction.stop(self) end
function Action:forceCancel() end
function Action:interruptWaitToStart() end
