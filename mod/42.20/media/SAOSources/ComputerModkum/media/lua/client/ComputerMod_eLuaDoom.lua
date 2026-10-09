require "ISUI/ISPanel"

PZDoomGame = ISPanel:derive("PZDoomGame")

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
