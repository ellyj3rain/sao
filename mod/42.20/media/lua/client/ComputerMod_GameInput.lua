-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
ComputerModGameInput = ComputerModGameInput or {}

ComputerModGameInput.profileOrder = {"arrows", "wasd", "ijkl", "numpad"}
ComputerModGameInput.profiles = {
    arrows = {
        label = "Arrow keys",
        movementLabel = "ARROWS",
        actionLabel = "SPACE",
        secondaryLabel = "R",
        upLabel = "UP",
        up = Keyboard.KEY_UP,
        down = Keyboard.KEY_DOWN,
        left = Keyboard.KEY_LEFT,
        right = Keyboard.KEY_RIGHT,
        action = Keyboard.KEY_SPACE,
        secondary = Keyboard.KEY_R,
        forward = Keyboard.KEY_W,
        backward = Keyboard.KEY_S,
        strafeLeft = Keyboard.KEY_A,
        strafeRight = Keyboard.KEY_D
    },
    wasd = {
        label = "WASD",
        movementLabel = "WASD",
        actionLabel = "SPACE",
        secondaryLabel = "R",
        upLabel = "W",
        up = Keyboard.KEY_W,
        down = Keyboard.KEY_S,
        left = Keyboard.KEY_A,
        right = Keyboard.KEY_D,
        action = Keyboard.KEY_SPACE,
        secondary = Keyboard.KEY_R,
        forward = Keyboard.KEY_W,
        backward = Keyboard.KEY_S,
        strafeLeft = Keyboard.KEY_Q,
        strafeRight = Keyboard.KEY_E
    },
    ijkl = {
        label = "IJKL",
        movementLabel = "IJKL",
        actionLabel = "SPACE",
        secondaryLabel = "R",
        upLabel = "I",
        up = Keyboard.KEY_I,
        down = Keyboard.KEY_K,
        left = Keyboard.KEY_J,
        right = Keyboard.KEY_L,
        action = Keyboard.KEY_SPACE,
        secondary = Keyboard.KEY_R,
        forward = Keyboard.KEY_I,
        backward = Keyboard.KEY_K,
        strafeLeft = Keyboard.KEY_U,
        strafeRight = Keyboard.KEY_O
    },
    numpad = {
        label = "Numpad",
        movementLabel = "NUMPAD",
        actionLabel = "NUM0",
        secondaryLabel = "NUMENTER",
        upLabel = "NUM8",
        up = Keyboard.KEY_NUMPAD8,
        down = Keyboard.KEY_NUMPAD2,
        left = Keyboard.KEY_NUMPAD4,
        right = Keyboard.KEY_NUMPAD6,
        action = Keyboard.KEY_NUMPAD0,
        secondary = Keyboard.KEY_NUMPADENTER,
        forward = Keyboard.KEY_NUMPAD8,
        backward = Keyboard.KEY_NUMPAD2,
        strafeLeft = Keyboard.KEY_NUMPAD4,
        strafeRight = Keyboard.KEY_NUMPAD6
    }
}

ComputerModGameInput.gameInstanceFields = {
    "pongInstance", "snakeInstance", "minesweeperInstance", "tetrisInstance",
    "spaceInvadersInstance", "doomInstance", "racerInstance", "flappyInstance",
    "breakoutInstance", "asteroidsInstance", "froggerInstance", "missileInstance",
    "landerInstance", "circuitInstance", "memoryInstance", "starPilotInstance",
    "caveRunnerInstance", "lightsOutInstance", "signalMatchInstance", "boxPushInstance",
    "tileSlideInstance", "pipeLinkInstance", "codeBreakerInstance", "outbreakOpsInstance"
}

local function getRoot(element)
    local current = element
    local last = element
    while current do
        last = current
        current = current.parent
    end
    return last
end

function ComputerModGameInput.getPlayer(element)
    local root = getRoot(element)
    return root and root.playerObj or (getPlayer and getPlayer()) or nil
end

function ComputerModGameInput.getProfileName(player)
    local data = player and player.getModData and player:getModData() or nil
    local name = data and tostring(data.ComputerModGameControlProfile or "arrows") or "arrows"
    if not ComputerModGameInput.profiles[name] then name = "arrows" end
    return name
end

function ComputerModGameInput.getProfile(element)
    return ComputerModGameInput.profiles[ComputerModGameInput.getProfileName(ComputerModGameInput.getPlayer(element))]
end

