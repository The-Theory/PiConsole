---@diagnostic disable: undefined-global

local utils = require("TiPiL.utils")

local Enemies = {}
Enemies.__index = Enemies

local game = nil
function Enemies.setGameState(gameState)
    game = gameState
end

local function slugger()
    local enemy = {
        position = {x = 0, y = 0},
		velocity = {x = 0, y = 0},
		health = 100,
		speed = 100,
		size = 25,
    }

    function enemy:update(dt)
        if not game then return end

        local target = {x = game.player.position.x, y = game.player.position.y}
        target.x = target.x + game.player.size / 2
        target.y = target.y + game.player.size / 2
        
        local dx = target.x - self.position.x
        local dy = target.y - self.position.y

        local ndx, ndy = utils.normalize(dx, dy)
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance < self.size then
            return
        end

        --local angle = math.atan(dy, dx)
        --self.velocity.x = math.cos(angle) * self.speed
        --self.velocity.y = math.sin(angle) * self.speed
        self.velocity.x = ndx * self.speed
        self.velocity.y = ndy * self.speed
        self.position.x = self.position.x + self.velocity.x * dt
        self.position.y = self.position.y + self.velocity.y * dt
    end

    function enemy:render()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", self.position.x, self.position.y, self.size)
    end

    return enemy
end

function Enemies.new()
    local self = setmetatable({}, Enemies)
    self.enemyTypes = {
        slugger = slugger,
    }
    return self
end

return Enemies