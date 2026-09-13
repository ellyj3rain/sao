-- SAO_Organization.lua - durable groups, offices, deference, and dissent.

SAO = SAO or {}
SAO.Organization = SAO.Organization or {}
local Org = SAO.Organization

Org.organizations = Org.organizations or {}
Org.offices = Org.offices or {}
Org.claims = Org.claims or {}
Org.decisions = Org.decisions or {}

local RESPONSES = {
    accept = 1.0,
    reluctant = 0.7,
    ignore = 0.0,
    refuse = -0.4,
    appeal = -0.2,
    contest = -0.7,
    exit = -1.0,
    resist = -1.0,
}

local GOVERNANCE = {
    unsettled = "unsettled",
    democratic = "democratic",
    despotic = "despotic",
    localist = "localist",
    federated = "federated",
    communal = "communal",
}

function Org.createOrganization(id, boundary, governance)
    if type(id) ~= "string" or id == "" then return nil end
    local organization = {
        id = id,
        boundary = boundary or {},
        governance = GOVERNANCE[governance] or GOVERNANCE.unsettled,
        members = {},
        offices = {},
        customs = {},
        createdAt = 0,
    }
    Org.organizations[id] = organization
    return organization
end

function Org.join(organizationId, personId)
    local organization = Org.organizations[organizationId]
    if not organization or type(personId) ~= "string" then return false end
    organization.members[personId] = {
        person = personId,
        joinedAt = 0,
        obligations = {},
    }
    return true
end

function Org.leave(organizationId, personId)
    local organization = Org.organizations[organizationId]
    if not organization then return false end
    organization.members[personId] = nil
    for _, office in pairs(Org.offices) do
        if office.organization == organizationId then
            office.holders[personId] = nil
        end
    end
    return true
end

function Org.members(organizationId)
    local organization = Org.organizations[organizationId]
    if not organization then return {} end
    local members = {}
    for personId in pairs(organization.members) do
        members[#members + 1] = personId
    end
    return members
end

function Org.organizationsOf(personId)
    local organizations = {}
    for organizationId, organization in pairs(Org.organizations) do
        if organization.members[personId] then
            organizations[#organizations + 1] = organizationId
        end
    end
    return organizations
end

function Org.createOffice(organizationId, officeId, jurisdiction,
                          legitimacy, succession)
    local organization = Org.organizations[organizationId]
    if not organization or type(officeId) ~= "string" then return nil end
    local key = organizationId .. ":" .. officeId
    local office = {
        id = officeId,
        organization = organizationId,
        jurisdiction = jurisdiction or {},
        legitimacy = legitimacy or "consent",
        succession = succession or "election",
        holders = {},
        decisions = {},
        vacant = true,
    }
    Org.offices[key] = office
    organization.offices[officeId] = office
    return office
end

function Org.appoint(organizationId, officeId, personId)
    local office = Org.offices[organizationId .. ":" .. officeId]
    if not office or type(personId) ~= "string" then return false end
    office.holders[personId] = true
    office.vacant = false
    return true
end

function Org.vacate(organizationId, officeId, personId)
    local office = Org.offices[organizationId .. ":" .. officeId]
    if not office then return false end
    office.holders[personId] = nil
    local holderCount = 0
    for _ in pairs(office.holders) do holderCount = holderCount + 1 end
    office.vacant = holderCount == 0
    return true
end

function Org.recordClaim(claimant, kind, target, organizationId)
    if type(claimant) ~= "string" or type(kind) ~= "string" then return nil end
    local key = claimant .. ":" .. kind .. ":" .. tostring(target)
    local claim = {
        claimant = claimant,
        kind = kind,
        target = target,
        organization = organizationId,
        recognizers = {},
        dissenters = {},
        response = "unanswered",
    }
    Org.claims[key] = claim
    return claim
end

function Org.recognize(claimant, kind, target, recognizer)
    local key = claimant .. ":" .. kind .. ":" .. tostring(target)
    local claim = Org.claims[key]
    if not claim or type(recognizer) ~= "string" then return false end
    claim.recognizers[recognizer] = true
    claim.dissenters[recognizer] = nil
    return true
end

function Org.dissent(claimant, kind, target, dissenter, response)
    local key = claimant .. ":" .. kind .. ":" .. tostring(target)
    local claim = Org.claims[key]
    if not claim then return false end
    claim.dissenters[dissenter] = response or "refuse"
    claim.recognizers[dissenter] = nil
    return true
end

function Org.deference(personId, organizationId, officeId, matter,
                       trust, coercion)
    local office = Org.offices[organizationId .. ":" .. officeId]
    if not office then return "ignore" end
    if not office.jurisdiction[matter] then return "ignore" end

    local legitimacyWeight = 0.5
    if office.legitimacy == "consent" then legitimacyWeight = 0.8 end
    if office.legitimacy == "election" then legitimacyWeight = 0.9 end
    if office.legitimacy == "competence" then legitimacyWeight = 0.7 end
    if office.legitimacy == "custom" then legitimacyWeight = 0.6 end
    if office.legitimacy == "coercion" then legitimacyWeight = 0.2 end

    local trustWeight = math.max(0.0, math.min(1.0, tonumber(trust) or 0.0))
    local coercionWeight = math.max(0.0, math.min(1.0, tonumber(coercion) or 0.0))
    local score = legitimacyWeight * 0.4 + trustWeight * 0.4
        + coercionWeight * 0.2

    if score >= 0.8 then return "accept" end
    if score >= 0.6 then return "reluctant" end
    if score >= 0.4 then return "ignore" end
    if score >= 0.2 then return "refuse" end
    if score >= 0.1 then return "appeal" end
    return "contest"
end

function Org.recordDecision(organizationId, officeId, holder, matter,
                            decision, basis)
    local key = organizationId .. ":" .. officeId .. ":" .. matter
    local record = {
        organization = organizationId,
        office = officeId,
        holder = holder,
        matter = matter,
        decision = decision,
        basis = basis or {},
    }
    Org.decisions[key] = record
    local office = Org.offices[organizationId .. ":" .. officeId]
    if office then office.decisions[#office.decisions + 1] = record end
    return record
end

function Org.succeed(organizationId, officeId, method)
    local office = Org.offices[organizationId .. ":" .. officeId]
    if not office then return nil end
    office.succession = method or office.succession
    if office.succession == "vacancy" then
        office.holders = {}
        office.vacant = true
    end
    return office
end

function Org.playerAction(personId, organizationId, action, target)
    if type(personId) ~= "string" or type(action) ~= "string" then return nil end
    local claim = Org.recordClaim(personId, action, target, organizationId)
    if not claim then return nil end
    if action == "petition" then
        claim.response = "considered"
    elseif action == "support" then
        -- [C105] A claim is never recognized by its own claimant
        -- (ORGANIZATION.md): support records the stance and waits
        -- for somebody ELSE to recognize it.
        claim.response = "recorded"
    elseif action == "contest" then
        Org.dissent(personId, action, target, personId, "contest")
        claim.response = "recorded"
    elseif action == "claim" then
        claim.response = "claimed"
    elseif action == "vote" then
        claim.response = "counted"
    elseif action == "leave" then
        Org.leave(organizationId, personId)
        claim.response = "left"
    else
        claim.response = "recorded"
    end
    return claim
end

return Org
