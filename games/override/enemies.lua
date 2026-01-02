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
    local playerCenterX = game.player.position.x + game.player.size / 2
		local playerCenterY = game.player.position.y + game.player.size / 2
    
    local dx = playerCenterX - enemy.position.x
    local dy = playerCenterY - enemy.position.y
    return utils.normalize(dx, dy)
end

local function resolveEnemyCollisions(enemy)
	for _, other in ipairs(game.enemies) do
		if enemy ~= other then
			-- Check collision
			if utils.rectCollision(
				enemy.position.x, enemy.position.y, enemy.size, enemy.size,
				other.position.x, other.position.y, other.size, other.size
			) then
				-- Calculate centers
				local center1X = enemy.position.x + enemy.size / 2
				local center1Y = enemy.position.y + enemy.size / 2
				local center2X = other.position.x + other.size / 2
				local center2Y = other.position.y + other.size / 2
				
				-- Calculate separation vector
				local dx = center1X - center2X
				local dy = center1Y - center2Y
				local distance = math.sqrt(dx * dx + dy * dy)
				
				if distance > 0 then
					-- Normalize and push apart
					local pushDistance = (enemy.size + other.size) / 2 - distance
					local pushX = (dx / distance) * pushDistance * 0.5
					local pushY = (dy / distance) * pushDistance * 0.5
					
					-- Move enemy away from other
					enemy.position.x = enemy.position.x + pushX
					enemy.position.y = enemy.position.y + pushY
				end
			end
		end
	end
end



----------------------------------------------------------------------
-- Enemy types -------------------------------------------------------
----------------------------------------------------------------------
local function slugger()
    local enemy = {
        position = {x = 0, y = 0},
		velocity = {x = 0, y = 0},
		health = 10,
		speed = 60,
		size = 30,
    }

    local params = {
        color = {177/255, 207/255, 78/255, 1},
        name = "Slugger",
        rarity = 1,
    }

    function enemy:update(dt)
        local ndx, ndy = vectorToPlayer(self)

        self.velocity.x = ndx * self.speed
        self.velocity.y = ndy * self.speed
        self.position.x = self.position.x + self.velocity.x * dt
        self.position.y = self.position.y + self.velocity.y * dt
		
		-- Resolve collisions with other enemies
		resolveEnemyCollisions(self)
    end

    function enemy:render()
        love.graphics.setColor(params.color)
        love.graphics.rectangle("fill", self.position.x, self.position.y, self.size, self.size)

        if self == game.closestEnemy then
            love.graphics.setColor(1, 0, 0, 1)
            love.graphics.rectangle("line", self.position.x, self.position.y, self.size, self.size)
        end
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
