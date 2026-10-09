NMZombieDeviceVariantCatalog = NMZombieDeviceVariantCatalog or {}

local VARIANT_ORDER = {
    "walkman",
    "cd_player",
    "boombox"
}

local VARIANT_CONFIGS = {
    walkman = {
        variantId = "walkman",
        deviceType = "walkman",
        stopReason = "zombie_walkman_proof",
        ensureItem = "Base.Belt2",
        itemPool = {
            "NewMusic.WalkmanBlue",
            "NewMusic.WalkmanPurple",
            "NewMusic.WalkmanRed",
            "NewMusic.WalkmanBlack",
            "NewMusic.WalkmanPink",
            "NewMusic.WalkmanGreen",
            "NewMusic.WalkmanCamo",
            "NewMusic.WalkmanOrange",
            "NewMusic.WalkmanYellow",
            "NewMusic.WalkmanCyan",
            "NewMusic.WalkmanMagenta",
            "NewMusic.WalkmanWhite",
            "NewMusic.WalkmanLore"
        },
        itemWeights = {
            ["NewMusic.WalkmanLore"] = 0.25
        },
        attachmentPool = {
            {
                attachmentLocation = "Walkie Belt Left",
                modelAttachmentName = "walkie_belt_left"
            },
            {
                attachmentLocation = "Walkie Belt Right",
                modelAttachmentName = "walkie_belt_right"
            }
        }
    },
    cd_player = {
        variantId = "cd_player",
        deviceType = "cdplayer",
        stopReason = "zombie_cd_player_proof",
        ensureItem = "Base.Belt2",
        itemPool = {
            "NewMusic.CDPlayerBlue",
            "NewMusic.CDPlayerBlack",
            "NewMusic.CDPlayerCow",
            "NewMusic.CDPlayerGreen",
            "NewMusic.CDPlayerOrange",
            "NewMusic.CDPlayerPurple",
            "NewMusic.CDPlayerRed",
            "NewMusic.CDPlayerWhite",
            "NewMusic.CDPlayerYellow",
            "NewMusic.CDPlayerMagenta",
            "NewMusic.CDPlayerPink",
            "NewMusic.CDPlayerCyan"
        },
        attachmentPool = {
            {
                attachmentLocation = "Walkie Belt Left",
                modelAttachmentName = "walkie_belt_left"
            },
            {
                attachmentLocation = "Walkie Belt Right",
                modelAttachmentName = "walkie_belt_right"
            }
        }
    },
    boombox = {
        variantId = "boombox",
        deviceType = "boombox",
        stopReason = "zombie_boombox_proof",
        ensureItem = nil,
        itemPool = {
            "NewMusic.BoomboxGrey",
            "NewMusic.BoomboxBlue",
            "NewMusic.BoomboxCamo",
            "NewMusic.BoomboxBlack",
            "NewMusic.BoomboxGreen",
            "NewMusic.BoomboxPink",
            "NewMusic.BoomboxRed",
            "NewMusic.BoomboxWhite",
            "NewMusic.BoomboxOrange",
            "NewMusic.BoomboxYellow",
            "NewMusic.BoomboxCyan",
            "NewMusic.BoomboxMagenta",
            "NewMusic.BoomboxPurple"
        },
        attachmentPool = {
            {
                attachmentLocation = "Big Weapon On Back",
                modelAttachmentName = "big_w_back"
            }
        }
    }
}

local function copyAttachment(attachment)
    if type(attachment) ~= "table" then
        return nil
    end
    return {
        attachmentLocation = tostring(attachment.attachmentLocation or ""),
        modelAttachmentName = tostring(attachment.modelAttachmentName or "")
    }
end

