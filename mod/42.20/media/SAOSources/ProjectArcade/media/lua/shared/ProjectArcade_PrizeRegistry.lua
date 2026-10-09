ProjectArcade_PrizeRegistry = ProjectArcade_PrizeRegistry or {}

local DEFAULT_POOL = {
	{ item = "Base.KatePic",      weight = 1 },
	{ item = "ProjectArcade.WalletILovePixels",      weight = 2 },
    { item = "ProjectArcade.KeyRing_BlueGhost",      weight = 2 },
	{ item = "ProjectArcade.PenMulticolor_DKong",      weight = 2 },
	{ item = "Base.SpiffoSuit",      weight = 10 },
	{ item = "Base.Hat_Spiffo",      weight = 10 },
	{ item = "Base.SpiffoTail",      weight = 10 },
	{ item = "Base.SpiffoBig",      weight = 20 },
	{ item = "Base.Plushabug",      weight = 25 },
	{ item = "Base.PanchoDog",      weight = 25 },
	{ item = "Base.Pillow_Happyface",      weight = 25 },
	{ item = "Base.Pillow_Star",      weight = 25 },
	{ item = "Base.BorisBadger",      weight = 50 },
	{ item = "Base.JacquesBeaver",      weight = 50 },
	{ item = "Base.FluffyfootBunny",      weight = 50 },
	{ item = "Base.FreddyFox",      weight = 50 },
	{ item = "Base.PancakeHedgehog",      weight = 50 },
	{ item = "Base.MoleyMole",      weight = 50 },
	{ item = "Base.Spiffo",      weight = 50 },
	{ item = "Base.SpiffoBig",      weight = 50 },
	{ item = "Base.FurbertSquirrel",      weight = 50 },
}

local function isDefaultPoolEnabled()
        if not SandboxVars or not SandboxVars.ProjectArcade then
        return true
    end

        return SandboxVars.ProjectArcade.DisableDefaultPrizePool ~= true
end


ProjectArcade_PrizeRegistry.MODDATA_KEY = "ProjectArcade_PrizePools"

local function getStore()
    local md = ModData.getOrCreate(ProjectArcade_PrizeRegistry.MODDATA_KEY)
    md.pools = md.pools or {}
    return md
end

local function transmit()
    if isServer() then
        ModData.transmit(ProjectArcade_PrizeRegistry.MODDATA_KEY)
    end
end

function ProjectArcade_PrizeRegistry.reset()
    if isClient() and not isServer() then return end
    local md = getStore()
    md.pools = {}
    transmit()
end

function ProjectArcade_PrizeRegistry.register(modId, poolName, pool)
                        if isClient() and not isServer() then return end

    if not modId or modId == "" then return end
    if not poolName or poolName == "" then poolName = "default" end
    if type(pool) ~= "table" then return end

        local act = getActivatedMods()
    if act and (not act:contains(modId)) and (modId ~= "ProjectArcade") then
        return
    end

    local md = getStore()
    md.pools[modId] = md.pools[modId] or {}
    md.pools[modId][poolName] = pool

    transmit()
end

function ProjectArcade_PrizeRegistry.getAllPools()
    local md = getStore()
    return md.pools or {}
end

function ProjectArcade_PrizeRegistry.buildMergedPool()
	local out = {}

	if isDefaultPoolEnabled() then
	   for _, e in ipairs(DEFAULT_POOL) do table.insert(out, e) end
	end

		local ok, ext = pcall(require, "ProjectArcade_ExternalPrizes")
	if ok and type(ext)=="table" then
	  for _, e in ipairs(ext) do table.insert(out, e) end
	end

	return out
end

function ProjectArcade_PrizeRegistry.rollWeighted(pool)
    if type(pool) ~= "table" or #pool == 0 then return nil end

    local total = 0
    for _, e in ipairs(pool) do
        local w = tonumber(e.weight) or 0
        if w > 0 then total = total + w end
    end
    if total <= 0 then return nil end

    local r = ZombRand(total) + 1
    local acc = 0
    for _, e in ipairs(pool) do
        local w = tonumber(e.weight) or 0
        if w > 0 then
            acc = acc + w
            if r <= acc then
                return e.item
            end
        end
    end

    return nil
end

function ProjectArcade_PrizeRegistry.rollMerged()
    local merged = ProjectArcade_PrizeRegistry.buildMergedPool()
    return ProjectArcade_PrizeRegistry.rollWeighted(merged)
end
