-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ISUI/ISPanel"

PZTetrisGame = ISPanel:derive("PZTetrisGame")

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
