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
    local inv = playerObj:getInventory()
    if not inv then return false end
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        -- [B42] ASK before calling. `getDeviceData` is declared on
        -- `zombie.inventory.types.Radio`, not on `InventoryItem`, so
        -- this threw on every ordinary item in the inventory - a claw
        -- hammer, a bag of chips - once per item, every time the
        -- context menu opened. The pcall swallowed the result and the
        -- loop carried on, so the feature worked and the only symptom
        -- was the console filling with Kahlua stack traces.
        --
        -- That is the class this project keeps finding: a pcall whose
        -- failure is indistinguishable from "nothing there". Testing
        -- the type first is not defensive - it is the difference
        -- between asking a question and guessing.
        local dd = nil
        if instanceof(it, "Radio") then
            local ok
            ok, dd = pcall(function() return it:getDeviceData() end)
            if not ok then dd = nil end
        end
        if dd
            and dd:getIsTurnedOn()
            and dd:getIsTwoWay()
            and dd:getChannel() == freq then
            return true
        end
    end
    return false
end

SAO.RadioEar.hasLiveWireRadio = hasLiveWireRadio

local function onAddMessage(message, tabID)
    local ok = pcall(function()
        local playerObj = getSpecificPlayer(0)
        if not playerObj or playerObj:isDead() then return end
        local author = message and message.getAuthor
            and message:getAuthor() or nil
        if not author or author ~= playerObj:getUsername() then return end
        if not hasLiveWireRadio(playerObj) then return end
        SAO.Standing.hearPlayerOnAir(
            SAO.Standing.playerKey(playerObj))
    end)
    if not ok then end
end

Events.OnAddMessage.Add(onAddMessage)
