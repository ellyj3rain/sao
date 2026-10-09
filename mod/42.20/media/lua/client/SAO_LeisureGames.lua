require "ISBaseObject"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
SAO=SAO or {}
if not SAO.SourceIntegration and type(require)=="function"then pcall(require,"SAO_SourceIntegration")end;SAO.LeisureGames=SAO.LeisureGames or {}
local G=SAO.LeisureGames
if G.reset then G.reset("module-reload")end
local runtime={};local sceneOwners={};local current
local Definitions={["pong"]={["className"]="PZPongGame",["revision"]="41640a406d036b4cf22942f31355cd906e3e33e7c5a5a93296ed4fd3be0871d1",["keys"]={"action","down","up"}},["snake"]={["className"]="PZSnakeGame",["revision"]="6dc4b4e86cdf8b0c9e1d30661425d10ea3b2aa1aa77adefbfd607f5a98b8f61d",["keys"]={"action","down","left","right","up"}},["minesweeper"]={["className"]="PZMinesweeperGame",["revision"]="2145c21b079a8e0f2e91d05d226bfc52d35a6e5aa1703084c7897723a46b98c5",["keys"]={"action","down","left","right","secondary","up"}},["tetris"]={["className"]="PZTetrisGame",["revision"]="dc8aa3ef77e0b36d88e4fcfcfdc0e5b3662e75ff5ecd135b9dfa53d89800fa98",["keys"]={"action","down","left","right","up"}},["space_invaders"]={["className"]="PZSpaceInvadersGame",["revision"]="0830e492f8dd67b614d5a02ad77ba46eb24846812a174d26157719369263b7f5",["keys"]={"action","left","right"}},["doom"]={["className"]="PZDoomGame",["revision"]="c3529f653ee89e81cf078a3b7150ea5997aa08a3a8918bcc67665ab198123def",["keys"]={"action","backward","down","forward","left","right","secondary","strafeLeft","strafeRight","up"}},["racer"]={["className"]="PZRacerGame",["revision"]="11fa140f101036151858fe01e42efa279b8b881f373df98952cc42b64770c176",["keys"]={"action","down","left","right","up"}},["flappy"]={["className"]="PZFlappyGame",["revision"]="cd7bfa33699dde0b007f243569807807b16c1c614dd4ffc6d21bd5461cb3e13e",["keys"]={"action","up"}},["breakout"]={["className"]="PZBreakoutGame",["revision"]="76ab39f313333c50fc9dea6d0e51184b49135fcacbae3ced3c1343b895db8418",["keys"]={"action","left","right"}},["asteroids"]={["className"]="PZAsteroidsGame",["revision"]="8e00ed8363045bcafde856b7bd7859a747c4310c7474ecff595617c6f4ebebfa",["keys"]={"action","down","left","right","up"}},["frogger"]={["className"]="PZFroggerGame",["revision"]="46cc9e0d0a75a1608d8c5f33e3570d6f468b2f637336fae25aef8d0636b947d4",["keys"]={"action","down","left","right","up"}},["missile"]={["className"]="PZMissileCommandGame",["revision"]="7f8b23a247f53e70b02b8089a1ced82c5aeea411f3d0d2d488ff1daf6ecfce69",["keys"]={"action","down","left","right","up"}},["lander"]={["className"]="PZLunarLanderGame",["revision"]="621f41f46d8476ad501e2a0123eda2a5a3a9ef453dcf24f8ace63a5829282a28",["keys"]={"action","left","right","up"}},["circuit"]={["className"]="PZCircuitRunnerGame",["revision"]="c32b06c21b3ab9b15859db6f318d890fd94cfd9451aaebcf5b3be228300b2300",["keys"]={"action","down","left","right","up"}},["memory"]={["className"]="PZMemoryMatchGame",["revision"]="a20982ee466f1ae150ad2f30e7e2f0c4377c58a320bb9e4e98a4301f7478ed73",["keys"]={"action","down","left","right","secondary","up"}},["starpilot"]={["className"]="PZStarPilotGame",["revision"]="aa88003ee013ed21af03f7553ac2c1eb0c8a9bd0ea45ce77ffd9e1434bd47b77",["keys"]={"action","backward","down","forward","left","right","strafeLeft","strafeRight","up"}},["caverunner"]={["className"]="PZCaveRunnerGame",["revision"]="0d47a4dd4a27ca31d19c6af3d7483ad36bc9342186020506deec8a9987857a59",["keys"]={"action","backward","down","forward","up"}},["lightsout"]={["className"]="PZLightsOutGame",["revision"]="c8f78c7584d0ad3bf5b739a4db0fd11d05c58de121307db1aa2718e32f7ca726",["keys"]={"action","down","left","right","secondary","up"}},["signalmatch"]={["className"]="PZSignalMatchGame",["revision"]="17e68905d7c797ee57fd2ed0f268b648f9b331e44419983a6cf57fbae75944d0",["keys"]={"action","down","left","right","secondary","up"}},["boxpush"]={["className"]="PZBoxPushGame",["revision"]="8431f2deb519031afdeeacb9e46dfd09d578a799d35108d4e494e0741d0c0e2b",["keys"]={"action","backward","down","forward","left","right","strafeLeft","strafeRight","up"}},["tileslide"]={["className"]="PZTileSlideGame",["revision"]="637970961b1cb81ecd37b83e6516c51e22bb9397986f825a4a71d469ea683ed6",["keys"]={"action","down","left","right","secondary","up"}},["pipelink"]={["className"]="PZPipeLinkGame",["revision"]="608bd8f5c4d12c6103608acfd81a01b8e272d90a15dbcb37686a06d920f7b5d2",["keys"]={"action","down","left","right","secondary","up"}},["codebreaker"]={["className"]="PZCodeBreakerGame",["revision"]="c873028660092761e8303b38d17f4fdce59fdc80002d07b9ebc833184e8df9dc",["keys"]={"action","down","left","right","secondary","up"}},["outbreakops"]={["className"]="PZOutbreakOpsGame",["revision"]="a9f3e1bcef4f83a9ab73e0223c7fa6584b42ca493c053931b31efbdb1ba7684b",["keys"]={"action","backward","down","forward","left","right","secondary","strafeLeft","strafeRight","up"}}}
local PingRevision="9ea42c24e57a2ea75e5cd450c008c20578042893622b3cb1088b70fe71154ccd"
local ArcadeRevision="0004ea7bc92d3ec3844bd8cb35254a0317c349e19dadbfd2cef2b97c0a0cf5fc"
local ClawRevision="51859529688195ee783c08a0d317ccd22120fb1630e777a9bf6182574baedbc2"
local GameClasses={}
local owned,usable,finish,render,snapshot,measured
local function finite(n)return type(n)=="number"and n==n and math.abs(n)<math.huge end
local function plain(v,depth)
    if type(v)=="number"then return finite(v)and v or nil end
    if type(v)=="boolean"or type(v)=="string"then return v end
    depth=depth or 0;if type(v)~="table"or depth>10 then return nil end
    local out={}for k,x in pairs(v)do if type(k)=="string"or type(k)=="number"then out[k]=plain(x,depth+1)end end;return out
end
local function same(a,b)
    if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
    for k,v in pairs(a)do if not same(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function rec(id)return SAO.Identity and SAO.Identity.get(id)end
local function hours()return SAO.History.countyHours()end
local function getTimestampMs()return hours()*3600000 end
local HaloTextHelper={addTextWithArrow=function(body,text,positive,r,g,b)
    if not current or current.body~=body or not owned(current)then error("unbound-source-arcade-presentation")end
    current.halos=current.halos or{};if #current.halos>=64 then table.remove(current.halos,1)end
    current.halos[#current.halos+1]={text=text,positive=positive,r=r,g=g,b=b,atHours=hours()}
end}
local function live(id,body)
    return rec(id)and not rec(id).dead and body and SAO.Needs.ownsRecoveryBody(id,body)==true
        and not body:isDead()and not body:isAsleep()and body:isExistInTheWorld()
end
-- Private logical source scene. No player panel, slot, key or UI manager changes.
local ISPanel=ISBaseObject:derive("SAOActorGameScene")
function ISPanel:new(x,y,width,height)
    local o={x=x,y=y,width=width,height=height};setmetatable(o,self);self.__index=self;return o
end
function ISPanel:initialise()end
local function draw(scene,kind,args)
    local a=sceneOwners[scene]
    if not a or not current or current~=a or not owned(a)then error("unbound-source-game-presentation")end
    a.drawCount=a.drawCount+1
    local row={kind=kind,args=plain(args)}
    local rows=a.drawCommands
    if #rows>=4096 then table.remove(rows,1);a.drawOmitted=a.drawOmitted+1 end
    rows[#rows+1]=row
end
function ISPanel:drawRect(...)draw(self,"rect",{...})end
function ISPanel:drawText(text,x,y,r,g,b,alpha,font)
    draw(self,"text",{text,x,y,r,g,b,alpha,tostring(font)})
end
function ISPanel:drawTextureScaled(texture,x,y,width,height,alpha,r,g,b)
    draw(self,"texture",{texture and texture:getName(),x,y,width,height,alpha,r,g,b})
end
local function inputs(scene)
    local a=sceneOwners[scene]
    return a and current==a and owned(a)and a.keys or {}
end
local ComputerModGameInput={}
function ComputerModGameInput.isDown(scene,key)return inputs(scene)[key]==true end
ComputerModGameInput.isGamepadDown=ComputerModGameInput.isDown
function ComputerModGameInput.hasGamepad()return true end
function ComputerModGameInput.getPlayer(scene)return sceneOwners[scene]and sceneOwners[scene].body or nil end
function ComputerModGameInput.drawGamepadSelection(scene,x,y,width,height)
    -- Actual source selector frame, grounded in its actor-local controller mode.
    local pulse=.72+math.abs(math.sin((tonumber(scene.animationTick or scene.tick or scene.timerTicks)or 0)*.08))*.28
    scene:drawRect(x,y,width,2,pulse,.94,.90,.34)
    scene:drawRect(x,y+height-2,width,2,pulse,.94,.90,.34)
    scene:drawRect(x,y,2,height,pulse,.94,.90,.34)
    scene:drawRect(x+width-2,y,2,height,pulse,.94,.90,.34)
end
local function getSoundManager()return {playUISound=function(_,name)
    if current and owned(current)then
        current.sounds=current.sounds or {};current.sounds[#current.sounds+1]=tostring(name)
        if #current.sounds>64 then table.remove(current.sounds,1)end
    end
end}end
-- Original ping-pong timestamps are bound to this actor's simulation clock.
local function getTimestamp()return current and hours()*3600 or 0 end
local function isKeyDown()return false end
local Keyboard={KEY_LSHIFT="LSHIFT"}

-- BEGIN INSTALLED SOURCE ComputerMod_GameInput.labels
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

function ComputerModGameInput.getProfileName(player)
    local data = player and player.getModData and player:getModData() or nil
    local name = data and tostring(data.ComputerModGameControlProfile or "arrows") or "arrows"
    if not ComputerModGameInput.profiles[name] then name = "arrows" end
    return name
end

function ComputerModGameInput.getProfile(element)
    return ComputerModGameInput.profiles[ComputerModGameInput.getProfileName(ComputerModGameInput.getPlayer(element))]
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
-- END INSTALLED SOURCE ComputerMod_GameInput.labels
-- BEGIN INSTALLED SOURCE ComputerMod_UI_State.mood
local ComputerMood=(function()
local target={}
local ComputerScreenUI={}
local function clampComputerMood(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function adjustComputerCharacterStat(stats, stat, delta)
    if not stats or not stat or not delta or delta == 0 then return false end
    if delta < 0 then
        local ok = pcall(function() stats:remove(stat, -delta) end)
        if ok then return true end
    elseif delta > 0 then
        local ok = pcall(function() stats:add(stat, delta) end)
        if ok then return true end
    end
    local okGet, value = pcall(function() return stats:get(stat) end)
    if okGet and type(value) == "number" then
        local okSet = pcall(function() stats:set(stat, math.max(0, value + delta)) end)
        if okSet then return true end
    end
    return false
end

function target:adjustPlayerMood(boredomDelta, stressDelta, sadnessDelta, playerOverride)
    local playerObj = playerOverride or self.playerObj
    if not playerObj and getPlayer then
        local okPlayer, value = pcall(getPlayer)
        if okPlayer then playerObj = value end
    end
    if not playerObj then return end
    local stats = nil
    local bodyDamage = nil
    local okStats, statsValue = pcall(function() return playerObj:getStats() end)
    if okStats then stats = statsValue end
    local okBody, bodyValue = pcall(function() return playerObj:getBodyDamage() end)
    if okBody then bodyDamage = bodyValue end
    if boredomDelta and boredomDelta ~= 0 then
        local changed = CharacterStat and adjustComputerCharacterStat(stats, CharacterStat.BOREDOM, boredomDelta)
        if not changed and bodyDamage then
            local ok, value = pcall(function() return bodyDamage:getBoredomLevel() end)
            if ok and type(value) == "number" then
                pcall(function() bodyDamage:setBoredomLevel(clampComputerMood(value + boredomDelta, 0, 100)) end)
            end
        end
        if not changed and stats then
            local ok, value = pcall(function() return stats:getBoredom() end)
            if ok and type(value) == "number" then
                pcall(function() stats:setBoredom(clampComputerMood(value + boredomDelta, 0, 100)) end)
            end
        end
    end
    if stressDelta and stressDelta ~= 0 then
        local changed = CharacterStat and adjustComputerCharacterStat(stats, CharacterStat.STRESS, stressDelta)
        if not changed and stats then
            local ok, value = pcall(function() return stats:getStress() end)
            if ok and type(value) == "number" then
                pcall(function() stats:setStress(clampComputerMood(value + stressDelta, 0, 1)) end)
            end
        end
    end
    if sadnessDelta and sadnessDelta ~= 0 then
        local changed = CharacterStat and adjustComputerCharacterStat(stats, CharacterStat.UNHAPPINESS, sadnessDelta)
        if not changed and bodyDamage then
            local ok, value = pcall(function() return bodyDamage:getUnhappynessLevel() end)
            if ok and type(value) == "number" then
                pcall(function() bodyDamage:setUnhappynessLevel(clampComputerMood(value + sadnessDelta, 0, 100)) end)
            end
        end
    end
end

function target:updateGameMoodEffects(timeStep)
    if not self:isGameView() then
        self.gameMoodTick = 0
        self.lastGameOutcomeState = nil
        return
    end
    self.gameMoodTick = (self.gameMoodTick or 0) + timeStep
    while self.gameMoodTick >= 30 do
        self.gameMoodTick = self.gameMoodTick - 30
        self:adjustPlayerMood(-0.25, -0.0025, -0.18)
    end
    local game = self:getActiveGameInstance()
    local state = game and game.gameState or nil
    if state == "GAMEOVER" and self.lastGameOutcomeState ~= "GAMEOVER" then
        self:adjustPlayerMood(0, 0.08, 0)
    end
    self.lastGameOutcomeState = state
end

local function updateComputerGameMoodFromPlayer(playerObj)
    local ui = ComputerScreenUI and ComputerScreenUI.instance or nil
    if not ui or not ui.isVisible or not ui:isVisible() then
        if ui then
            ui.gameMoodLastTickMs = nil
            ui.computerUseMoodLastTickMs = nil
            ui.lastPlayerGameOutcomeState = nil
        end
        return
    end
    ui.playerObj = playerObj or ui.playerObj
    local nowMs = getTimestampMs and getTimestampMs() or nil
    if not nowMs then
        return
    end
    ui.computerUseMoodLastTickMs = ui.computerUseMoodLastTickMs or nowMs
    if nowMs - ui.computerUseMoodLastTickMs >= 5000 then
        ui.computerUseMoodLastTickMs = nowMs
        ui:adjustPlayerMood(-0.20, -0.002, -0.15, playerObj)
    end
    if not ui.isGameView or not ui:isGameView() then
        ui.gameMoodLastTickMs = nil
        ui.lastPlayerGameOutcomeState = nil
        return
    end
    ui.gameMoodLastTickMs = ui.gameMoodLastTickMs or nowMs
    if nowMs - ui.gameMoodLastTickMs >= 1000 then
        ui.gameMoodLastTickMs = nowMs
        ui:adjustPlayerMood(-0.35, -0.0035, -0.25, playerObj)
    end
    local game = ui.getActiveGameInstance and ui:getActiveGameInstance() or nil
    local state = game and game.gameState or nil
    if state == "GAMEOVER" and ui.lastPlayerGameOutcomeState ~= "GAMEOVER" then
        ui:adjustPlayerMood(0, 0.08, 0, playerObj)
    end
    ui.lastPlayerGameOutcomeState = state
end


target.__index=target
function target:isVisible()return current and current.body==self.playerObj and owned(current)end
function target:isGameView()return true end
function target:getActiveGameInstance()return self.game end
return {new=function(body,game)return setmetatable({playerObj=body,game=game},target)end,
    update=function(ui)ComputerScreenUI.instance=ui;updateComputerGameMoodFromPlayer(ui.playerObj);ComputerScreenUI.instance=nil end}
end)()
-- END INSTALLED SOURCE ComputerMod_UI_State.mood
-- BEGIN INSTALLED SOURCE ComputerMod_GameInput.updateGridSelection
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

-- END INSTALLED SOURCE ComputerMod_GameInput.updateGridSelection
-- BEGIN INSTALLED SOURCE Lifestyle/LSPingPongBall
local LSPingPongBall=(function()
local LSPingPongBall=ISPanel:derive("SAONpcPingBall")
local driftDistance = 0.5

local function hash01(n)
	local x = math.sin(n * 12.9898) * 43758.5453
	return x - math.floor(x)
end

local function sourceSetShot(self,shot)
	if not shot then return; end
	self.fromX, self.fromY = shot.fromX, shot.fromY
	self.toX, self.toY = shot.toX, shot.toY
	self.bounceX, self.bounceY = shot.bounceX, shot.bounceY
	if shot.z then self.z = shot.z; end
	self.t = math.max(0, shot.t or 0)
	self.endT = shot.endT or 1
	self.hasBounce = shot.hasBounce or false
	self.bounceT = shot.bounceT or 0.6
	self.dropped = shot.dropped or false
	self.wild = shot.wild or false
	self.alpha = shot.alpha or 1
	local variant = shot.variant
	if variant and variant ~= self.variant then
		self.variant = variant
		self.arcMul = 0.7 + hash01(variant) * 0.6 -- arc h
		self.lateralMul = (hash01(variant + 91.7) - 0.5) * 2 -- sideway drift
	end
end

function LSPingPongBall:new(character, texture, scale, arcHeight, baseOffsetY)
	local o = ISPanel:new(0, 0, 0, 0)
	setmetatable(o, self)
	self.__index = self
	o.character = character
	-- NPC scene has no player camera/slot.
	o.texture = texture
	o.fromX, o.fromY, o.z = nil, nil, nil
	o.toX, o.toY = nil, nil
	o.bounceX, o.bounceY = nil, nil
	o.t = 0
	o.endT = 1
	o.hasBounce = false
	o.bounceT = 0.6
	o.arcMul = 1
	o.lateralMul = 0
	o.variant = nil
	o.dropped = false
	o.wild = false
	o.alpha = 1
	o.r, o.g, o.b = 1, 1, 1
	o.texW = (scale and scale[1]) or 16
	o.texH = (scale and scale[2]) or 16
	o.baseOffsetY = baseOffsetY or 48 -- lift the ball above the table/floor sprite, in pixels before zoom
	o.arcHeight = arcHeight or 24
	o.shouldClose = false
	o.name = nil
	o.backgroundColor = {r=0, g=0, b=0, a=0}
	o.borderColor = {r=0, g=0, b=0, a=0}
	o.width = 0
	o.height = 0
	o.anchorLeft = true
	o.anchorRight = true
	o.anchorTop = true
	o.anchorBottom = true
	return o
end

function LSPingPongBall:setShot(shot)
    if not current or not owned(current)then error("unbound-source-ping-shot")end
    sourceSetShot(self,shot)
    current.shot=plain(shot);current.work.nativeProgress.shots=(current.work.nativeProgress.shots or 0)+1
    current.work.nativeProgress.ballPosition=self:position()
end
function LSPingPongBall:position()
	local t = self.t
	local peakArc = self.arcHeight * (self.arcMul or 1)
	local wx, wy, arc

	if self.hasBounce and self.bounceX then
		if t <= self.bounceT then
			-- first bigger arc
			local seg = (self.bounceT > 0) and math.max(0, t / self.bounceT) or 0
			wx = self.fromX + (self.bounceX - self.fromX) * seg
			wy = self.fromY + (self.bounceY - self.fromY) * seg
			arc = math.sin(math.min(1, seg) * math.pi) * peakArc
		else
			-- second
			local span = math.max(0.001, self.endT - self.bounceT)
			local seg = (t - self.bounceT) / span
			wx = self.bounceX + (self.toX - self.bounceX) * seg
			wy = self.bounceY + (self.toY - self.bounceY) * seg
			arc = math.sin(math.max(0, math.min(1, seg)) * math.pi) * peakArc * 0.4
		end
	else
		local seg = math.max(0, math.min(1, t))
		wx = self.fromX + (self.toX - self.fromX) * seg
		wy = self.fromY + (self.toY - self.fromY) * seg
		arc = math.sin(seg * math.pi) * peakArc
	end

	if self.dropped then
		local dx, dy = self.toX - self.fromX, self.toY - self.fromY
		local dlen = math.sqrt(dx*dx + dy*dy)
		if dlen > 0 then
			local driftAmount = (1 - (self.alpha or 1)) * driftDistance
			wx = wx + (-dy/dlen) * (self.lateralMul or 0) * driftAmount
			wy = wy + (dx/dlen) * (self.lateralMul or 0) * driftAmount
		end
	end

	local overallT = math.max(0, math.min(1, (self.endT > 0) and (t / self.endT) or t))
	local lateral = (self.lateralMul or 0) * (self.wild and 26 or 10) * math.sin(overallT * math.pi)
	local flyDepthScale = 1 + (peakArc > 0 and (arc / peakArc) or 0) * 0.35
	local droppedness = self.dropped and (1 - (self.alpha or 1)) or 0
	arc = arc * (1 - droppedness)
	local depthScale = flyDepthScale + (0.55 - flyDepthScale) * droppedness

    return {x=wx,y=wy,z=self.z,arcPixels=arc,lateralPixels=lateral,depthScale=depthScale,alpha=self.alpha}
end
function LSPingPongBall:setVisible()end
function LSPingPongBall:addToUIManager()end
function LSPingPongBall:close()self.shouldClose=true end
return LSPingPongBall
end)()
-- END INSTALLED SOURCE Lifestyle/LSPingPongBall
-- BEGIN INSTALLED SOURCE Lifestyle/LSPingPong
local PingCore=(function()
local LSPingPong = ISBaseTimedAction:derive("LSPingPong")

local volleyTime = 8
local maxVolley_delta = 0.3
local edgeExtension = 0.9
local edgeSpan = 2 * edgeExtension + 1

local bounceFrac_min, bounceFrac_max = 0.55, 1.35
local fadeFrac_start = 0.6

local lateral_max = 0.4
local lateral_wild = 0.9

local overshootGoodOut = 0.3

local ballTex = "media/ui/tennisball.png"
local ballScale = 10

local bounce_sounds = {"Pong_BOUNCE1", "Pong_BOUNCE2", "Pong_BOUNCE3", "Pong_BOUNCE4", "Pong_BOUNCE5", "Pong_BOUNCE6"}
local hit_sounds = {"Pong_HIT1", "Pong_HIT2", "Pong_HIT3", "Pong_HIT4", "Pong_HIT5", "Pong_HIT6"}

local vol_min, vol_max = 0.85, 1.0
local pitch_min, pitch_max = 0.9, 1.1

local restTime_round = 6
local restTime_match = 12
local restTime_anticipation = 3

local paddleItem = "BadmintonRacket"

local function addNumbered(list, prefix, count)
	for n = 1, count do
		local suffix = (n < 10) and ("0"..tostring(n)) or tostring(n)
		table.insert(list, prefix..suffix)
	end
end

local negativeAnim_round = {
	"Bob_Converse_Angry01", "Bob_Converse_Angry02", "Bob_Converse_ShakeHeadNo",
	"Bob_Converse_Dismissive01", "Bob_Converse_Dismissive02",
}
local positiveAnim_round = {
	"Bob_Converse_Acknowledging", "Bob_Converse_AgreeingHandGesture", "Bob_Converse_Agreeing",
	"Bob_EmoteClap", "Bob_EmoteClap02", "Bob_EmoteThumbsUp",
}

local negativeAnim_match = {
	"Bob_ConverseEnd_Frustrated01", "Bob_ConverseEnd_Frustrated02",
	"Bob_ConverseEnd_Frustrated03", "Bob_ConverseEnd_Frustrated04", "Bob_EmoteInsult",
}
local positiveAnim_match = {
	"Bob_Applauding", "Bob_EmoteSalute_Casual", "Bob_EmoteWaveHi", "Bob_EmoteWaveHi02",
	"Bob_DancingChicken", "Bob_DancingClubSidestep", "Bob_DancingHandsInAir",
}

local idleAnim = "Bob_Aim1Hand"
local swingAnim_miss = "Bob_Swing1Hand01_Miss"

local swingAnims_hit = {
	"Bob_Swing1Hand01_CritHit", "Bob_Swing1Hand02_CritHit", "Bob_Swing1Hand03_CritHit",
	"Bob_Swing1Hand01_Hit", "Bob_Swing1Hand01_HitB", "Bob_Swing1Hand01_HitC",
	"Bob_Swing1Hand02_Hit", "Bob_Swing1Hand03_Hit",
}

local negativeVoice_round = {}
addNumbered(negativeVoice_round, "NoUHUH", 2)
addNumbered(negativeVoice_round, "Bored", 2)
addNumbered(negativeVoice_round, "ConfusedHUH", 4)
addNumbered(negativeVoice_round, "IndifferentHMM", 5)
local positiveVoice_round = {}
addNumbered(positiveVoice_round, "IntriguedHMM", 9)
addNumbered(positiveVoice_round, "LikeHMM", 3)
local negativeVoice_match = {}
addNumbered(negativeVoice_match, "ListenBlowOff", 3)
addNumbered(negativeVoice_match, "NegativeOOOU", 4)
local positiveVoice_match = {}
addNumbered(positiveVoice_match, "Woohoo", 3)
addNumbered(positiveVoice_match, "AgreeableUHU", 3)

local function playReaction(actionSelf, character, animList, voiceList)
	if not character then return; end
	if animList and #animList > 0 then
		actionSelf:setActionAnim(animList[LSUtil.rdm_inst:random(#animList)])
	end
	if voiceList and #voiceList > 0 and character.getEmitter then
		local prefix = character:isFemale() and "Woman" or "Man"
		character:getEmitter():playSound(prefix..voiceList[LSUtil.rdm_inst:random(#voiceList)])
	end
end

local function playSwingHit(actionSelf, character)
	local anim = swingAnims_hit[LSUtil.rdm_inst:random(#swingAnims_hit)]
	actionSelf:setActionAnim(anim)
	-- Source debug animation-name speech is retained as the real action animation.
end

local function playSwingMiss(actionSelf, character)
	actionSelf:setActionAnim(swingAnim_miss)
	-- Source debug animation-name speech is retained as the real action animation.
end

local function hash01(n)
	local x = math.sin(n * 12.9898) * 43758.5453
	return x - math.floor(x)
end

local function playRandomBallSound(character, soundList)
	if not character or not character.getEmitter then return; end
	local soundName = soundList[LSUtil.rdm_inst:random(#soundList)]
	local emitter = character:getEmitter()
	local sound = emitter:playSound(soundName)
	if not sound then return; end
	local volume = vol_min + LSUtil.rdm_inst:random() * (vol_max - vol_min)
	local pitch = pitch_min + LSUtil.rdm_inst:random() * (pitch_max - pitch_min)
	emitter:setVolume(sound, volume)
	emitter:setPitch(sound, pitch)
end

local function getMatchData(args)
	if type(args) == "table" and type(args[1]) == "table" and args[1].event then
		return args[1].event, args[1]
	end
	return nil, (type(args) == "table" and args[1]) or nil
end

local function scanSquareForSprite(s, spriteName)
	if not s or not spriteName then return nil; end
	local objs = s:getObjects()
	for i = 1, objs:size() do
		local o = objs:get(i-1)
		if o and LSUtil.getObjSpriteName(o) == spriteName then
			return o
		end
	end
	return nil
end

-- checks sqr itself then neighbors for an object with required spriteName
local function scanAroundForSprite(sqr, spriteName)
	if not sqr or not spriteName then return nil; end
	local found = scanSquareForSprite(sqr, spriteName)
	if found then return found; end
	for _, dirName in ipairs({"N", "S", "E", "W"}) do
		found = scanSquareForSprite(sqr:getAdjacentSquare(IsoDirections[dirName]), spriteName)
		if found then return found; end
	end
	return nil
end

local function findTableObj(character, spriteName)
	if not character then return nil; end
	return scanAroundForSprite(character:getSquare(), spriteName)
end

function LSPingPong:resolveTableObjs()
	if (self.matchObj and self.opponentObj) or not self.matchArgs then return; end
	local mySpriteName = self.source and self.matchArgs.sN or self.matchArgs.aSN or self.matchArgs.sN
	local otherSpriteName = self.source and self.matchArgs.aSN or self.matchArgs.sN
	if not self.matchObj and mySpriteName then self.matchObj = findTableObj(self.character, mySpriteName); end
	if not self.opponentObj and otherSpriteName and otherSpriteName ~= mySpriteName then
		self.opponentObj = self.matchObj and scanAroundForSprite(self.matchObj:getSquare(), otherSpriteName)
	end
end

function LSPingPong:computeEdges()
	if self.myEdgeX or not self.matchObj or not self.opponentObj then return; end
	local mx, my, mz = self.matchObj:getX(), self.matchObj:getY(), self.matchObj:getZ()
	local ox, oy = self.opponentObj:getX(), self.opponentObj:getY()
	local dx, dy = ox - mx, oy - my
	local dist = math.sqrt(dx*dx + dy*dy)
	local ux, uy = 0, 0
	if dist > 0 then ux, uy = dx/dist, dy/dist; end
	self.myCenterX, self.myCenterY, self.z = mx, my, mz
	self.oppCenterX, self.oppCenterY = ox, oy
	self.myEdgeX, self.myEdgeY = mx - ux*edgeExtension, my - uy*edgeExtension
	self.oppEdgeX, self.oppEdgeY = ox + ux*edgeExtension, oy + uy*edgeExtension
	self.perpX, self.perpY = -uy, ux
end

function LSPingPong:spawnBall()
	if not LSPingPongBall or not getTexture then return; end
	if not self.matchObj or not self.opponentObj then return; end
	local ok, overlay = pcall(function()
		return LSPingPongBall:new(self.character, getTexture(ballTex), {ballScale, ballScale})
	end)
	if not ok or not overlay then return; end
	self.overlay = overlay
	self:computeEdges()
	self.overlay:setShot({
		fromX = self.myEdgeX, fromY = self.myEdgeY,
		toX = self.oppEdgeX, toY = self.oppEdgeY,
		z = self.z, t = 0, endT = 1,
		variant = self.pointIdx * 10 + self.volleyIdx,
	})
	self.overlay:setVisible(true)
	self.overlay:addToUIManager()
end

function LSPingPong:releaseTable()
	if self.matchObj and self.matchObj.getModData and self.matchObj:getModData().movableData then
		self.matchObj:getModData().movableData.inUse = false
	end
end

function LSPingPong:resolvePoint()
	local pointDetails = self.matchData and self.matchData.points[self.pointIdx]
	if not pointDetails then
		self:forceComplete()
		return
	end

	local iWon = (pointDetails.winner == "source") == (self.source == true)

	if self.character.Say then
		--self.character:Say(iWon and "win!" or "lost!")
	end

	self.pointIdx = self.pointIdx + 1
	self.volleyIdx = 1
	self.volleyTimer = 0

	local isMatchPoint = self.pointIdx > #self.matchData.points
	self.resting = true
	self.restEndTimestamp = getTimestamp() + (isMatchPoint and restTime_match or restTime_round)
	self.restFinalize = isMatchPoint
	if isMatchPoint then
		playReaction(self, self.character, iWon and positiveAnim_match or negativeAnim_match, iWon and positiveVoice_match or negativeVoice_match)
	else
		playReaction(self, self.character, iWon and positiveAnim_round or negativeAnim_round, iWon and positiveVoice_round or negativeVoice_round)
	end
end

function LSPingPong:waitToStart()
	self.character:nullifyAiming()
	self.character:setX(self.character:getX())
	self.character:setY(self.character:getY())

	self:resolveTableObjs()

	if self.otherPlayer then
		self.character:faceLocation(self.otherPlayer:getX(), self.otherPlayer:getY())
		self.character:faceLocationF(self.otherPlayer:getX(), self.otherPlayer:getY())
	elseif self.opponentObj then -- fakeRival improv
		self.character:faceLocation(self.opponentObj:getX(), self.opponentObj:getY())
		self.character:faceLocationF(self.opponentObj:getX(), self.opponentObj:getY())
	end

	return self.character:shouldBeTurning()
end

function LSPingPong:isValid()
	return true
end

function LSPingPong:update()

	self.character:nullifyAiming()

	if self.character:getModData().LSInteractionState == "none" and self.otherPlayer then
		self:forceStop()
		return
	elseif (self.character:pressedMovement(true)) and (isKeyDown(Keyboard.KEY_LSHIFT)) then
		self:forceStop()
		return
	end

	if self.resting then
		if getTimestamp() < self.restEndTimestamp then
			return
		end
		self.resting = false
		if self.restFinalize then
			self:forceComplete()
			return
		end
		self.anticipating = true
		self.anticipationEndTimestamp = getTimestamp() + restTime_anticipation
		self:setActionAnim(idleAnim)
	end

	-- aim/ready anim
	if self.anticipating then
		if getTimestamp() < self.anticipationEndTimestamp then
			return
		end
		self.anticipating = false
	end

	if not self.matchData then return; end

	local pointDetails = self.matchData.points[self.pointIdx]
	if not pointDetails then
		self:forceComplete()
		return
	end

	local totalVolleys = pointDetails.volleys + 1
	local isFinalVolley = self.volleyIdx >= totalVolleys
	local myServe = (self.pointIdx % 2 == 1) == (self.source == true)
	local towardOpponent = (self.volleyIdx % 2 == 1) == myServe

	self.volleyTimer = self.volleyTimer + math.min(maxVolley_delta, getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
	self:computeEdges()

	if self.overlay and self.myEdgeX and self.oppEdgeX then
		local fromX, fromY = towardOpponent and self.myEdgeX or self.oppEdgeX, towardOpponent and self.myEdgeY or self.oppEdgeY
		local toX, toY = towardOpponent and self.oppEdgeX or self.myEdgeX, towardOpponent and self.oppEdgeY or self.myEdgeY
		local fromCenterX, fromCenterY = towardOpponent and self.myCenterX or self.oppCenterX, towardOpponent and self.myCenterY or self.oppCenterY
		local toCenterX, toCenterY = towardOpponent and self.oppCenterX or self.myCenterX, towardOpponent and self.oppCenterY or self.myCenterY
		local localT = math.min(1, self.volleyTimer / volleyTime)
		local variant = self.pointIdx * 10 + self.volleyIdx
		local frac = bounceFrac_min + hash01(variant + 17.3) * (bounceFrac_max - bounceFrac_min)
		local lateralOffset = (hash01(variant + 53.7) - 0.5) * 2 * lateral_max
		local bounceX = fromCenterX + (toCenterX - fromCenterX) * frac + self.perpX * lateralOffset
		local bounceY = fromCenterY + (toCenterY - fromCenterY) * frac + self.perpY * lateralOffset
		local bounceT = (edgeExtension + frac) / edgeSpan

		local shot = {
			fromX = fromX, fromY = fromY, toX = toX, toY = toY,
			bounceX = bounceX, bounceY = bounceY, bounceT = bounceT,
			z = self.z, variant = variant, alpha = 1,
		}
		if isFinalVolley and pointDetails.faultType == "net" then
			shot.endT, shot.hasBounce = 0.5, false
			local missT = math.min(1, localT / fadeFrac_start)
			shot.t = missT * shot.endT
			shot.dropped = (missT >= 1)
			shot.alpha = 1 - math.max(0, (localT - fadeFrac_start) / (1 - fadeFrac_start))
		elseif isFinalVolley and pointDetails.faultType == "badOut" then
			shot.endT, shot.hasBounce, shot.wild = 0.55, false, true
			local wildLateral = (hash01(variant + 71.3) - 0.5) * 2 * lateral_wild
			shot.toX = toX + self.perpX * wildLateral
			shot.toY = toY + self.perpY * wildLateral
			local missT = math.min(1, localT / fadeFrac_start)
			shot.t = missT * shot.endT
			shot.dropped = (missT >= 1)
			shot.alpha = 1 - math.max(0, (localT - fadeFrac_start) / (1 - fadeFrac_start))
		elseif isFinalVolley and pointDetails.faultType == "goodOut" then
			shot.endT, shot.hasBounce = 1 + overshootGoodOut / edgeSpan, true
			shot.t = localT * shot.endT
			shot.alpha = 1 - math.max(0, (localT - fadeFrac_start) / (1 - fadeFrac_start))
		else
			shot.endT, shot.hasBounce = 1, true
			shot.t = localT
		end
		self.overlay:setShot(shot)

		if shot.hasBounce and not self.bounceSoundPlayed and shot.t >= bounceT then
			self.bounceSoundPlayed = true
			playRandomBallSound(self.character, bounce_sounds)
		end
	end

	if self.volleyTimer >= volleyTime then
		self.volleyTimer = 0
		self.bounceSoundPlayed = false
		if isFinalVolley then
			if pointDetails.faultType == "goodOut" then
				if towardOpponent then
					playSwingHit(self, self.character)
				else
					playSwingMiss(self, self.character)
				end
			elseif towardOpponent then
				playSwingMiss(self, self.character)
			end
		else
			playRandomBallSound(self.character, hit_sounds)
			if not towardOpponent then
				playSwingHit(self, self.character)
			end
		end
		self.volleyIdx = self.volleyIdx + 1
		if self.volleyIdx > totalVolleys then
			self:resolvePoint()
		end
	end
end

function LSPingPong:start()

	if self.otherPlayer then
		self.character:getModData().LSInteractionState =
			(self.character:getModData().LSInteractionState == "sourceStoppedWaiting") and "none" or "doingAction"
	end

	self:setOverrideHandModels(paddleItem, nil)
	self.character:setBlockMovement(true)

	if not self.matchData then
		local pending = self.character:getModData().LSObjInteractionArgsPending
		self.character:getModData().LSObjInteractionArgsPending = false
		if pending then
			self.matchData = pending.event
			self.matchArgs = pending
		end
	end

	if not self.matchData or not self.matchData.points or #self.matchData.points == 0 then
		self:forceStop()
		return
	end

	self:resolveTableObjs()

	self.anticipating = true
	self.anticipationEndTimestamp = getTimestamp() + restTime_anticipation
	self:setActionAnim(idleAnim)
	self:spawnBall()
end

function LSPingPong:stop()

	self.character:setBlockMovement(false)
	self:setOverrideHandModels(nil, nil)
	self:releaseTable()

	if self.otherPlayer and self.character:getModData().LSInteractionState == "doingAction" then
		sendClientCommand(self.character, "LS", "StopOrStartInteraction", {self.otherPlayer:getOnlineID(), "none"})
	end
	self.character:getModData().LSInteractionState = "none"

	if self.overlay then self.overlay:close(); self.overlay = nil; end

	ISBaseTimedAction.stop(self);
end

function LSPingPong:perform()

	self.character:setBlockMovement(false)
	self.character:getModData().LSInteractionState = "none"
	self:setOverrideHandModels(nil, nil)
	self:releaseTable()

	if self.overlay then self.overlay:close(); self.overlay = nil; end

	if self.matchData and self.matchData.winner then
		-- maybe track plays for a hidden skill later
		--[[
		local iWon = (self.matchData.winner == "source") == (self.source == true)
		local charData = self.character:getModData()
		if iWon then
			charData.LSPingPongWins = (charData.LSPingPongWins or 0) + 1
		else
			charData.LSPingPongLosses = (charData.LSPingPongLosses or 0) + 1
		end
		]]--
	end

	ISBaseTimedAction.perform(self);
end

function LSPingPong:complete()
	return true
end

function LSPingPong:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 2000
end

function LSPingPong:new(character, otherPlayer, args)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.otherPlayer = otherPlayer
	o.args = args
	local matchData, matchArgs = getMatchData(args)
	o.matchData = matchData
	o.matchArgs = matchArgs
	o.matchObj = nil
	o.source = (type(args) == "table" and args[2]) and true or false
	o.stopOnAim = false
	o.stopOnWalk = false
	o.stopOnRun = true
	o.gameSound = 0
	o.maxTime = o:getDuration()
	o.ignoreDynamicTime = true
	o.useProgressBar = false
	o.pointIdx = 1
	o.volleyIdx = 1
	o.volleyTimer = 0
	o.bounceSoundPlayed = false
	o.resting = false
	o.restEndTimestamp = 0
	o.restFinalize = false
	o.anticipating = false
	o.anticipationEndTimestamp = 0
	o.myCenterX, o.myCenterY = nil, nil
	o.oppCenterX, o.oppCenterY = nil, nil
	o.myEdgeX, o.myEdgeY = nil, nil
	o.oppEdgeX, o.oppEdgeY = nil, nil
	o.perpX, o.perpY = nil, nil
	o.z = nil
	o.overlay = nil
	return o;
end

return LSPingPong

end)()
-- END INSTALLED SOURCE Lifestyle/LSPingPong
-- BEGIN INSTALLED SOURCE Lifestyle/LSMPS.pingRules
local MatchRules=(function()
local LSMPS={}
LSMPS.getPingPongForm = function(character)
	if not character then return 0.4; end -- neutral fallback
	local skill = (character:getPerkLevel(Perks.Fitness) + character:getPerkLevel(Perks.Nimble)) / 2
	local stress = LSUtil.getCharacterMood(character, "Stress") or 0
	local boredom = (LSUtil.getCharacterMood(character, "Boredom") or 0) / 100
	local unhappiness = (LSUtil.getCharacterMood(character, "Unhappiness") or 0) / 100
	local mood = 1 - ((stress + boredom + unhappiness) / 3)
	local luck = ZombRandFloat(0, 1)
	--if CharacterTrait.LUCKY and character:hasTrait(CharacterTrait.LUCKY) then luck = math.min(1, luck + 0.15); end
	--if CharacterTrait.UNLUCKY and character:hasTrait(CharacterTrait.UNLUCKY) then luck = math.max(0, luck - 0.15); end
	return (skill/10)*0.4 + math.max(0, mood)*0.3 + luck*0.3
end

LSMPS.rollPointDetails = function(winner)
	local roll = ZombRandFloat(0, 1)
	local faultType
	if roll < 0.15 then
		faultType = "net"
	elseif roll < 0.3 then
		faultType = "badOut"
	else
		faultType = "goodOut"
	end
	return {
		winner = winner,
		faultType = faultType,
		volleys = ZombRand(3, 7),
	}
end

LSMPS.resolvePingPongMatch = function(formSource, formOther)
	formSource = formSource or 0.4
	formOther = formOther or 0.4
	local pSource = formSource / math.max(0.01, (formSource + formOther))
	local points = {}
	local scoreSource, scoreOther = 0, 0
	while scoreSource < 5 and scoreOther < 5 do
		local winner = (ZombRandFloat(0, 1) < pSource) and "source" or "other"
		if winner == "source" then scoreSource = scoreSource + 1 else scoreOther = scoreOther + 1 end
		table.insert(points, LSMPS.rollPointDetails(winner))
	end
	return {
		points = points,
		scoreSource = scoreSource,
		scoreOther = scoreOther,
		winner = (scoreSource > scoreOther) and "source" or "other",
	}
end


return LSMPS
end)()
-- END INSTALLED SOURCE Lifestyle/LSMPS.pingRules
-- BEGIN INSTALLED SOURCE ProjectArcade/currency
local ProjectArcade_Currency=(function()
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"

local ProjectArcade_Currency = {}
ProjectArcade_Currency.PendingPays = ProjectArcade_Currency.PendingPays or {}

local function safeGetText(key, ...)
    if getText then
        local ok, txt = pcall(getText, key, ...)
        if ok and txt and txt ~= key then return txt end
    end
    return key
end



-- =========================
-- Utils: recursive item search (supports wallets/bags)
-- =========================
local function findItemRecursive(container, fullType)
    if not container or not fullType then return nil, nil end

    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it:getFullType() == fullType then
            return container, it
        end

        if it and it.IsInventoryContainer and it:IsInventoryContainer() then
            local inner = it:getInventory()
            if inner then
                local c, innerIt = findItemRecursive(inner, fullType)
                if c and innerIt then return c, innerIt end
            end
        end
    end

    return nil, nil
end

ProjectArcade_Currency.Config = {
    Cost = 1,
    CurrencyFullType = "Base.SilverCoin",
    DebugFreePlay = false,
    NoCoinText = "ContextMenu_ProjectArcade_NotEnoughCoins",
}

-- =========================
-- Sandbox config
-- =========================
function ProjectArcade_Currency.ApplySandboxConfig()
    local ft = SandboxVars and SandboxVars.ProjectArcade and SandboxVars.ProjectArcade.CurrencyFullType
    if type(ft) == "string" then
        ft = ft:gsub("^\\s+", ""):gsub("\\s+$", "")
        if ft ~= "" then
            local sm = getScriptManager and getScriptManager()
            if sm and sm.FindItem and sm:FindItem(ft) then
                ProjectArcade_Currency.Config.CurrencyFullType = ft
            else
                print("[ProjectArcade] WARNING: Invalid CurrencyFullType in sandbox: " .. tostring(ft) .. " (fallback to Base.SilverCoin)")
                ProjectArcade_Currency.Config.CurrencyFullType = "Base.SilverCoin"
            end
        end
    end
end

local function PA_Currency_ApplySandboxOnStart()
    pcall(ProjectArcade_Currency.ApplySandboxConfig)
end

-- Original player/server event registration remains with the installed owner.



ProjectArcade_Currency.CheckAndQueueAction = ISBaseTimedAction:derive("ProjectArcade_Currency_CheckAndQueueAction")

function ProjectArcade_Currency.CheckAndQueueAction:isValid()
    return true
end

function ProjectArcade_Currency.CheckAndQueueAction:perform()
    -- FreePlay: no cobramos nada, encolamos directo.
    if self.debugFreePlay then
        if self.queueFn then self.queueFn() end
        ISBaseTimedAction.perform(self)
        return
    end

    -- MP CLIENT: el server cobra y responde. Acá solo pedimos el cobro.
    if isClient() and not isServer() then
        local nonce = tostring((getTimestampMs and getTimestampMs()) or 0) .. "-" .. tostring(ZombRand(1000000))

        ProjectArcade_Currency.PendingPays[nonce] = {
            character = self.character,
            cost = self.cost,
            currencyFullType = self.currencyFullType,
            noCoinText = self.noCoinText,
            queueFn = self.queueFn,
        }

        sendClientCommand(self.character, "ProjectArcade", "PayCoins", {
            nonce = nonce,
            cost = self.cost,
            currencyFullType = self.currencyFullType,
        })

        ISBaseTimedAction.perform(self)
        return
    end

    -- SP / Host / Server: cobramos local (está bien porque acá sí es autoridad)
    local inv = self.character and self.character:getInventory()
    local have = inv and inv:getCountTypeRecurse(self.currencyFullType) >= self.cost

    if have then
        for i = 1, self.cost do
            local c, coin = findItemRecursive(inv, self.currencyFullType)
            if not coin then
                have = false
                break
            end
            c:Remove(coin)
            if isServer() then
                sendRemoveItemFromContainer(c, coin)
            end
        end
    end

    if have then
        if self.queueFn then self.queueFn() end
    else
        if self.character and self.character.Say then
            local k = self.noCoinText or ProjectArcade_Currency.Config.NoCoinText
            self.character:Say(safeGetText(k))
        end
    end

    ISBaseTimedAction.perform(self)
end

function ProjectArcade_Currency.CheckAndQueueAction:new(character, cost, currencyFullType, debugFreePlay, noCoinText, queueFn)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = 0
    o.useProgressBar = false

    o.cost = cost or ProjectArcade_Currency.Config.Cost
    o.currencyFullType = currencyFullType or ProjectArcade_Currency.Config.CurrencyFullType
    o.debugFreePlay = (debugFreePlay == true)
    o.noCoinText = noCoinText or ProjectArcade_Currency.Config.NoCoinText
    o.queueFn = queueFn

    return o
end

local function onServerCommand(module, command, args)
    if module ~= "ProjectArcade" then return end
    if command ~= "PayCoinsResult" then return end

    local nonce = args and args.nonce
    if not nonce then return end

    local pending = ProjectArcade_Currency.PendingPays and ProjectArcade_Currency.PendingPays[nonce]
    if not pending then return end

    ProjectArcade_Currency.PendingPays[nonce] = nil

    local character = pending.character
    if not character then return end

    if args and args.ok == true then
        if pending.queueFn then
            pending.queueFn()
        end
    else
        if character and character.Say then
            local k = pending.noCoinText or ProjectArcade_Currency.Config.NoCoinText
            character:Say(safeGetText(k))
        end
    end
end

-- Original player/server event registration remains with the installed owner.

PA_Currency_ApplySandboxOnStart()
return ProjectArcade_Currency
end)()
-- END INSTALLED SOURCE ProjectArcade/currency
-- BEGIN INSTALLED SOURCE ProjectArcade/play
local ArcadeSource=(function()
require "TimedActions/ISBaseTimedAction"
require "ProjectArcade_Currency"

local function safeGetText(key, ...)
    if getText then
        local ok, txt = pcall(getText, key, ...)
        if ok and txt and txt ~= key then return txt end
    end
    return key
end

local function tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

local function getArcadeMachineType(spriteName)
    local arcadeMachineSprites = {
        ArcadeMachine1 = { "recreational_01_16","recreational_01_17","recreational_01_18","recreational_01_19" },
        ArcadeMachine2 = { "recreational_01_20","recreational_01_21","recreational_01_22","recreational_01_23" },

        ArcadeStreetFighter = { "pa_arcades_0","pa_arcades_1","pa_arcades_2","pa_arcades_3" },
        ArcadePacman        = { "pa_arcades_4","pa_arcades_5","pa_arcades_6","pa_arcades_7" },
        ArcadeDoubleDragon  = { "pa_arcades_8","pa_arcades_9","pa_arcades_10","pa_arcades_11" },
        ArcadeSpaceInvaders = { "pa_arcades_12","pa_arcades_13","pa_arcades_14","pa_arcades_15" },
		ArcadeDonkeyKong = { "pa_arcades_16","pa_arcades_17","pa_arcades_18","pa_arcades_19", },
        ArcadeCentipede   = { "pa_arcades_20","pa_arcades_21","pa_arcades_22","pa_arcades_23" },
        ArcadeDigDug      = { "pa_arcades_24","pa_arcades_25","pa_arcades_26","pa_arcades_27" },
        ArcadeNBAJam     = { "pa_arcades_28","pa_arcades_29","pa_arcades_30","pa_arcades_31" },
        ArcadeTMNT       = { "pa_arcades_32","pa_arcades_33","pa_arcades_34","pa_arcades_35" },
        ArcadeMK         = { "pa_arcades_36","pa_arcades_37","pa_arcades_38","pa_arcades_39" },

        ComplexTerminator2 = { "pa_complex_0", "pa_complex_1" },
		ComplexStarWars = {
            "pa_complex_2", "pa_complex_3",
            "pa_complex_4", "pa_complex_5",
            "pa_complex_6", "pa_complex_7",
            "pa_complex_8", "pa_complex_9"
        },

        PinballMachine = { "recreational_01_24","recreational_01_27" },

        PinballAddamsFamily = { "pa_pinballs_0", "pa_pinballs_3" },
        PinballTwilightZone = { "pa_pinballs_4", "pa_pinballs_7" },
        PinballIndianaJones = { "pa_pinballs_8", "pa_pinballs_11" },
        PinballBlackKnight2000 = { "pa_pinballs_12", "pa_pinballs_15" },
        PinballFunHouse        = { "pa_pinballs_16", "pa_pinballs_19" },
        PinballElviraPartyMonsters = { "pa_pinballs_20", "pa_pinballs_23" },
        PinballMarioBros = { "pa_pinballs_24", "pa_pinballs_27" },
    }

    for machineType, sprites in pairs(arcadeMachineSprites) do
        for _, s in ipairs(sprites) do
            if s == spriteName then
                return machineType
            end
        end
    end
    return nil
end

local function getFrontTileForRecreational(square, spriteName)
    if not square or not spriteName then return nil end

        if tableContains({ "recreational_01_16", "recreational_01_20", "recreational_01_24" }, spriteName) then
        return square:getS()
    elseif tableContains({ "recreational_01_17", "recreational_01_21", "recreational_01_27" }, spriteName) then
        return square:getE()
    elseif tableContains({ "recreational_01_19", "recreational_01_23" }, spriteName) then
        return square:getN()
    elseif tableContains({ "recreational_01_18", "recreational_01_22" }, spriteName) then
        return square:getW()
    end

    if tableContains({ "pa_arcades_0","pa_arcades_4","pa_arcades_8","pa_arcades_12","pa_arcades_16","pa_arcades_20","pa_arcades_24","pa_arcades_28","pa_arcades_32","pa_arcades_36" }, spriteName) then
        return square:getS()
    elseif tableContains({ "pa_arcades_1","pa_arcades_5","pa_arcades_9","pa_arcades_13","pa_arcades_17","pa_arcades_21","pa_arcades_25","pa_arcades_29","pa_arcades_33","pa_arcades_37" }, spriteName) then
        return square:getE()
    elseif tableContains({ "pa_arcades_2","pa_arcades_6","pa_arcades_10","pa_arcades_14","pa_arcades_18","pa_arcades_22","pa_arcades_26","pa_arcades_30","pa_arcades_34","pa_arcades_38" }, spriteName) then
        return square:getW()
    elseif tableContains({ "pa_arcades_3","pa_arcades_7","pa_arcades_11","pa_arcades_15","pa_arcades_19","pa_arcades_23","pa_arcades_27","pa_arcades_31","pa_arcades_35","pa_arcades_39" }, spriteName) then
        return square:getN()
	end
	
    if tableContains({ "pa_complex_0" }, spriteName) then
        return square:getS()
    elseif tableContains({ "pa_complex_1" }, spriteName) then
        return square:getE()
    end
		
    if tableContains({ "pa_pinballs_0", "pa_pinballs_4", "pa_pinballs_8", "pa_pinballs_12", "pa_pinballs_16", "pa_pinballs_20", "pa_pinballs_24" }, spriteName) then
        return square:getS()
    elseif tableContains({ "pa_pinballs_3", "pa_pinballs_7", "pa_pinballs_11", "pa_pinballs_15", "pa_pinballs_19", "pa_pinballs_23", "pa_pinballs_27" }, spriteName) then
        return square:getE()
    end

    return nil
end

local function getComplexStarWarsTailSprite(spriteName)
    if not spriteName then return nil end

    -- Solo cola, no frente
    if spriteName == "pa_complex_4" then
        return "pa_complex_4"
    end

    if spriteName == "pa_complex_3" then
        return "pa_complex_3"
    end

    if spriteName == "pa_complex_6" then
        return "pa_complex_6"
    end

    if spriteName == "pa_complex_9" then
        return "pa_complex_9"
    end

    return nil
end

local function getComplexStarWarsInteractionTile(square, spriteName)
    if not square or not spriteName then return nil end

    local tailSprite = getComplexStarWarsTailSprite(spriteName)
    if not tailSprite then return nil end

    -- S = cola pa_complex_4 -> entrar por el ESTE
    if tailSprite == "pa_complex_4" then
        return square:getE()
    end

    -- E = cola pa_complex_3 -> entrar por el NORTE
    if tailSprite == "pa_complex_3" then
        return square:getN()
    end

    -- W = cola pa_complex_6 -> entrar por el SUR
    if tailSprite == "pa_complex_6" then
        return square:getS()
    end

    -- N = cola pa_complex_9 -> entrar por el OESTE
    if tailSprite == "pa_complex_9" then
        return square:getW()
    end

    return nil
end

local function getInteractionTileForRecreational(square, spriteName, machineType)
    if not square or not spriteName then return nil end

    if machineType == "ComplexStarWars" then
        return getComplexStarWarsInteractionTile(square, spriteName)
    end

    return getFrontTileForRecreational(square, spriteName)
end

local PA_MACHINE_CONFIG = {     -- Animaciones
    ArcadeStreetFighter = { actionAnim = "PlayArcadeSF2" },
    ArcadePacman        = { actionAnim = "PlayArcadePac" },
    ArcadeDoubleDragon  = { actionAnim = "PlayArcadeDD" },
    ArcadeSpaceInvaders = { actionAnim = "PlayArcadeSI" },
    ArcadeDonkeyKong    = { actionAnim = "PlayArcadeDK" },
    ArcadeCentipede    = { actionAnim = "PlayArcadeCen", loopSound = "PAcenplay", endSound = "PAcenend" },
    ArcadeDigDug       = { actionAnim = "PlayArcadeDig", loopSound = "PAdigplay", endSound = "PAdigend" },
    ArcadeNBAJam       = { actionAnim = "PlayArcade4P", loopSound = "PAnbaplay", endSound = "PAnbaend" },
    ArcadeTMNT         = { actionAnim = "PlayArcade4P", loopSound = "PAtmntplay", endSound = "PAtmntend" },
    ArcadeMK           = { actionAnim = "PlayArcade4P", loopSound = "PAmkplay", endSound = "PAmkend" },
	
    ArcadeMachine1      = { actionAnim = "PlayArcade" },
    ArcadeMachine2      = { actionAnim = "PlayArcade" },

    PinballMachine      = { actionAnim = "PlayPinball" },
    PinballAddamsFamily = { actionAnim = "PlayPinball" },
    PinballTwilightZone = { actionAnim = "PlayPinball" },
    PinballIndianaJones = { actionAnim = "PlayPinball" },
    PinballBlackKnight2000 = { actionAnim = "PlayPinball" },
    PinballFunHouse        = { actionAnim = "PlayPinball" },
    PinballElviraPartyMonsters = { actionAnim = "PlayPinball" },
	PinballMarioBros       = { actionAnim = "PlayPinball" },

    ComplexTerminator2  = { actionAnim = "PlayComplex", loopSound = "PAt2play", endSound = "PAt2end" },
    ComplexStarWars    = { actionAnim = "PlayComplexSW", loopSound = "PAswplay", endSound = "PAswend" },
}

local function PA_MakeSoundKeyFromObject(obj)
    if not obj or not obj.getSquare then return "nil" end
    local sq = obj:getSquare()
    if not sq then return "nil" end
    return tostring(sq:getX()) .. ":" .. tostring(sq:getY()) .. ":" .. tostring(sq:getZ())
end

local function PA_SendWorldSoundStart(self, soundName)
    if not isClient() then return end
    if not self or not self.object or not soundName then return end
    local sq = self.object:getSquare()
    if not sq then return end

    sendClientCommand("ProjectArcade", "WorldSoundStart", {
        key = PA_MakeSoundKeyFromObject(self.object),
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ(),
        sound = soundName,
    })
end

local function PA_SendWorldSoundStop(self)
    if not isClient() then return end
    if not self or not self.object then return end
    local sq = self.object:getSquare()
    if not sq then return end

    sendClientCommand("ProjectArcade", "WorldSoundStop", {
        key = PA_MakeSoundKeyFromObject(self.object),
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ(),
    })
end

local function PA_SendWorldSoundOneShot(self, soundName)
    if not isClient() then return end
    if not self or not self.object or not soundName then return end
    local sq = self.object:getSquare()
    if not sq then return end

    sendClientCommand("ProjectArcade", "WorldSoundOneShot", {
        key = PA_MakeSoundKeyFromObject(self.object),
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ(),
        sound = soundName,
    })
end

local function PA_GetMachineConfig(machineType)
    return (machineType and PA_MACHINE_CONFIG[machineType]) or nil
end

local function getPlayLoopSound(machineType)
    if machineType == "ArcadeStreetFighter" then return "PAMsfplay" end
    if machineType == "ArcadePacman" then return "PAMpacplay" end
    if machineType == "ArcadeDoubleDragon" then return "PAddplay" end
    if machineType == "ArcadeSpaceInvaders" then return "PAsiplay" end
	if machineType == "ArcadeDonkeyKong" then return "PAdkplay" end
    if machineType == "ArcadeMachine2" then return "PAMdroidsplay" end
    if machineType == "ArcadeNBAJam" then return "PAnbaplay" end
    if machineType == "ArcadeTMNT" then return "PAtmntplay" end
    if machineType == "ArcadeMK" then return "PAmkplay" end
	
    if machineType == "ComplexTerminator2" then return "PAt2play" end
    if machineType == "ComplexStarWars" then return "PAswplay" end

    if machineType == "PinballMachine" then return "PAMpinballplay" end
    if machineType == "PinballAddamsFamily" then return "PAafplay" end
    if machineType == "PinballTwilightZone" then return "PAtzplay" end
    if machineType == "PinballIndianaJones" then return "PAijplay" end
    if machineType == "PinballBlackKnight2000" then return "PAbk2000play" end
    if machineType == "PinballFunHouse"        then return "PAfhplay" end
    if machineType == "PinballElviraPartyMonsters" then return "PAetpmplay" end
    if machineType == "PinballMarioBros" then return "PAmbplay" end

    return "PAMkaboomplay"
end

local function getEndSound(machineType)
    if machineType == "ArcadeStreetFighter" then return "PAMsfend" end
    if machineType == "ArcadePacman" then return "PAMpacend" end
	if machineType == "ArcadeDoubleDragon" then return "PAddend" end
	if machineType == "ArcadeSpaceInvaders" then return "PAsiend" end
	if machineType == "ArcadeDonkeyKong" then return "PAdkend" end
	if machineType == "ArcadeMachine2" then return "PAMdroidsend" end
    if machineType == "ArcadeNBAJam" then return "PAnbaend" end
    if machineType == "ArcadeTMNT" then return "PAtmntend" end
    if machineType == "ArcadeMK" then return "PAmkend" end
	
    if machineType == "ComplexTerminator2" then return "PAt2end" end
	if machineType == "ComplexStarWars" then return "PAswend" end

    if machineType == "PinballMachine" then return "PAMpinballend" end
    if machineType == "PinballAddamsFamily" then return "PAafend" end
    if machineType == "PinballTwilightZone" then return "PAtzend" end
    if machineType == "PinballIndianaJones" then return "PAijend" end
    if machineType == "PinballBlackKnight2000" then return "PAbk2000end" end
    if machineType == "PinballFunHouse"        then return "PAfhend" end
    if machineType == "PinballElviraPartyMonsters" then return "PAetpmend" end
    if machineType == "PinballMarioBros" then return "PAmbend" end
	
    return "PAMkaboomend"
end

local function getLoopDurationMs(soundName)
    local policy = require "ProjectArcade_SoundPolicy"
    return policy.getLoopDurationMs(soundName)
end


local function applyMoodChanges_B42Safe(character, boredomDecrease, unhappinessDecrease, stressDecrease)
    local stats = character:getStats()

    if CharacterStat and stats and stats.get and stats.set then
        local curBoredom = stats:get(CharacterStat.BOREDOM)
        local curUnhappy = stats:get(CharacterStat.UNHAPPINESS)
        local curStress  = stats:get(CharacterStat.STRESS)

        stats:set(CharacterStat.BOREDOM, math.max(0, curBoredom - boredomDecrease))
        stats:set(CharacterStat.UNHAPPINESS, math.max(0, curUnhappy - unhappinessDecrease))
        stats:set(CharacterStat.STRESS, math.max(0, curStress - stressDecrease))
        return
    end

    local bd = character:getBodyDamage()
    if bd then
        if bd.getBoredomLevel and bd.setBoredomLevel then
            bd:setBoredomLevel(math.max(0, bd:getBoredomLevel() - boredomDecrease))
        end
        if bd.getUnhappinessLevel and bd.setUnhappinessLevel then
            bd:setUnhappinessLevel(math.max(0, bd:getUnhappinessLevel() - unhappinessDecrease))
        end
    end
    if stats and stats.getStress and stats.setStress then
        stats:setStress(math.max(0, stats:getStress() - stressDecrease))
    end
end

local function PA_SendMoodDeltaToServer(self, boredomDec, unhappyDec, stressDec)
    if not self or not self.character then return end

    if not isClient() then
        applyMoodChanges_B42Safe(self.character, boredomDec, unhappyDec, stressDec)
        return
    end

    local nowMs = (getTimestampMs and getTimestampMs()) or nil
    if not nowMs then
        sendClientCommand(self.character, "ProjectArcade", "ApplyMoodDelta", {
            boredom = boredomDec,
            unhappiness = unhappyDec,
            stress = stressDec
        })
        return
    end

    self._PA_moodAccB = (self._PA_moodAccB or 0) + (boredomDec or 0)
    self._PA_moodAccU = (self._PA_moodAccU or 0) + (unhappyDec or 0)
    self._PA_moodAccS = (self._PA_moodAccS or 0) + (stressDec or 0)

    if not self._PA_nextMoodSendMs then
        self._PA_nextMoodSendMs = nowMs + 1000
        return
    end

    if nowMs < self._PA_nextMoodSendMs then return end
    self._PA_nextMoodSendMs = nowMs + 1000

    sendClientCommand(self.character, "ProjectArcade", "ApplyMoodDelta", {
        boredom = self._PA_moodAccB,
        unhappiness = self._PA_moodAccU,
        stress = self._PA_moodAccS
    })

    self._PA_moodAccB = 0
    self._PA_moodAccU = 0
    self._PA_moodAccS = 0
end


local function PA_GetSfxVolMult()
    local pct = 100
    if SandboxVars and SandboxVars.ProjectArcade and SandboxVars.ProjectArcade.SfxVolumePct ~= nil then
        pct = tonumber(SandboxVars.ProjectArcade.SfxVolumePct) or 100
    end
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end
    return pct / 100.0
end

local function PA_PlayGameSound(self, soundName)
    if not soundName then return end

    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if not snd then return end

    if not self.emitter then
        self.emitter = IsoWorld.instance:getFreeEmitter()
    end

    local sq = self.object and self.object:getSquare() or nil
    if not sq then return end
    self.emitter:setPos(sq:getX(), sq:getY(), sq:getZ())

    local nowMs = (getTimestampMs and getTimestampMs()) or nil
    local shouldRestart = (not self.soundId or self.soundId == 0)

    if nowMs then
        if not self.nextLoopAtMs then self.nextLoopAtMs = 0 end
        if self.nextLoopAtMs ~= 0 and nowMs >= self.nextLoopAtMs then
            shouldRestart = true
        end
    end

    if shouldRestart then
        if self.soundId and self.soundId ~= 0 then
            self.emitter:stopSound(self.soundId)
            self.soundId = nil
        end

        local clip = snd:getRandomClip()
        if not clip then return end

        self.soundId = self.emitter:playClip(clip, nil)
        if self.soundId and self.soundId ~= 0 then
            -- Respeta volumen del script:
            local clipVol = (clip.getVolume and clip:getVolume()) or 1.0
            self.emitter:setVolume(self.soundId, clipVol * PA_GetSfxVolMult())
            self.emitter:set3D(self.soundId, true)

            if nowMs then
                local dur = getLoopDurationMs(soundName) or 60000
                self.nextLoopAtMs = nowMs + dur - 200
            end
        end
    end

    self.emitter:tick()
end

local function PA_StopGameSound(self)
    if self.emitter and self.soundId and self.soundId ~= 0 then
        self.emitter:stopSound(self.soundId)
        self.emitter:tick()
    end
    self.soundId = nil
    self.nextLoopAtMs = 0
end

local function PA_PlayOneShotAtCharacter(character, soundName)
    if not soundName then return end

    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if not snd then return end

    local clip = snd:getRandomClip()
    if not clip then return end

    local e = IsoWorld.instance:getFreeEmitter()
    if not e then return end

    e:setPos(character:getX(), character:getY(), character:getZ())

    local id = e:playClip(clip, nil)
    if id and id ~= 0 then
        local clipVol = (clip.getVolume and clip:getVolume()) or 1.0
        local mult = (PA_GetSfxVolMult and PA_GetSfxVolMult()) or 1.0
        e:setVolume(id, clipVol * mult)
        e:set3D(id, true)
        e:tick()
    end
end


local function PA_PlayOneShotAtMachine(self, soundName)
    if not soundName then return end

    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if not snd then return end

    local sq = self.object and self.object:getSquare() or nil
    if not sq then return end

    local clip = snd:getRandomClip()
    if not clip then return end

    local e = IsoWorld.instance:getFreeEmitter()
    if not e then return end

    e:setPos(sq:getX(), sq:getY(), sq:getZ())

    local id = e:playClip(clip, nil)
    if id and id ~= 0 then
        local clipVol = (clip.getVolume and clip:getVolume()) or 1.0
        local mult = (PA_GetSfxVolMult and PA_GetSfxVolMult()) or 1.0
        e:setVolume(id, clipVol * mult)
        e:set3D(id, true)
        e:tick()
    end
end


local PA_MOOD_TICK_MS = 12000 
local function PA_HaloArrow(character, translationKey, isPositive, r, g, b)
    if not character then return end
    if not (HaloTextHelper and HaloTextHelper.addTextWithArrow) then return end

    local text = getText(translationKey) or translationKey
    HaloTextHelper.addTextWithArrow(character, text, isPositive, r or 200, g or 255, b or 200)
end

local function PA_QueueHalo(self, translationKey, isPositive, r, g, b, delayMs)
    if not self then return end
    if not self.haloQueue then self.haloQueue = {} end

    local nowMs = (getTimestampMs and getTimestampMs()) or 0
    table.insert(self.haloQueue, {
        at = nowMs + (delayMs or 0),
        key = translationKey,
        pos = isPositive,
        r = r, g = g, b = b
    })
end

local function PA_TickHaloQueue(self)
    if not self or not self.haloQueue or #self.haloQueue == 0 then return end
    local nowMs = (getTimestampMs and getTimestampMs()) or nil
    if not nowMs then return end

        for i = #self.haloQueue, 1, -1 do
        local msg = self.haloQueue[i]
        if nowMs >= msg.at then
            PA_HaloArrow(self.character, msg.key, msg.pos, msg.r, msg.g, msg.b)
            table.remove(self.haloQueue, i)
        end
    end
end

local function PA_MoodTick(self, boredomDec, unhappyDec, stressDec)
    if not self or not self.character then return end

        local nowMs = (getTimestampMs and getTimestampMs()) or nil
    if not nowMs then return end

	if not self.nextMoodHaloAtMs then
		self.nextMoodHaloAtMs = nowMs + 2000 		return
	end

    if nowMs < self.nextMoodHaloAtMs then return end
    self.nextMoodHaloAtMs = nowMs + PA_MOOD_TICK_MS

	local d = 0
	if boredomDec and boredomDec > 0 then
		PA_QueueHalo(self, "ContextMenu_ProjectArcade_Mood_BoredomDown", true, 200, 255, 200, d)
		d = d + 300
	end
	if unhappyDec and unhappyDec > 0 then
		PA_QueueHalo(self, "ContextMenu_ProjectArcade_Mood_UnhappinessDown", true, 200, 255, 200, d)
		d = d + 300
	end
	if stressDec and stressDec > 0 then
		PA_QueueHalo(self, "ContextMenu_ProjectArcade_Mood_StressDown", true, 200, 255, 200, d)
		d = d + 300
	end

end

-- =========================================================
-- Arcade "Screen ON" overlay (B42 safe) - uses attached anim sprites
-- Based on Open All Containers overlay technique
-- =========================================================

local PA_ARCADE_SCREEN_OVERLAYS = {
    ["pa_arcades_0"]  = "pa_arcades_overlay_0",
    ["pa_arcades_1"]  = "pa_arcades_overlay_1",
    ["pa_arcades_4"]  = "pa_arcades_overlay_4",
    ["pa_arcades_5"]  = "pa_arcades_overlay_5",
    ["pa_arcades_8"]  = "pa_arcades_overlay_8",
    ["pa_arcades_9"]  = "pa_arcades_overlay_9",
    ["pa_arcades_12"] = "pa_arcades_overlay_12",
    ["pa_arcades_13"] = "pa_arcades_overlay_13",
	["pa_arcades_16"] = "pa_arcades_overlay_16",
	["pa_arcades_17"] = "pa_arcades_overlay_17",
	["pa_arcades_20"] = "pa_arcades_overlay_20",
	["pa_arcades_21"] = "pa_arcades_overlay_21",
	["pa_arcades_24"] = "pa_arcades_overlay_24",
	["pa_arcades_25"] = "pa_arcades_overlay_25",
	["pa_arcades_28"] = "pa_arcades_overlay_28",
	["pa_arcades_29"] = "pa_arcades_overlay_29",
	["pa_arcades_32"] = "pa_arcades_overlay_32",
	["pa_arcades_33"] = "pa_arcades_overlay_33",
	["pa_arcades_36"] = "pa_arcades_overlay_36",
	["pa_arcades_37"] = "pa_arcades_overlay_37",
	
    ["pa_complex_0"] = "pa_complex_overlay_0",
    ["pa_complex_1"] = "pa_complex_overlay_1",
	["pa_complex_3"] = "pa_complex_overlay_3",
    ["pa_complex_4"] = "pa_complex_overlay_4",
}

local function PA_GetOverlayForSprite(spriteName)
    if not spriteName then return nil end
    return PA_ARCADE_SCREEN_OVERLAYS[spriteName]
end

local PA_MD_KEY_ORIG_OVERLAY = "PA_originalTileOverlay"
local PA_MD_KEY_IS_ON = "PA_arcadeScreenOn"

local function PA_SaveAndRemoveAnyTileOverlay(obj)
    if not obj then return end
    local modData = obj:getModData()
    if modData[PA_MD_KEY_ORIG_OVERLAY] then
        return -- ya lo guardamos antes
    end

    local saved = nil

    local childSprites = obj:getChildSprites()
    local overlaySprite = obj:getOverlaySprite()
    local hasAnim = obj:hasAttachedAnimSprites()

    if childSprites and childSprites:size() > 0 then
        local firstChild = childSprites:get(0)
        if firstChild and firstChild:getName() then saved = firstChild:getName() end
        obj:setChildSprites(nil)

    elseif overlaySprite then
        saved = overlaySprite:getName()
        obj:setOverlaySprite(nil)

    elseif hasAnim then
        local animSprite = obj:getAttachedAnimSprite()
        if animSprite and animSprite:getName() then saved = animSprite:getName() end
        obj:setAttachedAnimSprite(nil)
    end

    if saved then
        modData[PA_MD_KEY_ORIG_OVERLAY] = saved
    end

    obj:transmitUpdatedSprite()
    obj:transmitModData()
end

local function PA_RestoreSavedTileOverlay(obj)
    if not obj then return end
    local modData = obj:getModData()

    -- limpiar overlays actuales
    obj:setOverlaySprite(nil)
    if obj:hasAttachedAnimSprites() then
        obj:setAttachedAnimSprite(nil)
    end

    local saved = modData[PA_MD_KEY_ORIG_OVERLAY]
    if saved then
        local spr = IsoSpriteManager.instance:getSprite(saved)
        if spr then
            obj:addAttachedAnimSprite(spr)
        end
        modData[PA_MD_KEY_ORIG_OVERLAY] = nil
    end

    obj:transmitUpdatedSprite()
    obj:transmitModData()
end

local function PA_ForceOverlayRefresh(obj)
    if not obj then return end

    obj:transmitUpdatedSprite()

    if ItemPicker and ItemPicker.updateOverlaySprite then
        ItemPicker.updateOverlaySprite(obj)
    end

    local sq = obj:getSquare()
    if sq then
        sq:RecalcProperties()

        if sq.InvalidateSpecialObjects then
            sq:InvalidateSpecialObjects()
        end

        if sq.RecalcLighting then
            sq:RecalcLighting()
        end
    end
end


local function PA_SetArcadeScreenOverlay(obj, enabled)
    if not obj or not obj:getSprite() then return end
	local spriteName = obj:getSprite():getName()
	local overlayName = PA_GetOverlayForSprite(spriteName)
	if not overlayName then return end


    local modData = obj:getModData()

    if enabled then
        if modData[PA_MD_KEY_IS_ON] then
            return
        end
        modData[PA_MD_KEY_IS_ON] = true

        PA_SaveAndRemoveAnyTileOverlay(obj)

        local onSpr = IsoSpriteManager.instance:getSprite(overlayName)
        if onSpr then
            obj:addAttachedAnimSprite(onSpr)
        end

        obj:transmitUpdatedSprite()
        obj:transmitModData()
        if ItemPicker and ItemPicker.updateOverlaySprite then
            ItemPicker.updateOverlaySprite(obj)
        end
		PA_ForceOverlayRefresh(obj)
    else
        if not modData[PA_MD_KEY_IS_ON] then
            return 
        end
        modData[PA_MD_KEY_IS_ON] = nil

        PA_RestoreSavedTileOverlay(obj)

        if ItemPicker and ItemPicker.updateOverlaySprite then
            ItemPicker.updateOverlaySprite(obj)
        end
		PA_ForceOverlayRefresh(obj)
    end
end


local ProjectArcade_PlayArcadeTimedAction = ISBaseTimedAction:derive("ProjectArcade_PlayArcadeTimedAction")

function ProjectArcade_PlayArcadeTimedAction:isValid()
    if not self.character or not self.object then return false end
    local square = self.object:getSquare()
    if not square then return false end

    local sprite = self.object:getSprite()
    local spriteName = sprite and sprite:getName() or nil

    local interactionTile = getInteractionTileForRecreational(square, spriteName, self.machineType)

    if interactionTile and interactionTile ~= self.character:getSquare() then
        if not self.hasSaidMessage then
            self.character:Say(safeGetText("ContextMenu_StepInFront"))
            self.hasSaidMessage = true
        end
        return false
    end

    return true
end

local function getFacingTargetSquareForMachine(square, spriteName, machineType)
    if not square or not spriteName then return square end

    if machineType == "ComplexStarWars" then
        -- En todos los casos mira hacia la máquina/cola
        return square
    end

    return square
end

function ProjectArcade_PlayArcadeTimedAction:start()
        self.paid = false
		
		self._PA_moodAccB = 0
	self._PA_moodAccU = 0
	self._PA_moodAccS = 0
	self._PA_nextMoodSendMs = nil

    local sq = self.object and self.object:getSquare() or nil
    local sp = self.object and self.object:getSprite() or nil
    local spriteName = sp and sp:getName() or nil
    local faceSq = getFacingTargetSquareForMachine(sq, spriteName, self.machineType) or sq
    if faceSq then
        self.character:faceLocation(faceSq:getX(), faceSq:getY())
    end

        if not self.debugFreePlay then
    end

    self.paid = true

    local cfg = PA_GetMachineConfig(self.machineType)
    local anim = (cfg and cfg.actionAnim) or "PlayArcade"
    self:setActionAnim(anim)
    PA_SetArcadeScreenOverlay(self.object, true)

    self.loopSoundName = (cfg and cfg.loopSound) or getPlayLoopSound(self.machineType)

    PA_SendWorldSoundStart(self, self.loopSoundName)

    -- Suprime el sonido de ambiente de esta máquina mientras se juega
    local ArcadeAmbientSound = require "ProjectArcade_ArcadeAmbientSound"
    if ArcadeAmbientSound and ArcadeAmbientSound.suppressForObject then
        ArcadeAmbientSound.suppressForObject(self.object)
    end

end


function ProjectArcade_PlayArcadeTimedAction:update()
    local delta = getGameTime():getTrueMultiplier()

-- Recordatorio para mi mismo
    local boredomBase = 25
    local unhappinessBase = 35
    local stressBase = 25
-- ---------------------------

    local boredomDecrease = (boredomBase / self.maxTime) * delta
    local unhappinessDecrease = (unhappinessBase / self.maxTime) * delta
    local stressDecrease = (stressBase / (100 * self.maxTime)) * delta

	PA_SendMoodDeltaToServer(self, boredomDecrease, unhappinessDecrease, stressDecrease)
	PA_MoodTick(self, boredomDecrease, unhappinessDecrease, stressDecrease)

    if not self.loopSoundName then
        local cfg = PA_GetMachineConfig(self.machineType)
        self.loopSoundName = (cfg and cfg.loopSound) or getPlayLoopSound(self.machineType)
    end

    PA_PlayGameSound(self, self.loopSoundName)

    -- SP: en singleplayer no hay server que reciba comandos, así que generamos ruido real acá
    if not isClient() then
        local nowMs = (getTimestampMs and getTimestampMs()) or (os.time() * 1000)
        self._PA_nextAggroMs = self._PA_nextAggroMs or 0
        if nowMs >= self._PA_nextAggroMs then
            local sq = self.object and self.object:getSquare() or nil
            if sq and addSound then
                local x, y, z = sq:getX(), sq:getY(), sq:getZ()

                -- Tomamos parámetros desde el clip (distanceMax/volume) si está disponible.
                local aggroRadius, aggroVol = 30, 0.5
                local snd = GameSounds and GameSounds.getSound and self.loopSoundName and GameSounds.getSound(self.loopSoundName)
                if snd then
                    local clip = snd:getRandomClip()
                    if clip then
                        if clip.getMaxDistance then
                            local d = clip:getMaxDistance()
                            if d and d > 0 then aggroRadius = math.floor(d) end
                        end
                        if clip.getVolume then
                            local v = clip:getVolume()
                            if v and v > 0 then aggroVol = v end
                        end
                    end
                end

                addSound(self.character, x, y, z, aggroRadius, aggroVol)
            end
            self._PA_nextAggroMs = nowMs + 2000
        end
    end


    local sq = self.object and self.object:getSquare() or nil
    local sp = self.object and self.object:getSprite() or nil
    local spriteName = sp and sp:getName() or nil
    local faceSq = getFacingTargetSquareForMachine(sq, spriteName, self.machineType) or sq
    if faceSq then
        self.character:faceLocation(faceSq:getX(), faceSq:getY())
    end
	PA_TickHaloQueue(self)
end

local function PA_PlayOneShotAtMachine(self, soundName)
    if not soundName then return end

    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if not snd then return end

    local sq = self.object and self.object:getSquare() or nil
    if not sq then return end

    local clip = snd:getRandomClip()
    if not clip then return end

    local e = IsoWorld.instance:getFreeEmitter()
    if not e then return end

    e:setPos(sq:getX(), sq:getY(), sq:getZ())

    local id = e:playClip(clip, nil)
    if id and id ~= 0 then
        local clipVol = (clip.getVolume and clip:getVolume()) or 1.0
        local mult = (PA_GetSfxVolMult and PA_GetSfxVolMult()) or 1.0
        e:setVolume(id, clipVol * mult)
        e:set3D(id, true)
        e:tick()
    end
end

function ProjectArcade_PlayArcadeTimedAction:stop()
    PA_StopGameSound(self)
    PA_SetArcadeScreenOverlay(self.object, false)

    PA_SendWorldSoundStop(self)

	if not self._PA_endPlayed then
		local cfg = PA_GetMachineConfig(self.machineType)
		local endSnd = (cfg and cfg.endSound) or getEndSound(self.machineType)
		self._PA_endPlayed = true

		PA_PlayOneShotAtMachine(self, endSnd)

		PA_SendWorldSoundOneShot(self, endSnd)
	end
	
	self._PA_moodAccB = 0
	self._PA_moodAccU = 0
	self._PA_moodAccS = 0
	self._PA_nextMoodSendMs = nil
	
    ISBaseTimedAction.stop(self)
end

function ProjectArcade_PlayArcadeTimedAction:perform()
    PA_SetArcadeScreenOverlay(self.object, false)
    PA_StopGameSound(self)

    PA_SendWorldSoundStop(self)

    local cfg = PA_GetMachineConfig(self.machineType)
    local endSnd = (cfg and cfg.endSound) or getEndSound(self.machineType)

    PA_PlayOneShotAtMachine(self, endSnd)

    if not self._PA_endPlayed then
        self._PA_endPlayed = true
        PA_SendWorldSoundOneShot(self, endSnd)
    end

	self.announcedResult = self.announcedResult or false

    local stats = self.character:getStats()
    if CharacterStat and stats and stats.get and stats.set then
        if self.didWin then
            stats:set(CharacterStat.BOREDOM, math.max(0, stats:get(CharacterStat.BOREDOM) - 20))
            stats:set(CharacterStat.UNHAPPINESS, math.max(0, stats:get(CharacterStat.UNHAPPINESS) - 25))
            stats:set(CharacterStat.STRESS, math.max(0, stats:get(CharacterStat.STRESS) - 0.15))
			if not self.announcedResult then
				self.announcedResult = true
				PA_QueueHalo(self, self.didWin and "ContextMenu_ArcadeWin" or "ContextMenu_ArcadeLose", self.didWin, 200, 255, 200, 0)
				PA_TickHaloQueue(self)
			end
        else
--            stats:set(CharacterStat.UNHAPPINESS, math.min(100, stats:get(CharacterStat.UNHAPPINESS) + 5))
            stats:set(CharacterStat.STRESS, math.min(1, stats:get(CharacterStat.STRESS) + 0.1))
			if not self.announcedResult then
				self.announcedResult = true
				PA_QueueHalo(self, self.didWin and "ContextMenu_ArcadeWin" or "ContextMenu_ArcadeLose", self.didWin, 200, 255, 200, 0)
				PA_TickHaloQueue(self)
			end
        end
    else
			if not self.announcedResult then
				self.announcedResult = true
				PA_QueueHalo(self, self.didWin and "ContextMenu_ArcadeWin" or "ContextMenu_ArcadeLose", self.didWin, 200, 255, 200, 0)
				PA_TickHaloQueue(self)
			end
    end
	
	if not self.didWin then
--		PA_QueueHalo(self, "ContextMenu_ProjectArcade_Mood_UnhappinessUp", false, 255, 120, 120, 0)
		PA_QueueHalo(self, "ContextMenu_ProjectArcade_Mood_StressUp", false, 255, 120, 120, 300)
		PA_TickHaloQueue(self)
	end

    ISBaseTimedAction.perform(self)
end

function ProjectArcade_PlayArcadeTimedAction:new(character, object, time, cost, currencyFullType, debugFreePlay)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.object = object

    local sprite = object and object:getSprite()
    local spriteName = sprite and sprite:getName() or nil
    o.machineType = getArcadeMachineType(spriteName)

    o.maxTime = time or 3000
    o.hasSaidMessage = false

    o.stopOnWalk = true
    o.stopOnRun = true

    o.emitter = nil
    o.soundId = nil
    o.loopSoundName = nil
    o.nextLoopAtMs = 0

    o.didWin = (ZombRand(100) < 60)
	
	o.nextMoodHaloAtMs = 0


        o.cost = cost or (ProjectArcade_Currency and ProjectArcade_Currency.Config and ProjectArcade_Currency.Config.Cost) or 1
    o.currencyFullType = currencyFullType or (ProjectArcade_Currency and ProjectArcade_Currency.Config and ProjectArcade_Currency.Config.CurrencyFullType) or "Base.SilverCoin"
    o.debugFreePlay = (debugFreePlay == true)
    o.paid = false

    return o
end

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


return {class=ProjectArcade_PlayArcadeTimedAction,machineType=getArcadeMachineType,front=getInteractionTileForRecreational,overlay=PA_SetArcadeScreenOverlay,power=machineHasPower}
end)()
-- END INSTALLED SOURCE ProjectArcade/play
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaPong.lua
GameClasses['pong'] = (function()
require "ISUI/ISPanel"

local PZPongGame = ISPanel:derive("PZPongGame")

function PZPongGame:initialise()
    ISPanel.initialise(self)
    self:buildBackdrop()
    self:resetGame()
end

function PZPongGame:buildBackdrop()
    self.backdrop = {}
    for i = 1, 28 do
        self.backdrop[#self.backdrop + 1] = {
            x = ZombRand(1000) / 1000,
            y = ZombRand(1000) / 1000,
            s = 1 + ZombRand(3),
            a = 0.10 + (ZombRand(40) / 100)
        }
    end
end

function PZPongGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.flashTick = 0
    self.hitFlash = 0
    self.scorePulse = 0
    self.shake = 0
    self.ballTrail = {}
    self.particles = {}
    self.ball = {
        x = 0.5,
        y = 0.5,
        dx = (ZombRand(2) == 0 and -0.017 or 0.017),
        dy = (ZombRand(2) == 0 and -0.011 or 0.011),
        size = 0.026
    }
    self.paddle = {x = 0.045, y = 0.5 - 0.09, width = 0.016, height = 0.19, speed = 0.024}
    self.cpu = {x = 0.939, y = 0.5 - 0.09, width = 0.016, height = 0.19, speed = 0.0135, error = 0, delay = 0}
    self.score = 0
    self.cpuScore = 0
    self.targetScore = 7
end

function PZPongGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZPongGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZPongGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZPongGame:clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function PZPongGame:update()
    self.flashTick = self.flashTick + 1
    self.hitFlash = math.max(0, (self.hitFlash or 0) - 1)
    self.scorePulse = math.max(0, (self.scorePulse or 0) - 1)
    self.shake = math.max(0, (self.shake or 0) - 1)
    self:updateParticles()

    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    if ComputerModGameInput.isDown(self, "up") then
        self.paddle.y = self.paddle.y - self.paddle.speed
    elseif ComputerModGameInput.isDown(self, "down") then
        self.paddle.y = self.paddle.y + self.paddle.speed
    end

    self.paddle.y = self:clamp(self.paddle.y, 0.035, 1 - self.paddle.height - 0.035)
    self:gameTick()
end

function PZPongGame:resetBall(direction)
    self.ball.x = 0.5
    self.ball.y = 0.5
    self.ball.dx = direction or (self.ball.dx > 0 and -0.017 or 0.017)
    self.ball.dy = (ZombRand(2) == 0 and -0.011 or 0.011)
    self.ballTrail = {}
    self.cpu.error = (ZombRand(180) - 90) / 560
    self.cpu.delay = 4 + ZombRand(12)
end

function PZPongGame:updateCpu()
    if self.cpu.delay and self.cpu.delay > 0 then
        self.cpu.delay = self.cpu.delay - 1
        return
    end
    local ballCenterY = self.ball.y + self.ball.size * 0.5
    local cpuCenterY = self.cpu.y + self.cpu.height * 0.5
    local trackingTarget = ballCenterY + self.cpu.error
    local deadzone = 0.034

    if math.abs(cpuCenterY - trackingTarget) > deadzone then
        if cpuCenterY < trackingTarget then
            self.cpu.y = self.cpu.y + self.cpu.speed
        else
            self.cpu.y = self.cpu.y - self.cpu.speed
        end
    end

    if self.ball.dx < 0 then
        self.cpu.y = self.cpu.y + ((0.5 - self.cpu.height * 0.5) - self.cpu.y) * 0.010
    end

    self.cpu.y = self:clamp(self.cpu.y, 0.035, 1 - self.cpu.height - 0.035)
end

function PZPongGame:pushTrail()
    table.insert(self.ballTrail, 1, {x = self.ball.x, y = self.ball.y, s = self.ball.size})
    if #self.ballTrail > 12 then
        table.remove(self.ballTrail)
    end
end

function PZPongGame:emitParticles(x, y, r, g, b, count)
    for i = 1, count do
        local life = 16 + ZombRand(18)
        self.particles[#self.particles + 1] = {
            x = x,
            y = y,
            vx = (ZombRand(1200) - 600) / 42000,
            vy = (ZombRand(1200) - 600) / 42000,
            r = r,
            g = g,
            b = b,
            life = life,
            maxLife = life
        }
    end
end

function PZPongGame:updateParticles()
    if not self.particles then self.particles = {} end
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.x = p.x + p.vx
        p.y = p.y + p.vy
        p.vx = p.vx * 0.96
        p.vy = p.vy * 0.96
        p.life = p.life - 1
        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end
end

function PZPongGame:paddleHit(paddle, playerSide)
    local center = self.ball.y + self.ball.size * 0.5
    local paddleCenter = paddle.y + paddle.height * 0.5
    local influence = (center - paddleCenter) / (paddle.height * 0.5)
    if playerSide then
        self.ball.x = paddle.x + paddle.width
        self.ball.dx = math.min(math.abs(self.ball.dx) + 0.0010, 0.032)
        self.ball.dy = self.ball.dy + influence * 0.010
        self:emitParticles(self.ball.x, self.ball.y + self.ball.size * 0.5, 0.38, 0.96, 1, 9)
    else
        self.ball.x = paddle.x - self.ball.size
        self.ball.dx = -math.min(math.abs(self.ball.dx) + 0.0008, 0.030)
        self.ball.dy = self.ball.dy + influence * 0.009
        self.cpu.error = (ZombRand(200) - 100) / 470
        self.cpu.delay = 4 + ZombRand(10)
        self:emitParticles(self.ball.x + self.ball.size, self.ball.y + self.ball.size * 0.5, 1, 0.36, 0.42, 8)
    end
    self.hitFlash = 8
    self:playSound("ComputerBallHit")
end

function PZPongGame:gameTick()
    self:updateCpu()
    self:pushTrail()

    if self.ball.y <= 0.025 then
        self.ball.y = 0.025
        self.ball.dy = math.abs(self.ball.dy)
        self:emitParticles(self.ball.x, self.ball.y, 0.52, 0.72, 1, 3)
    elseif self.ball.y + self.ball.size >= 0.975 then
        self.ball.y = 0.975 - self.ball.size
        self.ball.dy = -math.abs(self.ball.dy)
        self:emitParticles(self.ball.x, self.ball.y + self.ball.size, 0.52, 0.72, 1, 3)
    end

    if self.ball.x <= self.paddle.x + self.paddle.width and self.ball.x + self.ball.size >= self.paddle.x then
        if self.ball.y + self.ball.size >= self.paddle.y and self.ball.y <= self.paddle.y + self.paddle.height and self.ball.dx < 0 then
            self:paddleHit(self.paddle, true)
        end
    end

    if self.ball.x + self.ball.size >= self.cpu.x and self.ball.x <= self.cpu.x + self.cpu.width then
        if self.ball.y + self.ball.size >= self.cpu.y and self.ball.y <= self.cpu.y + self.cpu.height and self.ball.dx > 0 then
            self:paddleHit(self.cpu, false)
        end
    end

    self.ball.dy = self:clamp(self.ball.dy, -0.023, 0.023)
    self.ball.x = self.ball.x + self.ball.dx
    self.ball.y = self.ball.y + self.ball.dy

    if self.ball.x + self.ball.size < -0.02 then
        self.cpuScore = self.cpuScore + 1
        self.scorePulse = 18
        self.shake = 10
        self:playSound("ComputerBallHit")
        if self.cpuScore >= self.targetScore then
            self.gameState = "GAMEOVER"
            self:playGameOverSound()
        else
            self:resetBall(0.017)
        end
    elseif self.ball.x > 1.02 then
        self.score = self.score + 1
        self.scorePulse = 18
        self.shake = 6
        self:playSound("ComputerWinOpen")
        if self.score >= self.targetScore then
            self.gameState = "WIN"
            self:playWinSound()
        else
            self:resetBall(-0.017)
        end
    end
end

function PZPongGame:drawScaledRect(x, y, w, h, a, r, g, b)
    self:drawRect(x * self.width, y * self.height, w * self.width, h * self.height, a, r, g, b)
end

function PZPongGame:drawBackdrop()
    self:drawRect(0, 0, self.width, self.height, 1, 0.015, 0.025, 0.045)
    local bands = 14
    for i = 0, bands do
        local y = (i / bands) * self.height
        local alpha = 0.12 + (i / bands) * 0.08
        self:drawRect(0, y, self.width, math.max(2, self.height / bands), alpha, 0.03, 0.08 + i * 0.006, 0.13 + i * 0.008)
    end
    for i = 1, #self.backdrop do
        local star = self.backdrop[i]
        local twinkle = 0.65 + math.sin((self.flashTick + i * 9) / 18) * 0.35
        self:drawRect(star.x * self.width, star.y * self.height, star.s, star.s, star.a * twinkle, 0.44, 0.88, 1)
    end
    local horizon = self.height * 0.52
    self:drawRect(0, horizon - 1, self.width, 2, 0.55, 0.06, 0.42, 0.56)
    for i = 1, 8 do
        local y = horizon + i * i * 2.2
        if y < self.height then
            self:drawRect(0, y, self.width, 1, 0.22, 0.12, 0.72, 0.86)
        end
    end
    for i = -6, 6 do
        local x = self.width * 0.5 + i * self.width * 0.08
        self:drawRect(x, horizon, 1, self.height - horizon, 0.16, 0.12, 0.72, 0.86)
    end
    if self.hitFlash and self.hitFlash > 0 then
        self:drawRect(0, 0, self.width, self.height, self.hitFlash / 80, 0.42, 0.95, 1)
    end
end

function PZPongGame:drawCourt()
    local dashH = math.max(6, self.height * 0.045)
    local gapH = math.max(5, self.height * 0.030)
    local y = self.height * 0.08
    while y < self.height * 0.92 do
        self:drawRect(self.width * 0.5 - 1, y, 2, dashH, 0.34, 0.85, 0.96, 1)
        y = y + dashH + gapH
    end
    self:drawRect(self.width * 0.025, self.height * 0.035, self.width * 0.95, 2, 0.28, 0.26, 0.72, 0.9)
    self:drawRect(self.width * 0.025, self.height * 0.96, self.width * 0.95, 2, 0.28, 0.26, 0.72, 0.9)
    self:drawRect(self.width * 0.025, self.height * 0.035, 2, self.height * 0.93, 0.18, 0.26, 0.72, 0.9)
    self:drawRect(self.width * 0.973, self.height * 0.035, 2, self.height * 0.93, 0.18, 0.26, 0.72, 0.9)
end

function PZPongGame:drawTrail()
    for i = #self.ballTrail, 1, -1 do
        local entry = self.ballTrail[i]
        local alpha = 0.06 + (i / #self.ballTrail) * 0.16
        self:drawScaledRect(entry.x - 0.003, entry.y - 0.003, entry.s + 0.006, entry.s + 0.006, alpha, 0.25, 0.92, 1)
    end
end

function PZPongGame:drawParticles()
    local particles = self.particles or {}
    for i = 1, #particles do
        local p = particles[i]
        local alpha = math.max(0, p.life / p.maxLife)
        local px = p.x * self.width
        local py = p.y * self.height
        local size = math.max(2, math.floor(2 + alpha * 4))
        if px >= -size and px <= self.width + size and py >= -size and py <= self.height + size then
            self:drawRect(px, py, size, size, alpha * 0.85, p.r, p.g, p.b)
        end
    end
end

function PZPongGame:drawPaddleGlow(paddle, r, g, b)
    self:drawScaledRect(paddle.x - 0.007, paddle.y - 0.012, paddle.width + 0.014, paddle.height + 0.024, 0.18, r, g, b)
    self:drawScaledRect(paddle.x - 0.003, paddle.y - 0.005, paddle.width + 0.006, paddle.height + 0.010, 0.32, r, g, b)
    self:drawScaledRect(paddle.x, paddle.y, paddle.width, paddle.height, 1, r, g, b)
    self:drawScaledRect(paddle.x + paddle.width * 0.22, paddle.y + 0.012, paddle.width * 0.30, paddle.height - 0.024, 0.72, 1, 1, 1)
end

function PZPongGame:drawScorePanel()
    local pulse = self.scorePulse and self.scorePulse > 0 and self.scorePulse / 18 or 0
    local y = 8
    local leftX = self.width * 0.5 - 70
    local rightX = self.width * 0.5 + 20
    self:drawRect(leftX - pulse * 2, y - pulse, 54 + pulse * 4, 28 + pulse * 2, 0.64, 0.01, 0.04, 0.08)
    self:drawRect(rightX - pulse * 2, y - pulse, 54 + pulse * 4, 28 + pulse * 2, 0.64, 0.01, 0.04, 0.08)
    self:drawRect(leftX, y, 54, 2, 0.95, 0.4, 0.95, 1)
    self:drawRect(rightX, y, 54, 2, 0.95, 1, 0.38, 0.38)
    self:drawText(tostring(self.score), leftX + 21, y + 3, 0.78, 0.96, 1, 1, UIFont.Large)
    self:drawText(tostring(self.cpuScore), rightX + 21, y + 3, 1, 0.56, 0.48, 1, UIFont.Large)
    self:drawText("PLAYER", 12, 8, 0.56, 0.92, 1, 0.82, UIFont.Small)
    self:drawText("CPU", self.width - 38, 8, 1, 0.56, 0.48, 0.82, UIFont.Small)
end

function PZPongGame:drawBall()
    self:drawScaledRect(self.ball.x - 0.010, self.ball.y - 0.010, self.ball.size + 0.020, self.ball.size + 0.020, 0.16, 0.2, 1, 0.78)
    self:drawScaledRect(self.ball.x - 0.004, self.ball.y - 0.004, self.ball.size + 0.008, self.ball.size + 0.008, 0.42, 0.48, 1, 0.78)
    self:drawScaledRect(self.ball.x, self.ball.y, self.ball.size, self.ball.size, 1, 0.86, 1, 0.82)
    self:drawScaledRect(self.ball.x + self.ball.size * 0.18, self.ball.y + self.ball.size * 0.15, self.ball.size * 0.28, self.ball.size * 0.22, 0.86, 1, 1, 1)
end

function PZPongGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.07, 0, 0, 0)
        y = y + 4
    end
    self:drawRect(0, 0, self.width, 8, 0.25, 0, 0, 0)
    self:drawRect(0, self.height - 8, self.width, 8, 0.25, 0, 0, 0)
end

function PZPongGame:drawOverlay(title, detail, r, g, b)
    local boxW = math.min(self.width - 36, 248)
    local boxH = 112
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 4, boxY - 4, boxW + 8, boxH + 8, 0.25, r, g, b)
    self:drawRect(boxX, boxY, boxW, boxH, 0.92, 0.01, 0.02, 0.04)
    self:drawRect(boxX, boxY, boxW, 3, 1, r, g, b)
    self:drawText(title, boxX + 28, boxY + 22, r, g, b, 1, UIFont.Medium)
    self:drawText(detail, boxX + 44, boxY + 52, 0.9, 0.95, 1, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. " TO RESTART", boxX + 58, boxY + 78, 0.78, 0.9, 1, 1, UIFont.Small)
end

function PZPongGame:prerender()
    self:drawBackdrop()
    self:drawCourt()
    self:drawScorePanel()
    self:drawTrail()
    self:drawParticles()
    self:drawPaddleGlow(self.paddle, 0.40, 0.95, 1)
    self:drawPaddleGlow(self.cpu, 1, 0.34, 0.42)
    self:drawBall()

    if self.gameState == "WIN" then
        self:drawOverlay("VICTORY", "Score " .. tostring(self.score) .. " - " .. tostring(self.cpuScore), 0.34, 1, 0.58)
    elseif self.gameState == "GAMEOVER" then
        self:drawOverlay("GAME OVER", "Score " .. tostring(self.score) .. " - " .. tostring(self.cpuScore), 1, 0.42, 0.34)
    end

    self:drawScanlines()
end

function PZPongGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZPongGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaPong.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaSnake.lua
GameClasses['snake'] = (function()
require "ISUI/ISPanel"

local PZSnakeGame = ISPanel:derive("PZSnakeGame")

function PZSnakeGame:initialise()
    ISPanel.initialise(self)
    self.highscore = 0
    self:resetGame()
end

function PZSnakeGame:layoutBoard()
    self.cols = 28
    self.rows = 18
    local topSpace = math.max(32, math.floor(self.height * 0.12))
    local bottomSpace = 14
    local usableW = math.max(1, self.width - 28)
    local usableH = math.max(1, self.height - topSpace - bottomSpace)
    self.gridSize = math.max(4, math.floor(math.min(usableW / self.cols, usableH / self.rows)))
    self.boardW = self.gridSize * self.cols
    self.boardH = self.gridSize * self.rows
    self.boardX = math.floor((self.width - self.boardW) / 2)
    self.boardY = topSpace + math.floor((usableH - self.boardH) / 2)
    self.layoutW = self.width
    self.layoutH = self.height
end

function PZSnakeGame:resetGame()
    self:layoutBoard()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.gridGlow = 0
    self.foodPulse = 0
    self.turnPulse = 0
    self.particles = {}
    self.snake = {}
    local startX = math.floor(self.cols / 2)
    local startY = math.floor(self.rows / 2)
    table.insert(self.snake, {x = startX, y = startY})
    table.insert(self.snake, {x = startX - 1, y = startY})
    table.insert(self.snake, {x = startX - 2, y = startY})
    table.insert(self.snake, {x = startX - 3, y = startY})
    self.dx = 1
    self.dy = 0
    self.nextDx = 1
    self.nextDy = 0
    self.inputRegistered = false
    self.food = {x = 0, y = 0}
    self.score = 0
    self.tickCounter = 0
    self.speed = 4.2
    self:spawnFood()
end

function PZSnakeGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZSnakeGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZSnakeGame:spawnFood()
    local tries = 0
    local valid = false
    while not valid and tries < 800 do
        tries = tries + 1
        self.food.x = ZombRand(self.cols)
        self.food.y = ZombRand(self.rows)
        valid = true
        for i = 1, #self.snake do
            if self.snake[i].x == self.food.x and self.snake[i].y == self.food.y then
                valid = false
                break
            end
        end
    end
end

function PZSnakeGame:update()
    self.foodPulse = (self.foodPulse + 1) % 80
    self.gridGlow = (self.gridGlow + 1) % 120
    self.turnPulse = math.max(0, (self.turnPulse or 0) - 1)
    self:updateParticles()

    if self.gameState == "GAMEOVER" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    if not self.inputRegistered then
        if ComputerModGameInput.isDown(self, "up") and self.dy == 0 then
            self.nextDx = 0
            self.nextDy = -1
            self.inputRegistered = true
            self.turnPulse = 8
        elseif ComputerModGameInput.isDown(self, "down") and self.dy == 0 then
            self.nextDx = 0
            self.nextDy = 1
            self.inputRegistered = true
            self.turnPulse = 8
        elseif ComputerModGameInput.isDown(self, "left") and self.dx == 0 then
            self.nextDx = -1
            self.nextDy = 0
            self.inputRegistered = true
            self.turnPulse = 8
        elseif ComputerModGameInput.isDown(self, "right") and self.dx == 0 then
            self.nextDx = 1
            self.nextDy = 0
            self.inputRegistered = true
            self.turnPulse = 8
        end
    end

    self.tickCounter = self.tickCounter + 1
    if self.tickCounter >= self.speed then
        self.tickCounter = 0
        self:gameTick()
    end
end

function PZSnakeGame:gameTick()
    self.dx = self.nextDx
    self.dy = self.nextDy
    self.inputRegistered = false

    local head = self.snake[1]
    local newX = head.x + self.dx
    local newY = head.y + self.dy

    if newX < 0 or newX >= self.cols or newY < 0 or newY >= self.rows then
        self:gameOver()
        return
    end

    for i = 1, #self.snake do
        if newX == self.snake[i].x and newY == self.snake[i].y then
            self:gameOver()
            return
        end
    end

    table.insert(self.snake, 1, {x = newX, y = newY})

    if newX == self.food.x and newY == self.food.y then
        self.score = self.score + 10
        self.speed = math.max(2.1, self.speed - 0.10)
        self:emitFoodParticles(newX, newY)
        self:playSound("ComputerBallHit")
        self:spawnFood()
    else
        table.remove(self.snake)
    end
end

function PZSnakeGame:gameOver()
    self.gameState = "GAMEOVER"
    if self.score > self.highscore then
        self.highscore = self.score
    end
    self:emitFoodParticles(self.snake[1].x, self.snake[1].y)
    self:playGameOverSound()
end

function PZSnakeGame:emitFoodParticles(cellX, cellY)
    for i = 1, 18 do
        local life = 18 + ZombRand(18)
        self.particles[#self.particles + 1] = {
            x = cellX + 0.5,
            y = cellY + 0.5,
            vx = (ZombRand(1000) - 500) / 1800,
            vy = (ZombRand(1000) - 500) / 1800,
            life = life,
            maxLife = life,
            c = 1 + ZombRand(3)
        }
    end
end

function PZSnakeGame:updateParticles()
    if not self.particles then self.particles = {} end
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.x = p.x + p.vx
        p.y = p.y + p.vy
        p.vx = p.vx * 0.92
        p.vy = p.vy * 0.92
        p.life = p.life - 1
        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end
end

function PZSnakeGame:drawBackground()
    self:drawRect(0, 0, self.width, self.height, 1, 0.012, 0.028, 0.018)
    for i = 0, 14 do
        local y = i * self.height / 14
        self:drawRect(0, y, self.width, math.max(2, self.height / 16), 0.18, 0.02, 0.06 + i * 0.004, 0.035)
    end
    local glow = 0.05 + math.sin(self.gridGlow / 18) * 0.025
    self:drawRect(self.boardX - 8, self.boardY - 8, self.boardW + 16, self.boardH + 16, 0.22 + glow, 0.14, 0.9, 0.34)
    self:drawRect(self.boardX - 5, self.boardY - 5, self.boardW + 10, self.boardH + 10, 1, 0.015, 0.07, 0.035)
end

function PZSnakeGame:drawHud()
    local speedText = "LVL " .. tostring(math.max(1, math.floor((4.4 - self.speed) * 4) + 1))
    self:drawRect(0, 0, self.width, 24, 1, 0.006, 0.020, 0.010)
    self:drawRect(0, 23, self.width, 1, 1, 0.18, 0.42, 0.22)
    self:drawText("SNAKE.EXE", 10, 7, 0.62, 0.90, 0.58, 1, UIFont.Small)
    self:drawText("SCORE:" .. tostring(self.score), 96, 7, 0.62, 0.90, 0.58, 1, UIFont.Small)
    self:drawText("BEST:" .. tostring(self.highscore), 188, 7, 0.62, 0.90, 0.58, 1, UIFont.Small)
    self:drawText(speedText, self.width - 54, 7, 0.80, 0.78, 0.48, 1, UIFont.Small)
end

function PZSnakeGame:drawBoard()
    self:drawRect(self.boardX, self.boardY, self.boardW, self.boardH, 1, 0.035, 0.11, 0.045)
    for y = 0, self.rows - 1 do
        for x = 0, self.cols - 1 do
            local shade = ((x + y) % 2 == 0) and 0.050 or 0.038
            local px = self.boardX + x * self.gridSize
            local py = self.boardY + y * self.gridSize
            self:drawRect(px, py, self.gridSize - 1, self.gridSize - 1, 1, 0.025, shade + 0.065, 0.035)
            if self.gridSize >= 12 then
                self:drawRect(px, py, self.gridSize - 1, 1, 0.18, 0.14, 0.35, 0.14)
            end
        end
    end
    self:drawRect(self.boardX - 2, self.boardY - 2, self.boardW + 4, 2, 1, 0.18, 0.72, 0.28)
    self:drawRect(self.boardX - 2, self.boardY + self.boardH, self.boardW + 4, 2, 1, 0.05, 0.28, 0.12)
    self:drawRect(self.boardX - 2, self.boardY - 2, 2, self.boardH + 4, 1, 0.18, 0.72, 0.28)
    self:drawRect(self.boardX + self.boardW, self.boardY - 2, 2, self.boardH + 4, 1, 0.05, 0.28, 0.12)
end

function PZSnakeGame:cellRect(cell)
    return self.boardX + cell.x * self.gridSize, self.boardY + cell.y * self.gridSize, self.gridSize
end

function PZSnakeGame:drawSnakeCell(cell, index)
    local px, py, size = self:cellRect(cell)
    local inset = math.max(1, math.floor(size * 0.12))
    local core = math.max(2, size - inset * 2)
    local fade = math.max(0.34, 1 - index * 0.026)
    local pulse = index == 1 and (self.turnPulse or 0) / 42 or 0

    self:drawRect(px + inset - 1, py + inset + 1, core + 2, core + 2, 0.24, 0, 0, 0)
    if index == 1 then
        self:drawRect(px + inset - 2, py + inset - 2, core + 4, core + 4, 0.25 + pulse, 0.34, 1, 0.48)
        self:drawRect(px + inset, py + inset, core, core, 1, 0.32, 0.96, 0.38)
        self:drawRect(px + inset + 2, py + inset + 2, math.max(2, core - 4), math.max(2, math.floor(core * 0.34)), 0.50, 0.84, 1, 0.66)
        local eyeSize = math.max(2, math.floor(size * 0.13))
        local eyeY = py + inset + math.max(2, math.floor(core * 0.24))
        if self.dx ~= 0 then
            local leftEye = self.dx > 0 and px + inset + core - eyeSize * 3 or px + inset + eyeSize
            self:drawRect(leftEye, eyeY, eyeSize, eyeSize, 1, 0.02, 0.07, 0.02)
            self:drawRect(leftEye, eyeY + eyeSize * 2, eyeSize, eyeSize, 1, 0.02, 0.07, 0.02)
        else
            local eyeX = px + inset + math.max(2, math.floor(core * 0.25))
            local eyeX2 = px + inset + core - eyeSize - math.max(2, math.floor(core * 0.25))
            local finalY = self.dy > 0 and py + inset + core - eyeSize * 2 or eyeY
            self:drawRect(eyeX, finalY, eyeSize, eyeSize, 1, 0.02, 0.07, 0.02)
            self:drawRect(eyeX2, finalY, eyeSize, eyeSize, 1, 0.02, 0.07, 0.02)
        end
    else
        self:drawRect(px + inset, py + inset, core, core, 1, 0.08, 0.34 + fade * 0.40, 0.12)
        self:drawRect(px + inset + 2, py + inset + 2, math.max(2, core - 4), math.max(2, core - 4), 0.48, 0.16, 0.72 + fade * 0.18, 0.22)
    end
end

function PZSnakeGame:drawFood()
    local pulse = 0.45 + math.sin(self.foodPulse / 8) * 0.18
    local px = self.boardX + self.food.x * self.gridSize
    local py = self.boardY + self.food.y * self.gridSize
    local size = self.gridSize
    local inset = math.max(2, math.floor(size * (0.18 - pulse * 0.04)))
    self:drawRect(px + inset - 2, py + inset - 2, size - inset * 2 + 4, size - inset * 2 + 4, 0.22 + pulse * 0.12, 1, 0.28, 0.18)
    self:drawRect(px + inset, py + inset, size - inset * 2, size - inset * 2, 1, 0.92, 0.08, 0.08)
    self:drawRect(px + math.floor(size * 0.46), py + math.floor(size * 0.14), math.max(2, math.floor(size * 0.14)), math.max(2, math.floor(size * 0.20)), 1, 0.12, 0.42, 0.08)
    self:drawRect(px + inset + 2, py + inset + 2, math.max(2, math.floor(size * 0.25)), math.max(2, math.floor(size * 0.18)), 0.8, 1, 0.78, 0.38)
end

function PZSnakeGame:drawParticles()
    local particles = self.particles or {}
    for i = 1, #particles do
        local p = particles[i]
        local alpha = math.max(0, p.life / p.maxLife)
        local px = self.boardX + p.x * self.gridSize
        local py = self.boardY + p.y * self.gridSize
        local s = math.max(2, math.floor(self.gridSize * 0.16 * alpha + 1))
        local r, g, b = 0.96, 0.9, 0.2
        if p.c == 2 then r, g, b = 0.40, 1, 0.52 end
        if p.c == 3 then r, g, b = 0.34, 0.90, 1 end
        self:drawRect(px, py, s, s, alpha, r, g, b)
    end
end

function PZSnakeGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.06, 0, 0, 0)
        y = y + 4
    end
end

function PZSnakeGame:drawGameOver()
    local boxW = math.min(self.boardW - 28, 238)
    local boxH = 104
    local boxX = math.floor(self.boardX + (self.boardW - boxW) / 2)
    local boxY = math.floor(self.boardY + (self.boardH - boxH) / 2)
    if boxW < 190 then
        boxW = math.min(self.width - 28, 190)
        boxX = math.floor((self.width - boxW) / 2)
    end

    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.06, 0.10, 0.06)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.004, 0.018, 0.008)
    self:drawRect(boxX + 4, boxY + 4, boxW - 8, 1, 1, 0.24, 0.46, 0.24)
    self:drawRect(boxX + 4, boxY + boxH - 5, boxW - 8, 1, 1, 0.24, 0.46, 0.24)
    self:drawText("SNAKE.EXE STOPPED", boxX + 10, boxY + 18, 0.62, 0.90, 0.58, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), boxX + 10, boxY + 44, 0.62, 0.90, 0.58, 1, UIFont.Small)
    self:drawText("BEST  " .. tostring(self.highscore), boxX + 10, boxY + 60, 0.62, 0.90, 0.58, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RUN AGAIN", boxX + 10, boxY + 82, 0.80, 0.78, 0.48, 1, UIFont.Small)
end

function PZSnakeGame:prerender()
    if self.layoutW ~= self.width or self.layoutH ~= self.height then
        self:layoutBoard()
    end

    self:drawBackground()
    self:drawHud()
    self:drawBoard()

    if self.gameState == "PLAYING" then
        self:drawFood()
    end

    for i = #self.snake, 1, -1 do
        self:drawSnakeCell(self.snake[i], i)
    end

    self:drawParticles()

    if self.gameState == "GAMEOVER" then
        self:drawGameOver()
    end

    self:drawScanlines()
end

function PZSnakeGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZSnakeGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaSnake.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaMinesweeper.lua
GameClasses['minesweeper'] = (function()
require "ISUI/ISPanel"

local PZMinesweeperGame = ISPanel:derive("PZMinesweeperGame")

local mineNumberPatterns = {
    [1] = {"00100", "01100", "00100", "00100", "00100", "00100", "01110"},
    [2] = {"01110", "10001", "00001", "00010", "00100", "01000", "11111"},
    [3] = {"11110", "00001", "00001", "01110", "00001", "00001", "11110"},
    [4] = {"10010", "10010", "10010", "11111", "00010", "00010", "00010"},
    [5] = {"11111", "10000", "10000", "11110", "00001", "00001", "11110"},
    [6] = {"01110", "10000", "10000", "11110", "10001", "10001", "01110"},
    [7] = {"11111", "00001", "00010", "00100", "01000", "01000", "01000"},
    [8] = {"01110", "10001", "10001", "01110", "10001", "10001", "01110"}
}

function PZMinesweeperGame:initialise()
    ISPanel.initialise(self)
    self.cols = 12
    self.rows = 9
    self.mineCount = 16
    self.bestTime = nil
    self:resetGame()
end

function PZMinesweeperGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.firstClick = true
    self.flags = 0
    self.revealed = 0
    self.timerTicks = 0
    self.winSoundPlayed = false
    self.flash = 0
    self.explodeX = nil
    self.explodeY = nil
    self.grid = {}
    for y = 1, self.rows do
        self.grid[y] = {}
        for x = 1, self.cols do
            self.grid[y][x] = {mine=false, revealed=false, flagged=false, count=0}
        end
    end
end

function PZMinesweeperGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZMinesweeperGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZMinesweeperGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZMinesweeperGame:getCellSize()
    local headerH = math.max(38, math.floor(self.height * 0.14))
    local footerH = 20
    local sizeX = math.floor((self.width - 24) / self.cols)
    local sizeY = math.floor((self.height - headerH - footerH) / self.rows)
    return math.max(8, math.min(sizeX, sizeY)), headerH, footerH
end

function PZMinesweeperGame:getGridOrigin()
    local cell, headerH, footerH = self:getCellSize()
    local gridW = cell * self.cols
    local gridH = cell * self.rows
    local usableH = math.max(1, self.height - headerH - footerH)
    return math.floor((self.width - gridW) / 2), headerH + math.floor((usableH - gridH) / 2), cell
end

function PZMinesweeperGame:cellFromMouse(x, y)
    local ox, oy, cell = self:getGridOrigin()
    local cx = math.floor((x - ox) / cell) + 1
    local cy = math.floor((y - oy) / cell) + 1
    if cx < 1 or cx > self.cols or cy < 1 or cy > self.rows then return nil, nil end
    return cx, cy
end

function PZMinesweeperGame:placeMines(safeX, safeY)
    local placed = 0
    while placed < self.mineCount do
        local x = ZombRand(self.cols) + 1
        local y = ZombRand(self.rows) + 1
        local cell = self.grid[y][x]
        local safe = math.abs(x - safeX) <= 1 and math.abs(y - safeY) <= 1
        if not cell.mine and not safe then
            cell.mine = true
            placed = placed + 1
        end
    end

    for y = 1, self.rows do
        for x = 1, self.cols do
            local count = 0
            for yy = y - 1, y + 1 do
                for xx = x - 1, x + 1 do
                    if self.grid[yy] and self.grid[yy][xx] and self.grid[yy][xx].mine then
                        count = count + 1
                    end
                end
            end
            self.grid[y][x].count = count
        end
    end
end

function PZMinesweeperGame:revealCell(x, y)
    if not self.grid[y] or not self.grid[y][x] then return end
    local cell = self.grid[y][x]
    if cell.revealed or cell.flagged then return end

    cell.revealed = true
    self.revealed = self.revealed + 1

    if cell.mine then
        self.gameState = "GAMEOVER"
        self.explodeX = x
        self.explodeY = y
        self.flash = 16
        self:revealAllMines()
        self:playGameOverSound()
        return
    end

    if cell.count == 0 then
        for yy = y - 1, y + 1 do
            for xx = x - 1, x + 1 do
                if not (xx == x and yy == y) then
                    self:revealCell(xx, yy)
                end
            end
        end
    end

    if self.revealed >= self.cols * self.rows - self.mineCount then
        self.gameState = "WIN"
        self:flagAllMines()
        local time = self:getTimerSeconds()
        if not self.bestTime or time < self.bestTime then
            self.bestTime = time
        end
        self:playWinSound()
    end
end

function PZMinesweeperGame:revealAllMines()
    for y = 1, self.rows do
        for x = 1, self.cols do
            if self.grid[y][x].mine then
                self.grid[y][x].revealed = true
            end
        end
    end
end

function PZMinesweeperGame:flagAllMines()
    self.flags = self.mineCount
    for y = 1, self.rows do
        for x = 1, self.cols do
            if self.grid[y][x].mine then
                self.grid[y][x].flagged = true
            end
        end
    end
end

function PZMinesweeperGame:onMouseDown(x, y)
    if self.gameState ~= "PLAYING" then
        self:resetGame()
        return true
    end

    local cx, cy = self:cellFromMouse(x, y)
    if not cx then return true end

    if self.firstClick then
        self:placeMines(cx, cy)
        self.firstClick = false
    end

    self:playSound("ComputerBallHit")
    self:revealCell(cx, cy)
    return true
end

function PZMinesweeperGame:onRightMouseDown(x, y)
    if self.gameState ~= "PLAYING" then return true end
    local cx, cy = self:cellFromMouse(x, y)
    if not cx then return true end

    local cell = self.grid[cy][cx]
    if cell.revealed then return true end
    if not cell.flagged and self.flags >= self.mineCount then return true end

    cell.flagged = not cell.flagged
    if cell.flagged then
        self.flags = self.flags + 1
    else
        self.flags = self.flags - 1
    end
    self:playSound("ComputerBallHit")
    return true
end

function PZMinesweeperGame:update()
    self.flash = math.max(0, (self.flash or 0) - 1)
    local selectedX, selectedY, activated, secondaryActivated = ComputerModGameInput.updateGridSelection(self, self.cols, self.rows)
    if self.gameState == "PLAYING" and not self.firstClick then
        self.timerTicks = (self.timerTicks or 0) + 1
    end
    if self.gameState ~= "PLAYING" and ComputerModGameInput.isDown(self, "action") then
        self:resetGame()
    elseif self.gameState == "PLAYING" and (activated or secondaryActivated) then
        local ox, oy, cell = self:getGridOrigin()
        local targetX = ox + (selectedX - 0.5) * cell
        local targetY = oy + (selectedY - 0.5) * cell
        if secondaryActivated then
            self:onRightMouseDown(targetX, targetY)
        else
            self:onMouseDown(targetX, targetY)
        end
    end
end

function PZMinesweeperGame:getTimerSeconds()
    return math.min(999, math.floor((self.timerTicks or 0) / 30))
end

function PZMinesweeperGame:drawCellFrame(x, y, size, raised)
    if raised then
        self:drawRect(x, y, size, size, 1, 0.47, 0.50, 0.50)
        self:drawRect(x + 1, y + 1, size - 2, size - 2, 1, 0.60, 0.64, 0.64)
        self:drawRect(x, y, size, 2, 1, 0.88, 0.92, 0.90)
        self:drawRect(x, y, 2, size, 1, 0.88, 0.92, 0.90)
        self:drawRect(x + size - 2, y, 2, size, 1, 0.18, 0.20, 0.22)
        self:drawRect(x, y + size - 2, size, 2, 1, 0.18, 0.20, 0.22)
    else
        self:drawRect(x, y, size, size, 1, 0.30, 0.33, 0.34)
        self:drawRect(x + 2, y + 2, size - 4, size - 4, 1, 0.38, 0.42, 0.42)
        self:drawRect(x, y, size, 1, 1, 0.16, 0.18, 0.18)
        self:drawRect(x, y, 1, size, 1, 0.16, 0.18, 0.18)
    end
end

function PZMinesweeperGame:getNumberColor(n)
    if n == 1 then return 0.18, 0.35, 1 end
    if n == 2 then return 0.08, 0.70, 0.20 end
    if n == 3 then return 1, 0.18, 0.14 end
    if n == 4 then return 0.32, 0.22, 0.82 end
    if n == 5 then return 0.72, 0.12, 0.12 end
    if n == 6 then return 0.0, 0.70, 0.76 end
    if n == 7 then return 0.04, 0.04, 0.05 end
    return 0.75, 0.75, 0.75
end

function PZMinesweeperGame:drawMineNumber(n, x, y, size)
    local r, g, b = self:getNumberColor(n)
    local pattern = mineNumberPatterns[n]
    if not pattern then return end

    local block = math.max(1, math.floor(math.min((size - 8) / 5, (size - 8) / 7)))
    local digitW = block * 5
    local digitH = block * 7
    local left = x + math.floor((size - digitW) / 2)
    local top = y + math.floor((size - digitH) / 2)

    for row = 1, #pattern do
        local line = pattern[row]
        for col = 1, string.len(line) do
            if string.sub(line, col, col) == "1" then
                local px = left + (col - 1) * block
                local py = top + (row - 1) * block
                self:drawRect(px + 1, py + 1, block, block, 0.24, 0, 0, 0)
                self:drawRect(px, py, block, block, 1, r, g, b)
            end
        end
    end
end

function PZMinesweeperGame:drawFlag(px, py, size)
    local poleW = math.max(2, math.floor(size * 0.10))
    local poleX = px + math.floor(size * 0.34)
    local poleY = py + math.floor(size * 0.18)
    self:drawRect(poleX, poleY, poleW, math.floor(size * 0.58), 1, 0.04, 0.04, 0.04)
    self:drawRect(poleX + poleW, poleY, math.floor(size * 0.42), math.floor(size * 0.26), 1, 0.88, 0.04, 0.06)
    self:drawRect(poleX + poleW, poleY + math.floor(size * 0.26), math.floor(size * 0.27), math.max(2, math.floor(size * 0.11)), 1, 0.62, 0.02, 0.04)
    self:drawRect(px + math.floor(size * 0.24), py + math.floor(size * 0.78), math.floor(size * 0.52), math.max(2, math.floor(size * 0.09)), 1, 0.04, 0.04, 0.04)
end

function PZMinesweeperGame:drawMine(px, py, size, exploded)
    if exploded then
        self:drawRect(px + 2, py + 2, size - 4, size - 4, 1, 0.76, 0.08, 0.08)
    end
    local cx = px + math.floor(size * 0.5)
    local cy = py + math.floor(size * 0.5)
    local r = math.max(4, math.floor(size * 0.26))
    self:drawRect(cx - r, cy - r, r * 2, r * 2, 1, 0.03, 0.03, 0.035)
    self:drawRect(cx - 1, py + math.floor(size * 0.18), 2, math.floor(size * 0.64), 1, 0.03, 0.03, 0.035)
    self:drawRect(px + math.floor(size * 0.18), cy - 1, math.floor(size * 0.64), 2, 1, 0.03, 0.03, 0.035)
    self:drawRect(cx - math.floor(r * 0.7), cy - math.floor(r * 0.7), math.max(2, math.floor(r * 0.55)), math.max(2, math.floor(r * 0.45)), 0.85, 0.88, 0.88, 0.82)
end

function PZMinesweeperGame:drawHeaderBox(x, y, w, h, label, value, r, g, b)
    self:drawRect(x, y, w, h, 1, 0.08, 0.09, 0.10)
    self:drawRect(x + 2, y + 2, w - 4, h - 4, 1, 0.015, 0.025, 0.030)
    self:drawRect(x, y, w, 2, 1, r, g, b)
    self:drawText(label, x + 7, y + 4, 0.62, 0.70, 0.70, 1, UIFont.Small)
    self:drawText(value, x + 7, y + 17, r, g, b, 1, UIFont.Small)
end

function PZMinesweeperGame:drawStatusFace(x, y, size)
    self:drawRect(x, y, size, size, 1, 0.44, 0.46, 0.46)
    self:drawRect(x + 2, y + 2, size - 4, size - 4, 1, 0.92, 0.78, 0.18)
    local eyeY = y + math.floor(size * 0.33)
    self:drawRect(x + math.floor(size * 0.28), eyeY, 3, 3, 1, 0.04, 0.04, 0.04)
    self:drawRect(x + math.floor(size * 0.64), eyeY, 3, 3, 1, 0.04, 0.04, 0.04)
    if self.gameState == "WIN" then
        self:drawRect(x + math.floor(size * 0.24), y + math.floor(size * 0.62), math.floor(size * 0.52), 3, 1, 0.04, 0.24, 0.04)
        self:drawRect(x + math.floor(size * 0.30), y + math.floor(size * 0.66), math.floor(size * 0.40), 2, 1, 0.04, 0.24, 0.04)
    elseif self.gameState == "GAMEOVER" then
        self:drawRect(x + math.floor(size * 0.28), y + math.floor(size * 0.66), math.floor(size * 0.48), 2, 1, 0.24, 0.04, 0.04)
    else
        self:drawRect(x + math.floor(size * 0.30), y + math.floor(size * 0.63), math.floor(size * 0.40), 2, 1, 0.04, 0.04, 0.04)
        self:drawRect(x + math.floor(size * 0.30), y + math.floor(size * 0.63), 2, 3, 1, 0.04, 0.04, 0.04)
        self:drawRect(x + math.floor(size * 0.68), y + math.floor(size * 0.63), 2, 3, 1, 0.04, 0.04, 0.04)
    end
end

function PZMinesweeperGame:drawBackground()
    self:drawRect(0, 0, self.width, self.height, 1, 0.22, 0.25, 0.26)
    for i = 0, 10 do
        local y = i * self.height / 10
        self:drawRect(0, y, self.width, math.max(2, self.height / 12), 0.10, 0.38, 0.42, 0.42)
    end
    if self.flash and self.flash > 0 then
        self:drawRect(0, 0, self.width, self.height, self.flash / 40, 1, 0.06, 0.04)
    end
end

function PZMinesweeperGame:drawHeader()
    local _, headerH = self:getCellSize()
    self:drawRect(6, 6, self.width - 12, headerH - 12, 1, 0.36, 0.39, 0.39)
    self:drawRect(8, 8, self.width - 16, headerH - 16, 1, 0.50, 0.53, 0.53)
    local boxH = math.max(26, headerH - 20)
    local boxY = 12
    self:drawHeaderBox(14, boxY, 78, boxH, "MINES", string.format("%03d", math.max(0, self.mineCount - self.flags)), 1, 0.20, 0.20)
    self:drawHeaderBox(self.width - 92, boxY, 78, boxH, "TIME", string.format("%03d", self:getTimerSeconds()), 0.34, 0.95, 1)
    if self.bestTime then
        self:drawText("BEST " .. string.format("%03d", self.bestTime), self.width - 90, headerH - 15, 0.10, 0.16, 0.16, 1, UIFont.Small)
    end
    local faceSize = math.min(30, math.max(22, boxH))
    self:drawStatusFace(math.floor((self.width - faceSize) / 2), boxY, faceSize)
    if self.gameState == "WIN" then
        self:drawText("CLEARED", math.floor(self.width / 2) - 27, headerH - 15, 0.05, 0.34, 0.10, 1, UIFont.Small)
    elseif self.gameState == "GAMEOVER" then
        self:drawText("BOOM", math.floor(self.width / 2) - 17, headerH - 15, 0.42, 0.04, 0.04, 1, UIFont.Small)
    elseif self.firstClick then
        self:drawText("FIRST CLICK IS SAFE", math.floor(self.width / 2) - 58, headerH - 15, 0.10, 0.16, 0.16, 1, UIFont.Small)
    else
        self:drawText("SCANNING", math.floor(self.width / 2) - 30, headerH - 15, 0.10, 0.16, 0.16, 1, UIFont.Small)
    end
end

function PZMinesweeperGame:drawGrid()
    local ox, oy, cellSize = self:getGridOrigin()
    local gridW = self.cols * cellSize
    local gridH = self.rows * cellSize
    self:drawRect(ox - 6, oy - 6, gridW + 12, gridH + 12, 1, 0.13, 0.15, 0.16)
    self:drawRect(ox - 3, oy - 3, gridW + 6, gridH + 6, 1, 0.58, 0.62, 0.62)
    for y = 1, self.rows do
        for x = 1, self.cols do
            local px = ox + (x - 1) * cellSize
            local py = oy + (y - 1) * cellSize
            local cell = self.grid[y][x]
            self:drawCellFrame(px, py, cellSize - 1, not cell.revealed)
            if cell.revealed then
                if cell.mine then
                    self:drawMine(px, py, cellSize - 1, self.explodeX == x and self.explodeY == y)
                elseif cell.count > 0 then
                    self:drawMineNumber(cell.count, px, py, cellSize)
                else
                    self:drawRect(px + 4, py + 4, cellSize - 9, cellSize - 9, 0.18, 0.60, 0.70, 0.66)
                end
            elseif cell.flagged then
                self:drawFlag(px, py, cellSize - 1)
            end
        end
    end
    local selectedX = math.max(1, math.min(self.cols, tonumber(self.gamepadSelectionX) or 1))
    local selectedY = math.max(1, math.min(self.rows, tonumber(self.gamepadSelectionY) or 1))
    ComputerModGameInput.drawGamepadSelection(self, ox + (selectedX - 1) * cellSize, oy + (selectedY - 1) * cellSize, cellSize - 1, cellSize - 1)
end

function PZMinesweeperGame:drawFooter()
    if self.gameState ~= "PLAYING" then
        self:drawRect(0, self.height - 19, self.width, 19, 0.72, 0.05, 0.06, 0.065)
        self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. " OR CLICK TO RESTART", math.floor(self.width / 2) - 76, self.height - 16, 0.9, 0.95, 1, 1, UIFont.Small)
    else
        self:drawRect(0, self.height - 14, self.width, 14, 0.28, 0.05, 0.06, 0.065)
        local controls = ComputerModGameInput.hasGamepad(ComputerModGameInput.getPlayer(self)) and "A: REVEAL   X: FLAG" or "LEFT: REVEAL   RIGHT: FLAG"
        self:drawText(controls, math.floor(self.width / 2) - 82, self.height - 13, 0.76, 0.82, 0.82, 1, UIFont.Small)
    end
end

function PZMinesweeperGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.05, 0, 0, 0)
        y = y + 4
    end
end

function PZMinesweeperGame:prerender()
    self:drawBackground()
    self:drawHeader()
    self:drawGrid()
    self:drawFooter()
    self:drawScanlines()
end

function PZMinesweeperGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZMinesweeperGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaMinesweeper.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaTetris.lua
GameClasses['tetris'] = (function()
require "ISUI/ISPanel"

local PZTetrisGame = ISPanel:derive("PZTetrisGame")

local tetrisShapes = {
    I = {{{0,1}, {1,1}, {2,1}, {3,1}}, {{2,0}, {2,1}, {2,2}, {2,3}}},
    O = {{{1,0}, {2,0}, {1,1}, {2,1}}},
    T = {{{1,0}, {0,1}, {1,1}, {2,1}}, {{1,0}, {1,1}, {2,1}, {1,2}}, {{0,1}, {1,1}, {2,1}, {1,2}}, {{1,0}, {0,1}, {1,1}, {1,2}}},
    S = {{{1,0}, {2,0}, {0,1}, {1,1}}, {{1,0}, {1,1}, {2,1}, {2,2}}},
    Z = {{{0,0}, {1,0}, {1,1}, {2,1}}, {{2,0}, {1,1}, {2,1}, {1,2}}},
    J = {{{0,0}, {0,1}, {1,1}, {2,1}}, {{1,0}, {2,0}, {1,1}, {1,2}}, {{0,1}, {1,1}, {2,1}, {2,2}}, {{1,0}, {1,1}, {0,2}, {1,2}}},
    L = {{{2,0}, {0,1}, {1,1}, {2,1}}, {{1,0}, {1,1}, {1,2}, {2,2}}, {{0,1}, {1,1}, {2,1}, {0,2}}, {{0,0}, {1,0}, {1,1}, {1,2}}}
}

local tetrisShapeKeys = {"I", "O", "T", "S", "Z", "J", "L"}

local tetrisColors = {
    I = {r=0.20, g=0.72, b=0.82},
    O = {r=0.92, g=0.78, b=0.22},
    T = {r=0.56, g=0.34, b=0.72},
    S = {r=0.30, g=0.68, b=0.34},
    Z = {r=0.78, g=0.24, b=0.22},
    J = {r=0.24, g=0.36, b=0.74},
    L = {r=0.86, g=0.48, b=0.20}
}

function PZTetrisGame:initialise()
    ISPanel.initialise(self)
    self.cols = 10
    self.rows = 18
    self.highscore = 0
    self:resetGame()
end

function PZTetrisGame:resetGame()
    self.board = {}
    for y = 1, self.rows do
        self.board[y] = {}
        for x = 1, self.cols do
            self.board[y][x] = nil
        end
    end
    self.score = 0
    self.lines = 0
    self.level = 1
    self.tickCounter = 0
    self.moveDelay = 0
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.lineFlash = 0
    self.lockPulse = 0
    self.crtTick = 0
    self.nextType = self:getRandomType()
    self:spawnPiece()
end

function PZTetrisGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZTetrisGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZTetrisGame:getRandomType()
    return tetrisShapeKeys[ZombRand(#tetrisShapeKeys) + 1]
end

function PZTetrisGame:spawnPiece()
    self.currentType = self.nextType or self:getRandomType()
    self.nextType = self:getRandomType()
    self.rotation = 1
    self.pieceX = 4
    self.pieceY = 0
    if not self:canMove(self.pieceX, self.pieceY, self.rotation) then
        self.gameState = "GAMEOVER"
        if self.score > self.highscore then self.highscore = self.score end
        self:playGameOverSound()
    end
end

function PZTetrisGame:getBlocks(pieceType, rotation)
    local rotations = tetrisShapes[pieceType]
    return rotations[((rotation - 1) % #rotations) + 1]
end

function PZTetrisGame:canMove(px, py, rotation)
    local blocks = self:getBlocks(self.currentType, rotation)
    for i = 1, #blocks do
        local bx = px + blocks[i][1]
        local by = py + blocks[i][2]
        if bx < 1 or bx > self.cols or by > self.rows then return false end
        if by >= 1 and self.board[by][bx] then return false end
    end
    return true
end

function PZTetrisGame:movePiece(dx, dy)
    if self:canMove(self.pieceX + dx, self.pieceY + dy, self.rotation) then
        self.pieceX = self.pieceX + dx
        self.pieceY = self.pieceY + dy
        return true
    end
    return false
end

function PZTetrisGame:rotatePiece()
    local rotations = tetrisShapes[self.currentType]
    local nextRotation = (self.rotation % #rotations) + 1
    if self:canMove(self.pieceX, self.pieceY, nextRotation) then
        self.rotation = nextRotation
    elseif self:canMove(self.pieceX - 1, self.pieceY, nextRotation) then
        self.pieceX = self.pieceX - 1
        self.rotation = nextRotation
    elseif self:canMove(self.pieceX + 1, self.pieceY, nextRotation) then
        self.pieceX = self.pieceX + 1
        self.rotation = nextRotation
    end
end

function PZTetrisGame:getGhostY()
    local ghostY = self.pieceY
    while self:canMove(self.pieceX, ghostY + 1, self.rotation) do
        ghostY = ghostY + 1
    end
    return ghostY
end

function PZTetrisGame:lockPiece()
    local blocks = self:getBlocks(self.currentType, self.rotation)
    for i = 1, #blocks do
        local bx = self.pieceX + blocks[i][1]
        local by = self.pieceY + blocks[i][2]
        if by >= 1 and by <= self.rows and bx >= 1 and bx <= self.cols then
            self.board[by][bx] = self.currentType
        end
    end
    self.lockPulse = 6
    local cleared = self:clearLines()
    if cleared > 0 then
        self:playSound("ComputerWinOpen")
    end
    self:spawnPiece()
end

function PZTetrisGame:clearLines()
    local cleared = 0
    local y = self.rows
    while y >= 1 do
        local full = true
        for x = 1, self.cols do
            if not self.board[y][x] then
                full = false
                break
            end
        end
        if full then
            cleared = cleared + 1
            for yy = y, 2, -1 do
                for x = 1, self.cols do
                    self.board[yy][x] = self.board[yy - 1][x]
                end
            end
            for x = 1, self.cols do
                self.board[1][x] = nil
            end
        else
            y = y - 1
        end
    end
    if cleared > 0 then
        local points = {100, 300, 500, 800}
        self.score = self.score + points[cleared] * self.level
        self.lines = self.lines + cleared
        self.level = math.floor(self.lines / 8) + 1
        self.lineFlash = 8 + cleared * 4
    end
    return cleared
end

function PZTetrisGame:getDropSpeed()
    return math.max(4, 24 - self.level * 2)
end

function PZTetrisGame:update()
    self.crtTick = ((self.crtTick or 0) + 1) % 240
    self.lineFlash = math.max(0, (self.lineFlash or 0) - 1)
    self.lockPulse = math.max(0, (self.lockPulse or 0) - 1)

    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then self:resetGame() end
        return
    end

    if self.moveDelay > 0 then self.moveDelay = self.moveDelay - 1 end

    if self.moveDelay == 0 then
        if ComputerModGameInput.isDown(self, "left") then
            self:movePiece(-1, 0)
            self.moveDelay = 5
        elseif ComputerModGameInput.isDown(self, "right") then
            self:movePiece(1, 0)
            self.moveDelay = 5
        elseif ComputerModGameInput.isDown(self, "up") then
            self:rotatePiece()
            self.moveDelay = 8
        end
    end

    self.tickCounter = self.tickCounter + 1
    local speed = self:getDropSpeed()
    if ComputerModGameInput.isDown(self, "down") then speed = 2 end

    if self.tickCounter >= speed then
        self.tickCounter = 0
        if not self:movePiece(0, 1) then
            self:lockPiece()
        end
    end
end

function PZTetrisGame:getLayout()
    local margin = 10
    local gap = 12
    local panelW = math.min(112, math.max(82, math.floor(self.width * 0.23)))
    local usableW = math.max(1, self.width - panelW - gap - margin * 2)
    local usableH = math.max(1, self.height - margin * 2)
    local cell = math.max(6, math.floor(math.min(usableW / self.cols, usableH / self.rows)))
    local boardW = cell * self.cols
    local boardH = cell * self.rows
    local totalW = boardW + gap + panelW
    local ox = math.floor((self.width - totalW) / 2)
    local oy = math.floor((self.height - boardH) / 2)
    if ox < margin then ox = margin end
    if oy < margin then oy = margin end
    local panelX = ox + boardW + gap
    if panelX + panelW > self.width - margin then
        panelW = math.max(72, self.width - margin - panelX)
    end
    return ox, oy, cell, panelW, panelX, boardW, boardH
end

function PZTetrisGame:drawBackground()
    self:drawRect(0, 0, self.width, self.height, 1, 0.025, 0.027, 0.028)
    for i = 0, 12 do
        local y = i * self.height / 12
        self:drawRect(0, y, self.width, math.max(2, self.height / 16), 0.12, 0.10, 0.12, 0.12)
    end
    local glow = 0.025 + math.sin((self.crtTick or 0) / 20) * 0.012
    self:drawRect(0, 0, self.width, self.height, glow, 0.28, 0.45, 0.38)
end

function PZTetrisGame:drawBlock(x, y, cell, pieceType, alpha)
    local color = tetrisColors[pieceType] or {r=0.72, g=0.72, b=0.70}
    local a = alpha or 1
    local s = math.max(2, cell - 1)
    self:drawRect(x + 1, y + 2, s, s, a * 0.22, 0, 0, 0)
    self:drawRect(x, y, s, s, a, color.r, color.g, color.b)
    self:drawRect(x + 2, y + 2, math.max(1, s - 4), math.max(1, math.floor(s * 0.32)), a * 0.30, 1, 1, 1)
    self:drawRect(x, y, s, 2, a * 0.45, 1, 1, 1)
    self:drawRect(x, y, 2, s, a * 0.28, 1, 1, 1)
    self:drawRect(x + s - 2, y, 2, s, a * 0.24, 0, 0, 0)
    self:drawRect(x, y + s - 2, s, 2, a * 0.28, 0, 0, 0)
end

function PZTetrisGame:drawMiniPiece(pieceType, x, y, cell)
    local blocks = self:getBlocks(pieceType, 1)
    for i = 1, #blocks do
        self:drawBlock(x + blocks[i][1] * cell, y + blocks[i][2] * cell, cell, pieceType, 1)
    end
end

function PZTetrisGame:drawBoard(ox, oy, cell, boardW, boardH)
    self:drawRect(ox - 5, oy - 5, boardW + 10, boardH + 10, 1, 0.10, 0.11, 0.11)
    self:drawRect(ox - 3, oy - 3, boardW + 6, boardH + 6, 1, 0.43, 0.45, 0.42)
    self:drawRect(ox, oy, boardW, boardH, 1, 0.035, 0.038, 0.040)
    if self.lineFlash and self.lineFlash > 0 then
        self:drawRect(ox, oy, boardW, boardH, self.lineFlash / 80, 0.86, 0.92, 0.74)
    elseif self.lockPulse and self.lockPulse > 0 then
        self:drawRect(ox, oy, boardW, boardH, self.lockPulse / 130, 0.72, 0.82, 0.88)
    end
    for y = 1, self.rows do
        for x = 1, self.cols do
            local px = ox + (x - 1) * cell
            local py = oy + (y - 1) * cell
            self:drawRect(px, py, cell - 1, cell - 1, 0.12, 0.22, 0.25, 0.25)
            if self.board[y][x] then
                self:drawBlock(px, py, cell, self.board[y][x], 1)
            end
        end
    end
end

function PZTetrisGame:drawGhostPiece(ox, oy, cell)
    if self.gameState ~= "PLAYING" then return end
    local ghostY = self:getGhostY()
    local blocks = self:getBlocks(self.currentType, self.rotation)
    for i = 1, #blocks do
        local bx = self.pieceX + blocks[i][1]
        local by = ghostY + blocks[i][2]
        if by >= 1 then
            local px = ox + (bx - 1) * cell
            local py = oy + (by - 1) * cell
            self:drawRect(px + 2, py + 2, math.max(2, cell - 5), 2, 0.36, 0.82, 0.88, 0.78)
            self:drawRect(px + 2, py + cell - 5, math.max(2, cell - 5), 2, 0.25, 0.82, 0.88, 0.78)
            self:drawRect(px + 2, py + 2, 2, math.max(2, cell - 5), 0.25, 0.82, 0.88, 0.78)
            self:drawRect(px + cell - 5, py + 2, 2, math.max(2, cell - 5), 0.25, 0.82, 0.88, 0.78)
        end
    end
end

function PZTetrisGame:drawCurrentPiece(ox, oy, cell)
    if self.gameState ~= "PLAYING" then return end
    local blocks = self:getBlocks(self.currentType, self.rotation)
    for i = 1, #blocks do
        local bx = self.pieceX + blocks[i][1]
        local by = self.pieceY + blocks[i][2]
        if by >= 1 then
            self:drawBlock(ox + (bx - 1) * cell, oy + (by - 1) * cell, cell, self.currentType, 1)
        end
    end
end

function PZTetrisGame:drawPanel(panelX, oy, panelW, boardH, cell)
    self:drawRect(panelX - 1, oy - 1, panelW + 2, boardH + 2, 1, 0.34, 0.34, 0.30)
    self:drawRect(panelX, oy, panelW, boardH, 1, 0.012, 0.014, 0.012)
    self:drawRect(panelX + 5, oy + 20, panelW - 10, 1, 1, 0.26, 0.34, 0.24)
    self:drawText("TETRIS.EXE", panelX + 7, oy + 5, 0.66, 0.82, 0.56, 1, UIFont.Small)

    local y = oy + 28
    self:drawText("SCORE", panelX + 7, y, 0.48, 0.58, 0.44, 1, UIFont.Small)
    self:drawText(tostring(self.score), panelX + 7, y + 14, 0.78, 0.92, 0.62, 1, UIFont.Small)

    y = y + 44
    self:drawText("LINES " .. tostring(self.lines), panelX + 7, y, 0.66, 0.82, 0.56, 1, UIFont.Small)

    y = y + 22
    self:drawText("LEVEL " .. tostring(self.level), panelX + 7, y, 0.66, 0.82, 0.56, 1, UIFont.Small)

    y = y + 32
    self:drawText("NEXT", panelX + 7, y, 0.48, 0.58, 0.44, 1, UIFont.Small)
    self:drawRect(panelX + 7, y + 15, panelW - 14, 50, 1, 0.006, 0.008, 0.006)
    self:drawRect(panelX + 7, y + 15, panelW - 14, 1, 1, 0.22, 0.26, 0.20)
    local mini = math.max(6, math.min(12, math.floor(cell * 0.68)))
    self:drawMiniPiece(self.nextType, panelX + math.floor(panelW * 0.24), y + 23, mini)

    self:drawRect(panelX + 5, oy + boardH - 34, panelW - 10, 1, 1, 0.26, 0.34, 0.24)
    self:drawText(ComputerModGameInput.getInputLabel(self, "up") .. "=ROT", panelX + 7, oy + boardH - 27, 0.44, 0.54, 0.42, 1, UIFont.Small)
    self:drawText("DN=DROP", panelX + 7, oy + boardH - 14, 0.44, 0.54, 0.42, 1, UIFont.Small)
end

function PZTetrisGame:drawTerminalOverlay(ox, oy, boardW, boardH)
    local boxW = math.min(boardW - 18, 170)
    local boxH = 92
    local boxX = math.floor(ox + (boardW - boxW) / 2)
    local boxY = math.floor(oy + (boardH - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.08, 0.08, 0.06)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.008, 0.006)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.30, 0.34, 0.24)
    self:drawText("TETRIS.EXE HALTED", boxX + 9, boxY + 19, 0.66, 0.82, 0.56, 1, UIFont.Small)
    self:drawText("STACK FULL", boxX + 9, boxY + 41, 0.82, 0.72, 0.46, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), boxX + 9, boxY + 58, 0.66, 0.82, 0.56, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 9, boxY + 76, 0.72, 0.72, 0.50, 1, UIFont.Small)
end

function PZTetrisGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.05, 0, 0, 0)
        y = y + 4
    end
end

function PZTetrisGame:prerender()
    self:drawBackground()

    local ox, oy, cell, panelW, panelX, boardW, boardH = self:getLayout()
    self:drawBoard(ox, oy, cell, boardW, boardH)
    self:drawGhostPiece(ox, oy, cell)
    self:drawCurrentPiece(ox, oy, cell)
    self:drawPanel(panelX, oy, panelW, boardH, cell)

    if self.gameState == "GAMEOVER" then
        self:drawTerminalOverlay(ox, oy, boardW, boardH)
    end

    self:drawScanlines()
end

function PZTetrisGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZTetrisGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaTetris.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaSpaceInvaders.lua
GameClasses['space_invaders'] = (function()
require "ISUI/ISPanel"

local PZSpaceInvadersGame = ISPanel:derive("PZSpaceInvadersGame")

function PZSpaceInvadersGame:initialise()
    ISPanel.initialise(self)
    self.highscore = 0
    self:buildStarfield()
    self:resetGame()
end

function PZSpaceInvadersGame:buildStarfield()
    self.stars = {}
    for i = 1, 42 do
        self.stars[#self.stars + 1] = {
            x = ZombRand(1000) / 1000,
            y = ZombRand(1000) / 1000,
            s = 1 + ZombRand(2),
            a = 0.25 + ZombRand(55) / 100
        }
    end
end

function PZSpaceInvadersGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.score = 0
    self.fireCooldown = 0
    self.enemyFireTimer = 0
    self.moveTick = 0
    self.crtTick = 0
    self.playerHitFlash = 0
    self.invaderDir = 1
    self.invaderSpeed = 18
    self.player = {x = 0.5, y = 0.895, width = 0.086, height = 0.034, speed = 0.021, lives = 3}
    self.playerBullets = {}
    self.enemyBullets = {}
    self.invaders = {}
    self.particles = {}

    for row = 1, 4 do
        for col = 1, 7 do
            table.insert(self.invaders, {
                x = 0.12 + (col - 1) * 0.1,
                y = 0.13 + (row - 1) * 0.08,
                width = 0.055,
                height = 0.037,
                alive = true,
                row = row,
                phase = row * 3 + col
            })
        end
    end
end

function PZSpaceInvadersGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZSpaceInvadersGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZSpaceInvadersGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZSpaceInvadersGame:clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function PZSpaceInvadersGame:rectsOverlap(a, b)
    return a.x < b.x + b.width and a.x + a.width > b.x and a.y < b.y + b.height and a.y + a.height > b.y
end

function PZSpaceInvadersGame:firePlayerBullet()
    self:playSound("ComputerLaserShot")
    table.insert(self.playerBullets, {
        x = self.player.x + self.player.width * 0.5 - 0.004,
        y = self.player.y - 0.018,
        width = 0.008,
        height = 0.023,
        speed = 0.027
    })
end

function PZSpaceInvadersGame:fireEnemyBullet()
    local columns = {}
    for i = 1, #self.invaders do
        local invader = self.invaders[i]
        if invader.alive then
            local key = math.floor(invader.x * 1000 + 0.5)
            local current = columns[key]
            if not current or invader.y > current.y then
                columns[key] = invader
            end
        end
    end

    local candidates = {}
    for _, invader in pairs(columns) do
        table.insert(candidates, invader)
    end
    if #candidates == 0 then return end

    local shooter = candidates[ZombRand(#candidates) + 1]
    table.insert(self.enemyBullets, {
        x = shooter.x + shooter.width * 0.5 - 0.004,
        y = shooter.y + shooter.height + 0.006,
        width = 0.008,
        height = 0.022,
        speed = 0.014 + ZombRand(4) * 0.001
    })
end

function PZSpaceInvadersGame:emitExplosion(x, y, r, g, b, count)
    for i = 1, count do
        local life = 14 + ZombRand(18)
        self.particles[#self.particles + 1] = {
            x = x,
            y = y,
            vx = (ZombRand(1000) - 500) / 32000,
            vy = (ZombRand(1000) - 500) / 32000,
            r = r,
            g = g,
            b = b,
            life = life,
            maxLife = life
        }
    end
end

function PZSpaceInvadersGame:updateParticles()
    if not self.particles then self.particles = {} end
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.x = p.x + p.vx
        p.y = p.y + p.vy
        p.vx = p.vx * 0.94
        p.vy = p.vy * 0.94
        p.life = p.life - 1
        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end
end

function PZSpaceInvadersGame:updateInvaders()
    self.moveTick = self.moveTick + 1
    if self.moveTick < self.invaderSpeed then return end
    self.moveTick = 0

    local step = 0.015 * self.invaderDir
    local turn = false
    for i = 1, #self.invaders do
        local invader = self.invaders[i]
        if invader.alive then
            local nextX = invader.x + step
            if nextX < 0.055 or nextX + invader.width > 0.945 then
                turn = true
                break
            end
        end
    end

    for i = 1, #self.invaders do
        local invader = self.invaders[i]
        if invader.alive then
            if turn then
                invader.y = invader.y + 0.03
            else
                invader.x = invader.x + step
            end
        end
    end

    if turn then self.invaderDir = -self.invaderDir end
    if self.invaderSpeed > 8 then self.invaderSpeed = math.max(8, self.invaderSpeed - 0.15) end
end

function PZSpaceInvadersGame:updateBullets()
    for i = #self.playerBullets, 1, -1 do
        local bullet = self.playerBullets[i]
        bullet.y = bullet.y - bullet.speed
        if bullet.y + bullet.height < 0 then
            table.remove(self.playerBullets, i)
        else
            for j = 1, #self.invaders do
                local invader = self.invaders[j]
                if invader.alive and self:rectsOverlap(bullet, invader) then
                    invader.alive = false
                    self.score = self.score + (60 - invader.row * 10)
                    self:emitExplosion(invader.x + invader.width * 0.5, invader.y + invader.height * 0.5, 0.34, 0.88, 0.42, 12)
                    self:playSound("ComputerBallHit")
                    table.remove(self.playerBullets, i)
                    break
                end
            end
        end
    end

    for i = #self.enemyBullets, 1, -1 do
        local bullet = self.enemyBullets[i]
        bullet.y = bullet.y + bullet.speed
        if bullet.y > 1 then
            table.remove(self.enemyBullets, i)
        elseif self:rectsOverlap(bullet, self.player) then
            table.remove(self.enemyBullets, i)
            self.player.lives = self.player.lives - 1
            self.playerHitFlash = 10
            self:emitExplosion(self.player.x + self.player.width * 0.5, self.player.y + self.player.height * 0.5, 0.92, 0.34, 0.24, 16)
            if self.player.lives <= 0 then
                self.gameState = "GAMEOVER"
                if self.score > self.highscore then self.highscore = self.score end
                self:playGameOverSound()
            end
        end
    end
end

function PZSpaceInvadersGame:update()
    self.crtTick = ((self.crtTick or 0) + 1) % 240
    self.playerHitFlash = math.max(0, (self.playerHitFlash or 0) - 1)
    self:updateParticles()

    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then self:resetGame() end
        return
    end

    if ComputerModGameInput.isDown(self, "left") then
        self.player.x = self:clamp(self.player.x - self.player.speed, 0.04, 0.96 - self.player.width)
    elseif ComputerModGameInput.isDown(self, "right") then
        self.player.x = self:clamp(self.player.x + self.player.speed, 0.04, 0.96 - self.player.width)
    end

    if self.fireCooldown > 0 then self.fireCooldown = self.fireCooldown - 1 end
    if ComputerModGameInput.isDown(self, "action") and self.fireCooldown == 0 then
        self:firePlayerBullet()
        self.fireCooldown = 10
    end

    self.enemyFireTimer = self.enemyFireTimer + 1
    if self.enemyFireTimer >= 36 then
        self.enemyFireTimer = 0
        self:fireEnemyBullet()
    end

    self:updateInvaders()
    self:updateBullets()

    local aliveCount = 0
    for i = 1, #self.invaders do
        local invader = self.invaders[i]
        if invader.alive then
            aliveCount = aliveCount + 1
            if invader.y + invader.height >= self.player.y then
                self.gameState = "GAMEOVER"
                if self.score > self.highscore then self.highscore = self.score end
                self:playGameOverSound()
                return
            end
        end
    end

    if aliveCount == 0 then
        self.gameState = "WIN"
        if self.score > self.highscore then self.highscore = self.score end
        self:playWinSound()
    end
end

function PZSpaceInvadersGame:drawScaledRect(x, y, w, h, a, r, g, b)
    self:drawRect(x * self.width, y * self.height, w * self.width, h * self.height, a, r, g, b)
end

function PZSpaceInvadersGame:drawBackground()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.008, 0.018)
    for i = 0, 11 do
        local y = i * self.height / 11
        self:drawRect(0, y, self.width, math.max(2, self.height / 20), 0.10, 0.05, 0.09, 0.14)
    end
    local stars = self.stars or {}
    for i = 1, #stars do
        local star = stars[i]
        local twinkle = 0.65 + math.sin(((self.crtTick or 0) + i * 11) / 22) * 0.24
        self:drawRect(star.x * self.width, star.y * self.height, star.s, star.s, star.a * twinkle, 0.68, 0.82, 0.72)
    end
    self:drawRect(0, self.height * 0.075, self.width, 1, 0.28, 0.20, 0.62, 0.52)
    self:drawRect(0, self.height * 0.845, self.width, 2, 0.30, 0.20, 0.62, 0.52)
end

function PZSpaceInvadersGame:drawHud()
    self:drawRect(0, 0, self.width, 28, 1, 0.004, 0.006, 0.014)
    self:drawRect(0, 27, self.width, 1, 1, 0.20, 0.30, 0.24)
    self:drawText("1UP", 14, 5, 0.66, 0.88, 0.66, 1, UIFont.Small)
    self:drawText(tostring(self.score), 14, 17, 0.82, 0.90, 0.70, 1, UIFont.Small)
    self:drawText("HI-SCORE", math.floor(self.width * 0.5) - 34, 5, 0.66, 0.88, 0.66, 1, UIFont.Small)
    self:drawText(tostring(math.max(self.highscore, self.score)), math.floor(self.width * 0.5) - 12, 17, 0.82, 0.90, 0.70, 1, UIFont.Small)
    local lx = self.width - 56
    self:drawText("LIVES", lx - 34, 5, 0.66, 0.88, 0.66, 1, UIFont.Small)
    for i = 1, self.player.lives do
        self:drawRect(lx + (i - 1) * 12, 17, 8, 6, 1, 0.66, 0.88, 0.66)
    end
end

function PZSpaceInvadersGame:drawInvader(invader)
    local x = invader.x
    local y = invader.y
    local w = invader.width
    local h = invader.height
    local step = math.sin(((self.crtTick or 0) + invader.phase * 7) / 10) > 0 and 1 or 0
    local tint = 0.88 - (invader.row - 1) * 0.12
    local r, g, b = 0.18, tint, 0.36
    self:drawScaledRect(x + w * 0.18, y, w * 0.64, h * 0.18, 1, r, g, b)
    self:drawScaledRect(x + w * 0.08, y + h * 0.18, w * 0.84, h * 0.48, 1, r, math.min(1, g + 0.08), b)
    self:drawScaledRect(x, y + h * 0.38, w, h * 0.20, 1, r, g, b)
    self:drawScaledRect(x + w * 0.14, y + h * 0.68, w * 0.18, h * 0.20, 1, r, g, b)
    self:drawScaledRect(x + w * 0.68, y + h * 0.68, w * 0.18, h * 0.20, 1, r, g, b)
    if step == 0 then
        self:drawScaledRect(x + w * 0.02, y + h * 0.78, w * 0.16, h * 0.16, 1, r, g, b)
        self:drawScaledRect(x + w * 0.82, y + h * 0.78, w * 0.16, h * 0.16, 1, r, g, b)
    else
        self:drawScaledRect(x + w * 0.24, y + h * 0.80, w * 0.16, h * 0.14, 1, r, g, b)
        self:drawScaledRect(x + w * 0.60, y + h * 0.80, w * 0.16, h * 0.14, 1, r, g, b)
    end
    self:drawScaledRect(x + w * 0.24, y + h * 0.33, w * 0.12, h * 0.12, 1, 0.006, 0.012, 0.016)
    self:drawScaledRect(x + w * 0.64, y + h * 0.33, w * 0.12, h * 0.12, 1, 0.006, 0.012, 0.016)
end

function PZSpaceInvadersGame:drawPlayer()
    local flash = (self.playerHitFlash or 0) > 0
    local r, g, b = 0.52, 0.78, 0.82
    if flash then r, g, b = 1, 0.42, 0.30 end
    local x = self.player.x
    local y = self.player.y
    local w = self.player.width
    local h = self.player.height
    self:drawScaledRect(x, y + h * 0.55, w, h * 0.34, 1, 0.18, 0.34, 0.36)
    self:drawScaledRect(x + w * 0.13, y + h * 0.33, w * 0.74, h * 0.42, 1, r, g, b)
    self:drawScaledRect(x + w * 0.40, y, w * 0.20, h * 0.52, 1, 0.82, 0.92, 0.86)
    self:drawScaledRect(x + w * 0.46, y - h * 0.34, w * 0.08, h * 0.42, 1, 0.84, 0.92, 0.86)
end

function PZSpaceInvadersGame:drawBullets()
    for i = 1, #self.playerBullets do
        local bullet = self.playerBullets[i]
        self:drawScaledRect(bullet.x - 0.003, bullet.y, bullet.width + 0.006, bullet.height, 0.25, 0.80, 0.95, 0.62)
        self:drawScaledRect(bullet.x, bullet.y, bullet.width, bullet.height, 1, 0.92, 0.94, 0.46)
    end

    for i = 1, #self.enemyBullets do
        local bullet = self.enemyBullets[i]
        self:drawScaledRect(bullet.x - 0.002, bullet.y, bullet.width + 0.004, bullet.height, 0.32, 0.92, 0.22, 0.18)
        self:drawScaledRect(bullet.x, bullet.y, bullet.width, bullet.height, 1, 0.90, 0.28, 0.24)
    end
end

function PZSpaceInvadersGame:drawParticles()
    local particles = self.particles or {}
    for i = 1, #particles do
        local p = particles[i]
        local alpha = math.max(0, p.life / p.maxLife)
        local size = math.max(2, math.floor(2 + alpha * 3))
        self:drawRect(p.x * self.width, p.y * self.height, size, size, alpha, p.r, p.g, p.b)
    end
end

function PZSpaceInvadersGame:drawTerminalOverlay(title, detail, r, g, b)
    local boxW = math.min(self.width - 40, 230)
    local boxH = 94
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.05, 0.07, 0.06)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.004, 0.008, 0.012)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.20, 0.32, 0.24)
    self:drawText("INVADERS.SYS", boxX + 10, boxY + 18, 0.66, 0.88, 0.66, 1, UIFont.Small)
    self:drawText(title, boxX + 10, boxY + 38, r, g, b, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 56, 0.72, 0.82, 0.66, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 76, 0.78, 0.76, 0.52, 1, UIFont.Small)
end

function PZSpaceInvadersGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.06, 0, 0, 0)
        y = y + 4
    end
end

function PZSpaceInvadersGame:prerender()
    self:drawBackground()
    self:drawHud()

    for i = 1, #self.invaders do
        local invader = self.invaders[i]
        if invader.alive then
            self:drawInvader(invader)
        end
    end

    self:drawPlayer()
    self:drawBullets()
    self:drawParticles()

    if self.gameState == "WIN" then
        self:drawTerminalOverlay("SECTOR CLEARED", "SCORE " .. tostring(self.score), 0.46, 0.96, 0.56)
    elseif self.gameState == "GAMEOVER" then
        self:drawTerminalOverlay("DEFENSE FAILED", "BEST " .. tostring(math.max(self.highscore, self.score)), 0.96, 0.48, 0.38)
    end

    self:drawScanlines()
end

function PZSpaceInvadersGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZSpaceInvadersGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaSpaceInvaders.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaDoom.lua
GameClasses['doom'] = (function()
require "ISUI/ISPanel"

local PZDoomGame = ISPanel:derive("PZDoomGame")

local doomMap = {
    "1111111111111111",
    "1000000000000001",
    "1011110111111101",
    "1000010100000101",
    "1111010101110101",
    "1000010001010001",
    "1011111101011111",
    "1010000001000001",
    "1010111111011101",
    "1010100000010101",
    "1010101111010101",
    "1010001000010001",
    "1011101011110111",
    "1000001000000001",
    "1000001000000201",
    "1111111111111111"
}

local doomEnemies = {
    {x = 4.5, y = 3.5, hp = 2},
    {x = 11.5, y = 3.5, hp = 2},
    {x = 7.5, y = 7.5, hp = 3},
    {x = 12.5, y = 9.5, hp = 2},
    {x = 4.5, y = 13.5, hp = 3},
    {x = 12.5, y = 13.5, hp = 2}
}

local doomMedkits = {
    {x = 2.5, y = 13.5},
    {x = 10.5, y = 7.5},
    {x = 13.5, y = 11.5}
}

local function atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi * 0.5 end
    if x == 0 and y < 0 then return -math.pi * 0.5 end
    return 0
end

function PZDoomGame:initialise()
    ISPanel.initialise(self)
    self.mapWidth = #doomMap[1]
    self.mapHeight = #doomMap
    self.fieldOfView = math.rad(70)
    self.maxDepth = 18
    self.rayStep = 0.035
    self.highscore = 0
    self:resetGame()
end

function PZDoomGame:resetGame()
    self.gameState = "PLAYING"
    self.score = 0
    self.damageFlash = 0
    self.muzzleFlash = 0
    self.fireCooldown = 0
    self.crtTick = 0
    self.lastSpaceDown = false
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.player = {
        x = 1.75,
        y = 1.75,
        angle = 0,
        health = 100,
        radius = 0.18,
        moveSpeed = 0.09,
        strafeSpeed = 0.075,
        turnSpeed = 0.065
    }
    self.enemies = {}
    self.medkits = {}
    for i = 1, #doomEnemies do
        local enemy = doomEnemies[i]
        self.enemies[i] = {
            x = enemy.x,
            y = enemy.y,
            hp = enemy.hp,
            cooldown = ZombRand(20),
            alive = true,
            hitFlash = 0
        }
    end
    for i = 1, #doomMedkits do
        local kit = doomMedkits[i]
        self.medkits[i] = {x = kit.x, y = kit.y, used = false}
    end
    self.totalEnemies = #self.enemies
end

function PZDoomGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZDoomGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZDoomGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZDoomGame:isWall(x, y)
    local cellX = math.floor(x) + 1
    local cellY = math.floor(y) + 1
    if cellX < 1 or cellY < 1 or cellX > self.mapWidth or cellY > self.mapHeight then return true end
    return doomMap[cellY]:sub(cellX, cellX) == "1"
end

function PZDoomGame:isExit(x, y)
    local cellX = math.floor(x) + 1
    local cellY = math.floor(y) + 1
    if cellX < 1 or cellY < 1 or cellX > self.mapWidth or cellY > self.mapHeight then return false end
    return doomMap[cellY]:sub(cellX, cellX) == "2"
end

function PZDoomGame:normalizeAngle(angle)
    while angle <= -math.pi do angle = angle + math.pi * 2 end
    while angle > math.pi do angle = angle - math.pi * 2 end
    return angle
end

function PZDoomGame:clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function PZDoomGame:drawClippedRect(x, y, width, height, a, r, g, b)
    local clippedX = math.max(0, math.floor(x))
    local clippedY = math.max(0, math.floor(y))
    local clippedW = math.ceil(x + width) - clippedX
    local clippedH = math.ceil(y + height) - clippedY

    if clippedX >= self.width or clippedY >= self.height then return end
    if clippedX + clippedW > self.width then
        clippedW = self.width - clippedX
    end
    if clippedY + clippedH > self.height then
        clippedH = self.height - clippedY
    end
    if clippedW <= 0 or clippedH <= 0 then return end

    self:drawRect(clippedX, clippedY, clippedW, clippedH, a, r, g, b)
end

function PZDoomGame:projectPoint(worldX, worldY)
    local dx = worldX - self.player.x
    local dy = worldY - self.player.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local angle = self:normalizeAngle(atan2(dy, dx) - self.player.angle)
    local correctedDistance = distance * math.cos(angle)
    return distance, angle, correctedDistance
end

function PZDoomGame:canMoveTo(x, y)
    local r = self.player.radius
    return not self:isWall(x - r, y - r)
        and not self:isWall(x + r, y - r)
        and not self:isWall(x - r, y + r)
        and not self:isWall(x + r, y + r)
end

function PZDoomGame:movePlayer(forwardMove, strafeMove)
    local sinA = math.sin(self.player.angle)
    local cosA = math.cos(self.player.angle)
    local targetX = self.player.x + cosA * forwardMove + math.cos(self.player.angle + math.pi * 0.5) * strafeMove
    local targetY = self.player.y + sinA * forwardMove + math.sin(self.player.angle + math.pi * 0.5) * strafeMove

    if self:canMoveTo(targetX, self.player.y) then
        self.player.x = targetX
    end
    if self:canMoveTo(self.player.x, targetY) then
        self.player.y = targetY
    end
end

function PZDoomGame:lineBlocked(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local steps = math.max(1, math.floor(math.max(math.abs(dx), math.abs(dy)) / 0.08))
    for i = 1, steps do
        local t = i / steps
        local sx = x1 + dx * t
        local sy = y1 + dy * t
        if self:isWall(sx, sy) then
            return true
        end
    end
    return false
end

function PZDoomGame:getAliveEnemies()
    local alive = 0
    for i = 1, #self.enemies do
        if self.enemies[i].alive then
            alive = alive + 1
        end
    end
    return alive
end

function PZDoomGame:shoot()
    if self.fireCooldown > 0 then return end
    self.fireCooldown = 8
    self.muzzleFlash = 3
    self:playSound("ComputerDoomGun")

    local bestEnemy = nil
    local bestDistance = 999
    for i = 1, #self.enemies do
        local enemy = self.enemies[i]
        if enemy.alive then
            local dx = enemy.x - self.player.x
            local dy = enemy.y - self.player.y
            local distance = math.sqrt(dx * dx + dy * dy)
            local angle = self:normalizeAngle(atan2(dy, dx) - self.player.angle)
            if distance < bestDistance and math.abs(angle) < 0.12 and not self:lineBlocked(self.player.x, self.player.y, enemy.x, enemy.y) then
                bestDistance = distance
                bestEnemy = enemy
            end
        end
    end

    if bestEnemy then
        bestEnemy.hp = bestEnemy.hp - 1
        bestEnemy.hitFlash = 5
        if bestEnemy.hp <= 0 then
            bestEnemy.alive = false
            self.score = self.score + 100
        else
            self.score = self.score + 25
        end
    end
end

function PZDoomGame:updateEnemies()
    for i = 1, #self.enemies do
        local enemy = self.enemies[i]
        if enemy.alive then
            if enemy.cooldown > 0 then enemy.cooldown = enemy.cooldown - 1 end
            if enemy.hitFlash > 0 then enemy.hitFlash = enemy.hitFlash - 1 end

            local dx = self.player.x - enemy.x
            local dy = self.player.y - enemy.y
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance > 0.9 and not self:lineBlocked(enemy.x, enemy.y, self.player.x, self.player.y) then
                local moveX = dx / distance * 0.025
                local moveY = dy / distance * 0.025
                local testX = enemy.x + moveX
                local testY = enemy.y + moveY
                if not self:isWall(testX, enemy.y) then
                    enemy.x = testX
                end
                if not self:isWall(enemy.x, testY) then
                    enemy.y = testY
                end
            end

            if distance <= 1.05 and enemy.cooldown == 0 then
                enemy.cooldown = 28
                self.player.health = self.player.health - 8
                self.damageFlash = 7
                if self.player.health <= 0 then
                    self.player.health = 0
                    self.gameState = "GAMEOVER"
                    if self.score > self.highscore then self.highscore = self.score end
                    self:playGameOverSound()
                end
            end
        end
    end
end

function PZDoomGame:updateMedkits()
    for i = 1, #self.medkits do
        local kit = self.medkits[i]
        if not kit.used then
            local dx = self.player.x - kit.x
            local dy = self.player.y - kit.y
            if dx * dx + dy * dy < 0.22 then
                kit.used = true
                self.player.health = math.min(100, self.player.health + 25)
                self.score = self.score + 15
            end
        end
    end
end

function PZDoomGame:castRay(angle)
    local distance = 0
    local hitX = self.player.x
    local hitY = self.player.y
    while distance < self.maxDepth do
        distance = distance + self.rayStep
        hitX = self.player.x + math.cos(angle) * distance
        hitY = self.player.y + math.sin(angle) * distance
        if self:isWall(hitX, hitY) then
            break
        end
    end

    local localX = hitX - math.floor(hitX)
    local localY = hitY - math.floor(hitY)
    local edgeDistance = math.min(localX, 1 - localX, localY, 1 - localY)
    local shade = edgeDistance < 0.08 and 0.94 or 0.78
    if distance >= self.maxDepth then shade = 0.18 end
    return distance, shade
end

function PZDoomGame:update()
    self.crtTick = ((self.crtTick or 0) + 1) % 240

    if self.gameState ~= "PLAYING" then
        local resetPressed = ComputerModGameInput.isDown(self, "action") or ComputerModGameInput.isDown(self, "secondary")
        if resetPressed and not self.lastSpaceDown then
            self:resetGame()
        end
        self.lastSpaceDown = resetPressed
        return
    end

    if ComputerModGameInput.isDown(self, "left") then
        self.player.angle = self:normalizeAngle(self.player.angle - self.player.turnSpeed)
    end
    if ComputerModGameInput.isDown(self, "right") then
        self.player.angle = self:normalizeAngle(self.player.angle + self.player.turnSpeed)
    end

    local forwardMove = 0
    local strafeMove = 0
    if ComputerModGameInput.isDown(self, "forward") or ComputerModGameInput.isDown(self, "up") then
        forwardMove = forwardMove + self.player.moveSpeed
    end
    if ComputerModGameInput.isDown(self, "backward") or ComputerModGameInput.isDown(self, "down") then
        forwardMove = forwardMove - self.player.moveSpeed
    end
    if ComputerModGameInput.isDown(self, "strafeLeft") then
        strafeMove = strafeMove - self.player.strafeSpeed
    end
    if ComputerModGameInput.isDown(self, "strafeRight") then
        strafeMove = strafeMove + self.player.strafeSpeed
    end
    if forwardMove ~= 0 or strafeMove ~= 0 then
        self:movePlayer(forwardMove, strafeMove)
    end

    local shootPressed = ComputerModGameInput.isDown(self, "action")
    if shootPressed and not self.lastSpaceDown then
        self:shoot()
    end
    self.lastSpaceDown = shootPressed

    if self.fireCooldown > 0 then self.fireCooldown = self.fireCooldown - 1 end
    if self.damageFlash > 0 then self.damageFlash = self.damageFlash - 1 end
    if self.muzzleFlash > 0 then self.muzzleFlash = self.muzzleFlash - 1 end

    self:updateEnemies()
    self:updateMedkits()

    if self:getAliveEnemies() == 0 and self:isExit(self.player.x, self.player.y) then
        self.gameState = "WIN"
        self.score = self.score + 250
        if self.score > self.highscore then self.highscore = self.score end
        self:playWinSound()
    end
end

function PZDoomGame:drawWeapon()
    local baseX = math.floor(self.width * 0.5)
    local baseY = self.height - 74
    local bob = self.fireCooldown % 2
    self:drawClippedRect(baseX - 34, baseY + 8 + bob, 68, 28, 1, 0.18, 0.18, 0.2)
    self:drawClippedRect(baseX - 12, baseY - 4 + bob, 24, 36, 1, 0.42, 0.42, 0.46)
    self:drawClippedRect(baseX - 6, baseY - 16 + bob, 12, 18, 1, 0.62, 0.62, 0.66)
    self:drawClippedRect(baseX - 2, baseY - 26 + bob, 4, 14, 1, 0.85, 0.85, 0.88)
    if self.muzzleFlash > 0 then
        self:drawClippedRect(baseX - 12, baseY - 34, 24, 16, 1, 1, 0.78, 0.12)
        self:drawClippedRect(baseX - 6, baseY - 44, 12, 12, 1, 1, 0.3, 0.1)
    end
end

function PZDoomGame:drawMinimap()
    local cell = 4
    local mapW = self.mapWidth * cell
    local mapH = self.mapHeight * cell
    local ox = self.width - mapW - 12
    local oy = 12

    self:drawClippedRect(ox - 3, oy - 3, mapW + 6, mapH + 6, 0.9, 0.02, 0.02, 0.02)
    for my = 1, self.mapHeight do
        for mx = 1, self.mapWidth do
            local tile = doomMap[my]:sub(mx, mx)
            local r, g, b = 0.08, 0.08, 0.08
            if tile == "1" then
                r, g, b = 0.5, 0.12, 0.12
            elseif tile == "2" then
                r, g, b = 0.12, 0.42, 0.12
            end
            self:drawClippedRect(ox + (mx - 1) * cell, oy + (my - 1) * cell, cell - 1, cell - 1, 1, r, g, b)
        end
    end
    for i = 1, #self.medkits do
        local kit = self.medkits[i]
        if not kit.used then
            self:drawClippedRect(ox + math.floor((kit.x - 0.5) * cell), oy + math.floor((kit.y - 0.5) * cell), cell - 1, cell - 1, 1, 0.78, 0.78, 0.78)
        end
    end
    for i = 1, #self.enemies do
        local enemy = self.enemies[i]
        if enemy.alive then
            self:drawClippedRect(ox + math.floor((enemy.x - 0.5) * cell), oy + math.floor((enemy.y - 0.5) * cell), cell - 1, cell - 1, 1, 0.92, 0.18, 0.18)
        end
    end
    local px = ox + math.floor((self.player.x - 0.5) * cell)
    local py = oy + math.floor((self.player.y - 0.5) * cell)
    self:drawClippedRect(px, py, cell - 1, cell - 1, 1, 1, 1, 1)
    self:drawClippedRect(px + math.floor(math.cos(self.player.angle) * 4), py + math.floor(math.sin(self.player.angle) * 4), 2, 2, 1, 1, 0.85, 0.2)
end

function PZDoomGame:drawEnemies(depthBuffer, rayCount, columnWidth)
    local visible = {}
    for i = 1, #self.enemies do
        local enemy = self.enemies[i]
        if enemy.alive then
            local distance, angle, correctedDistance = self:projectPoint(enemy.x, enemy.y)
            if correctedDistance > 0.12 and math.abs(angle) < self.fieldOfView * 0.58 and not self:lineBlocked(self.player.x, self.player.y, enemy.x, enemy.y) then
                table.insert(visible, {
                    enemy = enemy,
                    distance = distance,
                    angle = angle,
                    correctedDistance = correctedDistance
                })
            end
        end
    end

    table.sort(visible, function(a, b) return a.distance > b.distance end)

    for i = 1, #visible do
        local item = visible[i]
        local enemy = item.enemy
        local distance = math.max(0.2, item.correctedDistance)
        local screenCenter = (0.5 + item.angle / self.fieldOfView) * self.width
        local spriteHeight = math.floor(self.height / distance * 0.78)
        local spriteWidth = math.floor(spriteHeight * 0.55)
        local left = math.floor(screenCenter - spriteWidth * 0.5)
        local top = math.floor(self.height * 0.5 - spriteHeight * 0.55)
        local hitTint = enemy.hitFlash > 0 and 0.95 or 0.72
        for sx = 0, spriteWidth, columnWidth do
            local drawX = left + sx
            if drawX >= 0 and drawX < self.width then
                local rayIndex = self:clamp(math.floor(drawX / columnWidth) + 1, 1, rayCount)
                if distance <= depthBuffer[rayIndex] + 0.02 then
                    local ratio = spriteWidth > 0 and sx / math.max(1, spriteWidth) or 0
                    local centerBias = math.abs(ratio - 0.5) * 2
                    local bodyTop = top + math.floor(spriteHeight * 0.16)
                    local bodyHeight = math.floor(spriteHeight * 0.68)
                    local hornHeight = math.floor(spriteHeight * 0.1)
                    local eyeTop = top + math.floor(spriteHeight * 0.28)
                    local eyeHeight = math.max(2, math.floor(spriteHeight * 0.08))
                    local armTop = top + math.floor(spriteHeight * 0.34)
                    local armHeight = math.floor(spriteHeight * 0.18)
                    local legTop = top + math.floor(spriteHeight * 0.72)
                    local legHeight = math.floor(spriteHeight * 0.18)
                    local baseRed = math.max(0.18, hitTint - centerBias * 0.14)
                    local baseDark = math.max(0.06, 0.12 - centerBias * 0.04)

                    if centerBias < 0.86 then
                        self:drawClippedRect(drawX, bodyTop, columnWidth + 1, bodyHeight, 1, baseRed, 0.08, 0.08)
                    end
                    if centerBias < 0.52 then
                        self:drawClippedRect(drawX, top + math.floor(spriteHeight * 0.08), columnWidth + 1, math.floor(spriteHeight * 0.22), 1, baseRed * 0.95, 0.05, 0.05)
                    elseif centerBias < 0.72 then
                        self:drawClippedRect(drawX, top + math.floor(spriteHeight * 0.12), columnWidth + 1, math.floor(spriteHeight * 0.16), 1, baseRed * 0.82, 0.04, 0.04)
                    end
                    if ratio > 0.16 and ratio < 0.28 then
                        self:drawClippedRect(drawX, eyeTop, columnWidth + 1, eyeHeight, 1, 1, 0.82, 0.18)
                    elseif ratio > 0.72 and ratio < 0.84 then
                        self:drawClippedRect(drawX, eyeTop, columnWidth + 1, eyeHeight, 1, 1, 0.82, 0.18)
                    elseif ratio > 0.26 and ratio < 0.74 then
                        self:drawClippedRect(drawX, top + math.floor(spriteHeight * 0.44), columnWidth + 1, math.max(2, math.floor(spriteHeight * 0.06)), 1, 0.18, 0.18, 0.2)
                    end
                    if ratio > 0.34 and ratio < 0.66 then
                        self:drawClippedRect(drawX, top + math.floor(spriteHeight * 0.56), columnWidth + 1, math.max(2, math.floor(spriteHeight * 0.08)), 1, 0.34, 0.34, 0.36)
                    end
                    if ratio < 0.18 or ratio > 0.82 then
                        self:drawClippedRect(drawX, armTop, columnWidth + 1, armHeight, 1, baseRed * 0.82, 0.06, 0.06)
                    end
                    if ratio > 0.12 and ratio < 0.22 then
                        self:drawClippedRect(drawX, top + math.floor(spriteHeight * 0.04), columnWidth + 1, hornHeight, 1, 0.88, 0.88, 0.9)
                    elseif ratio > 0.78 and ratio < 0.88 then
                        self:drawClippedRect(drawX, top + math.floor(spriteHeight * 0.04), columnWidth + 1, hornHeight, 1, 0.88, 0.88, 0.9)
                    end
                    if ratio > 0.18 and ratio < 0.34 then
                        self:drawClippedRect(drawX, legTop, columnWidth + 1, legHeight, 1, baseDark, baseDark, baseDark)
                    elseif ratio > 0.66 and ratio < 0.82 then
                        self:drawClippedRect(drawX, legTop, columnWidth + 1, legHeight, 1, baseDark, baseDark, baseDark)
                    end
                end
            end
        end
    end
end

function PZDoomGame:drawObjectiveBanner()
    local text = "CLEAR THE MAZE"
    local r, g, b = 0.92, 0.72, 0.26
    if self:getAliveEnemies() == 0 then
        text = "EXIT OPEN"
        r, g, b = 0.42, 0.92, 0.36
    end
    self:drawText(text, math.floor(self.width * 0.5) - 42, 9, r, g, b, 1, UIFont.Small)
end

function PZDoomGame:drawStatusBar()
    local barH = 42
    local y = self.height - barH
    self:drawClippedRect(0, y, self.width, barH, 1, 0.34, 0.32, 0.28)
    self:drawClippedRect(0, y, self.width, 2, 1, 0.70, 0.68, 0.58)
    self:drawClippedRect(0, y + barH - 2, self.width, 2, 1, 0.08, 0.08, 0.07)

    local healthW = math.max(54, math.floor(self.width * 0.22))
    local killsW = 74
    local scoreW = math.max(84, math.floor(self.width * 0.24))
    local healthX = 10
    local faceX = math.floor(self.width * 0.5 - 13)
    local killsX = faceX + 34
    local scoreX = self.width - scoreW - 10
    local hp = self:clamp(self.player.health or 0, 0, 100)

    self:drawText("HEALTH", healthX, y + 8, 0.14, 0.08, 0.05, 1, UIFont.Small)
    self:drawText(tostring(hp), healthX + 4, y + 22, 0.78, 0.05, 0.03, 1, UIFont.Medium)
    self:drawText("KILLS", killsX, y + 8, 0.14, 0.08, 0.05, 1, UIFont.Small)
    self:drawText(tostring(self.totalEnemies - self:getAliveEnemies()) .. "/" .. tostring(self.totalEnemies), killsX + 7, y + 22, 0.78, 0.05, 0.03, 1, UIFont.Medium)
    self:drawText("SCORE", scoreX, y + 8, 0.14, 0.08, 0.05, 1, UIFont.Small)
    self:drawText(tostring(self.score), scoreX + 4, y + 22, 0.78, 0.05, 0.03, 1, UIFont.Medium)

    self:drawClippedRect(faceX - 2, y + 5, 30, 31, 1, 0.12, 0.10, 0.09)
    self:drawClippedRect(faceX + 1, y + 8, 24, 25, 1, 0.56, 0.42, 0.30)
    self:drawClippedRect(faceX + 7, y + 16, 3, 3, 1, 0.02, 0.01, 0.01)
    self:drawClippedRect(faceX + 16, y + 16, 3, 3, 1, 0.02, 0.01, 0.01)
    if hp <= 0 then
        self:drawClippedRect(faceX + 8, y + 25, 10, 2, 1, 0.12, 0.02, 0.02)
    elseif hp < 35 then
        self:drawClippedRect(faceX + 8, y + 24, 10, 2, 1, 0.22, 0.04, 0.03)
    else
        self:drawClippedRect(faceX + 8, y + 24, 10, 2, 1, 0.08, 0.05, 0.03)
    end
end

function PZDoomGame:drawTerminalOverlay(title, detail, r, g, b)
    local boxW = math.min(self.width - 44, 224)
    local boxH = 96
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawClippedRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.08, 0.06, 0.04)
    self:drawClippedRect(boxX, boxY, boxW, boxH, 0.96, 0.010, 0.006, 0.004)
    self:drawClippedRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.42, 0.24, 0.14)
    self:drawText("DOOM.EXE", boxX + 10, boxY + 18, 0.84, 0.66, 0.42, 1, UIFont.Small)
    self:drawText(title, boxX + 10, boxY + 38, r, g, b, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 56, 0.84, 0.66, 0.42, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. "/" .. ComputerModGameInput.getInputLabel(self, "secondary") .. ": RESTART", boxX + 10, boxY + 76, 0.70, 0.60, 0.44, 1, UIFont.Small)
end

function PZDoomGame:drawScreenOverlay()
    local y = 0
    while y < self.height do
        self:drawClippedRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
    self:drawClippedRect(0, 0, self.width, 6, 0.20, 0, 0, 0)
    self:drawClippedRect(0, self.height - 6, self.width, 6, 0.20, 0, 0, 0)
end

function PZDoomGame:prerender()
    self:drawClippedRect(0, 0, self.width, self.height, 1, 0.06, 0.01, 0.01)
    self:drawClippedRect(0, 0, self.width, math.floor(self.height * 0.52), 1, 0.16, 0.02, 0.02)
    self:drawClippedRect(0, math.floor(self.height * 0.52), self.width, self.height, 1, 0.11, 0.08, 0.06)

    local rayCount = math.max(96, math.floor(self.width / 3))
    local columnWidth = self.width / rayCount
    local depthBuffer = {}
    local horizon = self.height * 0.5

    for ray = 1, rayCount do
        local ratio = (ray - 1) / math.max(1, rayCount - 1)
        local angle = self.player.angle - self.fieldOfView * 0.5 + self.fieldOfView * ratio
        local distance, shade = self:castRay(angle)
        local corrected = math.max(0.08, distance * math.cos(angle - self.player.angle))
        local wallHeight = math.floor(self.height / corrected * 0.75)
        local top = math.floor(horizon - wallHeight * 0.5)
        local drawX = math.floor((ray - 1) * columnWidth)
        local color = math.max(0.08, shade * (1 - corrected / (self.maxDepth + 2)))
        self:drawClippedRect(drawX, top, math.ceil(columnWidth) + 1, wallHeight, 1, color, color * 0.28, color * 0.28)
        self:drawClippedRect(drawX, top + wallHeight, math.ceil(columnWidth) + 1, self.height - (top + wallHeight), 0.08, 0, 0, 0)
        depthBuffer[ray] = corrected
    end

    self:drawEnemies(depthBuffer, rayCount, math.max(2, math.ceil(columnWidth)))

    for i = 1, #self.medkits do
        local kit = self.medkits[i]
        if not kit.used then
            local distance, angle, correctedDistance = self:projectPoint(kit.x, kit.y)
            if correctedDistance > 0.12 and math.abs(angle) < self.fieldOfView * 0.5 then
                local screenCenter = (0.5 + angle / self.fieldOfView) * self.width
                local size = math.floor(self.height / math.max(correctedDistance, 0.3) * 0.25)
                local rx = self:clamp(math.floor(screenCenter / columnWidth) + 1, 1, rayCount)
                if correctedDistance <= depthBuffer[rx] + 0.02 then
                    self:drawClippedRect(math.floor(screenCenter - size * 0.5), math.floor(horizon + 32 - size), size, size, 1, 0.92, 0.92, 0.92)
                    self:drawClippedRect(math.floor(screenCenter - size * 0.12), math.floor(horizon + 32 - size), math.floor(size * 0.24), size, 1, 0.75, 0.12, 0.12)
                    self:drawClippedRect(math.floor(screenCenter - size * 0.5), math.floor(horizon + 32 - size * 0.62), size, math.floor(size * 0.24), 1, 0.75, 0.12, 0.12)
                end
            end
        end
    end

    self:drawClippedRect(math.floor(self.width * 0.5) - 1, math.floor(horizon) - 10, 2, 20, 1, 1, 1, 1)
    self:drawClippedRect(math.floor(self.width * 0.5) - 10, math.floor(horizon) - 1, 20, 2, 1, 1, 1, 1)

    self:drawWeapon()
    self:drawMinimap()
    self:drawStatusBar()
    self:drawObjectiveBanner()

    if self.damageFlash > 0 then
        self:drawClippedRect(0, 0, self.width, self.height, 0.08 * self.damageFlash, 1, 0, 0)
    end

    if self.gameState == "WIN" then
        self:drawTerminalOverlay("EXIT SEQUENCE COMPLETE", "SCORE " .. tostring(self.score), 0.52, 0.92, 0.44)
    elseif self.gameState == "GAMEOVER" then
        self:drawTerminalOverlay("PLAYER SIGNAL LOST", "BEST " .. tostring(math.max(self.highscore, self.score)), 0.94, 0.42, 0.32)
    end

    self:drawScreenOverlay()
end

function PZDoomGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZDoomGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaDoom.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaRacer.lua
GameClasses['racer'] = (function()
require "ISUI/ISPanel"

local PZRacerGame = ISPanel:derive("PZRacerGame")

function PZRacerGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZRacerGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.crashPulse = 0
    self.flashTick = 0
    self.roadOffset = 0
    self.spawnTick = 0
    self.laneCount = 4
    self.roadLeft = 0.18
    self.roadWidth = 0.64
    self.roadTop = 0.05
    self.roadBottom = 0.95
    self.laneWidth = self.roadWidth / self.laneCount
    self.traffic = {}
    self.score = 0
    self.distance = 0
    self.nearMisses = 0
    self.player = {
        lane = 1,
        laneOffset = 0,
        targetLane = 1,
        speed = 0.030,
        targetSpeed = 0.030,
        minSpeed = 0.020,
        maxSpeed = 0.056
    }
    self.leftHeld = false
    self.rightHeld = false
end

function PZRacerGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZRacerGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZRacerGame:clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function PZRacerGame:getLaneCenter(lane)
    return (self.roadLeft + self.laneWidth * lane + self.laneWidth * 0.5) * self.width
end

function PZRacerGame:getCarWidth()
    return math.floor(self.laneWidth * self.width * 0.54)
end

function PZRacerGame:getCarHeight()
    return math.floor(self.height * 0.14)
end

function PZRacerGame:getPlayerY()
    return self.height * 0.79
end

function PZRacerGame:spawnTrafficCar()
    local lane = ZombRand(self.laneCount)
    local tooClose = false
    for i = 1, #self.traffic do
        local car = self.traffic[i]
        if car.lane == lane and car.y < self.height * 0.30 then
            tooClose = true
            break
        end
    end
    if tooClose then return end

    local colorPool = {
        {0.92, 0.34, 0.28},
        {0.24, 0.70, 0.95},
        {0.96, 0.56, 0.18},
        {0.72, 0.38, 0.94},
        {0.84, 0.84, 0.86}
    }
    local color = colorPool[ZombRand(#colorPool) + 1]
    self.traffic[#self.traffic + 1] = {
        lane = lane,
        offset = ((ZombRand(100) - 50) / 50) * self.laneWidth * 0.10,
        y = self.roadTop * self.height + 6,
        speed = 0.020 + ZombRand(18) / 1000,
        color = color,
        passed = false,
        nearMiss = false
    }
end

function PZRacerGame:updatePlayer()
    local leftDown = ComputerModGameInput.isDown(self, "left")
    local rightDown = ComputerModGameInput.isDown(self, "right")

    if leftDown and not self.leftHeld then
        self.player.targetLane = self.player.targetLane - 1
    elseif rightDown and not self.rightHeld then
        self.player.targetLane = self.player.targetLane + 1
    end

    self.leftHeld = leftDown
    self.rightHeld = rightDown

    self.player.targetLane = self:clamp(self.player.targetLane, 0, self.laneCount - 1)

    if ComputerModGameInput.isDown(self, "up") then
        self.player.targetSpeed = math.min(self.player.maxSpeed, self.player.targetSpeed + 0.0014)
    elseif ComputerModGameInput.isDown(self, "down") then
        self.player.targetSpeed = math.max(self.player.minSpeed, self.player.targetSpeed - 0.0017)
    else
        self.player.targetSpeed = self.player.targetSpeed - 0.0002
    end

    self.player.targetSpeed = self:clamp(self.player.targetSpeed, self.player.minSpeed, self.player.maxSpeed)
    self.player.speed = self.player.speed + (self.player.targetSpeed - self.player.speed) * 0.14

    local laneStep = self.player.targetLane - self.player.lane
    local desiredOffset = laneStep * self.laneWidth
    self.player.laneOffset = self.player.laneOffset + desiredOffset * 0.18
    if laneStep ~= 0 and math.abs(self.player.laneOffset) > self.laneWidth * 0.92 then
        self.player.lane = self.player.targetLane
        self.player.laneOffset = 0
    end

    self.distance = self.distance + self.player.speed * 28
    self.score = self.score + self.player.speed * 12
end

function PZRacerGame:updateTraffic()
    self.spawnTick = self.spawnTick + 1
    local spawnRate = math.max(16, 44 - math.floor(self.distance / 180))
    if self.spawnTick >= spawnRate then
        self.spawnTick = 0
        self:spawnTrafficCar()
    end

    local playerY = self:getPlayerY()
    for i = #self.traffic, 1, -1 do
        local car = self.traffic[i]
        local relativeSpeed = (self.player.speed - car.speed)
        local screenSpeed = 5.1 + relativeSpeed * 210
        car.y = car.y + screenSpeed

        if not car.passed and car.y > playerY + 16 then
            car.passed = true
            self.score = self.score + 18
        end

        if car.y > self.height + self:getCarHeight() then
            table.remove(self.traffic, i)
        end
    end
end

function PZRacerGame:checkCollisions()
    local playerX = self:getLaneCenter(self.player.lane) + self.player.laneOffset * self.width
    local playerY = self:getPlayerY()
    local playerW = self:getCarWidth()
    local playerH = self:getCarHeight()

    for i = 1, #self.traffic do
        local car = self.traffic[i]
        local carX = self:getLaneCenter(car.lane) + car.offset * self.width
        local carY = car.y
        local dx = math.abs(playerX - carX)
        local dy = math.abs(playerY - carY)

        if not car.nearMiss and dy < playerH * 0.8 and dx < playerW * 0.95 then
            car.nearMiss = true
            self.nearMisses = self.nearMisses + 1
            self.score = self.score + 8
            self:playSound("ComputerBallHit")
        end

        if dx < playerW * 0.72 and dy < playerH * 0.68 then
            self.gameState = "GAMEOVER"
            self.crashPulse = 24
            self:playGameOverSound()
            return
        end
    end
end

function PZRacerGame:update()
    self.flashTick = self.flashTick + 1
    self.crashPulse = math.max(0, (self.crashPulse or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    self:updatePlayer()
    self:updateTraffic()
    self:checkCollisions()
    self.roadOffset = (self.roadOffset + self.player.speed * self.height * 0.98) % 28
end

function PZRacerGame:drawBackground()
    self:drawRect(0, 0, self.width, self.height, 1, 0.025, 0.085, 0.035)
    for i = 0, 10 do
        local y = i * self.height / 10
        local shade = i % 2 == 0 and 0.012 or 0.028
        self:drawRect(0, y, self.width, math.max(2, self.height / 13), 0.45, 0.03 + shade, 0.12 + shade, 0.04)
    end
end

function PZRacerGame:drawScenery()
    local leftXs = {20, 26, 18, 24, 16, 28}
    local rightXs = {self.width - 34, self.width - 26, self.width - 36, self.width - 24, self.width - 30, self.width - 40}
    for i = 1, 6 do
        local y = ((i - 1) * 46 + self.roadOffset * 0.6) % (self.height + 48) - 24
        self:drawRect(leftXs[i], y + 8, 6, 10, 1, 0.40, 0.24, 0.12)
        self:drawRect(leftXs[i] - 10, y - 2, 26, 20, 1, 0.10, 0.42, 0.17)
        self:drawRect(leftXs[i] - 4, y - 8, 14, 12, 1, 0.16, 0.58, 0.22)
        self:drawRect(rightXs[i], y + 8, 6, 10, 1, 0.40, 0.24, 0.12)
        self:drawRect(rightXs[i] - 10, y - 2, 26, 20, 1, 0.10, 0.42, 0.17)
        self:drawRect(rightXs[i] - 4, y - 8, 14, 12, 1, 0.16, 0.58, 0.22)
    end
end

function PZRacerGame:drawRoad()
    local x = self.roadLeft * self.width
    local y = self.roadTop * self.height
    local w = self.roadWidth * self.width
    local h = (self.roadBottom - self.roadTop) * self.height

    self:drawRect(x - 14, y, 14, h, 1, 0.12, 0.12, 0.12)
    self:drawRect(x + w, y, 14, h, 1, 0.12, 0.12, 0.12)
    self:drawRect(x, y, w, h, 1, 0.105, 0.108, 0.110)
    for band = 0, 12 do
        local by = y + band * h / 12
        self:drawRect(x, by, w, math.max(2, h / 20), 0.16, 0.04, 0.04, 0.045)
    end
    local railY = y + self.roadOffset
    while railY < y + h do
        self:drawRect(x - 13, railY, 12, 9, 1, 0.86, 0.86, 0.78)
        self:drawRect(x + w + 1, railY, 12, 9, 1, 0.86, 0.86, 0.78)
        self:drawRect(x - 13, railY + 9, 12, 9, 1, 0.62, 0.10, 0.09)
        self:drawRect(x + w + 1, railY + 9, 12, 9, 1, 0.62, 0.10, 0.09)
        railY = railY + 36
    end

    for i = 1, self.laneCount - 1 do
        local lineX = x + i * self.laneWidth * self.width
        local markY = y + 6 + self.roadOffset
        while markY < y + h - 18 do
            self:drawRect(lineX - 1, markY, 2, 16, 0.78, 0.78, 0.78, 0.68)
            markY = markY + 28
        end
    end
end

function PZRacerGame:drawCarAt(centerX, centerY, color, player)
    local carW = self:getCarWidth()
    local carH = self:getCarHeight()
    local x = math.floor(centerX - carW * 0.5)
    local y = math.floor(centerY - carH * 0.5)
    self:drawRect(x + 1, y + 3, carW, carH, 0.28, 0, 0, 0)
    self:drawRect(x, y + 4, carW, carH - 8, 1, color[1], color[2], color[3])
    self:drawRect(x + 4, y, carW - 8, carH, 1, color[1] * 0.86, color[2] * 0.86, color[3] * 0.86)
    self:drawRect(x + 5, y + 6, carW - 10, math.max(4, carH - 18), 1, 0.10, 0.14, 0.16)
    self:drawRect(x + 6, y + 7, carW - 12, math.max(2, carH - 22), 1, 0.46, 0.62, 0.70)
    self:drawRect(x + 4, y + 2, carW - 8, 2, 1, 0.92, 0.90, 0.72)
    self:drawRect(x - 1, y + 5, 3, 5, 1, 0.08, 0.08, 0.08)
    self:drawRect(x + carW - 2, y + 5, 3, 5, 1, 0.08, 0.08, 0.08)
    self:drawRect(x - 1, y + carH - 10, 3, 5, 1, 0.08, 0.08, 0.08)
    self:drawRect(x + carW - 2, y + carH - 10, 3, 5, 1, 0.08, 0.08, 0.08)
end

function PZRacerGame:drawTraffic()
    for i = 1, #self.traffic do
        local car = self.traffic[i]
        local x = self:getLaneCenter(car.lane) + car.offset * self.width
        self:drawCarAt(x, car.y, car.color, false)
    end
end

function PZRacerGame:drawPlayer()
    local x = self:getLaneCenter(self.player.lane) + self.player.laneOffset * self.width
    self:drawCarAt(x, self:getPlayerY(), {0.98, 0.86, 0.22}, true)
end

function PZRacerGame:drawHUD()
    self:drawRect(0, 0, self.width, 25, 1, 0.010, 0.012, 0.010)
    self:drawRect(0, 24, self.width, 1, 1, 0.42, 0.42, 0.34)
    self:drawText("RACER.EXE", 10, 7, 0.72, 0.74, 0.56, 1, UIFont.Small)
    self:drawText("MPH " .. string.format("%03d", math.floor(self.player.speed * 1600)), 102, 7, 0.72, 0.74, 0.56, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(math.floor(self.score)), 184, 7, 0.72, 0.74, 0.56, 1, UIFont.Small)
    self:drawText("MISS " .. tostring(self.nearMisses), self.width - 70, 7, 0.72, 0.74, 0.56, 1, UIFont.Small)
end

function PZRacerGame:drawOverlay()
    if self.gameState ~= "GAMEOVER" then return end
    local boxW = math.min(self.width - 40, 214)
    local boxH = 82
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.06, 0.05, 0.04)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.006, 0.004)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.42, 0.38, 0.24)
    self:drawText("RACER.EXE CRASH", boxX + 10, boxY + 18, 0.82, 0.76, 0.48, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(math.floor(self.score)), boxX + 10, boxY + 40, 0.72, 0.74, 0.56, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 60, 0.72, 0.74, 0.56, 1, UIFont.Small)
end

function PZRacerGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
    if self.crashPulse and self.crashPulse > 0 then
        self:drawRect(0, 0, self.width, self.height, self.crashPulse / 120, 0.88, 0.12, 0.08)
    end
end

function PZRacerGame:prerender()
    self:drawBackground()
    self:drawScenery()
    self:drawRoad()
    self:drawTraffic()
    self:drawPlayer()
    self:drawHUD()
    self:drawOverlay()
    self:drawScanlines()
end

function PZRacerGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZRacerGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaRacer.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaFlappy.lua
GameClasses['flappy'] = (function()
require "ISUI/ISPanel"

local PZFlappyGame = ISPanel:derive("PZFlappyGame")

function PZFlappyGame:initialise()
    ISPanel.initialise(self)
    self.bestScore = 0
    self:resetGame()
end

function PZFlappyGame:resetGame()
    self.gameState = "READY"
    self.gameOverSoundPlayed = false
    self.tick = 0
    self.score = 0
    self.bird = {
        x = math.floor(self.width * 0.28),
        y = math.floor(self.height * 0.46),
        velocity = 0
    }
    self.gravity = 0.34
    self.flapPower = -5.9
    self.pipeSpeed = 3.1
    self.pipeGap = 76
    self.pipeWidth = 34
    self.pipeSpacing = 112
    self.groundH = 24
    self.skyOffset = 0
    self.flapHeld = false
    self.pipes = {}
    local firstX = self.width * 0.72
    for i = 1, 3 do
        self:addPipe(firstX + (i - 1) * self.pipeSpacing)
    end
end

function PZFlappyGame:drawSafeRect(x, y, w, h, a, r, g, b)
    local x1 = math.max(0, math.floor(x))
    local y1 = math.max(0, math.floor(y))
    local x2 = math.min(self.width, math.ceil(x + w))
    local y2 = math.min(self.height, math.ceil(y + h))
    if x2 <= x1 or y2 <= y1 then return end
    self:drawRect(x1, y1, x2 - x1, y2 - y1, a, r, g, b)
end

function PZFlappyGame:addPipe(x)
    local minTop = 34
    local maxTop = self.height - self.groundH - self.pipeGap - 38
    local gapY = minTop
    if maxTop > minTop then
        gapY = minTop + ZombRand(maxTop - minTop)
    end
    self.pipes[#self.pipes + 1] = {x = x, gapY = gapY, scored = false}
end

function PZFlappyGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZFlappyGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZFlappyGame:doFlap()
    if self.gameState == "GAMEOVER" then
        self:resetGame()
        return
    end
    if self.gameState == "READY" then
        self.gameState = "PLAYING"
    end
    self.bird.velocity = self.flapPower
    self:playSound("ComputerBirdJump")
end

function PZFlappyGame:updateInput()
    local flapDown = ComputerModGameInput.isDown(self, "action") or ComputerModGameInput.isDown(self, "up")
    if flapDown and not self.flapHeld then
        self:doFlap()
    end
    self.flapHeld = flapDown
end

function PZFlappyGame:updatePipes()
    local rightMost = 0
    for i = #self.pipes, 1, -1 do
        local pipe = self.pipes[i]
        pipe.x = pipe.x - self.pipeSpeed
        if pipe.x > rightMost then rightMost = pipe.x end
        if pipe.x + self.pipeWidth < -4 then
            table.remove(self.pipes, i)
        end
    end
    while #self.pipes < 3 do
        self:addPipe(rightMost + self.pipeSpacing)
        rightMost = rightMost + self.pipeSpacing
    end
end

function PZFlappyGame:checkScoreAndCollision()
    local bx = self.bird.x
    local by = self.bird.y
    local birdW = 18
    local birdH = 14
    local floorY = self.height - self.groundH

    if by - birdH * 0.5 < 0 or by + birdH * 0.5 > floorY then
        self.gameState = "GAMEOVER"
        self:playGameOverSound()
        return
    end

    for i = 1, #self.pipes do
        local pipe = self.pipes[i]
        if not pipe.scored and pipe.x + self.pipeWidth < bx - birdW * 0.5 then
            pipe.scored = true
            self.score = self.score + 1
            self:playSound("ComputerBallHit")
            if self.score > self.bestScore then
                self.bestScore = self.score
            end
        end

        local overlapX = bx + birdW * 0.42 > pipe.x and bx - birdW * 0.42 < pipe.x + self.pipeWidth
        if overlapX then
            local topBottom = pipe.gapY
            local bottomTop = pipe.gapY + self.pipeGap
            if by - birdH * 0.42 < topBottom or by + birdH * 0.42 > bottomTop then
                self.gameState = "GAMEOVER"
                self:playGameOverSound()
                return
            end
        end
    end
end

function PZFlappyGame:update()
    self.tick = self.tick + 1
    self.skyOffset = (self.skyOffset + 0.6) % 48
    self:updateInput()

    if self.gameState == "READY" then
        self.bird.y = math.floor(self.height * 0.46) + math.sin(self.tick / 8) * 5
        return
    end

    if self.gameState == "GAMEOVER" then
        return
    end

    self.bird.velocity = self.bird.velocity + self.gravity
    self.bird.y = self.bird.y + self.bird.velocity
    self:updatePipes()
    self:checkScoreAndCollision()
end

function PZFlappyGame:drawPipe(pipe)
    local px = math.floor(pipe.x)
    local topH = pipe.gapY
    local bottomY = pipe.gapY + self.pipeGap
    local bottomH = self.height - self.groundH - bottomY
    local topCapY = math.max(0, topH - 12)
    local topCapH = math.min(12, topH)
    local bottomBodyH = math.max(0, bottomH)
    local bottomDetailH = math.max(0, bottomH - 12)
    self:drawSafeRect(px + 2, 0, self.pipeWidth - 4, topH, 1, 0.10, 0.42, 0.18)
    self:drawSafeRect(px, 0, 3, topH, 1, 0.04, 0.20, 0.09)
    self:drawSafeRect(px + self.pipeWidth - 3, 0, 3, topH, 1, 0.04, 0.20, 0.09)
    if topCapH > 0 then
        self:drawSafeRect(px - 3, topCapY, self.pipeWidth + 6, topCapH, 1, 0.16, 0.58, 0.24)
        self:drawSafeRect(px - 3, topCapY, self.pipeWidth + 6, 2, 1, 0.36, 0.74, 0.34)
    end
    if topH - topCapH > 0 then
        self:drawSafeRect(px + 7, 0, 3, topH - topCapH, 0.30, 0.42, 0.74, 0.38)
    end
    if bottomBodyH > 0 then
        self:drawSafeRect(px + 2, bottomY, self.pipeWidth - 4, bottomBodyH, 1, 0.10, 0.42, 0.18)
        self:drawSafeRect(px, bottomY, 3, bottomBodyH, 1, 0.04, 0.20, 0.09)
        self:drawSafeRect(px + self.pipeWidth - 3, bottomY, 3, bottomBodyH, 1, 0.04, 0.20, 0.09)
        self:drawSafeRect(px - 3, bottomY, self.pipeWidth + 6, 12, 1, 0.16, 0.58, 0.24)
        self:drawSafeRect(px - 3, bottomY, self.pipeWidth + 6, 2, 1, 0.36, 0.74, 0.34)
    end
    if bottomDetailH > 0 then
        self:drawSafeRect(px + 7, bottomY + 12, 3, bottomDetailH, 0.30, 0.42, 0.74, 0.38)
    end
end

function PZFlappyGame:drawBird()
    local bx = self.bird.x
    local by = self.bird.y
    local wingLift = math.sin(self.tick / 3) * 2
    self:drawRect(bx - 10, by - 6, 18, 13, 1, 0.84, 0.62, 0.16)
    self:drawRect(bx - 6, by - 10, 12, 10, 1, 0.94, 0.76, 0.20)
    self:drawRect(bx + 5, by - 3, 8, 4, 1, 0.82, 0.30, 0.14)
    self:drawRect(bx - 6, by + wingLift, 10, 5, 1, 0.70, 0.38, 0.10)
    self:drawRect(bx + 2, by - 7, 2, 2, 1, 0.02, 0.02, 0.02)
end

function PZFlappyGame:drawHud()
    self:drawRect(0, 0, self.width, 24, 1, 0.010, 0.024, 0.036)
    self:drawRect(0, 23, self.width, 1, 1, 0.42, 0.58, 0.62)
    self:drawText("BIRD.EXE", 10, 7, 0.78, 0.90, 0.88, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), 94, 7, 0.78, 0.90, 0.88, 1, UIFont.Small)
    self:drawText("BEST " .. tostring(self.bestScore), self.width - 74, 7, 0.78, 0.90, 0.88, 1, UIFont.Small)
end

function PZFlappyGame:drawMessage(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 72
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor(self.height * 0.35)
    self:drawSafeRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.06, 0.08, 0.08)
    self:drawSafeRect(boxX, boxY, boxW, boxH, 0.98, 0.010, 0.024, 0.036)
    self:drawSafeRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.42, 0.58, 0.62)
    self:drawText(title, boxX + 10, boxY + 19, 0.78, 0.90, 0.88, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 42, 0.82, 0.78, 0.52, 1, UIFont.Small)
end

function PZFlappyGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawSafeRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZFlappyGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.34, 0.62, 0.74)
    for band = 0, 9 do
        local y = band * self.height / 9
        self:drawSafeRect(0, y, self.width, math.max(2, self.height / 24), 0.10, 0.20, 0.42, 0.52)
    end
    for i = 0, 7 do
        local x = i * 48 - self.skyOffset
        self:drawSafeRect(x + 5, 34, 28, 8, 0.26, 0.88, 0.92, 0.90)
        self:drawSafeRect(x + 18, 28, 22, 10, 0.26, 0.88, 0.92, 0.90)
    end

    for i = 1, #self.pipes do
        self:drawPipe(self.pipes[i])
    end

    self:drawRect(0, self.height - self.groundH, self.width, self.groundH, 1, 0.36, 0.24, 0.12)
    self:drawRect(0, self.height - self.groundH, self.width, 5, 1, 0.14, 0.46, 0.18)
    for i = 0, self.width, 18 do
        self:drawSafeRect(i - (self.skyOffset % 18), self.height - self.groundH + 10, 9, 3, 0.55, 0.82, 0.66, 0.28)
    end

    self:drawBird()
    self:drawHud()

    if self.gameState == "READY" then
        self:drawMessage("BIRD.EXE READY", ComputerModGameInput.getInputLabel(self, "action") .. "/" .. ComputerModGameInput.getInputLabel(self, "up") .. ": FLAP")
    elseif self.gameState == "GAMEOVER" then
        self:drawMessage("BIRD.EXE STOPPED", ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART")
    end

    self:drawScanlines()
end

function PZFlappyGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZFlappyGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaFlappy.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaBreakout.lua
GameClasses['breakout'] = (function()
require "ISUI/ISPanel"

local PZBreakoutGame = ISPanel:derive("PZBreakoutGame")

function PZBreakoutGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZBreakoutGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.hitSoundLock = false
    self.flashTick = 0
    self.hitFlash = 0
    self.paddle = {x = self.width * 0.5 - 38, y = self.height - 24, w = 76, h = 8, speed = 7}
    self.ball = {x = self.width * 0.5, y = self.height - 40, dx = 2.9, dy = -3.0, r = 4}
    self.score = 0
    self.rows = 5
    self.cols = 8
    self.ballTrail = {}
    self.bricks = {}
    local brickW = math.floor((self.width - 28) / self.cols)
    for row = 1, self.rows do
        for col = 1, self.cols do
            self.bricks[#self.bricks + 1] = {
                x = 14 + (col - 1) * brickW,
                y = 24 + (row - 1) * 16,
                w = brickW - 4,
                h = 12,
                alive = true,
                tone = row
            }
        end
    end
end

function PZBreakoutGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZBreakoutGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZBreakoutGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZBreakoutGame:pushTrail()
    table.insert(self.ballTrail, 1, {x = self.ball.x, y = self.ball.y})
    if #self.ballTrail > 7 then
        table.remove(self.ballTrail)
    end
end

function PZBreakoutGame:update()
    self.flashTick = ((self.flashTick or 0) + 1) % 240
    self.hitFlash = math.max(0, (self.hitFlash or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    if ComputerModGameInput.isDown(self, "left") then
        self.paddle.x = math.max(8, self.paddle.x - self.paddle.speed)
    elseif ComputerModGameInput.isDown(self, "right") then
        self.paddle.x = math.min(self.width - self.paddle.w - 8, self.paddle.x + self.paddle.speed)
    end

    self:pushTrail()
    self.ball.x = self.ball.x + self.ball.dx
    self.ball.y = self.ball.y + self.ball.dy

    if self.ball.x <= 8 then
        self.ball.x = 8
        self.ball.dx = math.abs(self.ball.dx)
    elseif self.ball.x >= self.width - 8 then
        self.ball.x = self.width - 8
        self.ball.dx = -math.abs(self.ball.dx)
    end

    if self.ball.y <= 18 then
        self.ball.y = 18
        self.ball.dy = math.abs(self.ball.dy)
    end

    if self.ball.y >= self.height then
        self.gameState = "GAMEOVER"
        self:playGameOverSound()
        return
    end

    if self.ball.y + self.ball.r >= self.paddle.y and self.ball.y <= self.paddle.y + self.paddle.h and self.ball.x >= self.paddle.x and self.ball.x <= self.paddle.x + self.paddle.w then
        self.ball.y = self.paddle.y - self.ball.r
        self.ball.dy = -math.abs(self.ball.dy)
        local offset = (self.ball.x - (self.paddle.x + self.paddle.w * 0.5)) / (self.paddle.w * 0.5)
        self.ball.dx = offset * 4.2
        self.hitFlash = 5
        self:playSound("ComputerBallHit")
    end

    local aliveCount = 0
    for i = 1, #self.bricks do
        local brick = self.bricks[i]
        if brick.alive then
            aliveCount = aliveCount + 1
            if self.ball.x + self.ball.r >= brick.x and self.ball.x - self.ball.r <= brick.x + brick.w and self.ball.y + self.ball.r >= brick.y and self.ball.y - self.ball.r <= brick.y + brick.h then
                brick.alive = false
                self.ball.dy = -self.ball.dy
                self.score = self.score + 10
                aliveCount = aliveCount - 1
                self.hitFlash = 6
                self:playSound("ComputerBallHit")
                break
            end
        end
    end

    if aliveCount == 0 then
        self.gameState = "WIN"
        self:playWinSound()
    end
end

function PZBreakoutGame:drawHud()
    self:drawRect(0, 0, self.width, 24, 1, 0.010, 0.010, 0.018)
    self:drawRect(0, 23, self.width, 1, 1, 0.34, 0.30, 0.46)
    self:drawText("BREAKOUT.EXE", 10, 7, 0.72, 0.68, 0.86, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), 128, 7, 0.72, 0.68, 0.86, 1, UIFont.Small)
    local bricksLeft = 0
    for i = 1, #self.bricks do
        if self.bricks[i].alive then bricksLeft = bricksLeft + 1 end
    end
    self:drawText("BRICKS " .. tostring(bricksLeft), self.width - 82, 7, 0.72, 0.68, 0.86, 1, UIFont.Small)
end

function PZBreakoutGame:drawBrick(brick)
    local colors = {
        {0.46, 0.22, 0.62},
        {0.34, 0.26, 0.68},
        {0.22, 0.34, 0.66},
        {0.22, 0.48, 0.50},
        {0.54, 0.44, 0.22}
    }
    local c = colors[brick.tone] or colors[1]
    self:drawRect(brick.x + 1, brick.y + 2, brick.w, brick.h, 0.26, 0, 0, 0)
    self:drawRect(brick.x, brick.y, brick.w, brick.h, 1, c[1], c[2], c[3])
    self:drawRect(brick.x, brick.y, brick.w, 2, 1, math.min(1, c[1] + 0.24), math.min(1, c[2] + 0.24), math.min(1, c[3] + 0.24))
    self:drawRect(brick.x, brick.y + brick.h - 2, brick.w, 2, 1, c[1] * 0.55, c[2] * 0.55, c[3] * 0.55)
    self:drawRect(brick.x + 3, brick.y + 4, math.max(2, brick.w - 6), 1, 0.20, 1, 1, 1)
end

function PZBreakoutGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 210)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.05, 0.04, 0.07)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.010, 0.010, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.34, 0.30, 0.46)
    self:drawText(title, boxX + 10, boxY + 19, 0.72, 0.68, 0.86, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.78, 0.78, 0.60, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.72, 0.68, 0.86, 1, UIFont.Small)
end

function PZBreakoutGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZBreakoutGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.014, 0.014, 0.024)
    for band = 0, 10 do
        local y = band * self.height / 10
        self:drawRect(0, y, self.width, math.max(2, self.height / 18), 0.08, 0.12, 0.10, 0.18)
    end
    if self.hitFlash and self.hitFlash > 0 then
        self:drawRect(0, 24, self.width, self.height - 24, self.hitFlash / 90, 0.58, 0.48, 0.78)
    end
    self:drawHud()

    for i = #self.ballTrail, 1, -1 do
        local trail = self.ballTrail[i]
        local alpha = 0.04 + ((#self.ballTrail - i) * 0.028)
        self:drawRect(trail.x - self.ball.r, trail.y - self.ball.r, self.ball.r * 2, self.ball.r * 2, alpha, 0.78, 0.72, 0.42)
    end

    for i = 1, #self.bricks do
        local brick = self.bricks[i]
        if brick.alive then
            self:drawBrick(brick)
        end
    end

    self:drawRect(self.paddle.x + 1, self.paddle.y + 2, self.paddle.w, self.paddle.h, 0.35, 0, 0, 0)
    self:drawRect(self.paddle.x, self.paddle.y, self.paddle.w, self.paddle.h, 1, 0.62, 0.62, 0.68)
    self:drawRect(self.paddle.x + 6, self.paddle.y + 2, self.paddle.w - 12, 2, 1, 0.88, 0.88, 0.84)
    self:drawRect(self.ball.x - self.ball.r - 1, self.ball.y - self.ball.r - 1, self.ball.r * 2 + 2, self.ball.r * 2 + 2, 0.18, 1, 1, 1)
    self:drawRect(self.ball.x - self.ball.r, self.ball.y - self.ball.r, self.ball.r * 2, self.ball.r * 2, 1, 0.86, 0.80, 0.42)

    if self.gameState == "WIN" then
        self:drawOverlay("BREAKOUT CLEARED", "SCORE " .. tostring(self.score))
    elseif self.gameState == "GAMEOVER" then
        self:drawOverlay("BALL LOST", "SCORE " .. tostring(self.score))
    end
    self:drawScanlines()
end

function PZBreakoutGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZBreakoutGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaBreakout.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaAsteroids.lua
GameClasses['asteroids'] = (function()
require "ISUI/ISPanel"

local asteroidTexture = getTexture("media/textures/asteroid.png")

local PZAsteroidsGame = ISPanel:derive("PZAsteroidsGame")

function PZAsteroidsGame:initialise()
    ISPanel.initialise(self)
    self.highscore = 0
    self:buildStarfield()
    self:resetGame()
end

function PZAsteroidsGame:buildStarfield()
    self.stars = {}
    for i = 1, 58 do
        self.stars[#self.stars + 1] = {
            x = ZombRand(1000) / 1000,
            y = ZombRand(1000) / 1000,
            s = 1 + ZombRand(2),
            a = 0.25 + ZombRand(55) / 100
        }
    end
end

function PZAsteroidsGame:spawnRock(radius)
    local rock = {vx = (ZombRand(100) - 50) / 30, vy = (ZombRand(100) - 50) / 30, r = radius, spin = ZombRand(100)}
    rock.x = radius + ZombRand(math.max(1, self.width - radius * 2))
    rock.y = radius + ZombRand(math.max(1, self.height - radius * 2))
    return rock
end

function PZAsteroidsGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.flashTick = 0
    self.hitFlash = 0
    self.ship = {x = self.width * 0.5, y = self.height * 0.6, a = -1.57, vx = 0, vy = 0}
    self.bullets = {}
    self.rocks = {}
    self.particles = {}
    self.score = 0
    self.fireCooldown = 0
    self.thrustGlow = 0
    for i = 1, 6 do
        self.rocks[#self.rocks + 1] = self:spawnRock(11 + ZombRand(10))
    end
end

function PZAsteroidsGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZAsteroidsGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZAsteroidsGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZAsteroidsGame:wrap(obj)
    if obj.x < 0 then obj.x = self.width end
    if obj.x > self.width then obj.x = 0 end
    if obj.y < 0 then obj.y = self.height end
    if obj.y > self.height then obj.y = 0 end
end

function PZAsteroidsGame:wrapRock(rock)
    local r = rock.r or 10
    if rock.x < r then rock.x = self.width - r end
    if rock.x > self.width - r then rock.x = r end
    if rock.y < r then rock.y = self.height - r end
    if rock.y > self.height - r then rock.y = r end
end

function PZAsteroidsGame:limitShipSpeed()
    local speed = math.sqrt(self.ship.vx * self.ship.vx + self.ship.vy * self.ship.vy)
    if speed > 4.4 then
        local scale = 4.4 / speed
        self.ship.vx = self.ship.vx * scale
        self.ship.vy = self.ship.vy * scale
    end
end

function PZAsteroidsGame:emitParticles(x, y, count, r, g, b)
    for i = 1, count do
        local life = 14 + ZombRand(20)
        self.particles[#self.particles + 1] = {
            x = x,
            y = y,
            vx = (ZombRand(1000) - 500) / 160,
            vy = (ZombRand(1000) - 500) / 160,
            life = life,
            maxLife = life,
            r = r,
            g = g,
            b = b
        }
    end
end

function PZAsteroidsGame:updateParticles()
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.x = p.x + p.vx
        p.y = p.y + p.vy
        p.vx = p.vx * 0.94
        p.vy = p.vy * 0.94
        p.life = p.life - 1
        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end
end

function PZAsteroidsGame:update()
    self.flashTick = ((self.flashTick or 0) + 1) % 240
    self.hitFlash = math.max(0, (self.hitFlash or 0) - 1)
    self:updateParticles()

    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    if ComputerModGameInput.isDown(self, "left") then
        self.ship.a = self.ship.a - 0.11
    end
    if ComputerModGameInput.isDown(self, "right") then
        self.ship.a = self.ship.a + 0.11
    end
    if ComputerModGameInput.isDown(self, "up") then
        self.ship.vx = self.ship.vx + math.cos(self.ship.a) * 0.22
        self.ship.vy = self.ship.vy + math.sin(self.ship.a) * 0.22
        self.thrustGlow = 4
    else
        self.thrustGlow = math.max(0, self.thrustGlow - 1)
    end
    if ComputerModGameInput.isDown(self, "down") then
        self.ship.vx = self.ship.vx * 0.92
        self.ship.vy = self.ship.vy * 0.92
    end

    self.ship.x = self.ship.x + self.ship.vx
    self.ship.y = self.ship.y + self.ship.vy
    self.ship.vx = self.ship.vx * 0.96
    self.ship.vy = self.ship.vy * 0.96
    self:limitShipSpeed()
    self:wrap(self.ship)

    if self.fireCooldown > 0 then
        self.fireCooldown = self.fireCooldown - 1
    end
    if ComputerModGameInput.isDown(self, "action") and self.fireCooldown <= 0 then
        self.fireCooldown = 8
        self.bullets[#self.bullets + 1] = {
            x = self.ship.x + math.cos(self.ship.a) * 10,
            y = self.ship.y + math.sin(self.ship.a) * 10,
            vx = self.ship.vx + math.cos(self.ship.a) * 6.4,
            vy = self.ship.vy + math.sin(self.ship.a) * 6.4,
            life = 34
        }
        self:playSound("ComputerLaserShot")
    end

    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet.x = bullet.x + bullet.vx
        bullet.y = bullet.y + bullet.vy
        bullet.life = bullet.life - 1
        if bullet.life <= 0 or bullet.x < 2 or bullet.x > self.width - 2 or bullet.y < 2 or bullet.y > self.height - 2 then
            table.remove(self.bullets, i)
        end
    end

    for i = #self.rocks, 1, -1 do
        local rock = self.rocks[i]
        rock.x = rock.x + rock.vx
        rock.y = rock.y + rock.vy
        rock.spin = (rock.spin or 0) + 1
        self:wrapRock(rock)

        local dx = rock.x - self.ship.x
        local dy = rock.y - self.ship.y
        if dx * dx + dy * dy < (rock.r + 7) * (rock.r + 7) then
            self.gameState = "GAMEOVER"
            if self.score > self.highscore then self.highscore = self.score end
            self:emitParticles(self.ship.x, self.ship.y, 24, 0.82, 0.72, 0.45)
            self:playGameOverSound()
            return
        end

        for j = #self.bullets, 1, -1 do
            local bullet = self.bullets[j]
            local bx = rock.x - bullet.x
            local by = rock.y - bullet.y
            if bx * bx + by * by < rock.r * rock.r then
                self.score = self.score + 15
                self.hitFlash = 5
                self:emitParticles(rock.x, rock.y, 12, 0.60, 0.62, 0.66)
                self:playSound("ComputerBallHit")
                table.remove(self.bullets, j)
                if rock.r > 11 then
                    for k = 1, 2 do
                        local split = self:spawnRock(math.max(8, math.floor(rock.r * 0.62)))
                        split.x = rock.x
                        split.y = rock.y
                        split.vx = (ZombRand(100) - 50) / 22
                        split.vy = (ZombRand(100) - 50) / 22
                        self.rocks[#self.rocks + 1] = split
                    end
                end
                table.remove(self.rocks, i)
                break
            end
        end
    end

    if #self.rocks == 0 then
        self.gameState = "WIN"
        if self.score > self.highscore then self.highscore = self.score end
        self:playWinSound()
    end
end

function PZAsteroidsGame:drawHud()
    self:drawRect(0, 0, self.width, 24, 1, 0.006, 0.008, 0.018)
    self:drawRect(0, 23, self.width, 1, 1, 0.28, 0.30, 0.42)
    self:drawText("ASTEROIDS.EXE", 10, 7, 0.70, 0.74, 0.88, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), 138, 7, 0.70, 0.74, 0.88, 1, UIFont.Small)
    self:drawText("ROCKS " .. tostring(#self.rocks), self.width - 74, 7, 0.70, 0.74, 0.88, 1, UIFont.Small)
end

function PZAsteroidsGame:drawShip()
    local sx = self.ship.x
    local sy = self.ship.y
    local nx = math.cos(self.ship.a)
    local ny = math.sin(self.ship.a)
    local wx = math.cos(self.ship.a + 1.57)
    local wy = math.sin(self.ship.a + 1.57)
    self:drawRect(sx + nx * 8 - 2, sy + ny * 8 - 2, 4, 4, 1, 0.86, 0.90, 0.95)
    self:drawRect(sx - wx * 6 - 2, sy - wy * 6 - 2, 4, 4, 1, 0.56, 0.66, 0.82)
    self:drawRect(sx + wx * 6 - 2, sy + wy * 6 - 2, 4, 4, 1, 0.56, 0.66, 0.82)
    self:drawRect(sx - 3, sy - 3, 6, 6, 1, 0.70, 0.78, 0.88)
    if self.thrustGlow > 0 then
        self:drawRect(sx - nx * 9 - 2, sy - ny * 9 - 2, 4, 4, 1, 0.94, 0.56, 0.20)
        self:drawRect(sx - nx * 14 - 1, sy - ny * 14 - 1, 2, 2, 0.70, 0.94, 0.80, 0.24)
    end
end

function PZAsteroidsGame:drawRock(rock)
    if asteroidTexture then
        self:drawTextureScaled(asteroidTexture, rock.x - rock.r, rock.y - rock.r, rock.r * 2, rock.r * 2, 0.92, 0.72, 0.72, 0.72)
    else
        self:drawRect(rock.x - rock.r, rock.y - rock.r, rock.r * 2, rock.r * 2, 1, 0.36, 0.36, 0.40)
    end
    self:drawRect(rock.x - rock.r * 0.55, rock.y - rock.r * 0.25, rock.r * 0.72, 2, 0.28, 0.88, 0.88, 0.82)
    self:drawRect(rock.x + rock.r * 0.10, rock.y + rock.r * 0.32, rock.r * 0.42, 2, 0.20, 0.22, 0.22, 0.24)
    self:drawRect(rock.x - 1, rock.y - 1, 2, 2, 0.36, 0.12, 0.12, 0.14)
end

function PZAsteroidsGame:drawParticles()
    for i = 1, #self.particles do
        local p = self.particles[i]
        local alpha = math.max(0, p.life / p.maxLife)
        self:drawRect(p.x, p.y, math.max(2, math.floor(alpha * 4)), math.max(2, math.floor(alpha * 4)), alpha, p.r, p.g, p.b)
    end
end

function PZAsteroidsGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 230)
    local boxH = 78
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.05, 0.05, 0.07)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.008, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.28, 0.30, 0.42)
    self:drawText(title, boxX + 10, boxY + 20, 0.70, 0.74, 0.88, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 42, 0.78, 0.78, 0.60, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 59, 0.70, 0.74, 0.88, 1, UIFont.Small)
end

function PZAsteroidsGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZAsteroidsGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.008, 0.020)
    for i = 1, #self.stars do
        local star = self.stars[i]
        local alpha = star.a * (0.72 + math.sin(((self.flashTick or 0) + i * 7) / 24) * 0.20)
        self:drawRect(star.x * self.width, star.y * self.height, star.s, star.s, alpha, 0.70, 0.72, 0.82)
    end
    if self.hitFlash and self.hitFlash > 0 then
        self:drawRect(0, 24, self.width, self.height - 24, self.hitFlash / 100, 0.58, 0.58, 0.72)
    end

    self:drawHud()

    for i = 1, #self.rocks do
        self:drawRock(self.rocks[i])
    end

    for i = 1, #self.bullets do
        local bullet = self.bullets[i]
        self:drawRect(bullet.x - 1, bullet.y - 1, 3, 3, 1, 0.92, 0.84, 0.44)
    end

    self:drawParticles()
    self:drawShip()

    if self.gameState == "WIN" then
        self:drawOverlay("SECTOR CLEAR", "SCORE " .. tostring(self.score))
    elseif self.gameState == "GAMEOVER" then
        self:drawOverlay("SHIP LOST", "BEST " .. tostring(math.max(self.highscore, self.score)))
    end

    self:drawScanlines()
end

function PZAsteroidsGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZAsteroidsGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaAsteroids.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaFrogger.lua
GameClasses['frogger'] = (function()
require "ISUI/ISPanel"

local PZFroggerGame = ISPanel:derive("PZFroggerGame")

function PZFroggerGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZFroggerGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.cols = 11
    self.rows = 11
    self.originX = 8
    self.originY = 24
    self.boardW = self.width - 16
    self.boardH = self.height - 30
    self.cellW = self.boardW / self.cols
    self.cellH = self.boardH / self.rows
    self.frog = {col = 5, row = 10}
    self.score = 0
    self.moveLock = false
    self.flashTick = 0
    self.goalFlash = 0
    self.deathFlash = 0
    local positionScale = self.boardW / 520
    local objectScale = math.min(self.cellW, self.cellH) / 17
    local speedScale = math.max(0.70, math.min(1.28, objectScale))
    local laneLeft = self.originX
    local function car(x, w)
        local width = math.max(22, math.floor(w * objectScale))
        width = math.min(width, math.floor(self.cellW * 1.16))
        return {x = laneLeft + math.floor(x * positionScale), w = width}
    end
    local function log(x, w)
        local width = math.max(32, math.floor(w * objectScale))
        width = math.min(width, math.floor(self.cellW * 1.95))
        return {x = laneLeft + math.floor(x * positionScale), w = width}
    end
    self.waterLanes = {
        {row = 1, speed = 1.15 * speedScale, logs = {log(0, 70), log(156, 86), log(340, 72)}},
        {row = 2, speed = -1.35 * speedScale, logs = {log(72, 96), log(260, 74), log(428, 92)}}
    }
    self.lanes = {
        {row = 8, speed = 2.45 * speedScale, color = {0.82, 0.26, 0.18}, cars = {car(0, 38), car(132, 34), car(278, 46)}},
        {row = 7, speed = -2.65 * speedScale, color = {0.92, 0.72, 0.20}, cars = {car(64, 48), car(220, 38), car(368, 42)}},
        {row = 6, speed = 2.85 * speedScale, color = {0.32, 0.72, 0.86}, cars = {car(0, 34), car(168, 52), car(332, 34)}},
        {row = 5, speed = -3.00 * speedScale, color = {0.82, 0.44, 0.24}, cars = {car(96, 58), car(302, 38)}},
        {row = 4, speed = 2.55 * speedScale, color = {0.50, 0.38, 0.92}, cars = {car(24, 34), car(186, 50), car(360, 40)}},
        {row = 3, speed = -2.80 * speedScale, color = {0.30, 0.66, 0.30}, cars = {car(78, 42), car(244, 36), car(400, 46)}}
    }
end

function PZFroggerGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZFroggerGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZFroggerGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZFroggerGame:updateMovingRect(rect, speed)
    rect.x = rect.x + speed
    local left = self.originX
    local right = self.originX + self.boardW
    if speed > 0 and rect.x > right - rect.w then
        rect.x = left
    elseif speed < 0 and rect.x < left then
        rect.x = right - rect.w
    end
end

function PZFroggerGame:getFrogRect()
    local sizeW = math.max(12, math.floor(self.cellW * 0.62))
    local sizeH = math.max(10, math.floor(self.cellH * 0.68))
    local frogX = self.originX + self.frog.col * self.cellW + math.floor((self.cellW - sizeW) * 0.5)
    local frogY = self.originY + self.frog.row * self.cellH + math.floor((self.cellH - sizeH) * 0.5)
    return frogX, frogY, sizeW, sizeH
end

function PZFroggerGame:update()
    self.flashTick = self.flashTick + 1
    self.goalFlash = math.max(0, (self.goalFlash or 0) - 1)
    self.deathFlash = math.max(0, (self.deathFlash or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    if ComputerModGameInput.isDown(self, "up") then
        if not self.moveLock then self.frog.row = math.max(0, self.frog.row - 1); self.moveLock = true end
    elseif ComputerModGameInput.isDown(self, "down") then
        if not self.moveLock then self.frog.row = math.min(self.rows - 1, self.frog.row + 1); self.moveLock = true end
    elseif ComputerModGameInput.isDown(self, "left") then
        if not self.moveLock then self.frog.col = math.max(0, self.frog.col - 1); self.moveLock = true end
    elseif ComputerModGameInput.isDown(self, "right") then
        if not self.moveLock then self.frog.col = math.min(self.cols - 1, self.frog.col + 1); self.moveLock = true end
    else
        self.moveLock = false
    end

    local frogX, _, frogW = self:getFrogRect()
    local frogCenter = frogX + frogW * 0.5
    for i = 1, #self.waterLanes do
        local lane = self.waterLanes[i]
        local onLog = false
        for j = 1, #lane.logs do
            local log = lane.logs[j]
            self:updateMovingRect(log, lane.speed)
            if self.frog.row == lane.row and frogCenter >= log.x and frogCenter <= log.x + log.w then
                onLog = true
            end
        end
        if self.frog.row == lane.row and not onLog then
            self.gameState = "GAMEOVER"
            self.deathFlash = 16
            self:playGameOverSound()
            return
        end
    end

    for i = 1, #self.lanes do
        local lane = self.lanes[i]
        for j = 1, #lane.cars do
            local car = lane.cars[j]
            self:updateMovingRect(car, lane.speed)
            if self.frog.row == lane.row then
                local fx, _, fw = self:getFrogRect()
                if fx + fw >= car.x and fx <= car.x + car.w then
                    self.gameState = "GAMEOVER"
                    self.deathFlash = 16
                    self:playGameOverSound()
                    return
                end
            end
        end
    end

    if self.frog.row == 0 then
        self.score = self.score + 1
        self.goalFlash = 12
        self:playSound("ComputerBallHit")
        self.frog.col = 5
        self.frog.row = self.rows - 1
        if self.score >= 5 then
            self.gameState = "WIN"
            self:playWinSound()
        end
    end
end

function PZFroggerGame:laneY(row)
    return self.originY + row * self.cellH
end

function PZFroggerGame:drawCar(car, y, color)
    local x = math.max(self.originX, math.min(car.x, self.originX + self.boardW - car.w - 1))
    local h = math.max(13, math.floor(self.cellH * 0.70))
    local cy = y + math.floor((self.cellH - h) * 0.5)
    self:drawRect(x + 1, cy + 3, car.w, h, 0.30, 0, 0, 0)
    self:drawRect(x, cy + 4, car.w, h - 7, 1, color[1] * 0.78, color[2] * 0.78, color[3] * 0.78)
    self:drawRect(x + 4, cy, car.w - 8, h, 1, color[1], color[2], color[3])
    self:drawRect(x + 5, cy + 4, car.w - 10, math.max(4, math.floor(h * 0.28)), 1, 0.08, 0.10, 0.12)
    self:drawRect(x + 5, cy + 5, car.w - 10, 1, 0.45, 0.62, 0.76, 0.74)
    self:drawRect(x + 3, cy + h - 3, 6, 3, 1, 0.03, 0.03, 0.03)
    self:drawRect(x + car.w - 9, cy + h - 3, 6, 3, 1, 0.03, 0.03, 0.03)
end

function PZFroggerGame:drawLog(log, y)
    local x = math.max(self.originX, math.min(log.x, self.originX + self.boardW - log.w - 1))
    local h = math.max(11, math.floor(self.cellH * 0.55))
    local ly = y + math.floor((self.cellH - h) * 0.5)
    self:drawRect(x + 1, ly + 2, log.w, h, 0.26, 0, 0, 0)
    self:drawRect(x, ly, log.w, h, 1, 0.34, 0.20, 0.10)
    self:drawRect(x + 3, ly + 2, log.w - 6, 2, 0.72, 0.60, 0.38, 0.20)
    self:drawRect(x + 5, ly + h - 4, log.w - 10, 1, 0.40, 0.18, 0.09, 0.05)
    self:drawRect(x + log.w - 8, ly + 2, 4, h - 4, 0.55, 0.16, 0.08, 0.04)
end

function PZFroggerGame:drawFrog()
    local frogX, frogY, frogW, frogH = self:getFrogRect()
    self:drawRect(frogX + 1, frogY + 2, frogW, frogH, 0.28, 0, 0, 0)
    self:drawRect(frogX, frogY, frogW, frogH, 1, 0.22, 0.70, 0.22)
    self:drawRect(frogX + 2, frogY + 2, frogW - 4, math.max(2, math.floor(frogH * 0.32)), 0.45, 0.58, 0.92, 0.40)
    self:drawRect(frogX + 2, frogY + frogH - 4, 4, 4, 1, 0.10, 0.42, 0.10)
    self:drawRect(frogX + frogW - 6, frogY + frogH - 4, 4, 4, 1, 0.10, 0.42, 0.10)
    self:drawRect(frogX + math.floor(frogW * 0.18), frogY + math.floor(frogH * 0.18), 2, 2, 1, 0.02, 0.02, 0.02)
    self:drawRect(frogX + math.floor(frogW * 0.66), frogY + math.floor(frogH * 0.18), 2, 2, 1, 0.02, 0.02, 0.02)
end

function PZFroggerGame:drawHud()
    self:drawRect(0, 0, self.width, 23, 1, 0.008, 0.018, 0.010)
    self:drawRect(0, 22, self.width, 1, 1, 0.20, 0.42, 0.20)
    self:drawText("FROGGER.EXE", 8, 6, 0.60, 0.82, 0.54, 1, UIFont.Small)
    self:drawText("GOALS " .. tostring(self.score) .. "/5", 112, 6, 0.60, 0.82, 0.54, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "movement") .. " MOVE", self.width - 94, 6, 0.48, 0.62, 0.46, 1, UIFont.Small)
end

function PZFroggerGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.05, 0.08, 0.05)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.018, 0.008)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.20, 0.42, 0.20)
    self:drawText(title, boxX + 10, boxY + 19, 0.60, 0.82, 0.54, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.76, 0.76, 0.52, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.60, 0.82, 0.54, 1, UIFont.Small)
end

function PZFroggerGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZFroggerGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.022, 0.062, 0.030)
    self:drawHud()

    self:drawRect(self.originX - 2, self.originY - 2, self.boardW + 4, self.boardH + 4, 1, 0.05, 0.08, 0.05)
    self:drawRect(self.originX, self.originY, self.boardW, self.boardH, 1, 0.05, 0.16, 0.07)
    self:drawRect(self.originX, self:laneY(0), self.boardW, self.cellH - 2, 1, 0.08, 0.28, 0.10)
    for i = 0, 4 do
        local padX = self.originX + i * math.floor(self.boardW / 5) + math.floor(self.cellW * 0.35)
        self:drawRect(padX + 1, self:laneY(0) + 6, self.cellW, self.cellH - 10, 0.28, 0, 0, 0)
        self:drawRect(padX, self:laneY(0) + 4, self.cellW, self.cellH - 10, 1, 0.14, 0.42, 0.16)
    end

    for i = 1, #self.waterLanes do
        local lane = self.waterLanes[i]
        local y = self:laneY(lane.row)
        self:drawRect(self.originX, y, self.boardW, self.cellH - 2, 1, 0.025, 0.095, 0.22)
        local waveX = (self.flashTick * 1.4) % 36
        while waveX < self.boardW do
            self:drawRect(self.originX + waveX, y + math.floor(self.cellH * 0.55), 18, 1, 0.36, 0.28, 0.48, 0.72)
            waveX = waveX + 36
        end
        for j = 1, #lane.logs do
            self:drawLog(lane.logs[j], y)
        end
    end

    self:drawRect(self.originX, self:laneY(9), self.boardW, self.cellH - 2, 1, 0.08, 0.28, 0.10)
    self:drawRect(self.originX, self:laneY(10), self.boardW, self.cellH - 2, 1, 0.08, 0.28, 0.10)

    for i = 1, #self.lanes do
        local lane = self.lanes[i]
        local y = self:laneY(lane.row)
        self:drawRect(self.originX, y, self.boardW, self.cellH - 2, 1, 0.105, 0.108, 0.112)
        local stripeX = (self.flashTick * math.abs(lane.speed) * 0.7) % 52
        while stripeX <= self.boardW - 22 do
            self:drawRect(self.originX + stripeX, y + math.floor(self.cellH * 0.45), 22, 2, 0.32, 0.78, 0.76, 0.58)
            stripeX = stripeX + 52
        end
        for j = 1, #lane.cars do
            self:drawCar(lane.cars[j], y, lane.color)
        end
    end

    self:drawFrog()
    if self.goalFlash and self.goalFlash > 0 then
        self:drawRect(self.originX, self.originY, self.boardW, self.boardH, self.goalFlash / 120, 0.38, 0.72, 0.34)
    end
    if self.deathFlash and self.deathFlash > 0 then
        self:drawRect(self.originX, self.originY, self.boardW, self.boardH, self.deathFlash / 100, 0.80, 0.10, 0.08)
    end

    if self.gameState == "WIN" then
        self:drawOverlay("FROGGER COMPLETE", "GOALS " .. tostring(self.score) .. "/5")
    elseif self.gameState == "GAMEOVER" then
        self:drawOverlay("FROG LOST", "GOALS " .. tostring(self.score) .. "/5")
    end
    self:drawScanlines()
end

function PZFroggerGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZFroggerGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaFrogger.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaMissileCommand.lua
GameClasses['missile'] = (function()
require "ISUI/ISPanel"

local PZMissileCommandGame = ISPanel:derive("PZMissileCommandGame")

local function drawPixelLine(panel, x1, y1, x2, y2, a, r, g, b)
    local dx = x2 - x1
    local dy = y2 - y1
    local steps = math.max(math.abs(dx), math.abs(dy))
    if steps < 1 then
        panel:drawRect(x1, y1, 2, 2, a or 1, r or 1, g or 1, b or 1)
        return
    end
    for i = 0, steps do
        local t = i / steps
        local px = x1 + dx * t
        local py = y1 + dy * t
        panel:drawRect(px, py, 2, 2, a or 1, r or 1, g or 1, b or 1)
    end
end

function PZMissileCommandGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZMissileCommandGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.animationTick = 0
    self.hitFlash = 0
    self.cityFlash = 0
    self.wave = 1
    self.score = 0
    self.spawnTimer = 0
    self.fireCooldown = 0
    self.waveClearTimer = 0
    self.crosshair = {x = self.width * 0.5, y = self.height * 0.38}
    self.base = {x = self.width * 0.5, y = self.height - 24}
    self.cities = {
        {x = 54, alive = true},
        {x = 118, alive = true},
        {x = self.width - 118, alive = true},
        {x = self.width - 54, alive = true}
    }
    self.enemyMissiles = {}
    self.playerMissiles = {}
    self.explosions = {}
    self.waveMissiles = 11
    self.enemySpawned = 0
    self.stars = {}
    for i = 1, 42 do
        self.stars[i] = {
            x = (i * 31 + ZombRand(24)) % self.width,
            y = (i * 57 + ZombRand(19)) % math.max(1, self.height - 44),
            size = (i % 4 == 0) and 2 or 1,
            pulse = 0.5 + (ZombRand(40) / 100)
        }
    end
end

function PZMissileCommandGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZMissileCommandGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZMissileCommandGame:getAliveCityTargets()
    local targets = {}
    for i = 1, #self.cities do
        if self.cities[i].alive then
            targets[#targets + 1] = self.cities[i]
        end
    end
    return targets
end

function PZMissileCommandGame:spawnEnemyMissile()
    local targets = self:getAliveCityTargets()
    if #targets == 0 then return end
    local target = targets[ZombRand(#targets) + 1]
    local startX = 18 + ZombRand(math.max(1, self.width - 36))
    local startY = 18
    local dx = target.x - startX
    local dy = (self.height - 28) - startY
    local len = math.sqrt(dx * dx + dy * dy)
    if len <= 0 then len = 1 end
    local speed = 1.1 + (self.wave * 0.11)
    self.enemyMissiles[#self.enemyMissiles + 1] = {
        x = startX,
        y = startY,
        tx = target.x,
        ty = self.height - 28,
        vx = dx / len * speed,
        vy = dy / len * speed
    }
    self.enemySpawned = self.enemySpawned + 1
end

function PZMissileCommandGame:firePlayerMissile()
    if self.fireCooldown > 0 or self.gameState ~= "PLAYING" then return end
    self.fireCooldown = 10
    local startX = self.base.x
    local startY = self.base.y
    local dx = self.crosshair.x - startX
    local dy = self.crosshair.y - startY
    local len = math.sqrt(dx * dx + dy * dy)
    if len <= 0 then len = 1 end
    self.playerMissiles[#self.playerMissiles + 1] = {
        x = startX,
        y = startY,
        tx = self.crosshair.x,
        ty = self.crosshair.y,
        vx = dx / len * 4.6,
        vy = dy / len * 4.6
    }
    self:playSound("ComputerLaserShot")
end

function PZMissileCommandGame:spawnExplosion(x, y, radius)
    self.explosions[#self.explosions + 1] = {x = x, y = y, r = 2, maxR = radius or 28, grow = true}
end

function PZMissileCommandGame:updateCrosshair()
    local speed = 4
    if ComputerModGameInput.isDown(self, "left") then
        self.crosshair.x = math.max(18, self.crosshair.x - speed)
    end
    if ComputerModGameInput.isDown(self, "right") then
        self.crosshair.x = math.min(self.width - 18, self.crosshair.x + speed)
    end
    if ComputerModGameInput.isDown(self, "up") then
        self.crosshair.y = math.max(18, self.crosshair.y - speed)
    end
    if ComputerModGameInput.isDown(self, "down") then
        self.crosshair.y = math.min(self.height - 52, self.crosshair.y + speed)
    end
end

function PZMissileCommandGame:update()
    self.animationTick = (self.animationTick or 0) + 1
    self.hitFlash = math.max(0, (self.hitFlash or 0) - 1)
    self.cityFlash = math.max(0, (self.cityFlash or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    self:updateCrosshair()
    if self.fireCooldown > 0 then
        self.fireCooldown = self.fireCooldown - 1
    end
    if ComputerModGameInput.isDown(self, "action") and self.fireCooldown <= 0 then
        self:firePlayerMissile()
    end

    self.spawnTimer = self.spawnTimer + 1
    local spawnRate = math.max(16, 42 - self.wave * 3)
    if self.enemySpawned < self.waveMissiles and self.spawnTimer >= spawnRate then
        self.spawnTimer = 0
        self:spawnEnemyMissile()
    end

    for i = #self.playerMissiles, 1, -1 do
        local missile = self.playerMissiles[i]
        missile.x = missile.x + missile.vx
        missile.y = missile.y + missile.vy
        if math.abs(missile.x - missile.tx) <= math.abs(missile.vx) + 1 and math.abs(missile.y - missile.ty) <= math.abs(missile.vy) + 1 then
            self:spawnExplosion(missile.tx, missile.ty, 30)
            table.remove(self.playerMissiles, i)
        end
    end

    for i = #self.explosions, 1, -1 do
        local boom = self.explosions[i]
        if boom.grow then
            boom.r = boom.r + 2.8
            if boom.r >= boom.maxR then
                boom.grow = false
            end
        else
            boom.r = boom.r - 1.5
            if boom.r <= 1 then
                table.remove(self.explosions, i)
            end
        end
    end

    for i = #self.enemyMissiles, 1, -1 do
        local missile = self.enemyMissiles[i]
        missile.x = missile.x + missile.vx
        missile.y = missile.y + missile.vy

        local exploded = false
        for j = #self.explosions, 1, -1 do
            local boom = self.explosions[j]
            local dx = missile.x - boom.x
            local dy = missile.y - boom.y
            if dx * dx + dy * dy <= boom.r * boom.r then
                self.score = self.score + 25
                self.hitFlash = 5
                self:spawnExplosion(missile.x, missile.y, 18)
                self:playSound("ComputerBallHit")
                table.remove(self.enemyMissiles, i)
                exploded = true
                break
            end
        end
        if not exploded and missile.y >= self.height - 28 then
            for cityIndex = 1, #self.cities do
                local city = self.cities[cityIndex]
                if city.alive and math.abs(missile.x - city.x) <= 18 then
                    city.alive = false
                    self.cityFlash = 12
                    break
                end
            end
            self:spawnExplosion(missile.x, self.height - 28, 24)
            table.remove(self.enemyMissiles, i)
        end
    end

    if #self:getAliveCityTargets() == 0 then
        self.gameState = "GAMEOVER"
        self:playGameOverSound()
        return
    end

    if self.enemySpawned >= self.waveMissiles and #self.enemyMissiles == 0 and #self.playerMissiles == 0 and #self.explosions == 0 then
        self.waveClearTimer = self.waveClearTimer + 1
        if self.waveClearTimer >= 28 then
            self.wave = self.wave + 1
            self.waveMissiles = self.waveMissiles + 3
            self.enemySpawned = 0
            self.spawnTimer = 0
            self.waveClearTimer = 0
            for i = 1, #self.cities do
                if ZombRand(100) < 35 then
                    self.cities[i].alive = true
                end
            end
            self:playSound("ComputerWinOpen")
        end
    else
        self.waveClearTimer = 0
    end
end

function PZMissileCommandGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.008, 0.012, 0.020)
    self:drawRect(0, 25, self.width, 1, 1, 0.30, 0.42, 0.44)
    self:drawText("MISSILE.EXE", 10, 6, 0.66, 0.82, 0.82, 1, UIFont.Small)
    self:drawText("WAVE " .. tostring(self.wave), 112, 6, 0.66, 0.82, 0.82, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), 184, 6, 0.66, 0.82, 0.82, 1, UIFont.Small)
    self:drawText("CITY " .. tostring(#self:getAliveCityTargets()), self.width - 130, 6, 0.66, 0.82, 0.82, 1, UIFont.Small)
    self:drawText("INC " .. tostring(math.max(0, self.waveMissiles - self.enemySpawned)), self.width - 66, 6, 0.82, 0.72, 0.50, 1, UIFont.Small)
end

function PZMissileCommandGame:drawCity(city)
    local color = city.alive and {0.38, 0.72, 0.48} or {0.22, 0.16, 0.16}
    local y = self.height - 28
    self:drawRect(city.x - 16, y + 2, 32, 10, 0.28, 0, 0, 0)
    self:drawRect(city.x - 15, y, 30, 10, 1, color[1], color[2], color[3])
    self:drawRect(city.x - 10, y - 8, 7, 8, 1, color[1] * 0.86, color[2] * 0.86, color[3] * 0.86)
    self:drawRect(city.x + 3, y - 8, 7, 8, 1, color[1] * 0.86, color[2] * 0.86, color[3] * 0.86)
    if city.alive then
        self:drawRect(city.x - 10, y + 3, 2, 2, 0.85, 0.90, 0.94, 0.55)
        self:drawRect(city.x - 2, y + 3, 2, 2, 0.85, 0.90, 0.94, 0.55)
        self:drawRect(city.x + 6, y + 3, 2, 2, 0.85, 0.90, 0.94, 0.55)
    else
        self:drawRect(city.x - 13, y + 4, 26, 2, 1, 0.10, 0.08, 0.08)
    end
end

function PZMissileCommandGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 230)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.04, 0.06, 0.06)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.012, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.30, 0.42, 0.44)
    self:drawText(title, boxX + 10, boxY + 19, 0.66, 0.82, 0.82, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.82, 0.72, 0.50, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.66, 0.82, 0.82, 1, UIFont.Small)
end

function PZMissileCommandGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZMissileCommandGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.012, 0.018, 0.034)
    self:drawRect(0, 26, self.width, self.height * 0.30, 0.12, 0.10, 0.16, 0.24)
    self:drawRect(0, self.height * 0.42, self.width, self.height * 0.20, 0.06, 0.12, 0.18, 0.16)
    self:drawRect(0, self.height - 38, self.width, 38, 1, 0.08, 0.09, 0.11)
    self:drawHud()
    if self.hitFlash and self.hitFlash > 0 then
        self:drawRect(0, 26, self.width, self.height - 26, self.hitFlash / 95, 0.56, 0.70, 0.72)
    end
    if self.cityFlash and self.cityFlash > 0 then
        self:drawRect(0, self.height - 42, self.width, 42, self.cityFlash / 90, 0.82, 0.16, 0.12)
    end

    for i = 1, #self.stars do
        local star = self.stars[i]
        local pulse = 0.78 + math.abs(math.sin((self.animationTick + i * 3) * 0.05)) * star.pulse
        self:drawRect(star.x, star.y, star.size, star.size, math.min(1, pulse), 0.85, 0.85, 0.92)
    end

    for i = 1, 5 do
        local gy = math.floor(self.height - 44 - i * 28)
        self:drawRect(0, gy, self.width, 1, 0.04, 0.22, 0.4, 0.2)
    end

    for i = 1, #self.cities do
        self:drawCity(self.cities[i])
    end

    self:drawRect(self.base.x - 14, self.base.y - 4, 28, 8, 1, 0.62, 0.66, 0.70)
    self:drawRect(self.base.x - 4, self.base.y - 14, 8, 10, 1, 0.62, 0.66, 0.70)
    local aimDx = self.crosshair.x - self.base.x
    local aimDy = self.crosshair.y - self.base.y
    local aimLen = math.max(1, math.sqrt(aimDx * aimDx + aimDy * aimDy))
    drawPixelLine(self, self.base.x, self.base.y - 10, self.base.x + (aimDx / aimLen) * 18, self.base.y - 10 + (aimDy / aimLen) * 18, 1, 0.82, 0.82, 0.88)

    for i = 1, #self.playerMissiles do
        local missile = self.playerMissiles[i]
        drawPixelLine(self, self.base.x, self.base.y, missile.x, missile.y, 0.8, 0.55, 0.82, 1)
        self:drawRect(missile.x - 1, missile.y - 1, 3, 3, 1, 0.72, 0.92, 1)
    end

    for i = 1, #self.enemyMissiles do
        local missile = self.enemyMissiles[i]
        drawPixelLine(self, missile.x, missile.y, missile.tx, missile.ty, 0.6, 0.85, 0.22, 0.22)
        self:drawRect(missile.x - 1, missile.y - 1, 3, 3, 1, 1, 0.45, 0.32)
    end

    for i = 1, #self.explosions do
        local boom = self.explosions[i]
        self:drawRect(boom.x - boom.r, boom.y - boom.r, boom.r * 2, boom.r * 2, 0.18, 1, 0.92, 0.45)
        self:drawRect(boom.x - boom.r * 0.62, boom.y - boom.r * 0.62, boom.r * 1.24, boom.r * 1.24, 0.3, 1, 0.55, 0.22)
        self:drawRect(boom.x - boom.r * 0.28, boom.y - boom.r * 0.28, boom.r * 0.56, boom.r * 0.56, 0.5, 1, 0.96, 0.74)
    end

    local crosshairPulse = 8 + math.floor(math.abs(math.sin((self.animationTick or 0) * 0.09)) * 3)
    drawPixelLine(self, self.crosshair.x - crosshairPulse, self.crosshair.y, self.crosshair.x + crosshairPulse, self.crosshair.y, 1, 0.85, 0.92, 0.35)
    drawPixelLine(self, self.crosshair.x, self.crosshair.y - crosshairPulse, self.crosshair.x, self.crosshair.y + crosshairPulse, 1, 0.85, 0.92, 0.35)
    self:drawRect(self.crosshair.x - 1, self.crosshair.y - 1, 3, 3, 1, 1, 0.96, 0.52)

    if self.waveClearTimer > 0 then
        local alpha = math.min(0.78, self.waveClearTimer / 30)
        self:drawRect(self.width * 0.5 - 70, 38, 140, 24, alpha, 0.006, 0.012, 0.018)
        self:drawText("WAVE CLEAR", self.width * 0.5 - 34, 45, 0.66, 0.82, 0.82, 1, UIFont.Small)
    end

    if self.gameState == "GAMEOVER" then
        self:drawOverlay("DEFENSE FAILED", "SCORE " .. tostring(self.score))
    end
    self:drawScanlines()
end

function PZMissileCommandGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZMissileCommandGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaMissileCommand.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaLunarLander.lua
GameClasses['lander'] = (function()
require "ISUI/ISPanel"

local PZLunarLanderGame = ISPanel:derive("PZLunarLanderGame")

local function drawPixelLine(panel, x1, y1, x2, y2, a, r, g, b)
    local dx = x2 - x1
    local dy = y2 - y1
    local steps = math.max(math.abs(dx), math.abs(dy))
    if steps < 1 then
        panel:drawRect(x1, y1, 2, 2, a or 1, r or 1, g or 1, b or 1)
        return
    end
    for i = 0, steps do
        local t = i / steps
        local px = x1 + dx * t
        local py = y1 + dy * t
        panel:drawRect(px, py, 2, 2, a or 1, r or 1, g or 1, b or 1)
    end
end

function PZLunarLanderGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZLunarLanderGame:buildTerrain()
    local h = self.height
    local padHalf = 30 + ZombRand(13)
    local padCenter = 150 + ZombRand(math.max(1, self.width - 300))
    local padY = h - (94 + ZombRand(20))
    local padX1 = padCenter - padHalf
    local padX2 = padCenter + padHalf

    self.pad = {x1 = padX1, x2 = padX2, y = padY}
    self.terrain = {
        {x = 0, y = h - (34 + ZombRand(10))},
        {x = 42 + ZombRand(12), y = h - (58 + ZombRand(16))},
        {x = 96 + ZombRand(14), y = h - (46 + ZombRand(14))},
        {x = padX1 - (68 + ZombRand(16)), y = padY - (22 + ZombRand(20))},
        {x = padX1 - (24 + ZombRand(8)), y = padY - (6 + ZombRand(8))},
        {x = padX1, y = padY},
        {x = padX2, y = padY},
        {x = padX2 + (26 + ZombRand(10)), y = padY - (6 + ZombRand(10))},
        {x = padX2 + (82 + ZombRand(18)), y = padY - (18 + ZombRand(24))},
        {x = self.width, y = h - (36 + ZombRand(12))}
    }
end

function PZLunarLanderGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.animationTick = 0
    self.crashFlash = 0
    self.ship = {
        x = self.width * 0.28,
        y = 46,
        vx = 0,
        vy = 0,
        angle = 0,
        fuel = 100
    }
    self.stars = {}
    self.score = 0
    self:buildTerrain()
    for i = 1, 44 do
        self.stars[i] = {
            x = (i * 37 + ZombRand(21)) % self.width,
            y = (i * 61 + ZombRand(17)) % math.max(1, self.height - 130),
            size = (i % 3 == 0) and 2 or 1,
            pulse = 0.55 + (ZombRand(35) / 100)
        }
    end
end

function PZLunarLanderGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZLunarLanderGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZLunarLanderGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZLunarLanderGame:getGroundY(x)
    local points = self.terrain
    for i = 1, #points - 1 do
        local a = points[i]
        local b = points[i + 1]
        if x >= a.x and x <= b.x then
            local span = math.max(1, b.x - a.x)
            local t = (x - a.x) / span
            return a.y + (b.y - a.y) * t
        end
    end
    return self.height - 24
end

function PZLunarLanderGame:update()
    self.animationTick = (self.animationTick or 0) + 1
    self.crashFlash = math.max(0, (self.crashFlash or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    if ComputerModGameInput.isDown(self, "left") then
        self.ship.angle = self.ship.angle - 0.05
    end
    if ComputerModGameInput.isDown(self, "right") then
        self.ship.angle = self.ship.angle + 0.05
    end

    local thrusting = ComputerModGameInput.isDown(self, "up") and self.ship.fuel > 0
    if thrusting then
        self.ship.vx = self.ship.vx + math.sin(self.ship.angle) * 0.035
        self.ship.vy = self.ship.vy - math.cos(self.ship.angle) * 0.055
        self.ship.fuel = math.max(0, self.ship.fuel - 0.45)
    end

    self.ship.vy = self.ship.vy + 0.028
    self.ship.x = self.ship.x + self.ship.vx
    self.ship.y = self.ship.y + self.ship.vy
    self.ship.vx = self.ship.vx * 0.995

    if self.ship.x < 12 then
        self.ship.x = 12
        self.ship.vx = math.abs(self.ship.vx) * 0.4
    elseif self.ship.x > self.width - 12 then
        self.ship.x = self.width - 12
        self.ship.vx = -math.abs(self.ship.vx) * 0.4
    end

    local footY = self.ship.y + 11
    local groundY = self:getGroundY(self.ship.x)
    if footY >= groundY then
        local gentle = math.abs(self.ship.vx) <= 0.55 and math.abs(self.ship.vy) <= 0.75
        local aligned = math.abs(self.ship.angle) <= 0.18
        local onPad = self.ship.x >= self.pad.x1 and self.ship.x <= self.pad.x2 and math.abs(groundY - self.pad.y) <= 0.2
        if gentle and aligned and onPad then
            self.gameState = "WIN"
            self.score = math.floor(self.ship.fuel * 10)
            self.ship.y = groundY - 11
            self.ship.vx = 0
            self.ship.vy = 0
            self.ship.angle = 0
            self:playWinSound()
        else
            self.gameState = "GAMEOVER"
            self.ship.y = groundY - 11
            self.crashFlash = 18
            self:playGameOverSound()
        end
    end
end

function PZLunarLanderGame:drawShip()
    local x = self.ship.x
    local y = self.ship.y
    local sinA = math.sin(self.ship.angle)
    local cosA = math.cos(self.ship.angle)
    local noseX = x + sinA * 10
    local noseY = y - cosA * 10
    local leftX = x - cosA * 6 - sinA * 5
    local leftY = y - sinA * 6 + cosA * 5
    local rightX = x + cosA * 6 - sinA * 5
    local rightY = y + sinA * 6 + cosA * 5
    drawPixelLine(self, leftX, leftY, noseX, noseY, 1, 0.92, 0.92, 0.96)
    drawPixelLine(self, rightX, rightY, noseX, noseY, 1, 0.92, 0.92, 0.96)
    drawPixelLine(self, leftX, leftY, rightX, rightY, 1, 0.92, 0.92, 0.96)
    drawPixelLine(self, leftX, leftY, leftX - cosA * 7, leftY - sinA * 7, 1, 0.72, 0.72, 0.78)
    drawPixelLine(self, rightX, rightY, rightX + cosA * 7, rightY + sinA * 7, 1, 0.72, 0.72, 0.78)
    if ComputerModGameInput.isDown(self, "up") and self.ship.fuel > 0 and self.gameState == "PLAYING" then
        local flameX = x - sinA * 11
        local flameY = y + cosA * 11
        drawPixelLine(self, x - sinA * 6, y + cosA * 6, flameX, flameY, 1, 1, 0.68, 0.22)
        drawPixelLine(self, x - sinA * 4 - cosA * 2, y + cosA * 4 - sinA * 2, flameX - cosA * 2, flameY - sinA * 2, 0.9, 1, 0.38, 0.12)
        drawPixelLine(self, x - sinA * 4 + cosA * 2, y + cosA * 4 + sinA * 2, flameX + cosA * 2, flameY + sinA * 2, 0.9, 1, 0.82, 0.32)
    end
end

function PZLunarLanderGame:drawHud()
    local altitude = math.max(0, math.floor(self:getGroundY(self.ship.x) - (self.ship.y + 11)))
    local angleDeg = math.floor(math.deg(self.ship.angle))
    self:drawRect(0, 0, self.width, 25, 1, 0.006, 0.010, 0.018)
    self:drawRect(0, 24, self.width, 1, 1, 0.34, 0.36, 0.44)
    self:drawText("LANDER.EXE", 10, 7, 0.72, 0.74, 0.84, 1, UIFont.Small)
    self:drawText("FUEL " .. tostring(math.floor(self.ship.fuel)), 110, 7, 0.72, 0.74, 0.84, 1, UIFont.Small)
    self:drawText("ALT " .. tostring(altitude), 184, 7, 0.72, 0.74, 0.84, 1, UIFont.Small)
    self:drawText(string.format("V %.2f", self.ship.vy), self.width - 132, 7, 0.72, 0.74, 0.84, 1, UIFont.Small)
    self:drawText("ANG " .. tostring(angleDeg), self.width - 66, 7, 0.72, 0.74, 0.84, 1, UIFont.Small)
end

function PZLunarLanderGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 230)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.05, 0.05, 0.06)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.010, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.34, 0.36, 0.44)
    self:drawText(title, boxX + 10, boxY + 19, 0.72, 0.74, 0.84, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.78, 0.78, 0.58, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.72, 0.74, 0.84, 1, UIFont.Small)
end

function PZLunarLanderGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZLunarLanderGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.010, 0.022)
    self:drawRect(0, 25, self.width, self.height * 0.26, 0.12, 0.14, 0.18, 0.30)
    self:drawRect(0, self.height * 0.30, self.width, self.height * 0.18, 0.08, 0.10, 0.12, 0.24)
    for i = 1, #self.stars do
        local star = self.stars[i]
        local pulse = 0.82 + math.abs(math.sin((self.animationTick + i * 5) * 0.04)) * star.pulse
        self:drawRect(star.x, star.y, star.size, star.size, math.min(1, pulse), 0.74, 0.76, 0.86)
    end
    self:drawHud()
    if self.crashFlash and self.crashFlash > 0 then
        self:drawRect(0, 25, self.width, self.height - 25, self.crashFlash / 100, 0.82, 0.14, 0.10)
    end

    for i = 1, #self.terrain - 1 do
        local a = self.terrain[i]
        local b = self.terrain[i + 1]
        drawPixelLine(self, a.x, a.y, b.x, b.y, 1, 0.56, 0.56, 0.62)
        self:drawRect(a.x, a.y, math.max(1, b.x - a.x), self.height - a.y, 0.16, 0.18, 0.16, 0.13)
    end
    local padGlow = 0.5 + math.abs(math.sin((self.animationTick or 0) * 0.08)) * 0.4
    self:drawRect(self.pad.x1 - 2, self.pad.y - 4, self.pad.x2 - self.pad.x1 + 4, 8, 0.16, 0.34, 0.72, 0.34)
    self:drawRect(self.pad.x1, self.pad.y - 2, self.pad.x2 - self.pad.x1, 4, 0.75 + padGlow * 0.2, 0.34, 0.72, 0.34)
    self:drawText("PAD", self.pad.x1 + math.floor((self.pad.x2 - self.pad.x1) * 0.5) - 12, self.pad.y - 16, 0.60, 0.82, 0.60, 1, UIFont.Small)
    local safeText = math.abs(self.ship.vx) <= 0.55 and math.abs(self.ship.vy) <= 0.75 and math.abs(self.ship.angle) <= 0.18 and "SAFE APPROACH" or "STABILIZE SHIP"
    local safeColor = safeText == "SAFE APPROACH" and {0.60, 0.82, 0.60} or {0.82, 0.72, 0.48}
    self:drawText(safeText, self.width * 0.5 - 44, 28, safeColor[1], safeColor[2], safeColor[3], 1, UIFont.Small)

    self:drawShip()

    if self.gameState == "WIN" then
        self:drawOverlay("LANDING CONFIRMED", "SCORE " .. tostring(self.score))
    elseif self.gameState == "GAMEOVER" then
        self:drawOverlay("CRASH LANDING", "FUEL " .. tostring(math.floor(self.ship.fuel)))
    end
    self:drawScanlines()
end

function PZLunarLanderGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZLunarLanderGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaLunarLander.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaCircuitRunner.lua
GameClasses['circuit'] = (function()
require "ISUI/ISPanel"

local PZCircuitRunnerGame = ISPanel:derive("PZCircuitRunnerGame")

local circuitMaps = {
    {
        "###############",
        "#P....#.....cE#",
        "#.###.#.#####.#",
        "#...#...#.....#",
        "###.#####.###.#",
        "#c..#.....#...#",
        "#.###.###.#.###",
        "#.....#...#..c#",
        "#.#####.###...#",
        "###############"
    },
    {
        "###############",
        "#P..#....#...E#",
        "#.#.#.##.#.#..#",
        "#.#...#..#.#c.#",
        "#.#####.##.####",
        "#.....#....#..#",
        "###.#.####.#.##",
        "#c..#......#c.#",
        "#.########....#",
        "###############"
    },
    {
        "###############",
        "#P....#...c..E#",
        "####..#.#####.#",
        "#.....#.....#.#",
        "#.#########.#.#",
        "#...c.....#...#",
        "#.#####.#.###.#",
        "#.....#.#...c.#",
        "###...#.#####.#",
        "###############"
    }
}

local droneDirections = {
    {x = 1, y = 0},
    {x = -1, y = 0},
    {x = 0, y = 1},
    {x = 0, y = -1}
}

function PZCircuitRunnerGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZCircuitRunnerGame:isReservedDroneCell(x, y)
    if self.player and math.abs(self.player.x - x) + math.abs(self.player.y - y) < 5 then return true end
    if self.exit and self.exit.x == x and self.exit.y == y then return true end
    for i = 1, #self.chips do
        if self.chips[i].x == x and self.chips[i].y == y then return true end
    end
    return false
end

function PZCircuitRunnerGame:getOpenNeighborCount(x, y)
    local count = 0
    for i = 1, #droneDirections do
        local dir = droneDirections[i]
        if not self:isWall(x + dir.x, y + dir.y) then
            count = count + 1
        end
    end
    return count
end

function PZCircuitRunnerGame:getDroneSpawnCells()
    local cells = {}
    local backup = {}
    for y = 2, #self.grid - 1 do
        for x = 2, #self.grid[y] - 1 do
            if not self:isWall(x, y) and not self:isReservedDroneCell(x, y) then
                local cell = {x = x, y = y}
                backup[#backup + 1] = cell
                if self:getOpenNeighborCount(x, y) >= 2 then
                    cells[#cells + 1] = cell
                end
            end
        end
    end
    if #cells == 0 then
        return backup
    end
    return cells
end

function PZCircuitRunnerGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.tick = 0
    self.chipFlash = 0
    self.deathFlash = 0
    self.moveCooldown = 0
    self.droneCooldown = 0
    self.score = 0
    self.mapIndex = ZombRand(#circuitMaps) + 1
    self.grid = {}
    self.chips = {}
    self.drones = {}
    local source = circuitMaps[self.mapIndex]
    for y = 1, #source do
        self.grid[y] = {}
        for x = 1, string.len(source[y]) do
            local ch = string.sub(source[y], x, x)
            if ch == "P" then
                self.player = {x = x, y = y}
                self.grid[y][x] = "."
            elseif ch == "E" then
                self.exit = {x = x, y = y}
                self.grid[y][x] = "."
            elseif ch == "c" then
                self.chips[#self.chips + 1] = {x = x, y = y, taken = false}
                self.grid[y][x] = "."
            else
                self.grid[y][x] = ch
            end
        end
    end
    self.totalChips = #self.chips
    local spawnCells = self:getDroneSpawnCells()
    local droneCount = math.min(3, #spawnCells)
    for i = 1, droneCount do
        local pick = ZombRand(#spawnCells) + 1
        local cell = table.remove(spawnCells, pick)
        local dir = droneDirections[ZombRand(#droneDirections) + 1]
        self.drones[#self.drones + 1] = {x = cell.x, y = cell.y, dx = dir.x, dy = dir.y, wait = i * 2}
    end
end

function PZCircuitRunnerGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZCircuitRunnerGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZCircuitRunnerGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZCircuitRunnerGame:isWall(x, y)
    return not self.grid[y] or self.grid[y][x] == "#"
end

function PZCircuitRunnerGame:chipsRemaining()
    local left = 0
    for i = 1, #self.chips do
        if not self.chips[i].taken then
            left = left + 1
        end
    end
    return left
end

function PZCircuitRunnerGame:tryMove(dx, dy)
    local nx = self.player.x + dx
    local ny = self.player.y + dy
    if self:isWall(nx, ny) then return end
    self.player.x = nx
    self.player.y = ny
    for i = 1, #self.chips do
        local chip = self.chips[i]
        if not chip.taken and chip.x == nx and chip.y == ny then
            chip.taken = true
            self.score = self.score + 100
            self.chipFlash = 8
            self:playSound("ComputerBallHit")
        end
    end
    if self.exit and self.exit.x == nx and self.exit.y == ny and self:chipsRemaining() == 0 then
        self.gameState = "WIN"
        self.score = self.score + 500
        self:playWinSound()
    end
    for i = 1, #self.drones do
        if self.drones[i].x == nx and self.drones[i].y == ny then
            self.gameState = "GAMEOVER"
            self.deathFlash = 14
            self:playGameOverSound()
            return
        end
    end
end

function PZCircuitRunnerGame:updateDrones()
    for i = 1, #self.drones do
        local drone = self.drones[i]
        drone.wait = math.max(0, (drone.wait or 0) - 1)
        if drone.wait <= 0 then
            local options = {}
            local forwardX = drone.x + (drone.dx or 0)
            local forwardY = drone.y + (drone.dy or 0)
            if not self:isWall(forwardX, forwardY) then
                options[#options + 1] = {x = drone.dx or 0, y = drone.dy or 0}
                options[#options + 1] = {x = drone.dx or 0, y = drone.dy or 0}
            end
            for d = 1, #droneDirections do
                local dir = droneDirections[d]
                if not self:isWall(drone.x + dir.x, drone.y + dir.y) and not (dir.x == -(drone.dx or 0) and dir.y == -(drone.dy or 0)) then
                    options[#options + 1] = dir
                end
            end
            if #options == 0 then
                for d = 1, #droneDirections do
                    local dir = droneDirections[d]
                    if not self:isWall(drone.x + dir.x, drone.y + dir.y) then
                        options[#options + 1] = dir
                    end
                end
            end
            if #options > 0 then
                local dir = options[ZombRand(#options) + 1]
                drone.dx = dir.x
                drone.dy = dir.y
                drone.x = drone.x + dir.x
                drone.y = drone.y + dir.y
            end
            drone.wait = 1
        end
        if drone.x == self.player.x and drone.y == self.player.y then
            self.gameState = "GAMEOVER"
            self.deathFlash = 14
            self:playGameOverSound()
        end
    end
end

function PZCircuitRunnerGame:update()
    self.tick = (self.tick or 0) + 1
    self.chipFlash = math.max(0, (self.chipFlash or 0) - 1)
    self.deathFlash = math.max(0, (self.deathFlash or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end
    self.moveCooldown = math.max(0, (self.moveCooldown or 0) - 1)
    self.droneCooldown = math.max(0, (self.droneCooldown or 0) - 1)
    if self.moveCooldown <= 0 then
        if ComputerModGameInput.isDown(self, "left") then
            self:tryMove(-1, 0)
            self.moveCooldown = 8
        elseif ComputerModGameInput.isDown(self, "right") then
            self:tryMove(1, 0)
            self.moveCooldown = 8
        elseif ComputerModGameInput.isDown(self, "up") then
            self:tryMove(0, -1)
            self.moveCooldown = 8
        elseif ComputerModGameInput.isDown(self, "down") then
            self:tryMove(0, 1)
            self.moveCooldown = 8
        end
    end
    if self.droneCooldown <= 0 then
        self:updateDrones()
        self.droneCooldown = 14
    end
end

function PZCircuitRunnerGame:drawNode(cx, cy, size, r, g, b)
    self:drawRect(cx + size * 0.25, cy + size * 0.25, size * 0.5, size * 0.5, 1, r, g, b)
    self:drawRect(cx + size * 0.4, cy, size * 0.2, size, 0.45, r, g, b)
    self:drawRect(cx, cy + size * 0.4, size, size * 0.2, 0.45, r, g, b)
end

function PZCircuitRunnerGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.004, 0.014, 0.016)
    self:drawRect(0, 25, self.width, 1, 1, 0.18, 0.44, 0.40)
    self:drawText("CIRCUIT.EXE", 10, 7, 0.60, 0.84, 0.78, 1, UIFont.Small)
    self:drawText("CHIP " .. tostring(self.totalChips - self:chipsRemaining()) .. "/" .. tostring(self.totalChips), 112, 7, 0.60, 0.84, 0.78, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score or 0), self.width - 92, 7, 0.60, 0.84, 0.78, 1, UIFont.Small)
end

function PZCircuitRunnerGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 230)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.03, 0.07, 0.06)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.004, 0.014, 0.016)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.18, 0.44, 0.40)
    self:drawText(title, boxX + 10, boxY + 19, 0.60, 0.84, 0.78, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.78, 0.78, 0.56, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.60, 0.84, 0.78, 1, UIFont.Small)
end

function PZCircuitRunnerGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZCircuitRunnerGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.018, 0.020)
    self:drawHud()
    local cols = 15
    local rows = 10
    local cell = math.floor(math.min((self.width - 32) / cols, (self.height - 54) / rows))
    local gridW = cell * cols
    local gridH = cell * rows
    local ox = math.floor((self.width - gridW) * 0.5)
    local oy = 38
    self:drawRect(ox - 4, oy - 4, gridW + 8, gridH + 8, 1, 0.02, 0.18, 0.16)
    self:drawRect(ox, oy, gridW, gridH, 1, 0.004, 0.036, 0.036)
    if self.chipFlash and self.chipFlash > 0 then
        self:drawRect(ox, oy, gridW, gridH, self.chipFlash / 100, 0.58, 0.54, 0.18)
    end
    if self.deathFlash and self.deathFlash > 0 then
        self:drawRect(ox, oy, gridW, gridH, self.deathFlash / 90, 0.82, 0.08, 0.06)
    end
    for y = 1, rows do
        for x = 1, cols do
            local px = ox + (x - 1) * cell
            local py = oy + (y - 1) * cell
            if self.grid[y] and self.grid[y][x] == "#" then
                self:drawRect(px + 1, py + 1, cell - 2, cell - 2, 1, 0.035, 0.24, 0.22)
                self:drawRect(px + 2, py + 2, cell - 4, 2, 0.45, 0.20, 0.66, 0.56)
            else
                self:drawRect(px, py, cell, 1, 0.10, 0.12, 0.50, 0.46)
                self:drawRect(px, py, 1, cell, 0.10, 0.12, 0.50, 0.46)
            end
        end
    end
    local exitColor = self:chipsRemaining() == 0 and {0.28, 1, 0.48} or {0.35, 0.35, 0.35}
    if self.exit then
        self:drawRect(ox + (self.exit.x - 1) * cell + 3, oy + (self.exit.y - 1) * cell + 3, cell - 6, cell - 6, 1, exitColor[1], exitColor[2], exitColor[3])
        self:drawRect(ox + (self.exit.x - 1) * cell + 6, oy + (self.exit.y - 1) * cell + 6, cell - 12, cell - 12, 0.40, 0.01, 0.02, 0.02)
    end
    for i = 1, #self.chips do
        local chip = self.chips[i]
        if not chip.taken then
            self:drawNode(ox + (chip.x - 1) * cell + 4, oy + (chip.y - 1) * cell + 4, cell - 8, 0.96, 0.86, 0.18)
        end
    end
    for i = 1, #self.drones do
        local drone = self.drones[i]
        local px = ox + (drone.x - 1) * cell
        local py = oy + (drone.y - 1) * cell
        self:drawRect(px + 5, py + 5, cell - 10, cell - 10, 1, 0.78, 0.10, 0.10)
        self:drawRect(px + 8, py + 8, cell - 16, cell - 16, 1, 0.96, 0.52, 0.18)
        self:drawRect(px + math.floor(cell * 0.44), py + 3, 2, cell - 6, 0.40, 0.96, 0.52, 0.18)
    end
    local pX = ox + (self.player.x - 1) * cell
    local pY = oy + (self.player.y - 1) * cell
    self:drawRect(pX + 4, pY + 4, cell - 8, cell - 8, 1, 0.14, 0.46, 0.82)
    self:drawRect(pX + 8, pY + 8, cell - 16, cell - 16, 1, 0.56, 0.78, 0.90)
    if self.gameState == "WIN" then
        self:drawOverlay("SYSTEM CLEAR", "SCORE " .. tostring(self.score or 0))
    elseif self.gameState == "GAMEOVER" then
        self:drawOverlay("SHORT CIRCUIT", "CHIP " .. tostring(self.totalChips - self:chipsRemaining()) .. "/" .. tostring(self.totalChips))
    end
    self:drawScanlines()
end

function PZCircuitRunnerGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZCircuitRunnerGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaCircuitRunner.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaMemoryMatch.lua
GameClasses['memory'] = (function()
require "ISUI/ISPanel"

local PZMemoryMatchGame = ISPanel:derive("PZMemoryMatchGame")

local memorySymbols = {"A", "B", "C", "D", "E", "F", "G", "H"}

local function shuffleCards(cards)
    for i = #cards, 2, -1 do
        local j = ZombRand(i) + 1
        cards[i], cards[j] = cards[j], cards[i]
    end
end

local function drawBorder(panel, x, y, w, h, a, r, g, b)
    panel:drawRect(x, y, w, 1, a, r, g, b)
    panel:drawRect(x, y, 1, h, a, r, g, b)
    panel:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    panel:drawRect(x, y + h - 1, w, 1, a, r, g, b)
end

function PZMemoryMatchGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZMemoryMatchGame:resetGame()
    self.gameState = "PLAYING"
    self.winSoundPlayed = false
    self.animationTick = 0
    self.flipDelay = 0
    self.matchFlash = 0
    self.missFlash = 0
    self.firstPick = nil
    self.secondPick = nil
    self.matches = 0
    self.moves = 0
    self.score = 0
    self.cards = {}
    local pool = {}
    for i = 1, #memorySymbols do
        pool[#pool + 1] = memorySymbols[i]
        pool[#pool + 1] = memorySymbols[i]
    end
    shuffleCards(pool)
    for i = 1, 16 do
        self.cards[i] = {symbol = pool[i], open = false, matched = false}
    end
end

function PZMemoryMatchGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZMemoryMatchGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZMemoryMatchGame:getCardLayout()
    local boardSize = math.min(self.width - 34, self.height - 62)
    local cardSize = math.floor((boardSize - 24) / 4)
    local startX = math.floor((self.width - (cardSize * 4 + 24)) / 2)
    local startY = 44
    return startX, startY, cardSize
end

function PZMemoryMatchGame:getCardAt(x, y)
    local startX, startY, cardSize = self:getCardLayout()
    for row = 0, 3 do
        for col = 0, 3 do
            local index = row * 4 + col + 1
            local cx = startX + col * (cardSize + 8)
            local cy = startY + row * (cardSize + 8)
            if x >= cx and x <= cx + cardSize and y >= cy and y <= cy + cardSize then
                return index
            end
        end
    end
    return nil
end

function PZMemoryMatchGame:onMouseDown(x, y)
    if self.gameState ~= "PLAYING" then
        self:resetGame()
        return true
    end
    if self.flipDelay > 0 then return true end
    local index = self:getCardAt(x, y)
    if not index then return true end
    local card = self.cards[index]
    if not card or card.open or card.matched then return true end
    card.open = true
    if not self.firstPick then
        self.firstPick = index
    else
        self.secondPick = index
        self.moves = self.moves + 1
        local first = self.cards[self.firstPick]
        if first and first.symbol == card.symbol then
            first.matched = true
            card.matched = true
            self.matches = self.matches + 1
            self.score = self.score + 100 + math.max(0, 40 - self.moves)
            self.matchFlash = 8
            self:playSound("ComputerBallHit")
            self.firstPick = nil
            self.secondPick = nil
            if self.matches >= 8 then
                self.gameState = "WIN"
                self.score = self.score + 500
                self:playWinSound()
            end
        else
            self.flipDelay = 34
            self.missFlash = 8
        end
    end
    return true
end

function PZMemoryMatchGame:update()
    self.animationTick = (self.animationTick or 0) + 1
    self.matchFlash = math.max(0, (self.matchFlash or 0) - 1)
    self.missFlash = math.max(0, (self.missFlash or 0) - 1)
    local selectedX, selectedY, activated = ComputerModGameInput.updateGridSelection(self, 4, 4)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end
    if activated and self.flipDelay <= 0 then
        local startX, startY, cardSize = self:getCardLayout()
        self:onMouseDown(startX + (selectedX - 1) * (cardSize + 8) + cardSize / 2, startY + (selectedY - 1) * (cardSize + 8) + cardSize / 2)
    end
    if self.flipDelay > 0 then
        self.flipDelay = self.flipDelay - 1
        if self.flipDelay <= 0 then
            if self.firstPick and self.cards[self.firstPick] then self.cards[self.firstPick].open = false end
            if self.secondPick and self.cards[self.secondPick] then self.cards[self.secondPick].open = false end
            self.firstPick = nil
            self.secondPick = nil
        end
    end
end

function PZMemoryMatchGame:drawCard(x, y, size, card, index)
    local pulse = 0.05 + math.abs(math.sin((self.animationTick + index * 7) * 0.05)) * 0.06
    if card.matched then
        self:drawRect(x + 1, y + 2, size, size, 0.24, 0, 0, 0)
        self:drawRect(x, y, size, size, 1, 0.04, 0.18, 0.12)
        drawBorder(self, x, y, size, size, 1, 0.34, 0.72, 0.46)
        self:drawText(card.symbol, x + size * 0.5 - 4, y + size * 0.5 - 8, 0.62, 0.86, 0.62, 1, UIFont.Medium)
    elseif card.open then
        self:drawRect(x + 1, y + 2, size, size, 0.24, 0, 0, 0)
        self:drawRect(x, y, size, size, 1, 0.62, 0.58, 0.36)
        drawBorder(self, x, y, size, size, 1, 0.12, 0.10, 0.06)
        self:drawText(card.symbol, x + size * 0.5 - 4, y + size * 0.5 - 8, 0.03, 0.03, 0.02, 1, UIFont.Medium)
    else
        self:drawRect(x + 1, y + 2, size, size, 0.26, 0, 0, 0)
        self:drawRect(x, y, size, size, 1, 0.018 + pulse, 0.030 + pulse, 0.072 + pulse)
        drawBorder(self, x, y, size, size, 1, 0.20, 0.28, 0.46)
        self:drawRect(x + 5, y + 5, size - 10, 1, 0.55, 0.40, 0.46, 0.72)
        self:drawRect(x + 5, y + size - 6, size - 10, 1, 0.35, 0.40, 0.46, 0.72)
        self:drawText("MEM", x + size * 0.5 - 12, y + size * 0.5 - 7, 0.54, 0.62, 0.82, 1, UIFont.Small)
    end
end

function PZMemoryMatchGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.008, 0.010, 0.018)
    self:drawRect(0, 25, self.width, 1, 1, 0.28, 0.34, 0.48)
    self:drawText("MEMORY.EXE", 10, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText("MOVES " .. tostring(self.moves), 110, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText("MATCH " .. tostring(self.matches) .. "/8", 186, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), self.width - 92, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
end

function PZMemoryMatchGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.04, 0.04, 0.06)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.008, 0.010, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.28, 0.34, 0.48)
    self:drawText(title, boxX + 10, boxY + 19, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.78, 0.78, 0.58, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.62, 0.70, 0.88, 1, UIFont.Small)
end

function PZMemoryMatchGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZMemoryMatchGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.010, 0.012, 0.022)
    self:drawHud()
    local startX, startY, cardSize = self:getCardLayout()
    local boardW = cardSize * 4 + 24
    local boardH = cardSize * 4 + 24
    self:drawRect(startX - 10, startY - 10, boardW + 20, boardH + 20, 1, 0.030, 0.034, 0.046)
    self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, 1, 0.006, 0.008, 0.014)
    if self.matchFlash and self.matchFlash > 0 then
        self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, self.matchFlash / 100, 0.34, 0.72, 0.42)
    end
    if self.missFlash and self.missFlash > 0 then
        self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, self.missFlash / 110, 0.72, 0.42, 0.20)
    end
    for row = 0, 3 do
        for col = 0, 3 do
            local index = row * 4 + col + 1
            local x = startX + col * (cardSize + 8)
            local y = startY + row * (cardSize + 8)
            self:drawCard(x, y, cardSize, self.cards[index], index)
        end
    end
    local selectedX = math.max(1, math.min(4, tonumber(self.gamepadSelectionX) or 1))
    local selectedY = math.max(1, math.min(4, tonumber(self.gamepadSelectionY) or 1))
    ComputerModGameInput.drawGamepadSelection(self, startX + (selectedX - 1) * (cardSize + 8), startY + (selectedY - 1) * (cardSize + 8), cardSize, cardSize)
    if self.gameState == "WIN" then
        self:drawOverlay("BOARD CLEARED", "SCORE " .. tostring(self.score))
    end
    self:drawScanlines()
end

function PZMemoryMatchGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZMemoryMatchGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaMemoryMatch.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaStarPilot.lua
GameClasses['starpilot'] = (function()
require "ISUI/ISPanel"

local PZStarPilotGame = ISPanel:derive("PZStarPilotGame")

local function clampValue(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

function PZStarPilotGame:initialise()
    ISPanel.initialise(self)
    self.highscore = 0
    self:resetGame()
end

function PZStarPilotGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.animationTick = 0
    self.hitFlash = 0
    self.damageFlash = 0
    self.score = 0
    self.lives = 3
    self.level = 1
    self.fireCooldown = 0
    self.spawnTimer = 0
    self.collectTimer = 0
    self.player = {x = self.width * 0.5, y = self.height - 42, vx = 0, vy = 0}
    self.bullets = {}
    self.enemies = {}
    self.collectibles = {}
    self.particles = {}
    self.stars = {}
    for i = 1, 58 do
        self.stars[i] = {
            x = (i * 47 + ZombRand(30)) % math.max(1, self.width),
            y = (i * 29 + ZombRand(40)) % math.max(1, self.height),
            speed = 0.4 + (i % 5) * 0.18,
            size = (i % 7 == 0) and 2 or 1
        }
    end
end

function PZStarPilotGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZStarPilotGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZStarPilotGame:spawnEnemy()
    local w = 18 + ZombRand(18)
    local x = 12 + ZombRand(math.max(1, self.width - w - 24))
    local speed = 1.35 + self.level * 0.12 + ZombRand(50) / 100
    self.enemies[#self.enemies + 1] = {x = x, y = -24, w = w, h = 16 + ZombRand(12), speed = speed, phase = ZombRand(100)}
end

function PZStarPilotGame:spawnCollectible()
    local x = 18 + ZombRand(math.max(1, self.width - 36))
    self.collectibles[#self.collectibles + 1] = {x = x, y = -18, speed = 1.1 + ZombRand(40) / 100}
end

function PZStarPilotGame:fire()
    if self.fireCooldown > 0 or self.gameState ~= "PLAYING" then return end
    self.fireCooldown = 11
    self.bullets[#self.bullets + 1] = {x = self.player.x, y = self.player.y - 18}
    self:playSound("ComputerLaserShot")
end

function PZStarPilotGame:emitParticles(x, y, count, r, g, b)
    for i = 1, count do
        local life = 12 + ZombRand(18)
        self.particles[#self.particles + 1] = {
            x = x,
            y = y,
            vx = (ZombRand(1000) - 500) / 220,
            vy = (ZombRand(1000) - 500) / 220,
            life = life,
            maxLife = life,
            r = r,
            g = g,
            b = b
        }
    end
end

function PZStarPilotGame:updateParticles()
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.x = p.x + p.vx
        p.y = p.y + p.vy
        p.vx = p.vx * 0.94
        p.vy = p.vy * 0.94
        p.life = p.life - 1
        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end
end

function PZStarPilotGame:update()
    self.animationTick = (self.animationTick or 0) + 1
    self.hitFlash = math.max(0, (self.hitFlash or 0) - 1)
    self.damageFlash = math.max(0, (self.damageFlash or 0) - 1)
    self:updateParticles()
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    local accelerationX = 0
    local accelerationY = 0
    if ComputerModGameInput.isDown(self, "left") or ComputerModGameInput.isDown(self, "strafeLeft") then accelerationX = accelerationX - 1.15 end
    if ComputerModGameInput.isDown(self, "right") or ComputerModGameInput.isDown(self, "strafeRight") then accelerationX = accelerationX + 1.15 end
    if ComputerModGameInput.isDown(self, "up") or ComputerModGameInput.isDown(self, "forward") then accelerationY = accelerationY - 0.88 end
    if ComputerModGameInput.isDown(self, "down") or ComputerModGameInput.isDown(self, "backward") then accelerationY = accelerationY + 0.88 end
    self.player.vx = (self.player.vx + accelerationX) * 0.82
    self.player.vy = (self.player.vy + accelerationY) * 0.82
    self.player.x = clampValue(self.player.x + self.player.vx, 18, self.width - 18)
    self.player.y = clampValue(self.player.y + self.player.vy, 54, self.height - 26)
    if self.fireCooldown > 0 then self.fireCooldown = self.fireCooldown - 1 end
    if ComputerModGameInput.isDown(self, "action") then self:fire() end

    for i = 1, #self.stars do
        local star = self.stars[i]
        star.y = star.y + star.speed + self.level * 0.04
        if star.y > self.height then
            star.y = 0
            star.x = ZombRand(math.max(1, self.width))
        end
    end

    self.spawnTimer = self.spawnTimer + 1
    local spawnRate = math.max(18, 45 - self.level * 2)
    if self.spawnTimer >= spawnRate then
        self.spawnTimer = 0
        self:spawnEnemy()
    end

    self.collectTimer = self.collectTimer + 1
    if self.collectTimer >= 95 then
        self.collectTimer = 0
        self:spawnCollectible()
    end

    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet.y = bullet.y - 5.8
        if bullet.y < -8 then
            table.remove(self.bullets, i)
        end
    end

    for i = #self.collectibles, 1, -1 do
        local item = self.collectibles[i]
        item.y = item.y + item.speed
        if rectsOverlap(self.player.x - 11, self.player.y - 11, 22, 22, item.x - 6, item.y - 6, 12, 12) then
            self.score = self.score + 75
            self.hitFlash = 5
            self:emitParticles(item.x, item.y, 10, 0.34, 0.70, 0.95)
            self:playSound("ComputerBallHit")
            table.remove(self.collectibles, i)
        elseif item.y > self.height + 12 then
            table.remove(self.collectibles, i)
        end
    end

    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        enemy.y = enemy.y + enemy.speed
        enemy.x = enemy.x + math.sin((self.animationTick + enemy.phase) * 0.07) * 0.75
        if rectsOverlap(self.player.x - 12, self.player.y - 12, 24, 24, enemy.x, enemy.y, enemy.w, enemy.h) then
            self.lives = self.lives - 1
            self.damageFlash = 10
            self:emitParticles(self.player.x, self.player.y, 16, 0.90, 0.36, 0.20)
            table.remove(self.enemies, i)
            if self.lives <= 0 then
                self.gameState = "GAMEOVER"
                if self.score > self.highscore then self.highscore = self.score end
                self:playGameOverSound()
                return
            end
        else
            local destroyed = false
            for j = #self.bullets, 1, -1 do
                local bullet = self.bullets[j]
                if rectsOverlap(bullet.x - 2, bullet.y - 8, 4, 10, enemy.x, enemy.y, enemy.w, enemy.h) then
                    self.score = self.score + 45
                    self.hitFlash = 4
                    self:emitParticles(enemy.x + enemy.w * 0.5, enemy.y + enemy.h * 0.5, 12, 0.84, 0.42, 0.22)
                    self:playSound("ComputerBallHit")
                    table.remove(self.bullets, j)
                    table.remove(self.enemies, i)
                    destroyed = true
                    break
                end
            end
            if not destroyed and enemy.y > self.height + 18 then
                self.score = self.score + 5
                table.remove(self.enemies, i)
            end
        end
    end

    self.level = 1 + math.floor(self.score / 650)
end

function PZStarPilotGame:drawShip(x, y)
    self:drawRect(x + 1, y - 13, 10, 24, 0.24, 0, 0, 0)
    self:drawRect(x - 5, y - 18, 10, 20, 1, 0.42, 0.62, 0.80)
    self:drawRect(x - 12, y - 4, 24, 10, 1, 0.14, 0.28, 0.54)
    self:drawRect(x - 3, y - 22, 6, 6, 1, 0.76, 0.86, 0.90)
    self:drawRect(x - 8, y + 6, 4, 8, 1, 0.86, 0.44, 0.12)
    self:drawRect(x + 4, y + 6, 4, 8, 1, 0.86, 0.44, 0.12)
    if ComputerModGameInput.isDown(self, "up") or ComputerModGameInput.isDown(self, "forward") then
        self:drawRect(x - 6, y + 14, 3, 6, 0.80, 0.90, 0.62, 0.18)
        self:drawRect(x + 3, y + 14, 3, 6, 0.80, 0.90, 0.62, 0.18)
    end
end

function PZStarPilotGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.006, 0.008, 0.018)
    self:drawRect(0, 25, self.width, 1, 1, 0.26, 0.32, 0.46)
    self:drawText("PILOT.EXE", 10, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText("LIFE " .. tostring(self.lives), 98, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText("LVL " .. tostring(self.level), 160, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), self.width - 94, 7, 0.62, 0.70, 0.88, 1, UIFont.Small)
end

function PZStarPilotGame:drawEnemy(enemy)
    self:drawRect(enemy.x + 1, enemy.y + 2, enemy.w, enemy.h, 0.28, 0, 0, 0)
    self:drawRect(enemy.x, enemy.y, enemy.w, enemy.h, 1, 0.48, 0.12, 0.12)
    self:drawRect(enemy.x + 3, enemy.y + 3, enemy.w - 6, enemy.h - 6, 1, 0.72, 0.28, 0.18)
    self:drawRect(enemy.x + 4, enemy.y + 5, enemy.w - 8, 2, 0.45, 1, 0.72, 0.38)
    self:drawRect(enemy.x + enemy.w * 0.5 - 2, enemy.y + enemy.h - 2, 4, 4, 1, 0.92, 0.60, 0.24)
end

function PZStarPilotGame:drawParticles()
    for i = 1, #self.particles do
        local p = self.particles[i]
        local alpha = math.max(0, p.life / p.maxLife)
        self:drawRect(p.x, p.y, math.max(2, math.floor(alpha * 4)), math.max(2, math.floor(alpha * 4)), alpha, p.r, p.g, p.b)
    end
end

function PZStarPilotGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.04, 0.04, 0.06)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.008, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.26, 0.32, 0.46)
    self:drawText(title, boxX + 10, boxY + 19, 0.62, 0.70, 0.88, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.78, 0.78, 0.58, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.62, 0.70, 0.88, 1, UIFont.Small)
end

function PZStarPilotGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZStarPilotGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.008, 0.020)
    for i = 1, #self.stars do
        local star = self.stars[i]
        self:drawRect(star.x, star.y, star.size, star.size, 0.82, 0.60, 0.66, 0.82)
    end
    if self.hitFlash and self.hitFlash > 0 then
        self:drawRect(0, 26, self.width, self.height - 26, self.hitFlash / 100, 0.34, 0.58, 0.72)
    end
    if self.damageFlash and self.damageFlash > 0 then
        self:drawRect(0, 26, self.width, self.height - 26, self.damageFlash / 85, 0.86, 0.12, 0.08)
    end
    self:drawHud()
    for i = 1, #self.collectibles do
        local item = self.collectibles[i]
        self:drawRect(item.x - 6, item.y - 6, 12, 12, 1, 0.04, 0.34, 0.62)
        self:drawRect(item.x - 3, item.y - 3, 6, 6, 1, 0.52, 0.78, 0.90)
    end
    for i = 1, #self.bullets do
        local bullet = self.bullets[i]
        self:drawRect(bullet.x - 1, bullet.y - 8, 2, 10, 1, 0.72, 1, 0.82)
    end
    for i = 1, #self.enemies do
        self:drawEnemy(self.enemies[i])
    end
    self:drawParticles()
    self:drawShip(self.player.x, self.player.y)
    if self.gameState == "GAMEOVER" then
        self:drawOverlay("SHIP LOST", "BEST " .. tostring(math.max(self.highscore, self.score)))
    end
    self:drawScanlines()
end

function PZStarPilotGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZStarPilotGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaStarPilot.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaCaveRunner.lua
GameClasses['caverunner'] = (function()
require "ISUI/ISPanel"

local PZCaveRunnerGame = ISPanel:derive("PZCaveRunnerGame")

local function clampCaveValue(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function caveRectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

local function drawCaveRect(panel, x, y, w, h, a, r, g, b)
    if w <= 0 or h <= 0 then return end
    local x1 = clampCaveValue(x, 0, panel.width)
    local y1 = clampCaveValue(y, 0, panel.height)
    local x2 = clampCaveValue(x + w, 0, panel.width)
    local y2 = clampCaveValue(y + h, 0, panel.height)
    if x2 <= x1 or y2 <= y1 then return end
    panel:drawRect(x1, y1, x2 - x1, y2 - y1, a, r, g, b)
end

function PZCaveRunnerGame:initialise()
    ISPanel.initialise(self)
    self:resetGame()
end

function PZCaveRunnerGame:resetGame()
    self.gameState = "PLAYING"
    self.gameOverSoundPlayed = false
    self.animationTick = 0
    self.crystalFlash = 0
    self.crashFlash = 0
    self.score = 0
    self.bonusScore = 0
    self.distance = 0
    self.speed = 2.4
    self.ship = {x = 64, y = self.height * 0.5, vy = 0}
    self.segments = {}
    self.crystals = {}
    self.spawnCursor = 0
    self.gapCenter = self.height * 0.5
    self.gapSize = math.max(92, self.height * 0.36)
    for i = 1, 24 do
        self:addSegment((i - 1) * 24)
    end
end

function PZCaveRunnerGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZCaveRunnerGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZCaveRunnerGame:addSegment(x)
    self.gapCenter = self.gapCenter + ZombRand(-24, 25)
    self.gapCenter = clampCaveValue(self.gapCenter, 72, self.height - 62)
    self.gapSize = clampCaveValue(self.gapSize + ZombRand(-8, 7), 72, math.max(88, self.height * 0.36))
    local topH = math.max(22, self.gapCenter - self.gapSize * 0.5)
    local bottomY = math.min(self.height - 18, self.gapCenter + self.gapSize * 0.5)
    self.segments[#self.segments + 1] = {x = x, topH = topH, bottomY = bottomY}
    if ZombRand(100) < 28 then
        self.crystals[#self.crystals + 1] = {x = x + 10, y = self.gapCenter + ZombRand(-24, 25)}
    end
end

function PZCaveRunnerGame:update()
    self.animationTick = (self.animationTick or 0) + 1
    self.crystalFlash = math.max(0, (self.crystalFlash or 0) - 1)
    self.crashFlash = math.max(0, (self.crashFlash or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end

    local thrust = 0
    if ComputerModGameInput.isDown(self, "up") or ComputerModGameInput.isDown(self, "forward") then thrust = thrust - 0.72 end
    if ComputerModGameInput.isDown(self, "down") or ComputerModGameInput.isDown(self, "backward") then thrust = thrust + 0.72 end
    self.ship.vy = (self.ship.vy + thrust + 0.055) * 0.9
    self.ship.y = self.ship.y + self.ship.vy
    self.speed = math.min(5.6, 2.4 + self.distance / 1600)
    self.distance = self.distance + self.speed
    self.score = math.floor(self.distance / 8) + (self.bonusScore or 0)

    local maxX = 0
    for i = #self.segments, 1, -1 do
        local seg = self.segments[i]
        seg.x = seg.x - self.speed
        if seg.x > maxX then maxX = seg.x end
        if seg.x < -28 then
            table.remove(self.segments, i)
        end
    end
    while maxX < self.width + 36 do
        maxX = maxX + 24
        self:addSegment(maxX)
    end

    for i = #self.crystals, 1, -1 do
        local crystal = self.crystals[i]
        crystal.x = crystal.x - self.speed
        if caveRectsOverlap(self.ship.x - 10, self.ship.y - 8, 20, 16, crystal.x - 5, crystal.y - 5, 10, 10) then
            self.bonusScore = (self.bonusScore or 0) + 120
            self.score = self.score + 120
            self.crystalFlash = 7
            self:playSound("ComputerBallHit")
            table.remove(self.crystals, i)
        elseif crystal.x < -12 then
            table.remove(self.crystals, i)
        end
    end

    if self.ship.y < 30 or self.ship.y > self.height - 18 then
        self.gameState = "GAMEOVER"
        self.crashFlash = 16
        self:playGameOverSound()
        return
    end
    for i = 1, #self.segments do
        local seg = self.segments[i]
        if seg.x < self.ship.x + 10 and seg.x + 24 > self.ship.x - 10 then
            if self.ship.y - 8 < seg.topH or self.ship.y + 8 > seg.bottomY then
                self.gameState = "GAMEOVER"
                self.crashFlash = 16
                self:playGameOverSound()
                return
            end
        end
    end
end

function PZCaveRunnerGame:drawShip()
    local x = self.ship.x
    local y = self.ship.y
    self:drawRect(x - 9, y - 6, 18, 12, 1, 0.16, 0.52, 0.58)
    self:drawRect(x + 1, y - 10, 10, 20, 1, 0.42, 0.74, 0.78)
    self:drawRect(x - 15, y - 3, 7, 6, 1, 0.86, 0.46, 0.12)
    self:drawRect(x + 10, y - 2, 5, 4, 1, 0.72, 0.86, 0.86)
    self:drawRect(x - 17, y - 1, 4, 2, 0.65, 0.90, 0.62, 0.16)
end

function PZCaveRunnerGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.006, 0.016, 0.014)
    self:drawRect(0, 25, self.width, 1, 1, 0.24, 0.42, 0.34)
    self:drawText("CAVE.EXE", 10, 7, 0.62, 0.82, 0.66, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), 92, 7, 0.62, 0.82, 0.66, 1, UIFont.Small)
    self:drawText("SPD " .. tostring(math.floor(self.speed * 10)), self.width - 64, 7, 0.62, 0.82, 0.66, 1, UIFont.Small)
end

function PZCaveRunnerGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.04, 0.07, 0.05)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.016, 0.014)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.24, 0.42, 0.34)
    self:drawText(title, boxX + 10, boxY + 19, 0.62, 0.82, 0.66, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.78, 0.78, 0.56, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.62, 0.82, 0.66, 1, UIFont.Small)
end

function PZCaveRunnerGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZCaveRunnerGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.018, 0.014)
    self:drawHud()
    if self.crystalFlash and self.crystalFlash > 0 then
        self:drawRect(0, 26, self.width, self.height - 26, self.crystalFlash / 100, 0.32, 0.72, 0.64)
    end
    if self.crashFlash and self.crashFlash > 0 then
        self:drawRect(0, 26, self.width, self.height - 26, self.crashFlash / 90, 0.82, 0.12, 0.08)
    end
    for i = 1, #self.segments do
        local seg = self.segments[i]
        local shade = 0.12 + (i % 4) * 0.02
        drawCaveRect(self, seg.x, 26, 25, seg.topH - 26, 1, 0.08, shade + 0.12, 0.12)
        drawCaveRect(self, seg.x, seg.bottomY, 25, self.height - seg.bottomY, 1, 0.08, shade + 0.12, 0.12)
        drawCaveRect(self, seg.x, seg.topH - 3, 25, 3, 1, 0.24, 0.54, 0.36)
        drawCaveRect(self, seg.x, seg.bottomY, 25, 3, 1, 0.24, 0.54, 0.36)
        if i % 3 == 0 then
            drawCaveRect(self, seg.x + 5, 30, 3, math.max(0, seg.topH - 40), 0.14, 0.44, 0.62, 0.48)
            drawCaveRect(self, seg.x + 14, seg.bottomY + 8, 3, math.max(0, self.height - seg.bottomY - 18), 0.12, 0.44, 0.62, 0.48)
        end
    end
    for i = 1, #self.crystals do
        local crystal = self.crystals[i]
        local pulse = math.abs(math.sin((self.animationTick + i * 8) * 0.1)) * 0.24
        drawCaveRect(self, crystal.x - 5, crystal.y - 5, 10, 10, 1, 0.28, 0.7 + pulse, 1)
        drawCaveRect(self, crystal.x - 2, crystal.y - 8, 4, 16, 0.7, 0.8, 1, 1)
    end
    self:drawShip()
    if self.gameState == "GAMEOVER" then
        self:drawOverlay("RUN ENDED", "SCORE " .. tostring(self.score))
    end
    self:drawScanlines()
end

function PZCaveRunnerGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZCaveRunnerGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaCaveRunner.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaLightsOut.lua
GameClasses['lightsout'] = (function()
require "ISUI/ISPanel"

local PZLightsOutGame = ISPanel:derive("PZLightsOutGame")

local function drawLightsBorder(panel, x, y, w, h, a, r, g, b)
    panel:drawRect(x, y, w, 1, a, r, g, b)
    panel:drawRect(x, y, 1, h, a, r, g, b)
    panel:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    panel:drawRect(x, y + h - 1, w, 1, a, r, g, b)
end

function PZLightsOutGame:initialise()
    ISPanel.initialise(self)
    self.bestMoves = nil
    self:resetGame()
end

function PZLightsOutGame:resetGame()
    self.gameState = "PLAYING"
    self.winSoundPlayed = false
    self.tick = 0
    self.flash = 0
    self.moves = 0
    self.board = {}
    for y = 1, 5 do
        self.board[y] = {}
        for x = 1, 5 do
            self.board[y][x] = false
        end
    end
    local shuffles = 8 + ZombRand(8)
    for i = 1, shuffles do
        self:toggleCell(ZombRand(5) + 1, ZombRand(5) + 1, false)
    end
    if self:isSolved() then
        self:toggleCell(3, 3, false)
    end
end

function PZLightsOutGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZLightsOutGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZLightsOutGame:isSolved()
    for y = 1, 5 do
        for x = 1, 5 do
            if self.board[y][x] then return false end
        end
    end
    return true
end

function PZLightsOutGame:toggleOne(x, y)
    if not self.board[y] or self.board[y][x] == nil then return end
    self.board[y][x] = not self.board[y][x]
end

function PZLightsOutGame:toggleCell(x, y, countMove)
    self:toggleOne(x, y)
    self:toggleOne(x - 1, y)
    self:toggleOne(x + 1, y)
    self:toggleOne(x, y - 1)
    self:toggleOne(x, y + 1)
    if countMove then
        self.moves = self.moves + 1
        self.flash = 6
        self:playSound("ComputerBallHit")
        if self:isSolved() then
            self.gameState = "WIN"
            if not self.bestMoves or self.moves < self.bestMoves then
                self.bestMoves = self.moves
            end
            self:playWinSound()
        end
    end
end

function PZLightsOutGame:getBoardLayout()
    local usableW = math.max(1, self.width - 44)
    local usableH = math.max(1, self.height - 78)
    local gap = math.max(2, math.floor(math.min(usableW, usableH) * 0.012))
    local cell = math.floor((math.min(usableW, usableH) - gap * 4) / 5)
    cell = math.max(14, cell)
    local boardW = cell * 5 + gap * 4
    local boardH = boardW
    local x = math.floor((self.width - boardW) / 2)
    local y = 42 + math.floor((usableH - boardH) / 2)
    return x, y, cell, gap, boardW, boardH
end

function PZLightsOutGame:getCellAt(mx, my)
    local startX, startY, cell, gap = self:getBoardLayout()
    for y = 1, 5 do
        for x = 1, 5 do
            local cx = startX + (x - 1) * (cell + gap)
            local cy = startY + (y - 1) * (cell + gap)
            if mx >= cx and mx <= cx + cell and my >= cy and my <= cy + cell then
                return x, y
            end
        end
    end
    return nil, nil
end

function PZLightsOutGame:onMouseDown(x, y)
    if self.gameState ~= "PLAYING" then
        self:resetGame()
        return true
    end
    local cx, cy = self:getCellAt(x, y)
    if cx then
        self:toggleCell(cx, cy, true)
    end
    return true
end

function PZLightsOutGame:update()
    self.tick = (self.tick or 0) + 1
    self.flash = math.max(0, (self.flash or 0) - 1)
    local selectedX, selectedY, activated = ComputerModGameInput.updateGridSelection(self, 5, 5)
    if self.gameState ~= "PLAYING" and ComputerModGameInput.isDown(self, "action") then
        self:resetGame()
    elseif self.gameState == "PLAYING" and activated then
        self:toggleCell(selectedX, selectedY, true)
    end
end

function PZLightsOutGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.008, 0.014, 0.018)
    self:drawRect(0, 25, self.width, 1, 1, 0.24, 0.40, 0.38)
    self:drawText("LIGHTS.EXE", 10, 7, 0.58, 0.78, 0.72, 1, UIFont.Small)
    self:drawText("MOVES " .. tostring(self.moves), 112, 7, 0.58, 0.78, 0.72, 1, UIFont.Small)
    local best = self.bestMoves and tostring(self.bestMoves) or "--"
    self:drawText("BEST " .. best, self.width - 80, 7, 0.58, 0.78, 0.72, 1, UIFont.Small)
end

function PZLightsOutGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 218)
    local boxH = 74
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.03, 0.05, 0.05)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.012, 0.014)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.24, 0.40, 0.38)
    self:drawText(title, boxX + 10, boxY + 18, 0.62, 0.84, 0.72, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 40, 0.82, 0.74, 0.48, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": NEW BOARD", boxX + 10, boxY + 57, 0.62, 0.84, 0.72, 1, UIFont.Small)
end

function PZLightsOutGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZLightsOutGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.012, 0.016)
    self:drawHud()
    local startX, startY, cell, gap, boardW, boardH = self:getBoardLayout()
    self:drawRect(startX - 10, startY - 10, boardW + 20, boardH + 20, 1, 0.022, 0.028, 0.032)
    self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, 1, 0.004, 0.008, 0.010)
    drawLightsBorder(self, startX - 6, startY - 6, boardW + 12, boardH + 12, 1, 0.22, 0.38, 0.36)
    if self.flash and self.flash > 0 then
        self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, self.flash / 100, 0.66, 0.78, 0.46)
    end
    for y = 1, 5 do
        for x = 1, 5 do
            local cx = startX + (x - 1) * (cell + gap)
            local cy = startY + (y - 1) * (cell + gap)
            local lit = self.board[y][x]
            if lit then
                local pulse = math.abs(math.sin((self.tick + x * 3 + y * 7) * 0.08)) * 0.10
                self:drawRect(cx + 1, cy + 2, cell, cell, 0.25, 0, 0, 0)
                self:drawRect(cx, cy, cell, cell, 1, 0.70 + pulse, 0.54 + pulse, 0.18)
                drawLightsBorder(self, cx, cy, cell, cell, 1, 0.94, 0.82, 0.36)
                self:drawRect(cx + 5, cy + 5, math.max(1, cell - 10), 2, 0.52, 1, 0.94, 0.52)
            else
                self:drawRect(cx + 1, cy + 2, cell, cell, 0.24, 0, 0, 0)
                self:drawRect(cx, cy, cell, cell, 1, 0.018, 0.034, 0.038)
                drawLightsBorder(self, cx, cy, cell, cell, 1, 0.10, 0.20, 0.20)
                self:drawRect(cx + 4, cy + cell - 6, math.max(1, cell - 8), 1, 0.36, 0.22, 0.36, 0.34)
            end
        end
    end
    local selectedX = math.max(1, math.min(5, tonumber(self.gamepadSelectionX) or 1))
    local selectedY = math.max(1, math.min(5, tonumber(self.gamepadSelectionY) or 1))
    ComputerModGameInput.drawGamepadSelection(self, startX + (selectedX - 1) * (cell + gap), startY + (selectedY - 1) * (cell + gap), cell, cell)
    if self.gameState == "WIN" then
        self:drawOverlay("PANEL CLEARED", "MOVES " .. tostring(self.moves))
    end
    self:drawScanlines()
end

function PZLightsOutGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZLightsOutGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaLightsOut.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaSignalMatch.lua
GameClasses['signalmatch'] = (function()
require "ISUI/ISPanel"

local PZSignalMatchGame = ISPanel:derive("PZSignalMatchGame")

local signalPads = {
    {label = "A", r = 0.58, g = 0.25, b = 0.20},
    {label = "B", r = 0.18, g = 0.48, b = 0.38},
    {label = "C", r = 0.22, g = 0.34, b = 0.62},
    {label = "D", r = 0.66, g = 0.54, b = 0.18}
}

local function drawSignalBorder(panel, x, y, w, h, a, r, g, b)
    panel:drawRect(x, y, w, 1, a, r, g, b)
    panel:drawRect(x, y, 1, h, a, r, g, b)
    panel:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    panel:drawRect(x, y + h - 1, w, 1, a, r, g, b)
end

function PZSignalMatchGame:initialise()
    ISPanel.initialise(self)
    self.highRound = 0
    self:resetGame()
end

function PZSignalMatchGame:resetGame()
    self.gameState = "SHOWING"
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.tick = 0
    self.score = 0
    self.sequence = {}
    self.inputIndex = 1
    self.showIndex = 1
    self.showTimer = 34
    self.clearTimer = 0
    self.flashTimer = 0
    self.litPad = nil
    self.maxRound = 9
    self:addSignal()
end

function PZSignalMatchGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZSignalMatchGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZSignalMatchGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZSignalMatchGame:addSignal()
    self.sequence[#self.sequence + 1] = ZombRand(4) + 1
    if #self.sequence > self.highRound then
        self.highRound = #self.sequence
    end
end

function PZSignalMatchGame:getPadLayout()
    local usableW = math.max(1, self.width - 64)
    local usableH = math.max(1, self.height - 94)
    local gap = math.max(6, math.floor(math.min(usableW, usableH) * 0.03))
    local pad = math.floor((math.min(usableW, usableH) - gap) / 2)
    pad = math.max(24, pad)
    local boardW = pad * 2 + gap
    local boardH = boardW
    local x = math.floor((self.width - boardW) / 2)
    local y = 44 + math.floor((usableH - boardH) / 2)
    return x, y, pad, gap, boardW, boardH
end

function PZSignalMatchGame:getPadAt(mx, my)
    local startX, startY, pad, gap = self:getPadLayout()
    for i = 1, 4 do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x = startX + col * (pad + gap)
        local y = startY + row * (pad + gap)
        if mx >= x and mx <= x + pad and my >= y and my <= y + pad then
            return i
        end
    end
    return nil
end

function PZSignalMatchGame:fail()
    self.gameState = "GAMEOVER"
    self.flashTimer = 16
    self.litPad = nil
    self:playGameOverSound()
end

function PZSignalMatchGame:acceptPad(pad)
    if self.gameState ~= "INPUT" then return end
    self.litPad = pad
    self.flashTimer = 8
    self:playSound("ComputerBallHit")
    if self.sequence[self.inputIndex] ~= pad then
        self:fail()
        return
    end
    self.score = self.score + 20 + #self.sequence * 5
    self.inputIndex = self.inputIndex + 1
    if self.inputIndex > #self.sequence then
        if #self.sequence >= self.maxRound then
            self.gameState = "WIN"
            self.score = self.score + 400
            self:playWinSound()
        else
            self.gameState = "ROUND_CLEAR"
            self.clearTimer = 30
        end
    end
end

function PZSignalMatchGame:onMouseDown(x, y)
    if self.gameState == "GAMEOVER" or self.gameState == "WIN" then
        self:resetGame()
        return true
    end
    local pad = self:getPadAt(x, y)
    if pad then
        self:acceptPad(pad)
    end
    return true
end

function PZSignalMatchGame:update()
    self.tick = (self.tick or 0) + 1
    self.flashTimer = math.max(0, (self.flashTimer or 0) - 1)
    local selectedX, selectedY, activated = ComputerModGameInput.updateGridSelection(self, 2, 2)
    if self.flashTimer <= 0 and self.gameState == "INPUT" then
        self.litPad = nil
    end
    if self.gameState == "GAMEOVER" or self.gameState == "WIN" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end
    if self.gameState == "INPUT" and activated then
        self:acceptPad((selectedY - 1) * 2 + selectedX)
    end
    if self.gameState == "SHOWING" then
        self.showTimer = self.showTimer - 1
        if self.showTimer > 13 then
            self.litPad = self.sequence[self.showIndex]
        else
            self.litPad = nil
        end
        if self.showTimer <= 0 then
            self.showIndex = self.showIndex + 1
            if self.showIndex > #self.sequence then
                self.gameState = "INPUT"
                self.inputIndex = 1
                self.litPad = nil
            else
                self.showTimer = 30
            end
        end
    elseif self.gameState == "ROUND_CLEAR" then
        self.clearTimer = self.clearTimer - 1
        self.litPad = nil
        if self.clearTimer <= 0 then
            self:addSignal()
            self.showIndex = 1
            self.showTimer = 34
            self.inputIndex = 1
            self.gameState = "SHOWING"
        end
    end
end

function PZSignalMatchGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.010, 0.012, 0.020)
    self:drawRect(0, 25, self.width, 1, 1, 0.30, 0.32, 0.46)
    self:drawText("SIGNAL.EXE", 10, 7, 0.62, 0.68, 0.86, 1, UIFont.Small)
    self:drawText("ROUND " .. tostring(#self.sequence), 112, 7, 0.62, 0.68, 0.86, 1, UIFont.Small)
    self:drawText("SCORE " .. tostring(self.score), self.width - 92, 7, 0.62, 0.68, 0.86, 1, UIFont.Small)
end

function PZSignalMatchGame:drawStatusLine()
    local text = "WATCH"
    if self.gameState == "INPUT" then
        text = "REPEAT " .. tostring(self.inputIndex) .. "/" .. tostring(#self.sequence)
    elseif self.gameState == "ROUND_CLEAR" then
        text = "GOOD"
    elseif self.gameState == "GAMEOVER" then
        text = "BAD SIGNAL"
    elseif self.gameState == "WIN" then
        text = "LINK OK"
    end
    self:drawText(text, 10, self.height - 18, 0.62, 0.68, 0.86, 1, UIFont.Small)
end

function PZSignalMatchGame:drawPad(index, x, y, size)
    local pad = signalPads[index]
    local lit = self.litPad == index
    local pulse = lit and 0.26 or math.abs(math.sin((self.tick + index * 9) * 0.05)) * 0.04
    self:drawRect(x + 2, y + 3, size, size, 0.28, 0, 0, 0)
    self:drawRect(x, y, size, size, 1, pad.r + pulse, pad.g + pulse, pad.b + pulse)
    drawSignalBorder(self, x, y, size, size, 1, lit and 0.92 or 0.18, lit and 0.90 or 0.18, lit and 0.70 or 0.20)
    self:drawRect(x + 6, y + 6, math.max(1, size - 12), 2, lit and 0.65 or 0.22, 1, 1, 0.82)
    self:drawText(pad.label, x + math.floor(size * 0.5) - 4, y + math.floor(size * 0.5) - 8, 0.02, 0.02, 0.02, 1, UIFont.Medium)
end

function PZSignalMatchGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.04, 0.04, 0.07)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.008, 0.010, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.30, 0.32, 0.46)
    self:drawText(title, boxX + 10, boxY + 19, 0.62, 0.68, 0.86, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.80, 0.76, 0.52, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": RESTART", boxX + 10, boxY + 58, 0.62, 0.68, 0.86, 1, UIFont.Small)
end

function PZSignalMatchGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZSignalMatchGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.008, 0.010, 0.018)
    self:drawHud()
    local startX, startY, pad, gap, boardW, boardH = self:getPadLayout()
    self:drawRect(startX - 10, startY - 10, boardW + 20, boardH + 20, 1, 0.030, 0.032, 0.046)
    self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, 1, 0.004, 0.006, 0.014)
    drawSignalBorder(self, startX - 6, startY - 6, boardW + 12, boardH + 12, 1, 0.24, 0.28, 0.42)
    for i = 1, 4 do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        self:drawPad(i, startX + col * (pad + gap), startY + row * (pad + gap), pad)
    end
    local selectedX = math.max(1, math.min(2, tonumber(self.gamepadSelectionX) or 1))
    local selectedY = math.max(1, math.min(2, tonumber(self.gamepadSelectionY) or 1))
    ComputerModGameInput.drawGamepadSelection(self, startX + (selectedX - 1) * (pad + gap), startY + (selectedY - 1) * (pad + gap), pad, pad)
    if self.gameState == "GAMEOVER" then
        self:drawOverlay("SEQUENCE LOST", "ROUND " .. tostring(#self.sequence))
    elseif self.gameState == "WIN" then
        self:drawOverlay("SIGNAL LOCKED", "SCORE " .. tostring(self.score))
    end
    self:drawStatusLine()
    self:drawScanlines()
end

function PZSignalMatchGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZSignalMatchGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaSignalMatch.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaBoxPush.lua
GameClasses['boxpush'] = (function()
require "ISUI/ISPanel"

local PZBoxPushGame = ISPanel:derive("PZBoxPushGame")

local boxPushMaps = {
    {
        "##########",
        "#........#",
        "#..B.G...#",
        "#..P.....#",
        "#..B.G...#",
        "#........#",
        "##########"
    },
    {
        "###########",
        "#.........#",
        "#..G.B....#",
        "#..##.##..#",
        "#....P....#",
        "#..##.##..#",
        "#....B.G..#",
        "#.........#",
        "###########"
    },
    {
        "###########",
        "#.........#",
        "#..G.B....#",
        "#.........#",
        "#....P....#",
        "#.........#",
        "#....B.G..#",
        "#.........#",
        "###########"
    }
}

local function drawBoxBorder(panel, x, y, w, h, a, r, g, b)
    panel:drawRect(x, y, w, 1, a, r, g, b)
    panel:drawRect(x, y, 1, h, a, r, g, b)
    panel:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    panel:drawRect(x, y + h - 1, w, 1, a, r, g, b)
end

function PZBoxPushGame:initialise()
    ISPanel.initialise(self)
    self.nextMapIndex = 1
    self:resetGame()
end

function PZBoxPushGame:resetGame()
    self.gameState = "PLAYING"
    self.winSoundPlayed = false
    self.tick = 0
    self.steps = 0
    self.pushes = 0
    self.moveCooldown = 0
    self.level = self.nextMapIndex or 1
    self.nextMapIndex = (self.level % #boxPushMaps) + 1
    self.grid = {}
    self.boxes = {}
    self.goals = {}
    local source = boxPushMaps[self.level]
    self.rows = #source
    self.cols = string.len(source[1])
    for y = 1, #source do
        self.grid[y] = {}
        for x = 1, string.len(source[y]) do
            local ch = string.sub(source[y], x, x)
            if ch == "P" then
                self.player = {x = x, y = y}
                self.grid[y][x] = "."
            elseif ch == "B" then
                self.boxes[#self.boxes + 1] = {x = x, y = y}
                self.grid[y][x] = "."
            elseif ch == "G" then
                self.goals[#self.goals + 1] = {x = x, y = y}
                self.grid[y][x] = "."
            else
                self.grid[y][x] = ch
            end
        end
    end
end

function PZBoxPushGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZBoxPushGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZBoxPushGame:isWall(x, y)
    return not self.grid[y] or self.grid[y][x] == "#"
end

function PZBoxPushGame:getBoxAt(x, y)
    for i = 1, #self.boxes do
        if self.boxes[i].x == x and self.boxes[i].y == y then
            return i
        end
    end
    return nil
end

function PZBoxPushGame:isGoal(x, y)
    for i = 1, #self.goals do
        if self.goals[i].x == x and self.goals[i].y == y then
            return true
        end
    end
    return false
end

function PZBoxPushGame:isBoxOnGoal(box)
    return box and self:isGoal(box.x, box.y)
end

function PZBoxPushGame:isSolved()
    for i = 1, #self.boxes do
        if not self:isBoxOnGoal(self.boxes[i]) then
            return false
        end
    end
    return true
end

function PZBoxPushGame:tryMove(dx, dy)
    if self.gameState ~= "PLAYING" then return end
    local nx = self.player.x + dx
    local ny = self.player.y + dy
    if self:isWall(nx, ny) then return end
    local boxIndex = self:getBoxAt(nx, ny)
    if boxIndex then
        local bx = nx + dx
        local by = ny + dy
        if self:isWall(bx, by) or self:getBoxAt(bx, by) then return end
        self.boxes[boxIndex].x = bx
        self.boxes[boxIndex].y = by
        self.pushes = self.pushes + 1
        self:playSound("ComputerBallHit")
    end
    self.player.x = nx
    self.player.y = ny
    self.steps = self.steps + 1
    if self:isSolved() then
        self.gameState = "WIN"
        self:playWinSound()
    end
end

function PZBoxPushGame:getBoardLayout()
    local usableW = math.max(1, self.width - 42)
    local usableH = math.max(1, self.height - 76)
    local cell = math.floor(math.min(usableW / self.cols, usableH / self.rows))
    cell = math.max(10, cell)
    local boardW = cell * self.cols
    local boardH = cell * self.rows
    local x = math.floor((self.width - boardW) / 2)
    local y = 40 + math.floor((usableH - boardH) / 2)
    return x, y, cell, boardW, boardH
end

function PZBoxPushGame:update()
    self.tick = (self.tick or 0) + 1
    self.moveCooldown = math.max(0, (self.moveCooldown or 0) - 1)
    if self.gameState ~= "PLAYING" then
        if ComputerModGameInput.isDown(self, "action") then
            self:resetGame()
        end
        return
    end
    if self.moveCooldown > 0 then return end
    local dx = 0
    local dy = 0
    if ComputerModGameInput.isDown(self, "left") or ComputerModGameInput.isDown(self, "strafeLeft") then
        dx = -1
    elseif ComputerModGameInput.isDown(self, "right") or ComputerModGameInput.isDown(self, "strafeRight") then
        dx = 1
    elseif ComputerModGameInput.isDown(self, "up") or ComputerModGameInput.isDown(self, "forward") then
        dy = -1
    elseif ComputerModGameInput.isDown(self, "down") or ComputerModGameInput.isDown(self, "backward") then
        dy = 1
    end
    if dx ~= 0 or dy ~= 0 then
        self:tryMove(dx, dy)
        self.moveCooldown = 10
    end
end

function PZBoxPushGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.012, 0.012, 0.014)
    self:drawRect(0, 25, self.width, 1, 1, 0.38, 0.34, 0.24)
    self:drawText("BOXPUSH.EXE", 10, 7, 0.84, 0.78, 0.58, 1, UIFont.Small)
    self:drawText("LVL " .. tostring(self.level), 116, 7, 0.84, 0.78, 0.58, 1, UIFont.Small)
    self:drawText("STEP " .. tostring(self.steps), 174, 7, 0.84, 0.78, 0.58, 1, UIFont.Small)
    self:drawText("PUSH " .. tostring(self.pushes), self.width - 82, 7, 0.84, 0.78, 0.58, 1, UIFont.Small)
end

function PZBoxPushGame:drawCell(x, y, cell, gx, gy)
    local px = x + (gx - 1) * cell
    local py = y + (gy - 1) * cell
    local ch = self.grid[gy] and self.grid[gy][gx] or "#"
    if ch == "#" then
        self:drawRect(px, py, cell, cell, 1, 0.16, 0.16, 0.15)
        drawBoxBorder(self, px, py, cell, cell, 1, 0.36, 0.34, 0.26)
        if cell > 15 then
            self:drawRect(px + 3, py + 3, math.max(1, cell - 6), 1, 0.25, 0.56, 0.52, 0.36)
        end
    else
        self:drawRect(px, py, cell, cell, 1, 0.026, 0.024, 0.022)
        drawBoxBorder(self, px, py, cell, cell, 0.45, 0.10, 0.09, 0.08)
        if self:isGoal(gx, gy) then
            local inset = math.max(4, math.floor(cell * 0.24))
            self:drawRect(px + inset, py + inset, cell - inset * 2, cell - inset * 2, 1, 0.16, 0.42, 0.24)
            drawBoxBorder(self, px + inset, py + inset, cell - inset * 2, cell - inset * 2, 1, 0.42, 0.72, 0.42)
        end
    end
end

function PZBoxPushGame:drawBox(x, y, cell, onGoal)
    local inset = math.max(2, math.floor(cell * 0.12))
    if onGoal then
        self:drawRect(x + inset, y + inset, cell - inset * 2, cell - inset * 2, 1, 0.22, 0.52, 0.28)
        drawBoxBorder(self, x + inset, y + inset, cell - inset * 2, cell - inset * 2, 1, 0.60, 0.86, 0.52)
    else
        self:drawRect(x + inset, y + inset, cell - inset * 2, cell - inset * 2, 1, 0.58, 0.42, 0.20)
        drawBoxBorder(self, x + inset, y + inset, cell - inset * 2, cell - inset * 2, 1, 0.88, 0.68, 0.32)
    end
    if cell > 16 then
        self:drawRect(x + inset + 3, y + inset + 3, math.max(1, cell - inset * 2 - 6), 2, 0.36, 0.98, 0.86, 0.55)
    end
end

function PZBoxPushGame:drawPlayer(x, y, cell)
    local inset = math.max(3, math.floor(cell * 0.18))
    self:drawRect(x + inset, y + inset, cell - inset * 2, cell - inset * 2, 1, 0.18, 0.54, 0.62)
    drawBoxBorder(self, x + inset, y + inset, cell - inset * 2, cell - inset * 2, 1, 0.62, 0.88, 0.92)
    if cell > 14 then
        self:drawRect(x + math.floor(cell * 0.5) - 2, y + inset + 3, 4, 4, 1, 0.90, 0.95, 0.82)
    end
end

function PZBoxPushGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.05, 0.04, 0.03)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.012, 0.012, 0.014)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.38, 0.34, 0.24)
    self:drawText(title, boxX + 10, boxY + 19, 0.84, 0.78, 0.58, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.64, 0.86, 0.62, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": NEXT MAP", boxX + 10, boxY + 58, 0.84, 0.78, 0.58, 1, UIFont.Small)
end

function PZBoxPushGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZBoxPushGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.010, 0.010, 0.012)
    self:drawHud()
    local startX, startY, cell, boardW, boardH = self:getBoardLayout()
    self:drawRect(startX - 8, startY - 8, boardW + 16, boardH + 16, 1, 0.04, 0.036, 0.030)
    self:drawRect(startX - 4, startY - 4, boardW + 8, boardH + 8, 1, 0.006, 0.006, 0.008)
    drawBoxBorder(self, startX - 4, startY - 4, boardW + 8, boardH + 8, 1, 0.38, 0.34, 0.24)
    for gy = 1, self.rows do
        for gx = 1, self.cols do
            self:drawCell(startX, startY, cell, gx, gy)
        end
    end
    for i = 1, #self.boxes do
        local box = self.boxes[i]
        self:drawBox(startX + (box.x - 1) * cell, startY + (box.y - 1) * cell, cell, self:isBoxOnGoal(box))
    end
    if self.player then
        self:drawPlayer(startX + (self.player.x - 1) * cell, startY + (self.player.y - 1) * cell, cell)
    end
    if self.gameState == "WIN" then
        self:drawOverlay("WAREHOUSE CLEAR", "PUSHES " .. tostring(self.pushes))
    end
    self:drawScanlines()
end

function PZBoxPushGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZBoxPushGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaBoxPush.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaTileSlide.lua
GameClasses['tileslide'] = (function()
require "ISUI/ISPanel"

local PZTileSlideGame = ISPanel:derive("PZTileSlideGame")

local function drawTileBorder(panel, x, y, w, h, a, r, g, b)
    panel:drawRect(x, y, w, 1, a, r, g, b)
    panel:drawRect(x, y, 1, h, a, r, g, b)
    panel:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    panel:drawRect(x, y + h - 1, w, 1, a, r, g, b)
end

function PZTileSlideGame:initialise()
    ISPanel.initialise(self)
    self.bestMoves = nil
    self:resetGame()
end

function PZTileSlideGame:resetGame()
    self.gameState = "PLAYING"
    self.winSoundPlayed = false
    self.tick = 0
    self.moves = 0
    self.flash = 0
    self.tiles = {}
    local n = 1
    for y = 1, 4 do
        self.tiles[y] = {}
        for x = 1, 4 do
            if x == 4 and y == 4 then
                self.tiles[y][x] = 0
                self.blankX = x
                self.blankY = y
            else
                self.tiles[y][x] = n
                n = n + 1
            end
        end
    end
    local lastDx = 0
    local lastDy = 0
    for i = 1, 120 do
        local options = {}
        local dirs = {{x = 1, y = 0}, {x = -1, y = 0}, {x = 0, y = 1}, {x = 0, y = -1}}
        for d = 1, #dirs do
            local dir = dirs[d]
            local tx = self.blankX + dir.x
            local ty = self.blankY + dir.y
            if tx >= 1 and tx <= 4 and ty >= 1 and ty <= 4 and not (dir.x == -lastDx and dir.y == -lastDy) then
                options[#options + 1] = dir
            end
        end
        local pick = options[ZombRand(#options) + 1]
        self:moveTileAt(self.blankX + pick.x, self.blankY + pick.y, false)
        lastDx = pick.x
        lastDy = pick.y
    end
    if self:isSolved() then
        self:moveTileAt(3, 4, false)
    end
    self.moves = 0
end

function PZTileSlideGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZTileSlideGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZTileSlideGame:isSolved()
    local n = 1
    for y = 1, 4 do
        for x = 1, 4 do
            if x == 4 and y == 4 then
                if self.tiles[y][x] ~= 0 then return false end
            else
                if self.tiles[y][x] ~= n then return false end
                n = n + 1
            end
        end
    end
    return true
end

function PZTileSlideGame:getBoardLayout()
    local usableW = math.max(1, self.width - 46)
    local usableH = math.max(1, self.height - 80)
    local gap = math.max(2, math.floor(math.min(usableW, usableH) * 0.012))
    local cell = math.floor((math.min(usableW, usableH) - gap * 3) / 4)
    cell = math.max(18, cell)
    local boardW = cell * 4 + gap * 3
    local boardH = boardW
    local x = math.floor((self.width - boardW) / 2)
    local y = 42 + math.floor((usableH - boardH) / 2)
    return x, y, cell, gap, boardW, boardH
end

function PZTileSlideGame:getCellAt(mx, my)
    local startX, startY, cell, gap = self:getBoardLayout()
    for y = 1, 4 do
        for x = 1, 4 do
            local cx = startX + (x - 1) * (cell + gap)
            local cy = startY + (y - 1) * (cell + gap)
            if mx >= cx and mx <= cx + cell and my >= cy and my <= cy + cell then
                return x, y
            end
        end
    end
    return nil, nil
end

function PZTileSlideGame:moveTileAt(x, y, countMove)
    if math.abs(x - self.blankX) + math.abs(y - self.blankY) ~= 1 then return false end
    self.tiles[self.blankY][self.blankX] = self.tiles[y][x]
    self.tiles[y][x] = 0
    self.blankX = x
    self.blankY = y
    if countMove then
        self.moves = self.moves + 1
        self.flash = 5
        self:playSound("ComputerBallHit")
        if self:isSolved() then
            self.gameState = "WIN"
            if not self.bestMoves or self.moves < self.bestMoves then
                self.bestMoves = self.moves
            end
            self:playWinSound()
        end
    end
    return true
end

function PZTileSlideGame:onMouseDown(x, y)
    if self.gameState ~= "PLAYING" then
        self:resetGame()
        return true
    end
    local cx, cy = self:getCellAt(x, y)
    if cx then
        self:moveTileAt(cx, cy, true)
    end
    return true
end

function PZTileSlideGame:update()
    self.tick = (self.tick or 0) + 1
    self.flash = math.max(0, (self.flash or 0) - 1)
    local selectedX, selectedY, activated = ComputerModGameInput.updateGridSelection(self, 4, 4)
    if self.gameState ~= "PLAYING" and ComputerModGameInput.isDown(self, "action") then
        self:resetGame()
    elseif self.gameState == "PLAYING" and activated then
        self:moveTileAt(selectedX, selectedY, true)
    end
end

function PZTileSlideGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.012, 0.012, 0.016)
    self:drawRect(0, 25, self.width, 1, 1, 0.38, 0.36, 0.28)
    self:drawText("TILESLD.EXE", 10, 7, 0.82, 0.78, 0.58, 1, UIFont.Small)
    self:drawText("MOVES " .. tostring(self.moves), 116, 7, 0.82, 0.78, 0.58, 1, UIFont.Small)
    local best = self.bestMoves and tostring(self.bestMoves) or "--"
    self:drawText("BEST " .. best, self.width - 78, 7, 0.82, 0.78, 0.58, 1, UIFont.Small)
end

function PZTileSlideGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 220)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.05, 0.04, 0.03)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.012, 0.012, 0.014)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.38, 0.36, 0.28)
    self:drawText(title, boxX + 10, boxY + 19, 0.82, 0.78, 0.58, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.62, 0.86, 0.62, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": SHUFFLE", boxX + 10, boxY + 58, 0.82, 0.78, 0.58, 1, UIFont.Small)
end

function PZTileSlideGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZTileSlideGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.010, 0.010, 0.012)
    self:drawHud()
    local startX, startY, cell, gap, boardW, boardH = self:getBoardLayout()
    self:drawRect(startX - 8, startY - 8, boardW + 16, boardH + 16, 1, 0.04, 0.036, 0.030)
    self:drawRect(startX - 4, startY - 4, boardW + 8, boardH + 8, 1, 0.006, 0.006, 0.008)
    drawTileBorder(self, startX - 4, startY - 4, boardW + 8, boardH + 8, 1, 0.38, 0.36, 0.28)
    if self.flash and self.flash > 0 then
        self:drawRect(startX - 4, startY - 4, boardW + 8, boardH + 8, self.flash / 100, 0.72, 0.62, 0.32)
    end
    for y = 1, 4 do
        for x = 1, 4 do
            local value = self.tiles[y][x]
            local px = startX + (x - 1) * (cell + gap)
            local py = startY + (y - 1) * (cell + gap)
            if value == 0 then
                self:drawRect(px, py, cell, cell, 1, 0.016, 0.016, 0.018)
                drawTileBorder(self, px, py, cell, cell, 0.5, 0.12, 0.11, 0.10)
            else
                self:drawRect(px + 1, py + 2, cell, cell, 0.26, 0, 0, 0)
                self:drawRect(px, py, cell, cell, 1, 0.54, 0.44, 0.24)
                drawTileBorder(self, px, py, cell, cell, 1, 0.86, 0.70, 0.34)
                self:drawRect(px + 5, py + 5, math.max(1, cell - 10), 2, 0.36, 0.98, 0.88, 0.56)
                local dx = value < 10 and 4 or 8
                self:drawText(tostring(value), px + math.floor(cell * 0.5) - dx, py + math.floor(cell * 0.5) - 8, 0.02, 0.02, 0.02, 1, UIFont.Medium)
            end
        end
    end
    local selectedX = math.max(1, math.min(4, tonumber(self.gamepadSelectionX) or 1))
    local selectedY = math.max(1, math.min(4, tonumber(self.gamepadSelectionY) or 1))
    ComputerModGameInput.drawGamepadSelection(self, startX + (selectedX - 1) * (cell + gap), startY + (selectedY - 1) * (cell + gap), cell, cell)
    if self.gameState == "WIN" then
        self:drawOverlay("TILES RESTORED", "MOVES " .. tostring(self.moves))
    end
    self:drawScanlines()
end

function PZTileSlideGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZTileSlideGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaTileSlide.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaPipeLink.lua
GameClasses['pipelink'] = (function()
require "ISUI/ISPanel"

local PZPipeLinkGame = ISPanel:derive("PZPipeLinkGame")

local pipeDirs = {
    {x = 0, y = -1, bit = 1, opposite = 3},
    {x = 1, y = 0, bit = 2, opposite = 4},
    {x = 0, y = 1, bit = 4, opposite = 1},
    {x = -1, y = 0, bit = 8, opposite = 2}
}

local pipePuzzles = {
    {
        {5, 3, 6, 5, 6},
        {10, 6, 10, 12, 5},
        {10, 9, 3, 3, 10},
        {6, 5, 10, 6, 5},
        {9, 3, 5, 12, 10}
    },
    {
        {6, 5, 3, 5, 6},
        {6, 12, 6, 10, 5},
        {9, 3, 12, 3, 6},
        {5, 12, 3, 10, 9},
        {9, 3, 12, 9, 10}
    },
    {
        {5, 6, 5, 3, 6},
        {10, 9, 12, 6, 12},
        {12, 6, 10, 9, 3},
        {3, 9, 5, 10, 5},
        {9, 12, 5, 10, 10}
    }
}

local function drawPipeBorder(panel, x, y, w, h, a, r, g, b)
    panel:drawRect(x, y, w, 1, a, r, g, b)
    panel:drawRect(x, y, 1, h, a, r, g, b)
    panel:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    panel:drawRect(x, y + h - 1, w, 1, a, r, g, b)
end

local function rotateMask(mask, turns)
    local value = mask
    for i = 1, turns do
        local nextMask = 0
        if value % 2 >= 1 then nextMask = nextMask + 2 end
        if math.floor(value / 2) % 2 >= 1 then nextMask = nextMask + 4 end
        if math.floor(value / 4) % 2 >= 1 then nextMask = nextMask + 8 end
        if math.floor(value / 8) % 2 >= 1 then nextMask = nextMask + 1 end
        value = nextMask
    end
    return value
end

local function hasPipe(mask, bit)
    return math.floor(mask / bit) % 2 >= 1
end

function PZPipeLinkGame:initialise()
    ISPanel.initialise(self)
    self.bestMoves = nil
    self:resetGame()
end

function PZPipeLinkGame:resetGame()
    self.gameState = "PLAYING"
    self.winSoundPlayed = false
    self.tick = 0
    self.moves = 0
    self.flash = 0
    self.puzzleIndex = ZombRand(#pipePuzzles) + 1
    self.tiles = {}
    local source = pipePuzzles[self.puzzleIndex]
    for y = 1, 5 do
        self.tiles[y] = {}
        for x = 1, 5 do
            local correct = source[y][x]
            local rot = ZombRand(4)
            self.tiles[y][x] = {base = correct, rot = rot, mask = rotateMask(correct, rot)}
        end
    end
    if self:isSolved() then
        self:rotateTile(3, 3, false)
    end
    self.moves = 0
end

function PZPipeLinkGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZPipeLinkGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZPipeLinkGame:getBoardLayout()
    local usableW = math.max(1, self.width - 46)
    local usableH = math.max(1, self.height - 82)
    local gap = math.max(2, math.floor(math.min(usableW, usableH) * 0.010))
    local cell = math.floor((math.min(usableW, usableH) - gap * 4) / 5)
    cell = math.max(14, cell)
    local boardW = cell * 5 + gap * 4
    local boardH = boardW
    local x = math.floor((self.width - boardW) / 2)
    local y = 42 + math.floor((usableH - boardH) / 2)
    return x, y, cell, gap, boardW, boardH
end

function PZPipeLinkGame:getTileAt(mx, my)
    local startX, startY, cell, gap = self:getBoardLayout()
    for y = 1, 5 do
        for x = 1, 5 do
            local px = startX + (x - 1) * (cell + gap)
            local py = startY + (y - 1) * (cell + gap)
            if mx >= px and mx <= px + cell and my >= py and my <= py + cell then
                return x, y
            end
        end
    end
    return nil, nil
end

function PZPipeLinkGame:rotateTile(x, y, countMove)
    local tile = self.tiles[y] and self.tiles[y][x]
    if not tile then return end
    tile.rot = (tile.rot + 1) % 4
    tile.mask = rotateMask(tile.base, tile.rot)
    if countMove then
        self.moves = self.moves + 1
        self.flash = 5
        self:playSound("ComputerBallHit")
        if self:isSolved() then
            self.gameState = "WIN"
            if not self.bestMoves or self.moves < self.bestMoves then
                self.bestMoves = self.moves
            end
            self:playWinSound()
        end
    end
end

function PZPipeLinkGame:isSolved()
    local startTile = self.tiles[3] and self.tiles[3][1]
    if not startTile or not hasPipe(startTile.mask, 8) then return false end
    local visited = {}
    local queue = {{x = 1, y = 3}}
    while #queue > 0 do
        local node = table.remove(queue, 1)
        local key = tostring(node.x) .. ":" .. tostring(node.y)
        if not visited[key] then
            visited[key] = true
            local tile = self.tiles[node.y] and self.tiles[node.y][node.x]
            if tile then
                if node.x == 5 and node.y == 3 and hasPipe(tile.mask, 2) then
                    return true
                end
                for i = 1, #pipeDirs do
                    local dir = pipeDirs[i]
                    if hasPipe(tile.mask, dir.bit) then
                        local nx = node.x + dir.x
                        local ny = node.y + dir.y
                        local other = self.tiles[ny] and self.tiles[ny][nx]
                        if other and hasPipe(other.mask, pipeDirs[dir.opposite].bit) then
                            queue[#queue + 1] = {x = nx, y = ny}
                        end
                    end
                end
            end
        end
    end
    return false
end

function PZPipeLinkGame:onMouseDown(x, y)
    if self.gameState ~= "PLAYING" then
        self:resetGame()
        return true
    end
    local tx, ty = self:getTileAt(x, y)
    if tx then
        self:rotateTile(tx, ty, true)
    end
    return true
end

function PZPipeLinkGame:update()
    self.tick = (self.tick or 0) + 1
    self.flash = math.max(0, (self.flash or 0) - 1)
    local selectedX, selectedY, activated = ComputerModGameInput.updateGridSelection(self, 5, 5)
    if self.gameState ~= "PLAYING" and ComputerModGameInput.isDown(self, "action") then
        self:resetGame()
    elseif self.gameState == "PLAYING" and activated then
        self:rotateTile(selectedX, selectedY, true)
    end
end

function PZPipeLinkGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.006, 0.014, 0.014)
    self:drawRect(0, 25, self.width, 1, 1, 0.24, 0.42, 0.34)
    self:drawText("PIPELINK.EXE", 10, 7, 0.62, 0.82, 0.66, 1, UIFont.Small)
    self:drawText("TURNS " .. tostring(self.moves), 122, 7, 0.62, 0.82, 0.66, 1, UIFont.Small)
    local best = self.bestMoves and tostring(self.bestMoves) or "--"
    self:drawText("BEST " .. best, self.width - 78, 7, 0.62, 0.82, 0.66, 1, UIFont.Small)
end

function PZPipeLinkGame:drawPipe(tile, x, y, cell, connected)
    local cx = x + math.floor(cell / 2)
    local cy = y + math.floor(cell / 2)
    local thick = math.max(4, math.floor(cell * 0.20))
    local half = math.floor(thick / 2)
    local r = connected and 0.34 or 0.18
    local g = connected and 0.72 or 0.38
    local b = connected and 0.46 or 0.38
    self:drawRect(cx - half, cy - half, thick, thick, 1, r, g, b)
    if hasPipe(tile.mask, 1) then self:drawRect(cx - half, y + 4, thick, cy - y - 4, 1, r, g, b) end
    if hasPipe(tile.mask, 2) then self:drawRect(cx, cy - half, x + cell - cx - 4, thick, 1, r, g, b) end
    if hasPipe(tile.mask, 4) then self:drawRect(cx - half, cy, thick, y + cell - cy - 4, 1, r, g, b) end
    if hasPipe(tile.mask, 8) then self:drawRect(x + 4, cy - half, cx - x - 4, thick, 1, r, g, b) end
end

function PZPipeLinkGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 224)
    local boxH = 76
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.04, 0.06, 0.04)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.006, 0.014, 0.014)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.24, 0.42, 0.34)
    self:drawText(title, boxX + 10, boxY + 19, 0.62, 0.82, 0.66, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 41, 0.80, 0.78, 0.54, 1, UIFont.Small)
    self:drawText(ComputerModGameInput.getInputLabel(self, "action") .. ": NEW GRID", boxX + 10, boxY + 58, 0.62, 0.82, 0.66, 1, UIFont.Small)
end

function PZPipeLinkGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZPipeLinkGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.006, 0.018, 0.014)
    self:drawHud()
    local startX, startY, cell, gap, boardW, boardH = self:getBoardLayout()
    self:drawRect(startX - 10, startY - 10, boardW + 20, boardH + 20, 1, 0.030, 0.038, 0.032)
    self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, 1, 0.004, 0.008, 0.008)
    drawPipeBorder(self, startX - 6, startY - 6, boardW + 12, boardH + 12, 1, 0.24, 0.42, 0.34)
    if self.flash and self.flash > 0 then
        self:drawRect(startX - 6, startY - 6, boardW + 12, boardH + 12, self.flash / 100, 0.34, 0.72, 0.42)
    end
    for y = 1, 5 do
        for x = 1, 5 do
            local px = startX + (x - 1) * (cell + gap)
            local py = startY + (y - 1) * (cell + gap)
            self:drawRect(px, py, cell, cell, 1, 0.016, 0.028, 0.026)
            drawPipeBorder(self, px, py, cell, cell, 0.7, 0.12, 0.24, 0.22)
            self:drawPipe(self.tiles[y][x], px, py, cell, self.gameState == "WIN")
        end
    end
    local selectedX = math.max(1, math.min(5, tonumber(self.gamepadSelectionX) or 1))
    local selectedY = math.max(1, math.min(5, tonumber(self.gamepadSelectionY) or 1))
    ComputerModGameInput.drawGamepadSelection(self, startX + (selectedX - 1) * (cell + gap), startY + (selectedY - 1) * (cell + gap), cell, cell)
    self:drawRect(startX - 16, startY + 2 * (cell + gap) + math.floor(cell / 2) - 3, 14, 6, 1, 0.62, 0.82, 0.66)
    self:drawRect(startX + boardW + 2, startY + 2 * (cell + gap) + math.floor(cell / 2) - 3, 14, 6, 1, 0.62, 0.82, 0.66)
    if self.gameState == "WIN" then
        self:drawOverlay("LINK ESTABLISHED", "TURNS " .. tostring(self.moves))
    end
    self:drawScanlines()
end

function PZPipeLinkGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZPipeLinkGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaPipeLink.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaCodeBreaker.lua
GameClasses['codebreaker'] = (function()
require "ISUI/ISPanel"

local PZCodeBreakerGame = ISPanel:derive("PZCodeBreakerGame")

local codeColors = {
    {r = 0.72, g = 0.26, b = 0.20},
    {r = 0.18, g = 0.58, b = 0.34},
    {r = 0.22, g = 0.36, b = 0.72},
    {r = 0.76, g = 0.62, b = 0.18},
    {r = 0.58, g = 0.30, b = 0.64}
}

local function drawCodeBorder(panel, x, y, w, h, a, r, g, b)
    panel:drawRect(x, y, w, 1, a, r, g, b)
    panel:drawRect(x, y, 1, h, a, r, g, b)
    panel:drawRect(x + w - 1, y, 1, h, a, r, g, b)
    panel:drawRect(x, y + h - 1, w, 1, a, r, g, b)
end

function PZCodeBreakerGame:initialise()
    ISPanel.initialise(self)
    self.bestRows = nil
    self:resetGame()
end

function PZCodeBreakerGame:resetGame()
    self.gameState = "PLAYING"
    self.winSoundPlayed = false
    self.gameOverSoundPlayed = false
    self.tick = 0
    self.flash = 0
    self.row = 1
    self.secret = {}
    self.rows = {}
    for i = 1, 4 do
        self.secret[i] = ZombRand(#codeColors) + 1
    end
    for y = 1, 8 do
        self.rows[y] = {guess = {1, 1, 1, 1}, exact = nil, near = nil}
    end
end

function PZCodeBreakerGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZCodeBreakerGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZCodeBreakerGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZCodeBreakerGame:getLayout()
    local rowH = math.max(22, math.floor((self.height - 72) / 8))
    local peg = math.max(14, math.min(22, rowH - 6))
    local startX = math.max(12, math.floor((self.width - 228) / 2))
    local startY = 36
    local checkX = startX + 156
    local resultX = startX + 118
    return startX, startY, rowH, peg, resultX, checkX
end

function PZCodeBreakerGame:getPegAt(mx, my)
    local startX, startY, rowH, peg = self:getLayout()
    local y = startY + (self.row - 1) * rowH
    if my < y or my > y + rowH then return nil end
    for i = 1, 4 do
        local x = startX + (i - 1) * (peg + 8)
        if mx >= x and mx <= x + peg and my >= y + 3 and my <= y + 3 + peg then
            return i
        end
    end
    return nil
end

function PZCodeBreakerGame:getCheckRect()
    local startX, startY, rowH, peg, resultX, checkX = self:getLayout()
    return {x = checkX, y = startY + (self.row - 1) * rowH + 3, w = 58, h = peg}
end

function PZCodeBreakerGame:evaluateGuess(guess)
    local exact = 0
    local near = 0
    local secretUsed = {}
    local guessUsed = {}
    for i = 1, 4 do
        if guess[i] == self.secret[i] then
            exact = exact + 1
            secretUsed[i] = true
            guessUsed[i] = true
        end
    end
    for i = 1, 4 do
        if not guessUsed[i] then
            for j = 1, 4 do
                if not secretUsed[j] and guess[i] == self.secret[j] then
                    near = near + 1
                    secretUsed[j] = true
                    guessUsed[i] = true
                    break
                end
            end
        end
    end
    return exact, near
end

function PZCodeBreakerGame:submitGuess()
    if self.gameState ~= "PLAYING" then return end
    local current = self.rows[self.row]
    local exact, near = self:evaluateGuess(current.guess)
    current.exact = exact
    current.near = near
    self.flash = 6
    self:playSound("ComputerBallHit")
    if exact >= 4 then
        self.gameState = "WIN"
        if not self.bestRows or self.row < self.bestRows then
            self.bestRows = self.row
        end
        self:playWinSound()
    elseif self.row >= 8 then
        self.gameState = "GAMEOVER"
        self:playGameOverSound()
    else
        self.row = self.row + 1
        for i = 1, 4 do
            self.rows[self.row].guess[i] = current.guess[i]
        end
    end
end

function PZCodeBreakerGame:onMouseDown(x, y)
    if self.gameState ~= "PLAYING" then
        self:resetGame()
        return true
    end
    local peg = self:getPegAt(x, y)
    if peg then
        local row = self.rows[self.row]
        row.guess[peg] = (row.guess[peg] % #codeColors) + 1
        self:playSound("ComputerBallHit")
        return true
    end
    local button = self:getCheckRect()
    if x >= button.x and x <= button.x + button.w and y >= button.y and y <= button.y + button.h then
        self:submitGuess()
    end
    return true
end

function PZCodeBreakerGame:update()
    self.tick = (self.tick or 0) + 1
    self.flash = math.max(0, (self.flash or 0) - 1)
    local selectedX, _, activated = ComputerModGameInput.updateGridSelection(self, 5, 1)
    if self.gameState ~= "PLAYING" and ComputerModGameInput.isDown(self, "action") then
        self:resetGame()
    elseif self.gameState == "PLAYING" and activated then
        if selectedX <= 4 then
            local row = self.rows[self.row]
            row.guess[selectedX] = (row.guess[selectedX] % #codeColors) + 1
            self:playSound("ComputerBallHit")
        else
            self:submitGuess()
        end
    end
end

function PZCodeBreakerGame:drawHud()
    self:drawRect(0, 0, self.width, 26, 1, 0.010, 0.010, 0.018)
    self:drawRect(0, 25, self.width, 1, 1, 0.30, 0.32, 0.46)
    self:drawText("CODEBRK.EXE", 10, 7, 0.62, 0.68, 0.86, 1, UIFont.Small)
    self:drawText("ROW " .. tostring(self.row) .. "/8", 118, 7, 0.62, 0.68, 0.86, 1, UIFont.Small)
    local best = self.bestRows and tostring(self.bestRows) or "--"
    self:drawText("BEST " .. best, self.width - 78, 7, 0.62, 0.68, 0.86, 1, UIFont.Small)
end

function PZCodeBreakerGame:drawPeg(x, y, size, colorIndex, dim)
    local color = codeColors[colorIndex] or codeColors[1]
    local shade = dim and 0.48 or 1
    self:drawRect(x + 1, y + 2, size, size, 0.22, 0, 0, 0)
    self:drawRect(x, y, size, size, 1, color.r * shade, color.g * shade, color.b * shade)
    drawCodeBorder(self, x, y, size, size, 1, 0.10, 0.10, 0.12)
    if size > 16 then
        self:drawRect(x + 4, y + 4, math.max(1, size - 8), 2, 0.32, 1, 1, 0.86)
    end
end

function PZCodeBreakerGame:drawOverlay(title, detail)
    local boxW = math.min(self.width - 42, 228)
    local boxH = 82
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.04, 0.04, 0.07)
    self:drawRect(boxX, boxY, boxW, boxH, 0.98, 0.008, 0.010, 0.018)
    self:drawRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.30, 0.32, 0.46)
    self:drawText(title, boxX + 10, boxY + 17, 0.62, 0.68, 0.86, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 37, 0.80, 0.76, 0.52, 1, UIFont.Small)
    for i = 1, 4 do
        self:drawPeg(boxX + 10 + (i - 1) * 24, boxY + 55, 16, self.secret[i], false)
    end
end

function PZCodeBreakerGame:drawScanlines()
    local y = 0
    while y < self.height do
        self:drawRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
end

function PZCodeBreakerGame:prerender()
    self:drawRect(0, 0, self.width, self.height, 1, 0.008, 0.010, 0.018)
    self:drawHud()
    local startX, startY, rowH, peg, resultX, checkX = self:getLayout()
    local panelW = math.min(self.width - 24, 232)
    self:drawRect(startX - 8, startY - 6, panelW, rowH * 8 + 12, 1, 0.030, 0.032, 0.046)
    drawCodeBorder(self, startX - 8, startY - 6, panelW, rowH * 8 + 12, 1, 0.24, 0.28, 0.42)
    if self.flash and self.flash > 0 then
        self:drawRect(startX - 8, startY - 6, panelW, rowH * 8 + 12, self.flash / 100, 0.52, 0.62, 0.86)
    end
    for r = 1, 8 do
        local rowY = startY + (r - 1) * rowH
        if r == self.row and self.gameState == "PLAYING" then
            self:drawRect(startX - 4, rowY, panelW - 8, rowH - 1, 0.22, 0.34, 0.40, 0.52)
        end
        self:drawText(tostring(r), startX - 22, rowY + 6, 0.62, 0.68, 0.86, 1, UIFont.Small)
        for i = 1, 4 do
            self:drawPeg(startX + (i - 1) * (peg + 8), rowY + 3, peg, self.rows[r].guess[i], r > self.row and self.gameState == "PLAYING")
        end
        if self.rows[r].exact then
            self:drawText("X" .. tostring(self.rows[r].exact), resultX, rowY + 5, 0.82, 0.78, 0.58, 1, UIFont.Small)
            self:drawText("N" .. tostring(self.rows[r].near), resultX + 34, rowY + 5, 0.62, 0.82, 0.66, 1, UIFont.Small)
        end
    end
    if self.gameState == "PLAYING" then
        local button = self:getCheckRect()
        self:drawRect(button.x, button.y, button.w, button.h, 1, 0.18, 0.20, 0.32)
        drawCodeBorder(self, button.x, button.y, button.w, button.h, 1, 0.48, 0.52, 0.72)
        self:drawText("CHECK", button.x + 9, button.y + math.floor(button.h / 2) - 6, 0.82, 0.86, 0.92, 1, UIFont.Small)
        local selectedX = math.max(1, math.min(5, tonumber(self.gamepadSelectionX) or 1))
        if selectedX <= 4 then
            ComputerModGameInput.drawGamepadSelection(self, startX + (selectedX - 1) * (peg + 8), startY + (self.row - 1) * rowH + 3, peg, peg)
        else
            ComputerModGameInput.drawGamepadSelection(self, button.x, button.y, button.w, button.h)
        end
    end
    if self.gameState == "WIN" then
        self:drawOverlay("CODE OPENED", "ROW " .. tostring(self.row))
    elseif self.gameState == "GAMEOVER" then
        self:drawOverlay("ACCESS DENIED", "CODE WAS")
    end
    self:drawScanlines()
end

function PZCodeBreakerGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZCodeBreakerGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaCodeBreaker.lua
-- BEGIN INSTALLED SOURCE client\ComputerMod_eLuaOutbreakOps.lua
GameClasses['outbreakops'] = (function()
require "ISUI/ISPanel"

local PZOutbreakOpsGame = ISPanel:derive("PZOutbreakOpsGame")

local function opsText(id, fallback)
    return ComputerModLocalization and ComputerModLocalization.text("OutbreakOps", "HUD", id, fallback) or fallback
end

local opsMap = {
    "1111111111111111",
    "1000000000000001",
    "1011110111111101",
    "1000010100000101",
    "1111010101110101",
    "1000010001010001",
    "1011111101011111",
    "1010000001000001",
    "1010111111011101",
    "1010100000010101",
    "1010101111010101",
    "1010001000010001",
    "1011101011110111",
    "1000001000000001",
    "1000001000000201",
    "1111111111111111"
}

local opsEnemies = {
    {x = 4.5, y = 3.5, hp = 2},
    {x = 11.5, y = 3.5, hp = 2},
    {x = 7.5, y = 7.5, hp = 3},
    {x = 12.5, y = 9.5, hp = 2},
    {x = 4.5, y = 13.5, hp = 3},
    {x = 12.5, y = 13.5, hp = 2}
}

local opsObjectives = {
    {id = "relay", label = "RELAY", x = 13.5, y = 11.5},
    {id = "fuel", label = "FUEL", x = 10.5, y = 7.5},
    {id = "rescue", label = "CREW", x = 2.5, y = 13.5}
}

local opsPickups = {
    {kind = "ammo", x = 5.5, y = 1.5, amount = 3},
    {kind = "med", x = 10.5, y = 1.5, amount = 22},
    {kind = "ammo", x = 14.5, y = 7.5, amount = 3},
    {kind = "med", x = 5.5, y = 13.5, amount = 18}
}

local function atan2Ops(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi * 0.5 end
    if x == 0 and y < 0 then return -math.pi * 0.5 end
    return 0
end

local function clampOps(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function PZOutbreakOpsGame:initialise()
    ISPanel.initialise(self)
    self.mapWidth = #opsMap[1]
    self.mapHeight = #opsMap
    self.fieldOfView = math.rad(68)
    self.maxDepth = 18
    self.rayStep = 0.035
    self.highscore = 0
    self:resetGame()
end

function PZOutbreakOpsGame:resetGame()
    self.gameState = "PLAYING"
    self.score = 0
    self.damageFlash = 0
    self.muzzleFlash = 0
    self.fireCooldown = 0
    self.crtTick = 0
    self.lastSpaceDown = false
    self.gameOverSoundPlayed = false
    self.winSoundPlayed = false
    self.ammo = 10
    self.events = {}
    self.hint = opsText("SecureCaches", "SECURE CACHES")
    self.player = {
        x = 1.75,
        y = 1.75,
        angle = 0,
        health = 100,
        radius = 0.18,
        moveSpeed = 0.087,
        strafeSpeed = 0.071,
        turnSpeed = 0.063
    }
    self.objectives = {}
    self.pickups = {}
    self.enemies = {}
    for i = 1, #opsObjectives do
        local item = opsObjectives[i]
        self.objectives[i] = {id = item.id, label = opsText("Objective_" .. item.id, item.label), x = item.x, y = item.y, secured = false, flash = 0}
    end
    for i = 1, #opsPickups do
        local item = opsPickups[i]
        self.pickups[i] = {kind = item.kind, x = item.x, y = item.y, amount = item.amount, used = false}
    end
    for i = 1, #opsEnemies do
        local enemy = opsEnemies[i]
        self.enemies[i] = {x = enemy.x, y = enemy.y, hp = enemy.hp, cooldown = ZombRand(24), alive = true, hitFlash = 0}
    end
    self.totalEnemies = #self.enemies
    self:addLog(opsText("Title", "OUTBREAK OPS"))
    self:addLog(opsText("UseFire", "ACTION: USE/FIRE"))
end

function PZOutbreakOpsGame:addLog(text)
    table.insert(self.events, 1, text)
    while #self.events > 4 do
        table.remove(self.events)
    end
end

function PZOutbreakOpsGame:playSound(name)
    if not name or not getSoundManager then return end
    pcall(function() getSoundManager():playUISound(name) end)
end

function PZOutbreakOpsGame:playGameOverSound()
    if self.gameOverSoundPlayed then return end
    self.gameOverSoundPlayed = true
    if ZombRand(100) < 5 then
        self:playSound("ComputerDoomGameOverRare")
    else
        self:playSound("ComputerDoomGameOver")
    end
end

function PZOutbreakOpsGame:playWinSound()
    if self.winSoundPlayed then return end
    self.winSoundPlayed = true
    self:playSound("ComputerWinOpen")
end

function PZOutbreakOpsGame:getTile(x, y)
    local cellX = math.floor(x) + 1
    local cellY = math.floor(y) + 1
    if cellX < 1 or cellY < 1 or cellX > self.mapWidth or cellY > self.mapHeight then return "1" end
    return opsMap[cellY]:sub(cellX, cellX)
end

function PZOutbreakOpsGame:isWall(x, y)
    return self:getTile(x, y) == "1"
end

function PZOutbreakOpsGame:isExit(x, y)
    return self:getTile(x, y) == "2"
end

function PZOutbreakOpsGame:normalizeAngle(angle)
    while angle <= -math.pi do angle = angle + math.pi * 2 end
    while angle > math.pi do angle = angle - math.pi * 2 end
    return angle
end

function PZOutbreakOpsGame:clamp(value, minValue, maxValue)
    return clampOps(value, minValue, maxValue)
end

function PZOutbreakOpsGame:drawClippedRect(x, y, width, height, a, r, g, b)
    local clippedX = math.max(0, math.floor(x))
    local clippedY = math.max(0, math.floor(y))
    local clippedW = math.ceil(x + width) - clippedX
    local clippedH = math.ceil(y + height) - clippedY
    if clippedX >= self.width or clippedY >= self.height then return end
    if clippedX + clippedW > self.width then clippedW = self.width - clippedX end
    if clippedY + clippedH > self.height then clippedH = self.height - clippedY end
    if clippedW <= 0 or clippedH <= 0 then return end
    self:drawRect(clippedX, clippedY, clippedW, clippedH, a, r, g, b)
end

function PZOutbreakOpsGame:projectPoint(worldX, worldY)
    local dx = worldX - self.player.x
    local dy = worldY - self.player.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local angle = self:normalizeAngle(atan2Ops(dy, dx) - self.player.angle)
    local correctedDistance = distance * math.cos(angle)
    return distance, angle, correctedDistance
end

function PZOutbreakOpsGame:canMoveTo(x, y)
    local r = self.player.radius
    return not self:isWall(x - r, y - r)
        and not self:isWall(x + r, y - r)
        and not self:isWall(x - r, y + r)
        and not self:isWall(x + r, y + r)
end

function PZOutbreakOpsGame:movePlayer(forwardMove, strafeMove)
    local targetX = self.player.x + math.cos(self.player.angle) * forwardMove + math.cos(self.player.angle + math.pi * 0.5) * strafeMove
    local targetY = self.player.y + math.sin(self.player.angle) * forwardMove + math.sin(self.player.angle + math.pi * 0.5) * strafeMove
    if self:canMoveTo(targetX, self.player.y) then self.player.x = targetX end
    if self:canMoveTo(self.player.x, targetY) then self.player.y = targetY end
end

function PZOutbreakOpsGame:lineBlocked(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local steps = math.max(1, math.floor(math.max(math.abs(dx), math.abs(dy)) / 0.08))
    for i = 1, steps do
        local t = i / steps
        if self:isWall(x1 + dx * t, y1 + dy * t) then return true end
    end
    return false
end

function PZOutbreakOpsGame:getSecuredObjectives()
    local count = 0
    for i = 1, #self.objectives do
        if self.objectives[i].secured then count = count + 1 end
    end
    return count
end

function PZOutbreakOpsGame:objectivesComplete()
    return self:getSecuredObjectives() >= #self.objectives
end

function PZOutbreakOpsGame:getAliveEnemies()
    local alive = 0
    for i = 1, #self.enemies do
        if self.enemies[i].alive then alive = alive + 1 end
    end
    return alive
end

function PZOutbreakOpsGame:getTargetEnemy()
    local bestEnemy = nil
    local bestDistance = 999
    for i = 1, #self.enemies do
        local enemy = self.enemies[i]
        if enemy.alive then
            local dx = enemy.x - self.player.x
            local dy = enemy.y - self.player.y
            local distance = math.sqrt(dx * dx + dy * dy)
            local angle = self:normalizeAngle(atan2Ops(dy, dx) - self.player.angle)
            if distance < bestDistance and math.abs(angle) < 0.13 and not self:lineBlocked(self.player.x, self.player.y, enemy.x, enemy.y) then
                bestDistance = distance
                bestEnemy = enemy
            end
        end
    end
    return bestEnemy
end

function PZOutbreakOpsGame:getNearestObjective()
    for i = 1, #self.objectives do
        local obj = self.objectives[i]
        if not obj.secured then
            local dx = obj.x - self.player.x
            local dy = obj.y - self.player.y
            if dx * dx + dy * dy < 0.64 and not self:lineBlocked(self.player.x, self.player.y, obj.x, obj.y) then
                return obj
            end
        end
    end
    return nil
end

function PZOutbreakOpsGame:secureObjective(obj)
    obj.secured = true
    obj.flash = 8
    self.score = self.score + 240
    if obj.id == "relay" then
        self.hint = opsText("RelayOnline", "RELAY ONLINE")
    elseif obj.id == "fuel" then
        self.hint = opsText("FuelSecured", "FUEL SECURED")
        self.ammo = self.ammo + 2
    else
        self.hint = opsText("CrewLocated", "CREW LOCATED")
        self.player.health = math.min(100, self.player.health + 20)
    end
    self:addLog(obj.label .. " OK")
    self:playSound("ComputerWinOpen")
end

function PZOutbreakOpsGame:finishOperation()
    if self.gameState ~= "PLAYING" then return end
    self.gameState = "WIN"
    self.score = self.score + 300 + self.player.health * 2 + self.ammo * 12
    if self.score > self.highscore then self.highscore = self.score end
    self.hint = opsText("Extracted", "EXTRACTED")
    self:addLog(opsText("ExtractOK", "EXTRACT OK"))
    self:playWinSound()
end

function PZOutbreakOpsGame:interact()
    local obj = self:getNearestObjective()
    if obj then
        self:secureObjective(obj)
        return true
    end
    if self:isExit(self.player.x, self.player.y) and self:objectivesComplete() then
        self:finishOperation()
        return true
    end
    if self:isExit(self.player.x, self.player.y) then
        self.hint = opsText("CacheMissing", "CACHE MISSING")
        self:addLog(opsText("ObjectivesLeft", "OBJECTIVES LEFT"))
        self:playSound("ComputerBallHit")
        return true
    end
    return false
end

function PZOutbreakOpsGame:shootOrUse()
    if self.fireCooldown > 0 then return end
    local target = self:getTargetEnemy()
    if not target and self:interact() then return end
    if self.ammo <= 0 then
        self.hint = opsText("NoAmmo", "NO AMMO")
        self:addLog(opsText("NoAmmo", "NO AMMO"))
        self:playSound("ComputerBallHit")
        return
    end
    self.fireCooldown = 8
    self.muzzleFlash = 3
    self.ammo = self.ammo - 1
    self:playSound("ComputerDoomGun")
    if target then
        target.hp = target.hp - 1
        target.hitFlash = 5
        if target.hp <= 0 then
            target.alive = false
            self.score = self.score + 105
            self.hint = opsText("ContactDown", "CONTACT DOWN")
        else
            self.score = self.score + 28
            self.hint = opsText("Hit", "HIT")
        end
    else
        self.hint = opsText("Miss", "MISS")
    end
end

function PZOutbreakOpsGame:updateEnemies()
    for i = 1, #self.enemies do
        local enemy = self.enemies[i]
        if enemy.alive then
            if enemy.cooldown > 0 then enemy.cooldown = enemy.cooldown - 1 end
            if enemy.hitFlash > 0 then enemy.hitFlash = enemy.hitFlash - 1 end
            local dx = self.player.x - enemy.x
            local dy = self.player.y - enemy.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance > 0.88 and not self:lineBlocked(enemy.x, enemy.y, self.player.x, self.player.y) then
                local speed = distance < 4.2 and 0.024 or 0.014
                local moveX = dx / distance * speed
                local moveY = dy / distance * speed
                if not self:isWall(enemy.x + moveX, enemy.y) then enemy.x = enemy.x + moveX end
                if not self:isWall(enemy.x, enemy.y + moveY) then enemy.y = enemy.y + moveY end
            end
            if distance <= 1.02 and enemy.cooldown == 0 then
                enemy.cooldown = 30
                self.player.health = self.player.health - 8
                self.damageFlash = 7
                self.hint = opsText("TeamHit", "TEAM HIT")
                if self.player.health <= 0 then
                    self.player.health = 0
                    self.gameState = "GAMEOVER"
                    if self.score > self.highscore then self.highscore = self.score end
                    self:playGameOverSound()
                end
            end
        end
    end
end

function PZOutbreakOpsGame:updatePickups()
    for i = 1, #self.pickups do
        local item = self.pickups[i]
        if not item.used then
            local dx = self.player.x - item.x
            local dy = self.player.y - item.y
            if dx * dx + dy * dy < 0.20 then
                item.used = true
                if item.kind == "ammo" then
                    self.ammo = self.ammo + item.amount
                    self.hint = opsText("AmmoFound", "AMMO FOUND")
                    self:addLog(opsText("Ammo", "AMMO") .. " +" .. tostring(item.amount))
                else
                    self.player.health = math.min(100, self.player.health + item.amount)
                    self.hint = opsText("MedFound", "MED FOUND")
                    self:addLog(opsText("Med", "MED") .. " +" .. tostring(item.amount))
                end
                self.score = self.score + 20
                self:playSound("ComputerBallHit")
            end
        end
    end
end

function PZOutbreakOpsGame:castRay(angle)
    local distance = 0
    local hitX = self.player.x
    local hitY = self.player.y
    while distance < self.maxDepth do
        distance = distance + self.rayStep
        hitX = self.player.x + math.cos(angle) * distance
        hitY = self.player.y + math.sin(angle) * distance
        if self:isWall(hitX, hitY) then break end
    end
    local localX = hitX - math.floor(hitX)
    local localY = hitY - math.floor(hitY)
    local edgeDistance = math.min(localX, 1 - localX, localY, 1 - localY)
    local shade = edgeDistance < 0.08 and 0.88 or 0.68
    if distance >= self.maxDepth then shade = 0.16 end
    return distance, shade
end

function PZOutbreakOpsGame:update()
    self.crtTick = ((self.crtTick or 0) + 1) % 240
    if self.gameState ~= "PLAYING" then
        local resetPressed = ComputerModGameInput.isDown(self, "action") or ComputerModGameInput.isDown(self, "secondary")
        if resetPressed and not self.lastSpaceDown then self:resetGame() end
        self.lastSpaceDown = resetPressed
        return
    end
    if ComputerModGameInput.isDown(self, "left") then self.player.angle = self:normalizeAngle(self.player.angle - self.player.turnSpeed) end
    if ComputerModGameInput.isDown(self, "right") then self.player.angle = self:normalizeAngle(self.player.angle + self.player.turnSpeed) end
    local forwardMove = 0
    local strafeMove = 0
    if ComputerModGameInput.isDown(self, "forward") or ComputerModGameInput.isDown(self, "up") then forwardMove = forwardMove + self.player.moveSpeed end
    if ComputerModGameInput.isDown(self, "backward") or ComputerModGameInput.isDown(self, "down") then forwardMove = forwardMove - self.player.moveSpeed end
    if ComputerModGameInput.isDown(self, "strafeLeft") then strafeMove = strafeMove - self.player.strafeSpeed end
    if ComputerModGameInput.isDown(self, "strafeRight") then strafeMove = strafeMove + self.player.strafeSpeed end
    if forwardMove ~= 0 or strafeMove ~= 0 then self:movePlayer(forwardMove, strafeMove) end
    local actionPressed = ComputerModGameInput.isDown(self, "action")
    if actionPressed and not self.lastSpaceDown then self:shootOrUse() end
    self.lastSpaceDown = actionPressed
    if self.fireCooldown > 0 then self.fireCooldown = self.fireCooldown - 1 end
    if self.damageFlash > 0 then self.damageFlash = self.damageFlash - 1 end
    if self.muzzleFlash > 0 then self.muzzleFlash = self.muzzleFlash - 1 end
    for i = 1, #self.objectives do
        if self.objectives[i].flash > 0 then self.objectives[i].flash = self.objectives[i].flash - 1 end
    end
    self:updateEnemies()
    self:updatePickups()
    if self:isExit(self.player.x, self.player.y) and self:objectivesComplete() then self:finishOperation() end
end

function PZOutbreakOpsGame:onMouseDown(x, y)
    if self.gameState == "PLAYING" then
        self:shootOrUse()
    else
        self:resetGame()
    end
end

function PZOutbreakOpsGame:drawWeapon()
    local baseX = math.floor(self.width * 0.5)
    local baseY = self.height - 74
    local bob = self.fireCooldown % 2
    self:drawClippedRect(baseX - 38, baseY + 13 + bob, 76, 22, 1, 0.10, 0.12, 0.12)
    self:drawClippedRect(baseX - 16, baseY - 5 + bob, 32, 40, 1, 0.27, 0.30, 0.29)
    self:drawClippedRect(baseX - 9, baseY - 19 + bob, 18, 22, 1, 0.54, 0.58, 0.52)
    self:drawClippedRect(baseX - 3, baseY - 30 + bob, 6, 15, 1, 0.78, 0.82, 0.72)
    self:drawClippedRect(baseX - 24, baseY + 17 + bob, 48, 5, 1, 0.03, 0.04, 0.04)
    if self.muzzleFlash > 0 then
        self:drawClippedRect(baseX - 14, baseY - 39, 28, 18, 1, 1, 0.78, 0.18)
        self:drawClippedRect(baseX - 7, baseY - 50, 14, 14, 1, 0.98, 0.25, 0.08)
    end
end

function PZOutbreakOpsGame:drawMinimap()
    local cell = clampOps(math.floor(self.width / 150), 3, 5)
    local mapW = self.mapWidth * cell
    local mapH = self.mapHeight * cell
    local ox = self.width - mapW - 10
    local oy = 10
    self:drawClippedRect(ox - 3, oy - 3, mapW + 6, mapH + 6, 0.92, 0.02, 0.025, 0.022)
    for my = 1, self.mapHeight do
        for mx = 1, self.mapWidth do
            local tile = opsMap[my]:sub(mx, mx)
            local r, g, b = 0.06, 0.08, 0.07
            if tile == "1" then
                r, g, b = 0.22, 0.28, 0.24
            elseif tile == "2" then
                r, g, b = 0.22, 0.78, 0.34
            end
            self:drawClippedRect(ox + (mx - 1) * cell, oy + (my - 1) * cell, cell - 1, cell - 1, 1, r, g, b)
        end
    end
    for i = 1, #self.objectives do
        local obj = self.objectives[i]
        if not obj.secured then
            self:drawClippedRect(ox + math.floor((obj.x - 0.5) * cell), oy + math.floor((obj.y - 0.5) * cell), cell - 1, cell - 1, 1, 0.82, 0.72, 0.26)
        end
    end
    for i = 1, #self.enemies do
        local enemy = self.enemies[i]
        if enemy.alive then
            self:drawClippedRect(ox + math.floor((enemy.x - 0.5) * cell), oy + math.floor((enemy.y - 0.5) * cell), cell - 1, cell - 1, 1, 0.64, 0.82, 0.42)
        end
    end
    local px = ox + math.floor((self.player.x - 0.5) * cell)
    local py = oy + math.floor((self.player.y - 0.5) * cell)
    self:drawClippedRect(px, py, cell - 1, cell - 1, 1, 0.96, 0.96, 0.82)
    self:drawClippedRect(px + math.floor(math.cos(self.player.angle) * 4), py + math.floor(math.sin(self.player.angle) * 4), 2, 2, 1, 1, 0.78, 0.24)
end

function PZOutbreakOpsGame:drawEnemies(depthBuffer, rayCount, columnWidth)
    local visible = {}
    for i = 1, #self.enemies do
        local enemy = self.enemies[i]
        if enemy.alive then
            local distance, angle, correctedDistance = self:projectPoint(enemy.x, enemy.y)
            if correctedDistance > 0.12 and math.abs(angle) < self.fieldOfView * 0.58 and not self:lineBlocked(self.player.x, self.player.y, enemy.x, enemy.y) then
                table.insert(visible, {enemy = enemy, distance = distance, angle = angle, correctedDistance = correctedDistance})
            end
        end
    end
    table.sort(visible, function(a, b) return a.distance > b.distance end)
    for i = 1, #visible do
        local item = visible[i]
        local enemy = item.enemy
        local distance = math.max(0.2, item.correctedDistance)
        local screenCenter = (0.5 + item.angle / self.fieldOfView) * self.width
        local spriteHeight = math.floor(self.height / distance * 0.72)
        local spriteWidth = math.floor(spriteHeight * 0.50)
        local left = math.floor(screenCenter - spriteWidth * 0.5)
        local top = math.floor(self.height * 0.5 - spriteHeight * 0.49)
        local hitTint = enemy.hitFlash > 0 and 0.92 or 0.58
        for sx = 0, spriteWidth, columnWidth do
            local drawX = left + sx
            if drawX >= 0 and drawX < self.width then
                local rayIndex = self:clamp(math.floor(drawX / columnWidth) + 1, 1, rayCount)
                if distance <= depthBuffer[rayIndex] + 0.02 then
                    local ratio = spriteWidth > 0 and sx / math.max(1, spriteWidth) or 0
                    local centerBias = math.abs(ratio - 0.5) * 2
                    local bodyTop = top + math.floor(spriteHeight * 0.16)
                    local bodyHeight = math.floor(spriteHeight * 0.66)
                    local headTop = top + math.floor(spriteHeight * 0.06)
                    local eyeTop = top + math.floor(spriteHeight * 0.26)
                    local eyeHeight = math.max(2, math.floor(spriteHeight * 0.07))
                    local armTop = top + math.floor(spriteHeight * 0.35)
                    local armHeight = math.floor(spriteHeight * 0.16)
                    local legTop = top + math.floor(spriteHeight * 0.72)
                    local legHeight = math.floor(spriteHeight * 0.18)
                    local baseGreen = math.max(0.22, hitTint - centerBias * 0.12)
                    local shadow = math.max(0.05, 0.12 - centerBias * 0.05)
                    if centerBias < 0.84 then self:drawClippedRect(drawX, bodyTop, columnWidth + 1, bodyHeight, 1, 0.16, baseGreen, 0.18) end
                    if centerBias < 0.52 then
                        self:drawClippedRect(drawX, headTop, columnWidth + 1, math.floor(spriteHeight * 0.23), 1, 0.18, baseGreen * 0.92, 0.18)
                    elseif centerBias < 0.72 then
                        self:drawClippedRect(drawX, top + math.floor(spriteHeight * 0.12), columnWidth + 1, math.floor(spriteHeight * 0.16), 1, 0.13, baseGreen * 0.78, 0.14)
                    end
                    if ratio > 0.18 and ratio < 0.30 then
                        self:drawClippedRect(drawX, eyeTop, columnWidth + 1, eyeHeight, 1, 0.92, 0.78, 0.20)
                    elseif ratio > 0.70 and ratio < 0.82 then
                        self:drawClippedRect(drawX, eyeTop, columnWidth + 1, eyeHeight, 1, 0.92, 0.78, 0.20)
                    elseif ratio > 0.28 and ratio < 0.72 then
                        self:drawClippedRect(drawX, top + math.floor(spriteHeight * 0.45), columnWidth + 1, math.max(2, math.floor(spriteHeight * 0.05)), 1, 0.06, 0.10, 0.08)
                    end
                    if ratio < 0.18 or ratio > 0.82 then self:drawClippedRect(drawX, armTop, columnWidth + 1, armHeight, 1, 0.12, baseGreen * 0.70, 0.12) end
                    if ratio > 0.18 and ratio < 0.34 then
                        self:drawClippedRect(drawX, legTop, columnWidth + 1, legHeight, 1, shadow, shadow * 1.2, shadow)
                    elseif ratio > 0.66 and ratio < 0.82 then
                        self:drawClippedRect(drawX, legTop, columnWidth + 1, legHeight, 1, shadow, shadow * 1.2, shadow)
                    end
                end
            end
        end
    end
end

function PZOutbreakOpsGame:drawWorldObject(screenCenter, horizon, size, kind)
    local left = math.floor(screenCenter - size * 0.5)
    local top = math.floor(horizon + 26 - size)
    if kind == "exit" then
        self:drawClippedRect(left, top, size, size, 0.92, 0.04, 0.16, 0.07)
        self:drawClippedRect(left + size * 0.14, top + size * 0.12, size * 0.72, size * 0.70, 1, 0.12, 0.54, 0.20)
        self:drawClippedRect(left + size * 0.27, top + size * 0.25, size * 0.46, size * 0.42, 1, 0.60, 0.92, 0.36)
        self:drawClippedRect(left + size * 0.40, top + size * 0.76, size * 0.20, size * 0.12, 1, 0.72, 0.88, 0.46)
    elseif kind == "objective" then
        self:drawClippedRect(left, top + size * 0.30, size, size * 0.52, 1, 0.28, 0.25, 0.12)
        self:drawClippedRect(left + size * 0.08, top + size * 0.18, size * 0.84, size * 0.22, 1, 0.72, 0.60, 0.24)
        self:drawClippedRect(left + size * 0.18, top + size * 0.42, size * 0.64, size * 0.12, 1, 0.90, 0.78, 0.32)
        self:drawClippedRect(left + size * 0.44, top, size * 0.12, size * 0.25, 1, 0.80, 0.86, 0.58)
    elseif kind == "ammo" then
        self:drawClippedRect(left + size * 0.18, top + size * 0.32, size * 0.64, size * 0.40, 1, 0.26, 0.28, 0.20)
        self:drawClippedRect(left + size * 0.24, top + size * 0.38, size * 0.52, size * 0.10, 1, 0.90, 0.72, 0.25)
        self:drawClippedRect(left + size * 0.24, top + size * 0.56, size * 0.52, size * 0.10, 1, 0.90, 0.72, 0.25)
    else
        self:drawClippedRect(left + size * 0.18, top + size * 0.18, size * 0.64, size * 0.64, 1, 0.82, 0.82, 0.74)
        self:drawClippedRect(left + size * 0.43, top + size * 0.24, size * 0.14, size * 0.52, 1, 0.62, 0.14, 0.12)
        self:drawClippedRect(left + size * 0.24, top + size * 0.43, size * 0.52, size * 0.14, 1, 0.62, 0.14, 0.12)
    end
end

function PZOutbreakOpsGame:drawObjects(depthBuffer, rayCount, columnWidth)
    local sprites = {}
    for i = 1, #self.objectives do
        local obj = self.objectives[i]
        if not obj.secured then table.insert(sprites, {x = obj.x, y = obj.y, kind = "objective", scale = 0.27}) end
    end
    for i = 1, #self.pickups do
        local item = self.pickups[i]
        if not item.used then table.insert(sprites, {x = item.x, y = item.y, kind = item.kind, scale = 0.22}) end
    end
    if self:objectivesComplete() then table.insert(sprites, {x = 13.5, y = 14.5, kind = "exit", scale = 0.34}) end
    for i = 1, #sprites do
        local sprite = sprites[i]
        local distance, angle, correctedDistance = self:projectPoint(sprite.x, sprite.y)
        sprite.distance = distance
        sprite.angle = angle
        sprite.correctedDistance = correctedDistance
    end
    table.sort(sprites, function(a, b) return a.distance > b.distance end)
    for i = 1, #sprites do
        local sprite = sprites[i]
        if sprite.correctedDistance > 0.12 and math.abs(sprite.angle) < self.fieldOfView * 0.52 and not self:lineBlocked(self.player.x, self.player.y, sprite.x, sprite.y) then
            local screenCenter = (0.5 + sprite.angle / self.fieldOfView) * self.width
            local rayIndex = self:clamp(math.floor(screenCenter / columnWidth) + 1, 1, rayCount)
            if sprite.correctedDistance <= depthBuffer[rayIndex] + 0.02 then
                local size = math.floor(self.height / math.max(sprite.correctedDistance, 0.3) * sprite.scale)
                size = clampOps(size, 7, math.floor(self.height * 0.32))
                self:drawWorldObject(screenCenter, self.height * 0.5, size, sprite.kind)
            end
        end
    end
end

function PZOutbreakOpsGame:drawObjectiveBanner()
    local complete = self:getSecuredObjectives()
    local text = opsText("Objectives", "OBJ") .. " " .. tostring(complete) .. "/" .. tostring(#self.objectives) .. "  " .. self.hint
    local r, g, b = 0.72, 0.92, 0.60
    if self:objectivesComplete() then
        text = opsText("ExitOpen", "EXIT OPEN")
        r, g, b = 0.38, 0.95, 0.48
    end
    self:drawText(text, math.max(8, math.floor(self.width * 0.5) - 70), 8, r, g, b, 1, UIFont.Small)
end

function PZOutbreakOpsGame:drawStatusBar()
    local barH = 44
    local y = self.height - barH
    self:drawClippedRect(0, y, self.width, barH, 1, 0.045, 0.058, 0.052)
    self:drawClippedRect(0, y, self.width, 2, 1, 0.34, 0.48, 0.38)
    self:drawClippedRect(0, y + barH - 2, self.width, 2, 1, 0.01, 0.015, 0.012)
    local hp = self:clamp(self.player.health or 0, 0, 100)
    local healthX = 10
    local ammoX = math.max(86, math.floor(self.width * 0.22))
    local objX = math.max(ammoX + 74, math.floor(self.width * 0.43))
    local scoreX = self.width - math.min(112, math.max(82, math.floor(self.width * 0.22)))
    self:drawText(opsText("HP", "HP"), healthX, y + 8, 0.56, 0.74, 0.58, 1, UIFont.Small)
    self:drawText(tostring(hp), healthX + 22, y + 21, 0.84, 0.88, 0.66, 1, UIFont.Medium)
    self:drawClippedRect(healthX + 2, y + 24, 18, 5, 1, 0.18, 0.26, 0.20)
    self:drawClippedRect(healthX + 2, y + 24, math.floor(18 * hp / 100), 5, 1, 0.52, 0.86, 0.46)
    self:drawText(opsText("Ammo", "AMMO"), ammoX, y + 8, 0.56, 0.74, 0.58, 1, UIFont.Small)
    self:drawText(tostring(self.ammo), ammoX + 8, y + 22, 0.88, 0.78, 0.42, 1, UIFont.Medium)
    self:drawText(opsText("Cache", "CACHE"), objX, y + 8, 0.56, 0.74, 0.58, 1, UIFont.Small)
    self:drawText(tostring(self:getSecuredObjectives()) .. "/" .. tostring(#self.objectives), objX + 8, y + 22, 0.80, 0.90, 0.62, 1, UIFont.Medium)
    self:drawText(opsText("Score", "SCORE"), scoreX, y + 8, 0.56, 0.74, 0.58, 1, UIFont.Small)
    self:drawText(tostring(self.score), scoreX + 4, y + 22, 0.82, 0.86, 0.62, 1, UIFont.Medium)
end

function PZOutbreakOpsGame:drawTerminalOverlay(title, detail, r, g, b)
    local boxW = math.min(self.width - 44, 236)
    local boxH = 96
    local boxX = math.floor((self.width - boxW) / 2)
    local boxY = math.floor((self.height - boxH) / 2)
    self:drawClippedRect(boxX - 2, boxY - 2, boxW + 4, boxH + 4, 1, 0.012, 0.018, 0.014)
    self:drawClippedRect(boxX, boxY, boxW, boxH, 0.97, 0.020, 0.032, 0.026)
    self:drawClippedRect(boxX + 5, boxY + 5, boxW - 10, 1, 1, 0.30, 0.48, 0.34)
    self:drawText(opsText("Executable", "OUTBREAK.EXE"), boxX + 10, boxY + 17, 0.62, 0.84, 0.60, 1, UIFont.Small)
    self:drawText(title, boxX + 10, boxY + 38, r, g, b, 1, UIFont.Small)
    self:drawText(detail, boxX + 10, boxY + 56, 0.80, 0.78, 0.58, 1, UIFont.Small)
    self:drawText(opsText("Restart", "ACTION/SECONDARY: RESTART"), boxX + 10, boxY + 76, 0.58, 0.76, 0.56, 1, UIFont.Small)
end

function PZOutbreakOpsGame:drawScreenOverlay()
    local y = 0
    while y < self.height do
        self:drawClippedRect(0, y, self.width, 1, 0.045, 0, 0, 0)
        y = y + 4
    end
    self:drawClippedRect(0, 0, self.width, 5, 0.18, 0, 0, 0)
    self:drawClippedRect(0, self.height - 5, self.width, 5, 0.18, 0, 0, 0)
end

function PZOutbreakOpsGame:prerender()
    self:drawClippedRect(0, 0, self.width, self.height, 1, 0.006, 0.010, 0.008)
    self:drawClippedRect(0, 0, self.width, math.floor(self.height * 0.52), 1, 0.030, 0.070, 0.060)
    self:drawClippedRect(0, math.floor(self.height * 0.52), self.width, self.height, 1, 0.035, 0.044, 0.040)
    local rayCount = math.max(112, math.floor(self.width / 3))
    local columnWidth = self.width / rayCount
    local depthBuffer = {}
    local horizon = self.height * 0.5
    for ray = 1, rayCount do
        local ratio = (ray - 1) / math.max(1, rayCount - 1)
        local angle = self.player.angle - self.fieldOfView * 0.5 + self.fieldOfView * ratio
        local distance, shade = self:castRay(angle)
        local corrected = math.max(0.08, distance * math.cos(angle - self.player.angle))
        local wallHeight = math.floor(self.height / corrected * 0.76)
        local top = math.floor(horizon - wallHeight * 0.5)
        local drawX = math.floor((ray - 1) * columnWidth)
        local falloff = math.max(0.10, 1 - corrected / (self.maxDepth + 2))
        local color = math.max(0.07, shade * falloff)
        self:drawClippedRect(drawX, top, math.ceil(columnWidth) + 1, wallHeight, 1, color * 0.38, color * 0.52, color * 0.44)
        self:drawClippedRect(drawX, top, math.ceil(columnWidth) + 1, 2, 0.28, 0.74, 0.86, 0.58)
        self:drawClippedRect(drawX, top + wallHeight, math.ceil(columnWidth) + 1, self.height - (top + wallHeight), 0.075, 0, 0, 0)
        depthBuffer[ray] = corrected
    end
    self:drawObjects(depthBuffer, rayCount, math.max(2, math.ceil(columnWidth)))
    self:drawEnemies(depthBuffer, rayCount, math.max(2, math.ceil(columnWidth)))
    local crossX = math.floor(self.width * 0.5)
    local crossY = math.floor(horizon)
    self:drawClippedRect(crossX - 1, crossY - 8, 2, 16, 0.88, 0.76, 0.92, 0.70)
    self:drawClippedRect(crossX - 8, crossY - 1, 16, 2, 0.88, 0.76, 0.92, 0.70)
    self:drawWeapon()
    self:drawMinimap()
    self:drawStatusBar()
    self:drawObjectiveBanner()
    if self.damageFlash > 0 then
        self:drawClippedRect(0, 0, self.width, self.height, 0.08 * self.damageFlash, 0.90, 0.04, 0.02)
    end
    if self.gameState == "WIN" then
        self:drawTerminalOverlay(opsText("ExtractionComplete", "EXTRACTION COMPLETE"), opsText("Score", "SCORE") .. " " .. tostring(self.score), 0.48, 0.92, 0.48)
    elseif self.gameState == "GAMEOVER" then
        self:drawTerminalOverlay(opsText("TeamSignalLost", "TEAM SIGNAL LOST"), opsText("Best", "BEST") .. " " .. tostring(math.max(self.highscore, self.score)), 0.92, 0.36, 0.28)
    end
    self:drawScreenOverlay()
end

function PZOutbreakOpsGame:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

return PZOutbreakOpsGame
end)()
-- END INSTALLED SOURCE client\ComputerMod_eLuaOutbreakOps.lua

local function sourceActive(mod)return SAO.SourceIntegration and SAO.SourceIntegration.available(mod)and not isClient()and not isServer()end
local function clawSource()
    if not sourceActive("ProjectArcade") then return nil,nil end
    if not rawget(_G,"ProjectArcade_ClawMachine") then pcall(require,"ProjectArcade_ClawMachine") end
    if not rawget(_G,"ProjectArcade_ClawTimedAction") then pcall(require,"TimedActions/ProjectArcade_ClawTimedAction") end
    local machine=rawget(_G,"ProjectArcade_ClawMachine")
    local action=rawget(_G,"ProjectArcade_ClawTimedAction")
    if type(machine)~="table" or type(machine.isMachine)~="function"
        or type(machine.front)~="function" or type(machine.power)~="function"
        or type(action)~="table" or type(action.new)~="function" then return nil,nil end
    return machine,action
end
local ClawMachine,ClawCore=clawSource()
local function knowledge(id,concept)
    local K=SAO.ConceptKnowledge
    if not K or not K.infer then return nil end
    for _,key in ipairs({concept,"games","recreation"})do
        local v=K.infer(id,key,"recreation");local p=v and v.actorId==id and v.paths and v.paths[1]
        if p and p.status=="expectation"and type(p.id)=="string"and type(p.evidenceIds)=="table"and #p.evidenceIds>0 then
            return {concept=key,id=p.id,evidenceIds=plain(p.evidenceIds),modal=true}
        end
    end
end
local function permission(id,obj)return SAO.Standing and SAO.Standing.mayEnterCurrent and SAO.Standing.mayEnterCurrent(id,obj:getX(),obj:getY())==true end
local function lease(obj)return obj:getModData().SAONpcGameLease end
local function available(id,obj)
    local l=lease(obj);return permission(id,obj)and(l==nil or l.actorId==id and runtime[id]and l.workId==runtime[id].work.workId)
end
local function near(body,obj)
    return body:getSquare()and obj:getSquare()and body:getZ()==obj:getZ()
        and math.abs(body:getX()-obj:getX())<=2.6 and math.abs(body:getY()-obj:getY())<=2.6
end
local PAIRS={LS_Recreation_0={"LS_Recreation_1","E","W"},LS_Recreation_1={"LS_Recreation_0","W","E"},
    LS_Recreation_2={"LS_Recreation_3","S","N"},LS_Recreation_3={"LS_Recreation_2","N","S"}}
local function pingKind(obj)
    local p=obj:getSprite():getProperties()
    return p:has("CustomName")and p:get("CustomName")=="Table"and p:has("GroupName")and p:get("GroupName")=="Ping Pong"
        and PAIRS[obj:getSprite():getName()]~=nil
end
local function pingFront(obj)
    local p=PAIRS[obj:getSprite():getName()]
    return p and obj:getSquare():getAdjacentSquare(IsoDirections[p[3]])
end
local function pingPair(obj,observed)
    local pair=PAIRS[obj:getSprite():getName()]
    if not pair then return nil end
    local square=obj:getSquare():getAdjacentSquare(IsoDirections[pair[2]])
    for _,v in ipairs(observed)do
        if v.object:getSquare()==square and v.object:getSprite():getName()==pair[1]and pingKind(v.object)then return v end
    end
end
local function computer(obj)
    local C=ComputerModComputerTypes
    if not sourceActive("ComputerModkum")or not C or not C.getData or not C.isComputer or not C.isComputer(obj)
        or not ComputerModPower or not ComputerModPower.hasComputerPower
        or not ComputerModComponents or not ComputerModComponents.getBootFailure then return nil end
    local d=C.getData(obj)
    -- The source's player initialization/credential owner remains authoritative.
    if not d or d.ComputerModMetaInitialized~=true or d.ComputerModOSInstalled==false or d.ComputerModPowerOn~=true
        or d.ComputerModPasswordEnabled==true or d.ComputerModNetworkTerminal==true
        or type(d.ComputerModMachineID)~="string"or type(d.ComputerModInstalledGames)~="table"
        or ComputerModComponents.getBootFailure(d)~=nil or not ComputerModPower.hasComputerPower(obj)then return nil end
    return d
end
local function arcadeConfig()
    local installed=rawget(_G,"ProjectArcade_Currency")
    local c=installed and installed.Config or ProjectArcade_Currency.Config
    if not c or not finite(c.Cost)or c.Cost<0 or c.Cost~=math.floor(c.Cost)or c.Cost>100
        or type(c.CurrencyFullType)~="string"or c.CurrencyFullType==""or not getScriptManager then return nil end
    local definition=getScriptManager():getItem(c.CurrencyFullType)
    return definition and definition:getFullName()==c.CurrencyFullType and plain(c)or nil
end
local function arcadeCount(body,c)
    local inv=body:getInventory();return inv and inv:getCountTypeRecurse(c.CurrencyFullType)or 0
end
local ArcadeTypes={"ArcadeMachine1","ArcadeMachine2","ArcadeStreetFighter","ArcadePacman",
    "ArcadeDoubleDragon","ArcadeSpaceInvaders","ArcadeDonkeyKong","ArcadeCentipede","ArcadeDigDug",
    "ArcadeNBAJam","ArcadeTMNT","ArcadeMK","ComplexTerminator2","ComplexStarWars","PinballMachine",
    "PinballAddamsFamily","PinballTwilightZone","PinballIndianaJones","PinballBlackKnight2000",
    "PinballFunHouse","PinballElviraPartyMonsters","PinballMarioBros"}
function G.materialRequirementsForType(_,itemType)
    local c=sourceActive("ProjectArcade")and arcadeConfig()
    if not c or c.DebugFreePlay==true or c.Cost<1 or itemType~=c.CurrencyFullType then return {}end
    local rows={}
    for _,machine in ipairs(ArcadeTypes)do
        rows[#rows+1]={owner="SAO.LeisureGames",family="games",activity="arcade-"..machine,
            sourceId="ProjectArcade:ProjectArcade_PlayArcadeTimedAction:"..machine,revision=ArcadeRevision,
            requirementId="arcade-currency:"..machine,itemType=itemType,role="material"}
    end
    if ClawMachine and ClawCore then
        rows[#rows+1]={owner="SAO.LeisureGames",family="games",activity="claw-machine",
            sourceId="ProjectArcade:ProjectArcade_ClawTimedAction",revision=ClawRevision,
            requirementId="claw-currency",itemType=itemType,role="material"}
    end
    return rows
end
local function arcadeCarried(body,c)
    local materials={};local items=SAOJavaBridge and SAOJavaBridge:privateCarriedItems(body)
    for i=0,(items and items:size()or 0)-1 do
        local item=items:get(i)
        if item and item:getFullType()==c.CurrencyFullType then
            materials[#materials+1]={id=tostring(item:getID()),itemType=c.CurrencyFullType}
        end
    end
    return materials
end
local function held(body,item)
    local rows=SAOJavaBridge and SAOJavaBridge:privateCarriedItems(body)
    if not rows then return false end
    for i=0,rows:size()-1 do if rows:get(i)==item then return true end end;return false
end
local function tabletopSource(id,body,item,kind)
    if isClient()or isServer()or not held(body,item)or not SAOJavaBridge.nativeTabletopAffordance then return nil end
    local d=SAOJavaBridge:nativeTabletopAffordance(body,item,kind)
    if type(d)~="table"or d.schema~="sao.native-tabletop-affordance/1"or d.actorId~=id or d.kind~=kind
        or d.itemId~=item:getID()or d.itemType~=item:getFullType()or not finite(d.time)or d.time<=0
        or d.revision~="a28157ee4cfe60d2117060bf016cb54462603279c54a069638ae0a0d1ae76adc"
        or d.sourceId~=(kind=="draw-card"and "native:RecipeCodeOnCreate.drawRandomCard"or "native:RecipeCodeOnCreate.rollDice")
        or type(d.actionAnim)~="string"or type(d.canWalk)~="boolean"
        or d.hasMuscleStrain~=false then return nil end
    return d
end
local function tabletopMetadata(d)
    local row=plain(d);row.metabolicsName=d.metabolics and tostring(d.metabolics)or nil;return row
end
local function observed(id,body)
    local out={};local P=SAO.Perception
    if not P or not P.leisureObjects or not P.resolveLeisureObject then return out end
    local tick=SAO.History.ticks()
    for _,row in ipairs(P.leisureObjects(id,body))do
        if row.actorId==id and row.kind=="object"and row.source=="native-personal-visibility"
            and(row.concept=="ping-pong"or row.concept=="computer"or row.concept=="arcade-machine"or row.concept=="claw-machine")and finite(row.at)and row.at<=tick and tick-row.at<=120
            and type(row.runtimeInstance)=="string"and type(row.key)=="string"and type(row.spriteName)=="string"then
            local object=P.resolveLeisureObject(id,body,row.key)
            if object and object:getSprite():getName()==row.spriteName and available(id,object)then out[#out+1]={row=row,object=object}end
        end
    end;return out
end
function G.materialRequirementAvailable(id,body,row)
    if not live(id,body)or not SAO.Needs.workAvailable(body)or type(row)~="table"
        or row.owner~="SAO.LeisureGames"or row.role~="material"
        or not knowledge(id,row.activity=="claw-machine" and "claw-machine" or "arcade-machine")then return false end
    local c=sourceActive("ProjectArcade")and arcadeConfig()
    if not c or c.DebugFreePlay==true or c.Cost<1 or arcadeCount(body,c)>=c.Cost then return false end
    local canonical=false
    for _,candidate in ipairs(G.materialRequirementsForType(nil,row.itemType))do
        if same(candidate,row)then canonical=true;break end
    end
    if not canonical then return false end
    for _,v in ipairs(observed(id,body))do
        if row.activity=="claw-machine" and v.row.concept=="claw-machine" and ClawMachine and ClawCore then
            local obj=v.object
            if ClawMachine.isMachine(obj) and ClawMachine.front(obj) and ClawMachine.power(obj) then return true end
        elseif v.row.concept=="arcade-machine"then
            local obj=v.object;local sprite=obj:getSprite():getName()
            local machine=ArcadeSource.machineType(sprite)
            if row.activity=="arcade-"..tostring(machine)and ArcadeSource.front(obj:getSquare(),sprite,machine)
                and ArcadeSource.power(obj)then return true end
        end
    end
    return false
end
local function offers(id,body)
    if not live(id,body)then return {}end
    local out={};local visible=observed(id,body)
    local carried=SAOJavaBridge and SAOJavaBridge:privateCarriedItems(body)
    for i=0,(carried and carried:size()or 0)-1 do
        local item=carried:get(i)
        for _,kind in ipairs({"draw-card","roll-dice"})do
            local d=tabletopSource(id,body,item,kind);local reason=d and knowledge(id,kind)
            if reason then out[#out+1]={id="games:"..kind..":"..item:getID(),actorId=id,family="games",activity=kind,
                sourceId=d.sourceId,revision=d.revision,itemKey="item:"..item:getFullType()..":"..item:getID(),itemId=item:getID(),itemType=item:getFullType(),
                tabletopKind=kind,sourceAction=tabletopMetadata(d),evidence=reason,afterSequence=rec(id).gamesSequence or 0,
                targetX=body:getX(),targetY=body:getY(),targetZ=body:getZ(),requiresPreparation={frontSquare=false},
                revisionAuthority="loaded native RecipeCodeOnCreate.class sealed by source owner"}end
        end
    end
    for _,v in ipairs(visible)do
        local obj=v.object
        local function add(activity,source,revision,reason,extra)
            local row={id="games:"..activity..":"..v.row.key,actorId=id,family="games",activity=activity,sourceId=source,revision=revision,
                objectKey=v.row.key,runtimeInstance=v.row.runtimeInstance,objectIndex=v.row.objectIndex,spriteName=v.row.spriteName,
                x=obj:getX(),y=obj:getY(),z=obj:getZ(),evidence=reason,afterSequence=rec(id).gamesSequence or 0,
                revisionAuthority="audited-source; loaded-byte-seal-unavailable"}
            for k,value in pairs(extra or {})do row[k]=plain(value)end;out[#out+1]=row
        end
        if v.row.concept=="computer"then
            local d=computer(obj);local reason=knowledge(id,"computer-game")
            -- No installed software is exposed remotely through the scene owner.
            if d and reason and near(body,obj)then
                for _,gameId in ipairs(d.ComputerModInstalledGames)do
                    local def=Definitions[gameId]
                    if def then add("computer-"..gameId,"ComputerModkum:"..def.className,def.revision,reason,
                        {gameId=gameId,machineId=d.ComputerModMachineID,targetX=body:getX(),targetY=body:getY(),targetZ=body:getZ(),
                            requiresPreparation={frontSquare=false}})end
                end
            end
        elseif v.row.concept=="claw-machine"and ClawMachine and ClawCore then
            local front=ClawMachine.isMachine(obj) and ClawMachine.front(obj)
            local c=arcadeConfig();local reason=knowledge(id,"claw-machine")
            if front and c and reason and ClawMachine.power(obj)
                and(c.DebugFreePlay==true or arcadeCount(body,c)>=c.Cost)then
                add("claw-machine","ProjectArcade:ProjectArcade_ClawTimedAction",ClawRevision,reason,
                    {clawMachine=true,currencyType=c.CurrencyFullType,cost=c.Cost,debugFreePlay=c.DebugFreePlay==true,
                        materials=arcadeCarried(body,c),targetX=front:getX(),targetY=front:getY(),targetZ=front:getZ(),
                        requiresPreparation={frontSquare=body:getCurrentSquare()~=front}})
            end
        elseif v.row.concept=="arcade-machine"and sourceActive("ProjectArcade")then
            local name=obj:getSprite():getName();local machine=ArcadeSource.machineType(name)
            local front=machine and ArcadeSource.front(obj:getSquare(),name,machine)
            local c=arcadeConfig();local reason=knowledge(id,"arcade-machine")
            if front and c and reason and ArcadeSource.power(obj)and(c.DebugFreePlay==true or arcadeCount(body,c)>=c.Cost)then
                add("arcade-"..machine,"ProjectArcade:ProjectArcade_PlayArcadeTimedAction:"..machine,ArcadeRevision,reason,
                    {arcadeType=machine,currencyType=c.CurrencyFullType,cost=c.Cost,debugFreePlay=c.DebugFreePlay==true,
                        materials=arcadeCarried(body,c),
                        targetX=front:getX(),targetY=front:getY(),targetZ=front:getZ(),requiresPreparation={frontSquare=body:getCurrentSquare()~=front}})
            end
        elseif v.row.concept=="ping-pong"and sourceActive("LifestyleHobbies")and pingKind(obj)then
            local reason=knowledge(id,"ping-pong");local partner=pingPair(obj,visible);local front=pingFront(obj)
            local d=obj:getModData().movableData;local p=partner and partner.object:getModData().movableData
            if reason and partner and front and d and p and d.fakeRival==true and p.fakeRival==true and not d.inUse and not p.inUse then
                add("ping-pong-fake-rival","LifestyleHobbies:LSPingPong/fakeRival",PingRevision,reason,
                    {opponentKey=partner.row.key,opponentInstance=partner.row.runtimeInstance,targetX=front:getX(),targetY=front:getY(),targetZ=front:getZ(),
                        requiresPreparation={frontSquare=body:getCurrentSquare()~=front}})
            end
        end
    end;return out
end
function G.offers(id,body)local ok,result=pcall(offers,id,body);if not ok then return {},"game-source-opportunity-unavailable"end;return result end
G.intentOffers=G.offers
function G.work(id)return rec(id)and plain(rec(id).gamesWork)end
function G.outcome(id,sequence)
    for _,r in ipairs(rec(id)and rec(id).gamesOutcomes or {})do if r.actorId==id and r.sequence==sequence then return plain(r)end end
end
owned=function(a)
    local w=a.work;return runtime[w.actorId]==a and rec(w.actorId).gamesWork==w and live(w.actorId,a.body)
        and a.body:getModData().SAOExternalToken==w.bodyToken and hours()>=w.admittedAtHours
end
usable=function(a)
    if not owned(a)then return false end
    local P=SAO.ProceduralPlanning;local admission=P and P.hobbyAdmission and P.hobbyAdmission(a.work.actorId,a.work.purposeId,a.work.workId)
    if not admission or admission.ownerName~="SAO.LeisureGames"or admission.actorId~=a.work.actorId
        or admission.sequence~=a.work.sequence or admission.sourceId~=a.work.sourceId or admission.bodyToken~=a.work.bodyToken then return false end
    if a.tabletopKind then
        local d=tabletopSource(a.work.actorId,a.body,a.item,a.tabletopKind)
        return d and same(tabletopMetadata(d),a.work.sourceAction)
    end
    if not permission(a.work.actorId,a.object)
        or SAO.Perception.resolveLeisureObject(a.work.actorId,a.body,a.work.objectKey)~=a.object then return false end
    local l=lease(a.object)
    if not l or l.actorId~=a.work.actorId or l.workId~=a.work.workId then return false end
    if a.clawMachine then
        local c=arcadeConfig()
        return sourceActive("ProjectArcade") and ClawMachine and ClawCore
            and ClawMachine.isMachine(a.object) and ClawMachine.power(a.object)
            and a.body:getCurrentSquare()==ClawMachine.front(a.object)
            and c and c.Cost==a.cost and c.CurrencyFullType==a.currencyType
            and(c.DebugFreePlay==true)==a.debugFreePlay
    end
    if a.arcadeType then
        local name=a.object:getSprite():getName();local c=arcadeConfig()
        return sourceActive("ProjectArcade")and ArcadeSource.machineType(name)==a.arcadeType and ArcadeSource.power(a.object)
            and a.body:getCurrentSquare()==ArcadeSource.front(a.object:getSquare(),name,a.arcadeType)
            and c and c.Cost==a.cost and c.CurrencyFullType==a.currencyType and(c.DebugFreePlay==true)==a.debugFreePlay
    end
    if a.scene then
        local data=computer(a.object);local installed=false
        for _,gameId in ipairs(data and data.ComputerModInstalledGames or {})do if gameId==a.gameId then installed=true;break end end
        return data and installed and data.ComputerModMachineID==a.work.machineId and near(a.body,a.object)
    end
    local p=a.opponent and lease(a.opponent)
    local d=a.object:getModData().movableData;local other=a.opponent and a.opponent:getModData().movableData
    return sourceActive("LifestyleHobbies")and p and p.actorId==a.work.actorId and p.workId==a.work.workId
        and permission(a.work.actorId,a.opponent)
        and SAO.Perception.resolveLeisureObject(a.work.actorId,a.body,a.work.opponentKey)==a.opponent
        and d and d.fakeRival==true and d.inUse==true and other and other.fakeRival==true
        and a.body:getCurrentSquare()==pingFront(a.object)
end
local function resumeKey(w)return w.sourceId.."/"..w.objectKey.."/"..tostring(w.machineId or w.opponentKey)end
local function saveResume(a,row)
    local r=rec(a.work.actorId);local state=r.gamesResume
    if not state or state.schema~=1 then state={schema=1,states={},order={}};r.gamesResume=state end
    local key=resumeKey(a.work)
    if state.states[key]==nil then state.order[#state.order+1]=key end
    state.states[key]=row
    if #state.order>32 then state.states[table.remove(state.order,1)]=nil end
end
local function getResume(r,w)
    return r.gamesResume and r.gamesResume.schema==1 and r.gamesResume.states[resumeKey(w)]
end
snapshot=function(a)
    if a.scene then
        local state=plain(a.scene)
        saveResume(a,{sourceId=a.work.sourceId,revision=a.work.revision,gameId=a.gameId,
            objectKey=a.work.objectKey,machineId=a.work.machineId,state=state,atHours=hours()})
    elseif not a.arcadeType and not a.tabletopKind and a.action and a.action.matchData then
        local state={}
        for _,name in ipairs({"matchData","matchArgs","pointIdx","volleyIdx","volleyTimer","bounceSoundPlayed","resting",
            "restEndTimestamp","restFinalize","anticipating","anticipationEndTimestamp"})do state[name]=plain(a.action[name])end
        saveResume(a,{sourceId=a.work.sourceId,revision=a.work.revision,objectKey=a.work.objectKey,
            opponentKey=a.work.opponentKey,state=state,atHours=hours()})
    end
end
render=function(a)
    a.drawCount,a.drawOmitted,a.drawCommands=0,0,{}
    current=a;a.scene:prerender();current=nil
    a.frameId=(a.frameId or 0)+1
    a.work.nativeProgress.frameId=a.frameId
    local labels={};for _,key in ipairs(Definitions[a.gameId].keys)do labels[key]=ComputerModGameInput.getInputLabel(a.scene,key)end
    a.context={actorId=a.work.actorId,workSequence=a.work.sequence,workId=a.work.workId,sourceId=a.work.sourceId,revision=a.work.revision,
        frameId=a.frameId,atHours=hours(),viewport={width=a.scene.width,height=a.scene.height},
        commands=plain(a.drawCommands),labels=labels,omittedCommands=a.drawOmitted,status="presented-source-scene"}
end
function G.context(id,body)
    local a=runtime[id];return a and a.scene and a.started and a.body==body and usable(a)and plain(a.context)or nil
end
function G.controlPresentation(id,body)
    local c=G.context(id,body);if not c then return nil end
    c.commands,c.omittedCommands,c.viewport=nil,nil,nil;return c
end
function G.inputOffers(id,body)
    local a=runtime[id];if not a or not a.scene or not a.started or a.body~=body or not usable(a)or not a.context then return {}end
    local out={};local keys=Definitions[a.gameId].keys
    local function add(values)
        out[#out+1]={id="game-input:"..table.concat(values,"+")..":"..a.frameId,actorId=id,workSequence=a.work.sequence,
            workId=a.work.workId,frameId=a.frameId,sourceId=a.work.sourceId,revision=a.work.revision,keys=plain(values)}
    end
    add({});for i,key in ipairs(keys)do add({key});for j=i+1,#keys do add({key,keys[j]})end end
    return out
end
function G.submitInput(id,body,offer)
    local a=runtime[id];if not a then return false end
    if a.inputFrame==a.frameId then return false end
    for _,v in ipairs(G.inputOffers(id,body))do
        if same(v,offer)then
            a.keys={};for _,key in ipairs(v.keys)do a.keys[key]=true end
            a.inputFrame=a.frameId
            a.work.nativeProgress.inputSelections=a.work.nativeProgress.inputSelections+1
            a.work.nativeProgress.lastInput={frameId=v.frameId,keys=plain(v.keys),atHours=hours()}
            return true
        end
    end;return false
end
local function release(a)
    for _,obj in ipairs({a.object,a.opponent})do
        local l=obj and lease(obj)
        if l and l.actorId==a.work.actorId and l.workId==a.work.workId and l.bodyToken==a.work.bodyToken then
            if a.arcadeType and obj==a.object then ArcadeSource.overlay(obj,false)end
            if not a.scene and not a.arcadeType and not a.clawMachine and obj==a.object and obj:getModData().movableData then obj:getModData().movableData.inUse=false end
            obj:getModData().SAONpcGameLease=nil
        end
    end
end
finish=function(a,status,reason)
    local w=a.work;local r=rec(w.actorId)
    if not r or r.gamesWork~=w or w.status=="completed"or w.status=="interrupted"then return false end
    if status=="interrupted"then snapshot(a)
    elseif r.gamesResume and r.gamesResume.schema==1 then
        local key=resumeKey(w);r.gamesResume.states[key]=nil
        for i,v in ipairs(r.gamesResume.order)do if v==key then table.remove(r.gamesResume.order,i);break end end
    end
    if not a.scene and a.body and a.body:getModData().SAONpcPingBlock==w.workId
        and a.body:getModData().SAOExternalToken==w.bodyToken then
        a.body:setBlockMovement(false);a.body:getModData().SAONpcPingBlock=nil
    end
    w.status,w.reason,w.atHours=status,reason,hours();w.presentationSounds=plain(a.sounds);w.presentationHalos=plain(a.halos)
    if a.scene then w.actualMeasuredAfter=a.after;w.presentedScene=plain(a.context);w.sourceResult={state=a.scene.gameState,
        score=a.scene.score,cpuScore=a.scene.cpuScore,won=a.scene.gameState=="WIN",terminal=a.scene.gameState=="WIN"or a.scene.gameState=="GAMEOVER"}
    elseif a.tabletopKind then
        if status=="completed"then w.sourceResult=plain(a.result)end
    elseif a.clawMachine then
        w.actualMeasuredAfter=a.after or nil
        if status=="completed" then w.sourceResult=plain(a.result) end
    elseif a.arcadeType then
        w.actualMeasuredAfter=a.after or nil
        if status=="completed"then w.sourceResult={state="source-arcade-session-complete",won=a.action.didWin,
            machineType=a.arcadeType,mode="installed-source procedural 60-percent win draw; no interactive board engine"}end
    elseif status=="completed"and a.action and a.action.matchData then
        local match=a.action.matchData;w.sourceResult={state="source-match-complete",winner=match.winner,scoreSource=match.scoreSource,scoreOther=match.scoreOther,
            mode="installed-mechanical-fake-rival; source-generated procedural match"}
    end
    release(a)
    r.gamesOutcomes=r.gamesOutcomes or {};r.gamesOutcomes[#r.gamesOutcomes+1]=plain(w)
    if #r.gamesOutcomes>32 then table.remove(r.gamesOutcomes,1)end
    if a.scene then sceneOwners[a.scene]=nil end
    r.gamesWork=nil;runtime[w.actorId]=nil
    if SAO.ProceduralPlanning and SAO.ProceduralPlanning.consumeHobbyOutcome then SAO.ProceduralPlanning.consumeHobbyOutcome(w.actorId,w.sequence,"SAO.LeisureGames")end
    return true
end
local ComputerAction=ISBaseTimedAction:derive("SAONpcComputerGameAction")
function ComputerAction:isValid()return usable(self.owner)end
function ComputerAction:start()
    local a=self.owner;if not usable(a)then self:forceStop();return end
    a.started=true;a.work.status="active";a.work.atHours=hours();a.work.actualMeasuredBefore=measured(a.body);a.mood=ComputerMood.new(a.body,a.scene);render(a);snapshot(a)
end
function ComputerAction:update()
    local a=self.owner
    if not usable(a)then self:forceStop();return end
    local C=ComputerModComponents;local data=ComputerModComputerTypes.getData(a.object)
    if C.applyWear(data,C.getWorldAgeHours())then C.captureDriveData(data);ComputerModComputerTypes.transmitData(a.object)end
    if not usable(a)then self:forceStop();return end
    current=a;a.scene:update();ComputerMood.update(a.mood);current=nil;a.after=measured(a.body)
    a.work.nativeProgress.sourceUpdates=a.work.nativeProgress.sourceUpdates+1;a.work.atHours=hours()
    render(a)
    snapshot(a)
    if a.scene.gameState=="WIN"or a.scene.gameState=="GAMEOVER"then a.terminal=true;self:forceComplete()end
end
function ComputerAction:perform()
    local a=self.owner
    if not a.performed and usable(a)and a.started and a.terminal and a.work.nativeProgress.sourceUpdates>0 then
        a.performed=true;ISBaseTimedAction.perform(self)
    end
end
function ComputerAction:complete()
    local a=self.owner
    return a.performed and owned(a)and a.terminal and finish(a,"completed")or false
end
function ComputerAction:stop()
    local a=self.owner;if not owned(a)then return end
    ISBaseTimedAction.stop(self);finish(a,"interrupted","computer-game-stopped")
end
function ComputerAction:forceCancel()if owned(self.owner)then self:stop()end end
function ComputerAction:new(a)
    local o={character=a.body,owner=a,maxTime=-1,ignoreDynamicTime=true,stopOnWalk=true,stopOnRun=true,stopOnAim=true}
    setmetatable(o,self);self.__index=self;return o
end
local PingAction=PingCore:derive("SAONpcPingPongAction")
local function pingSnapshot(a)
    local action=a.action;local progress=a.work.nativeProgress
    progress.pointsPlayed=math.max(0,action.pointIdx-1);progress.volley=action.volleyIdx;progress.volleyTime=action.volleyTimer
    progress.shot=plain(a.shot)
    progress.playedPoints={}
    for i=1,math.min(progress.pointsPlayed,#action.matchData.points)do progress.playedPoints[i]=plain(action.matchData.points[i])end
end
function PingAction:isValid()return usable(self.owner)end
function PingAction:waitToStart()
    if not self:isValid()then self:forceStop();return false end
    current=self.owner;local result=PingCore.waitToStart(self);current=nil;return result
end
function PingAction:start()
    local a=self.owner;if not usable(a)then self:forceStop();return end
    a.started=true;a.work.status="active"
    a.body:getModData().SAONpcPingBlock=a.work.workId
    current=a;PingCore.start(self);current=nil;pingSnapshot(a);snapshot(a)
end
function PingAction:update()
    local a=self.owner;if not usable(a)then self:forceStop();return end
    current=a;PingCore.update(self);current=nil
    if not owned(a)then return end
    a.work.nativeProgress.sourceUpdates=a.work.nativeProgress.sourceUpdates+1;pingSnapshot(a);a.work.atHours=hours();snapshot(a)
end
function PingAction:perform()
    local a=self.owner
    if a.performed or not usable(a)or not a.started or self.pointIdx<=#self.matchData.points
        or not self.restFinalize or hours()*3600<self.restEndTimestamp then return end
    a.performed=true;current=a;PingCore.perform(self);current=nil;pingSnapshot(a)
end
function PingAction:complete()
    local a=self.owner
    if not a.performed or not owned(a)then return false end
    return PingCore.complete(self)==true and finish(a,"completed")or false
end
function PingAction:stop()
    local a=self.owner;if not owned(a)then return end
    current=a;PingCore.stop(self);current=nil;pingSnapshot(a);finish(a,"interrupted","ping-pong-stopped")
end
function PingAction:forceCancel()
    local a=self.owner
    if not owned(a)then return end
    if self.action and a.started then self:stop()else
        if a.object:getModData().movableData then a.object:getModData().movableData.inUse=false end
        finish(a,"interrupted","ping-pong-unstarted")
    end
end
measured=function(body)
    local out={};local stats=body:getStats()
    for _,name in ipairs({"BOREDOM","UNHAPPINESS","STRESS"})do
        local stat=CharacterStat and CharacterStat[name];local value=stat and stats:get(stat)
        if finite(value)then out[name]=value end
    end;return out
end
local ArcadeAction=ArcadeSource.class:derive("SAONpcArcadePlayAction")
function ArcadeAction:isValid()return usable(self.owner)and ArcadeSource.class.isValid(self)end
function ArcadeAction:start()
    local a=self.owner;if not usable(a)then self:forceStop();return end
    a.started=true;a.work.status="active";a.work.actualMeasuredBefore=measured(a.body)
    current=a;ArcadeSource.class.start(self);current=nil;a.after=measured(a.body)
end
function ArcadeAction:update()
    local a=self.owner;if not usable(a)then self:forceStop();return end
    current=a;ArcadeSource.class.update(self);current=nil;a.after=measured(a.body)
    a.work.nativeProgress.sourceUpdates=a.work.nativeProgress.sourceUpdates+1
    a.work.nativeProgress.jobDelta=self:getJobDelta();a.work.atHours=hours()
end
function ArcadeAction:perform()
    local a=self.owner
    if a.performed or not usable(a)or not a.started or a.work.nativeProgress.sourceUpdates<1 or self:getJobDelta()<1 then return end
    a.performed=true;current=a;ArcadeSource.class.perform(self);current=nil;a.after=measured(a.body)
end
function ArcadeAction:complete()
    local a=self.owner;return a.performed and owned(a)and finish(a,"completed")or false
end
function ArcadeAction:stop()
    local a=self.owner;if not owned(a)then return end
    current=a;ArcadeSource.class.stop(self);current=nil;a.after=measured(a.body);finish(a,"interrupted","arcade-stopped")
end
function ArcadeAction:forceCancel()
    local a=self.owner;if not owned(a)then return end
    if a.started then self:stop()else ISBaseTimedAction.stop(self);finish(a,"interrupted","arcade-unstarted")end
end
local ClawAction=ClawCore and ClawCore:derive("SAONpcClawAction") or nil
if ClawAction then
    function ClawAction:isValid()return usable(self.owner) and ClawCore.isValid(self) end
    function ClawAction:start()
        local a=self.owner
        if not usable(a) or a.sourcePaid~=true or not a.work.nativeProgress.payment
            or a.work.nativeProgress.payment.sourcePaid~=true then self:forceStop();return end
        a.started=true;a.work.status="active";a.work.actualMeasuredBefore=measured(a.body)
        current=a;ClawCore.start(self);current=nil;a.after=measured(a.body)
        if not self.paid then finish(a,"interrupted","claw-payment-unconfirmed") end
    end
    function ClawAction:update()
        local a=self.owner;if not usable(a) or not a.started or not self.paid then self:forceStop();return end
        current=a;ClawCore.update(self);current=nil;a.after=measured(a.body)
        a.work.nativeProgress.sourceUpdates=a.work.nativeProgress.sourceUpdates+1
        a.work.nativeProgress.jobDelta=self:getJobDelta();a.work.atHours=hours()
    end
    function ClawAction:perform()
        local a=self.owner
        if a.performed or not usable(a) or not a.started or not self.paid
            or a.work.nativeProgress.sourceUpdates<1 or self:getJobDelta()<1 then return end
        a.performed=true
        current=a;local ok=pcall(ClawCore.perform,self);current=nil;a.after=measured(a.body)
        if not ok then finish(a,"interrupted","claw-source-perform-unavailable");return end
        local r=self.saoPrizeResult
        if type(r)~="table" or r.schema~="sao.source-claw-result/1" or r.state=="server-pending"
            or r.state=="unpaid" then finish(a,"interrupted","claw-source-result-unavailable");return end
        local custody="none"
        if r.state=="awarded" then
            custody="unconfirmed"
            local rows=SAOJavaBridge:privateCarriedItems(a.body)
            for i=0,(rows and rows:size() or 0)-1 do
                local item=rows:get(i)
                if item and item:getID()==r.itemId and item:getFullType()==r.itemType then custody="held";break end
            end
        end
        a.result={state="source-claw-complete",prizeState=r.state,custody=custody,
            prizeType=r.prizeType,itemType=r.itemType,itemId=r.itemId,sourceRevision=ClawRevision}
        a.work.nativeProgress.sourcePrize=plain(a.result)
    end
    function ClawAction:complete()
        local a=self.owner
        return a.performed and owned(a) and a.result and finish(a,"completed") or false
    end
    function ClawAction:stop()
        local a=self.owner;if not owned(a) then return end
        current=a;ClawCore.stop(self);current=nil;a.after=measured(a.body)
        finish(a,"interrupted","claw-stopped")
    end
    function ClawAction:forceCancel()
        local a=self.owner;if not owned(a) then return end
        if a.started then self:stop() else ISBaseTimedAction.stop(self);finish(a,"interrupted","claw-unstarted") end
    end
end
local ArcadePayment=ProjectArcade_Currency.CheckAndQueueAction:derive("SAONpcArcadePayment")
function ArcadePayment:isValid()return usable(self.owner)end
function ArcadePayment:start()
    local a=self.owner;if not usable(a)then self:forceStop();return end
    a.work.status="active";a.work.nativeProgress.paymentStarted=true
end
function ArcadePayment:perform()
    local a=self.owner;if a.paymentPerformed or not usable(a)or not self.action then return end
    a.paymentPerformed=true;local before=arcadeCount(a.body,{CurrencyFullType=a.currencyType})
    current=a;ProjectArcade_Currency.CheckAndQueueAction.perform(self);current=nil
    local after=arcadeCount(a.body,{CurrencyFullType=a.currencyType})
    a.work.nativeProgress.payment={sourcePaid=a.sourcePaid==true,beforeCount=before,afterCount=after,cost=a.cost,
        currencyType=a.currencyType,debugFreePlay=a.debugFreePlay}
    if not a.sourcePaid then finish(a,"interrupted","source-arcade-currency-refused");return end
    if a.clawMachine then
        a.action=ClawAction:new(a.body,a.object,a.cost,a.currencyType,a.debugFreePlay)
        a.action.saoPaymentReceipt={confirmed=true,character=a.body,machine=a.object,
            actorId=a.work.actorId,workId=a.work.workId,bodyToken=a.work.bodyToken,
            cost=a.cost,currencyType=a.currencyType}
    else
        a.action=ArcadeAction:new(a.body,a.object,2000,a.cost,a.currencyType,a.debugFreePlay)
    end
    a.action.owner=a
    if not SAO.Needs.queueVerified(a.action)then finish(a,"interrupted","source-arcade-play-queue-refused")end
end
function ArcadePayment:complete()return self.owner.paymentPerformed==true end
function ArcadePayment:stop()
    if not owned(self.owner)or self.owner.action~=self then return end
    ISBaseTimedAction.stop(self);finish(self.owner,"interrupted","arcade-payment-stopped")
end
function ArcadePayment:forceCancel()self:stop()end
-- Source-specific ISHandcraftAction core: keep-input-only native recipes.
-- Native Java OnCreate mechanics return privately instead of player-slot Halo.
local TabletopAction=ISBaseTimedAction:derive("SAONpcTabletopAction")
function TabletopAction:isValid()return usable(self.owner)end
function TabletopAction:start()
    local a=self.owner;if not usable(a)or a.action~=self or not self.action then self:forceStop();return end
    if a.started or not instanceof(self.action,"LuaTimedActionNew")or self.action:getTable()~=self then return end
    a.nativeAction=self.action
    local d=a.descriptor;a.started=true;a.work.status="active"
    a.item:setJobDelta(0);a.item:setJobType(d.translationName)
    if d.cantSit and a.body:isSitOnGround()then a.body:setSitOnGround(false)end
    self:setOverrideHandModels(d.prop1,d.prop2);self:setActionAnim(d.actionAnim)
    if d.animVarKey then self:setAnimVariable(d.animVarKey,d.animVarVal)end
    if d.sound and d.soundTime=="ACTION_START"then self.sound=a.body:playSound(d.sound);a.tabletopSound=self.sound end
    a.work.nativeProgress.actionStarted=true
end
function TabletopAction:update()
    local a=self.owner;if self.action~=a.nativeAction then return end
    if not usable(a)or a.action~=self or not a.started then self:forceStop();return end
    a.item:setJobDelta(self:getJobDelta());a.body:setMetabolicTarget(a.descriptor.metabolics)
    if a.descriptor.cantSit and a.body:isSitOnGround()then a.body:setSitOnGround(false)end
    a.work.nativeProgress.sourceUpdates=a.work.nativeProgress.sourceUpdates+1
    a.work.nativeProgress.jobDelta=self:getJobDelta();a.work.atHours=hours()
end
function TabletopAction:stopSound()
    if self.sound and self.character:getEmitter():isPlaying(self.sound)then self.character:stopOrTriggerSound(self.sound)end
end
function TabletopAction:animEvent(event,parameter)
    local a=self.owner;if not usable(a)or a.action~=self or not a.started then return end
    local d=a.descriptor
    if(event=="StartActionAnim"and d.soundTime=="ANIMATION_START"or event=="PlayActionSound"and d.soundTime=="ANIMATION_EVENT")and d.sound then
        self:stopSound();self.sound=a.body:playSound(d.sound);a.tabletopSound=self.sound
    end
end
function TabletopAction:perform()
    local a=self.owner
    if a.performed or a.action~=self or not usable(a)or not a.started or self.action~=a.nativeAction
        or a.work.nativeProgress.sourceUpdates<1 or not(self:getJobDelta()>=1)then return end
    a.item:setJobDelta(0);self:stopSound()
    if a.descriptor.completionSound then a.body:playSound(a.descriptor.completionSound)end
    local result=SAOJavaBridge:nativeTabletopComplete(a.body,a.item,a.tabletopKind,a.work.workId)
    if type(result)~="table"or result.schema~="sao.native-tabletop-result/1"or result.actorId~=a.work.actorId
        or result.workId~=a.work.workId or result.kind~=a.tabletopKind or result.itemId~=a.item:getID()
        or result.itemType~=a.work.itemType or result.revision~=a.work.revision or type(result.display)~="string"then
        self:forceStop();return
    end
    a.result=plain(result);a.performed=true
    ISBaseTimedAction.perform(self)
end
function TabletopAction:complete()
    local a=self.owner;if not a.performed or not owned(a)or self.action~=a.nativeAction then return false end
    return finish(a,"completed")
end
function TabletopAction:stop()
    local a=self.owner;if not owned(a)or a.action~=self then return end
    if held(a.body,a.item)then a.item:setJobDelta(0)end
    self:stopSound();ISBaseTimedAction.stop(self);finish(a,"interrupted","native-tabletop-stopped")
end
function TabletopAction:forceCancel()self:stop()end
function TabletopAction:new(a)
    local o=ISBaseTimedAction.new(self,a.body);o.owner=a
    o.maxTime=a.body:isTimedActionInstant()and 1 or a.descriptor.time*5
    o.stopOnWalk=not a.descriptor.canWalk;o.stopOnRun=true;o.stopOnAim=false
    if a.body:hasTrait(CharacterTrait.ALL_THUMBS)or a.body:isWearingAwkwardGloves()then o.stopOnWalk=true end
    return o
end
local function begin(id,body,offer,purposeId)
    if not live(id,body)or runtime[id]or rec(id).gamesWork or not SAO.Needs.workAvailable(body)or type(purposeId)~="string"then return false end
    local selected;for _,v in ipairs(G.offers(id,body))do if same(v,offer)then selected=v;break end end
    if not selected or selected.requiresPreparation.frontSquare then return false end
    local obj,item,descriptor
    if selected.tabletopKind then
        local rows=SAOJavaBridge:privateCarriedItems(body)
        for i=0,rows:size()-1 do local v=rows:get(i);if v:getID()==selected.itemId and v:getFullType()==selected.itemType then item=v;break end end
        descriptor=item and tabletopSource(id,body,item,selected.tabletopKind)
        if not descriptor or not same(tabletopMetadata(descriptor),selected.sourceAction)then return false end
    else
        obj=SAO.Perception.resolveLeisureObject(id,body,selected.objectKey)
        if not obj or not available(id,obj)then return false end
    end
    local r=rec(id);r.gamesSequence=(r.gamesSequence or 0)+1
    local token=body:getModData().SAOExternalToken
    local w={actorId=id,sequence=r.gamesSequence,workId="games:"..id..":"..r.gamesSequence,purposeId=purposeId,
        family="games",activity=selected.activity,sourceId=selected.sourceId,revision=selected.revision,
        nativeOwner=selected.tabletopKind and "native:ISHandcraftAction/NPC-keep-input-source-core"or selected.gameId and Definitions[selected.gameId].className.."/NPC-source-scene"or selected.clawMachine and "ProjectArcade_ClawTimedAction/NPC-source-core"or selected.arcadeType and "ProjectArcade_PlayArcadeTimedAction/NPC-source-core"or "LSPingPong/NPC-source-core",
        bodyGenerationKnown=type(token)=="string"and token~="",bodyToken=token,admittedAtHours=hours(),atHours=hours(),status="prepared",
        objectKey=selected.objectKey,runtimeInstance=selected.runtimeInstance,machineId=selected.machineId,opponentKey=selected.opponentKey,
        itemKey=selected.itemKey,itemType=selected.itemType,itemId=selected.itemId,sourceAction=plain(selected.sourceAction),
        nativeProgress={sourceUpdates=0,inputSelections=0},revisionAuthority=selected.revisionAuthority}
    local a={work=w,body=body,emitter=body:getEmitter(),object=obj,gameId=selected.gameId,keys={},frameId=0,
        arcadeType=selected.arcadeType,clawMachine=selected.clawMachine,cost=selected.cost,currencyType=selected.currencyType,debugFreePlay=selected.debugFreePlay,
        tabletopKind=selected.tabletopKind,item=item,descriptor=descriptor}
    r.gamesWork=w;runtime[id]=a
    local P=SAO.ProceduralPlanning
    if not P or not P.admitHobbyWork or not P.admitHobbyWork(id,purposeId,w.sequence,"SAO.LeisureGames")then r.gamesWork=nil;runtime[id]=nil;return false end
    if obj then obj:getModData().SAONpcGameLease={actorId=id,workId=w.workId,bodyToken=token,admittedAtHours=w.admittedAtHours}end
    if selected.tabletopKind then
        a.action=TabletopAction:new(a)
    elseif selected.gameId then
        local class=GameClasses[selected.gameId];a.scene=class:new(0,0,450,253);sceneOwners[a.scene]=a
        local resume=getResume(r,w)
        if resume and resume.sourceId==w.sourceId and resume.revision==w.revision and resume.objectKey==w.objectKey
            and resume.machineId==w.machineId and type(resume.state)=="table"then
            for k,v in pairs(plain(resume.state))do a.scene[k]=v end;w.resumedFromHours=resume.atHours
        else current=a;a.scene:initialise();current=nil end
        a.action=ComputerAction:new(a)
    elseif selected.arcadeType or selected.clawMachine then
        a.action=ArcadePayment:new(body,a.cost,a.currencyType,a.debugFreePlay,ProjectArcade_Currency.Config.NoCoinText,function()a.sourcePaid=true end)
        a.action.owner=a
    else
        local other=SAO.Perception.resolveLeisureObject(id,body,selected.opponentKey)
        if not other or not available(id,other)then finish(a,"interrupted","ping-pong-adjacent-source-unavailable");return false end
        a.opponent=other;other:getModData().SAONpcGameLease={actorId=id,workId=w.workId,bodyToken=token}
        obj:getModData().movableData.inUse=true
        local resume=getResume(r,w)
        local restorable=resume and resume.sourceId==w.sourceId and resume.revision==w.revision
            and resume.objectKey==w.objectKey and resume.opponentKey==w.opponentKey and type(resume.state)=="table"
        local match=restorable and plain(resume.state.matchData)or MatchRules.resolvePingPongMatch(MatchRules.getPingPongForm(body),ZombRandFloat(.3,.7))
        a.action=PingAction:new(body,nil,{{sN=obj:getSprite():getName(),aSN=other:getSprite():getName(),event=match},true})
        a.action.matchObj,a.action.opponentObj=obj,other;a.action.owner=a
        if restorable then
            for k,v in pairs(plain(resume.state))do a.action[k]=v end;w.resumedFromHours=resume.atHours
        end
    end
    snapshot(a)
    if not SAO.Needs.queueVerified(a.action)then finish(a,"interrupted","native-game-queue-refused");return false end
    return true
end
function G.begin(id,body,offer,purposeId)
    local ok,result=pcall(begin,id,body,offer,purposeId)
    if not ok then current=nil;local a=runtime[id];if a then finish(a,"interrupted","game-source-admission-unavailable")end end
    return ok and result==true
end
function G.interrupt(id,body,reason)
    local a=runtime[id]
    if a then
        if a.body~=body then return false end
        -- Retire private captured resources even after death/detachment. Source
        -- callbacks still require live ownership; cleanup never enacts a result.
        local action=a.action;local native=a.nativeAction or action and action.action
        local sound=a.tabletopSound or action and action.sound
        if sound and a.emitter then
            pcall(function()if a.emitter:isPlaying(sound)then a.emitter:stopOrTriggerSound(sound)end end)
        end
        if action and action.soundId and action.emitter then
            pcall(function()action.emitter:stopSound(action.soundId)end)
        end
        if native then
            pcall(function()native:forceStop()end)
            pcall(function()a.body:getCharacterActions():remove(native)end)
        end
        local q=ISTimedActionQueue.getTimedActionQueue(a.body)
        if q and q.removeFromQueue then q:removeFromQueue(action);if q.current==action then q.current=nil end end
        if a.body:getModData().SAOExternalToken==a.work.bodyToken and a.tabletopKind and held(a.body,a.item)then a.item:setJobDelta(0)end
        finish(a,"interrupted",reason or "game-interrupted")
    elseif rec(id)and rec(id).gamesWork then
        local w=rec(id).gamesWork
        if not body or body:getModData().SAOPersonId~=id or body:getModData().SAOExternalToken~=w.bodyToken
            or SAO.Needs.ownsRecoveryBody(id,body)~=true then return false end
            -- Fresh runtime retirement is limited to the acquired exact object
            -- and this saved work's lease. It never restores a native callback.
            local P=SAO.Perception
            for _,key in ipairs({w.objectKey,w.opponentKey})do
                local obj=P and P.resolveLeisureObject and P.resolveLeisureObject(id,body,key)
                local l=obj and lease(obj)
                if l and l.actorId==id and l.workId==w.workId and l.bodyToken==w.bodyToken then
                    if key==w.objectKey and w.activity and string.sub(w.activity,1,7)=="arcade-" then ArcadeSource.overlay(obj,false)
                    elseif key==w.objectKey and w.activity~="claw-machine" and not w.machineId and obj:getModData().movableData then obj:getModData().movableData.inUse=false end
                    obj:getModData().SAONpcGameLease=nil
                end
            end
            if body and SAO.Needs.ownsRecoveryBody(id,body)==true and body:getModData().SAOExternalToken==w.bodyToken
                and body:getModData().SAONpcPingBlock==w.workId then
                body:setBlockMovement(false);body:getModData().SAONpcPingBlock=nil
            end
            w.status,w.reason,w.atHours="interrupted",reason or "game-runtime-unavailable",hours()
            local r=rec(id);r.gamesOutcomes=r.gamesOutcomes or{};r.gamesOutcomes[#r.gamesOutcomes+1]=plain(w)
            if #r.gamesOutcomes>32 then table.remove(r.gamesOutcomes,1)end;r.gamesWork=nil
            if SAO.ProceduralPlanning.consumeHobbyOutcome then SAO.ProceduralPlanning.consumeHobbyOutcome(id,w.sequence,"SAO.LeisureGames")end
    end;return true
end
function G.advance(id,body)
    local a=runtime[id]
    if not a or a.body~=body or not owned(a)or not ISTimedActionQueue.hasAction(a.action)and not a.performed then
        G.interrupt(id,body,"game-runtime-or-queue-lost");return false
    end;return true
end
function G.reset(reason)
    local ids={};for id in pairs(runtime)do ids[#ids+1]=id end
    for _,id in ipairs(ids)do G.interrupt(id,runtime[id].body,reason)end
end
return G
