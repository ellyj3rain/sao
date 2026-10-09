require "TimedActions/ISBaseTimedAction"

ProjectArcade_CoinPusherTimedAction = ISBaseTimedAction:derive("ProjectArcade_CoinPusherTimedAction")

function ProjectArcade_CoinPusherTimedAction:isValid()
    return self.character ~= nil and self.machineObj ~= nil and self.machineObj:getSquare() ~= nil
end

function ProjectArcade_CoinPusherTimedAction:start()
end

function ProjectArcade_CoinPusherTimedAction:perform()
    if self.character and self.machineObj then
        if self.character.faceThisObject then
            self.character:faceThisObject(self.machineObj)
        end
    end

    if self.onDone then
        self.onDone(self.character, self.machineObj)
    end

    ISBaseTimedAction.perform(self)
end

function ProjectArcade_CoinPusherTimedAction:new(character, machineObj, onDoneFn)
    local o = ISBaseTimedAction.new(self, character)
    o.machineObj = machineObj
    o.onDone = onDoneFn
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = 1
    o.useProgressBar = false
    return o
end
