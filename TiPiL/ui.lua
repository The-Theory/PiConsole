---@diagnostic disable: undefined-global

local UI = {}
UI.__index = UI

-- Colors
UI.colors = {
    background = {0.08, 0.08, 0.09},
    text = {0.95, 0.96, 0.98},
    textDim = {0.7, 0.72, 0.75},
    textDimmer = {0.6, 0.62, 0.65},
    grid = {1, 1, 1, 0.02},
    primary = {0.2, 0.65, 0.9},
    primaryBright = {0.2, 0.75, 0.95},
    success = {0.2, 0.85, 0.5},
    warning = {0.95, 0.75, 0.2},
    danger = {0.95, 0.35, 0.35},
    dangerGlow = {0.95, 0.35, 0.35, 0.3},
    shadow = {0, 0, 0, 0.25},
    overlay = {0, 0, 0, 0.7},
}

-- New UI handler
function UI.new(title)
    local self = setmetatable({}, UI)
    
    self.title = title or "Game"
    self.pad = 8
    
    -- Fonts
    local fontPath = "TiPiL/editundo_font.ttf"
    local function loadFont(size)
        local success, font = pcall(love.graphics.newFont, fontPath, size)
        return success and font or love.graphics.newFont(size)
    end
    
    self.fonts = {
        title = loadFont(22),
        large = loadFont(18),
        medium = loadFont(14),
        small = loadFont(11),
    }
    
    return self
end

-- Setup window
function UI:setupWindow()
    love.graphics.setDefaultFilter("linear", "linear", 1)
end

-- Virtual world sizing (world↔screen)
function UI:setVirtualSize(worldW, worldH)
	-- Store virtual size, calc scale/offsets for letterboxing
	self.virtual = self.virtual or { w = 0, h = 0, scale = 1, ox = 0, oy = 0 }
	self.virtual.w, self.virtual.h = worldW, worldH
	local sw, sh = self:getScreen()
	local sx, sy = sw / worldW, sh / worldH
	local scale = math.min(sx, sy)
	self.virtual.scale = scale
	self.virtual.ox = (sw - worldW * scale) * 0.5
	self.virtual.oy = (sh - worldH * scale) * 0.5
	return self.virtual.scale, self.virtual.ox, self.virtual.oy
end

function UI:applyVirtual()
	if not self.virtual or self.virtual.w == 0 or self.virtual.h == 0 then return end
	love.graphics.push()
	love.graphics.translate(self.virtual.ox, self.virtual.oy)
	love.graphics.scale(self.virtual.scale, self.virtual.scale)
end

function UI:resetTransform()
	love.graphics.pop()
end

function UI:beginWorld(worldW, worldH)
	self:setVirtualSize(worldW, worldH)
	self:applyVirtual()
end

function UI:endWorld()
	self:resetTransform()
end

function UI:toScreen(wx, wy)
	if not self.virtual then return wx, wy end
	return self.virtual.ox + wx * self.virtual.scale, self.virtual.oy + wy * self.virtual.scale
end

function UI:toWorld(sx, sy)
	if not self.virtual then return sx, sy end
	return (sx - self.virtual.ox) / self.virtual.scale, (sy - self.virtual.oy) / self.virtual.scale
end

-- Get screen size
function UI:getScreen()
    return love.graphics.getWidth(), love.graphics.getHeight()
end

-- Get content area
function UI:getContentArea()
    local w, h = self:getScreen()
    return self.pad,  self.pad,
           w - self.pad * 2, h - self.pad * 2
end

-- Draw shadowed rect
function UI:drawShadowRect(x, y, w, h, radius, shadowOffset, shadowAlpha)
    radius = radius or 8
    shadowOffset = shadowOffset or 3
    shadowAlpha = shadowAlpha or 0.25
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, shadowAlpha)
    love.graphics.rectangle("fill", x + shadowOffset, y + shadowOffset, w, h, radius, radius)
    
    -- Main rect
    love.graphics.setColor(0.13, 0.13, 0.14, 1.0)
    love.graphics.rectangle("fill", x, y, w, h, radius, radius)
