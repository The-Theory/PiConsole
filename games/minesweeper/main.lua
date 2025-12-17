---@diagnostic disable: undefined-global

local Input = require("TiPiL.input")
local UI = require("TiPiL.ui")
local utils = require("TiPiL.utils")

local Scene = {}

local game_common = require("TiPiL.game_common")

local CONFIG = {
    targetTileSize = 24,  -- Target tile size in pixels
    mineCount = 50,       -- Number of mines
    moveDelay = game_common.TIMING.MOVE_DELAY,
    inputThreshold = game_common.THRESHOLDS.DIRECTION,
}

-- Colors
local COLORS = {
    bgPanel = {0.12, 0.12, 0.14, 1},
    gridBgLight = {0.18, 0.18, 0.20, 1},
    gridBgDark = {0.16, 0.16, 0.18, 1},
    tileHidden = {0.25, 0.35, 0.45, 1},      -- Darker blue-gray
    tileRevealed = {0.22, 0.24, 0.26, 1},    -- Dark gray
    tileCursor = {0.2, 0.65, 0.9, 1},        -- Primary color for cursor
    mine = {0.95, 0.35, 0.35, 1},            -- Danger red
    flag = {0.95, 0.75, 0.2, 1},             -- Warning orange
    flagPole = {0.4, 0.35, 0.3, 1},          -- Dark brown
    numbers = {
        {0.2, 0.65, 0.9, 1},   -- 1: Primary blue
        {0.2, 0.85, 0.5, 1},   -- 2: Success green
        {0.95, 0.35, 0.35, 1}, -- 3: Danger red
        {0.85, 0.35, 0.95, 1}, -- 4: Purple
        {0.95, 0.3, 0.3, 1},   -- 5: Red
        {0.2, 0.8, 0.8, 1},    -- 6: Cyan
        {0.95, 0.75, 0.2, 1},  -- 7: Warning yellow
        {0.6, 0.6, 0.6, 1},    -- 8: Gray
    },
    checkerLight = {0.18, 0.18, 0.20, 1},
    checkerDark = {0.16, 0.16, 0.18, 1},
}

local input, ui
local grid = { cols = 0, rows = 0, cell = 0, x = 0, y = 0, w = 0, h = 0 }
local cursor = { x = 0, y = 0 }
local board = {}  -- 2D array of tiles
local game = {
    state = "playing",  -- playing, won, lost
    firstMove = true,
    revealedCount = 0,
    flagCount = 0,
    moveTimer = 0,
    gameTimer = 0,      -- Game timer in seconds
    timerStarted = false,
}

-- Tile states
local function createTile()
    return {
        hasMine = false,
        state = "hidden",  -- hidden, revealed, flagged
        adjacentMines = 0,
    }
end

local function initBoard()
    board = {}
    for row = 0, grid.rows - 1 do
        board[row] = {}
        for col = 0, grid.cols - 1 do
            board[row][col] = createTile()
        end
    end
    game.firstMove = true
    game.revealedCount = 0
    game.flagCount = 0
end

local function placeMines(startX, startY)
    local placed = 0
    while placed < CONFIG.mineCount do
        local x = math.random(0, grid.cols - 1)
        local y = math.random(0, grid.rows - 1)
        
        -- Don't place on first click or adjacent
        local dx = math.abs(x - startX)
        local dy = math.abs(y - startY)
        if (dx > 1 or dy > 1) and not board[y][x].hasMine then
            board[y][x].hasMine = true
            placed = placed + 1
        end
    end
    
    -- Calculate adjacent mine counts
    for row = 0, grid.rows - 1 do
        for col = 0, grid.cols - 1 do
            if not board[row][col].hasMine then
                local count = 0
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if not (dx == 0 and dy == 0) then
                            local ny = row + dy
                            local nx = col + dx
                            if ny >= 0 and ny < grid.rows and nx >= 0 and nx < grid.cols then
                                if board[ny][nx].hasMine then
                                    count = count + 1
                                end
                            end
                        end
                    end
                end
                board[row][col].adjacentMines = count
            end
        end
    end
end

