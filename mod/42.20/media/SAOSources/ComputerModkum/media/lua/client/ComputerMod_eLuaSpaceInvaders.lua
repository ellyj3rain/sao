require "ISUI/ISPanel"

PZSpaceInvadersGame = ISPanel:derive("PZSpaceInvadersGame")

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
