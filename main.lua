---@diagnostic disable: undefined-global

math.randomseed(os.time())

local Input = require("TiPiL.input")
local UI = require("TiPiL.ui")

local input = nil
local ui = nil

local scenes = {}
local selectedIndex = 1
local currentSceneModuleName = nil
local thumbnails = {}  -- Cached thumbnails

-- Constants
local LAUNCHER_CONFIG = {
    COLS_VISIBLE = 3,
    ROWS_VISIBLE = 2,
    INPUT_THRESHOLD = 0.6,
    CARD_SPACING = 18,  -- Space between cards
}

local lastDir = { x = 0, y = 0 }  -- Previous frame dir
local lastSelectedIndex = 1
local selectionTime = 0.0  -- For anim timing
local gridAnimTime = 0.0   -- BG grid anim
local cardScales = {}      -- Per-card scale

-- Grid
local tileDimensions = {}
local grid = {
    colsVisible = LAUNCHER_CONFIG.COLS_VISIBLE,
    rowsVisible = LAUNCHER_CONFIG.ROWS_VISIBLE,
    firstVisibleRow = 0    -- First row currently visible (for scrolling)
}

local function getThumbnail(info)
    local key = info.module
    local cached = thumbnails[key]

    -- Return cached result 
    if cached ~= nil then return cached end

    -- Find icon
    local _, img = pcall(love.graphics.newImage, info.assetBase .. "/icon.png")
    img:setFilter("nearest") 
    return img
end

local launch
local function launcher_load()
    -- UI and Input
    ui = UI.new("Launcher")
    ui:setupWindow()
    love.window.setMode(480, 320, {msaa = 2})
    input = Input.new()

    -- Tile dimensions
    local w, h = ui:getScreen()
    local cardSpacing = LAUNCHER_CONFIG.CARD_SPACING
    local tileW = (w - ui.pad * 2 - cardSpacing * (grid.colsVisible - 1)) / grid.colsVisible
    local tileH = (h - ui.pad * 2 - cardSpacing * (grid.rowsVisible - 1)) / grid.rowsVisible
    local originX = ui.pad
    local originY = ui.pad
    tileDimensions = {
        width = tileW,
        height = tileH,
        originX = originX,
        originY = originY,
    }

    -- Games
    scenes = {}
    local files = love.filesystem.getDirectoryItems("games")
    table.sort(files)
    for _, file in ipairs(files) do
        local path = "games/" .. file .. "/"
        local fileInfo = love.filesystem.getInfo(path .. "main.lua")

        -- Skip hidden files
        if (file:sub(1, 1) ~= ".") then
            table.insert(scenes, {
                name = file:gsub("_", " "):gsub("%f[%a].", string.upper),  -- Space to _ and capitalize
                module = "games." .. file .. ".main",
                assetBase = path,
                implemented = fileInfo ~= nil
            })
        end
    end
end