local function revealTile(x, y)
    if x < 0 or x >= grid.cols or y < 0 or y >= grid.rows then
        return
    end
    
    local tile = board[y][x]
    
    if tile.state ~= "hidden" then
        return
    end
    
    tile.state = "revealed"
    game.revealedCount = game.revealedCount + 1
    
    -- If mine, lose
    if tile.hasMine then
        game.state = "lost"
        -- Reveal all mines
        for row = 0, grid.rows - 1 do
            for col = 0, grid.cols - 1 do
                if board[row][col].hasMine then
                    board[row][col].state = "revealed"
                end
            end
        end
        return
    end
    
    -- If no adjacent mines, reveal neighbors (flood fill)
    if tile.adjacentMines == 0 then
        for dy = -1, 1 do
            for dx = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    revealTile(x + dx, y + dy)
                end
            end
        end
    end
    
    -- Check win
    local totalTiles = grid.cols * grid.rows
    if game.revealedCount == totalTiles - CONFIG.mineCount then
        game.state = "won"
    end
end

local function toggleFlag(x, y)
    local tile = board[y][x]
    
    if tile.state == "hidden" then
        tile.state = "flagged"
        game.flagCount = game.flagCount + 1
    elseif tile.state == "flagged" then
        tile.state = "hidden"
        game.flagCount = game.flagCount - 1
    end
end

local function resetGame()
    cursor.x = math.floor(grid.cols / 2)
    cursor.y = math.floor(grid.rows / 2)
    game.state = "playing"
    game.moveTimer = 0
    game.gameTimer = 0
    game.timerStarted = false
    initBoard()
    input:clearQueue()
end

--[[═══════════════════════════════════════════════════════════════════════════
    SCENE CALLBACKS
═══════════════════════════════════════════════════════════════════════════════]]

function Scene.load()
    input = Input.new()
    ui = UI.new("Minesweeper")
    ui:setupWindow()
    
    -- Calc grid size
    local w, h = ui:getScreen()
    
    -- Calculate how many cells fit with target tile size
    grid.cols = math.floor(w / CONFIG.targetTileSize)
    grid.rows = math.floor(h / CONFIG.targetTileSize)
    
    -- Calc actual tile size
    grid.cell = math.floor(math.min(w / grid.cols, h / grid.rows))
    
    -- Calculate grid dimensions (will be adjusted in draw for sidebar)
    grid.w = grid.cols * grid.cell
    grid.h = grid.rows * grid.cell
    grid.x = 10  -- Will be adjusted in draw
    grid.y = math.floor((h - grid.h) / 2)
    
    print(string.format("Screen: %dx%d, Grid: %dx%d cells, Tile: %dpx", w, h, grid.cols, grid.rows, grid.cell))
    
    resetGame()
end

function Scene.update(dt)
    input:update(dt)
    
    if game.state == "playing" then
        game.moveTimer = game.moveTimer + dt
        
        -- Cursor movement
        if game.moveTimer >= CONFIG.moveDelay then
            local dx, dy = input:getDirection(CONFIG.inputThreshold)
            if dx ~= 0 or dy ~= 0 then
                cursor.x = (cursor.x + dx) % grid.cols
                cursor.y = (cursor.y + dy) % grid.rows
                
                -- Handle negative wrapping
                if cursor.x < 0 then cursor.x = grid.cols - 1 end
                if cursor.y < 0 then cursor.y = grid.rows - 1 end
                
                game.moveTimer = 0
            end
        end
        
        -- Reveal (A)
        if input:isButtonPressed("a") then
            if game.firstMove then
                placeMines(cursor.x, cursor.y)
                game.firstMove = false
                game.timerStarted = true
            end
            revealTile(cursor.x, cursor.y)
        end
        
        -- Update game timer
        if game.timerStarted and game.state == "playing" then
            game.gameTimer = game.gameTimer + dt
        end
        
        -- Toggle flag (X)
        if input:isButtonPressed("x") then
            if not game.firstMove then  -- Can't flag before first move
                toggleFlag(cursor.x, cursor.y)
            end
        end
    end
    
    -- Handle standard input (menu/back)
    if game_common.handleStandardInput(input) then
        return
    end
    
    -- Reset input
    if game_common.handleResetInput(input, game.state, resetGame) then
        return
    end
