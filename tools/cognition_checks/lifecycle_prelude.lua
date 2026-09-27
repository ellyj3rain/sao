SAO.Perception={beliefs={}}
SAO.Standing={}
SAO.Voice={}
SAO.Disposition={describe=function()return "fixture"end}
SAO.Locomotion={cancel=function(id)cancels=(cancels or 0)+1 end}
bodies={}
SAO.Body={active=bodies,foreign={},get=function(id)return bodies[id]end,
    isTransitioning=function()return false end}
SAO.SourceUse={closeForOwnershipTransfer=function()return sourceClosed~=false end,detach=function()end}
SAO.WorldSources={pendingActionFor=function(id)
    if sourceUnknown then error("unavailable source owner")end
    return sourceOwner and sourceOwner.actorId==id and sourceOwner or nil
end}
SAOJavaBridge={getLastAttackerTag=function()return ""end,getBleedingCount=function()return 0 end}
ISTimedActionQueue={clear=function()end}
stores.SurvivorAwareness_Records={records=records,nextId=1}
for id,rec in pairs(records)do rec.forename=id;rec.surname="Fixture";rec.x=0;rec.y=0;rec.z=0 end
function getSpecificPlayer()return nil end
