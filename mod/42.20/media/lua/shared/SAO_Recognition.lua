-- SAO_Recognition.lua - the record of what the county recognized.
--
-- [C105] Recognition projects only evidenced events from their existing
-- owners. A roster, score, generic message or queued action is not consent.
-- Delivered person-owned responses may support a claim; an accepted office
-- process may project its exact jurisdiction; completed native work may
-- project its receipt-backed result. Settlement grounding remains owned by
-- performed place/development work.

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

-- Retired compatibility hook. A roster settle is neither recognition nor
-- consent; explicit process responses now project offices and claims.
function R.onElection(_groupName, _leaderId, _memberIds)
    return false, "explicit-process-required"
end

-- An interaction claim becomes acquired and answered only by the person who
-- is actually in the conversation. Callers choose from that person's current
-- state; this owner records the admitted reception/return and projects
-- recognition or dissent only from the delivered response.
function R.answerPlayerClaim(claim, recipientId, choice, context)
    if not (orgsReady() and type(claim) == "table" and claim.processId
        and type(recipientId) == "string") then return nil end
    local Org = SAO.Organization
    context = type(context) == "table" and context or {}
    local process = Org.processes[tostring(claim.processId)]
    if not process then return nil end
    local revision = tonumber(claim.processRevision) or process.revision
    if not Org.recordReception(process.id, recipientId, revision,
        context.channel or "spoken", tostring(claim.claimant),
        context.receptionEvidence or { actualRecipient = true }) then
        return nil
    end
    local response = Org.appraiseMatter(process.id, recipientId, {
        owner = context.owner or "Recognition.answerPlayerClaim",
        executor = context.executor or "SAO.Recognition",
        currentActivity = context.currentActivity or "conversation",
        relationship = tonumber(context.relationship) or 0,
        contest = context.contest == true,
        destinationKnown = context.destinationKnown ~= false,
        choice = choice,
        terms = context.terms or {},
        interests = context.interests or {},
        constraints = context.constraints or { actualRecipient = true },
        bodyOwner = context.bodyOwner,
        ownNeed = context.ownNeed,
        canAcquire = context.canAcquire,
        canCarry = context.canCarry,
        canDeliver = context.canDeliver,
        canExecute = context.canExecute,
        dead = context.dead == true,
        incapable = context.incapable == true,
    })
    if not response then return nil end
    if not Org.deliverResponse(process.id, recipientId,
        tostring(claim.claimant), context.channel or "spoken",
        context.returnEvidence or { actualRecipient = true }) then
        return nil
    end
    if response.response == "accept" then
        Org.recognize(claim.claimant, claim.kind, claim.target,
            recipientId, process.id)
    elseif response.response == "contest" or response.response == "decline" then
        Org.dissent(claim.claimant, claim.kind, claim.target,
            recipientId, response.response, process.id)
    end
    claim.response = response.response
    return response, process
end

function R.membershipAuthority(groupName, personId)
    if not SAO.Organization then return false end
    groupName, personId = tostring(groupName or ""), tostring(personId or "")
    if SAO.Organization.officeAuthority
        and SAO.Organization.officeAuthority(groupName, "chair", personId,
            "membership") then
        return true
    end
    return #SAO.Organization.authorityFor(personId, groupName,
        "membership") > 0
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
    if Org and Org.retireOrganization then
        Org.retireOrganization(groupName, "house-dissolved")
    elseif Org then
        -- Legacy fallback for a partially loaded module set. Current builds
        -- retire all offices and active work through Organization above.
        if Org.organizations then Org.organizations[groupName] = nil end
        if Org.offices then Org.offices[officeKey(groupName, "chair")] = nil end
    end
    return true
end

function R.onChairTaken(groupName, playerKey)
    return false, "explicit-process-required"
end

-- The house offered the chair: the offer is the recognition half of
-- the claim, filed at the moment the house decided to make it -
-- before the player ever answers.
function R.onChairOffered(groupName, playerKey)
    return false, "explicit-process-required"
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
    return false, "explicit-process-required"
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
    return false, "command-owner-records-process"
end

-- A pact formed between two houses: external relations, decided
-- leader to leader, recorded on both sides.
function R.onPactFormed(gA, gB)
    return false, "explicit-process-required"
end

-- A schism: the leavers answered the old house with exit - the
-- strongest response in the deference enum. Their membership lapses
-- when the rosters settle through onElection; this records the
-- response itself, on the house that broke.
function R.onSchism(groupName, coreId, leftCount)
    return false, "explicit-process-required"
end

