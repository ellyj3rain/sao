-- SAO_RadioEar - the county hears you ([A26]).
-- ---------------------------------------------------------------------------
-- The wire's other direction. When the player speaks while carrying a
-- live two-way radio tuned to the county band, the voice physically
-- goes out on 101.2 - the engine's own requirement for a transmission
-- - and the county's radio-keeping companies hear it. Detection is
-- exactly those physical facts: a say line landing in chat
-- (Events.OnAddMessage, the same hook vanilla ISChat registers) plus
-- an on, two-way device on the band in the speaker's inventory.

SAO = SAO or {}

-- [B37] Read, not repeated. SAOWire is set when the wire channel is
-- registered, and the client already reads it at runtime elsewhere.
-- No wire registered means no county channel, so nobody's radio is on
-- it and a player transmitting on the band is talking to nobody -
-- which is why this answers false rather than falling back to a
-- second copy of the number.

-- Exposed ([A26]): the same physical test gates the call verbs.
SAO.RadioEar = SAO.RadioEar or {}

local function hasLiveWireRadio(playerObj)
    local freq = SAOWire and SAOWire.freq or nil
    if not freq then return false end
    if not (playerObj and SAO.Communication
        and SAO.Communication.radioTransmitterAccess
        and SAO.Standing and SAO.Standing.playerKey) then return false end
    local key = SAO.Standing.playerKey(playerObj)
    return SAO.Communication.radioTransmitterAccess(
        key, freq, playerObj) ~= nil
end

SAO.RadioEar.hasLiveWireRadio = hasLiveWireRadio

local function onAddMessage(message, tabID)
    local ok = pcall(function()
        local playerObj = (SAO.Participants and SAO.Participants.player or getSpecificPlayer)(0)
        if not playerObj or playerObj:isDead() then return end
        local author = message and message.getAuthor
            and message:getAuthor() or nil
        if not author or author ~= playerObj:getUsername() then return end
        if not hasLiveWireRadio(playerObj) then return end
        SAO.Standing.hearPlayerOnAir(
            SAO.Standing.playerKey(playerObj), playerObj,
            SAOWire and SAOWire.freq or nil)
    end)
    if not ok then end
end

Events.OnAddMessage.Add(onAddMessage)
