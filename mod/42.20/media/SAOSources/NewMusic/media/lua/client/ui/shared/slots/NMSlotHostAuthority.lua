local function resolveNowMs()
    local nowMs = (getTimestampMs and tonumber(getTimestampMs()))
        or (getTimeInMillis and tonumber(getTimeInMillis()))
        or 0
    if nowMs <= 0 and getTimestamp then
        nowMs = (tonumber(getTimestamp()) or 0) * 1000
    end
    return nowMs
end

local function resolveAwaitingSlotEjectMap(window, create)
    if not window then
        return nil
    end
    local map = window._nmAwaitingAuthoritativeSlotEjectByType
    if map == nil and create == true then
        map = {}
        window._nmAwaitingAuthoritativeSlotEjectByType = map
    end
    return map
end

return function(NMSlotHostLifecycle)
    function NMSlotHostLifecycle.markAwaitingAuthoritativeMediaEject(window, fullType)
        if not window then
            return
        end
        local pendingFullType = tostring(fullType or "")
        if pendingFullType == "" then
            window._nmAwaitingAuthoritativeMediaEject = nil
            return
        end
        window._nmAwaitingAuthoritativeMediaInsert = nil
        window._nmAwaitingAuthoritativeMediaEject = {
            active = true,
            fullType = pendingFullType,
            startedAtMs = resolveNowMs()
        }
    end

    function NMSlotHostLifecycle.clearAwaitingAuthoritativeMediaEject(window)
        if window then
            window._nmAwaitingAuthoritativeMediaEject = nil
        end
    end

    function NMSlotHostLifecycle.isAwaitingAuthoritativeMediaEject(window, fullType)
        local awaiting = window and window._nmAwaitingAuthoritativeMediaEject or nil
        if not (awaiting and awaiting.active == true) then
            return false
        end
        local awaitingFullType = tostring(awaiting.fullType or "")
        if tostring(fullType or "") == "" then
            return awaitingFullType ~= ""
        end
        return awaitingFullType ~= "" and awaitingFullType == tostring(fullType or "")
    end

    function NMSlotHostLifecycle.markAwaitingAuthoritativeMediaInsert(window, fullType)
        if not window then
            return
        end
        local pendingFullType = tostring(fullType or "")
        if pendingFullType == "" then
            window._nmAwaitingAuthoritativeMediaInsert = nil
            return
        end
        window._nmAwaitingAuthoritativeMediaEject = nil
        window._nmAwaitingAuthoritativeMediaInsert = {
            active = true,
            fullType = pendingFullType,
            startedAtMs = resolveNowMs()
        }
    end

    function NMSlotHostLifecycle.clearAwaitingAuthoritativeMediaInsert(window)
        if window then
            window._nmAwaitingAuthoritativeMediaInsert = nil
        end
    end

    function NMSlotHostLifecycle.isAwaitingAuthoritativeMediaInsert(window, fullType)
        local awaiting = window and window._nmAwaitingAuthoritativeMediaInsert or nil
        if not (awaiting and awaiting.active == true) then
            return false
        end
        local awaitingFullType = tostring(awaiting.fullType or "")
        if tostring(fullType or "") == "" then
            return awaitingFullType ~= ""
        end
        return awaitingFullType ~= "" and awaitingFullType == tostring(fullType or "")
    end

    function NMSlotHostLifecycle.markAwaitingAuthoritativeSlotEject(window, slotType, fullType)
        local key = tostring(slotType or "")
        local pendingFullType = tostring(fullType or "")
        if key == "" or not window then
            return
        end
        local map = resolveAwaitingSlotEjectMap(window, true)
        if pendingFullType == "" then
            map[key] = nil
            return
        end
        map[key] = {
            active = true,
            fullType = pendingFullType,
            startedAtMs = resolveNowMs()
        }
    end

    function NMSlotHostLifecycle.clearAwaitingAuthoritativeSlotEject(window, slotType)
        local key = tostring(slotType or "")
        if key == "" or not window then
            return
        end
        local map = resolveAwaitingSlotEjectMap(window, false)
        if map then
            map[key] = nil
        end
    end

    function NMSlotHostLifecycle.getAwaitingAuthoritativeSlotEject(window, slotType)
        local key = tostring(slotType or "")
        if key == "" then
            return nil
        end
        local map = resolveAwaitingSlotEjectMap(window, false)
        local awaiting = map and map[key] or nil
        if awaiting and awaiting.active == true then
            return awaiting
        end
        return nil
    end

    function NMSlotHostLifecycle.isAwaitingAuthoritativeSlotEject(window, slotType, fullType)
        local awaiting = NMSlotHostLifecycle.getAwaitingAuthoritativeSlotEject(window, slotType)
        if not awaiting then
            return false
        end
        local awaitingFullType = tostring(awaiting.fullType or "")
        if tostring(fullType or "") == "" then
            return awaitingFullType ~= ""
        end
        return awaitingFullType ~= "" and awaitingFullType == tostring(fullType or "")
    end
end
