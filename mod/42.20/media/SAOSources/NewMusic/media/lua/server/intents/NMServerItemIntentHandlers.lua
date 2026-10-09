-- Server handlers for inventory/world item intents and sync actions.
NMServerItemIntentHandlers = NMServerItemIntentHandlers or {}

function NMServerItemIntentHandlers.applyItemIntent(player, args)
    return NMServerItemIntentPipeline.process(player, args or {})
end

function NMServerItemIntentHandlers.handleSyncAttachedWorld(player, args)
    args = args or {}
    if not args.sourceMode or tostring(args.sourceMode) == "" then
        args.sourceMode = "attached"
    end
    return NMServerItemIntentHandlers.applyItemIntent(player, args)
end

function NMServerItemIntentHandlers.handleSyncPlacedWorld(player, args)
    args = args or {}
    if not args.sourceMode or tostring(args.sourceMode) == "" then
        args.sourceMode = "placed"
    end
    return NMServerItemIntentHandlers.applyItemIntent(player, args)
end

function NMServerItemIntentHandlers.handleSyncInventoryStowed(player, args)
    args = args or {}
    if not args.sourceMode or tostring(args.sourceMode) == "" then
        args.sourceMode = "stowed"
    end
    return NMServerItemIntentHandlers.applyItemIntent(player, args)
end

function NMServerItemIntentHandlers.handleSyncPortableAttached(player, args)
    args = args or {}
    args.sourceMode = "attached"
    return NMServerItemIntentHandlers.applyItemIntent(player, args)
end

function NMServerItemIntentHandlers.handleSyncPortablePlaced(player, args)
    args = args or {}
    args.sourceMode = "placed"
    return NMServerItemIntentHandlers.applyItemIntent(player, args)
end

function NMServerItemIntentHandlers.handleSyncPortableStowed(player, args)
    args = args or {}
    args.sourceMode = "stowed"
    return NMServerItemIntentHandlers.applyItemIntent(player, args)
end

function NMServerItemIntentHandlers.handleTrackFinishedWorld(player, args)
    args = args or {}
    args.action = "track_finished"
    args.playbackMode = "world"
    return NMServerItemIntentHandlers.applyItemIntent(player, args)
end

