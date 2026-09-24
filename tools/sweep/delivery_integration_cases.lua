(function()
    local S, P, C, V = SAO.Standing, SAO.Perception, SAO.Communication, SAO.Provisioning
    local results = {}
    local function check(name, value)
        __deliveryIntegrationLast = name
        results[#results + 1] = name .. "=" .. tostring(value == true)
    end
    local function mind(id)
        local b = P.beliefs[id]
        if not b then
            b = { zombies={}, people={}, factions={}, places={}, known={} }
            P.beliefs[id] = b
        end
        return b
    end
    local function reset()
        __now, __stores, __records, __bodies, __represented = 100, {}, {}, {}, {}
        __unavailable, __hearing, __player = {}, {}, nil
        __loadedResult, __loadedThrows, __hearingThrows = true, false, false
        __ackAllowed, __ackCalls, __graphAvailable = true, {}, true
        __nativeCalls, __hearingCalls = {}, {}
        __weather, __weatherThrows = 1, false
        SAO.Controller.agents = {}
        SAO.Organization.organizations, SAO.Organization.offices = {}, {}
        SAO.Organization.claims, SAO.Organization.decisions = {}, {}
        SAO.Organization.claimHistory, SAO.Organization.decisionHistory = {}, {}
        SAO.Organization.processes, SAO.Organization.processOrder = {}, {}
        SAO.Organization.processMeta, SAO.Organization.workReceipts =
            { sequence = 0 }, {}
        SAO.Material = nil
        SandboxVars.SurvivorAwareness.Material = true
        P.beliefs, P.beliefVersion = {}, 0
        __stores.SurvivorAwareness_Beliefs = P.beliefs
        local standing = { schema=4, groups={requester='hungry',carrier='home'},
            groupMeta={home={creedName='mercy',larder={word='full',atHours=100}},
                hungry={}, remote={}},
            groupClaims={home={minX=0,minY=0,maxX=4,maxY=4},
                hungry={minX=80,minY=80,maxX=84,maxY=84},
                remote={minX=120,minY=120,maxX=124,maxY=124}},
            relations={}, claims={}, migrations={} }
        __stores.SurvivorAwareness_Standing = standing
        for _, id in ipairs({'actor','witness','requester','carrier','relay','outsider'}) do
            __records[id] = {id=id,x=10,y=10,z=0,sleeping=false,
                dormantSleeping=false,hibernation='native-' .. id}
            __bodies[id] = {id=id}
            __hearing['native-' .. id] = 'AVAILABLE:1.0'
            standing.relations[id] = {}
            for _, other in ipairs({'actor','witness','requester','carrier','relay','outsider'}) do
                standing.relations[id][other] = {trust=0.6}
            end
        end
        return standing
    end
    local function request(id, group)
        local b = P.beliefs[id]
        return b and b.aidRequests and b.aidRequests[group or 'hungry']
    end
    local function receipt(id)
        return {reservationId=id or 'transfer-1',actorId='actor',
            status='completed',operation='store',category='food',itemType='Base.Apple',
            sourceId='C:pantry',sourceFingerprint='pantry-fp',sourceKind='container',
            sourceX=99,sourceY=99,sourceZ=0,placeId='house-1',at=__now,
            provisioningContext='personal',materialProjectionEnabled=false,
            transferObservation={actorId='actor',at=100,x=10,y=12,z=0,nativeTransferProven=true,
                witnesses={'witness'},appraisals={}}}
    end
    local function fact(id, event)
        return P.transferFact(id, event or 'transfer-1')
    end

    local standing = reset()
    local called = S.callForBread('hungry','requester')
    local origin = request('requester')
    check('request_origin_production_api',called and origin
        and origin.source == 'requested' and origin.requestedAt == 100
        and origin.acquiredAt == 100 and origin.originId == 'requester')
    __now = 110
    check('request_cooldown_preserves_time',not S.callForBread('hungry','requester')
        and standing.groupMeta.hungry.askedAtHours == 100
        and origin and origin.requestedAt == 100
        and #(standing.radioNews or {}) == 1)

    standing = reset()
    local record = P.recordAidRequest
    P.recordAidRequest = function() return false end
    local rejected = S.callForBread('hungry','requester')
    P.recordAidRequest = record
    check('failed_origin_has_no_cooldown',not rejected
        and standing.groupMeta.hungry.askedAtHours == nil
        and #(standing.radioNews or {}) == 0)
    local retry = S.callForBread('hungry','requester')
    check('failed_origin_retry',retry and request('requester') ~= nil
        and standing.groupMeta.hungry.askedAtHours == 100)

    standing = reset()
    local sourceLess = S.callForBread('hungry')
    check('source_less_request_refused',not sourceLess
        and request('requester') == nil and not S.isAsking('hungry'))
    mind('carrier').factions.hungry = {minX=8,minY=8,maxX=12,maxY=12}
    check('global_only_request_not_selected',not S.isAsking('hungry')
        and S.nearestAsking('home','carrier') == nil)

    standing = reset()
    S.callForBread('hungry','requester')
    local firstRequest = request('requester')
    P.recordAidRequest('carrier','hungry',100,'told','requester','food',
        firstRequest and firstRequest.processId,
        firstRequest and firstRequest.processRevision, 'spoken', {})
    check('private_request_missing_location',S.nearestAsking('home','carrier') == nil)
    mind('carrier').places.hungry = {minX=8,minY=9,maxX=12,maxY=13}
    local group, destination = S.nearestAsking('home','carrier')
    check('private_place_destination_retained',group == 'hungry' and destination
        and destination.minX == 8 and destination.minY == 9
        and destination.maxX == 12 and destination.maxY == 13)
    if destination then destination.minX = -999 end
    local againGroup, againDestination = S.nearestAsking('home','carrier')
    check('private_destination_detached',againGroup == 'hungry' and againDestination
        and againDestination.minX == 8 and P.beliefs.carrier.places.hungry.minX == 8)
    standing.groupClaims.hungry = {minX=800,minY=800,maxX=804,maxY=804}
    local privateGroup, privateDestination = S.nearestAsking('home','carrier')
    check('private_request_beats_global_location',privateGroup == 'hungry'
        and privateDestination and privateDestination.minX == 8)
    __now = 195
    local carrierRequest = request('carrier')
    P.recordAidRequest('relay','hungry',100,'told','carrier','food',
        carrierRequest and carrierRequest.processId,
        carrierRequest and carrierRequest.processRevision, 'spoken', {})
    local retold = request('relay')
    __now = 197
    check('request_expiry_uses_original_time',retold and retold.acquiredAt == 195
        and retold.requestedAt == 100 and #P.knownAidRequests('relay') == 0)
    check('request_future_refused',not P.recordAidRequest('outsider','hungry',198,'requested')
        and request('outsider') == nil)

    reset()
    S.callForBread('hungry','requester')
    __loadedResult = false
    P.tell('requester','carrier',900000,true)
    check('request_testimony_requires_conversation',request('carrier') == nil)
    __loadedResult = true
    P.tell('requester','carrier',900000,true)
    local toldRequest = request('carrier')
    check('request_testimony_from_real_origin',toldRequest
        and toldRequest.source == 'told' and toldRequest.teller == 'requester'
        and toldRequest.originId == 'requester' and toldRequest.requestedAt == 100)

    reset()
    check('loaded_native_actor_listener',C.canConverse('actor','witness')
        and #__nativeCalls == 1 and __nativeCalls[1].actor == __bodies.actor
        and __nativeCalls[1].listener == __bodies.witness
        and __nativeCalls[1].range > 0)
    __loadedResult = false
    check('loaded_listener_deaf_port_refusal',not C.canConverse('actor','witness'))
    __loadedResult, __loadedThrows = true, true
    check('loaded_native_failure_refused',not C.canConverse('actor','witness'))
    __loadedThrows = false
    SAO.Controller.agents.witness = {sleeping=true}
    local before = #__nativeCalls
    check('loaded_sleeping_agent_refused',not C.canConverse('actor','witness')
        and #__nativeCalls == before)
    SAO.Controller.agents.witness = nil
    __bodies.witness = nil
    check('loaded_missing_body_refused',not C.canConverse('actor','witness'))
    __player = {getUsername=function() return 'operator' end}
    local playerHeard = C.canConverse('actor','player:operator')
    check('loaded_player_identity',playerHeard and __nativeCalls[#__nativeCalls].listener == __player
        and not C.canConverse('actor','player:someone-else'))
    check('unknown_channel_refused',not C.canConverse('actor','player:operator','radio-unproven'))
    check('same_actor_refused',not C.canConverse('actor','actor'))

    reset()
    __bodies = {}
    local dormant = C.canConverse('actor','witness','dormant-encounter')
    check('dormant_native_listener_access',dormant
        and __hearingCalls[#__hearingCalls] == __records.witness.hibernation)
    __hearing[__records.actor.hibernation] = 'REFUSED:deaf'
    check('dormant_access_is_directed',C.canConverse('actor','witness','dormant-encounter')
        and not C.canConverse('witness','actor','dormant-encounter'))
    __hearing[__records.witness.hibernation] = 'UNKNOWN:legacy-v1'
    check('dormant_unknown_hearing_refused',not C.canConverse('actor','witness','dormant-encounter'))
    __hearing[__records.witness.hibernation] = 'AVAILABLE:1.0'
    __hearingThrows = true
    check('dormant_hearing_failure_refused',not C.canConverse('actor','witness','dormant-encounter'))
    __hearingThrows = false
    __records.witness.dead = true
    check('dormant_dead_refused',not C.canConverse('actor','witness','dormant-encounter'))
    __records.witness.dead = nil
    __records.witness.dormantSleeping = true
    check('dormant_sleeping_refused',not C.canConverse('actor','witness','dormant-encounter'))
    __records.witness.dormantSleeping = nil
    check('dormant_missing_sleep_refused',not C.canConverse('actor','witness','dormant-encounter'))
    __records.witness.dormantSleeping = false
    __represented.witness = true
    check('dormant_loaded_participant_refused',not C.canConverse('actor','witness','dormant-encounter'))
    __represented.witness = nil
    __records.witness.z = 1
    local floorRefused = not C.canConverse('actor','witness','dormant-encounter')
    __records.witness.z, __records.witness.x = 0, 14
    check('dormant_floor_and_distance_refused',floorRefused
        and not C.canConverse('actor','witness','dormant-encounter'))

    reset()
    __bodies = {}
    __records.actor.hibernation, __records.witness.hibernation = nil, nil
    __records.actor.speechAccessOrigin = 'generated-empty-traits'
    __records.witness.speechAccessOrigin = 'generated-empty-traits'
    local generated = C.canConverse('actor','witness','dormant-encounter')
    __records.witness.speechAccessOrigin = nil
    check('dormant_generated_hearing_provenance',generated
        and not C.canConverse('actor','witness','dormant-encounter'))
    __records.witness.speechAccessOrigin = 'generated-empty-traits'
    __records.witness.hibernation = 'native-witness'
    __hearing['native-witness'] = 'REFUSED:deaf'
    check('dormant_generated_cannot_override_deaf',not C.canConverse('actor','witness','dormant-encounter'))
    __hearing['native-witness'] = 'AVAILABLE:0.01'
    __records.witness.x = 12
    check('dormant_hearing_reduces_reach',not C.canConverse('actor','witness','dormant-encounter'))
    __hearing['native-witness'], __weather = 'AVAILABLE:1.0', 0.01
    check('dormant_weather_reduces_reach',not C.canConverse('actor','witness','dormant-encounter'))
    __records.witness.x, __weather = 10, 1
    __hearing['native-witness'] = 'AVAILABLE:0'
    check('dormant_zero_hearing_refused',not C.canConverse('actor','witness','dormant-encounter'))
    __hearing['native-witness'], __weather = 'AVAILABLE:1.0', 0
    check('dormant_zero_weather_refused',not C.canConverse('actor','witness','dormant-encounter'))
    __weather, __weatherThrows = 1, true
    check('dormant_unknown_weather_refused',not C.canConverse('actor','witness','dormant-encounter'))

    reset()
    local delivered, why = V.processReceipt(receipt())
    local ack = __ackCalls[1]
    check('receipt_memory_before_ack',delivered and ack
        and ack.consumer == 'provisioning' and ack.actor and ack.witness
        and ack.actor.source == 'performed' and ack.witness.source == 'observed')
    check('material_disabled_keeps_private_memory',delivered and why == 'material-disabled'
        and fact('actor') ~= nil and fact('witness') ~= nil)
    check('receipt_captured_witnesses_only',fact('outsider') == nil
        and fact('requester') == nil and P.beliefs.outsider == nil)
    local seen = fact('witness')
    check('receipt_original_location_retained',seen and seen.x == 10 and seen.y == 12
        and seen.eventAt == 100)

    reset()
    __unavailable.SurvivorAwareness_Beliefs = true
    local blocked, blockedWhy = V.processReceipt(receipt())
    check('unavailable_mind_blocks_ack',not blocked and blockedWhy == 'perception-unavailable'
        and #__ackCalls == 0 and fact('witness') == nil)
    __unavailable.SurvivorAwareness_Beliefs = nil
    __now = 105
    local replay = receipt(); replay.at = 100
    local recovered = V.processReceipt(replay)
    local memory = fact('witness')
    check('mind_retry_records_original_time',recovered and memory
        and memory.acquiredAt == 100 and memory.eventAt == 100)

    reset()
    local refused = receipt(); refused.transferObservation.actorId = 'someone-else'
    check('rejected_memory_blocks_ack',not V.processReceipt(refused)
        and #__ackCalls == 0 and fact('witness') == nil)

    reset()
    __ackAllowed = false
    local held, heldWhy = V.processReceipt(receipt())
    local prior = fact('witness')
    local version = P.beliefVersion
    __now, __ackAllowed = 105, true
    local retryReceipt = receipt(); retryReceipt.at = 100
    local acknowledged = V.processReceipt(retryReceipt)
    local final = fact('witness')
    check('ack_retry_preserves_private_acquisition',not held and heldWhy == 'ack-refused'
        and acknowledged and prior and final and final.acquiredAt == prior.acquiredAt
        and P.beliefVersion == version and #__ackCalls == 2)

    reset()
    local legacy = receipt(); legacy.transferObservation = nil
    local accepted = V.processReceipt(legacy)
    check('legacy_receipt_does_not_invent_memory',accepted and #__ackCalls == 1
        and fact('actor') == nil and fact('witness') == nil)

    reset()
    __graphAvailable = false
    local waiting = V.processReceipt(receipt())
    local acquired = fact('witness')
    __now, __graphAvailable = 105, true
    local retryGraph = receipt(); retryGraph.at = 100
    check('graph_retry_preserves_memory',not waiting and acquired and #__ackCalls == 0
        and V.processReceipt(retryGraph) and fact('witness').acquiredAt == acquired.acquiredAt)

    reset()
    __graphAvailable = false
    local terminalDelivered = true
    for _, status in ipairs({'conflict','released','interrupted'}) do
        local observed = receipt(status)
        observed.status, observed.materialProjectionEnabled = status, true
        local acceptedObservation, observedWhy = V.processReceipt(observed)
        terminalDelivered = terminalDelivered and acceptedObservation
            and observedWhy == 'native-observation-delivered'
            and fact('witness',status) ~= nil and observed.status == status
    end
    check('terminal_observation_bypasses_projection',terminalDelivered and #__ackCalls == 3
        and __ackCalls[3].reason == 'native-observation-delivered')

    reset()
    local invalid = receipt(); invalid.status = 'pending'
    local pendingRefused = not V.processReceipt(invalid)
    invalid.status = 'conflict'; invalid.transferObservation.nativeTransferProven = nil
    local unprovedRefused = not V.processReceipt(invalid)
    invalid.transferObservation = nil
    check('terminal_without_proof_cannot_ack',pendingRefused and unprovedRefused
        and not V.processReceipt(invalid) and #__ackCalls == 0 and fact('witness') == nil)

    reset()
    __unavailable.SurvivorAwareness_Beliefs = true
    local conflict = receipt(); conflict.status = 'conflict'
    local mindBlocked = not V.processReceipt(conflict) and #__ackCalls == 0
    __unavailable.SurvivorAwareness_Beliefs, __ackAllowed = nil, false
    local ackBlocked = not V.processReceipt(conflict)
    local original = fact('witness')
    local beforeRetry = P.beliefVersion
    __now, __ackAllowed = 105, true
    local retried = V.processReceipt(conflict)
    check('terminal_memory_retry_idempotent',mindBlocked and ackBlocked and original
        and retried and fact('witness').eventAt == 100
        and fact('witness').acquiredAt == original.acquiredAt
        and P.beliefVersion == beforeRetry and #__ackCalls == 2)
    return table.concat(results,'|')
end)()
