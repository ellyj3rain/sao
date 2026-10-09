-- Adapted from Project Viewpoint 0.1.5a-hotfix by ellu and norkus.
-- SAO owns the packaged behavior and settings; see CREDITS.md.







SAO = SAO or {}
SAO.Viewpoint = SAO.Viewpoint or {}

local function mouse()
    return Viewpoint and Viewpoint.Mouse
end

local function wrap()
    if ISCoordConversion and ISCoordConversion.viewpointWrapped then
        SAOViewpointMouseLoaded = true
        return true
    end
    if not mouse() or not ISCoordConversion
        or type(ISCoordConversion.ToWorld) ~= "function" then return false end
    local toWorld = ISCoordConversion.ToWorld
    ISCoordConversion.ToWorld = function(x, y, z)
        local m = mouse()
        local wx = m and m.worldX()
        local wy = m and m.worldY()
        if wx and wy then return wx, wy end
        return toWorld(x, y, z)
    end
    ISCoordConversion.viewpointWrapped = true
    SAOViewpointMouseLoaded = true
    return true
end

wrap()
if not SAO.Viewpoint.mouseEventsInstalled then
    Events.OnGameStart.Add(wrap)
    SAO.Viewpoint.mouseEventsInstalled = true
end
