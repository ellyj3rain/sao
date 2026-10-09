-- Full production Locomotion.tick consumes a controlled movement delivery.
-- Native body coordinates change inside that receiver; no rendered path claim.
__productionLocomotionTick=SAO.Locomotion.tick
SAO.Locomotion.order=__fixtureRouteOrder
SAO.Locomotion.cancel=__fixtureRouteCancel
SAO.Locomotion.tick=function()end
function __installRoutePumpFixture(body)
    __pumpCalls=0
    local nativeBridge=SAOJavaBridge
    SAOJavaBridge={
        privateCarriedItems=function(_,actor)return nativeBridge:privateCarriedItems(actor)end,
        nativeLeisureActionSource=function(_,name)return nativeBridge:nativeLeisureActionSource(name)end,
        tickMove=function(_,actor)
            assert(actor==body,'route pump borrowed another body')
            local job=SAO.Locomotion.jobs.person
            assert(job and job.body==body,'route pump lost exact job')
            __pumpCalls=__pumpCalls+1
            body:setX(job.x);body:setY(job.y);body:setZ(job.z)
            return 'Succeeded'
        end,
        moveProgress=function()return nil end,
    }
    SAO.Locomotion.tick=__productionLocomotionTick
    return function()SAOJavaBridge=nativeBridge;SAO.Locomotion.tick=function()end end
end
