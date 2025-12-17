---@diagnostic disable: undefined-global

local game_common = {}

-- Input thresholds
game_common.THRESHOLDS = {
    DEFAULT_DEADZONE = 0.25,
    DIRECTION = 0.3,
    MOVE = 0.6,
}

-- Timing
game_common.TIMING = {
    MOVE_DELAY = 0.15,
    ANIMATION_SPEED = 12,
    SPAWN_ANIM_SPEED = 10,
}

-- Game states
game_common.STATES = {
    PLAYING = "playing",
    WON = "won",
    LOST = "lost",
    DEAD = "dead",
    OVER = "over",
    PAUSED = "paused",
}

-- Standard input handling
function game_common.handleStandardInput(input)
    -- Menu/back to launcher
    if input:handleMenuReturn() then
        return true
    end
    return false
end

-- Reset button handling
function game_common.handleResetInput(input, gameState, resetCallback)
    local resetStates = {game_common.STATES.WON, game_common.STATES.LOST, 
                         game_common.STATES.DEAD, game_common.STATES.OVER}
    for _, state in ipairs(resetStates) do
        if gameState == state and (input:isButtonPressed("y") or input:isButtonPressed("a")) then
            resetCallback()
            return true
        end
    end
    return false
end

-- Calc grid to fit screen
function game_common.calculateGridFit(screenW, screenH, targetCellSize, cols, rows, padding)
    padding = padding or 0
    local availableW = screenW - padding * 2
    local availableH = screenH - padding * 2
    local cellW = availableW / cols
    local cellH = availableH / rows
    local cell = math.floor(math.min(cellW, cellH, targetCellSize))
    
    local gridW = cols * cell
    local gridH = rows * cell
    local gridX = math.floor((screenW - gridW) / 2)
    local gridY = math.floor((screenH - gridH) / 2)
    
    return {
        cell = cell,
        x = gridX,
        y = gridY,
        w = gridW,
        h = gridH,
        cols = cols,
        rows = rows,
    }
end

-- Draw checkerboard bg
function game_common.drawCheckerboard(x, y, w, h, cellSize, colorLight, colorDark)
    for row = 0, math.ceil(h / cellSize) - 1 do
        for col = 0, math.ceil(w / cellSize) - 1 do
            local color = ((row + col) % 2 == 0) and colorLight or colorDark
            love.graphics.setColor(color)
            love.graphics.rectangle("fill",
                x + col * cellSize,
                y + row * cellSize,
                cellSize, cellSize)
        end
    end
end

return game_common

