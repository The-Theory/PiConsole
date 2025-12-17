---@diagnostic disable: undefined-global

local Input = require("TiPiL.input")
local UI = require("TiPiL.ui")
local utils = require("TiPiL.utils")

local Scene = {}

local game_common = require("TiPiL.game_common")

local CONFIG = {
    tileSize = 30,
    baseSpeed = 0.12,
    speedIncrease = 0.008,
    speedUpEvery = 5,
    minSpeed = 0.04,
    smoothMovement = true,  -- Enable smooth sliding animation
    inputThreshold = game_common.THRESHOLDS.DIRECTION,
}

-- Colors
local COLORS = {
    bgPanel = {0.12, 0.12, 0.14, 1},
    gridBgLight = {0.18, 0.18, 0.20, 1},
    gridBgDark = {0.16, 0.16, 0.18, 1},
    checkerLight = {0.18, 0.18, 0.20, 1},     -- Dark theme light
    checkerDark = {0.16, 0.16, 0.18, 1},      -- Dark theme dark
    snakeHead = {0.2, 0.7, 0.95, 1},          -- Bright cyan
    snakeBody = {0.15, 0.6, 0.85, 1},         -- Slightly darker cyan
    appleRed = {0.95, 0.3, 0.3, 1},           -- Bright red
    appleStem = {0.3, 0.7, 0.3, 1},           -- Green stem
    eyeWhite = {1, 1, 1, 0.95},
    eyePupil = {0.1, 0.1, 0.15, 1},
}

local input, ui
local grid = { cols = 0, rows = 0, cell = 0, x = 0, y = 0, w = 0, h = 0 }
local snake = { body = {}, dir = {x = 1, y = 0} }
local food = { x = 0, y = 0, scale = 1, pulseTimer = 0 }
local game = {
    state = "playing",
    score = 0,
    highScore = 0,
    stepTimer = 0,
    stepInterval = CONFIG.baseSpeed,
    moveProgress = 0,  -- 0 to 1 for smooth animation
    blinkTimer = 0,
    blinkState = false,
    scorePopTimer = 0,
    deathShake = 0,
    prevHead = nil,
}

local function placeFood()
    repeat
        food.x = math.random(0, grid.cols - 1)
        food.y = math.random(0, grid.rows - 1)
        local collision = false
        for _, seg in ipairs(snake.body) do
            if seg.x == food.x and seg.y == food.y then
                collision = true
                break
            end
        end
    until not collision
    -- Reset food anim
    food.scale = 0  -- Start small for pop-in effect
    food.pulseTimer = 0
end

local function resetGame()
    snake.body = {}
    for i = 1, 3 do
        table.insert(snake.body, {x = math.floor(grid.cols/2), y = math.floor(grid.rows/2) + i})
    end
    snake.dir = {x = 1, y = 0}
    game.state = "playing"
    game.score = 0
    game.stepTimer = 0
    game.stepInterval = CONFIG.baseSpeed 
    game.moveProgress = 0
    game.blinkTimer = 0
    game.blinkState = false
    game.scorePopTimer = 0
    game.deathShake = 0
    game.prevHead = { x = snake.body[1].x, y = snake.body[1].y }
    placeFood()
end

local function updateSpeed()
    local level = math.floor(game.score / CONFIG.speedUpEvery)
    game.stepInterval = math.max(CONFIG.minSpeed, CONFIG.baseSpeed - level * CONFIG.speedIncrease)
end

local function moveSnake()
    if game.state ~= "playing" then return end
    
    -- Remember prev head
    local previousHead = { x = snake.body[1].x, y = snake.body[1].y }
    
    -- Calculate new head position (no wrapping)
    local newX = snake.body[1].x + snake.dir.x
    local newY = snake.body[1].y + snake.dir.y
    
    -- Check wall
    if newX < 0 or newX >= grid.cols or newY < 0 or newY >= grid.rows then
        game.state = "dead"
        game.highScore = math.max(game.highScore, game.score)
        return
    end
    
    local head = {
        x = newX,
        y = newY
    }
    
    -- Check self
    for _, seg in ipairs(snake.body) do
        if seg.x == head.x and seg.y == head.y then
            game.state = "dead"
            game.highScore = math.max(game.highScore, game.score)
            return
        end
    end
    
    -- Add head
    table.insert(snake.body, 1, head)
    game.prevHead = previousHead
    
    -- Check food
    if head.x == food.x and head.y == food.y then
        game.score = game.score + 1
        game.scorePopTimer = 0.5  -- Show +1
        updateSpeed()
        placeFood()
    else
        table.remove(snake.body)
    end
    
    -- Reset move progress
    game.moveProgress = 0
