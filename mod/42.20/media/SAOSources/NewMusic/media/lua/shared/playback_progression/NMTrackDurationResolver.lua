-- Shared track duration resolver for authored playlist timing with non-authoritative fallback.
NMTrackDurationResolver = NMTrackDurationResolver or {}

local function resolveFallbackMs(fallbackMs)
    local value = tonumber(fallbackMs) or 210000
    return math.max(1000, math.floor(value + 0.5))
end

local function coerceDurationMsFromRow(row)
    if type(row) ~= "table" then
        return nil, nil
    end
    local durationMs = tonumber(row.authoredDurationMs)
    if durationMs and durationMs > 0 then
        return math.max(1000, math.floor(durationMs + 0.5)), "authored_durationMs"
    end
    local authoredSeconds = tonumber(row.authoredDurationSeconds) or tonumber(row.authoredLengthSeconds) or tonumber(row.authoredDuration)
    if authoredSeconds and authoredSeconds > 0 then
        return math.max(1000, math.floor((authoredSeconds * 1000) + 0.5)), "authored_durationSeconds"
    end
    durationMs = tonumber(row.durationMs)
    if durationMs and durationMs > 0 then
        return math.max(1000, math.floor(durationMs + 0.5)), "playlist_durationMs"
    end
    local durationSeconds = tonumber(row.durationSeconds) or tonumber(row.lengthSeconds) or tonumber(row.duration)
    if durationSeconds and durationSeconds > 0 then
        return math.max(1000, math.floor((durationSeconds * 1000) + 0.5)), "playlist_durationSeconds"
    end
    return nil, nil
end

function NMTrackDurationResolver.resolveForState(state, fallbackMs)
    local fallback = resolveFallbackMs(fallbackMs)
    if not state or not state.mediaFullType or not NMMusic or not NMMusic.resolveTracks then
        return {
            durationMs = fallback,
            knownDuration = false,
            source = "fallback",
            trackIndex = tonumber(state and state.trackIndex) or 1,
            row = nil
        }
    end

    local ok, resolved = pcall(NMMusic.resolveTracks, state.mediaFullType)
    if not ok or type(resolved) ~= "table" or type(resolved.tracks) ~= "table" then
        return {
            durationMs = fallback,
            knownDuration = false,
            source = "fallback",
            trackIndex = tonumber(state and state.trackIndex) or 1,
            row = nil
        }
    end

    local tracks = resolved.tracks
    local count = #tracks
    if count < 1 then
        return {
            durationMs = fallback,
            knownDuration = false,
            source = "fallback",
            trackIndex = tonumber(state and state.trackIndex) or 1,
            row = nil
        }
    end

    local idx = math.max(1, math.min(tonumber(state.trackIndex) or 1, count))
    local row = tracks[idx]
    local durationMs, source = coerceDurationMsFromRow(row)
    if durationMs then
        return {
            durationMs = durationMs,
            authoredDurationMs = durationMs,
            observedDurationMs = tonumber(type(state.observedTrackDurationHints) == "table" and state.observedTrackDurationHints[idx]) or 0,
            knownDuration = true,
            source = source or "playlist_durationMs",
            trackIndex = idx,
            row = row
        }
    end
    local hintTable = type(state and state.observedTrackDurationHints) == "table" and state.observedTrackDurationHints or nil
    local hintedMs = tonumber(hintTable and hintTable[idx]) or 0

    return {
        durationMs = fallback,
        authoredDurationMs = nil,
        observedDurationMs = hintedMs > 0 and math.max(1000, math.floor(hintedMs + 0.5)) or nil,
        knownDuration = false,
        source = "fallback",
        trackIndex = idx,
        row = row
    }
end