function ComputerModGameInput.getJoypadId(player)
    if not player then return nil end
    if player.getJoypadBind then
        local ok, joypadId = pcall(function() return player:getJoypadBind() end)
        joypadId = ok and tonumber(joypadId) or nil
        if joypadId and joypadId >= 0 then return math.floor(joypadId) end
    end
    if player.getPlayerNum and getJoypadData then
        local okPlayer, playerNum = pcall(function() return player:getPlayerNum() end)
        local okData, joypadData = pcall(function() return getJoypadData(okPlayer and playerNum or 0) end)
        local joypadId = okData and joypadData and tonumber(joypadData.id) or nil
        if joypadId and joypadId >= 0 then return math.floor(joypadId) end
    end
    return nil
end

function ComputerModGameInput.hasGamepad(player)
    local joypadId = ComputerModGameInput.getJoypadId(player)
    if joypadId == nil then return false end
    if isJoypadConnected then
        local ok, connected = pcall(function() return isJoypadConnected(joypadId) end)
        if ok then return connected == true end
    end
    return true
end

local function isJoypadDirectionDown(joypadId, direction)
    local directionFunction = _G and _G["isJoypad" .. direction] or nil
    if directionFunction then
        local ok, down = pcall(directionFunction, joypadId)
        if ok and down == true then return true end
    end

    local movementAxis = nil
    local povAxis = nil
    if direction == "Up" or direction == "Down" then
        if getJoypadMovementAxisY then
            local ok, value = pcall(getJoypadMovementAxisY, joypadId)
            if ok then movementAxis = tonumber(value) end
        end
        if getControllerPovY then
            local ok, value = pcall(getControllerPovY, joypadId)
            if ok then povAxis = tonumber(value) end
        end
        return direction == "Up" and ((movementAxis or 0) < -0.45 or (povAxis or 0) < -0.45)
            or direction == "Down" and ((movementAxis or 0) > 0.45 or (povAxis or 0) > 0.45)
    end

    if getJoypadMovementAxisX then
        local ok, value = pcall(getJoypadMovementAxisX, joypadId)
        if ok then movementAxis = tonumber(value) end
    end
    if getControllerPovX then
        local ok, value = pcall(getControllerPovX, joypadId)
        if ok then povAxis = tonumber(value) end
    end
    return direction == "Left" and ((movementAxis or 0) < -0.45 or (povAxis or 0) < -0.45)
        or direction == "Right" and ((movementAxis or 0) > 0.45 or (povAxis or 0) > 0.45)
end

local function isJoypadButtonDown(joypadId, button)
    if not button or not button.isDown then return false end
    local ok, down = pcall(function() return button:isDown(joypadId) end)
    return ok and down == true
end

function ComputerModGameInput.isGamepadDown(element, action)
    local player = ComputerModGameInput.getPlayer(element)
    local joypadId = ComputerModGameInput.getJoypadId(player)
    if joypadId == nil or not ComputerModGameInput.hasGamepad(player) then return false end

    if action == "up" or action == "forward" then
        return isJoypadDirectionDown(joypadId, "Up")
    elseif action == "down" or action == "backward" then
        return isJoypadDirectionDown(joypadId, "Down")
    elseif action == "left" then
        return isJoypadDirectionDown(joypadId, "Left")
    elseif action == "right" then
        return isJoypadDirectionDown(joypadId, "Right")
    end

    local buttons = Joypad or JoypadButton
    if not buttons then return false end
    if action == "action" then
        return isJoypadButtonDown(joypadId, buttons.AButton or buttons.A)
    elseif action == "secondary" then
        return isJoypadButtonDown(joypadId, buttons.XButton or buttons.X)
    elseif action == "strafeLeft" then
        return isJoypadButtonDown(joypadId, buttons.LBumper or buttons.LeftBump)
    elseif action == "strafeRight" then
        return isJoypadButtonDown(joypadId, buttons.RBumper or buttons.RightBump)
    end
    return false
end

function ComputerModGameInput.isDown(element, action)
    local profile = ComputerModGameInput.getProfile(element)
    local key = profile and profile[action] or nil
    local keyboardDown = key ~= nil and isKeyDown and isKeyDown(key) == true
    return keyboardDown or ComputerModGameInput.isGamepadDown(element, action)
end

function ComputerModGameInput.cycle(player)
    if not player or not player.getModData then return "arrows" end
    local current = ComputerModGameInput.getProfileName(player)
    local index = 1
    for i = 1, #ComputerModGameInput.profileOrder do
        if ComputerModGameInput.profileOrder[i] == current then index = i break end
    end
    index = index % #ComputerModGameInput.profileOrder + 1
    local name = ComputerModGameInput.profileOrder[index]
    player:getModData().ComputerModGameControlProfile = name
    if player.transmitModData then pcall(function() player:transmitModData() end) end
    return name
end

