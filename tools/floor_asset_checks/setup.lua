Events.OnTick.Remove=function()end
Events.OnPlayerDeath={Add=function()end,Remove=function()end}
Events.OnInitGlobalModData={Add=function()end}
Events.OnSave={Add=function()end}
Events.LoadGridsquare={Add=function()end}
Events.OnObjectAdded={Add=function()end}
Events.OnObjectAboutToBeRemoved={Add=function()end}
Events.OnContainerUpdate={Add=function()end}
Events.OnLoad={Add=function()end}
__stores={}
ModData={get=function(key)return __stores[key]end,getOrCreate=function(key)
    __stores[key]=__stores[key] or {};return __stores[key]end}
getText=function(s)return s end
isClient=function()return false end
isServer=function()return false end
createItemTransaction=function()return 1 end
removeItemTransaction=function()end
getPlayerData=function()return nil end
getGameTime=function()return {getMultiplier=function()return 1 end,getMinutesPerDay=function()return 60 end}end
getSandboxOptions=function()return {getOptionByName=function()return {getValue=function()return 2 end}end}end
sendSyncPlayerFields=function()end
syncItemFields=function()end
sendServerCommand=function()end
ISInventoryPage={}
SkillBook={}
SAO.Census={JOB_PERK={},bookSkillFor=function(p)return p end}
SAO.Lessons={has=function()return false end}
SAO.History.countyHours=function()return __nativeHours()+240 end
SAO.History.ticks=function()return math.floor(SAO.History.countyHours()*9000)end
SAO.History.literacyOf=function()return "reads"end
SAO.History.ageOf=function()return 30 end
SAO.Disposition={traits=function()return {discipline=.4,initiative=.5}end,isSmoker=function()return false end}
SAO.Standing.mayAttemptBelieved=function()return __permit end
SAO.Standing.mayTakeCurrent=function()return __permit end
SAO.Standing.provisioningContextAt=function()return "ungrouped"end
SAO.Standing.groupOf=function()return nil end
SAO.Places={at=function()return nil end,get=function()return nil end}
SAO.Cognition.capture=function()return nil end
SAO.Cognition.interpretPlans=function(_,candidates)return {selected=candidates[1].id}end
SAO.Locomotion={jobs={},order=function(id,body,x,y,z)
    SAO.Locomotion.jobs[id]={body=body,x=x,y=y,z=z};return true end,cancel=function(id)SAO.Locomotion.jobs[id]=nil end}
SAO.StateMachine={apply=function()return true end}
SAO.ProceduralPlanning=nil
SAO.Provisioning={consumeCompleted=function()
    if __deferDelivery then return end
    for _,receipt in ipairs(SAO.WorldSources.completedResults("provisioning",true)) do
        if receipt.purposeId then assert(SAO.ProceduralPlanning.consumeSourceResult(receipt),"actual purpose receipt")end
        SAO.WorldSources.acknowledgeResult(receipt.reservationId,"provisioning","controlled downstream material consumer")
    end
end}
