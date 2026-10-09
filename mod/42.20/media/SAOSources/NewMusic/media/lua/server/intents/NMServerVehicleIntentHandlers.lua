if not NMServerSlotIntentSpine then
    pcall(require, "intents/NMServerSlotIntentSpine")
end
if not NMServerVehicleIntentAdapter then
    pcall(require, "intents/vehicle/NMServerVehicleIntentAdapter")
end

-- Server handlers for vehicle radio intents and state replication.
NMServerVehicleIntentHandlers = NMServerVehicleIntentHandlers or {}
NMServerVehicleIntentHandlers._progressionHintSig = NMServerVehicleIntentHandlers._progressionHintSig or {}
NMServerVehicleIntentHandlers._acceptedTrackFinishedToken = NMServerVehicleIntentHandlers._acceptedTrackFinishedToken or {}

function NMServerVehicleIntentHandlers.applyVehicleIntent(player, args)
    local adapter = NMServerVehicleIntentAdapter.buildAdapter({
        progressionHintSig = NMServerVehicleIntentHandlers._progressionHintSig,
        acceptedTrackFinishedToken = NMServerVehicleIntentHandlers._acceptedTrackFinishedToken
    })
    return NMServerSlotIntentSpine.process(player, args, adapter)
end

return NMServerVehicleIntentHandlers
