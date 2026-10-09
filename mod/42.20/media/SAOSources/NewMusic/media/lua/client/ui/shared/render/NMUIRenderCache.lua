-- Canonical shared ui_render cache surface for frame-stable widget state.
NMUIRenderCache = NMUIRenderCache or {}

local function ensureStore(owner)
    if type(owner) ~= "table" then
        return nil
    end
    owner._nmRenderCache = owner._nmRenderCache or {}
    return owner._nmRenderCache
end

function NMUIRenderCache.buildStaticLayer(owner, cacheKey, builderFn, versionKey)
    local store = ensureStore(owner)
    if not store then
        return type(builderFn) == "function" and builderFn() or nil
    end
    local key = tostring(cacheKey or "")
    if key == "" then
        return type(builderFn) == "function" and builderFn() or nil
    end
    local existing = store[key]
    if type(existing) == "table" and existing._nmVersionKey == versionKey then
        return existing
    end
    local built = type(builderFn) == "function" and builderFn() or nil
    if type(built) ~= "table" then
        built = { value = built }
    end
    built._nmVersionKey = versionKey
    store[key] = built
    return built
end

function NMUIRenderCache.invalidateLayer(owner, cacheKey)
    local store = ensureStore(owner)
    if not store then
        return false
    end
    local key = tostring(cacheKey or "")
    if key == "" then
        owner._nmRenderCache = {}
        return true
    end
    store[key] = nil
    return true
end

function NMUIRenderCache.getFrameValue(owner, cacheKey, frameKey, builderFn)
    local store = ensureStore(owner)
    if not store then
        return type(builderFn) == "function" and builderFn() or nil
    end
    local key = tostring(cacheKey or "")
    if key == "" then
        return type(builderFn) == "function" and builderFn() or nil
    end
    local slot = store[key]
    if type(slot) == "table" and slot._nmFrameKey == frameKey then
        return slot.value
    end
    local value = type(builderFn) == "function" and builderFn() or nil
    store[key] = { _nmFrameKey = frameKey, value = value }
    return value
end

return NMUIRenderCache