end

-- Draw grid bg
function UI:drawGrid(x, y, w, h, cellSize)
    cellSize = cellSize or 20
    love.graphics.setColor(UI.colors.grid)
    
    -- Vertical
    for gx = x, x + w, cellSize do
        love.graphics.line(gx, y, gx, y + h)
    end
    
    -- Horizontal
    for gy = y, y + h, cellSize do
        love.graphics.line(x, gy, x + w, gy)
    end
    
    -- Center lines
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.line(x + w/2, y, x + w/2, y + h)
    love.graphics.line(x, y + h/2, x + w, y + h/2)
end

-- Draw text w/ shadow
function UI:drawTextShadow(text, x, y, font, color, shadowOffset)
    font = font or self.fonts.large
    color = color or UI.colors.text
    shadowOffset = shadowOffset or 1
    
    love.graphics.setFont(font)
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(text, x + shadowOffset, y + shadowOffset)
    
    -- Text
    love.graphics.setColor(color)
    love.graphics.print(text, x, y)
end

-- Draw overlay (legacy)
function UI:drawOverlay(title, subtitle, color)
    self:drawGameOver()
end

-- Draw game over screen
function UI:drawGameOver(borderColor)
    local w, h = self:getScreen()
    borderColor = borderColor or UI.colors.danger
    
    -- Overlay
    local overlayAlpha = 0.9
    love.graphics.setColor(0, 0, 0, overlayAlpha)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    -- Panel
    local panelW = math.min(400, w * 0.85)
    local panelH = 200
    local panelX = (w - panelW) / 2
    local panelY = (h - panelH) / 2
    
    -- Shadow
    local panelShadow = 8
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", panelX + panelShadow, panelY + panelShadow, panelW, panelH, 0, 0)
    
    -- Bg
    love.graphics.setColor(0.12, 0.12, 0.14, 1)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 0, 0)
    
    -- Border
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 0, 0)
    love.graphics.setLineWidth(1)
    
    -- Corner decals
    local cornerSize = 6
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 0.9)
    love.graphics.rectangle("fill", panelX, panelY, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", panelX + panelW - cornerSize, panelY, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", panelX, panelY + panelH - cornerSize, cornerSize, cornerSize, 0, 0)
    love.graphics.rectangle("fill", panelX + panelW - cornerSize, panelY + panelH - cornerSize, cornerSize, cornerSize, 0, 0)
    
    -- Title
    love.graphics.setFont(self.fonts.title)
    local titleText = "GAME OVER"
    local titleW = self.fonts.title:getWidth(titleText)
    local titleX = panelX + (panelW - titleW) / 2
    local titleY = panelY + 60
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(titleText, titleX + 2, titleY + 2)
    
    -- Title
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 1)
    love.graphics.print(titleText, titleX, titleY)
    
    -- Restart text
    local restartText = "Press A to restart"
    love.graphics.setFont(self.fonts.large)
    local restartW = self.fonts.large:getWidth(restartText)
    local restartX = panelX + (panelW - restartW) / 2
    local restartY = panelY + 120
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(restartText, restartX + 2, restartY + 2)
    
    -- Restart
    love.graphics.setColor(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], UI.colors.text[4])
    love.graphics.print(restartText, restartX, restartY)
end

-- Draw score
function UI:drawScore(score, label, x, y, font)
    label = label or "Score"
    font = font or self.fonts.small
    
    love.graphics.setFont(font)
    love.graphics.setColor(UI.colors.textDim)
    love.graphics.print(label .. ": ", x, y)
    
    local labelWidth = font:getWidth(label .. ": ")
    love.graphics.setColor(UI.colors.text)
    love.graphics.print(tostring(score), x + labelWidth, y)
end

-- Clear screen
function UI:clear(color)
    if not color then color = UI.colors.background end
    love.graphics.clear(color)
end

return UI






