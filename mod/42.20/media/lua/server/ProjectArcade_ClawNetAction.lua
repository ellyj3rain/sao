-- SAO-owned multiplayer receiver for ProjectArcade's claw play.
-- Original source and author are recorded in SAOSources and CREDITS.md.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ProjectArcade") then return end
require "TimedActions/ISBaseTimedAction"
require "ProjectArcade_PaymentServer"

-- Build 42 reconstructs a NetTimedAction through Type.new using the named
-- parameters of the client constructor. Keep this signature in the same order.
ProjectArcade_ClawTimedAction = ISBaseTimedAction:derive("ProjectArcade_ClawTimedAction")

function ProjectArcade_ClawTimedAction:new(character, machine, cost,
        currencyFullType, debugFreePlay, serverAttemptId)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.machine = machine
    o.cost = cost
    o.currencyFullType = currencyFullType
    o.debugFreePlay = debugFreePlay == true
    o.serverAttemptId = serverAttemptId
    o.maxTime = 624
    o.name = "Claw machine"
    o.startedPaid = false
    return o
end

function ProjectArcade_ClawTimedAction:serverStart()
    self.startedPaid = ProjectArcade_ClawPayments.begin(self.character,
        self.serverAttemptId, self.machine, self.cost, self.currencyFullType)
end

function ProjectArcade_ClawTimedAction:complete()
    if not self.startedPaid then return false end
    return ProjectArcade_ClawPayments.complete(self.character, self.serverAttemptId)
end

function ProjectArcade_ClawTimedAction:serverStop()
    ProjectArcade_ClawPayments.stop(self.character, self.serverAttemptId)
end
