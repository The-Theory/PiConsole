---@diagnostic disable: undefined-global

local Input = require("TiPiL.input")
local UI = require("TiPiL.ui")
local utils = require("TiPiL.utils")
local game_common = require("TiPiL.game_common")

local Scene = {}

local input, ui

-- Joystick display
local joystickDisplay = {
    centerX = 0,
    centerY = 0,
    radius = 60,
    dotRadius = 8,
}

-- Button positions
local buttonPositions = {
    a = { x = 0, y = 0, label = "A", key = "kp2" },
    b = { x = 0, y = 0, label = "B", key = "kp6" },
    x = { x = 0, y = 0, label = "X", key = "kp4" },
    y = { x = 0, y = 0, label = "Y", key = "kp8" },
    menu = { x = 0, y = 0, label = "MENU", key = "kp0" },
    stick = { x = 0, y = 0, label = "STICK", key = "kp1" },
}

-- Input history
local inputHistory = {
    axis = { x = 0, y = 0 },
    buttons = { a = false, b = false, x = false, y = false, menu = false, stick = false },
}

-- Menu return delay
local menuReturnTimer = 0
local menuReturnDelay = 0.15  -- Show press before returning

-- Anim state
local animations = {
    dotX = 0,
    dotY = 0,
    buttons = {
        a = { scale = 1.0, glow = 0.0, pressTimer = 0 },
        b = { scale = 1.0, glow = 0.0, pressTimer = 0 },
        x = { scale = 1.0, glow = 0.0, pressTimer = 0 },
        y = { scale = 1.0, glow = 0.0, pressTimer = 0 },
        menu = { scale = 1.0, glow = 0.0, pressTimer = 0 },
        stick = { scale = 1.0, glow = 0.0, pressTimer = 0 },
    },
    dotColor = { r = 0, g = 0, b = 0, a = 0 },
}


function Scene.load()
    input = Input.new()
    ui = UI.new("Input Test")
    ui:setupWindow()
    
    local w, h = ui:getScreen()
    
    -- Position joystick (center-left)
    joystickDisplay.centerX = w * 0.3
    joystickDisplay.centerY = h * 0.45
    
    -- Position buttons (2x3 grid, right side)
    local buttonStartX = w * 0.65
    local buttonStartY = h * 0.3
    local buttonSpacing = 70
    
    -- Row 1
    buttonPositions.a.x = buttonStartX
    buttonPositions.a.y = buttonStartY
    buttonPositions.b.x = buttonStartX + buttonSpacing
    buttonPositions.b.y = buttonStartY
    
    -- Row 2
    buttonPositions.x.x = buttonStartX
    buttonPositions.x.y = buttonStartY + buttonSpacing
    buttonPositions.y.x = buttonStartX + buttonSpacing
    buttonPositions.y.y = buttonStartY + buttonSpacing
    
    -- Row 3
    buttonPositions.menu.x = buttonStartX
    buttonPositions.menu.y = buttonStartY + buttonSpacing * 2
    buttonPositions.stick.x = buttonStartX + buttonSpacing
    buttonPositions.stick.y = buttonStartY + buttonSpacing * 2
    
    -- Init anim positions
    animations.dotX = joystickDisplay.centerX
    animations.dotY = joystickDisplay.centerY
end

