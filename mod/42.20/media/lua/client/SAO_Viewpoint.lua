-- Project Viewpoint's native-menu harvester keeps actions tied to the object
-- under its first/third-person cursor. SAO's person callbacks close over an
-- identity, so this late callback gives those existing options their exact
-- represented body as a harmless context-menu argument. Viewpoint then runs
-- the ordinary SAO action; no second action list or camera is created here.
SAO = SAO or {}
SAO.Viewpoint = SAO.Viewpoint or {}
local V = SAO.Viewpoint

function V.available()
    return Viewpoint and Viewpoint.Keys ~= nil
        and type(ViewpointInteract) == "table"
        and type(ViewpointInteract.harvest) == "function"
        and type(ViewpointInteract.run) == "function"
end

local function representedPerson(worldobjects)
    local bodies = SAO.Body
    local identity = SAO.Identity
    if not (bodies and bodies.get and identity and identity.get) then return nil end
    for _, object in ipairs(worldobjects or {}) do
        for _, registry in ipairs({ bodies.active or {}, bodies.foreign or {} }) do
            for id, body in pairs(registry) do
                if object == body and bodies.get(id) == body then
                    local rec = identity.get(id)
                    if rec and rec.id == id and not rec.dead then
                        local ok, dead, square = pcall(function()
                            return body:isDead(), body:getSquare()
                        end)
                        if ok and not dead and square then return id, rec, body end
                    end
                end
            end
        end
    end
    return nil
end

local function optionNamed(menu, name)
    if not menu or type(menu.getOptionFromName) ~= "function" then return nil end
    local ok, option = pcall(function() return menu:getOptionFromName(name) end)
    return ok and option or nil
end

local function childNamed(context, root, name)
    if not root or not root.subOption or not context
        or type(context.getSubMenu) ~= "function" then return nil end
    local ok, submenu = pcall(function() return context:getSubMenu(root.subOption) end)
    return ok and optionNamed(submenu, name) or nil
end

local function anchor(option, body)
    if not option or type(option.onSelect) ~= "function"
        or option.param1 ~= nil then return false end
    option.param1 = body
    return true
end

-- Called after SAO_Harness and SAO_Neighbours have built the normal menu.
-- The submenu needs one object-owned leaf so Viewpoint retains its siblings.
-- Every sibling still executes its own original SAO callback and gates.
function V.bindPersonMenu(_, context, worldobjects)
    if not V.available() or not context then return false end
    local id, rec, body = representedPerson(worldobjects)
    if not id then return false end

    local known = nil
    if type(SAO.Identity.knownName) == "function" then
        local ok, name = pcall(SAO.Identity.knownName, rec)
        if ok and type(name) == "string" and name ~= "" then known = name end
    end
    local talk = optionNamed(context, "Talk to " .. (known or id))
    local person = optionNamed(context, tostring(known or "them") .. "...")
    local look = childNamed(context, person, "Look them over")
    local changed = anchor(talk, body)
    changed = anchor(look, body) or changed

    -- When the optional neighbour bridge owns the one person root, SAO has
    -- already replaced its contents with SAO's talk/tell and their verbs.
    local nb = SAO.Neighbours
    if nb and type(nb.bridgeOpen) == "function"
        and type(nb.profileFor) == "function" then
        local okOpen, open = pcall(nb.bridgeOpen)
        if okOpen and open then
            local okProfile, profile = pcall(nb.profileFor, id)
            local name = okProfile and profile and profile.name
            if type(name) == "string" and name ~= "" then
                local root = optionNamed(context, name .. "...")
                changed = anchor(childNamed(context, root, "Talk to them"), body)
                    or changed
            end
        end
    end
    return changed
end

-- OnTick starts after OnGameStart, where Neighbours registers its late menu
-- handler. Re-adding once also puts this callback after Harness's file-scope
-- registration regardless of Lua file loading order.
local function installAfterStart()
    local fill = Events and Events.OnFillWorldObjectContextMenu
    if not (fill and fill.Add and fill.Remove) then return end
    if V.menuHandler then fill.Remove(V.menuHandler) end
    V.menuHandler = V.bindPersonMenu
    fill.Add(V.menuHandler)
    Events.OnTick.Remove(installAfterStart)
end

if Events and Events.OnTick and Events.OnTick.Add then
    Events.OnTick.Add(installAfterStart)
end

return V
