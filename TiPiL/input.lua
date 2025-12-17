---@diagnostic disable: undefined-global

local Input = {}
Input.__index = Input

-- New input handler
function Input.new()
    local self = setmetatable({}, Input)
    
    self.joystick = { x = 512, y = 512 }
    self.world = { x = 0.0, y = 0.0 }
    self.readTimer = 0.0
    self.readInterval = 0.06
    
    -- Buttons
    self.buttons = { a = 0, b = 0, x = 0, y = 0, menu = 0, stick = 0 }
    self.lastButtons = { a = 0, b = 0, x = 0, y = 0, menu = 0, stick = 0 }
    self.keyboardButtons = { a = 0, b = 0, x = 0, y = 0, menu = 0, stick = 0 }
    self.gpioButtons = { a = 0, b = 0, x = 0, y = 0, menu = 0, stick = 0 }
    
    -- Input queue
    self.dirQueue = {}
    self.maxQueueSize = 4
    
    return self
end

-- Update input (call every frame)
function Input:update(dt)
    -- Read GPIO
    self.readTimer = self.readTimer + dt
    if self.readTimer >= self.readInterval then
        self.readTimer = self.readTimer - self.readInterval
        
        -- pcall to avoid blocking on file errors
        local success, f = pcall(io.open, "/tmp/input.txt", "r")
        if success and f then
            local readSuccess, payload = pcall(function()
                local content = f:read("*a") or ""
                f:close()
                return content
            end)
            
            if readSuccess and payload then
                local result = {}
                for key, value in payload:gmatch("(%w+):([%-%d%.]+)") do
                    result[key] = tonumber(value)
                end
                
                -- Update joystick
                if result.jx then 
                    self.joystick.x = math.max(0, math.min(1023, result.jx))
                end
                if result.jy then 
                    self.joystick.y = math.max(0, math.min(1023, result.jy))
                end
                
                -- Update GPIO buttons
                if result.a then self.gpioButtons.a = result.a end
                if result.b then self.gpioButtons.b = result.b end
                if result.x then self.gpioButtons.x = result.x end
                if result.y then self.gpioButtons.y = result.y end
                if result.menu then self.gpioButtons.menu = result.menu end
                if result.stick then self.gpioButtons.stick = result.stick end
            else
                if f then pcall(function() f:close() end) end
            end
        end
    end
     
    -- Convert joystick to world coords
    local x01 = self.joystick.x / 1023.0
    local y01 = self.joystick.y / 1023.0
    self.world.x = -(x01 * 2.0 - 1.0)
    self.world.y = y01 * 2.0 - 1.0
    
    -- Keyboard input (arrows + WASD)
    local keyX, keyY = 0, 0
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then keyX = -1 end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then keyX = 1 end
    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then keyY = -1 end
    if love.keyboard.isDown("down") or love.keyboard.isDown("s") then keyY = 1 end
    
    -- Keyboard overrides GPIO if joystick centered
    local joystickActive = math.abs(self.world.x) > 0.1 or math.abs(self.world.y) > 0.1
    if (keyX ~= 0 or keyY ~= 0) and not joystickActive then
        self.world.x = keyX
        self.world.y = keyY
    end
    
    -- Keyboard buttons (numpad + IJKL layout, space for menu)
    self.keyboardButtons.a = (love.keyboard.isDown("kp2") or love.keyboard.isDown("k")) and 1 or 0
    self.keyboardButtons.b = (love.keyboard.isDown("kp6") or love.keyboard.isDown("l")) and 1 or 0
    self.keyboardButtons.x = (love.keyboard.isDown("kp4") or love.keyboard.isDown("j")) and 1 or 0
    self.keyboardButtons.y = (love.keyboard.isDown("kp8") or love.keyboard.isDown("i")) and 1 or 0
    self.keyboardButtons.menu = (love.keyboard.isDown("kp0") or love.keyboard.isDown("space")) and 1 or 0
    self.keyboardButtons.stick = love.keyboard.isDown("kp1") and 1 or 0
    
    -- Combine buttons
    self.buttons.a = (self.gpioButtons.a == 1 or self.keyboardButtons.a == 1) and 1 or 0
    self.buttons.b = (self.gpioButtons.b == 1 or self.keyboardButtons.b == 1) and 1 or 0
    self.buttons.x = (self.gpioButtons.x == 1 or self.keyboardButtons.x == 1) and 1 or 0
    self.buttons.y = (self.gpioButtons.y == 1 or self.keyboardButtons.y == 1) and 1 or 0
    self.buttons.menu = (self.gpioButtons.menu == 1 or self.keyboardButtons.menu == 1) and 1 or 0
    self.buttons.stick = (self.gpioButtons.stick == 1 or self.keyboardButtons.stick == 1) and 1 or 0
end

-- Get axis (-1 to 1)
function Input:getAxis()
    return self.world.x, self.world.y
end

-- Get axis w/ deadzone
function Input:getAxisDeadzone(threshold)
    threshold = threshold or 0.25
    local x = math.abs(self.world.x) > threshold and self.world.x or 0
    local y = math.abs(self.world.y) > threshold and self.world.y or 0
    return x, y
end

-- Check if button down
function Input:isButtonDown(button)
    button = button or "a"  -- Default to A button
    return self.buttons[button] == 1
end

-- Check if button just pressed
function Input:isButtonPressed(button)
    button = button or "a"  -- Default to A button
    local pressed = self.buttons[button] == 1 and self.lastButtons[button] == 0
    self.lastButtons[button] = self.buttons[button]
    return pressed
end

-- Check menu button
function Input:isMenuPressed()
    return self:isButtonPressed("menu")
end

-- Get primary direction
function Input:getDirection(threshold)
    threshold = threshold or 0.25
    if math.abs(self.world.x) > math.abs(self.world.y) then
        if self.world.x > threshold then return 1, 0   -- Right
        elseif self.world.x < -threshold then return -1, 0  -- Left
        end
    else
        if self.world.y > threshold then return 0, 1   -- Down
        elseif self.world.y < -threshold then return 0, -1  -- Up
        end
    end
    return 0, 0  -- No input
end

-- Queue direction
function Input:queueDirection(dx, dy)
    if #self.dirQueue < self.maxQueueSize then
        local dir = {x = dx, y = dy}
        table.insert(self.dirQueue, dir)
    end
end

-- Pop queued direction
function Input:popDirection()
    if #self.dirQueue > 0 then
        return table.remove(self.dirQueue, 1)
    else
        return nil
    end
end

-- Clear direction queue
function Input:clearQueue()
    self.dirQueue = {}
end

-- Reset input state
function Input:reset()
    -- Reset buttons
    self.lastButtons = { a = 0, b = 0, x = 0, y = 0, menu = 0, stick = 0 }
    self.buttons = { a = 0, b = 0, x = 0, y = 0, menu = 0, stick = 0 }
    self.keyboardButtons = { a = 0, b = 0, x = 0, y = 0, menu = 0, stick = 0 }
    self.gpioButtons = { a = 0, b = 0, x = 0, y = 0, menu = 0, stick = 0 }
    -- Clear queue
    self.dirQueue = {}
end

-- Handle menu return to launcher
function Input:handleMenuReturn()
    if self:isMenuPressed() then
        local launcher = require("main")
        if launcher and launcher.returnToLauncher then
            launcher.returnToLauncher()
            return true
        end
    end
    return false
end

return Input

