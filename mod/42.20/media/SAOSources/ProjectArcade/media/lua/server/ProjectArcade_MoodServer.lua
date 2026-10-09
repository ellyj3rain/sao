print("[ProjectArcade] ProjectArcade_MoodServer LOADED")

local function applyMoodChanges_B42Safe(character, boredomDecrease, unhappinessDecrease, stressDecrease)
    if not character then return end

    local stats = character:getStats()

    if CharacterStat and stats and stats.get and stats.set then
        local curBoredom = stats:get(CharacterStat.BOREDOM)
        local curUnhappy = stats:get(CharacterStat.UNHAPPINESS)
        local curStress  = stats:get(CharacterStat.STRESS)

        if type(curBoredom) == "number" then
            stats:set(CharacterStat.BOREDOM, math.max(0, curBoredom - boredomDecrease))
        end
        if type(curUnhappy) == "number" then
            stats:set(CharacterStat.UNHAPPINESS, math.max(0, curUnhappy - unhappinessDecrease))
        end
        if type(curStress) == "number" then
            stats:set(CharacterStat.STRESS, math.max(0, curStress - stressDecrease))
        end
        return
    end

    local bd = character:getBodyDamage()
    if bd then
        if bd.getBoredomLevel and bd.setBoredomLevel then
            bd:setBoredomLevel(math.max(0, bd:getBoredomLevel() - boredomDecrease))
        end
        if bd.getUnhappinessLevel and bd.setUnhappinessLevel then
            bd:setUnhappinessLevel(math.max(0, bd:getUnhappinessLevel() - unhappinessDecrease))
        elseif bd.getUnhappynessLevel and bd.setUnhappynessLevel then
            bd:setUnhappynessLevel(math.max(0, bd:getUnhappynessLevel() - unhappinessDecrease))
        end
    end

    if stats and stats.getStress and stats.setStress then
        stats:setStress(math.max(0, stats:getStress() - stressDecrease))
    end
end

local function applyMoodDeltaSigned_B42(character, boredomDelta, unhappinessDelta, stressDelta)
    if not character then return end
    local stats = character:getStats()

    if CharacterStat and stats and stats.get and stats.set then
        local b = stats:get(CharacterStat.BOREDOM)
        local u = stats:get(CharacterStat.UNHAPPINESS)
        local s = stats:get(CharacterStat.STRESS)

        if type(b) == "number" then
            stats:set(CharacterStat.BOREDOM, math.min(100, math.max(0, b + boredomDelta)))
        end
        if type(u) == "number" then
            stats:set(CharacterStat.UNHAPPINESS, math.min(100, math.max(0, u + unhappinessDelta)))
        end
        if type(s) == "number" then
            stats:set(CharacterStat.STRESS, math.min(1, math.max(0, s + stressDelta)))
        end
        return
    end

end

local function clampSigned(v, minV, maxV)
    v = tonumber(v) or 0
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end


local function clampNumber(v, minV, maxV)
    v = tonumber(v) or 0
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function onClientCommand(module, command, player, args)
    if module ~= "ProjectArcade" then return end
    if not player or not args then return end

    if command == "ApplyMoodDelta" then
        local boredom = clampNumber(args.boredom, 0, 5)
        local unhappy = clampNumber(args.unhappiness, 0, 5)
        local stress  = clampNumber(args.stress, 0, 0.10)

        if boredom <= 0 and unhappy <= 0 and stress <= 0 then return end
        applyMoodChanges_B42Safe(player, boredom, unhappy, stress)
        return
    end

    if command == "ApplyMoodDeltaSigned" then
        local boredom = clampSigned(args.boredom, -50, 50)
        local unhappy = clampSigned(args.unhappiness, -50, 50)
        local stress  = clampSigned(args.stress, -0.5, 0.5)

        if boredom == 0 and unhappy == 0 and stress == 0 then return end
        applyMoodDeltaSigned_B42(player, boredom, unhappy, stress)
        return
    end
end


Events.OnClientCommand.Add(onClientCommand)
