---@diagnostic disable: undefined-global, need-check-nil, undefined-field

-- Shared libraries
local Input = require("TiPiL.input")
local UI = require("TiPiL.ui")
local utils = require("TiPiL.utils")
local game_common = require("TiPiL.game_common")

local Scene = {}

-- Game state
local input, ui

local WORLD = { w = 480, h = 320 }

local CONFIG = {
	paddleSpeed = 360,
	paddleW = 90,
	paddleH = 14,
	paddleBottomPad = 26,

	ballRadius = 6,
	ballSpeed = 230,

	bricks = {
		rows = 3,
		cols = 10,
		topPad = 28,
		sidePad = 18,
		gap = 6,
		h = 16,
	},

	powerups = {
		dropChance = 0.15,
		fallSpeed = 150,
		radius = 11,
		duration = 20.0,
	},
}

local COLORS = {
	paddle = { 0.20, 0.75, 0.95, 1 },
	ball = { 0.95, 0.96, 0.98, 1 },
	brick1 = { 0.95, 0.75, 0.20, 1 },
	brick2 = { 0.20, 0.85, 0.50, 1 },
	brick3 = { 0.95, 0.35, 0.35, 1 },
	border = { 1, 1, 1, 0.10 },
	powerCircle = { 0.95, 0.96, 0.98, 0.95 },
	powerFill = { 0.12, 0.12, 0.14, 0.85 },
	powerGlyph = { 0.95, 0.96, 0.98, 0.95 },
	magnetBlue = { 0.20, 0.65, 0.90, 1.0 },
	magnetRed = { 0.95, 0.35, 0.35, 1.0 },
}

local game = {
	state = game_common.STATES.PLAYING,
	score = 0,
	highScore = 0,
	level = 1,

	paddle = { x = 0, y = 0, w = 0, h = 0 },
	ball = { x = 0, y = 0, vx = 0, vy = 0, r = 0, launched = false },
	bricks = {},
	brickCount = 0,

	powerups = {},
	activePower = { type = nil, timer = 0.0 },
	effects = {
		paddleScale = 1.0,
		ballSpeedScale = 1.0,
		magnet = false,
	},
}

local POWER_TYPES = { "bigger", "smaller", "faster", "magnet" }

local function currentBallSpeed()
	return (CONFIG.ballSpeed * game.level) * game.effects.ballSpeedScale
end

local function resetPaddle()
	game.paddle.w = CONFIG.paddleW
	game.paddle.h = CONFIG.paddleH
	game.paddle.x = (WORLD.w - game.paddle.w) * 0.5
	game.paddle.y = WORLD.h - CONFIG.paddleBottomPad - game.paddle.h
end

local function resetBall()
	game.ball.r = CONFIG.ballRadius
	game.ball.launched = false
	game.ball.vx, game.ball.vy = 0, 0
	game.ball.x = game.paddle.x + game.paddle.w * 0.5
	game.ball.y = game.paddle.y - game.ball.r - 1
end

local function normalizeBallVelocityToCurrentSpeed()
	if not game.ball.launched then return end
	local nx, ny = utils.normalize(game.ball.vx, game.ball.vy)
	game.ball.vx, game.ball.vy = nx * currentBallSpeed(), ny * currentBallSpeed()
end

local function clearActivePowerup()
	game.activePower.type = nil
	game.activePower.timer = 0.0

	-- Revert to defaults
	game.effects.paddleScale = 1.0
	game.effects.ballSpeedScale = 1.0
	game.effects.magnet = false

	-- Paddle sizing back to normal (preserve center)
	local cx = game.paddle.x + game.paddle.w * 0.5
	game.paddle.w = CONFIG.paddleW
	game.paddle.x = utils.clamp(cx - game.paddle.w * 0.5, 0, WORLD.w - game.paddle.w)

	-- Ball speed back to normal
	normalizeBallVelocityToCurrentSpeed()

	-- If ball is stuck, keep it aligned to the paddle
	if not game.ball.launched then
		game.ball.x = game.paddle.x + game.paddle.w * 0.5
		game.ball.y = game.paddle.y - game.ball.r - 1
	end
