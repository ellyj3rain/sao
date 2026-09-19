-- Read-only instrumentation around the shipped county's real verbs.
-- Captures failed protected calls as well as outcomes; changes no verdicts.
SAOSweepEvidence = {}

local function escape(value)
    local out = tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"')
    return out:gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
end

local function json(value)
    local kind = type(value)
    if kind == 'nil' then return 'null' end
    if kind == 'boolean' or kind == 'number' then return tostring(value) end
    if kind == 'string' then return '"' .. escape(value) .. '"' end
    if kind ~= 'table' then return 'null' end
    local fields = {}
    -- Maps are explicit, including numeric day/size keys. Empty maps stay maps.
    for key, item in pairs(value) do
        fields[#fields + 1] = '"' .. escape(key) .. '":' .. json(item)
    end
    return '{' .. table.concat(fields, ',') .. '}'
end

function SAOSweepEvidence.begin()
    local state = ModData.getOrCreate('SurvivorAwareness_Standing')
    local report = { snapshots = {}, companies = {}, events = {}, faults = {},
        faultCount = 0, callbackCounts = {}, deathCauses = {},
        housesFounded = 0, survivorsJoined = 0, survivorsLeft = 0 }
    local eventCount, lastDay = 0, -1
    local priorRoster, priorGroups, mutationDepth = {}, {}, 0
    local function hour() return SAO.History.countyHours() end
    local function event(kind, id, group, extra)
        eventCount = eventCount + 1
        report.events[tostring(eventCount)] = {
            kind = kind, id = id, group = group, hour = hour(), detail = extra }
    end
    local function pack(...) return { count = select('#', ...), ... } end
    local realPcall = pcall
    pcall = function(fn, ...)
        local result = pack(realPcall(fn, ...))
        if not result[1] then
            report.faultCount = report.faultCount + 1
            local message = tostring(result[2]) .. ' | ' .. tostring(result[3] or '')
            report.faults[message] = (report.faults[message] or 0) + 1
        end
        return unpack(result, 1, result.count)
    end
    local function reconcile(initial)
        local roster, groups = {}, {}
        for id, group in pairs(state.groups or {}) do
            local record = SAO.Identity.get(id)
            if record and not record.dead then
                roster[id] = group
                groups[group] = (groups[group] or 0) + 1
            end
        end
        for group, count in pairs(groups) do
            if count > 1 then
                local tracked = report.companies[group]
                if not tracked then
                    tracked = { maxSize = 0, periods = {}, periodCount = 0 }
                    report.companies[group] = tracked
                end
                if (priorGroups[group] or 0) < 2 then
                    tracked.periodCount = tracked.periodCount + 1
                    local period = { maxSize = count }
                    if initial then
                        period.firstObservedHour = hour()
                    else
                        period.foundedHour = hour()
                        tracked.foundedHour = tracked.foundedHour or hour()
                        report.housesFounded = report.housesFounded + 1
                        event('founded', nil, group, count)
                    end
                    tracked.periods[tostring(tracked.periodCount)] = period
                end
                local period = tracked.periods[tostring(tracked.periodCount)]
                period.maxSize = math.max(period.maxSize, count)
                tracked.maxSize = math.max(tracked.maxSize, count)
                tracked.lastObservedHour, tracked.lastSize = hour(), count
                tracked.endedHour = nil
            end
        end
        if not initial then
            for id, old in pairs(priorRoster) do
                if roster[id] ~= old then
                    event('left', id, old)
                    report.survivorsLeft = report.survivorsLeft + 1
                end
            end
            for id, group in pairs(roster) do
                if priorRoster[id] ~= group then
                    if (priorGroups[group] or 0) >= 2 then
                        event('joined', id, group)
                        report.survivorsJoined = report.survivorsJoined + 1
                    else
                        event('founder', id, group)
                    end
                end
            end
            for group, count in pairs(priorGroups) do
                if count > 1 and (groups[group] or 0) < 2 then
                    local tracked = report.companies[group]
                    tracked.endedHour, tracked.lastSize = hour(), groups[group] or 0
                    tracked.periods[tostring(tracked.periodCount)].endedHour = hour()
                    event('ended', nil, group)
                end
            end
        end
        priorRoster, priorGroups = roster, groups
    end
    reconcile(true)
    local function wrap(owner, name, after, rosterMutation)
        local original = owner and owner[name]
        if type(original) ~= 'function' then error('evidence callback absent: ' .. name) end
        owner[name] = function(...)
            report.callbackCounts[name] = (report.callbackCounts[name] or 0) + 1
            if rosterMutation then mutationDepth = mutationDepth + 1 end
            local args = pack(...)
            local result = pack(original(...))
            after(args, result)
            if rosterMutation then
                mutationDepth = mutationDepth - 1
                if mutationDepth == 0 then reconcile(false) end
            end
            return unpack(result, 1, result.count)
        end
    end
    for _, name in ipairs({ 'formCompany', 'joinGroup', 'leaveGroup',
            'releaseDead', 'electLeader', 'checkSchism', 'migrateKey' }) do
        wrap(SAO.Standing, name, function() end, true)
    end
    wrap(SAO.Identity, 'markDead', function(args, result)
        local record = args[1]
        if record and record.dead and result[1] then
            event('death', record.id, record.diedInGroup, record.deathCause)
        end
    end, true)
    if ZAO and ZAO.Pathogen then
        wrap(ZAO.Pathogen, 'begin', function() end)
        wrap(ZAO.Pathogen, 'advance', function() end)
        wrap(SAO.PathogenEvents, 'simulateDay', function() end)
    end
    local function observe(force)
        local day = tonumber(state.yearsRun) or 0
        if not force and day == lastDay then return end
        lastDay = day
        reconcile(false)
        local alive, dead, groups, causes, sizeCounts = 0, 0, {}, {}, {}
        for _, record in pairs(SAO.Identity.all()) do
            if record.dead then
                dead = dead + 1
                local cause = tostring(record.deathCause or 'unrecorded')
                causes[cause] = (causes[cause] or 0) + 1
            else alive = alive + 1 end
        end
        for id, group in pairs(state.groups or {}) do
            local record = SAO.Identity.get(id)
            if record and not record.dead then groups[group] = (groups[group] or 0) + 1 end
        end
        for group, size in pairs(groups) do
            sizeCounts[tostring(size)] = (sizeCounts[tostring(size)] or 0) + 1
        end
        local pathogens = {}
        if ZAO and ZAO.StateStore then
            for _, person in pairs(ZAO.StateStore.store().people or {}) do
                local terminal = tostring(person.terminalState or 'unrecorded')
                pathogens[terminal] = (pathogens[terminal] or 0) + 1
            end
        end
        report.snapshots[tostring(day)] = { completedDay = day, observedHour = hour(),
            alive = alive, dead = dead, groupSizes = sizeCounts, groups = groups,
            deathCauses = causes, pathogenStates = pathogens }
        report.deathCauses = causes
    end
    return {
        observe = observe,
        finish = function()
            observe(true)
            report.seed, report.drawCount = SAO.Rand.state()
            report.sandbox = SandboxVars
            report.pathogenPolicy = ZAO and ZAO.Sandbox and ZAO.Sandbox.policy() or nil
            pcall = realPcall
            return json(report)
        end,
    }
end
