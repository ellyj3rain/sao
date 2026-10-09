__nativeBridge=SAOJavaBridge
SAOJavaBridge={privateCarriedItems=function(self,body)return __nativeBridge:privateCarriedItems(body)end,
    initFitnessExerciseDefinitions=function(self,body,defs)return __initDefinitions(body,defs)end,
    fitnessExerciseXpModifier=function(self,body,name)return __xpModifier(body,name)end}
MoodleType.PAIN=__painMoodle;MoodleType.HEAVY_LOAD=__heavyMoodle
__seconds=100;GTLSCheck=1
getGameTime=function()return {getCalender=function()return {getTimeInMillis=function()return __ms end}end,
    getGameWorldSecondsSinceLastUpdate=function()return __seconds end,getNightsSurvived=function()return 1 end}end
getActivatedMods=function()return {contains=function(self,name)return name=='LifestyleHobbies' or name=='FWOBenchPressTreadmill' or name=='FWOFitnessWorkoutOverhaul' end}end
newrandom=function()return {random=function()return 1 end}end
ZombRand=function(low,high) if high then return low end if low==100 then return 99 end return 0 end
HaloTextHelper={addTextWithArrow=function()end}
getSoundManager=function()return {playUISound=function()end}end
CharacterTrait={SMOKER=__smokerTrait}
ISFitnessUI={enduranceLevelThreshold=2}
Events.OnGameStart={Add=function()end};Events.OnConnected={Add=function()end}
Events.OnDisconnect={Add=function()end};Events.EveryTenMinutes={Add=function()end}
sendClientCommand=function(body,module,command,args)
    assert(module=='LS' and command=='AddXP','unexpected-original-source-command')
    addXp(body,Perks[args[1]],args[2]);SyncXp(body)
end
SandboxVars.FWOWorkingTreadmill={BenchTreadKeepBagsOn=true,FitnessXPMultiply=1,HeatMultiplier=1,ThirstMultiplier=1,StrengthXPMultiply=1,SprintingXPMultiply=1}
SandboxVars.FWOFitness={XPMultiplier=1,BoredomMultiplier=1,UnhappynessMultiplier=1}
SandboxVars.Yoga={RequiresMat=false,KeepBags=true,FailChance=1}
SandboxVars.Text={DividerMeditationNew=true};SandboxVars.ElecShutModifier=30
LSNoteMng={addToQueue=function()end}
SAO.Perception.leisureObjects=function(id,body)return __observations or {} end
SAO.Perception.resolveLeisureObject=function(id,body,key)
    for _,row in ipairs(__observations or {}) do if row.key==key then
        local obj=__objects[key]
        if obj and row.runtimeInstance==__instances[key] and row.at==SAO.History.ticks() then return obj end
    end end
end
addSound=function(body,x,y,z,radius,volume)getWorldSoundManager():addSound(body,x,y,z,radius,volume)end
emulateAnimEvent=function()end;emulateAnimEventOnce=function()end
local originalQueue=ISTimedActionQueue.addGetUpAndThen
ISTimedActionQueue.addGetUpAndThen=function(body,action)
    originalQueue(body,action)
    action.action.getJobDelta=function()return 0 end
    action.action.setActionAnim=function()end
    action.action.setOverrideHandModelsObject=function()end
    action.action.forceComplete=function()action:perform()end
    action.action.forceStop=function()action:stop()end
end

-- Explicit controlled owned-package availability, independent of external activation.
SAO.SourceIntegration={active=function(id)return id=='LifestyleHobbies'or id=='FWOBenchPressTreadmill'or id=='FWOFitnessWorkoutOverhaul' end}
SAO.SourceIntegration.available=SAO.SourceIntegration.active
getActivatedMods=function()return {contains=function()return false end}end

-- Controlled queue host exposes current owned-action custody and selective cleanup.
ISTimedActionQueue.hasAction=function(action)for _,entry in ipairs(__queue.queue)do if entry==action then return true end end;return false end
__queue.removeFromQueue=function(self,action)for n=#self.queue,1,-1 do if self.queue[n]==action then table.remove(self.queue,n)end end;if self.current==action then self.current=self.queue[1]end end
__queue.onCompleted=function(self,action)self:removeFromQueue(action)end
local sourceAdmission=ISTimedActionQueue.addGetUpAndThen
ISTimedActionQueue.addGetUpAndThen=function(body,action)sourceAdmission(body,action);__queue.current=action end