end

local function applyPowerup(powerType)
	-- Replace any existing power-up
	clearActivePowerup()

	game.activePower.type = powerType
	game.activePower.timer = CONFIG.powerups.duration

	local cx = game.paddle.x + game.paddle.w * 0.5

	if powerType == "bigger" then
		game.effects.paddleScale = 2.0
		game.paddle.w = CONFIG.paddleW * game.effects.paddleScale
		game.paddle.x = utils.clamp(cx - game.paddle.w * 0.5, 0, WORLD.w - game.paddle.w)
	elseif powerType == "smaller" then
		game.effects.paddleScale = 0.5
		game.paddle.w = CONFIG.paddleW * game.effects.paddleScale
		game.paddle.x = utils.clamp(cx - game.paddle.w * 0.5, 0, WORLD.w - game.paddle.w)
	elseif powerType == "faster" then
		game.effects.ballSpeedScale = 2.0
		normalizeBallVelocityToCurrentSpeed()
	elseif powerType == "magnet" then
		game.effects.magnet = true
	end

	-- If ball is stuck, keep it centered on the resized paddle
	if not game.ball.launched then
		game.ball.x = game.paddle.x + game.paddle.w * 0.5
		game.ball.y = game.paddle.y - game.ball.r - 1
	end
end

local function launchBall()
	game.ball.launched = true
	local angle = (-math.pi / 2) + (math.random() * 0.8 - 0.4)
	game.ball.vx = math.cos(angle) * currentBallSpeed()
	game.ball.vy = math.sin(angle) * currentBallSpeed()
end

local function buildBricks()
	game.bricks = {}
	game.brickCount = 0

	local b = CONFIG.bricks
	local totalGapW = b.gap * (b.cols - 1)
	local usableW = WORLD.w - b.sidePad * 2 - totalGapW
	local brickW = math.floor(usableW / b.cols)
	local gridW = brickW * b.cols + totalGapW
	local startX = math.floor((WORLD.w - gridW) * 0.5)

	for row = 1, b.rows do
		for col = 1, b.cols do
			local x = startX + (col - 1) * (brickW + b.gap)
			local y = b.topPad + (row - 1) * (b.h + b.gap)
			local color = (row == 1 and COLORS.brick1) or (row == 2 and COLORS.brick2) or COLORS.brick3
			table.insert(game.bricks, { x = x, y = y, w = brickW, h = b.h, alive = true, color = color })
			game.brickCount = game.brickCount + 1
		end
	end
end

local function circleRectCollision(cx, cy, cr, rx, ry, rw, rh)
	local closestX = utils.clamp(cx, rx, rx + rw)
	local closestY = utils.clamp(cy, ry, ry + rh)
	local dx = cx - closestX
	local dy = cy - closestY
	return (dx * dx + dy * dy) <= (cr * cr), dx, dy, closestX, closestY
end

local function bounceOffPaddle()
	if game.ball.vy <= 0 then return end

	local hit, _, _, closestX, closestY = circleRectCollision(
		game.ball.x, game.ball.y, game.ball.r,
		game.paddle.x, game.paddle.y, game.paddle.w, game.paddle.h
	)
	if not hit then return end

	-- Magnet makes the ball stick to the paddle every time it touches
	if game.effects.magnet then
		game.ball.launched = false
		game.ball.vx, game.ball.vy = 0, 0
		game.ball.x = game.paddle.x + game.paddle.w * 0.5
		game.ball.y = game.paddle.y - game.ball.r - 1
		return
	end

	game.ball.y = game.paddle.y - game.ball.r - 0.5
	game.ball.vy = -math.abs(game.ball.vy)

	local paddleCenter = game.paddle.x + game.paddle.w * 0.5
	local offset = (closestX - paddleCenter) / (game.paddle.w * 0.5)
	offset = utils.clamp(offset, -1, 1)

	game.ball.vx = game.ball.vx + offset * 140

	local nx, ny = utils.normalize(game.ball.vx, game.ball.vy)
	game.ball.vx, game.ball.vy = nx * currentBallSpeed(), ny * currentBallSpeed()
