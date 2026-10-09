-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ISUI/ISPanel"

PZMissileCommandGame = ISPanel:derive("PZMissileCommandGame")

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
