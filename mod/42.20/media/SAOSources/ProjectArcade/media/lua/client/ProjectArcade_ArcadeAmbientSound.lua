-- =============================================================================
-- ArcadeAmbientSound.lua
-- Addon de sonido ambiente para máquinas de arcade
-- Compatible con Project Zomboid Build 42.x
-- =============================================================================
-- Para agregar nuevas máquinas:
--   1. Agregar una nueva entrada a ARCADE_MACHINES con los tiles y el sonido.
--   2. No es necesario modificar nada más.
-- =============================================================================

local ArcadeAmbientSound = {}

-- ----------------------------------------------------------------------------
-- CONFIGURACIÓN: Máquinas de arcade y sus sonidos
-- ----------------------------------------------------------------------------
local ARCADE_MACHINES = {
    {
        name  = "SF",
        tiles = {
            ["pa_arcades_0"] = true,
            ["pa_arcades_1"] = true,
            ["pa_arcades_2"] = true,
            ["pa_arcades_3"] = true,
        },
        sound = "SFMachineAmbience",
    },

    {
        name  = "TMNT",
        tiles = {
            ["pa_arcades_32"] = true,
            ["pa_arcades_33"] = true,
            ["pa_arcades_34"] = true,
            ["pa_arcades_35"] = true,
        },
        sound = "TMNTMachineAmbience",
    },

    {
        name  = "NBA",
        tiles = {
            ["pa_arcades_28"] = true,
            ["pa_arcades_29"] = true,
            ["pa_arcades_30"] = true,
            ["pa_arcades_31"] = true,
        },
        sound = "NBAMachineAmbience",
    },

    {
        name  = "Dig Dug",
        tiles = {
            ["pa_arcades_24"] = true,
            ["pa_arcades_25"] = true,
            ["pa_arcades_26"] = true,
            ["pa_arcades_27"] = true,
        },
        sound = "DigDMachineAmbience",
    },

    {
        name  = "DD",
        tiles = {
            ["pa_arcades_8"] = true,
            ["pa_arcades_9"] = true,
            ["pa_arcades_10"] = true,
            ["pa_arcades_11"] = true,
        },
        sound = "DDMachineAmbience",
    },

    {
        name  = "MK",
        tiles = {
            ["pa_arcades_36"] = true,
            ["pa_arcades_37"] = true,
            ["pa_arcades_38"] = true,
            ["pa_arcades_39"] = true,
        },
        sound = "MKMachineAmbience",
    },

    {
        name  = "Claw",
        tiles = {
            ["pa_recreational_2"] = true,
            ["pa_recreational_3"] = true,
            ["pa_recreational_4"] = true,
            ["pa_recreational_5"] = true,
        },
        sound = "ClawMachineAmbience",
    },

    {
        name  = "T2",
        tiles = {
            ["pa_complex_0"] = true,
            ["pa_complex_1"] = true,
        },
        sound = "T2MachineAmbience",
    },
}

-- ----------------------------------------------------------------------------
-- CONSTANTES
-- ----------------------------------------------------------------------------
local COOLDOWN_MS    = 2 * 60 * 1000  -- 2 minutos en milisegundos
local CHECK_RADIUS   = 5              -- Radio en tiles alrededor del jugador
local SOUND_RADIUS   = 10             -- Radio de atenuación del sonido (tiles)
local SOUND_VOLUME   = 1.0            -- Volumen (0.0 - 1.0)

-- ----------------------------------------------------------------------------
-- ESTADO INTERNO
-- ----------------------------------------------------------------------------
local lastPlayedAt = {}

local function buildSpriteIndex()
    local index = {}
    for _, machine in ipairs(ARCADE_MACHINES) do
        for spriteName, _ in pairs(machine.tiles) do
            index[spriteName] = machine
        end
    end
    return index
end

local SPRITE_INDEX = buildSpriteIndex()

-- ----------------------------------------------------------------------------
-- UTILIDADES
-- ----------------------------------------------------------------------------

local function tileKey(x, y, z)
    return x .. "," .. y .. "," .. z
end