end

local function maybeSpawnPowerup(brick)
	if math.random() >= CONFIG.powerups.dropChance then return end
	local powerType = POWER_TYPES[math.random(#POWER_TYPES)]
	table.insert(game.powerups, {
		type = powerType,
		x = brick.x + brick.w * 0.5,
		y = brick.y + brick.h * 0.5,
		r = CONFIG.powerups.radius,
		vy = CONFIG.powerups.fallSpeed,
	})
end

local function bounceOffBricks(prevX, prevY)
	for _, brick in ipairs(game.bricks) do
		if brick.alive then
			local hit, dx, dy = circleRectCollision(game.ball.x, game.ball.y, game.ball.r, brick.x, brick.y, brick.w, brick.h)
			if hit then
				brick.alive = false
				game.brickCount = game.brickCount - 1
				game.score = game.score + (10 * game.level)
				game.highScore = math.max(game.highScore, game.score)
				maybeSpawnPowerup(brick)

				local ax, ay = math.abs(dx), math.abs(dy)
				if ax == 0 and ay == 0 then
					if prevY <= brick.y - game.ball.r or prevY >= brick.y + brick.h + game.ball.r then
						game.ball.vy = -game.ball.vy
					else
						game.ball.vx = -game.ball.vx
					end
				elseif ax > ay then
					game.ball.vx = -game.ball.vx
				else
					game.ball.vy = -game.ball.vy
				end

				local nx, ny = utils.normalize(game.ball.vx, game.ball.vy)
				game.ball.vx, game.ball.vy = nx * currentBallSpeed(), ny * currentBallSpeed()
				return
			end
		end
	end
end

local function updatePowerups(dt)
	-- Active timer
	if game.activePower.type ~= nil then
		game.activePower.timer = game.activePower.timer - dt
		if game.activePower.timer <= 0 then
			clearActivePowerup()
		end
	end

	-- Falling pickups
	for i = #game.powerups, 1, -1 do
		local pu = game.powerups[i]
		pu.y = pu.y + pu.vy * dt

		local hit = utils.rectCollision(
			pu.x - pu.r, pu.y - pu.r, pu.r * 2, pu.r * 2,
			game.paddle.x, game.paddle.y, game.paddle.w, game.paddle.h
		)
		if hit then
			applyPowerup(pu.type)
			table.remove(game.powerups, i)
		elseif pu.y - pu.r > WORLD.h then
			table.remove(game.powerups, i)
		end
	end
end

local function drawPowerupIcon(pu)
	local cx, cy, r = pu.x, pu.y, pu.r

	-- Base circle
	love.graphics.setColor(COLORS.powerFill)
	love.graphics.circle("fill", cx, cy, r)
	love.graphics.setColor(COLORS.powerCircle)
	love.graphics.setLineWidth(2)
	love.graphics.circle("line", cx, cy, r)
	love.graphics.setLineWidth(1)

	if pu.type == "bigger" then
		local s = r * 0.75
		love.graphics.setColor(COLORS.powerGlyph)
		-- Left triangle pointing left
		love.graphics.polygon("fill",
			cx - s, cy,
			cx - s * 0.25, cy - s * 0.55,
			cx - s * 0.25, cy + s * 0.55
		)
		-- Right triangle pointing right
		love.graphics.polygon("fill",
			cx + s, cy,
			cx + s * 0.25, cy - s * 0.55,
			cx + s * 0.25, cy + s * 0.55
		)
	elseif pu.type == "smaller" then
		local s = r * 0.75
		love.graphics.setColor(COLORS.powerGlyph)
		-- Left triangle pointing right (toward center)
		love.graphics.polygon("fill",
			cx - s * 0.20, cy,
			cx - s, cy - s * 0.55,
			cx - s, cy + s * 0.55
		)
		-- Right triangle pointing left (toward center)
		love.graphics.polygon("fill",
			cx + s * 0.20, cy,
			cx + s, cy - s * 0.55,
			cx + s, cy + s * 0.55
		)
	elseif pu.type == "faster" then
		local tW = r * 0.75
		local tH = r * 0.70
		love.graphics.setColor(COLORS.powerGlyph)
		-- Two triangles pointing right
		for _, ox in ipairs({ -r * 0.20, r * 0.20 }) do
			love.graphics.polygon("fill",
				cx + ox + tW * 0.55, cy,
				cx + ox - tW * 0.35, cy - tH * 0.55,
				cx + ox - tW * 0.35, cy + tH * 0.55
			)
		end
	elseif pu.type == "magnet" then
		local s = r * 0.70
		local gap = r * 0.10
		local w = s
		local h = s
		local lx = cx - (w + gap) * 0.5
		local rx = cx + (gap) * 0.5
		local y = cy - h * 0.5
		love.graphics.setColor(COLORS.magnetBlue)
		love.graphics.rectangle("fill", lx, y, w, h, 2, 2)
		love.graphics.setColor(COLORS.magnetRed)
		love.graphics.rectangle("fill", rx, y, w, h, 2, 2)
	end
end

local function advanceLevel()
	game.level = game.level + 1
	game.powerups = {}
	clearActivePowerup()
	resetPaddle()
	resetBall()
	buildBricks()
	game.state = game_common.STATES.PLAYING
end

local function drawLevelCompleteOverlay()
	local w, h = ui:getScreen()

	-- Overlay
	love.graphics.setColor(0, 0, 0, 0.9)
	love.graphics.rectangle("fill", 0, 0, w, h)

	-- Panel
	local panelW = math.min(400, w * 0.85)
	local panelH = 200
	local panelX = (w - panelW) / 2
	local panelY = (h - panelH) / 2

	-- Shadow
	local panelShadow = 8
	love.graphics.setColor(0, 0, 0, 0.6)
	love.graphics.rectangle("fill", panelX + panelShadow, panelY + panelShadow, panelW, panelH)

	-- Bg
	love.graphics.setColor(0.12, 0.12, 0.14, 1)
	love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)

	-- Border
	local borderColor = UI.colors.success
	love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 0.9)
	love.graphics.setLineWidth(3)
	love.graphics.rectangle("line", panelX, panelY, panelW, panelH)
	love.graphics.setLineWidth(1)

	-- Title
	love.graphics.setFont(ui.fonts.title)
	local titleText = "LEVEL COMPLETE"
	local titleW = ui.fonts.title:getWidth(titleText)
	local titleX = panelX + (panelW - titleW) / 2
	local titleY = panelY + 52

	love.graphics.setColor(0, 0, 0, 0.7)
	love.graphics.print(titleText, titleX + 2, titleY + 2)
	love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 1)
	love.graphics.print(titleText, titleX, titleY)

	-- Subtitle
	love.graphics.setFont(ui.fonts.large)
	local subText = "Press A to continue"
	local subW = ui.fonts.large:getWidth(subText)
	local subX = panelX + (panelW - subW) / 2
	local subY = panelY + 120
	love.graphics.setColor(0, 0, 0, 0.7)
	love.graphics.print(subText, subX + 2, subY + 2)
	love.graphics.setColor(UI.colors.text)
	love.graphics.print(subText, subX, subY)
