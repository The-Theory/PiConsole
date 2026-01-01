---@diagnostic disable: undefined-global

-- Shared libraries
local Input = require("TiPiL.input")
local UI = require("TiPiL.ui")
local utils = require("TiPiL.utils")
local game_common = require("TiPiL.game_common")
local Enemies = require("games.override.enemies")

local Scene = {}

-- Game state
local input, ui, enemies

-- Scene callbacks
function Scene.load()
	input = Input.new()
	ui = UI.new("New Game")
	ui:setupWindow()

	-- Initialize game state here
	game.state = game_common.STATES.PLAYING
	enemies = Enemies.new()
	
	-- Share game state with enemies module
	Enemies.setGameState(game)
	table.insert(game.enemies, enemies.enemyTypes.slugger())
end

function Scene.update(dt)
	input:update(dt)

	-- Handle standard input (menu, exit, etc.)
	if game_common.handleStandardInput(input) then
		return
	end

	-- Handle game over/restart input
	if game.state ~= game_common.STATES.PLAYING then
		if game_common.handleResetInput(input, game.state, Scene.load) then
			return
		end
		return
	end
end

function Scene.draw()
	ui:clear()

	-- Overlays
	if game.state == game_common.STATES.GAME_OVER then
		ui:drawGameOver(UI.colors.danger)
	end
end

return Scene
