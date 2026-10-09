require "ui/shared/NMReadoutCachedLabelState"

_G.NMWalkmanWindow = _G.NMWalkmanWindow or {}
_G.NMWalkmanWindowEnv = _G.NMWalkmanWindowEnv or {}
local env = _G.NMWalkmanWindowEnv
if getmetatable(env) == nil then
    setmetatable(env, { __index = _G })
end
env.NMWalkmanWindow = _G.NMWalkmanWindow
setfenv(1, env)

NMWalkmanRenderState = NMWalkmanRenderState or {}

function NMWalkmanRenderState.buildCassetteLabelState(window, resolved, variant)
    if not window then
        return nil
    end

    local mediaState = window.getCassetteDisplayMediaState and window:getCassetteDisplayMediaState() or nil
    if not (mediaState and mediaState.visible == true) then
        return nil
    end

    local ctx = resolved or (window.resolveContextCached and window:resolveContextCached()) or nil
    local state = ctx and ctx.state or nil
    local resolvedVariant = variant or (window.resolveWalkmanUIVariant and window:resolveWalkmanUIVariant(ctx)) or nil
    local rect = window.getCassetteLabelRectForVariant and window:getCassetteLabelRectForVariant(resolvedVariant)
        or (window.getCassetteLabelRect and window:getCassetteLabelRect() or nil)
    if not rect then
        return nil
    end
    return NMReadoutCachedLabelState.build(window, {
        state = state,
        rect = rect,
        padX = CASSETTE_LABEL_TEXT_PAD_X,
        nowMs = tonumber(window._nmFrameNowMs) or getNowMs(),
        pagerHost = window,
        emptyAsNil = true,
        cacheName = "walkman_cassette",
        stateIdentityParts = {
            state and state.mediaFullType,
            state and state.trackIndex,
            state and state.mediaDisplayName,
        },
        identityParts = {
            resolvedVariant,
        },
    })
end

return NMWalkmanRenderState
