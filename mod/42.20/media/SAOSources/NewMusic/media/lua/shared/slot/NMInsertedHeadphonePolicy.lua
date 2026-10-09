NMInsertedHeadphonePolicy = NMInsertedHeadphonePolicy or {}

local PERSONAL_WORN_TYPE = "Base.Headphones"
local DEVICE_OWNED_TYPE = "Base.Earbuds"

local function normalize(fullType)
    return tostring(fullType or "")
end

function NMInsertedHeadphonePolicy.isSupported(fullType)
    local ft = normalize(fullType)
    return ft == PERSONAL_WORN_TYPE or ft == DEVICE_OWNED_TYPE
end

function NMInsertedHeadphonePolicy.isPersonalWorn(fullType)
    return normalize(fullType) == PERSONAL_WORN_TYPE
end

function NMInsertedHeadphonePolicy.isDeviceOwned(fullType)
    return normalize(fullType) == DEVICE_OWNED_TYPE
end

function NMInsertedHeadphonePolicy.shouldDetachOnGround(fullType)
    return NMInsertedHeadphonePolicy.isPersonalWorn(fullType)
end

function NMInsertedHeadphonePolicy.canAutoReattachFromAvatar(fullType)
    return NMInsertedHeadphonePolicy.isPersonalWorn(fullType)
end

function NMInsertedHeadphonePolicy.isGroundContext(mode)
    local context = tostring(mode or "")
    return context == "placed" or context == "drop_pending"
end

function NMInsertedHeadphonePolicy.shouldApplyAttachedOverride(fullType)
    return NMInsertedHeadphonePolicy.isSupported(fullType)
end

function NMInsertedHeadphonePolicy.shouldApplyPlacedOverride(fullType)
    return false
end

return NMInsertedHeadphonePolicy
