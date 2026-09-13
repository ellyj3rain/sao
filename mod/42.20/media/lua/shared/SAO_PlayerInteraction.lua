-- SAO_PlayerInteraction.lua - player claims against the county's organizations.

SAO = SAO or {}
SAO.PlayerInteraction = SAO.PlayerInteraction or {}
local Player = SAO.PlayerInteraction

Player.actions = {
    petition = true,
    support = true,
    contest = true,
    claim = true,
    vote = true,
    appeal = true,
    enforce = true,
    resist = true,
    leave = true,
}

Player.claims = Player.claims or {}

function Player.claim(playerKey, organizationId, action, target)
    local options = SandboxVars and SandboxVars.SurvivorAwareness or nil
    if options and options.PlayerInteraction == false then
        return nil
    end
    if type(playerKey) ~= "string" or not Player.actions[action] then
        return nil
    end
    if not SAO.Organization then return nil end
    local claim = SAO.Organization.playerAction(
        playerKey, organizationId, action, target)
    if claim then
        Player.claims[playerKey .. ":" .. action .. ":" .. tostring(target)] = claim
    end
    return claim
end

function Player.recognizedBy(playerKey, organizationId, action)
    if not SAO.Organization then return false end
    for _, claim in pairs(SAO.Organization.claims) do
        if claim.claimant == playerKey and claim.kind == action then
            -- [C105] An empty recognizers table is nobody: a claim
            -- is recognized when somebody OTHER than the claimant
            -- stands on it.
            for recognizer in pairs(claim.recognizers or {}) do
                if recognizer ~= playerKey then return true end
            end
            return false
        end
    end
    return false
end

function Player.response(playerKey, organizationId, action, target)
    if not SAO.Organization then return "ignore" end
    -- [C105] A READ: the answer the claim already carries. Asking
    -- what happened must never file a new claim ([C104] law - no
    -- writes on reads).
    local key = tostring(playerKey) .. ":" .. tostring(action)
        .. ":" .. tostring(target)
    local claim = Player.claims[key]
        or SAO.Organization.claims[key]
    if not claim then return "ignore" end
    return claim.response or "unanswered"
end

return Player
