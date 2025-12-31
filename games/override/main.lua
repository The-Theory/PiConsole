---@diagnostic disable: undefined-global

--[[
OVERRIDE — DEVELOPMENT TODO (BASE GAME)

This assumes:

Top-down

Single-screen rooms

Minimal pixel-shape art

Room → choice → room

Mods overwrite / reshape gameplay

No meta systems yet

0️⃣ PROJECT SETUP (DO THIS ONCE)

Create project repo

Decide engine / framework

Lock resolution to 480×320

Enable pixel-perfect rendering

Disable texture filtering / smoothing

Set fixed timestep (e.g. 60 FPS)

Implement basic game state system:

Boot

Playing

Upgrade choice

Pause

Death

Do not add menus yet.

1️⃣ CORE PLAYER CONTROLS (HIGHEST PRIORITY)

Nothing else matters if this doesn’t feel good.

Player movement

Implement top-down movement (8-direction)

Decide:

acceleration vs instant velocity

max speed

Clamp player to room bounds

Add simple collision against walls

Dash

Dash input (B button)

Fixed dash distance (not speed-based)

Temporary invulnerability during dash

Dash cooldown timer

Dash cancels velocity cleanly

Dash visual feedback (scale, trail, or flash)

Damage & health

Player health (start small, e.g. 3)

Damage cooldown / i-frames

Visual feedback on hit (flash, knockback)

Death trigger

👉 Stop here and test movement in an empty room.
If this isn’t fun, fix it before continuing.

2️⃣ ROOM SYSTEM (STRUCTURAL FOUNDATION)
Room container

Define room bounds (screen size)

Draw simple boundary walls

Add optional internal obstacles (rectangles)

Room lifecycle

On room start:

lock exits

spawn enemies

Track active enemies

On room clear:

unlock exits

transition to upgrade screen

Room transitions

Clean fade or slide transition

Reset player position

Reset temporary effects

3️⃣ ENEMY FRAMEWORK (KEEP THIS GENERAL)
Base enemy system

Enemy base class:

position

velocity

HP

hitbox

Enemy takes damage

Enemy death event

Enemy cleanup

Enemy spawning

Spawn points (edges / corners)

Spawn waves or timed spawns

Cap max enemies on screen

4️⃣ FIRST ENEMY TYPES (ONLY 3)

Keep this very small.

Enemy 1 — Charger

Idle phase

Telegraph (pause or flash)

Fast straight charge

Collision damage

Enemy 2 — Orbiter

Maintains distance from player

Circles player

Constant pressure

Enemy 3 — Shooter

Stops moving

Fires simple projectiles

Clear firing rhythm

👉 Combine these in rooms before adding more.

5️⃣ PLAYER ATTACK (MINIMAL BUT SOLID)
Basic attack

Auto-fire on timer

Fire toward nearest enemy OR facing direction

Simple projectile

Projectile lifetime

Projectile collision

Feedback

Hit flash on enemies

Small death effect (circle pop, scale)

6️⃣ MOD SYSTEM (CORE IDENTITY)

This is the heart of OVERRIDE.

Mod slots

Define 3 mod slots:

Weapon

Movement

Rule / Utility

Only one mod per slot

New mod replaces old mod in slot

Mod structure

Mod base interface:

onEquip

onUnequip

hooks (onHit, onDash, onKill, etc.)

7️⃣ ENEMY MODS (GLOBAL ROOM CONDITIONS)
Enemy mod framework

Only ONE enemy mod active per room

Enemy mod applies to all enemies

Enemy mod replaces previous one

Initial enemy mods (pick 3–5)

Faster enemies

Enemies explode on death

Enemies spawn in groups

Enemies take reduced first hit

Enemy mod presentation

Show mod name briefly on room start

Optional icon

Optional subtle screen pulse

8️⃣ PLAYER MODS (COUNTERPLAY)
First batch (10 total max initially)

Weapon mods:

Pierce

Chain hit

Close-range bonus

Movement mods:

Double dash

Dash damage

Blink dash

Utility / rule mods:

Slow enemies on dash

Shield on kill

Time slow on low HP

Each mod must:

change behavior

not just change numbers

9️⃣ UPGRADE CHOICE SCREEN (KEEP IT FAST)
UI

Pause gameplay

Show 3 mod cards

Highlight selection with joystick

Confirm with A

Rules

Mods offered are contextual:

related to current enemy mod

avoid duplicates

No rerolls (for now)

Immediate return to gameplay

🔟 ROOM DIFFICULTY CURVE
Scaling

Increase enemy count gradually

Introduce harder enemy mods later

Mix enemy types more aggressively

Room types

Open arena

Pillar room

Narrow movement room

Survival timer room

1️⃣1️⃣ DEATH & RESTART
Death

Freeze briefly

Clear effects

Fade to restart

Restart

Immediate return to Room 1

No meta progression yet

No menus unless absolutely necessary

1️⃣2️⃣ UI & POLISH (ONLY AFTER GAME FEELS GOOD)
HUD

HP indicators

Active mod icons (small)

Dash cooldown indicator

Feedback

Screen shake (very subtle)

Audio cues:

dash

hit

mod swap

room clear

1️⃣3️⃣ TITLE SCREEN (MINIMAL)

Show OVERRIDE icon

Show title text

Press A to start

No background animation yet

🚫 THINGS TO DELIBERATELY NOT BUILD YET

Do not add:

meta progression

unlock trees

score systems

achievements

story

more than 5 enemies

more than 10 player mods

more than 5 enemy mods

These come after playtesting.

FINAL DEVELOPMENT RULE (IMPORTANT)

If a feature does not directly improve
movement, decision-making, or clarity,
it does not get added.
]]--

-- Shared libraries
local Input = require("TiPiL.input")
local UI = require("TiPiL.ui")
local utils = require("TiPiL.utils")
local game_common = require("TiPiL.game_common")

local Scene = {}

-- Game state
local input, ui
local game = {
	state = game_common.STATES.PLAYING,
	player = {
		health = 100,
		speed = 100,
	},

	mods = {
		weapon = nil,
		movement = nil,
		rule = nil,
		enemy = nil,
	},

	enemies = {},
}

-- Scene callbacks
function Scene.load()
	input = Input.new()
	ui = UI.new("New Game")
	ui:setupWindow()

	-- Initialize game state here
	game.state = game_common.STATES.PLAYING
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

	-- Your game logic here
end

function Scene.draw()
	ui:clear()

	local w, h = ui:getScreen()

	-- Your drawing code here

	-- Overlays
	if game.state == game_common.STATES.GAME_OVER then
		ui:drawGameOver(UI.colors.danger)
	end
end

return Scene