function Scene.update(dt)
    input:update(dt)
    
    -- Update input history
    local worldX, worldY = input:getAxis()
    inputHistory.axis.x = worldX
    inputHistory.axis.y = worldY
    
    -- Update button states
    inputHistory.buttons.a = input:isButtonDown("a")
    inputHistory.buttons.b = input:isButtonDown("b")
    inputHistory.buttons.x = input:isButtonDown("x")
    inputHistory.buttons.y = input:isButtonDown("y")
    inputHistory.buttons.menu = input:isButtonDown("menu")
    inputHistory.buttons.stick = input:isButtonDown("stick")
    
    -- Check menu press, delay return
    if input:isMenuPressed() and menuReturnTimer == 0 then
        menuReturnTimer = menuReturnDelay
        -- Force menu pressed
        inputHistory.buttons.menu = true
    end
    
    -- Update menu timer
    if menuReturnTimer > 0 then
        menuReturnTimer = menuReturnTimer - dt
        if menuReturnTimer <= 0 then
            -- Return to launcher
            local launcher = require("main")
            if launcher and launcher.returnToLauncher then
                launcher.returnToLauncher()
                return
            end
        end
    else
        -- Normal menu handling
        if game_common.handleStandardInput(input) then
            return
        end
    end
    
    -- Store prev button states
    local prevButtons = {
        a = inputHistory.buttons.a,
        b = inputHistory.buttons.b,
        x = inputHistory.buttons.x,
        y = inputHistory.buttons.y,
        menu = inputHistory.buttons.menu,
        stick = inputHistory.buttons.stick,
    }
    
    -- Animate joystick dot
    local w, h = ui:getScreen()
    local radius = joystickDisplay.radius
    local panelPadding = 30
    local buttonPanelPadding = 25
    
    -- Calc button panel dims
    local minButtonY = buttonPositions.a.y
    local maxButtonY = buttonPositions.stick.y
    local buttonPanelH = (maxButtonY - minButtonY) + buttonPanelPadding * 2
    local joystickPanelH = (radius + panelPadding) * 2
    local panelH = math.max(joystickPanelH, buttonPanelH)
    local panelY = h * 0.5 - panelH * 0.5
    
    -- Use same jy calc as draw
    local jx = joystickDisplay.centerX
    local jy = panelY + panelH * 0.5
    
    local targetX = jx + worldX * radius * 0.9
    local targetY = jy + worldY * radius * 0.9
    local lerpFactor = 0.25
    animations.dotX = utils.lerp(animations.dotX, targetX, lerpFactor)
    animations.dotY = utils.lerp(animations.dotY, targetY, lerpFactor)
    
    -- Animate dot color
    local isActive = (worldX ~= 0 or worldY ~= 0)
    local targetColor = isActive and UI.colors.primaryBright or UI.colors.textDim
    local colorLerp = 0.15
    animations.dotColor.r = utils.lerp(animations.dotColor.r, targetColor[1], colorLerp)
    animations.dotColor.g = utils.lerp(animations.dotColor.g, targetColor[2], colorLerp)
    animations.dotColor.b = utils.lerp(animations.dotColor.b, targetColor[3], colorLerp)
    animations.dotColor.a = utils.lerp(animations.dotColor.a, targetColor[4] or 1, colorLerp)
    
    -- Update button anims
    for buttonName, anim in pairs(animations.buttons) do
        local isPressed = inputHistory.buttons[buttonName]
        local wasPressed = prevButtons[buttonName]
        
        -- Detect press
        if isPressed and not wasPressed then
            anim.pressTimer = 0.3  -- Glow time
        end
        
        -- Update timer
        if anim.pressTimer > 0 then
            anim.pressTimer = math.max(0, anim.pressTimer - dt)
        end
        
        -- Animate scale
        local targetScale = isPressed and 1.1 or 1.0
        local scaleLerp = isPressed and 0.3 or 0.2
        anim.scale = utils.lerp(anim.scale, targetScale, scaleLerp)
        
        -- Animate glow
        local targetGlow = (anim.pressTimer > 0) and 1.0 or 0.0
        local glowLerp = 0.2
        anim.glow = utils.lerp(anim.glow, targetGlow, glowLerp)
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
    
    -- Title
    love.graphics.setFont(ui.fonts.title)
    local titleText = "Input Test"
    local titleW = ui.fonts.title:getWidth(titleText)
    local titleX = (w - titleW) / 2
    local titleY = 20
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(titleText, titleX + 1, titleY + 1)
    love.graphics.setColor(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], UI.colors.text[4])
    love.graphics.print(titleText, titleX, titleY)
    
    
    -- Calc panel dims
    local radius = joystickDisplay.radius
    local panelPadding = 30
    
    -- Calc button panel
    local minButtonX = buttonPositions.a.x
    local maxButtonX = buttonPositions.b.x
    local minButtonY = buttonPositions.a.y
    local maxButtonY = buttonPositions.stick.y
    local buttonPanelPadding = 25
    local buttonPanelW = (maxButtonX - minButtonX) + buttonPanelPadding * 2
    local buttonPanelH = (maxButtonY - minButtonY) + buttonPanelPadding * 2
    
    -- Calc joystick panel
    local joystickPanelW = (radius + panelPadding) * 2
    local joystickPanelH = (radius + panelPadding) * 2
    
    -- Use max height for both
    local panelH = math.max(joystickPanelH, buttonPanelH)
    
    -- Align panels (centered)
    local panelY = h * 0.5 - panelH * 0.5
    
    -- Joystick panel
    local panelX = joystickDisplay.centerX - radius - panelPadding
    local panelW = joystickPanelW
    
    -- Center joystick in panel
    local jx = joystickDisplay.centerX
    local jy = panelY + panelH * 0.5
    
    -- Shadow
    local panelShadow = 6
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", panelX + panelShadow, panelY + panelShadow, panelW, panelH, 0, 0)
    
    -- Bg
    love.graphics.setColor(0.12, 0.12, 0.14, 1)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 0, 0)
    
    -- Border
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 0, 0)
    love.graphics.setLineWidth(1)
    
    -- Corner decals
    local cornerSize = 4
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.8)
    love.graphics.rectangle("fill", panelX, panelY, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", panelX + panelW - cornerSize, panelY, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", panelX, panelY + panelH - cornerSize, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", panelX + panelW - cornerSize, panelY + panelH - cornerSize, cornerSize, cornerSize, 0, 0)
    
    -- Joystick circle
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.circle("fill", jx + 2, jy + 2, radius)
    love.graphics.setColor(0.18, 0.18, 0.20, 1)
    love.graphics.circle("fill", jx, jy, radius)
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", jx, jy, radius)
    love.graphics.setLineWidth(1)
    
    -- Crosshair
    love.graphics.setColor(0.3, 0.3, 0.35, 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(jx - radius * 0.3, jy, jx + radius * 0.3, jy)
    love.graphics.line(jx, jy - radius * 0.3, jx, jy + radius * 0.3)
    
    -- Use animated dot pos
    local dotX = animations.dotX
    local dotY = animations.dotY
    
    -- Draw dot
    local dotRadius = joystickDisplay.dotRadius
    local dotColor = animations.dotColor
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.circle("fill", dotX + 1, dotY + 1, dotRadius)
    
    -- Fill
    love.graphics.setColor(dotColor.r, dotColor.g, dotColor.b, dotColor.a)
    love.graphics.circle("fill", dotX, dotY, dotRadius)
    
    -- Border
    love.graphics.setColor(dotColor.r * 1.2, dotColor.g * 1.2, dotColor.b * 1.2, 0.8)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", dotX, dotY, dotRadius)
    love.graphics.setLineWidth(1)
    
    
    -- Button panel
    local buttonPanelX = minButtonX - buttonPanelPadding
    local buttonPanelY = panelY
    local buttonPanelH = panelH
    
    -- Center buttons in panel
    local buttonCenterY = buttonPanelY + buttonPanelH * 0.5
    local buttonOffsetY = buttonCenterY - (minButtonY + maxButtonY) * 0.5
    
    -- Shadow
    local buttonPanelShadow = 6
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", buttonPanelX + buttonPanelShadow, buttonPanelY + buttonPanelShadow, buttonPanelW, buttonPanelH, 0, 0)
    
    -- Bg
    love.graphics.setColor(0.12, 0.12, 0.14, 1)
    love.graphics.rectangle("fill", buttonPanelX, buttonPanelY, buttonPanelW, buttonPanelH, 0, 0)
    
    -- Border
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", buttonPanelX, buttonPanelY, buttonPanelW, buttonPanelH, 0, 0)
    love.graphics.setLineWidth(1)
    
    -- Corner decals
    love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.8)
    love.graphics.rectangle("fill", buttonPanelX, buttonPanelY, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", buttonPanelX + buttonPanelW - cornerSize, buttonPanelY, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", buttonPanelX, buttonPanelY + buttonPanelH - cornerSize, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", buttonPanelX + buttonPanelW - cornerSize, buttonPanelY + buttonPanelH - cornerSize, cornerSize, cornerSize, 0, 0)
    
    -- Draw buttons
    love.graphics.setFont(ui.fonts.medium)
    for buttonName, pos in pairs(buttonPositions) do
        local isPressed = inputHistory.buttons[buttonName]
        local isKeyDown = love.keyboard.isDown(pos.key)
        local isActive = isPressed or isKeyDown
        
        local anim = animations.buttons[buttonName]
        local baseSize = 40
        local buttonSize = baseSize * anim.scale
        -- Apply vertical offset
        local buttonX = pos.x - buttonSize / 2
        local buttonY = pos.y + buttonOffsetY - buttonSize / 2
        
        -- Glow when pressed
        if anim.glow > 0 then
            local glowAlpha = anim.glow * 0.3
            local glowSize = buttonSize + anim.glow * 8
            local glowX = pos.x - glowSize / 2
            local glowY = pos.y - glowSize / 2
            love.graphics.setColor(UI.colors.primaryBright[1], UI.colors.primaryBright[2], UI.colors.primaryBright[3], glowAlpha)
            love.graphics.rectangle("fill", glowX, glowY, glowSize, glowSize, 0, 0)
        end
        
        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", buttonX + 2, buttonY + 2, buttonSize, buttonSize, 0, 0)
        
        -- Bg
        local bgColor = isActive and UI.colors.primaryBright or {0.2, 0.2, 0.25}
        love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], isActive and 0.4 or 0.3)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonSize, buttonSize, 0, 0)
        
        -- Border
        local borderColor = isActive and UI.colors.primaryBright or UI.colors.textDimmer
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], isActive and 0.8 or 0.5)
        love.graphics.setLineWidth(isActive and 2 or 1)
        love.graphics.rectangle("line", buttonX, buttonY, buttonSize, buttonSize, 0, 0)
        love.graphics.setLineWidth(1)
        
        -- Corner accents (active)
        if isActive then
            local accentSize = 4 * anim.scale
            love.graphics.setColor(UI.colors.primaryBright[1], UI.colors.primaryBright[2], UI.colors.primaryBright[3], 0.9)
            love.graphics.rectangle("fill", buttonX, buttonY, accentSize, accentSize, 0, 0)
            love.graphics.rectangle("fill", buttonX + buttonSize - accentSize, buttonY, accentSize, accentSize, 0, 0)
            love.graphics.rectangle("fill", buttonX, buttonY + buttonSize - accentSize, accentSize, accentSize, 0, 0)
            love.graphics.rectangle("fill", buttonX + buttonSize - accentSize, buttonY + buttonSize - accentSize, accentSize, accentSize, 0, 0)
        end
        
        -- Label
        love.graphics.setColor(0, 0, 0, 0.5)
        local labelW = ui.fonts.medium:getWidth(pos.label)
        local labelY = pos.y + buttonOffsetY - 8
        love.graphics.print(pos.label, pos.x - labelW / 2 + 1, labelY + 1)
        love.graphics.setColor(isActive and UI.colors.text or UI.colors.textDim)
        love.graphics.print(pos.label, pos.x - labelW / 2, labelY)
    end
end

return Scene

