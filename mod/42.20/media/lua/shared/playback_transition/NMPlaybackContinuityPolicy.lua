-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMPlaybackContinuityPolicy = NMPlaybackContinuityPolicy or {}

local ADVANCE_ACTIONS = {
    play = true,
    stop = true,
    next_track = true,
    prev_track = true,
    power_on = true,
    power_off = true,
    track_finished = true,
    track_finished_world = true
}

function NMPlaybackContinuityPolicy.doesActionAdvancePlaybackContinuity(action)
    return ADVANCE_ACTIONS[tostring(action or "")] == true
end

return NMPlaybackContinuityPolicy