end

function Scene.load()
	input = Input.new()
	ui = UI.new("Breakout")
	ui:setupWindow()

	game.state = game_common.STATES.PLAYING
	game.score = 0
	game.level = 1
	game.powerups = {}
	clearActivePowerup()
	resetPaddle()
	resetBall()
	buildBricks()
end

function Scene.update(dt)
	input:update(dt)

	-- Handle standard input (menu, exit, etc.)
	if game_common.handleStandardInput(input) then
		return
	end

	-- Handle game over/restart input
	if game.state ~= game_common.STATES.PLAYING then
		-- Level complete -> advance to next level (keep score)
		if game.state == game_common.STATES.WON then
			if input:isButtonPressed("y") or input:isButtonPressed("a") then
				advanceLevel()
			end
			return
		end

		if game_common.handleResetInput(input, game.state, Scene.load) then
			return
		end
		return
	end

	-- Paddle movement (world coords)
	do
		local dx = input:getAxisDeadzone(game_common.THRESHOLDS.MOVE)
		game.paddle.x = game.paddle.x + dx * CONFIG.paddleSpeed * dt
		game.paddle.x = utils.clamp(game.paddle.x, 0, WORLD.w - game.paddle.w)
	end

	updatePowerups(dt)

	-- Launch ball
	if not game.ball.launched then
		game.ball.x = game.paddle.x + game.paddle.w * 0.5
		game.ball.y = game.paddle.y - game.ball.r - 1
		if input:isButtonPressed("a") then
			launchBall()
		end
		return
	end

	-- Ball movement + collisions
	local prevX, prevY = game.ball.x, game.ball.y
	game.ball.x = game.ball.x + game.ball.vx * dt
	game.ball.y = game.ball.y + game.ball.vy * dt

	-- Walls
	if game.ball.x - game.ball.r < 0 then
		game.ball.x = game.ball.r
		game.ball.vx = -game.ball.vx
	elseif game.ball.x + game.ball.r > WORLD.w then
		game.ball.x = WORLD.w - game.ball.r
		game.ball.vx = -game.ball.vx
	end

	if game.ball.y - game.ball.r < 0 then
		game.ball.y = game.ball.r
		game.ball.vy = -game.ball.vy
	elseif game.ball.y - game.ball.r > WORLD.h then
		game.state = game_common.STATES.LOST
		game.highScore = math.max(game.highScore, game.score)
		return
	end

	-- Paddle + bricks
	bounceOffPaddle()
	bounceOffBricks(prevX, prevY)

	if game.brickCount <= 0 then
		game.state = game_common.STATES.WON
	end