end

-- Helper function to draw enhanced tile
local function drawEnhancedTile(x, y, size, color, isRevealed)
    local padding = 2
    local tileSize = size - padding * 2
    
    if isRevealed then
        -- Revealed (simple)
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", x + padding + 1, y + padding + 1, tileSize, tileSize, 0, 0)
        
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        love.graphics.rectangle("fill", x + padding, y + padding, tileSize, tileSize, 0, 0)
    else
        -- Hidden tile: enhanced with shadow, gradient, border
        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", x + padding + 1, y + padding + 1, tileSize, tileSize, 0, 0)
        
        -- Main
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        love.graphics.rectangle("fill", x + padding, y + padding, tileSize, tileSize, 0, 0)
        
        -- Highlight gradient (lighter top)
        local highlight = {color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, 0.4}
        love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])
        love.graphics.rectangle("fill", x + padding, y + padding, tileSize, tileSize * 0.3, 0, 0)
        
        -- Dark gradient
        local dark = {color[1] * 0.6, color[2] * 0.6, color[3] * 0.6, 0.3}
        love.graphics.setColor(dark[1], dark[2], dark[3], dark[4])
        love.graphics.rectangle("fill", x + padding, y + padding + tileSize * 0.7, tileSize, tileSize * 0.3, 0, 0)
        
        -- Border
        love.graphics.setColor(color[1] * 1.2, color[2] * 1.2, color[3] * 1.2, 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x + padding, y + padding, tileSize, tileSize, 0, 0)
    end
end

