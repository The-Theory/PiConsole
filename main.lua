---@diagnostic disable: undefined-global

math.randomseed(os.time())

local Input = require("TiPiL.input")
local UI = require("TiPiL.ui")

-- Config
local LAUNCHER_CONFIG = {
    COLS_VISIBLE = 3,
    ROWS_VISIBLE = 2,
    INPUT_THRESHOLD = 0.6,
    CARD_SPACING = 18,
    -- Animation
    SELECTED_SCALE = 1.04,
    UNSELECTED_SCALE = 0.92,
    SCALE_ANIM_SPEED = 12.0,
    SELECTION_ANIM_DURATION = 0.15,
    -- Background grid
    GRID_SIZE = 20,
    GRID_SPEED = 8,
    GRID_Y_RATIO = 0.7,
    GRID_ALPHA = 0.025,
    -- Card visuals
    CARD_PADDING = 10,
    CARD_TITLE_OFFSET = 4,
    CARD_TITLE_BOTTOM = 26,
    CARD_GLOW_LAYERS = 8,
    CARD_GLOW_SPREAD = 18,
    CARD_GLOW_ALPHA = 0.06,
    CARD_BORDER_GLOW_LAYERS = 3,
    CARD_BORDER_GLOW_OFFSET = 1.5,
    CARD_BORDER_GLOW_ALPHA = 0.15,
    CARD_CORNER_SIZE = 4,
}

-- State
local input = nil
local ui = nil
local scenes = {}
local selectedIndex = 1
local currentSceneModuleName = nil
local thumbnails = {}

-- Fade transitions
local transition = {
    state = "none",  -- none | fading_out | fading_in | black
    progress = 0.0,
    duration = 0.3,  -- per phase
    pendingAction = nil,
}

-- Input state
local lastDir = { x = 0, y = 0 }

-- Animation state
local lastSelectedIndex = 1
local selectionTime = 0.0
local gridAnimTime = 0.0
local cardScales = {}

-- Layout
local tileDimensions = {}
local grid = {
    colsVisible = LAUNCHER_CONFIG.COLS_VISIBLE,
    rowsVisible = LAUNCHER_CONFIG.ROWS_VISIBLE,
    firstVisibleRow = 0
}

local function getThumbnail(info)
    local key = info.module
    local cached = thumbnails[key]
    if cached ~= nil then return cached end

    local _, img = pcall(love.graphics.newImage, info.assetBase .. "/icon.png")
    img:setFilter("nearest")
    thumbnails[key] = img
    return img
end

local function calculateTileDimensions()
    local w, h = ui:getScreen()
    local cardSpacing = LAUNCHER_CONFIG.CARD_SPACING
    local tileW = (w - ui.pad * 2 - cardSpacing * (grid.colsVisible - 1)) / grid.colsVisible
    local tileH = (h - ui.pad * 2 - cardSpacing * (grid.rowsVisible - 1)) / grid.rowsVisible
    
    tileDimensions = {
        width = tileW,
        height = tileH,
        originX = ui.pad,
        originY = ui.pad,
    }
end

local function scanGamesFolder()
    scenes = {}
    local files = love.filesystem.getDirectoryItems("games")
    table.sort(files)
    
    for _, file in ipairs(files) do
        if file:sub(1, 1) ~= "." then
            local path = "games/" .. file .. "/"
            local fileInfo = love.filesystem.getInfo(path .. "main.lua")
            table.insert(scenes, {
                name = file:gsub("_", " "):gsub("%f[%a].", string.upper),
                module = "games." .. file .. ".main",
                assetBase = path,
                implemented = fileInfo ~= nil
            })
        end
    end
end

local launch
local function launcher_load()
    ui = UI.new("Launcher")
    ui:setupWindow()
    love.window.setMode(480, 320, {msaa = 2, borderless = true})
    input = Input.new()

    calculateTileDimensions()
    scanGamesFolder()
end

