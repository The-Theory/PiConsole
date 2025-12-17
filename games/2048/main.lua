---@diagnostic disable: undefined-global

local Input = require("TiPiL.input")
local UI = require("TiPiL.ui")
local utils = require("TiPiL.utils")

local Scene = {}

local game_common = require("TiPiL.game_common")

local CONFIG = {
    gridSize = 4,   
    targetTileSize = 60,
    moveDelay = game_common.TIMING.MOVE_DELAY,
    animSpeed = game_common.TIMING.ANIMATION_SPEED,
    spawnAnimSpeed = game_common.TIMING.SPAWN_ANIM_SPEED,
    inputThreshold = game_common.THRESHOLDS.DIRECTION,
}

-- Colors
local COLORS = {
    bgPanel = {0.12, 0.12, 0.14, 1},
    gridBgLight = {0.18, 0.18, 0.20, 1},
    gridBgDark = {0.16, 0.16, 0.18, 1},
    empty = {0.12, 0.12, 0.14, 1},         -- Dark empty cell
    tiles = {
        [2] = {0.37, 0.34, 0.31, 1},       -- Dark gray
        [4] = {0.51, 0.46, 0.61, 1},       -- Indigo
        [8] = {0.16, 0.68, 1.00, 1},       -- Bright blue
        [16] = {0.00, 0.89, 0.21, 1},      -- Green
        [32] = {1.00, 0.64, 0.00, 1},      -- Orange
        [64] = {1.00, 0.00, 0.30, 1},      -- Red
        [128] = {1.00, 0.47, 0.66, 1},     -- Pink
        [256] = {1.00, 0.93, 0.15, 1},     -- Yellow
        [512] = {1.00, 0.80, 0.67, 1},     -- Peach
        [1024] = {0.76, 0.76, 0.78, 1},    -- Light gray
        [2048] = {1.00, 0.95, 0.91, 1},    -- Almost white
        default = {0.24, 0.22, 0.20, 1},   -- Dark fallback
    },
    textLight = {0.08, 0.08, 0.10, 1},     -- Dark text for light tiles
    textDark = {0.98, 0.98, 0.98, 1},      -- Light text for saturated/dark tiles
    checkerLight = {0.18, 0.18, 0.20, 1},
    checkerDark = {0.16, 0.16, 0.18, 1},
}

local input, ui
local grid = { size = CONFIG.gridSize, cell = 0, x = 0, y = 0, w = 0, h = 0, pad = 8, gap = 8 }
local board = {}
local tiles = {}
local game = {
    state = "playing",  -- playing, won, lost
    score = 0,
    bestScore = 0,
    moveTimer = 0,
    moved = false,
    animating = false,
    moveCount = 0,
    lastScoreGain = 0,
    scorePopupTimer = 0,
    scorePopupX = 0,
    scorePopupY = 0,
}

local function createEmptyBoard()
    local b = {}
    for row = 0, grid.size - 1 do
        b[row] = {}
        for col = 0, grid.size - 1 do
            b[row][col] = 0
        end
    end
    return b
end

local function getTileColor(value)
    if value == 0 then
        return COLORS.empty
    end
    return COLORS.tiles[value] or COLORS.tiles.default
end

local function getTileTextColor(value)
    return value >= 8 and COLORS.textDark or COLORS.textLight
end

-- Tile ID counter
local tileIdCounter = 0
local function getNextTileId()
    tileIdCounter = tileIdCounter + 1
    return tileIdCounter
end

-- Create tile
local function createTile(row, col, value, isNew)
    return {
        id = getNextTileId(),
        value = value,
        row = row,
        col = col,
        x = col,  -- Visual position
        y = row,  -- Visual position
        scale = isNew and 0 or 1,  -- Small if new
        isNew = isNew or false,
    }
end

