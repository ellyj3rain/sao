require "intents/vehicle/NMServerVehicleIntentIngress"
require "intents/vehicle/NMServerVehicleIntentLogging"
require "intents/vehicle/NMServerVehicleIntentPostTransition"
require "intents/vehicle/NMServerVehicleIntentTargeting"
require "intents/vehicle/NMServerVehicleIntentTrackFinished"
require "intents/vehicle/NMServerVehicleIntentTransition"

NMServerVehicleIntentAdapter = NMServerVehicleIntentAdapter or {}

function NMServerVehicleIntentAdapter.buildAdapter(options)
    local opts = type(options) == "table" and options or {}

    return {
        resolveTarget = NMServerVehicleIntentTargeting.resolveTarget,
        onResolveReject = NMServerVehicleIntentLogging.logVehicleResolveReject,
        prepareContext = NMServerVehicleIntentPostTransition.prepareContext,
        onNormalizeReject = NMServerVehicleIntentLogging.logVehicleNormalizeReject,
        normalizeIngress = function(ctx)
            return NMServerVehicleIntentIngress.normalizeIngressArgsToMainInventory(ctx.player, ctx.args, ctx.action)
        end,
        handleBeforePayload = function(ctx)
            return NMServerVehicleIntentTrackFinished.handleBeforePayload(
                ctx,
                NMServerVehicleIntentTrackFinished,
                opts.acceptedTrackFinishedToken,
                opts.progressionHintSig
            )
        end,
        buildPayload = NMServerVehicleIntentTransition.buildPayload,
        validatePayload = NMServerVehicleIntentTransition.validatePayload,
        logIntentAttempt = NMServerVehicleIntentLogging.logIntentAttempt,
        applyTransition = NMServerVehicleIntentTransition.applyIntentTransition,
        afterApplyTransition = NMServerVehicleIntentTransition.afterApplyTransition,
        logTransitionResult = NMServerVehicleIntentLogging.logTransitionResult,
        postTransition = NMServerVehicleIntentPostTransition.postVehicleIntentTransition,
        finalizeTransition = NMServerVehicleIntentPostTransition.finalizeTransition
    }
end

return NMServerVehicleIntentAdapter