local function updateTransition(dt)
    if transition.state == "none" then return end
    
    transition.progress = transition.progress + dt / transition.duration
    
    if transition.state == "fading_out" then
        if transition.progress >= 1.0 then
            transition.progress = 0.0
            transition.state = "black"
            
            if transition.pendingAction then
                transition.pendingAction()
                transition.pendingAction = nil
            end
            
            transition.state = "fading_in"
        end
    elseif transition.state == "fading_in" then
        if transition.progress >= 1.0 then
            transition.progress = 0.0
            transition.state = "none"
        end
    end
end

local function drawBackgroundGrid()
    local w, h = ui:getScreen()
    love.graphics.setColor(1, 1, 1, LAUNCHER_CONFIG.GRID_ALPHA)
    
    local gridSize = LAUNCHER_CONFIG.GRID_SIZE
    local speed = LAUNCHER_CONFIG.GRID_SPEED
    local offsetX = (gridAnimTime * speed) % gridSize
    local offsetY = (gridAnimTime * speed * LAUNCHER_CONFIG.GRID_Y_RATIO) % gridSize
    
    for gx = -gridSize + offsetX, w + gridSize, gridSize do
        love.graphics.line(gx, 0, gx, h)
    end
    for gy = -gridSize + offsetY, h + gridSize, gridSize do
        love.graphics.line(0, gy, w, gy)
    end
end

local function drawCardGlow(x, y, cardW, cardH, easeOut)
    local glowLayers = LAUNCHER_CONFIG.CARD_GLOW_LAYERS
    local glowSpread = LAUNCHER_CONFIG.CARD_GLOW_SPREAD
    
    for layer = glowLayers, 1, -1 do
        local t = layer / glowLayers
        local expand = glowSpread * t
        local alpha = LAUNCHER_CONFIG.CARD_GLOW_ALPHA * (1 - t * t) * easeOut
        love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], alpha)
        love.graphics.rectangle("fill", x - expand, y - expand, cardW + expand * 2, cardH + expand * 2, 4, 4)
    end
end

local function drawCardBorderGlow(x, y, cardW, cardH)
    for layer = 1, LAUNCHER_CONFIG.CARD_BORDER_GLOW_LAYERS do
        local glowAlpha = LAUNCHER_CONFIG.CARD_BORDER_GLOW_ALPHA / layer
        local glowOffset = layer * LAUNCHER_CONFIG.CARD_BORDER_GLOW_OFFSET
        love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], glowAlpha)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x - glowOffset, y - glowOffset, cardW + glowOffset * 2, cardH + glowOffset * 2, 0, 0)
    end
end