local function copyPool(pool)
    local out = {}
    if type(pool) ~= "table" then
        return out
    end
    for i = 1, #pool do
        out[#out + 1] = tostring(pool[i] or "")
    end
    return out
end

local function buildSpec(config, fullType, attachment)
    if type(config) ~= "table" or type(attachment) ~= "table" then
        return nil
    end
    return {
        variantId = tostring(config.variantId or ""),
        deviceType = tostring(config.deviceType or ""),
        fullType = tostring(fullType or ""),
        attachmentLocation = tostring(attachment.attachmentLocation or ""),
        modelAttachmentName = tostring(attachment.modelAttachmentName or ""),
        stopReason = tostring(config.stopReason or ""),
        ensureItem = config.ensureItem ~= nil and tostring(config.ensureItem) or nil
    }
end

local function copyConfig(config)
    if type(config) ~= "table" then
        return nil
    end
    local out = {
        variantId = tostring(config.variantId or ""),
        deviceType = tostring(config.deviceType or ""),
        stopReason = tostring(config.stopReason or ""),
        ensureItem = config.ensureItem ~= nil and tostring(config.ensureItem) or nil,
        itemPool = copyPool(config.itemPool),
        itemWeights = {},
        attachmentPool = {}
    }
    for fullType, weight in pairs(config.itemWeights or {}) do
        out.itemWeights[tostring(fullType or "")] = tonumber(weight) or 1.0
    end
    for i = 1, #(config.attachmentPool or {}) do
        out.attachmentPool[#out.attachmentPool + 1] = copyAttachment(config.attachmentPool[i])
    end
    return out
end

local function getItemWeight(config, fullType)
    local weight = tonumber(config and config.itemWeights and config.itemWeights[tostring(fullType or "")]) or 1.0
    if weight <= 0 then
        return 0
    end
    return weight
end

local function mixHash(text, salt)
    local source = tostring(text or "") .. "|" .. tostring(salt or "")
    local total = 0
    for i = 1, #source do
        total = (total * 131 + string.byte(source, i) + i) % 2147483647
    end
    return total
end

local function deterministicIndex(text, salt, count)
    local size = tonumber(count) or 0
    if size <= 1 then
        return 1
    end
    return (mixHash(text, salt) % size) + 1
end

local function deterministicWeightedIndex(text, salt, pool, config)
    local size = #(pool or {})
    if size <= 1 then
        return 1
    end

    local totalWeight = 0
    for i = 1, size do
        totalWeight = totalWeight + getItemWeight(config, pool[i])
    end
    if totalWeight <= 0 then
        return deterministicIndex(text, salt, size)
    end

    local hash = mixHash(text, salt) % 1000000
    local roll = (hash / 1000000) * totalWeight
    local running = 0
    for i = 1, size do
        running = running + getItemWeight(config, pool[i])
        if roll < running or i == size then
            return i
        end
    end

    return size
end

local function resolveVariantId(selectionOrVariantId)
    if type(selectionOrVariantId) == "table" then
        return tostring(selectionOrVariantId.variantId or "")
    end
    return tostring(selectionOrVariantId or "")
end

local function getConfig(variantId)
    return VARIANT_CONFIGS[resolveVariantId(variantId)]
end

local function resolveBaseSpec(variantId)
    local config = getConfig(variantId)
    if not config then
        return nil
    end
    return buildSpec(config, config.itemPool[1], config.attachmentPool[1])
end

function NMZombieDeviceVariantCatalog.getDefaultSpec()
    return resolveBaseSpec("walkman")
end

function NMZombieDeviceVariantCatalog.getVariantConfig(variantId)
    return copyConfig(getConfig(variantId))
end

function NMZombieDeviceVariantCatalog.getSpec(variantId)
    return resolveBaseSpec(variantId)
end

function NMZombieDeviceVariantCatalog.getSpecs()
    local out = {}
    for i = 1, #VARIANT_ORDER do
        local spec = resolveBaseSpec(VARIANT_ORDER[i])
        if spec then
            out[#out + 1] = spec
        end
    end
    return out
end

function NMZombieDeviceVariantCatalog.getAllRealizationSpecs()
    local out = {}
    for i = 1, #VARIANT_ORDER do
        local config = getConfig(VARIANT_ORDER[i])
        if config then
            for itemIndex = 1, #(config.itemPool or {}) do
                for attachmentIndex = 1, #(config.attachmentPool or {}) do
                    local spec = buildSpec(config, config.itemPool[itemIndex], config.attachmentPool[attachmentIndex])
                    if spec then
                        out[#out + 1] = spec
                    end
                end
            end
        end
    end
    return out
end

function NMZombieDeviceVariantCatalog.getVariantIds()
    local out = {}
    for i = 1, #VARIANT_ORDER do
        out[#out + 1] = VARIANT_ORDER[i]
    end
    return out
end

function NMZombieDeviceVariantCatalog.findSpecByFullType(fullType)
    local wanted = tostring(fullType or "")
    if wanted == "" then
        return nil
    end
    for i = 1, #VARIANT_ORDER do
        local config = getConfig(VARIANT_ORDER[i])
        if config then
            for itemIndex = 1, #(config.itemPool or {}) do
                if tostring(config.itemPool[itemIndex] or "") == wanted then
                    return buildSpec(config, config.itemPool[itemIndex], config.attachmentPool[1])
                end
            end
        end
    end
    return nil
end

function NMZombieDeviceVariantCatalog.resolveStoredSpec(data)
    if type(data) ~= "table" then
        return nil
    end
    local variantId = tostring(data.variantId or "")
    local config = getConfig(variantId)
    if not config then
        return nil
    end
    local fullType = tostring(data.fullType or "")
    local attachmentLocation = tostring(data.attachmentLocation or "")
    local modelAttachmentName = tostring(data.modelAttachmentName or "")
    if fullType == "" or attachmentLocation == "" then
        return nil
    end
    if modelAttachmentName == "" then
        for i = 1, #(config.attachmentPool or {}) do
            local attachment = config.attachmentPool[i]
            if tostring(attachment.attachmentLocation or "") == attachmentLocation then
                modelAttachmentName = tostring(attachment.modelAttachmentName or "")
                break
            end
        end
    end
    return buildSpec(config, fullType, {
        attachmentLocation = attachmentLocation,
        modelAttachmentName = modelAttachmentName
    })
end

function NMZombieDeviceVariantCatalog.resolveRealization(selectionOrVariantId, zombieId)
    local variantId = resolveVariantId(selectionOrVariantId)
    local config = getConfig(variantId)
    if not config then
        return nil
    end
    local key = tostring(zombieId or "")
    local itemPool = config.itemPool or {}
    local attachmentPool = config.attachmentPool or {}
    local itemIndex = deterministicWeightedIndex(key, variantId .. "_item", itemPool, config)
    local attachmentIndex = deterministicIndex(key, variantId .. "_slot", #attachmentPool)
    return buildSpec(config, itemPool[itemIndex], attachmentPool[attachmentIndex])
end

function NMZombieDeviceVariantCatalog.isMusicSelection(selection)
    if type(selection) ~= "table" then
        return false
    end
    local variantId = tostring(selection.variantId or "")
    if variantId ~= "" and variantId ~= "none" then
        return true
    end
    return selection.musicSelected == true or selection.selected == true
end

function NMZombieDeviceVariantCatalog.getDeviceSpawnRate(variantId)
    local key = resolveVariantId(variantId)
    if key == "walkman" then
        return NMRuntimeConfig and NMRuntimeConfig.getWalkmanSpawnRate and NMRuntimeConfig.getWalkmanSpawnRate() or 0
    end
    if key == "cd_player" then
        return NMRuntimeConfig and NMRuntimeConfig.getCDPlayerSpawnRate and NMRuntimeConfig.getCDPlayerSpawnRate() or 0
    end
    if key == "boombox" then
        return NMRuntimeConfig and NMRuntimeConfig.getBoomboxSpawnRate and NMRuntimeConfig.getBoomboxSpawnRate() or 0
    end
    return 0
end

function NMZombieDeviceVariantCatalog.shouldRealizeVariant(variantId)
    local config = getConfig(variantId)
    if not config then
        return false, 0
    end
    local rate = tonumber(NMZombieDeviceVariantCatalog.getDeviceSpawnRate(config.variantId)) or 0
    return rate > 0, rate
end

function NMZombieDeviceVariantCatalog.shouldRealizeSelection(selection)
    if not NMZombieDeviceVariantCatalog.isMusicSelection(selection) then
        return false, 0
    end
    return NMZombieDeviceVariantCatalog.shouldRealizeVariant(selection)
end

return NMZombieDeviceVariantCatalog