end

--[[═══════════════════════════════════════════════════════════════════════════
    SCENE CALLBACKS
═══════════════════════════════════════════════════════════════════════════════]]

function Scene.load()
    input = Input.new()
    ui = UI.new("Snake")
    ui:setupWindow()
    
    -- Calc grid size
    local w, h = ui:getScreen()
    
    -- Reserve sidebar space
    local sidebarWidth = math.max(110, w * 0.15)
    local availableWidth = w - sidebarWidth - 20  -- 20px padding
    
    grid.cols = math.floor(availableWidth / CONFIG.tileSize)
    grid.rows = math.floor(h / CONFIG.tileSize)
    
    -- Calc tile size
    grid.cell = math.floor(math.min(availableWidth / grid.cols, h / grid.rows))
    
    -- Calc grid dims
    grid.w = grid.cols * grid.cell
    grid.h = grid.rows * grid.cell
    grid.x = 10  -- Left padding
    grid.y = math.floor((h - grid.h) / 2)
    
    print(string.format("Screen: %dx%d, Grid: %dx%d cells, Tile: %dpx", w, h, grid.cols, grid.rows, grid.cell))
    
    resetGame()
end

function Scene.update(dt)
    input:update(dt)
    
    -- Standard input
    if game_common.handleStandardInput(input) then
        return
    end
    
    -- Update anims
    if game.state == "playing" or game.state == "dead" then
        -- Food pulse
        food.pulseTimer = food.pulseTimer + dt * 3
        food.scale = food.scale + (1 - food.scale) * dt * 8  -- Pop-in anim
        
        -- Eye blink
        game.blinkTimer = game.blinkTimer + dt
        if game.blinkTimer > 3 then  -- Blink every 3-5s
            game.blinkState = true
            if game.blinkTimer > 3.15 then  -- Blink 0.15s
                game.blinkState = false
                game.blinkTimer = math.random() * 2  -- Random delay
            end
        end
        
        -- Score popup
        if game.scorePopTimer > 0 then
            game.scorePopTimer = game.scorePopTimer - dt
        end
        
        -- Death shake
        if game.state == "dead" and game.deathShake < 0.5 then
            game.deathShake = game.deathShake + dt
        end
    end
    
    -- Move snake
    if game.state == "playing" then
        game.stepTimer = game.stepTimer + dt
        
        -- Smooth movement
        if CONFIG.smoothMovement then
            game.moveProgress = math.min(1, game.stepTimer / game.stepInterval)
        end
        
        if game.stepTimer >= game.stepInterval then
            game.stepTimer = game.stepTimer - game.stepInterval
            moveSnake()
        end
        
        -- Apply direction input
        local dx, dy = input:getDirection(CONFIG.inputThreshold)
        if dx ~= 0 or dy ~= 0 then
            -- Only change if valid
            if not (dx == snake.dir.x and dy == snake.dir.y) and
               not (dx == -snake.dir.x and dy == -snake.dir.y) then
                snake.dir = {x = dx, y = dy}
            end
        end
    end
    
    -- Reset input
    if game_common.handleResetInput(input, game.state, resetGame) then
        return
    end
end

-- Draw snake segment
local function drawSnakeSegment(x, y, size, color, isHead)
    local padding = 2
    local segmentSize = size - padding * 2
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", x + padding + 1, y + padding + 1, segmentSize, segmentSize, 0, 0)
    
    -- Main
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.rectangle("fill", x + padding, y + padding, segmentSize, segmentSize, 0, 0)
    
    -- Highlight gradient (lighter top)
    local highlight = {color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, 0.4}
    love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])
    love.graphics.rectangle("fill", x + padding, y + padding, segmentSize, segmentSize * 0.3, 0, 0)
    
    -- Dark gradient (darker bottom)
    local dark = {color[1] * 0.6, color[2] * 0.6, color[3] * 0.6, 0.3}
    love.graphics.setColor(dark[1], dark[2], dark[3], dark[4])
    love.graphics.rectangle("fill", x + padding, y + padding + segmentSize * 0.7, segmentSize, segmentSize * 0.3, 0, 0)
    
    -- Border
    love.graphics.setColor(color[1] * 1.2, color[2] * 1.2, color[3] * 1.2, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + padding, y + padding, segmentSize, segmentSize, 0, 0)