local function drawCard(info, i, x, y, cardW, cardH, isSel, easeOut)
    -- Glow layers
    if isSel then
        drawCardGlow(x, y, cardW, cardH, easeOut)
    end

    -- Shadow
    local shadowOffset = isSel and 6 or 4
    local shadowAlpha = isSel and 0.4 or 0.3
    love.graphics.setColor(0, 0, 0, shadowAlpha)
    love.graphics.rectangle("fill", x + shadowOffset, y + shadowOffset, cardW, cardH, 0, 0)
    
    -- Card background
    local bgBrightness = isSel and 0.16 or 0.13
    love.graphics.setColor(bgBrightness, bgBrightness, bgBrightness + 0.01, 1.0)
    love.graphics.rectangle("fill", x, y, cardW, cardH, 0, 0)
    
    -- Gradients
    love.graphics.setColor(0, 0, 0, 0.1)
    love.graphics.rectangle("fill", x, y + cardH * 0.6, cardW, cardH * 0.4, 0, 0)
    love.graphics.setColor(0, 0, 0, 0.05)
    love.graphics.rectangle("fill", x, y, cardW, cardH * 0.3, 0, 0)
    
    -- Border
    local borderWidth = isSel and 2 or 1
    local borderColor = isSel and UI.colors.primary or {0.25, 0.25, 0.26}
    local borderAlpha = isSel and 0.6 or 0.3
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderAlpha)
    love.graphics.setLineWidth(borderWidth)
    love.graphics.rectangle("line", x, y, cardW, cardH, 0, 0)
    love.graphics.setLineWidth(1)
    
    -- Corner accents
    if isSel then
        local cs = LAUNCHER_CONFIG.CARD_CORNER_SIZE
        love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.8)
        love.graphics.rectangle("fill", x, y, cs, cs, 0, 0)
        love.graphics.rectangle("fill", x + cardW - cs, y, cs, cs, 0, 0)
        love.graphics.rectangle("fill", x, y + cardH - cs, cs, cs, 0, 0)
        love.graphics.rectangle("fill", x + cardW - cs, y + cardH - cs, cs, cs, 0, 0)
    end

    -- Icon
    local padIn = LAUNCHER_CONFIG.CARD_PADDING
    local thumbX = x + padIn
    local thumbY = y + padIn + LAUNCHER_CONFIG.CARD_TITLE_OFFSET
    local thumbW = cardW - padIn * 2
    local thumbH = cardH - padIn * 2 - (LAUNCHER_CONFIG.CARD_TITLE_BOTTOM - LAUNCHER_CONFIG.CARD_TITLE_OFFSET)
    local thumb = getThumbnail(info)

    local iw, ih = thumb:getWidth(), thumb:getHeight()
    local scale = math.min(thumbW / iw, thumbH / ih)
    local dx = thumbX + (thumbW - iw * scale) * 0.5
    local dy = thumbY + (thumbH - ih * scale) * 0.5

    love.graphics.setColor(1, 1, 1, isSel and 0.95 or 0.85)
    love.graphics.draw(thumb, dx, dy, 0, scale, scale)

    -- Title
    local nameY = y + cardH - LAUNCHER_CONFIG.CARD_TITLE_BOTTOM
    love.graphics.setFont(ui.fonts.title)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.printf(info.name, x + 1, nameY + 1, cardW, "center")
    love.graphics.setColor(isSel and UI.colors.primaryBright or UI.colors.textDim)
    love.graphics.printf(info.name, x, nameY, cardW, "center")
    
    -- Hint text
    if isSel then
        local instructionY = nameY + ui.fonts.title:getHeight() + 8
        love.graphics.setFont(ui.fonts.small)
        love.graphics.setColor(UI.colors.textDimmer[1], UI.colors.textDimmer[2], UI.colors.textDimmer[3], 0.7)
        love.graphics.printf("Press A to launch", x, instructionY, cardW, "center")
    end

    -- Border glow
    if isSel then
        drawCardBorderGlow(x, y, cardW, cardH)
    end
end

local function drawTransition()
    if transition.state == "none" or not ui then return end
    
    love.graphics.origin()  -- screen coords
    
    local w, h = ui:getScreen()
    local alpha = 0.0
    
    if transition.state == "fading_out" then
        alpha = transition.progress
    elseif transition.state == "black" then
        alpha = 1.0
    elseif transition.state == "fading_in" then
        alpha = 1.0 - transition.progress
    end
    
    if alpha > 0 then
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
end

local function updateCardScales(dt)
    for i = 1, #scenes do
        local target = (i == selectedIndex) and LAUNCHER_CONFIG.SELECTED_SCALE or LAUNCHER_CONFIG.UNSELECTED_SCALE
        local current = cardScales[i] or LAUNCHER_CONFIG.UNSELECTED_SCALE
        local newScale = current + (target - current) * (1 - math.exp(-LAUNCHER_CONFIG.SCALE_ANIM_SPEED * dt))
        
        if math.abs(newScale - target) < 0.001 then
            newScale = target
        end
        
        cardScales[i] = newScale
    end
end