function ComputerModGameInput.getLabel(player)
    local profile = ComputerModGameInput.profiles[ComputerModGameInput.getProfileName(player)]
    return profile and profile.label or "Arrow keys"
end

function ComputerModGameInput.isWorldMovementBlocked(player)
    local data = player and player.getModData and player:getModData() or nil
    return data and data.ComputerModBlockWorldMovementInGames == true or false
end

function ComputerModGameInput.toggleWorldMovementBlock(player)
    if not player or not player.getModData then return false end
    local data = player:getModData()
    data.ComputerModBlockWorldMovementInGames = data.ComputerModBlockWorldMovementInGames ~= true
    if player.transmitModData then pcall(function() player:transmitModData() end) end
    return data.ComputerModBlockWorldMovementInGames == true
end

function ComputerModGameInput.hasActiveGame(element)
    local root = getRoot(element)
    if not root then return false end
    for i = 1, #ComputerModGameInput.gameInstanceFields do
        if root[ComputerModGameInput.gameInstanceFields[i]] ~= nil then return true end
    end
    return false
end

function ComputerModGameInput.updateGridSelection(element, columns, rows)
    columns = math.max(1, math.floor(tonumber(columns) or 1))
    rows = math.max(1, math.floor(tonumber(rows) or 1))
    element.gamepadSelectionX = math.max(1, math.min(columns, tonumber(element.gamepadSelectionX) or 1))
    element.gamepadSelectionY = math.max(1, math.min(rows, tonumber(element.gamepadSelectionY) or 1))

    local current = {
        up = ComputerModGameInput.isGamepadDown(element, "up"),
        down = ComputerModGameInput.isGamepadDown(element, "down"),
        left = ComputerModGameInput.isGamepadDown(element, "left"),
        right = ComputerModGameInput.isGamepadDown(element, "right"),
        action = ComputerModGameInput.isGamepadDown(element, "action"),
        secondary = ComputerModGameInput.isGamepadDown(element, "secondary")
    }
    local previous = element.computerModGamepadSelectionPressed or {}
    if current.left and not previous.left then
        element.gamepadSelectionX = (element.gamepadSelectionX - 2) % columns + 1
    elseif current.right and not previous.right then
        element.gamepadSelectionX = element.gamepadSelectionX % columns + 1
    end
    if current.up and not previous.up then
        element.gamepadSelectionY = (element.gamepadSelectionY - 2) % rows + 1
    elseif current.down and not previous.down then
        element.gamepadSelectionY = element.gamepadSelectionY % rows + 1
    end
    local activated = current.action and not previous.action
    local secondaryActivated = current.secondary and not previous.secondary
    element.computerModGamepadSelectionPressed = current
    return element.gamepadSelectionX, element.gamepadSelectionY, activated, secondaryActivated
end

function ComputerModGameInput.drawGamepadSelection(element, x, y, width, height)
    if not element or not element.drawRect or not ComputerModGameInput.hasGamepad(ComputerModGameInput.getPlayer(element)) then return end
    local pulse = 0.72 + math.abs(math.sin((tonumber(element.animationTick or element.tick or element.timerTicks) or 0) * 0.08)) * 0.28
    element:drawRect(x, y, width, 2, pulse, 0.94, 0.90, 0.34)
    element:drawRect(x, y + height - 2, width, 2, pulse, 0.94, 0.90, 0.34)
    element:drawRect(x, y, 2, height, pulse, 0.94, 0.90, 0.34)
    element:drawRect(x + width - 2, y, 2, height, pulse, 0.94, 0.90, 0.34)
end

function ComputerModGameInput.getInputLabel(element, action)
    if ComputerModGameInput.hasGamepad(ComputerModGameInput.getPlayer(element)) then
        local gamepadLabels = {
            movement = "D-PAD / L-STICK",
            action = "A",
            secondary = "X",
            up = "D-PAD UP",
            down = "D-PAD DOWN",
            left = "D-PAD LEFT",
            right = "D-PAD RIGHT",
            forward = "L-STICK UP",
            backward = "L-STICK DOWN",
            strafeLeft = "LB",
            strafeRight = "RB"
        }
        if gamepadLabels[action] then return gamepadLabels[action] end
    end
    local profile = ComputerModGameInput.getProfile(element)
    if not profile then return "KEY" end
    if action == "movement" then return profile.movementLabel or profile.label or "KEYS" end
    if action == "action" then return profile.actionLabel or "ACTION" end
    if action == "secondary" then return profile.secondaryLabel or "SECONDARY" end
    if action == "up" then return profile.upLabel or "UP" end
    return string.upper(tostring(action or "KEY"))
end
