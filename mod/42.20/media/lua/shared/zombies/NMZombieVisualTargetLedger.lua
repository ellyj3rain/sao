-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
NMZombieVisualTargetLedger = NMZombieVisualTargetLedger or {}
require "zombies/NMZombieAudioVisualSupport"
require "zombies/NMZombieDeviceVariantCatalog"
require "zombies/NMZombieSandboxRarity"
NMZombieVisualTargetLedger._recordsByZombieId = NMZombieVisualTargetLedger._recordsByZombieId or {}
NMZombieVisualTargetLedger._selectionEpoch = NMZombieVisualTargetLedger._selectionEpoch or 0
NMZombieVisualTargetLedger._diag = NMZombieVisualTargetLedger._diag or {
    assigned = 0,
    reusedMemory = 0,
    reusedStamp = 0,
    zombieStamped = 0,
    corpseStamped = 0
}

local function shouldLog()
    return NMCore and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("zombie_visual") == true
end

local function logSummary(tag, detail)
    if not shouldLog() then
        return
    end
    print("[NewMusic] [ZombieProof] " .. tostring(tag or "") .. " " .. tostring(detail or ""))
end

local function getProofModData(holder)
    return NMZombieAudioVisualSupport and NMZombieAudioVisualSupport.getProofModData and NMZombieAudioVisualSupport.getProofModData(holder) or nil
end

local function getSelectionSource()
    return tostring(NMZombieVisualTargetContract and NMZombieVisualTargetContract.SelectionSource or "server_ledger")
end

local function copyVisualSelectionRecord(record)
    if type(record) ~= "table" then
        return nil
    end
    local variantId = tostring(record.variantId or (((record.musicSelected == true or record.selected == true) and "walkman") or "none"))
    local musicSelected = record.musicSelected == true or variantId ~= "none"
    return {
        zombieId = tostring(record.zombieId or ""),
        musicSelected = musicSelected,
        selected = record.selected == true or musicSelected,
        variantId = variantId,
        strategy = tostring(record.strategy or ""),
        selectionEpoch = tonumber(record.selectionEpoch) or 0,
        selectionSource = tostring(record.selectionSource or getSelectionSource())
    }
end

local function readStampedVisualSelectionRecord(holder, fallbackZombieId)
    local md = getProofModData(holder)
    if type(md) ~= "table" then
        return nil
    end
    if tostring(md.selectionSource or "") ~= getSelectionSource() then
        return nil
    end
    local zombieId = tostring(md.selectionZombieId or fallbackZombieId or "")
    if zombieId == "" then
        return nil
    end
    local variantId = tostring(md.variantId or (((md.musicSelected == true or md.selected == true) and "walkman") or "none"))
    local musicSelected = md.musicSelected == true or variantId ~= "none"
    return {
        zombieId = zombieId,
        musicSelected = musicSelected,
        selected = md.selected == true or musicSelected,
        variantId = variantId,
        strategy = tostring(md.strategy or md.liveVisualStrategy or ""),
        selectionEpoch = tonumber(md.selectionEpoch) or 0,
        selectionSource = tostring(md.selectionSource or getSelectionSource())
    }
end

local function writeVisualSelectionStamp(holder, record, extraFields)
    local md = getProofModData(holder)
    if type(md) ~= "table" then
        return false
    end
    local variantId = tostring(record and record.variantId or (((record and (record.musicSelected == true or record.selected == true)) and "walkman") or "none"))
    md.musicSelected = record and (record.musicSelected == true or variantId ~= "none") or false
    md.selected = record and (record.selected == true or md.musicSelected == true) or false
    md.variantId = variantId
    md.selectionSource = tostring(record and record.selectionSource or getSelectionSource())
    md.selectionEpoch = tonumber(record and record.selectionEpoch) or 0
    md.selectionZombieId = tostring(record and record.zombieId or "")
    if tostring(record and record.strategy or "") ~= "" then
        md.strategy = tostring(record.strategy)
    end
    if type(extraFields) == "table" then
        for key, value in pairs(extraFields) do
            md[key] = value
        end
    end
    if holder and holder.transmitModData then
        pcall(holder.transmitModData, holder)
    end
    return true
end

local function nextSelectionEpoch()
    NMZombieVisualTargetLedger._selectionEpoch = (tonumber(NMZombieVisualTargetLedger._selectionEpoch) or 0) + 1
    return NMZombieVisualTargetLedger._selectionEpoch
end

