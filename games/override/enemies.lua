---@diagnostic disable: undefined-global, need-check-nil, undefined-field

----------------------------------------------------------------------
-- Enemies module ----------------------------------------------------
----------------------------------------------------------------------
local utils = require("TiPiL.utils")
local Enemies = {}
Enemies.__index = Enemies

local game = nil
function Enemies.setGameState(gameState)
    game = gameState
end



----------------------------------------------------------------------
-- Enemy utilities ---------------------------------------------------
----------------------------------------------------------------------
local function vectorToPlayer(enemy)
    local target = {x = game.player.position.x, y = game.player.position.y}
    target.x = target.x + game.player.size / 2
    target.y = target.y + game.player.size / 2
    
    local dx = target.x - enemy.position.x
    local dy = target.y - enemy.position.y
    return utils.normalize(dx, dy)
end



----------------------------------------------------------------------
-- Enemy types -------------------------------------------------------
----------------------------------------------------------------------
local function slugger()
    local enemy = {
        position = {x = 0, y = 0},
		velocity = {x = 0, y = 0},
		health = 100,
		speed = 100,
		size = 25,
    }

    local params = {
        color = {1, 1, 1, 1},
        name = "Slugger",
        rarity = 1,
    }

    function enemy:update(dt)
        local ndx, ndy = vectorToPlayer(self)
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



----------------------------------------------------------------------
-- Enemies class ----------------------------------------------------
----------------------------------------------------------------------
function Enemies.new()
    local self = setmetatable({}, Enemies)
    self.enemyTypes = {
        slugger = slugger
    }
    return self
end

return Enemies