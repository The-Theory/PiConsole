---@diagnostic disable: undefined-global

-- Shared libraries
local Input = require("TiPiL.input")
local UI = require("TiPiL.ui")
local utils = require("TiPiL.utils")
local game_common = require("TiPiL.game_common")

local Scene = {}

-- Config
local CONFIG = {
	gridCols = 10,
	gridRows = 20,
	targetCell = 16,         -- Desired cell size in px; we will fit to screen
	gravityStart = 0.7,      -- Seconds per row drop at level 1
	gravityMin = 0.08,       -- Fastest gravity
	levelLines = 10,         -- Lines per level
	moveDelay = game_common.TIMING.MOVE_DELAY,  -- Repeat move delay for left/right
	inputThreshold = game_common.THRESHOLDS.DEFAULT_DEADZONE,
	softDropFactor = 12,     -- How much faster soft drop is vs gravity
	lockDelay = 0.4,         -- Extra time before locking after touching ground
	ghostPiece = true,       -- Show ghost drop position
}

-- Colors
local COLORS = {
	bgPanel = {0.12, 0.12, 0.14, 1},
	gridBgLight = {0.18, 0.18, 0.20, 1},
	gridBgDark = {0.16, 0.16, 0.18, 1},
	text = UI.colors.text,
	pieces = {
		{0.00, 0.80, 1.00, 1},   -- I
		{0.95, 0.80, 0.10, 1},   -- O
		{0.85, 0.35, 0.95, 1},   -- T
		{0.25, 0.85, 0.40, 1},   -- S
		{0.95, 0.30, 0.30, 1},   -- Z
		{1.00, 0.55, 0.10, 1},   -- L
		{0.20, 0.60, 0.95, 1},   -- J
	},
	ghost = {1, 1, 1, 0.18},
}

-- Shapes (4x4 grid, each rotation is list of blocks {x,y})
local SHAPES = {
	-- I
	{
		{{0,1},{1,1},{2,1},{3,1}},
		{{2,0},{2,1},{2,2},{2,3}},
		{{0,2},{1,2},{2,2},{3,2}},
		{{1,0},{1,1},{1,2},{1,3}},
	},
	-- O
	{
		{{1,1},{2,1},{1,2},{2,2}},
		{{1,1},{2,1},{1,2},{2,2}},
		{{1,1},{2,1},{1,2},{2,2}},
		{{1,1},{2,1},{1,2},{2,2}},
	},
	-- T
	{
		{{1,0},{0,1},{1,1},{2,1}},
		{{1,0},{1,1},{2,1},{1,2}},
		{{0,1},{1,1},{2,1},{1,2}},
		{{1,0},{0,1},{1,1},{1,2}},
	},
	-- S
	{
		{{1,0},{2,0},{0,1},{1,1}},
		{{1,0},{1,1},{2,1},{2,2}},
		{{1,1},{2,1},{0,2},{1,2}},
		{{0,0},{0,1},{1,1},{1,2}},
	},
	-- Z
	{
		{{0,0},{1,0},{1,1},{2,1}},
		{{2,0},{1,1},{2,1},{1,2}},
		{{0,1},{1,1},{1,2},{2,2}},
		{{1,0},{0,1},{1,1},{0,2}},
	},
	-- L
	{
		{{0,0},{0,1},{1,1},{2,1}},
		{{1,0},{2,0},{1,1},{1,2}},
		{{0,1},{1,1},{2,1},{2,2}},
		{{1,0},{1,1},{0,2},{1,2}},
	},
	-- J
	{
		{{2,0},{0,1},{1,1},{2,1}},
		{{1,0},{1,1},{1,2},{2,2}},
		{{0,1},{1,1},{2,1},{0,2}},
		{{0,0},{1,0},{1,1},{1,2}},
	},
}

local input, ui

local grid = { cols = CONFIG.gridCols, rows = CONFIG.gridRows, cell = 0, x = 0, y = 0, w = 0, h = 0 }
local board = {} -- board[row][col] = color or nil

local bag = {}   -- 7-bag
local current = { id = 1, rot = 1, x = 3, y = -2, color = COLORS.pieces[1] }
local nextId = 1

local game = {
	state = "playing",
	score = 0,
	lines = 0,
	level = 1,
	gravity = CONFIG.gravityStart,
	gravityTimer = 0,
	moveTimerX = 0,
	softDrop = false,
	lastSoftDrop = false,
	lockTimer = 0,
	touchingGround = false,
	clearingLines = {},
	clearTimer = 0,
	lastScore = 0,
	lastUpPress = false,
}