local function launcher_update(dt)
    -- Update input state
    if not input then return end
    input:update(dt)
    
    -- Reset anim on selection change
    if selectedIndex ~= lastSelectedIndex then
        selectionTime = 0.0
        lastSelectedIndex = selectedIndex
    else
        selectionTime = selectionTime + dt
    end
    
    -- Card scale anim
    local selectedScaleTarget = 1.04
    local unselectedScaleTarget = 0.92
    local animSpeed = 12.0
    
    for i = 1, #scenes do
        local target = (i == selectedIndex) and selectedScaleTarget or unselectedScaleTarget
        local current = cardScales[i] or unselectedScaleTarget
        
        -- Exp lerp
        local newScale = current + (target - current) * (1 - math.exp(-animSpeed * dt))
        
        -- Snap when close
        if math.abs(newScale - target) < 0.001 then
            newScale = target
        end
        
        cardScales[i] = newScale
    end
    
    gridAnimTime = gridAnimTime + dt
    
    local worldX, worldY = input:getAxis()
    local threshold = LAUNCHER_CONFIG.INPUT_THRESHOLD
    local dirX = 0
    local dirY = 0
    
    -- Joystick threshold check
    if      worldX > threshold then     dirX = 1
    elseif  worldX < -threshold then    dirX = -1 end
    ----
    if      worldY > threshold then     dirY = 1
    elseif  worldY < -threshold then    dirY = -1 end

    -- Move on edge trigger only
    -- Horiz
    if dirX ~= 0 and lastDir.x == 0 then
        if dirX > 0 then selectedIndex = math.min(#scenes, selectedIndex + 1)
        elseif dirX < 0 then selectedIndex = math.max(1, selectedIndex - 1) end
    end
    -- Vert
    if dirY ~= 0 and lastDir.y == 0 then
        if dirY > 0 then selectedIndex = math.min(#scenes, selectedIndex + grid.colsVisible) 
        elseif dirY < 0 then selectedIndex = math.max(1, selectedIndex - grid.colsVisible) end
    end
    
    -- Update last dir
    lastDir.x = dirX
    lastDir.y = dirY

    if input:isButtonPressed("a") then
        launch(selectedIndex)
    end

    if love.keyboard.isDown("escape") then
        love.event.quit()
    end
end

local function launcher_draw()
    if not ui then return end
    
    ui:clear()
    
    -- BG grid
    local w, h = ui:getScreen()
    love.graphics.setColor(1, 1, 1, 0.025)
    local gridSize = 20
    
    -- Drift offset
    local speed = 8
    local offsetX = (gridAnimTime * speed) % gridSize
    local offsetY = (gridAnimTime * speed * 0.7) % gridSize
    
    for gx = -gridSize + offsetX, w + gridSize, gridSize do
        love.graphics.line(gx, 0, gx, h)
    end
    for gy = -gridSize + offsetY, h + gridSize, gridSize do
        love.graphics.line(0, gy, w, gy)
    end
    
    -- Scroll
    local selRow = math.floor((selectedIndex - 1) / grid.colsVisible)
    if selRow < grid.firstVisibleRow then
        grid.firstVisibleRow = selRow
    end
    if selRow > grid.firstVisibleRow + grid.rowsVisible - 1 then
        grid.firstVisibleRow = selRow - (grid.rowsVisible - 1)
    end
    
    -- Glow easing
    local animDuration = 0.15
    local animProgress = math.min(selectionTime / animDuration, 1.0)
    local easeOut = 1.0 - (1.0 - animProgress) ^ 3
    
    -- Draw tiles
    for r = 0, grid.rowsVisible - 1 do
        for c = 0, grid.colsVisible - 1 do
            local i = (grid.firstVisibleRow + r) * grid.colsVisible + c + 1
            if i > #scenes then break end

            local info = scenes[i]
            local cardSpacing = LAUNCHER_CONFIG.CARD_SPACING
            local baseX = tileDimensions.originX + c * (tileDimensions.width + cardSpacing)
            local baseY = tileDimensions.originY + r * (tileDimensions.height + cardSpacing)
            local isSel = i == selectedIndex

            local cardScale = cardScales[i] or 0.92
            local cardW = tileDimensions.width * cardScale
            local cardH = tileDimensions.height * cardScale
            local x = baseX - (cardW - tileDimensions.width) * 0.5
            local y = baseY - (cardH - tileDimensions.height) * 0.5

            -- Glow
            if isSel then
                local glowLayers = 8
                local glowSpread = 18
                for layer = glowLayers, 1, -1 do
                    local t = layer / glowLayers
                    local expand = glowSpread * t
                    local alpha = 0.06 * (1 - t * t) * easeOut
                    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], alpha)
                    love.graphics.rectangle("fill", 
                        x - expand, y - expand, 
                        cardW + expand * 2, cardH + expand * 2, 
                        4, 4)
                end
            end

            -- Shadow
            local shadowOffset = isSel and 6 or 4
            local shadowAlpha = isSel and 0.4 or 0.3
            love.graphics.setColor(0, 0, 0, shadowAlpha)
            love.graphics.rectangle("fill", x + shadowOffset, y + shadowOffset, cardW, cardH, 0, 0)
            
            -- Card bg
            local bgBrightness = isSel and 0.16 or 0.13
            love.graphics.setColor(bgBrightness, bgBrightness, bgBrightness + 0.01, 1.0)
            love.graphics.rectangle("fill", x, y, cardW, cardH, 0, 0)
            
            -- Gradient overlay
            love.graphics.setColor(0, 0, 0, 0.1)
            love.graphics.rectangle("fill", x, y + cardH * 0.6, cardW, cardH * 0.4, 0, 0)
            love.graphics.setColor(0, 0, 0, 0.05)
            love.graphics.rectangle("fill", x, y, cardW, cardH * 0.3, 0, 0)
            
            -- Card border
            local borderWidth = isSel and 2 or 1
            local borderColor = isSel and UI.colors.primary or {0.25, 0.25, 0.26}
            local borderAlpha = isSel and 0.6 or 0.3
            love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderAlpha)
            love.graphics.setLineWidth(borderWidth)
            love.graphics.rectangle("line", x, y, cardW, cardH, 0, 0)
            love.graphics.setLineWidth(1)
            
            -- Corner accents
            if isSel then
                local cs = 4
                love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.8)
                love.graphics.rectangle("fill", x, y, cs, cs, 0, 0)                         -- TL
                love.graphics.rectangle("fill", x + cardW - cs, y, cs, cs, 0, 0)            -- TR
                love.graphics.rectangle("fill", x, y + cardH - cs, cs, cs, 0, 0)            -- BL
                love.graphics.rectangle("fill", x + cardW - cs, y + cardH - cs, cs, cs, 0, 0) -- BR
            end

            -- Thumb
            local padIn = 10
            local thumbX = x + padIn
            local thumbY = y + padIn + 4
            local thumbW = cardW - padIn * 2
            local thumbH = cardH - padIn * 2 - 28
            local thumb = getThumbnail(info)

            -- Fit + center
            local iw, ih = thumb:getWidth(), thumb:getHeight()
            local scale = math.min(thumbW / iw, thumbH / ih)
            local dx = thumbX + (thumbW - iw * scale) * 0.5
            local dy = thumbY + (thumbH - ih * scale) * 0.5

            love.graphics.setColor(1, 1, 1, isSel and 0.95 or 0.85)
            love.graphics.draw(thumb, dx, dy, 0, scale, scale)

            -- Name
            local nameY = y + cardH - 26
            love.graphics.setFont(ui.fonts.title)
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.printf(info.name, x + 1, nameY + 1, cardW, "center")
            love.graphics.setColor(isSel and UI.colors.primaryBright or UI.colors.textDim)
            love.graphics.printf(info.name, x, nameY, cardW, "center")
            
            -- Hint
            if isSel then
                local instructionY = nameY + ui.fonts.title:getHeight() + 8
                love.graphics.setFont(ui.fonts.small)
                love.graphics.setColor(UI.colors.textDimmer[1], UI.colors.textDimmer[2], UI.colors.textDimmer[3], 0.7)
                love.graphics.printf("Press A to launch", x, instructionY, cardW, "center")
            end

            -- Border glow
            if isSel then
                for layer = 1, 3 do
                    local glowAlpha = 0.15 / layer
                    local glowOffset = layer * 1.5
                    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], glowAlpha)
                    love.graphics.setLineWidth(1)
                    love.graphics.rectangle("line", 
                        x - glowOffset, y - glowOffset, 
                        cardW + glowOffset * 2, cardH + glowOffset * 2, 0, 0)
                end
            end
        end
    end
end

local function returnToLauncher()
    -- Cleanup game
    if currentSceneModuleName then
        local mod = package.loaded[currentSceneModuleName]

        if type(mod) == "table" and type(mod.unload) == "function" then
            pcall(mod.unload)
        end

        package.loaded[currentSceneModuleName] = nil
        currentSceneModuleName = nil
        collectgarbage("collect")
    end

    -- Reset state
    if input then input:reset() end
    lastDir = { x = 0, y = 0 }

    -- Restore callbacks
    love.update = launcher_update
    love.draw = launcher_draw
end

function launch(index)
    local info = scenes[index]
    if not info.implemented then return end

    currentSceneModuleName = info.module
    local scene = require(info.module)

    if scene.load then scene.load() end

    -- Override callbacks
    love.update = function(dt)
        if scene.update then scene.update(dt) end
    end

    love.draw = function()
        if scene.draw then scene.draw() end
    end
end

-- LOVE2D CALLBACKS
function love.load()        launcher_load() end
function love.update(dt)    launcher_update(dt) end
function love.draw()        launcher_draw() end

-- Export for games
local M = { returnToLauncher = returnToLauncher }
package.loaded["main"] = M
return M
