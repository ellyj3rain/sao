-- Transfer/food declarations are unrelated to this exact instrument probe.
ISInventoryTransferAction = ISBaseTimedAction:derive("UnusedTransferFixture")
function fresh()
    if SAO.Gesture then SAO.Gesture.resetInstruments() end
    ISTimedActionQueue.clear(__body); __body:getCharacterActions():clear()
    __body:getInventory():clear(); __other:getInventory():clear()
    __body:setPrimaryHandItem(nil); __body:setSecondaryHandItem(nil)
    __body:getInventory():AddItem(__harmonica)
    __body:getModData().SAOPersonId = "person"
    __body:getModData().SAOExternalOwner = nil; __body:getModData().ZAOOwned = nil
    __body:getModData().SAOExternalToken = nil
    __body:setAsleep(false); __body:setCanShout(true)
    local rec = { id = "person" }; __records.person = rec
    SAO.Body.active.person = __body; SAO.Body.foreign.person = nil
    SAO.Controller.agents.person = { rec = rec, state = "REST" }
    __emitter:reset(); __resetNoise(); __results = {}
    __physical = {}; __cognitive = {}; __admission = nil; __rejectAdmission = false
    return rec
end
function queueBlow()
    assert(SAO.Gesture.playInstrument("person", __body, "harmonica", "Base.Harmonica", __harmonica), "native item admission")
    return ISTimedActionQueue.queues[__body].queue[1]
end