function Scene.draw()
    ui:clear()
    
    local w, h = ui:getScreen()
    
    -- Bg grid
    love.graphics.setColor(1, 1, 1, 0.02)
    local gridSize = 20
    for gx = 0, w, gridSize do
        love.graphics.line(gx, 0, gx, h)
    end
    for gy = 0, h, gridSize do
        love.graphics.line(0, gy, w, gy)
    end
    
    -- Calc sidebar dims
    local sidebarWidth = math.max(110, w * 0.15)
    local availableWidth = w - sidebarWidth - 20
    local gridW = math.min(grid.w, availableWidth)
    local gridX = 10
    local gridY = math.floor((h - grid.h) / 2)
    
    -- Grid panel
    local shadowOffset = 6
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", gridX + shadowOffset, gridY + shadowOffset, gridW, grid.h, 0, 0)
    love.graphics.setColor(COLORS.bgPanel[1], COLORS.bgPanel[2], COLORS.bgPanel[3], COLORS.bgPanel[4])
    love.graphics.rectangle("fill", gridX, gridY, gridW, grid.h, 0, 0)
    
    -- Border
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", gridX, gridY, gridW, grid.h, 0, 0)
    love.graphics.setLineWidth(1)
    
    -- Corner decals for grid panel
    local cornerSize = 4
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.8)
    love.graphics.rectangle("fill", gridX, gridY, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", gridX + gridW - cornerSize, gridY, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", gridX, gridY + grid.h - cornerSize, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", gridX + gridW - cornerSize, gridY + grid.h - cornerSize, cornerSize, cornerSize, 0, 0)
    
    -- Draw checkerboard
    love.graphics.setScissor(gridX, gridY, gridW, grid.h)
    game_common.drawCheckerboard(gridX, gridY, gridW, grid.h, 
                                  grid.cell, COLORS.checkerLight, COLORS.checkerDark)
    
    -- Grid lines
    love.graphics.setColor(1, 1, 1, 0.05)
    for c = 0, grid.cols do
        local x = gridX + c * grid.cell
        love.graphics.line(x, gridY, x, gridY + grid.h)
    end
    for r = 0, grid.rows do
        local y = gridY + r * grid.cell
        love.graphics.line(gridX, y, gridX + gridW, y)
    end
    
    -- Draw tiles
    for row = 0, grid.rows - 1 do
        for col = 0, grid.cols - 1 do
            local tile = board[row][col]
            local x = gridX + col * grid.cell
            local y = gridY + row * grid.cell
            
            if tile.state == "hidden" or tile.state == "flagged" then
                -- Hidden
                drawEnhancedTile(x, y, grid.cell, COLORS.tileHidden, false)
                
                -- Flag
                if tile.state == "flagged" then
                    local flagSize = math.max(4, grid.cell / 3)
                    local poleX = x + grid.cell / 2
                    local poleY = y + grid.cell / 4
                    
                    -- Pole shadow
                    love.graphics.setColor(0, 0, 0, 0.3)
                    love.graphics.setLineWidth(2)
                    love.graphics.line(poleX + 1, poleY + 1, poleX + 1, poleY + flagSize * 1.5 + 1)
                    
                    -- Pole
                    love.graphics.setColor(COLORS.flagPole)
                    love.graphics.setLineWidth(2)
                    love.graphics.line(poleX, poleY, poleX, poleY + flagSize * 1.5)
                    love.graphics.setLineWidth(1)
                    
                    -- Flag shadow
                    love.graphics.setColor(0, 0, 0, 0.3)
                    love.graphics.polygon("fill",
                        poleX + 1, poleY + 1,
                        poleX + flagSize + 1, poleY + flagSize / 2 + 1,
                        poleX + 1, poleY + flagSize + 1)
                    
                    -- Flag
                    love.graphics.setColor(COLORS.flag)
                    love.graphics.polygon("fill",
                        poleX, poleY,
                        poleX + flagSize, poleY + flagSize / 2,
                        poleX, poleY + flagSize)
                end
            else
                -- Revealed
                drawEnhancedTile(x, y, grid.cell, COLORS.tileRevealed, true)
                
                if tile.hasMine then
                    -- Mine
                    local mineRadius = math.max(3, grid.cell / 5)
                    local cx = x + grid.cell / 2
                    local cy = y + grid.cell / 2
                    
                    -- Shadow
                    love.graphics.setColor(0, 0, 0, 0.4)
                    love.graphics.circle("fill", cx + 1, cy + 1, mineRadius)
                    
                    -- Main body
                    love.graphics.setColor(COLORS.mine)
                    love.graphics.circle("fill", cx, cy, mineRadius)
                    
                    -- Highlight
                    love.graphics.setColor(1, 1, 1, 0.5)
                    love.graphics.circle("fill", cx - mineRadius / 3, cy - mineRadius / 3, mineRadius / 3)
                    
                    -- Spikes
                    love.graphics.setColor(COLORS.mine)
                    love.graphics.setLineWidth(2)
                    for i = 0, 7 do
                        local angle = i * math.pi / 4
                        local x1 = cx + math.cos(angle) * mineRadius * 0.7
                        local y1 = cy + math.sin(angle) * mineRadius * 0.7
                        local x2 = cx + math.cos(angle) * mineRadius * 1.5
                        local y2 = cy + math.sin(angle) * mineRadius * 1.5
                        love.graphics.line(x1, y1, x2, y2)
                    end
                    love.graphics.setLineWidth(1)
                elseif tile.adjacentMines > 0 then
                    -- Number
                    local text = tostring(tile.adjacentMines)
                    love.graphics.setFont(ui.fonts.medium)
                    local tw = ui.fonts.medium:getWidth(text)
                    local th = ui.fonts.medium:getHeight()
                    local tx = x + (grid.cell - tw) / 2
                    local ty = y + (grid.cell - th) / 2
                    
                    -- Shadow
                    love.graphics.setColor(0, 0, 0, 0.5)
                    love.graphics.print(text, tx + 1, ty + 1)
                    
                    -- Text
                    love.graphics.setColor(COLORS.numbers[tile.adjacentMines])
                    love.graphics.print(text, tx, ty)
                end
            end
        end
    end
    
    -- Draw cursor
    local cursorX = gridX + cursor.x * grid.cell
    local cursorY = gridY + cursor.y * grid.cell
    
    -- Cursor glow layers
    for layer = 1, 3 do
        local glowAlpha = 0.15 / layer
        local glowOffset = layer * 1.5
        love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], glowAlpha)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", 
            cursorX - glowOffset, cursorY - glowOffset, 
            grid.cell + glowOffset * 2, grid.cell + glowOffset * 2, 0, 0)
    end
    
    -- Border
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", cursorX + 1, cursorY + 1, grid.cell - 2, grid.cell - 2, 0, 0)
    love.graphics.setLineWidth(1)
    
    love.graphics.setScissor()
    
    -- Sidebar
    local sidebarPadding = 6
    local sidebarX = gridX + gridW + sidebarPadding
    local sidebarW = math.max(110, w - sidebarX - sidebarPadding)
    local sidebarH = grid.h
    local sidebarY = gridY
    
    -- Shadow
    local sidebarShadow = 6
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", sidebarX + sidebarShadow, sidebarY + sidebarShadow, sidebarW, sidebarH, 0, 0)
    love.graphics.setColor(COLORS.bgPanel[1], COLORS.bgPanel[2], COLORS.bgPanel[3], COLORS.bgPanel[4])
    love.graphics.rectangle("fill", sidebarX, sidebarY, sidebarW, sidebarH, 0, 0)
    
    -- Border
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.3)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", sidebarX, sidebarY, sidebarW, sidebarH, 0, 0)
    love.graphics.setLineWidth(1)
    
    -- Corner decals
    local cornerSize = 4
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.8)
    love.graphics.rectangle("fill", sidebarX, sidebarY, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", sidebarX + sidebarW - cornerSize, sidebarY, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", sidebarX, sidebarY + sidebarH - cornerSize, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", sidebarX + sidebarW - cornerSize, sidebarY + sidebarH - cornerSize, cornerSize, cornerSize, 0, 0)
    
    local sectionY = sidebarY + 12
    
    -- Flags
    love.graphics.setFont(ui.fonts.large)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print("Flags", sidebarX + 12, sectionY + 1)
    love.graphics.setColor(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], UI.colors.text[4])
    love.graphics.print("Flags", sidebarX + 12, sectionY)
    love.graphics.setFont(ui.fonts.title)
    love.graphics.setColor(UI.colors.warning[1], UI.colors.warning[2], UI.colors.warning[3], 1)
    local flagText = game.flagCount .. "/" .. CONFIG.mineCount
    love.graphics.print(flagText, sidebarX + 12, sectionY + 26)
    
    -- Divider
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.rectangle("fill", sidebarX + 8, sectionY + 58, sidebarW - 16, 1, 0, 0)
    
    -- Timer
    sectionY = sectionY + 60
    love.graphics.setFont(ui.fonts.large)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print("Time", sidebarX + 12, sectionY + 1)
    love.graphics.setColor(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], UI.colors.text[4])
    love.graphics.print("Time", sidebarX + 12, sectionY)
    love.graphics.setFont(ui.fonts.title)
    love.graphics.setColor(UI.colors.success[1], UI.colors.success[2], UI.colors.success[3], 1)
    local minutes = math.floor(game.gameTimer / 60)
    local seconds = math.floor(game.gameTimer % 60)
    local timeText = string.format("%02d:%02d", minutes, seconds)
    love.graphics.print(timeText, sidebarX + 12, sectionY + 26)
    
    -- Divider
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.rectangle("fill", sidebarX + 8, sectionY + 58, sidebarW - 16, 1, 0, 0)
    
    -- Status
    sectionY = sectionY + 60
    love.graphics.setFont(ui.fonts.large)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print("Status", sidebarX + 12, sectionY + 1)
    love.graphics.setColor(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], UI.colors.text[4])
    love.graphics.print("Status", sidebarX + 12, sectionY)
    love.graphics.setFont(ui.fonts.medium)
    local statusText = game.state == "playing" and "Playing" or (game.state == "won" and "Won!" or "Lost")
    local statusColor = game.state == "won" and UI.colors.success or (game.state == "lost" and UI.colors.danger or UI.colors.primaryBright)
    love.graphics.setColor(statusColor[1], statusColor[2], statusColor[3], 1)
    love.graphics.print(statusText, sidebarX + 12, sectionY + 26)
    
    -- Game over
    if game.state == "won" or game.state == "lost" then
        local borderColor = game.state == "won" and UI.colors.success or UI.colors.danger
        ui:drawGameOver(borderColor)
    end
end

return Scene