local function buildAssignedVisualSelectionRecord(zombieId, strategy)
    local musicalRate = NMRuntimeConfig and NMRuntimeConfig.getMusicalZombiesSpawnRate and NMRuntimeConfig.getMusicalZombiesSpawnRate() or 0.6
    local outcome = NMZombieSandboxRarity and NMZombieSandboxRarity.resolveMusicZombieOutcome and NMZombieSandboxRarity.resolveMusicZombieOutcome(zombieId, musicalRate) or nil
    return {
        zombieId = zombieId,
        musicSelected = outcome and outcome.musicSelected == true or false,
        selected = outcome and outcome.selected == true or false,
        variantId = tostring(outcome and outcome.variantId or "none"),
        strategy = tostring(strategy or ""),
        selectionEpoch = nextSelectionEpoch(),
        selectionSource = getSelectionSource()
    }
end

local function rememberVisualSelectionRecord(record)
    local copied = copyVisualSelectionRecord(record)
    if not copied then
        return nil
    end
    NMZombieVisualTargetLedger._recordsByZombieId[copied.zombieId] = copied
    return copyVisualSelectionRecord(copied)
end

function NMZombieVisualTargetLedger.getZombieSelectionById(zombieId)
    local key = tostring(zombieId or "")
    if key == "" then
        return nil
    end
    return copyVisualSelectionRecord(NMZombieVisualTargetLedger._recordsByZombieId[key])
end

function NMZombieVisualTargetLedger.stampZombieSelection(zombie, record)
    if not (zombie and record) then
        return false
    end
    local stamped = writeVisualSelectionStamp(zombie, record)
    if stamped then
        NMZombieVisualTargetLedger._diag.zombieStamped = (NMZombieVisualTargetLedger._diag.zombieStamped or 0) + 1
    end
    return stamped
end

function NMZombieVisualTargetLedger.stampCorpseSelection(body, record, corpseHadProof)
    if not (body and record) then
        return false
    end
    local stamped = writeVisualSelectionStamp(body, record, {
        corpseHadProof = corpseHadProof == true,
        corpseSettled = true
    })
    if stamped then
        NMZombieVisualTargetLedger._diag.corpseStamped = (NMZombieVisualTargetLedger._diag.corpseStamped or 0) + 1
    end
    return stamped
end

function NMZombieVisualTargetLedger.getOrAssignZombieSelection(zombie, strategy)
    local zombieId = NMZombieVisualTargetContract and NMZombieVisualTargetContract.getZombieId and NMZombieVisualTargetContract.getZombieId(zombie) or tostring(zombie or "")
    if zombieId == "" then
        return nil
    end
    local existing = NMZombieVisualTargetLedger._recordsByZombieId[zombieId]
    if existing then
        NMZombieVisualTargetLedger._diag.reusedMemory = (NMZombieVisualTargetLedger._diag.reusedMemory or 0) + 1
        NMZombieVisualTargetLedger.stampZombieSelection(zombie, existing)
        return copyVisualSelectionRecord(existing)
    end
    local stamped = readStampedVisualSelectionRecord(zombie, zombieId)
    if stamped then
        if stamped.strategy == "" then
            stamped.strategy = tostring(strategy or "")
        end
        if stamped.selectionEpoch <= 0 then
            stamped.selectionEpoch = nextSelectionEpoch()
        end
        local remembered = rememberVisualSelectionRecord(stamped)
        NMZombieVisualTargetLedger._diag.reusedStamp = (NMZombieVisualTargetLedger._diag.reusedStamp or 0) + 1
        NMZombieVisualTargetLedger.stampZombieSelection(zombie, stamped)
        return remembered
    end
    local record = buildAssignedVisualSelectionRecord(zombieId, strategy)
    local remembered = rememberVisualSelectionRecord(record)
    NMZombieVisualTargetLedger._diag.assigned = (NMZombieVisualTargetLedger._diag.assigned or 0) + 1
    NMZombieVisualTargetLedger.stampZombieSelection(zombie, record)
    return remembered
end

function NMZombieVisualTargetLedger.getStampedSelection(holder, fallbackZombieId)
    return copyVisualSelectionRecord(readStampedVisualSelectionRecord(holder, fallbackZombieId))
end

function NMZombieVisualTargetLedger.logDiag(tag)
    logSummary(
        tag or "target_ledger",
        string.format(
            "assigned=%s reusedMemory=%s reusedStamp=%s zombieStamped=%s corpseStamped=%s",
            tostring(NMZombieVisualTargetLedger._diag.assigned or 0),
            tostring(NMZombieVisualTargetLedger._diag.reusedMemory or 0),
            tostring(NMZombieVisualTargetLedger._diag.reusedStamp or 0),
            tostring(NMZombieVisualTargetLedger._diag.zombieStamped or 0),
            tostring(NMZombieVisualTargetLedger._diag.corpseStamped or 0)
        )
    )
end

return NMZombieVisualTargetLedger
