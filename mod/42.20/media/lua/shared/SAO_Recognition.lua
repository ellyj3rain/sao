-- SAO_Recognition.lua - the record of what the county recognized.
--
-- [C105] The graph's write side is driven by one law: nothing here
-- decides anything. Every function is called AFTER a real event in the
-- county's own machinery - an election that settled, a chair accepted, a
-- promise asked, an order that landed, a pact formed, a hearth lit, a
-- real item shelved - and records what ALREADY happened into the
-- organization, settlement, material, and communication surfaces
-- (ORGANIZATION.md: "An organization is a result"). The graph pass
-- ([C104]) observes; this file is what the county's own verbs report.
--
-- A group existing does not found an organization. The house's first
-- SETTLED ELECTION does: that is the moment ORGANIZATION.md names -
-- people who repeatedly acted together accepting a way to decide
-- together. Settlement grounding belongs to performed place/development
-- work; provisioning can only refresh a settlement that already exists.
-- An order asked is nothing; the verdict the follower actually returns is
-- the deference fact.

SAO = SAO or {}
SAO.Recognition = SAO.Recognition or {}
local R = SAO.Recognition

-- The dials ([C104] sandbox surface). Organization and Settlement
-- recording are switchable; the rest of the chain rides with them.
local function dial(name)
    local options = SandboxVars and SandboxVars.SurvivorAwareness or nil
    if not options then return true end
    return options[name] ~= false
end

local function orgsReady()
    return SAO.Organization and SAO.Settlement and SAO.Communication
        and SAO.Material and true or false
end

local function officeKey(organizationId, officeId)
    return tostring(organizationId) .. ":" .. tostring(officeId)
end

-- The chair office every settled house holds: jurisdiction is what a
-- leader actually decides here (membership, the deal of work, the
-- quarrel, the shelves), legitimacy is the trust-summed election that
-- settled it, succession is the same election run again.
local CHAIR_JURISDICTION = {
    membership = true,
    ["work assignment"] = true,
    ["dispute resolution"] = true,
    ["resource allocation"] = true,
}

-- A settled election: the house accepted a way to decide. First settle
-- founds the organization record and the chair; later settles that
-- change the leader are succession, recorded with the basis the
-- election itself ran on (trust sums, the designated deal). Called
-- from Standing.electLeader only after a roster of two or more
-- actually settled on a leader.
function R.onElection(groupName, leaderId, memberIds)
    if not orgsReady() then return end
    if not dial("Organization") then return end
    groupName = tostring(groupName)
    local Org = SAO.Organization
    local organization = Org.organizations[groupName]
    if not organization then
        local claim = SAO.Standing and SAO.Standing.groupClaimOf
            and SAO.Standing.groupClaimOf(groupName) or nil
        local form = nil
        pcall(function()
            form = SAO.Standing.formOf and SAO.Standing.formOf(groupName)
                or nil
        end)
        organization = Org.createOrganization(groupName, claim or {}, form)
    end
    if not organization then return end
    for _, memberId in ipairs(memberIds or {}) do
        if not organization.members[memberId] then
            Org.join(groupName, memberId)
        end
    end
    -- The roster is the real membership: the dead, the exiled, and the
    -- schism-leavers stop being members because the settled roster says
    -- so, not because anything here decided it.
    local onRoster = {}
    for _, memberId in ipairs(memberIds or {}) do
        onRoster[memberId] = true
    end
    for memberId in pairs(organization.members) do
        if not onRoster[memberId] then
            Org.leave(groupName, memberId)
        end
    end
    local office = Org.offices[officeKey(groupName, "chair")]
    if not office then
        office = Org.createOffice(groupName, "chair",
            CHAIR_JURISDICTION, "election", "election")
    end
    if not office then return end
    -- [C106] The settled election is the members' recognition of the
    -- leader's claim to lead - ORGANIZATION.md's own example. The
    -- claim exists once; every settle (a new leader OR a continuing
    -- one with a changed roster) refreshes who stands behind it. The
    -- leader never recognizes their own claim.
    do
        local leadKey = tostring(leaderId) .. ":lead:" .. groupName
        local lead = Org.claims[leadKey]
        if not lead then
            lead = Org.recordClaim(tostring(leaderId), "lead", groupName,
                groupName)
            if lead then lead.response = "accepted" end
        end
        if lead then
            for _, memberId in ipairs(memberIds or {}) do
                if tostring(memberId) ~= tostring(leaderId) then
                    Org.recognize(tostring(leaderId), "lead", groupName,
                        tostring(memberId))
                end
            end
        end
    end
    local heldBefore = office.holders and office.holders[leaderId] or nil
    -- Only a CHANGED settle is succession; re-electing the same
    -- leader is the same office continuing, and records nothing.
    if heldBefore and office.vacant == false then
        return
    end
    local okH, hours = pcall(function()
        return SAO.History.countyHours()
    end)
    if office.vacant == false then
        for holder in pairs(office.holders or {}) do
            Org.vacate(groupName, "chair", holder)
        end
    end
    Org.appoint(groupName, "chair", leaderId)
    Org.recordDecision(groupName, "chair", leaderId, "succession",
        "elected", {
            basis = "trust-summed election over a settled roster",
            atHours = okH and hours or 0,
        })