-- Utils
local function emptyBoard()
	local b = {}
	for r = 0, grid.rows - 1 do
		b[r] = {}
	end
	return b
end

local function refillBag()
	bag = {1,2,3,4,5,6,7}
	utils.shuffle(bag)
end

local function takeFromBag()
	if #bag == 0 then refillBag() end
	return table.remove(bag)
end

local function spawnPiece()
	current.id = nextId
	current.rot = 1
	current.x = 3
	current.y = -2
	current.color = COLORS.pieces[current.id]
	nextId = takeFromBag()
	game.lockTimer = 0
	game.touchingGround = false
end

local function setLevelFromLines()
	game.level = math.max(1, math.floor(game.lines / CONFIG.levelLines) + 1)
	local t = 0.85 ^ (game.level - 1)
	game.gravity = math.max(CONFIG.gravityMin, CONFIG.gravityStart * t)
end

local function pieceCells(id, rot, px, py)
	local cells = {}
	for _, p in ipairs(SHAPES[id][rot]) do
		table.insert(cells, { x = px + p[1], y = py + p[2] })
	end
	return cells
end

local function outOfBounds(x, y)
	return x < 0 or x >= grid.cols or y >= grid.rows
end

local function collides(id, rot, px, py)
	for _, c in ipairs(pieceCells(id, rot, px, py)) do
		if c.y >= 0 then
			if outOfBounds(c.x, c.y) then return true end
			if board[c.y][c.x] ~= nil then return true end
		else
			-- Allow above top
			if c.x < 0 or c.x >= grid.cols then return true end
		end
	end
	return false
end

local function tryMove(dx, dy)
	if not collides(current.id, current.rot, current.x + dx, current.y + dy) then
		current.x = current.x + dx
		current.y = current.y + dy
		return true
	end
	return false
end

local function tryRotate(dir)
	local newRot = ((current.rot - 1 + dir) % 4) + 1
	-- Wall kicks
	local kicks = {{0,0},{-1,0},{1,0},{-2,0},{2,0},{0,-1}}
	for _,k in ipairs(kicks) do
		if not collides(current.id, newRot, current.x + k[1], current.y + k[2]) then
			current.rot = newRot
			current.x = current.x + k[1]
			current.y = current.y + k[2]
			return true
		end
	end
	return false
end

local function hardDrop()
	local drop = 0
	while not collides(current.id, current.rot, current.x, current.y + 1) do
		current.y = current.y + 1
		drop = drop + 1
	end
	game.score = game.score + drop * 2
end

local function lockPiece()
	for _, c in ipairs(pieceCells(current.id, current.rot, current.x, current.y)) do
		if c.y < 0 then
			game.state = "over"
			return
		end
		board[c.y][c.x] = { current.color[1], current.color[2], current.color[3], 1 }
	end
	
	-- Wait for line clear anim
	if game.clearTimer > 0 then
		return
	end
	
	-- Clear lines
	local cleared = 0
	game.clearingLines = {}
	for r = grid.rows - 1, 0, -1 do
		local full = true
		for c = 0, grid.cols - 1 do
			if board[r][c] == nil then full = false break end
		end
		if full then
			table.insert(game.clearingLines, r)
			cleared = cleared + 1
		end
	end
	if cleared > 0 then
		game.clearTimer = 0.3  -- Animation duration
		local points = ({100, 300, 500, 800})[cleared] or (cleared * 100)
		game.lastScore = points * game.level
		game.score = game.score + game.lastScore
		game.lines = game.lines + cleared
		setLevelFromLines()
		-- Don't spawn until cleared
		return
	end
	spawnPiece()
end

local function computeGhostY()
	if not CONFIG.ghostPiece then return current.y end
	local gy = current.y
	while not collides(current.id, current.rot, current.x, gy + 1) do
		gy = gy + 1
	end
	return gy
end

