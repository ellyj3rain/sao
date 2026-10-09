if not NMTrackFinishedAuthority then
    pcall(require, "playback_progression/NMTrackFinishedAuthority")
end
if not NMPlaybackContinuityPolicy then
    pcall(require, "playback_transition/NMPlaybackContinuityPolicy")
end
if not NMSourceDescriptorSummary then
    pcall(require, "registry/NMSourceDescriptorSummary")
end
if not NMIntentAuthority then
    pcall(require, "intent/NMIntentAuthority")
end
if not NMIntentInventoryOps then
    pcall(require, "intent/NMIntentInventoryOps")
end
if not NMIntentPayloadBuilder then
    pcall(require, "intent/NMIntentPayloadBuilder")
end
if not NMServerIntentFinalization then
    pcall(require, "intents/NMServerIntentFinalization")
end
if not NMServerSlotIntentSpine then
    pcall(require, "intents/NMServerSlotIntentSpine")
end
if not NMServerItemIntentTargeting then
    pcall(require, "intents/item/NMServerItemIntentTargeting")
end
if not NMServerItemIntentTrackFinished then
    pcall(require, "intents/item/NMServerItemIntentTrackFinished")
end
if not NMServerItemIntentAdapter then
    pcall(require, "intents/item/NMServerItemIntentAdapter")
end

NMServerItemIntentPipeline = NMServerItemIntentPipeline or {}
NMServerItemIntentPipeline._progressionHintSig = NMServerItemIntentPipeline._progressionHintSig or {}
NMServerItemIntentPipeline._acceptedTrackFinishedToken = NMServerItemIntentPipeline._acceptedTrackFinishedToken or {}

function NMServerItemIntentPipeline.process(player, args)
    local adapter = NMServerItemIntentAdapter.buildAdapter({
        progressionHintSig = NMServerItemIntentPipeline._progressionHintSig,
        acceptedTrackFinishedToken = NMServerItemIntentPipeline._acceptedTrackFinishedToken
    })
    return NMServerSlotIntentSpine.process(player, args, adapter)
end

return NMServerItemIntentPipeline