local function handleInput()
    local worldX, worldY = input:getAxis()
    local threshold = LAUNCHER_CONFIG.INPUT_THRESHOLD
    local dirX = 0
    local dirY = 0
    
    if worldX > threshold then
        dirX = 1
    elseif worldX < -threshold then
        dirX = -1
    end
    
    if worldY > threshold then
        dirY = 1
    elseif worldY < -threshold then
        dirY = -1
    end

    -- Edge trigger only
    if dirX ~= 0 and lastDir.x == 0 then
        if dirX > 0 then
            selectedIndex = math.min(#scenes, selectedIndex + 1)
        elseif dirX < 0 then
            selectedIndex = math.max(1, selectedIndex - 1)
        end
    end
    
    if dirY ~= 0 and lastDir.y == 0 then
        if dirY > 0 then
            selectedIndex = math.min(#scenes, selectedIndex + grid.colsVisible)
        elseif dirY < 0 then
            selectedIndex = math.max(1, selectedIndex - grid.colsVisible)
        end
    end
    
    lastDir.x = dirX
    lastDir.y = dirY

    if input:isButtonPressed("a") then
        launch(selectedIndex)
    end
end

local function launcher_update(dt)
    updateTransition(dt)
    if transition.state ~= "none" then return end
    
    if not input then return end
    input:update(dt)
    
    -- Selection animation
    if selectedIndex ~= lastSelectedIndex then
        selectionTime = 0.0
        lastSelectedIndex = selectedIndex
    else
        selectionTime = selectionTime + dt
    end
    
    updateCardScales(dt)
    gridAnimTime = gridAnimTime + dt
    handleInput()

    if love.keyboard.isDown("escape") then
        love.event.quit()
    end
end

local function updateGridScroll()
    local selRow = math.floor((selectedIndex - 1) / grid.colsVisible)
    if selRow < grid.firstVisibleRow then
        grid.firstVisibleRow = selRow
    elseif selRow > grid.firstVisibleRow + grid.rowsVisible - 1 then
        grid.firstVisibleRow = selRow - (grid.rowsVisible - 1)
    end
end

local function launcher_draw()
    if not ui then return end
    
    ui:clear()
    drawBackgroundGrid()
    updateGridScroll()
    
    -- Glow ease
    local animProgress = math.min(selectionTime / LAUNCHER_CONFIG.SELECTION_ANIM_DURATION, 1.0)
    local easeOut = 1.0 - (1.0 - animProgress) ^ 3
    
    -- Draw game cards
    for r = 0, grid.rowsVisible - 1 do
        for c = 0, grid.colsVisible - 1 do
            local i = (grid.firstVisibleRow + r) * grid.colsVisible + c + 1
            if i > #scenes then break end

            local info = scenes[i]
            local cardSpacing = LAUNCHER_CONFIG.CARD_SPACING
            local baseX = tileDimensions.originX + c * (tileDimensions.width + cardSpacing)
            local baseY = tileDimensions.originY + r * (tileDimensions.height + cardSpacing)
            local isSel = i == selectedIndex

            local cardScale = cardScales[i] or LAUNCHER_CONFIG.UNSELECTED_SCALE
            local cardW = tileDimensions.width * cardScale
            local cardH = tileDimensions.height * cardScale
            local x = baseX - (cardW - tileDimensions.width) * 0.5
            local y = baseY - (cardH - tileDimensions.height) * 0.5

            drawCard(info, i, x, y, cardW, cardH, isSel, easeOut)
        end
    end
    
    drawTransition()
end

local function returnToLauncher()
    if transition.state ~= "none" then return end
    
    transition.pendingAction = function()
        -- Cleanup
        if currentSceneModuleName then
            local mod = package.loaded[currentSceneModuleName]
            if type(mod) == "table" and type(mod.unload) == "function" then
                pcall(mod.unload)
            end
            package.loaded[currentSceneModuleName] = nil
            currentSceneModuleName = nil
            collectgarbage("collect")
        end

        -- Reset
        if input then input:reset() end
        lastDir = { x = 0, y = 0 }

        -- Back to launcher
        love.update = launcher_update
        love.draw = launcher_draw
    end
    
    transition.state = "fading_out"
    transition.progress = 0.0
end

function launch(index)
    local info = scenes[index]
    if not info.implemented then return end
    if transition.state ~= "none" then return end
    
    transition.pendingAction = function()
        currentSceneModuleName = info.module
        local scene = require(info.module)
        if scene.load then scene.load() end

        love.update = function(dt)
            updateTransition(dt)
            if transition.state == "none" and scene.update then 
                scene.update(dt) 
            end
        end

        love.draw = function()
            if scene.draw then scene.draw() end
            drawTransition()
        end
    end
    
    transition.state = "fading_out"
    transition.progress = 0.0
end

-- Love2D callbacks
function love.load()        launcher_load() end
function love.update(dt)    launcher_update(dt) end
function love.draw()        launcher_draw() end

-- Export
local M = { returnToLauncher = returnToLauncher }
package.loaded["main"] = M
return M