end

-- The house is done: the roster emptied or released its widow. The
-- record lapses with it - no organization outlives the people.
function R.onHouseDissolved(groupName)
    groupName = tostring(groupName or "")
    if groupName == "" then return false end
    if SAO.Material and SAO.Material.forgetHouse then
        SAO.Material.forgetHouse(groupName)
    end
    if SAO.Settlement and SAO.Settlement.bases then
        SAO.Settlement.bases[groupName] = nil
    end
    local Org = SAO.Organization
    if Org and Org.organizations and Org.organizations[groupName] then
        Org.organizations[groupName] = nil
    end
    if Org and Org.offices then
        Org.offices[officeKey(groupName, "chair")] = nil
    end
    return true
end

-- The chair accepted: the house offered, the player sat. The offer
-- was the recognition; the sitting is the response.
function R.onChairTaken(groupName, playerKey)
    if not orgsReady() then return end
    if not dial("Organization") then return end
    local Org = SAO.Organization
    groupName = tostring(groupName)
    playerKey = tostring(playerKey)
    local key = playerKey .. ":chair:" .. groupName
    local claim = Org.claims[key]
        or Org.recordClaim(playerKey, "chair", groupName, groupName)
    if claim then
        Org.recognize(playerKey, "chair", groupName, groupName)
        claim.response = "accepted"
    end
    local office = Org.offices[officeKey(groupName, "chair")]
    if office and office.vacant == false then
        for holder in pairs(office.holders or {}) do
            Org.vacate(groupName, "chair", holder)
        end
    end
    Org.appoint(groupName, "chair", playerKey)
end

-- The house offered the chair: the offer is the recognition half of
-- the claim, filed at the moment the house decided to make it -
-- before the player ever answers.
function R.onChairOffered(groupName, playerKey)
    if not orgsReady() then return end
    if not dial("Organization") then return end
    groupName = tostring(groupName)
    playerKey = tostring(playerKey)
    local key = playerKey .. ":chair:" .. groupName
    if not SAO.Organization.claims[key] then
        SAO.Organization.recordClaim(playerKey, "chair", groupName,
            groupName)
    end
end

-- The player declined the chair: the response half of the same
-- claim. The claim stands answered, not erased - a refusal is a
-- fact about the offer, and the house keeps the memory.
function R.onChairDeclined(groupName, playerKey)
    if not orgsReady() then return end
    local key = tostring(playerKey) .. ":chair:" .. tostring(groupName)
    local claim = SAO.Organization.claims[key]
    if claim then claim.response = "refused" end
end

