NMServerIntentFinalization = NMServerIntentFinalization or {}

function NMServerIntentFinalization.run(options)
    local opts = type(options) == "table" and options or {}
    local resolveKeep = opts.resolveKeep
    local emitState = opts.emitState
    local resolveEntry = opts.resolveEntry
    local broadcastEntry = opts.broadcastEntry

    if type(resolveKeep) ~= "function" or type(emitState) ~= "function" then
        return false, nil, nil, nil
    end

    local keep = resolveKeep()
    if type(opts.repairKeep) == "function" then
        keep = opts.repairKeep(keep) == true
    else
        keep = keep == true
    end

    local prepared = nil
    if type(opts.prepare) == "function" then
        prepared = opts.prepare(keep)
    end

    emitState(keep, prepared)

    local entry = nil
    if type(resolveEntry) == "function" then
        entry = resolveEntry(keep, prepared)
    end

    local op = keep and "upsert" or "remove"
    if entry then
        if type(broadcastEntry) == "function" then
            broadcastEntry(entry, op, keep, prepared)
        end
        if (not keep) and type(opts.removeEntry) == "function" then
            opts.removeEntry(entry, op, keep, prepared)
        end
        if type(opts.afterEntry) == "function" then
            opts.afterEntry(entry, op, keep, prepared)
        end
    elseif type(opts.onMissingEntry) == "function" then
        opts.onMissingEntry(keep, prepared)
    end

    return keep, entry, op, prepared
end

return NMServerIntentFinalization