--- Verifica si la máquina tiene electricidad (misma lógica que el resto del mod)
local function machineHasPower(obj)
    if not obj then return false end
    local square = obj:getSquare()
    if not square then return false end
    if square:haveElectricity() then
        return true
    end
    local gt = GameTime and GameTime.getInstance and GameTime:getInstance() or nil
    local shutModifier = SandboxVars and SandboxVars.ElecShutModifier
    if gt and shutModifier and shutModifier > -1 then
        if gt:getNightsSurvived() < shutModifier then
            return true
        end
    end
    return false
end

--- Reproduce el sonido anclado al IsoGridSquare del tile
--- PlayWorldSound(name, square, attackTime, radius, volume, isTrueLocation)
local function playSoundAt(soundName, square)
    getSoundManager():PlayWorldSound(soundName, square, 0, SOUND_RADIUS, SOUND_VOLUME, true)
end

--- Devuelve true si la opción sandbox de desactivar está habilitada
local function isDisabledBySandbox()
    return SandboxVars
        and SandboxVars.ProjectArcade
        and SandboxVars.ProjectArcade.DisableArcadeAmbientSound == true
end

-- ----------------------------------------------------------------------------
-- API PÚBLICA
-- Llamada desde ProjectArcade_PlayArcadeTimedAction cuando el jugador
-- empieza a jugar, para silenciar el ambiente de esa máquina y poner
-- en cooldown inmediatamente.
-- ----------------------------------------------------------------------------

--- Suprime el sonido ambiente de la máquina que contiene el sprite dado.
--- obj: el IsoObject de la máquina (el mismo que recibe el TimedAction)
function ArcadeAmbientSound.suppressForObject(obj)
    if not obj then return end
    local sq = obj:getSquare()
    if not sq then return end

    local sprite = obj:getSprite()
    local spriteName = sprite and sprite:getName() or nil
    if not spriteName then return end

    if not SPRITE_INDEX[spriteName] then return end

    local key = tileKey(sq:getX(), sq:getY(), sq:getZ())
    lastPlayedAt[key] = getTimestampMs()

    print("[ArcadeAmbientSound] Suprimido ambiente en " .. key .. " por inicio de juego.")
end

-- ----------------------------------------------------------------------------
-- LÓGICA PRINCIPAL
-- ----------------------------------------------------------------------------

local function checkNearbyArcades()
    -- Opción sandbox: funcionalidad completamente desactivada
    if isDisabledBySandbox() then return end

    local player = getPlayer()
    if not player then return end

    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())

    local now = getTimestampMs()

    for dx = -CHECK_RADIUS, CHECK_RADIUS do
        for dy = -CHECK_RADIUS, CHECK_RADIUS do
            local wx = px + dx
            local wy = py + dy
            local square = getCell():getGridSquare(wx, wy, pz)

            if square then
                local objects = square:getObjects()
                for i = 0, objects:size() - 1 do
                    local obj = objects:get(i)
                    local sprite = obj:getSprite()

                    if sprite then
                        local spriteName = sprite:getName()
                        local machine = SPRITE_INDEX[spriteName]

                        if machine then
                            local key = tileKey(wx, wy, pz)
                            local last = lastPlayedAt[key] or 0

                            if (now - last) >= COOLDOWN_MS then
                                -- Solo suena si hay electricidad
                                if machineHasPower(obj) then
                                    playSoundAt(machine.sound, square)
                                    lastPlayedAt[key] = now
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- LIMPIEZA DE CACHÉ al cargar nuevo mapa
-- ----------------------------------------------------------------------------
local function clearStaleCache()
    lastPlayedAt = {}
end

-- ----------------------------------------------------------------------------
-- HOOKS
-- ----------------------------------------------------------------------------

local tickCounter = 0
local TICK_INTERVAL = 180  -- ~3 segundos a 60 tps

Events.OnTickEvenPaused.Add(function()
    tickCounter = tickCounter + 1
    if tickCounter >= TICK_INTERVAL then
        tickCounter = 0
        checkNearbyArcades()
    end
end)

Events.OnPostMapLoad.Add(clearStaleCache)

return ArcadeAmbientSound