local function addRandomTile()
    -- Find empty
    local empty = {}
    for row = 0, grid.size - 1 do
        for col = 0, grid.size - 1 do
            if board[row][col] == 0 then
                table.insert(empty, {row = row, col = col})
            end
        end
    end
    
    if #empty > 0 then
        local cell = empty[math.random(#empty)]
        -- 90% 2, 10% 4
        local value = (math.random() < 0.9) and 2 or 4
        board[cell.row][cell.col] = value
        table.insert(tiles, createTile(cell.row, cell.col, value, true))
        return true
    end
    return false
end

local function copyBoard(b)
    local copy = {}
    for row = 0, grid.size - 1 do
        copy[row] = {}
        for col = 0, grid.size - 1 do
            copy[row][col] = b[row][col]
        end
    end
    return copy
end

local function boardsEqual(b1, b2)
    for row = 0, grid.size - 1 do
        for col = 0, grid.size - 1 do
            if b1[row][col] ~= b2[row][col] then return false end
        end
    end
    return true
end

local function slideAndMerge(line)
    -- Remove zeros
    local nonZero = {}
    for i = 1, #line do
        if line[i] ~= 0 then
            table.insert(nonZero, line[i])
        end
    end
    
    -- Merge
    local merged = {}
    local i = 1
    while i <= #nonZero do
        if i < #nonZero and nonZero[i] == nonZero[i + 1] then
            local value = nonZero[i] * 2
            table.insert(merged, value)
            game.lastScoreGain = value
            game.score = game.score + value
            i = i + 2
        else
            table.insert(merged, nonZero[i])
            i = i + 1
        end
    end
    
    -- Fill zeros
    while #merged < grid.size do
        table.insert(merged, 0)
    end
    
    return merged
end

-- Extract line by direction
local function extractLine(direction, index)
    local line = {}
    local isHorizontal = (direction == "left" or direction == "right")
    
    if isHorizontal then
        for col = 0, grid.size - 1 do
            table.insert(line, board[index][col])
        end
    else
        for row = 0, grid.size - 1 do
            table.insert(line, board[row][index])
        end
    end
    
    -- Reverse for right/down
    if direction == "right" or direction == "down" then
        local reversed = {}
        for i = #line, 1, -1 do
            table.insert(reversed, line[i])
        end
        line = reversed
    end
    
    return line
end

-- Apply merged line to board
local function applyLine(direction, index, mergedLine)
    if direction == "left" then
        for col = 0, grid.size - 1 do
            board[index][col] = mergedLine[col + 1]
        end
    elseif direction == "right" then
        for col = 0, grid.size - 1 do
            board[index][grid.size - 1 - col] = mergedLine[col + 1]
        end
    elseif direction == "up" then
        for row = 0, grid.size - 1 do
            board[row][index] = mergedLine[row + 1]
        end
    else -- down
        for row = 0, grid.size - 1 do
            board[grid.size - 1 - row][index] = mergedLine[row + 1]
        end
    end
end

-- Check valid move direction
local function isValidMoveDirection(direction, oldPos, newRow, newCol)
    if direction == "left" then
        return oldPos.row == newRow and oldPos.col >= newCol
    elseif direction == "right" then
        return oldPos.row == newRow and oldPos.col <= newCol
    elseif direction == "up" then
        return oldPos.col == newCol and oldPos.row >= newRow
    else -- down
        return oldPos.col == newCol and oldPos.row <= newRow
    end
end

-- Find best tile match
local function findBestTileMatch(tile, oldPositions, direction)
    local bestMatch = nil
    local bestDist = 999
    
    for _, oldPos in ipairs(oldPositions) do
        if isValidMoveDirection(direction, oldPos, tile.row, tile.col) then
            -- Check if value matches or is half (merge)
            if oldPos.value == tile.value or oldPos.value * 2 == tile.value then
                local dist = math.abs(oldPos.row - tile.row) + math.abs(oldPos.col - tile.col)
                if dist < bestDist then
                    bestDist = dist
                    bestMatch = oldPos
                end
            end
        end
    end
    
    return bestMatch
end

-- Build old positions list
local function buildOldPositions(oldBoard)
    local positions = {}
    for row = 0, grid.size - 1 do
        for col = 0, grid.size - 1 do
            if oldBoard[row][col] ~= 0 then
                table.insert(positions, {
                    row = row,
                    col = col,
                    value = oldBoard[row][col]
                })
            end
        end
    end
    return positions
end

-- Create animated tiles
local function createAnimatedTiles(oldBoard, direction)
    local oldPositions = buildOldPositions(oldBoard)
    tiles = {}
    
    for row = 0, grid.size - 1 do
        for col = 0, grid.size - 1 do
            if board[row][col] ~= 0 then
                local tile = createTile(row, col, board[row][col], false)
                local bestMatch = findBestTileMatch(tile, oldPositions, direction)
                
                if bestMatch then
                    tile.x = bestMatch.col
                    tile.y = bestMatch.row
                    bestMatch.value = -1  -- Mark used
                end
                
                table.insert(tiles, tile)
            end
        end
    end
end

local function move(direction)
    if game.animating then return end
    
    local oldBoard = copyBoard(board)
    
    -- Process lines
    local maxIndex = (direction == "left" or direction == "right") and grid.size or grid.size
    for i = 0, maxIndex - 1 do
        local line = extractLine(direction, i)
        local mergedLine = slideAndMerge(line)
        applyLine(direction, i, mergedLine)
    end
    
    -- Check if changed, create anims
    if not boardsEqual(oldBoard, board) then
        createAnimatedTiles(oldBoard, direction)
        addRandomTile()
        game.moved = true
        game.animating = true
        game.moveCount = game.moveCount + 1
        
        -- Set score popup on merge
        if game.lastScoreGain > 0 then
            game.scorePopupTimer = 0.5
            -- Calc popup pos (grid center)
            game.scorePopupX = grid.x + grid.w / 2
            game.scorePopupY = grid.y + grid.h / 2
        end
    end
end

local function canMove()
    -- Check empty
    for row = 0, grid.size - 1 do
        for col = 0, grid.size - 1 do
            if board[row][col] == 0 then
                return true
            end
        end
    end
    
    -- Check merges
    for row = 0, grid.size - 1 do
        for col = 0, grid.size - 1 do
            local value = board[row][col]
            -- Check right
            if col < grid.size - 1 and board[row][col + 1] == value then
                return true
            end
            -- Check down
            if row < grid.size - 1 and board[row + 1][col] == value then
                return true
            end
        end
    end
    
    return false
end

local function checkWin()
    for row = 0, grid.size - 1 do
        for col = 0, grid.size - 1 do
            if board[row][col] == 2048 then
                return true
            end
        end
    end
    return false
end

local function resetGame()
    board = createEmptyBoard()
    tiles = {}
    game.state = "playing"
    game.score = 0
    game.moveTimer = 0
    game.moved = false
    game.animating = false
    game.moveCount = 0
    game.lastScoreGain = 0
    game.scorePopupTimer = 0
    tileIdCounter = 0
    
    -- Add 2 starting tiles
    addRandomTile()
    addRandomTile()
    
    input:clearQueue()
end


function Scene.load()
    input = Input.new()
    ui = UI.new("2048")
    ui:setupWindow()
    
    -- Calc grid size
    local w, h = ui:getScreen()
    
    -- Calc cell size (account for sidebar)
    local sidebarWidth = math.max(110, w * 0.15)
    local availableW = w - sidebarWidth - 20 - grid.gap * (grid.size + 1)
    local availableH = h - grid.pad * 2 - grid.gap * (grid.size + 1)
    local maxCell = math.min(availableW / grid.size, availableH / grid.size)
    grid.cell = math.floor(maxCell)
    
    -- Calc grid dims
    grid.w = grid.size * grid.cell + (grid.size + 1) * grid.gap
    grid.h = grid.size * grid.cell + (grid.size + 1) * grid.gap
    grid.x = 10
    grid.y = math.floor((h - grid.h) / 2)
    
    print(string.format("Screen: %dx%d, Grid: %dx%d, Cell: %dpx", w, h, grid.size, grid.size, grid.cell))
    
    resetGame()
end

-- Update tile anim
local function updateTileAnimation(tile, dt)
    local targetX = tile.col
    local targetY = tile.row
    local speed = CONFIG.animSpeed * dt
    local threshold = 0.01
    
    -- Animate pos
    local dx = targetX - tile.x
    local dy = targetY - tile.y
    
    if math.abs(dx) > threshold then
        tile.x = tile.x + dx * speed
        -- Clamp to prevent overshoot
        if (dx > 0 and tile.x > targetX) or (dx < 0 and tile.x < targetX) then
            tile.x = targetX
        end
    else
        tile.x = targetX
    end
    
    if math.abs(dy) > threshold then
        tile.y = tile.y + dy * speed
        -- Clamp to prevent overshoot
        if (dy > 0 and tile.y > targetY) or (dy < 0 and tile.y < targetY) then
            tile.y = targetY
        end
    else
        tile.y = targetY
    end
    
    -- Clamp to bounds
    tile.x = math.max(0, math.min(grid.size - 1, tile.x))
    tile.y = math.max(0, math.min(grid.size - 1, tile.y))
    
    -- Animate scale (new tiles)
    if tile.scale < 1 then
        tile.scale = math.min(1, tile.scale + dt * CONFIG.spawnAnimSpeed)
    end
    
    -- Check if complete
    local isComplete = math.abs(tile.x - targetX) <= threshold and
                       math.abs(tile.y - targetY) <= threshold and
                       tile.scale >= 0.99
    
    if isComplete then
        tile.x = targetX
        tile.y = targetY
        tile.scale = 1
    end
    
    return isComplete
end

function Scene.update(dt)
    input:update(dt)
    
    -- Update score popup
    if game.scorePopupTimer > 0 then
        game.scorePopupTimer = game.scorePopupTimer - dt
    end
    
    -- Animate
    if game.animating then
        local allAnimsComplete = true
        for _, tile in ipairs(tiles) do
            if not updateTileAnimation(tile, dt) then
                allAnimsComplete = false
            end
        end
        
        if allAnimsComplete then
            game.animating = false
        end
    end
    
    if game.state == "playing" then
        game.moveTimer = game.moveTimer + dt
        
        -- Handle movement w/ delay
        if game.moveTimer >= CONFIG.moveDelay and not game.animating then
            local dx, dy = input:getDirection(CONFIG.inputThreshold)
            
            if dx ~= 0 or dy ~= 0 then
                local direction = nil
                if dx == 1 then
                    direction = "right"
                elseif dx == -1 then
                    direction = "left"
                elseif dy == 1 then
                    direction = "down"
                elseif dy == -1 then
                    direction = "up"
                end
                
                if direction then
                    move(direction)
                end
                
                if game.moved then
                    game.moveTimer = 0
                    game.moved = false
                    
                    -- Update best
                    if game.score > game.bestScore then
                        game.bestScore = game.score
                    end
                    
                    -- Check win/lose
                    if checkWin() then
                        game.state = "won"
                    elseif not canMove() then
                        game.state = "lost"
                    end
                end
            end
        end
    end
    
    -- Standard input
    if game_common.handleStandardInput(input) then
        return
    end
    
    -- Reset input
    if game_common.handleResetInput(input, game.state, resetGame) then
        return
    end
end

-- Draw enhanced tile
local function drawEnhancedTile(x, y, size, color, textColor, text, scale)
    local padding = 2
    local tileSize = size - padding * 2
    
    -- Apply scale
    local scaledSize = tileSize * scale
    local offsetX = (tileSize - scaledSize) / 2
    local offsetY = (tileSize - scaledSize) / 2
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", x + padding + offsetX + 1, y + padding + offsetY + 1, scaledSize, scaledSize, 6, 6)
    
    -- Main tile
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.rectangle("fill", x + padding + offsetX, y + padding + offsetY, scaledSize, scaledSize, 6, 6)
    
    -- Highlight gradient (lighter top)
    local highlight = {color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, 0.4}
    love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])
    love.graphics.rectangle("fill", x + padding + offsetX, y + padding + offsetY, scaledSize, scaledSize * 0.3, 6, 6)
    
    -- Dark gradient (darker bottom)
    local dark = {color[1] * 0.6, color[2] * 0.6, color[3] * 0.6, 0.3}
    love.graphics.setColor(dark[1], dark[2], dark[3], dark[4])
    love.graphics.rectangle("fill", x + padding + offsetX, y + padding + offsetY + scaledSize * 0.7, scaledSize, scaledSize * 0.3, 6, 6)
    
    -- Border
    love.graphics.setColor(color[1] * 1.2, color[2] * 1.2, color[3] * 1.2, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + padding + offsetX, y + padding + offsetY, scaledSize, scaledSize, 6, 6)
    
    -- Text with shadow
    if text then
        local textLen = #text
        local font = (textLen >= 4) and ui.fonts.medium or ui.fonts.large
        love.graphics.setFont(font)
        local tw = font:getWidth(text)
        local th = font:getHeight()
        local tx = x + padding + offsetX + (scaledSize - tw) / 2
        local ty = y + padding + offsetY + (scaledSize - th) / 2
        
        -- Text shadow
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.print(text, tx + 1, ty + 1)
        
        -- Text
        love.graphics.setColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
        love.graphics.print(text, tx, ty)
    end