-- Scene callbacks
function Scene.load()
	input = Input.new()
	ui = UI.new("Tetris")
	ui:setupWindow()

	local w, h = ui:getScreen()

	-- Fit grid to screen
	local minPadding = 6
	grid.cell = math.floor(math.min(
		(w * 0.82) / grid.cols,
		(h - minPadding * 2) / grid.rows
	))
	grid.w = grid.cols * grid.cell
	grid.h = grid.rows * grid.cell
	grid.x = math.floor((w - grid.w) / 2 - w * 0.08)  -- Reduced offset
	grid.y = math.floor((h - grid.h) / 2)
	grid.x = math.max(minPadding, grid.x)

	board = emptyBoard()
	refillBag()
	nextId = takeFromBag()
	spawnPiece()
	game.state = "playing"
	game.score = 0
	game.lines = 0
	game.level = 1
	game.gravity = CONFIG.gravityStart
	game.gravityTimer = 0
	game.moveTimerX = 0
	game.lockTimer = 0
	game.touchingGround = false
	game.clearingLines = {}
	game.clearTimer = 0
	game.lastScore = 0
	game.lastUpPress = false
	game.lastSoftDrop = false
end

function Scene.update(dt)
	input:update(dt)

	-- Update line clear anim
	if game.clearTimer > 0 then
		game.clearTimer = game.clearTimer - dt
		if game.clearTimer <= 0 then
			-- Remove cleared lines
			table.sort(game.clearingLines, function(a, b) return a > b end)
			for _, r in ipairs(game.clearingLines) do
				table.remove(board, r)
				table.insert(board, 0, {})
			end
			game.clearingLines = {}
			-- Spawn new piece
			spawnPiece()
		end
	end

	-- Standard input
	if game_common.handleStandardInput(input) then
		return
	end

	if game.state ~= game_common.STATES.PLAYING then
		-- Restart
		if game_common.handleResetInput(input, game.state, Scene.load) then
			return
		end
		return
	end

	-- Get axis
	local axisX, axisY = input:getAxis()
	local threshold = CONFIG.inputThreshold

	-- Movement (repeat)
	game.moveTimerX = game.moveTimerX + dt
	local dx = 0
	local movedThisFrame = false
	
	-- Button movement (X=left, B=right)
	if input:isButtonDown("x") then
		dx = -1
	elseif input:isButtonDown("b") then
		dx = 1
	elseif math.abs(axisX) > threshold then
		-- Direction input
		dx = axisX > 0 and 1 or -1
	end
	
	if dx ~= 0 then
		if game.moveTimerX >= CONFIG.moveDelay then
			if tryMove(dx, 0) then
				movedThisFrame = true
			end
			game.moveTimerX = 0
		end
	else
		game.moveTimerX = CONFIG.moveDelay
	end

	-- Rotation (Up/Y)
	if input:isButtonPressed("y") then
		tryRotate(1)
	end
	-- Also check direction input
	if axisY < -threshold then  -- Up
		if not game.lastUpPress then
			tryRotate(1)
			game.lastUpPress = true
		end
	else
		game.lastUpPress = false
	end

	-- Soft drop / Speed (Down/A)
	game.softDrop = false
	if input:isButtonDown("a") then
		game.softDrop = true
	elseif axisY > threshold then  -- Down
		game.softDrop = true
	end

	-- Reset gravity timer on state change
	if game.softDrop ~= game.lastSoftDrop then
		game.gravityTimer = 0
	end
	game.lastSoftDrop = game.softDrop

	-- Gravity
	local gravityInterval = game.gravity
	if game.softDrop then
		gravityInterval = math.max(CONFIG.gravityMin, game.gravity / CONFIG.softDropFactor)
		game.score = game.score + 1  -- Reward soft drop
	end

	game.gravityTimer = game.gravityTimer + dt

	-- Ground detection
	local willCollide = collides(current.id, current.rot, current.x, current.y + 1)
	if willCollide then
		game.touchingGround = true
		game.lockTimer = game.lockTimer + dt
		-- Reset lock delay if moved or rotated this frame
		if movedThisFrame then game.lockTimer = 0 end
		if game.lockTimer >= CONFIG.lockDelay then
			lockPiece()
			return
		end
	else
		game.touchingGround = false
		game.lockTimer = 0
	end

	if game.gravityTimer >= gravityInterval then
		game.gravityTimer = game.gravityTimer - gravityInterval
		if not tryMove(0, 1) then
			-- Start lock delay
			game.touchingGround = true
		end
	end
end