end

function Scene.draw()
	ui:clear()

	ui:beginWorld(WORLD.w, WORLD.h)

	love.graphics.setColor(COLORS.border)
	love.graphics.rectangle("line", 0.5, 0.5, WORLD.w - 1, WORLD.h - 1)

	ui:drawScore(game.score, "Score", 10, 8, ui.fonts.small)
	ui:drawScore(game.highScore, "Best", 110, 8, ui.fonts.small)
	if game.activePower.type ~= nil then
		love.graphics.setFont(ui.fonts.small)
		love.graphics.setColor(UI.colors.textDim)
		local t = math.max(0, math.ceil(game.activePower.timer))
		love.graphics.print(tostring(t), 200, 8)
	end

	-- Bricks
	for _, brick in ipairs(game.bricks) do
		if brick.alive then
			love.graphics.setColor(brick.color)
			love.graphics.rectangle("fill", brick.x, brick.y, brick.w, brick.h, 3, 3)
		end
	end

	-- Powerups
	for _, pu in ipairs(game.powerups) do
		drawPowerupIcon(pu)
	end

	-- Paddle
	love.graphics.setColor(COLORS.paddle)
	love.graphics.rectangle("fill", game.paddle.x, game.paddle.y, game.paddle.w, game.paddle.h, 4, 4)

	-- Ball
	love.graphics.setColor(COLORS.ball)
	love.graphics.circle("fill", game.ball.x, game.ball.y, game.ball.r)

	ui:endWorld()

	if game.state == game_common.STATES.LOST then
		ui:drawGameOver(UI.colors.danger)
	elseif game.state == game_common.STATES.WON then
		drawLevelCompleteOverlay()
	end
end

return Scene
