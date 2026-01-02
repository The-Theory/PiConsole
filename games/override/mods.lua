---@diagnostic disable: undefined-global, need-check-nil, undefined-field

----------------------------------------------------------------------
-- Mods module -------------------------------------------------------
----------------------------------------------------------------------
local utils = require("TiPiL.utils")
local game_common = require("TiPiL.game_common")
local Mods = {}
Mods.__index = Mods

local game = nil
function Mods.setGameState(gameState)
    game = gameState
end



----------------------------------------------------------------------
-- Weapon utilities --------------------------------------------------
---------------------------------------------------------------------- 
local function vectorTo(start, target)
	local startX = start.position.x + start.size / 2
	local startY = start.position.y + start.size / 2
	local targetX = target.position.x + target.size / 2
	local targetY = target.position.y + target.size / 2
	
	local dx = targetX - startX
	local dy = targetY - startY
	return utils.normalize(dx, dy)
end

local function shootBullet(weapon, target, source, bulletSize)
	source = source or game.player
	bulletSize = bulletSize or 8
	
	local dirX, dirY = vectorTo(source, target)
	
	local bullet = {
		position = {x = source.position.x, y = source.position.y},
		velocity = {x = dirX * weapon.speed, y = dirY * weapon.speed},
		size = bulletSize,
		active = true,
	}
	
	table.insert(weapon.bullets, bullet)
end


----------------------------------------------------------------------
-- Weapon types ------------------------------------------------------
----------------------------------------------------------------------
local function basicWeapon()
	local weapon = {
		bullets = {},
		shootTimer = 0,
		shootInterval = 1.0,
		damage = 10,
		speed = 400,
	}
	
	local function updateBullets(weapon, dt, ui)
		for i = #weapon.bullets, 1, -1 do
			local bullet = weapon.bullets[i]
			
			if not bullet.active then
				table.remove(weapon.bullets, i)
			else
				-- Update position
				bullet.position.x = bullet.position.x + bullet.velocity.x * dt
				bullet.position.y = bullet.position.y + bullet.velocity.y * dt
				
				-- Check bounds (remove if off screen)
				local w, h = ui:getScreen()
				if bullet.position.x < -bullet.size or bullet.position.x > w + bullet.size or
				   bullet.position.y < -bullet.size or bullet.position.y > h + bullet.size then
					bullet.active = false
				end
				
				-- Check collision with enemies
				for j, enemy in ipairs(game.enemies) do
					if utils.rectCollision(
						bullet.position.x - bullet.size / 2, bullet.position.y - bullet.size / 2,
						bullet.size, bullet.size,
						enemy.position.x, enemy.position.y,
						enemy.size, enemy.size
					) then
						-- Hit enemy
						enemy.health = enemy.health - weapon.damage
						bullet.active = false
						
						-- Remove enemy if dead
						if enemy.health <= 0 then
							table.remove(game.enemies, j)
						end
						break
					end
				end
			end
		end
	end
	
	function weapon:update(dt, ui)
		-- Auto-shoot towards closest enemy
		self.shootTimer = self.shootTimer + dt
		if self.shootTimer >= self.shootInterval then
			self.shootTimer = 0
			
			if game.closestEnemy then
				shootBullet(self, game.closestEnemy)
			else 
				self.shootTimer = self.shootInterval
			end
		end
		
		-- Update bullets
		updateBullets(self, dt, ui)
	end
	
	function weapon:render()
		love.graphics.setColor(1, 0.3, 0.3, 1)
		for _, bullet in ipairs(self.bullets) do
			if bullet.active then
				love.graphics.rectangle("fill", 
					bullet.position.x - bullet.size / 2, 
					bullet.position.y - bullet.size / 2, 
					bullet.size, 
					bullet.size
				)
			end
		end
	end
	
	return weapon
end



----------------------------------------------------------------------
-- Mods class --------------------------------------------------------
----------------------------------------------------------------------
function Mods.new()
    local self = setmetatable({}, Mods)
	self.weaponTypes = {
        basic = basicWeapon,
    }
    return self
end

return Mods
