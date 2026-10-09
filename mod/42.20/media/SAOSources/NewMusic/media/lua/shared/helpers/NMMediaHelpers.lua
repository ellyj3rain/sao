-- Shared media payload resolver for insert/eject transitions.
NMMediaHelpers = NMMediaHelpers or {}

function NMMediaHelpers.isInsertableMediaItem(media)
    if not media or not media.getFullType or not media.getType then
        return false
    end

    local fullType = tostring(media:getFullType() or "")
    if fullType == "" then
        return false
    end

    if NMDeviceProfiles and NMDeviceProfiles.getForItem then
        local profile = NMDeviceProfiles.getForItem(media)
        if profile then
            return false
        end
    end

    if NMMediaContract and NMMediaContract.resolveContainerMediaBinding then
        local boundMedia = tostring(NMMediaContract.resolveContainerMediaBinding(fullType) or "")
        if boundMedia ~= "" then
            return false
        end
    end

    local itemType = tostring(media:getType() or "")
    local carrier = NMMediaContract
        and NMMediaContract.resolveMediaCarrier
        and NMMediaContract.resolveMediaCarrier(fullType)
        or nil
    if not carrier then
        carrier = GlobalMusic and GlobalMusic[itemType] or nil
    end
    if carrier and NMMediaContract and NMMediaContract.normalizeCarrierToken then
        carrier = NMMediaContract.normalizeCarrierToken(carrier)
    end
    return carrier ~= nil and tostring(carrier) ~= ""
end

function NMMediaHelpers.resolveMediaInsertPayload(media)
    if NMMediaHelpers.isInsertableMediaItem(media) ~= true then
        return nil
    end

    local fullType = tostring(media:getFullType() or "")
    local itemType = tostring(media:getType() or "")
    local carrier = NMMediaContract
        and NMMediaContract.resolveMediaCarrier
        and NMMediaContract.resolveMediaCarrier(fullType)
        or nil
    if not carrier then
        carrier = GlobalMusic[itemType]
    end
    if carrier and NMMediaContract and NMMediaContract.normalizeCarrierToken then
        carrier = NMMediaContract.normalizeCarrierToken(carrier)
    end
    if not carrier then
        return nil
    end

    local out = {
        mediaCarrier = carrier,
        mediaFullType = fullType,
        mediaEjectFullType = fullType,
        mediaCanonicalFullType = NMMediaContract and NMMediaContract.resolveMediaCanonical and NMMediaContract.resolveMediaCanonical(fullType) or fullType,
        mediaRecordedMediaIndex = nil,
        mediaDisplayName = media.getDisplayName and media:getDisplayName() or nil
    }

    if fullType == "Base.Disc_Retail" and carrier == NMMediaContract.CD_CARRIER then
        local idx = nil
        if media.getRecordedMediaIndex then
            idx = tonumber(media:getRecordedMediaIndex())
        end
        if idx == nil and media.getRecordedMediaIndexInteger then
            idx = tonumber(media:getRecordedMediaIndexInteger())
        end
        if idx == nil then
            idx = -1
        end
        out.mediaFullType = NMMusic.buildVanillaCDTrackKey(idx)
        out.mediaRecordedMediaIndex = idx
    end

    return out
end