-- The house took the chair back ([A27]'s unseating): the trust
-- collapsed at the table the chair was granted at. The office
-- empties with the fact.
function R.onChairWithdrawn(groupName, playerKey)
    if not orgsReady() then return end
    if SAO.Organization.offices[officeKey(groupName, "chair")] then
        SAO.Organization.vacate(groupName, "chair", tostring(playerKey))
    end
end

-- A petition asked and answered. Acceptance is the leader's
-- recognition of the player's claim to belong; refusal is the same
-- claim answered the other way. Either way, the exchange is a fact.
function R.onPetitionAnswered(groupName, playerKey, judgeKey, accepted)
    if not orgsReady() then return end
    if not dial("Organization") then return end
    local Org = SAO.Organization
    groupName = tostring(groupName)
    playerKey = tostring(playerKey)
    local key = playerKey .. ":petition:" .. groupName
    local claim = Org.claims[key]
        or Org.recordClaim(playerKey, "petition", groupName, groupName)
    if not claim then return end
    if accepted then
        if judgeKey then
            Org.recognize(playerKey, "petition", groupName,
                tostring(judgeKey))
        end
        claim.response = "accepted"
        -- [C106] The acceptance IS the membership: the organization's
        -- own roster carries the player from the moment the leader
        -- said yes, so leave has something real to leave.
        if not Org.organizations[groupName]
            or not Org.organizations[groupName].members[playerKey] then
            Org.join(groupName, playerKey)
        end
    else
        claim.response = "refused"
    end
end

-- A performed provisioning result may update a settlement that an independent
-- place/development producer already grounded. It cannot create rooms, food,
-- water, membership, an organization or a settlement from a provisioning
-- signal. Material remains authoritative for the observed native projection.
function R.onProvisioned(groupName, evidence)
    if not (SAO.Settlement and SAO.Material) then
        return false, "recording-unavailable"
    end
    if not dial("Settlement") then return true, "settlement-disabled" end
    groupName = tostring(groupName or "")
    if groupName == "" or type(evidence) ~= "table"
        or type(evidence.receipt) ~= "table"
        or type(evidence.material) ~= "table" then
        return false, "invalid-evidence"
    end
    local Settlement = SAO.Settlement
    local base = Settlement.bases[groupName]
    if not base then return true, "not-grounded" end
    if not Settlement.isGrounded or not Settlement.isGrounded(base) then
        return false, "ungrounded-settlement"
    end
    if not Settlement.reconcileStorage then
        return false, "reconcile-unavailable"
    end
    local reconciled = Settlement.reconcileStorage(groupName,
        evidence.material, evidence.receipt)
    return reconciled and true or false,
        reconciled and "reconciled" or "reconcile-refused"
end

-- An order landed and the follower returned a verdict. That exchange
-- is the deference fact ORGANIZATION.md records three ways: the
-- office's decision, and the person's actual response to it.
function R.onOrder(giverKey, id, kind, arg, verdict)
    if not orgsReady() then return end
    if not dial("Organization") then return end
    local Org = SAO.Organization
    local group = SAO.Standing and SAO.Standing.groupOf
        and SAO.Standing.groupOf(id) or nil
    if not group then return end
    local office = Org.offices[officeKey(group, "chair")]
    -- The giver holds the chair over this person, or nobody does:
    -- a personal request is not an exercise of authority.
    if not office or not office.holders[giverKey] then return end
    local response = verdict
    if verdict == "complies" then response = "accept" end
    if verdict == "reluctant" then response = "reluctant" end
    if verdict == "refuses" then response = "refuse" end
    Org.recordDecision(group, "chair", giverKey, tostring(kind or "walk"),
        response, { towards = id, arg = arg })
end

-- A pact formed between two houses: external relations, decided
-- leader to leader, recorded on both sides.
function R.onPactFormed(gA, gB)
    if not orgsReady() then return end
    if not dial("Organization") then return end
    local Org = SAO.Organization
    for _, pair in ipairs({ { gA, gB }, { gB, gA } }) do
        local group, other = pair[1], pair[2]
        if Org.organizations[group] then
            Org.recordDecision(group, "chair", nil,
                "external relations", "pact", { with = other })
        end
    end
end

-- A schism: the leavers answered the old house with exit - the
-- strongest response in the deference enum. Their membership lapses
-- when the rosters settle through onElection; this records the
-- response itself, on the house that broke.
function R.onSchism(groupName, coreId, leftCount)
    if not orgsReady() then return end
    if not dial("Organization") then return end
    if leftCount < 2 then return end
    local Org = SAO.Organization
    if not Org.organizations[groupName] then return end
    Org.recordDecision(groupName, "chair", nil, "membership", "exit", {
        core = coreId, left = leftCount,
    })
end

-- A promise asked: "if I turn, you do it" is a claim between two
-- people ([B3]), recorded at the moment it is asked.
function R.onPromiseAsked(bittenId, keeperId)
    if not orgsReady() then return end
    SAO.Organization.recordClaim(keeperId, "promise", bittenId, nil)
end

-- One person told another something real - grudge, credit, news.
-- The tell is the message; the hearing is the delivery.
function R.onTold(fromId, toId, kind, payload)
    if not orgsReady() then return end
    if not dial("Communication") then return end
    local message = SAO.Communication.send(fromId, toId, kind, payload)
    if message then SAO.Communication.deliver(message) end
end

-- [C106] The chair dealt the player work. The ask came from the
-- player; the word came from the office - work assignment is the
-- chair's own jurisdiction, so the dealt word is a decision of the
-- office, recorded under that matter with the player named in the
-- basis. What the player does with it is theirs; this is the record.
function R.onWorkDealt(groupName, chairKey, playerKey, word, label)
    if not orgsReady() then return end
    if not dial("Organization") then return end
    groupName = tostring(groupName or "")
    local Org = SAO.Organization
    if not Org.organizations[groupName] then return end
    Org.recordDecision(groupName, "chair", tostring(chairKey or ""),
        "work assignment", tostring(word or "watch"), {
            towards = tostring(playerKey or ""),
            label = tostring(label or word or "watch"),
        })
end

-- [C106] The player answered the chair's dealt word. Accepting is a
-- claim the chair recognizes - "I take the foraging" is true because
-- the office that dealt it says so. Refusing is the same word
-- refused, recorded on the decision the office made, and the house
-- loses nothing it did not already have.
function R.onWorkAnswered(groupName, playerKey, word, chairKey, accepted)
    if not orgsReady() then return end
    local Org = SAO.Organization
    groupName = tostring(groupName or "")
    playerKey = tostring(playerKey or "")
    word = tostring(word or "")
    local kind = accepted and "claim" or "contest"
    local key = playerKey .. ":" .. kind .. ":" .. word
    local claim = Org.claims[key]
    if claim then
        if accepted then
            if chairKey then
                Org.recognize(playerKey, kind, word, tostring(chairKey))
            end
            claim.response = "accepted"
        else
            claim.response = "refused"
        end
    end
    local dealt = Org.decisions[groupName .. ":chair:work assignment"]
    if dealt and dealt.basis and tostring(dealt.basis.towards) == playerKey
        and tostring(dealt.decision) == word then
        dealt.basis.response = accepted and "accepted" or "refused"
    end
end

-- [C106] The player appealed over the chair to the house. The appeal
-- is a claim; the members answer it for themselves - each one who
-- trusts the player past the company bar recognizes it, each one who
-- does not says nothing. No majority is invented: one voice standing
-- with the player moves the claim to "appealed"; none leaves it
-- recorded, and the house continues either way.
function R.onAppealTaken(groupName, playerKey, matter)
    if not orgsReady() then return {} end
    if not dial("Organization") then return {} end
    local Org = SAO.Organization
    groupName = tostring(groupName or "")
    playerKey = tostring(playerKey or "")
    local appeal = Org.claims[playerKey .. ":appeal:" .. tostring(matter)]
    if not appeal then return {} end
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local bar = (sv and tonumber(sv.TrustToCompany)) or 0.5
    local leader = SAO.Standing and SAO.Standing.leaderOf
        and SAO.Standing.leaderOf(groupName) or nil
    local backers = {}
    local members = SAO.Standing and SAO.Standing.membersOf
        and SAO.Standing.membersOf(groupName) or {}
    for _, memberId in ipairs(members) do
        local mid = tostring(memberId)
        if mid ~= playerKey and mid ~= tostring(leader or "") then
            local trust = SAO.Standing and SAO.Standing.trust
                and SAO.Standing.trust(mid, playerKey) or 0
            if trust > bar then
                Org.recognize(playerKey, "appeal", tostring(matter), mid)
                backers[#backers + 1] = mid
            end
        end
    end
    if #backers > 0 then
        appeal.response = "appealed"
    end
    return backers
end

-- [C106] The player claimed the chair uninvited. The claim is
-- recorded by the ask; what this reckons is the house's answer - each
-- member who trusts the player past the company bar recognizes the
-- claim as a fact they stand behind. The OFFICE does not move: a
-- self-declared claim is not a recognized office (ORGANIZATION.md,
-- the boundary list), and the chair changes hands only through the
-- house's own offer or election. Recognition here is the house's
-- memory of who would have them, nothing more.
function R.onOfficeClaimed(groupName, playerKey)
    if not orgsReady() then return {} end
    if not dial("Organization") then return {} end
    local Org = SAO.Organization
    groupName = tostring(groupName or "")
    playerKey = tostring(playerKey or "")
    local claim = Org.claims[playerKey .. ":claim:chair"]
    if not claim then return {} end
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local bar = (sv and tonumber(sv.TrustToCompany)) or 0.5
    local leader = SAO.Standing and SAO.Standing.leaderOf
        and SAO.Standing.leaderOf(groupName) or nil
    local recognizers = {}
    local members = SAO.Standing and SAO.Standing.membersOf
        and SAO.Standing.membersOf(groupName) or {}
    for _, memberId in ipairs(members) do
        local mid = tostring(memberId)
        if mid ~= playerKey and mid ~= tostring(leader or "") then
            local trust = SAO.Standing and SAO.Standing.trust
                and SAO.Standing.trust(mid, playerKey) or 0
            if trust > bar then
                Org.recognize(playerKey, "claim", "chair", mid)
                recognizers[#recognizers + 1] = mid
            end
        end
    end
    return recognizers
end

return R
