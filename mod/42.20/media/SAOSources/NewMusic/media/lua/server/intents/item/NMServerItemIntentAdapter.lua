require "intents/item/NMServerItemIntentIngress"
require "intents/item/NMServerItemIntentLogging"
require "intents/item/NMServerItemIntentPostTransition"
require "intents/item/NMServerItemIntentTargeting"
require "intents/item/NMServerItemIntentTrackFinished"
require "intents/item/NMServerItemIntentTransition"

NMServerItemIntentAdapter = NMServerItemIntentAdapter or {}

function NMServerItemIntentAdapter.buildAdapter(options)
    local opts = type(options) == "table" and options or {}

    return {
        resolveTarget = NMServerItemIntentTargeting.resolveTarget,
        onResolveReject = NMServerItemIntentLogging.logItemResolveReject,
        prepareContext = NMServerItemIntentPostTransition.prepareContext,
        normalizeAction = function(ctx, rawAction)
            return NMServerItemIntentTransition.normalizeTransportAction(rawAction, ctx.state, ctx.args)
        end,
        handlePreNormalizedAction = NMServerItemIntentPostTransition.handlePreNormalizedAction,
        normalizeIngress = function(ctx)
            return NMServerItemIntentIngress.normalizeIngressArgsToMainInventory(ctx.player, ctx.args, ctx.action)
        end,
        handleBeforePayload = function(ctx)
            return NMServerItemIntentTrackFinished.handleBeforePayload(
                ctx,
                NMServerItemIntentTrackFinished,
                opts.acceptedTrackFinishedToken,
                opts.progressionHintSig
            )
        end,
        buildPayload = NMServerItemIntentTransition.buildPayload,
        applyTransition = NMServerItemIntentTransition.applyIntentTransition,
        postTransition = NMServerItemIntentPostTransition.postItemIntentTransition,
        finalizeRejectedTransition = NMServerItemIntentPostTransition.finalizeRejectedTransition,
        finalizeTransition = NMServerItemIntentPostTransition.finalizeTransition
    }
end

return NMServerItemIntentAdapter
