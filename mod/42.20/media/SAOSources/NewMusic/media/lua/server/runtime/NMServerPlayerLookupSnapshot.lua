-- Build one per-tick snapshot of online players keyed by id and username.
NMServerPlayerLookupSnapshot = NMServerPlayerLookupSnapshot or {}

function NMServerPlayerLookupSnapshot.build()
    local byId = {}
    local byName = {}
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then
        return byId, byName
    end
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p then
            local id = p.getOnlineID and tostring(p:getOnlineID() or "") or ""
            local name = p.getUsername and tostring(p:getUsername() or "") or ""
            if id ~= "" then
                byId[id] = p
            end
            if name ~= "" then
                byName[string.lower(name)] = p
            end
        end
    end
    return byId, byName
end

return NMServerPlayerLookupSnapshot