end

function Scene.draw()
    ui:clear()
    
    local w, h = ui:getScreen()
    
    -- Background grid pattern
    love.graphics.setColor(1, 1, 1, 0.02)
    local gridSize = 20
    for gx = 0, w, gridSize do
        love.graphics.line(gx, 0, gx, h)
    end
    for gy = 0, h, gridSize do
        love.graphics.line(0, gy, w, gy)
    end
    
    -- Grid panel with enhanced shadow
    local shadowOffset = 6
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", grid.x + shadowOffset, grid.y + shadowOffset, grid.w, grid.h, 0, 0)
    love.graphics.setColor(COLORS.bgPanel[1], COLORS.bgPanel[2], COLORS.bgPanel[3], COLORS.bgPanel[4])
    love.graphics.rectangle("fill", grid.x, grid.y, grid.w, grid.h, 0, 0)
    
    -- Grid border
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", grid.x, grid.y, grid.w, grid.h, 0, 0)
    love.graphics.setLineWidth(1)
    
    -- Corner decals for grid panel
    local cornerSize = 4
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.8)
    love.graphics.rectangle("fill", grid.x, grid.y, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", grid.x + grid.w - cornerSize, grid.y, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", grid.x, grid.y + grid.h - cornerSize, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", grid.x + grid.w - cornerSize, grid.y + grid.h - cornerSize, cornerSize, cornerSize, 0, 0)
    
    -- Draw checkered background inside grid
    love.graphics.setScissor(grid.x, grid.y, grid.w, grid.h)
    game_common.drawCheckerboard(grid.x, grid.y, grid.w, grid.h,
                                  grid.cell + grid.gap, COLORS.checkerLight, COLORS.checkerDark)
    
    -- Grid lines
    love.graphics.setColor(1, 1, 1, 0.05)
    local cellSpacing = grid.cell + grid.gap
    for c = 0, grid.size do
        local x = grid.x + grid.gap + c * cellSpacing - grid.gap / 2
        love.graphics.line(x, grid.y, x, grid.y + grid.h)
    end
    for r = 0, grid.size do
        local y = grid.y + grid.gap + r * cellSpacing - grid.gap / 2
        love.graphics.line(grid.x, y, grid.x + grid.w, y)
    end
    
    -- Draw empty cells
    love.graphics.setColor(COLORS.empty)
    for row = 0, grid.size - 1 do
        local y = grid.y + grid.gap + row * cellSpacing
        for col = 0, grid.size - 1 do
            local x = grid.x + grid.gap + col * cellSpacing
            love.graphics.rectangle("fill", x, y, grid.cell, grid.cell, 6, 6)
        end
    end
    
    -- Draw animated tiles
    for _, tile in ipairs(tiles) do
        local value = tile.value
        
        -- Calculate visual position (animated)
        local x = grid.x + grid.gap + tile.x * cellSpacing
        local y = grid.y + grid.gap + tile.y * cellSpacing
        
        local text = tostring(value)
        drawEnhancedTile(x, y, grid.cell, getTileColor(value), getTileTextColor(value), text, tile.scale)
    end
    
    love.graphics.setScissor()
    
    -- Score popup animation
    if game.scorePopupTimer > 0 and game.lastScoreGain > 0 then
        local alpha = game.scorePopupTimer / 0.5
        local offsetY = (1 - alpha) * 30
        local text = "+" .. tostring(game.lastScoreGain)
        
        love.graphics.setFont(ui.fonts.title)
        local textW = ui.fonts.title:getWidth(text)
        local textX = game.scorePopupX - textW / 2
        local textY = game.scorePopupY - 10 - offsetY
        
        -- Text shadow
        love.graphics.setColor(0, 0, 0, alpha * 0.5)
        love.graphics.print(text, textX + 1, textY + 1)
        
        -- Text
        love.graphics.setColor(UI.colors.success[1], UI.colors.success[2], UI.colors.success[3], alpha)
        love.graphics.print(text, textX, textY)
    end
    
    -- Sidebar panel
    local sidebarPadding = 6
    local sidebarX = grid.x + grid.w + sidebarPadding
    local sidebarW = math.max(110, w - sidebarX - sidebarPadding)
    local sidebarH = grid.h
    local sidebarY = grid.y
    
    -- Sidebar shadow
    local sidebarShadow = 6
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", sidebarX + sidebarShadow, sidebarY + sidebarShadow, sidebarW, sidebarH, 0, 0)
    love.graphics.setColor(COLORS.bgPanel[1], COLORS.bgPanel[2], COLORS.bgPanel[3], COLORS.bgPanel[4])
    love.graphics.rectangle("fill", sidebarX, sidebarY, sidebarW, sidebarH, 0, 0)
    
    -- Sidebar border
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.3)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", sidebarX, sidebarY, sidebarW, sidebarH, 0, 0)
    love.graphics.setLineWidth(1)
    
    -- Corner decals for sidebar
    local cornerSize = 4
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.8)
    love.graphics.rectangle("fill", sidebarX, sidebarY, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", sidebarX + sidebarW - cornerSize, sidebarY, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", sidebarX, sidebarY + sidebarH - cornerSize, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", sidebarX + sidebarW - cornerSize, sidebarY + sidebarH - cornerSize, cornerSize, cornerSize, 0, 0)
    
    local sectionY = sidebarY + 12
    
    -- Score section
    love.graphics.setFont(ui.fonts.large)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print("Score", sidebarX + 12, sectionY + 1)
    love.graphics.setColor(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], UI.colors.text[4])
    love.graphics.print("Score", sidebarX + 12, sectionY)
    love.graphics.setFont(ui.fonts.title)
    love.graphics.setColor(UI.colors.primaryBright[1], UI.colors.primaryBright[2], UI.colors.primaryBright[3], 1)
    love.graphics.print(tostring(game.score), sidebarX + 12, sectionY + 26)
    
    -- Divider
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.rectangle("fill", sidebarX + 8, sectionY + 58, sidebarW - 16, 1, 0, 0)
    
    -- Best Score section
    sectionY = sectionY + 60
    love.graphics.setFont(ui.fonts.large)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print("Best", sidebarX + 12, sectionY + 1)
    love.graphics.setColor(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], UI.colors.text[4])
    love.graphics.print("Best", sidebarX + 12, sectionY)
    love.graphics.setFont(ui.fonts.title)
    local bestColor = game.score == game.bestScore and game.score > 0 and UI.colors.success or UI.colors.warning
    love.graphics.setColor(bestColor[1], bestColor[2], bestColor[3], 1)
    love.graphics.print(tostring(game.bestScore), sidebarX + 12, sectionY + 26)
    
    -- Divider
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.rectangle("fill", sidebarX + 8, sectionY + 58, sidebarW - 16, 1, 0, 0)
    
    -- Moves section
    sectionY = sectionY + 60
    love.graphics.setFont(ui.fonts.large)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print("Moves", sidebarX + 12, sectionY + 1)
    love.graphics.setColor(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], UI.colors.text[4])
    love.graphics.print("Moves", sidebarX + 12, sectionY)
    love.graphics.setFont(ui.fonts.title)
    love.graphics.setColor(UI.colors.success[1], UI.colors.success[2], UI.colors.success[3], 1)
    love.graphics.print(tostring(game.moveCount), sidebarX + 12, sectionY + 26)
    
    -- Game over overlay
    if game.state == "won" or game.state == "lost" then
        local borderColor = game.state == "won" and UI.colors.warning or UI.colors.danger
        ui:drawGameOver(borderColor)
    end
end

return Scene