-- Helper function to draw enhanced block
local function drawBlock(x, y, size, color, isGhost, isClearing)
	local padding = 2
	local blockSize = size - padding * 2
	
	if isClearing then
		local flash = math.sin(game.clearTimer * 30) * 0.5 + 0.5
		love.graphics.setColor(1, 1, 1, flash * 0.9)
		love.graphics.rectangle("fill", x + padding, y + padding, blockSize, blockSize, 0, 0)
		return
	end
	
	if isGhost then
		-- Ghost
		love.graphics.setColor(color[1], color[2], color[3], 0.25)
		love.graphics.rectangle("fill", x + padding, y + padding, blockSize, blockSize, 0, 0)
		love.graphics.setColor(color[1], color[2], color[3], 0.6)
		love.graphics.setLineWidth(1.5)
		love.graphics.rectangle("line", x + padding, y + padding, blockSize, blockSize, 0, 0)
		love.graphics.setLineWidth(1)
	else
		-- Regular block with shadow, gradient, and border
		-- Shadow
		love.graphics.setColor(0, 0, 0, 0.4)
		love.graphics.rectangle("fill", x + padding + 1, y + padding + 1, blockSize, blockSize, 0, 0)
		
		-- Main
		love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
		love.graphics.rectangle("fill", x + padding, y + padding, blockSize, blockSize, 0, 0)
		
		-- Highlight gradient (lighter top)
		local highlight = {color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, 0.4}
		love.graphics.setColor(highlight[1], highlight[2], highlight[3], highlight[4])
		love.graphics.rectangle("fill", x + padding, y + padding, blockSize, blockSize * 0.3, 0, 0)
		
		-- Dark gradient
		local dark = {color[1] * 0.6, color[2] * 0.6, color[3] * 0.6, 0.3}
		love.graphics.setColor(dark[1], dark[2], dark[3], dark[4])
		love.graphics.rectangle("fill", x + padding, y + padding + blockSize * 0.7, blockSize, blockSize * 0.3, 0, 0)
		
		-- Border
		love.graphics.setColor(color[1] * 1.2, color[2] * 1.2, color[3] * 1.2, 0.8)
		love.graphics.setLineWidth(1)
		love.graphics.rectangle("line", x + padding, y + padding, blockSize, blockSize, 0, 0)
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

	-- Grid panel
	local shadowOffset = 6
	love.graphics.setColor(0, 0, 0, 0.4)
	love.graphics.rectangle("fill", grid.x + shadowOffset, grid.y + shadowOffset, grid.w, grid.h, 0, 0)
	love.graphics.setColor(COLORS.bgPanel[1], COLORS.bgPanel[2], COLORS.bgPanel[3], COLORS.bgPanel[4])
	love.graphics.rectangle("fill", grid.x, grid.y, grid.w, grid.h, 0, 0)
	
	-- Border
	love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.4)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", grid.x, grid.y, grid.w, grid.h, 0, 0)
	love.graphics.setLineWidth(1)
	
	-- Corner decals
	local cornerSize = 4
	love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.8)
	-- Top-left
	love.graphics.rectangle("fill", grid.x, grid.y, cornerSize, cornerSize, 0, 0)
	-- Top-right
	love.graphics.rectangle("fill", grid.x + grid.w - cornerSize, grid.y, cornerSize, cornerSize, 0, 0)
	-- Bottom-left
	love.graphics.rectangle("fill", grid.x, grid.y + grid.h - cornerSize, cornerSize, cornerSize, 0, 0)
	-- Bottom-right
	love.graphics.rectangle("fill", grid.x + grid.w - cornerSize, grid.y + grid.h - cornerSize, cornerSize, cornerSize, 0, 0)

	-- Checkerboard
	love.graphics.setScissor(grid.x, grid.y, grid.w, grid.h)
	game_common.drawCheckerboard(grid.x, grid.y, grid.w, grid.h,
	                              grid.cell, COLORS.gridBgLight, COLORS.gridBgDark)

	-- Grid lines
	love.graphics.setColor(1, 1, 1, 0.05)
	for c = 0, grid.cols do
		local x = grid.x + c * grid.cell
		love.graphics.line(x, grid.y, x, grid.y + grid.h)
	end
	for r = 0, grid.rows do
		local y = grid.y + r * grid.cell
		love.graphics.line(grid.x, y, grid.x + grid.w, y)
	end

	-- Draw board
	for r = 0, grid.rows - 1 do
		for c = 0, grid.cols - 1 do
			local cell = board[r][c]
			if cell ~= nil then
				local isClearing = false
				for _, clr in ipairs(game.clearingLines) do
					if clr == r then
						isClearing = true
						break
					end
				end
				drawBlock(
					grid.x + c * grid.cell,
					grid.y + r * grid.cell,
					grid.cell,
					cell,
					false,
					isClearing
				)
			end
		end
	end

	-- Draw ghost
	if CONFIG.ghostPiece then
		local gy = computeGhostY()
		for _, c in ipairs(pieceCells(current.id, current.rot, current.x, gy)) do
			if c.y >= 0 then
				drawBlock(
					grid.x + c.x * grid.cell,
					grid.y + c.y * grid.cell,
					grid.cell,
					current.color,
					true,
					false
				)
			end
		end
	end

	-- Draw current piece
	for _, c in ipairs(pieceCells(current.id, current.rot, current.x, current.y)) do
		if c.y >= 0 then
			drawBlock(
				grid.x + c.x * grid.cell,
				grid.y + c.y * grid.cell,
				grid.cell,
				current.color,
				false,
				false
			)
		end
	end
	love.graphics.setScissor()

	-- Score popup
	if game.clearTimer > 0 and game.lastScore > 0 then
		local popupY = grid.y + grid.h * 0.3
		local alpha = math.min(1.0, game.clearTimer / 0.1)
		love.graphics.setFont(ui.fonts.title)
		local scoreText = "+" .. tostring(game.lastScore)
		local textW = ui.fonts.title:getWidth(scoreText)
		love.graphics.setColor(UI.colors.success[1], UI.colors.success[2], UI.colors.success[3], alpha)
		love.graphics.printf(scoreText, grid.x, popupY, grid.w, "center")
	end

	-- Sidebar
	local sidebarPadding = 6
	local sidebarX = grid.x + grid.w + sidebarPadding
	local sidebarW = math.max(110, w - sidebarX - sidebarPadding)
	local sidebarH = grid.h
	local sidebarY = grid.y
	
	-- Sidebar shadow
	local sidebarShadow = 6
	love.graphics.setColor(0, 0, 0, 0.35)
	love.graphics.rectangle("fill", sidebarX + sidebarShadow, sidebarY + sidebarShadow, sidebarW, sidebarH, 0, 0)
	love.graphics.setColor(COLORS.bgPanel[1], COLORS.bgPanel[2], COLORS.bgPanel[3], COLORS.bgPanel[4])
	love.graphics.rectangle("fill", sidebarX, sidebarY, sidebarW, sidebarH, 0, 0)
	
	-- Border
	love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.3)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", sidebarX, sidebarY, sidebarW, sidebarH, 0, 0)
	love.graphics.setLineWidth(1)
	
	-- Corner decals for sidebar panel
	local cornerSize = 4
	love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.8)
	-- Top-left
	love.graphics.rectangle("fill", sidebarX, sidebarY, cornerSize, cornerSize, 0, 0)
	-- Top-right
	love.graphics.rectangle("fill", sidebarX + sidebarW - cornerSize, sidebarY, cornerSize, cornerSize, 0, 0)
	-- Bottom-left
	love.graphics.rectangle("fill", sidebarX, sidebarY + sidebarH - cornerSize, cornerSize, cornerSize, 0, 0)
	-- Bottom-right
	love.graphics.rectangle("fill", sidebarX + sidebarW - cornerSize, sidebarY + sidebarH - cornerSize, cornerSize, cornerSize, 0, 0)

	local sectionY = sidebarY + 12
	
	-- Score
	love.graphics.setFont(ui.fonts.large)
	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.print("Score", sidebarX + 12, sectionY + 1)
	love.graphics.setColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], COLORS.text[4])
	love.graphics.print("Score", sidebarX + 12, sectionY)
	love.graphics.setFont(ui.fonts.title)
	love.graphics.setColor(UI.colors.primaryBright[1], UI.colors.primaryBright[2], UI.colors.primaryBright[3], 1)
	love.graphics.print(tostring(game.score), sidebarX + 12, sectionY + 26)
	
	-- Divider
	love.graphics.setColor(1, 1, 1, 0.1)
	love.graphics.rectangle("fill", sidebarX + 8, sectionY + 58, sidebarW - 16, 1, 0, 0)

	-- Level
	sectionY = sectionY + 60
	love.graphics.setFont(ui.fonts.large)
	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.print("Level", sidebarX + 12, sectionY + 1)
	love.graphics.setColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], COLORS.text[4])
	love.graphics.print("Level", sidebarX + 12, sectionY)
	love.graphics.setFont(ui.fonts.title)
	love.graphics.setColor(UI.colors.warning[1], UI.colors.warning[2], UI.colors.warning[3], 1)
	love.graphics.print(tostring(game.level), sidebarX + 12, sectionY + 26)
	
	-- Divider
	love.graphics.setColor(1, 1, 1, 0.1)
	love.graphics.rectangle("fill", sidebarX + 8, sectionY + 58, sidebarW - 16, 1, 0, 0)

	-- Lines section
	sectionY = sectionY + 60
	love.graphics.setFont(ui.fonts.large)
	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.print("Lines", sidebarX + 12, sectionY + 1)
	love.graphics.setColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], COLORS.text[4])
	love.graphics.print("Lines", sidebarX + 12, sectionY)
	love.graphics.setFont(ui.fonts.title)
	love.graphics.setColor(UI.colors.success[1], UI.colors.success[2], UI.colors.success[3], 1)
	love.graphics.print(tostring(game.lines), sidebarX + 12, sectionY + 26)
	
	-- Progress bar
	local linesProgress = (game.lines % CONFIG.levelLines) / CONFIG.levelLines
	local progressW = sidebarW - 24
	local progressH = 4
	love.graphics.setColor(0.2, 0.2, 0.25, 1)
	love.graphics.rectangle("fill", sidebarX + 12, sectionY + 52, progressW, progressH, 0, 0)
	love.graphics.setColor(UI.colors.success[1], UI.colors.success[2], UI.colors.success[3], 0.8)
	love.graphics.rectangle("fill", sidebarX + 12, sectionY + 52, progressW * linesProgress, progressH, 0, 0)

	-- Next piece preview
	sectionY = sectionY + 60
	love.graphics.setFont(ui.fonts.large)
	love.graphics.setColor(0, 0, 0, 0.5)
	love.graphics.print("Next", sidebarX + 12, sectionY + 1)
	love.graphics.setColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], COLORS.text[4])
	love.graphics.print("Next", sidebarX + 12, sectionY)

	local py = sectionY + 24
	local availableHeight = sidebarY + sidebarH - py - 8
	local previewSize = math.min(grid.cell * 0.6, availableHeight / 5)
	local boxW = previewSize * 5
	local boxH = previewSize * 5
	local px = sidebarX + 12
	
	-- Preview shadow
	local previewShadow = 3
	love.graphics.setColor(0, 0, 0, 0.25)
	love.graphics.rectangle("fill", px + previewShadow, py + previewShadow, boxW, boxH, 0, 0)
	love.graphics.setColor(0.1, 0.1, 0.12, 1)
	love.graphics.rectangle("fill", px, py, boxW, boxH, 0, 0)
	
	-- Preview box border
	love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.4)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", px, py, boxW, boxH, 0, 0)
	love.graphics.setLineWidth(1)
	
	-- Corner decals
	local cornerSize = 4
	love.graphics.setColor(UI.colors.primary[1], UI.colors.primary[2], UI.colors.primary[3], 0.8)
	-- Top-left
	love.graphics.rectangle("fill", px, py, cornerSize, cornerSize, 0, 0)
	-- Top-right
	love.graphics.rectangle("fill", px + boxW - cornerSize, py, cornerSize, cornerSize, 0, 0)
	-- Bottom-left
	love.graphics.rectangle("fill", px, py + boxH - cornerSize, cornerSize, cornerSize, 0, 0)
	-- Bottom-right
	love.graphics.rectangle("fill", px + boxW - cornerSize, py + boxH - cornerSize, cornerSize, cornerSize, 0, 0)

	love.graphics.setScissor(px, py, boxW, boxH)
	for _, p in ipairs(SHAPES[nextId][1]) do
		local cx = px + (p[1] + 0.5) * previewSize + previewSize
		local cy = py + (p[2] + 0.5) * previewSize + previewSize
		drawBlock(
			cx - previewSize * 0.5,
			cy - previewSize * 0.5,
			previewSize,
			COLORS.pieces[nextId],
			false,
			false
		)
	end
	love.graphics.setScissor()

	-- Overlays
	if game.state == "over" then
		ui:drawGameOver(UI.colors.danger)
	end
end

return Scene


