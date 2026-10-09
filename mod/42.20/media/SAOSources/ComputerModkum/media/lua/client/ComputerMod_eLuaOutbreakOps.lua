require "ISUI/ISPanel"

PZOutbreakOpsGame = ISPanel:derive("PZOutbreakOpsGame")

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
