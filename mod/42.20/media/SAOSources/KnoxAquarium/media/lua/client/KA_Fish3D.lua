--[[ Knox Aquarium - real 3D fish models.

    Build 42 items carry their own 3D model as a script name on the item itself
    (WorldStaticModel / StaticModel). Reading that name off the item means the
    aquarium shows the species' ACTUAL mesh and ACTUAL texture at its ACTUAL
    proportions - vanilla fish and modded fish alike - without this mod shipping,
    copying or even naming anyone else's assets. If a fishing mod is installed
    its models are used because the item points at them. If it is uninstalled the
    item is gone too, so there is never a dangling model reference.

    The viewer is an ISUI3DScene, the same element the base game uses for its
    vehicle editor. It is a UI element only: it touches no world object, no grid
    square and no save data, so it cannot affect tank state, multiplayer sync or
    an existing save in any way.
]]
require 'KA_Core'
require 'KA_FishRegistry'
local K = KnoxAquarium

K.fish3D = K.fish3D or {}
local F = K.fish3D
local modelCache = {}

-- Resolve an item type to a model script name. Order matches how the base game
-- itself resolves a dropped item's mesh: world model first, held model second.
-- Some mods register the script under a bare name and some under "Base.", so
-- both spellings are offered and the scene is left to accept one.
function F.modelCandidates(itemType)
    if type(itemType) ~= 'string' then return {} end
    if modelCache[itemType] then return modelCache[itemType] end
    local names = {}
    local function add(name)
        if type(name) ~= 'string' or name == '' then return end
        for _, existing in ipairs(names) do if existing == name then return end end
        table.insert(names, name)
        if not string.find(name, '.', 1, true) then table.insert(names, 'Base.'..name) end
    end
    -- instanceItem is cheap and the result is discarded; the model name is the
    -- only thing wanted and it is cached per type.
    local ok, item = pcall(function() return instanceItem(itemType) end)
    if ok and item then
        pcall(function() add(item:getWorldStaticModel()) end)
        pcall(function() add(item:getStaticModel()) end)
    end
    modelCache[itemType] = names
    return names
end

function F.hasModel(itemType)
    return #F.modelCandidates(itemType) > 0
end

-- ---------------------------------------------------------------- the viewer
-- Returns a viewer handle, or nil when the 3D scene is unavailable for any
-- reason. Every caller must cope with nil; the aquarium's windows fall back to
-- text, exactly as they read before this file existed.
function F.createViewer(parent, x, y, w, h)
    if not rawget(_G, 'ISUI3DScene') then return nil end
    local viewer = {shown = nil}
    local ok = pcall(function()
        local scene = ISUI3DScene:new(x, y, w, h)
        scene:initialise()
        parent:addChild(scene)
        local java = scene.javaObject
        java:fromLua1('setDrawGrid', false)
        java:fromLua1('setDrawGridAxes', false)
        java:fromLua1('setDrawGridPlane', false)
        -- The tank's own window owns the mouse; swallow scene input so dragging
        -- inside the viewer cannot spin or zoom it by accident.
        scene.onMouseDown = function() return true end
        scene.onMouseMove = function() return true end
        scene.onMouseUp = function() return true end
        scene.onMouseUpOutside = function() return true end
        scene.onMouseWheel = function() return true end
        viewer.scene = scene
        viewer.java = java
    end)
    if not ok or not viewer.java then return nil end
    return setmetatable(viewer, {__index = F.viewerMethods})
end

F.viewerMethods = {}
local V = F.viewerMethods
local SLOT = 'ka_fish'

function V:clear()
    if not self.java or not self.shown then return end
    pcall(function() self.java:fromLua1('removeModel', SLOT) end)
    self.shown = nil
end

-- Show a species by item type. Returns true when a model was actually mounted.
function V:setFish(itemType)
    if not self.java then return false end
    if self.shown == itemType then return true end
    self:clear()
    if type(itemType) ~= 'string' then return false end
    for _, name in ipairs(F.modelCandidates(itemType)) do
        local ok = pcall(function() self.java:fromLua2('createModel', SLOT, name) end)
        -- createModel is tolerant of a bad name, so confirm something mounted
        -- rather than trusting the call not to have thrown.
        local mounted = false
        if ok then pcall(function() mounted = self.java:fromLua1('getObjectExists', SLOT) and true or false end) end
        if mounted then
            self.shown = itemType
            pcall(function() self.java:fromLua4('setObjectPosition', SLOT, 0, 0, 0) end)
            -- setObjectAutoRotate takes the object AND a boolean, through
            -- fromLua2. Calling it with one argument through fromLua1 is what
            -- produced 'unhandled "setObjectAutoRotate"' in the console: the
            -- scene has no one-argument form of it, so the call fell through to
            -- the catch-all and threw. AttachmentEditorUI.lua uses the two
            -- argument form.
            pcall(function() self.java:fromLua2('setObjectAutoRotate', SLOT, true) end)
            pcall(function() self.java:fromLua3('setViewRotation', 18, 35, 0) end)
            pcall(function() self.java:fromLua1('setMaxZoom', 40) end)
            pcall(function() self.java:fromLua1('setZoom', self.zoom or 14) end)
            return true
        end
        pcall(function() self.java:fromLua1('removeModel', SLOT) end)
    end
    return false
end

function V:setZoom(z)
    self.zoom = z
    if self.java then pcall(function() self.java:fromLua1('setZoom', z) end) end
end

-- The scene is a child of the window that made it, so closing that window takes
-- it away. This only drops the mounted model, which is what holds a reference.
function V:remove()
    self:clear()
end