end

-- Draw apple
local function drawApple(x, y, size, scale)
    local padding = 3
    local appleSize = (size - padding * 2) * scale
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", x + padding + 1, y + padding + 1, appleSize, appleSize, 0, 0)
    
    -- Main body
    love.graphics.setColor(COLORS.appleRed[1], COLORS.appleRed[2], COLORS.appleRed[3], COLORS.appleRed[4])
    love.graphics.rectangle("fill", x + padding, y + padding, appleSize, appleSize, 0, 0)
    
    -- Highlight gradient (lighter top)
    local highlight = {COLORS.appleRed[1] * 1.3, COLORS.appleRed[2] * 1.3, COLORS.appleRed[3] * 1.3, 0.4}
    love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])
    love.graphics.rectangle("fill", x + padding, y + padding, appleSize, appleSize * 0.3, 0, 0)
    
    -- Dark gradient (darker bottom)
    local dark = {COLORS.appleRed[1] * 0.6, COLORS.appleRed[2] * 0.6, COLORS.appleRed[3] * 0.6, 0.3}
    love.graphics.setColor(dark[1], dark[2], dark[3], dark[4])
    love.graphics.rectangle("fill", x + padding, y + padding + appleSize * 0.7, appleSize, appleSize * 0.3, 0, 0)
    
    -- Border
    love.graphics.setColor(COLORS.appleRed[1] * 1.2, COLORS.appleRed[2] * 1.2, COLORS.appleRed[3] * 1.2, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + padding, y + padding, appleSize, appleSize, 0, 0)
    
    -- Draw stem
    if size >= 12 then
        local stemWidth = math.max(3, size / 5)
        local stemHeight = math.max(4, size / 4)
        local stemX = x + size / 2 - stemWidth / 2
        local stemY = y + padding - 1
        
        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", stemX + 1, stemY + 1, stemWidth, stemHeight, 0, 0)
        
        -- Stem
        love.graphics.setColor(COLORS.appleStem[1], COLORS.appleStem[2], COLORS.appleStem[3], COLORS.appleStem[4])
        love.graphics.rectangle("fill", stemX, stemY, stemWidth, stemHeight, 0, 0)
        
        -- Border
        love.graphics.setColor(COLORS.appleStem[1] * 0.7, COLORS.appleStem[2] * 0.7, COLORS.appleStem[3] * 0.7, 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", stemX, stemY, stemWidth, stemHeight, 0, 0)
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
    
    -- Grid panel
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
    
    -- Corner decals
    local cornerSize = 4
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.8)
    -- Top-left
    love.graphics.rectangle("fill", grid.x, grid.y, cornerSize, cornerSize, 0, 0)
    -- Top-right
    love.graphics.rectangle("fill", grid.x + grid.w - cornerSize, grid.y, cornerSize, cornerSize, 0, 0)
    -- Bottom-left
    love.graphics.rectangle("fill", grid.x, grid.y + grid.h - cornerSize, cornerSize, cornerSize, 0, 0)
    -- Bottom-right
    love.graphics.rectangle("fill", grid.x + grid.w - cornerSize, grid.y + grid.h - cornerSize, cornerSize, cornerSize, 0, 0)
    
    -- Death shake
    local shakeX, shakeY = 0, 0
    if game.deathShake > 0 and game.deathShake < 0.3 then
        local intensity = 5 * (1 - game.deathShake / 0.3)
        shakeX = (math.random() - 0.5) * intensity
        shakeY = (math.random() - 0.5) * intensity
    end
    
    -- Checkerboard
    love.graphics.setScissor(grid.x, grid.y, grid.w, grid.h)
    game_common.drawCheckerboard(grid.x, grid.y, grid.w, grid.h,
                                  grid.cell, COLORS.checkerLight, COLORS.checkerDark)
    
    -- Grid lines
    love.graphics.setColor(1, 1, 1, 0.05)
    for c = 0, grid.cols do
        local x = grid.x + c * grid.cell
        love.graphics.line(x, grid.y, x, grid.y + grid.h)
    end
    for r = 0, grid.rows do
        local y = grid.y + r * grid.cell
        love.graphics.line(grid.x, y, grid.x + grid.w, y)
    end
    
    -- Apple
    local foodPulse = math.sin(food.pulseTimer) * 0.08 + 1  -- Subtle bounce
    local foodScale = food.scale * foodPulse
    
    local appleX = grid.x + food.x * grid.cell
    local appleY = grid.y + food.y * grid.cell
    
    drawApple(appleX, appleY, grid.cell, foodScale)
    
    -- Snake
    local function drawSegment(i, seg, isHead)
        local color = isHead and COLORS.snakeHead or COLORS.snakeBody
        local drawX = seg.x
        local drawY = seg.y
        
        if isHead and CONFIG.smoothMovement and game.moveProgress < 1 then
            local prev = game.prevHead or { x = seg.x, y = seg.y }
            local dx = seg.x - prev.x
            local dy = seg.y - prev.y
            drawX = prev.x + dx * game.moveProgress
            drawY = prev.y + dy * game.moveProgress
        elseif not isHead and CONFIG.smoothMovement and game.moveProgress < 1 then
            local prevSeg = snake.body[i - 1]
            local dx = prevSeg.x - seg.x
            local dy = prevSeg.y - seg.y
            drawX = seg.x + dx * game.moveProgress
            drawY = seg.y + dy * game.moveProgress
        end
        
        drawX = drawX + shakeX / grid.cell
        drawY = drawY + shakeY / grid.cell
        
        local segmentX = grid.x + drawX * grid.cell
        local segmentY = grid.y + drawY * grid.cell
        
        drawSnakeSegment(segmentX, segmentY, grid.cell, color, isHead)
        
        if isHead and grid.cell >= 10 then
            -- Determine facing
            local fx, fy = snake.dir.x, snake.dir.y
            if CONFIG.smoothMovement and game.moveProgress < 1 and game.prevHead then
                local dx = seg.x - game.prevHead.x
                local dy = seg.y - game.prevHead.y
                fx, fy = utils.sign(dx), utils.sign(dy)
            elseif snake.body[2] then
                local dx = seg.x - snake.body[2].x
                local dy = seg.y - snake.body[2].y
                fx, fy = utils.sign(dx), utils.sign(dy)
            end
            local eyeSize = math.max(2, math.floor(grid.cell / 5))
            local pupilSize = math.max(1, math.floor(grid.cell / 8))
            local eyeOffset = math.max(3, math.floor(grid.cell / 3.5))
            
            local eye1X, eye1Y, eye2X, eye2Y
            local baseX = segmentX
            local baseY = segmentY
            
            if fx == 1 then
                eye1X = baseX + grid.cell - eyeOffset
                eye1Y = baseY + eyeOffset
                eye2X = eye1X
                eye2Y = baseY + grid.cell - eyeOffset
            elseif fx == -1 then
                eye1X = baseX + eyeOffset
                eye1Y = baseY + eyeOffset
                eye2X = eye1X
                eye2Y = baseY + grid.cell - eyeOffset
            elseif fy == 1 then
                eye1X = baseX + eyeOffset
                eye1Y = baseY + grid.cell - eyeOffset
                eye2X = baseX + grid.cell - eyeOffset
                eye2Y = eye1Y
            else
                eye1X = baseX + eyeOffset
                eye1Y = baseY + eyeOffset
                eye2X = baseX + grid.cell - eyeOffset
                eye2Y = eye1Y
            end
            
            if game.blinkState then
                love.graphics.setColor(COLORS.eyePupil)
                love.graphics.setLineWidth(2)
                love.graphics.line(eye1X - eyeSize, eye1Y, eye1X + eyeSize, eye1Y)
                love.graphics.line(eye2X - eyeSize, eye2Y, eye2X + eyeSize, eye2Y)
                love.graphics.setLineWidth(1)
            else
                love.graphics.setColor(COLORS.eyeWhite)
                love.graphics.circle("fill", eye1X, eye1Y, eyeSize)
                love.graphics.circle("fill", eye2X, eye2Y, eyeSize)
                love.graphics.setColor(COLORS.eyePupil)
                love.graphics.circle("fill", eye1X, eye1Y, pupilSize)
                love.graphics.circle("fill", eye2X, eye2Y, pupilSize)
            end
        end
    end
    
    for i = 2, #snake.body do
        drawSegment(i, snake.body[i], false)
    end
    if snake.body[1] then
        drawSegment(1, snake.body[1], true)
    end
    
    love.graphics.setScissor()
    
    -- Sidebar (score, high score, speed level)
    local sidebarPadding = 6
    local sidebarX = grid.x + grid.w + sidebarPadding
    local sidebarW = math.max(110, w - sidebarX - sidebarPadding)
    local sidebarH = grid.h
    local sidebarY = grid.y
    
    -- Shadow
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
    
    -- Corner decals
    local cornerSize = 4
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.8)
    -- Top-left
    love.graphics.rectangle("fill", sidebarX, sidebarY, cornerSize, cornerSize, 0, 0)
    -- Top-right
    love.graphics.rectangle("fill", sidebarX + sidebarW - cornerSize, sidebarY, cornerSize, cornerSize, 0, 0)
    -- Bottom-left
    love.graphics.rectangle("fill", sidebarX, sidebarY + sidebarH - cornerSize, cornerSize, cornerSize, 0, 0)
    -- Bottom-right
    love.graphics.rectangle("fill", sidebarX + sidebarW - cornerSize, sidebarY + sidebarH - cornerSize, cornerSize, cornerSize, 0, 0)
    
    local sectionY = sidebarY + 12
    
    -- Score
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
    
    -- High Score section
    sectionY = sectionY + 60
    love.graphics.setFont(ui.fonts.large)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print("High", sidebarX + 12, sectionY + 1)
    love.graphics.setColor(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], UI.colors.text[4])
    love.graphics.print("High", sidebarX + 12, sectionY)
    love.graphics.setFont(ui.fonts.title)
    love.graphics.setColor(UI.colors.warning[1], UI.colors.warning[2], UI.colors.warning[3], 1)
    love.graphics.print(tostring(game.highScore), sidebarX + 12, sectionY + 26)
    
    -- Divider
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.rectangle("fill", sidebarX + 8, sectionY + 58, sidebarW - 16, 1, 0, 0)
    
    -- Speed Level
    sectionY = sectionY + 60
    local speedLevel = math.floor(game.score / CONFIG.speedUpEvery) + 1
    love.graphics.setFont(ui.fonts.large)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print("Speed", sidebarX + 12, sectionY + 1)
    love.graphics.setColor(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], UI.colors.text[4])
    love.graphics.print("Speed", sidebarX + 12, sectionY)
    love.graphics.setFont(ui.fonts.title)
    love.graphics.setColor(UI.colors.success[1], UI.colors.success[2], UI.colors.success[3], 1)
    love.graphics.print(tostring(speedLevel), sidebarX + 12, sectionY + 26)
    
    -- Score pop animation
    if game.scorePopTimer > 0 then
        local alpha = game.scorePopTimer / 0.5  -- Fade out
        local offsetY = (1 - alpha) * 30  -- Float up
        local headSeg = snake.body[1]
        if headSeg then
            local text = "+1"
            local textW = ui.fonts.large:getWidth(text)
            local textX = grid.x + headSeg.x * grid.cell + grid.cell / 2 - textW / 2
            local textY = grid.y + headSeg.y * grid.cell - 10 - offsetY
            
            -- Shadow
            love.graphics.setColor(0, 0, 0, alpha * 0.5)
            love.graphics.setFont(ui.fonts.large)
            love.graphics.print(text, textX + 1, textY + 1)
            
            -- Text
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.print(text, textX, textY)
        end
    end
    
    -- Game over
    if game.state == "dead" then
        ui:drawGameOver(UI.colors.danger)
    end
end

return Scene
