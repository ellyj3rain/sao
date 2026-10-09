-- Server reconcile pass for mode/source consistency in registry snapshots.
NMServerModeReconcile = NMServerModeReconcile or {}

function NMServerModeReconcile.onTick()
    for uuid, entry in pairs(NMServerRegistryState.worldRegistry) do
        local state = entry and entry.stateSnapshot or nil
        if state then
            NMAuthorityV4.ensureState(state)
            local mode = tostring(state.authoritativeMode or "off")

            if mode == "off" then
                NMServerRegistryState.worldRegistry[uuid] = nil
            elseif mode == "attached" then
                entry.sourceMode = "attached"
                entry.sourceEpoch = math.max(tonumber(entry.sourceEpoch) or 0, tonumber(state.sourceGeneration) or 0)
                entry.sourceGeneration = entry.sourceEpoch
                entry.stateSnapshot = NMDeviceState.export(state)
            elseif mode == "placed" then
                entry.sourceMode = "placed"
                entry.sourceEpoch = math.max(tonumber(entry.sourceEpoch) or 0, tonumber(state.sourceGeneration) or 0)
                entry.sourceGeneration = entry.sourceEpoch
                entry.stateSnapshot = NMDeviceState.export(state)
            elseif mode == "vehicle" then
                entry.sourceMode = "vehicle"
                entry.sourceEpoch = math.max(tonumber(entry.sourceEpoch) or 0, tonumber(state.sourceGeneration) or 0)
                entry.sourceGeneration = entry.sourceEpoch
                entry.stateSnapshot = NMDeviceState.export(state)
            elseif mode == "stowed" then
                entry.sourceMode = "stowed"
                entry.sourceEpoch = math.max(tonumber(entry.sourceEpoch) or 0, tonumber(state.sourceGeneration) or 0)
                entry.sourceGeneration = entry.sourceEpoch
                entry.stateSnapshot = NMDeviceState.export(state)
            end

            if entry and (not NMRegistryPolicy.shouldKeepWorldSourceState(state)) then
                NMServerRegistryState.worldRegistry[uuid] = nil
            end
        end
    end
end