-- A promise asked: "if I turn, you do it" is a claim between two
-- people ([B3]), recorded at the moment it is asked.
function R.onPromiseAsked(bittenId, keeperId)
    return false, "standing-owner-records-process"
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
    if not orgsReady() or not dial("Organization") then return nil end
    groupName, chairKey, playerKey = tostring(groupName or ""),
        tostring(chairKey or ""), tostring(playerKey or "")
    if groupName == "" or chairKey == "" or playerKey == "" then return nil end
    local process = SAO.Organization.raiseMatter(chairKey, "work-offer",
        groupName, {
            word = tostring(word or "watch"),
            label = tostring(label or word or "watch"),
            recipientId = playerKey,
            scope = { action = "take-work", responsibility = tostring(
                word or "watch"), organization = groupName,
                arrangement = true },
        }, { playerKey }, {
            source = "accepted-work-petition", offeredBy = chairKey,
        })
    if process then
        SAO.Organization.recordReception(process.id, playerKey,
            process.revision, "spoken", chairKey,
            { actualRecipient = true })
    end
    return process
end

-- [C106] The player answered the chair's dealt word. Accepting is a
-- claim the chair recognizes - "I take the foraging" is true because
-- the office that dealt it says so. Refusing is the same word
-- refused, recorded on the decision the office made, and the house
-- loses nothing it did not already have.
function R.onWorkAnswered(processId, playerKey, accepted)
    if not orgsReady() then return nil end
    local Org = SAO.Organization
    local process = Org.processes[tostring(processId or "")]
    playerKey = tostring(playerKey or "")
    if not process or process.kind ~= "work-offer"
        or not process.participants[playerKey] then return nil end
    local response = Org.appraiseMatter(process.id, playerKey, {
        owner = "Recognition.onWorkAnswered", executor = "player",
        currentActivity = "player-choice", destinationKnown = true,
        choice = accepted and "accept" or "decline",
        interests = { selectedByPlayer = true },
        constraints = { actualRecipient = true },
    })
    if response then
        Org.deliverResponse(process.id, playerKey, process.originatorId,
            "spoken", { selectedByPlayer = true })
    end
    return response
end

-- [C106] The player appealed over the chair to the house. The appeal
-- is a claim; the members answer it for themselves - each one who
-- trusts the player past the company bar recognizes it, each one who
-- does not says nothing. No majority is invented: one voice standing
-- with the player moves the claim to "appealed"; none leaves it
-- recorded, and the house continues either way.
function R.onAppealTaken(groupName, playerKey, matter, recipientId)
    if not orgsReady() then return {} end
    if not dial("Organization") then return {} end
    local Org = SAO.Organization
    groupName = tostring(groupName or "")
    playerKey = tostring(playerKey or "")
    recipientId = tostring(recipientId or "")
    local appeal = Org.claims[playerKey .. ":appeal:" .. tostring(matter)]
    if not appeal or recipientId == ""
        or (SAO.Standing and SAO.Standing.groupOf(recipientId)) ~= groupName then
        return {}
    end
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local bar = (sv and tonumber(sv.TrustToCompany)) or 0.5
    local trust = SAO.Standing.trust(recipientId, playerKey)
    local response = R.answerPlayerClaim(appeal, recipientId,
        trust > bar and "accept" or "decline", {
            owner = "Recognition.onAppealTaken",
            relationship = trust,
            interests = { matter = tostring(matter) },
        })
    return response and response.response == "accept"
        and { recipientId } or {}
end

-- [C106] The player claimed the chair uninvited. The claim is
-- recorded by the ask; what this reckons is the house's answer - each
-- member who trusts the player past the company bar recognizes the
-- claim as a fact they stand behind. The OFFICE does not move: a
-- self-declared claim is not a recognized office (ORGANIZATION.md,
-- the boundary list), and the chair changes hands only through the
-- house's own offer or election. Recognition here is the house's
-- memory of who would have them, nothing more.
function R.onOfficeClaimed(groupName, playerKey, recipientId)
    if not orgsReady() then return {} end
    if not dial("Organization") then return {} end
    local Org = SAO.Organization
    groupName = tostring(groupName or "")
    playerKey = tostring(playerKey or "")
    recipientId = tostring(recipientId or "")
    local claim = Org.claims[playerKey .. ":claim:chair"]
    if not claim or recipientId == ""
        or (SAO.Standing and SAO.Standing.groupOf(recipientId)) ~= groupName then
        return {}
    end
    local sv = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local bar = (sv and tonumber(sv.TrustToCompany)) or 0.5
    local trust = SAO.Standing.trust(recipientId, playerKey)
    local response = R.answerPlayerClaim(claim, recipientId,
        trust > bar and "accept" or "contest", {
            owner = "Recognition.onOfficeClaimed",
            relationship = trust, contest = trust <= bar,
            interests = { office = "chair" },
        })
    return response and response.response == "accept"
        and { recipientId } or {}
end

return R
