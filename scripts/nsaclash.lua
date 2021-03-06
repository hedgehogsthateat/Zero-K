include "constants.lua"
include "RockPiece.lua"

local base = piece 'base' 
local front = piece 'front' 
local turret = piece 'turret' 
local lbarrel = piece 'lbarrel' 
local rbarrel = piece 'rbarrel' 
local lflare = piece 'lflare' 
local rflare = piece 'rflare' 
local exhaust = piece 'exhaust'
local wakes = {}
for i = 1, 8 do
	wakes[i] = piece ('wake' .. i)
end
local ground1 = piece 'ground1'

local random = math.random 

local shotNum = 1
local flares = {
	lflare,
	rflare,
}

local gunHeading = 0

local ROCKET_SPREAD = 0.4

local SIG_ROCK_X = 8
local SIG_ROCK_Z = 16

local ROCK_FIRE_FORCE = 0.35
local ROCK_SPEED = 10	--Number of half-cycles per second around x-axis.
local ROCK_DECAY = -0.85	--Rocking around axis is reduced by this factor each time = piece 'to rock.
local ROCK_PIECE = base	-- should be negative to alternate rocking direction.
local ROCK_MIN = 0.001 --If around axis rock is not greater than this amount, rocking will stop after returning to center.
local ROCK_MAX = 1.5

local SIG_MOVE = 1
local SIG_AIM = 2
local RESTORE_DELAY = 3000

local function WobbleUnit()
	local wobble = true
	while true do
		if wobble == true then
			Move(base, y_axis, 0.9, 1.2)
		end
		if wobble == false then
		
			Move(base, y_axis, -0.9, 1.2)
		end
		wobble = not wobble
		Sleep(750)
	end
end

local sfxNum = 0
function script.setSFXoccupy(num)
	sfxNum = num
end

local function MoveScript()
	while Spring.GetUnitIsStunned(unitID) do
		Sleep(2000)
	end
	while true do
		if not Spring.GetUnitIsCloaked(unitID) then
			if (sfxNum == 1 or sfxNum == 2) and select(2, Spring.GetUnitPosition(unitID)) == 0 then
				for i = 1, 8 do
					EmitSfx(wakes[i], 3)
				end
			else
				EmitSfx(ground1, 1024)
			end
		end
		Sleep(150)
	end
end

function script.Create()
	Turn(exhaust, y_axis, math.rad(-180))
	Turn(lbarrel, y_axis, ROCKET_SPREAD)
	Turn(rbarrel, y_axis, -ROCKET_SPREAD)
	StartThread(SmokeUnit, {base})
	StartThread(WobbleUnit)
	StartThread(MoveScript)
	InitializeRock(ROCK_PIECE, ROCK_SPEED, ROCK_DECAY, ROCK_MIN, ROCK_MAX, SIG_ROCK_X, x_axis)
	InitializeRock(ROCK_PIECE, ROCK_SPEED, ROCK_DECAY, ROCK_MIN, ROCK_MAX, SIG_ROCK_Z, z_axis)
end

local function RestoreAfterDelay()
	Sleep(RESTORE_DELAY)
	Turn(turret, y_axis, 0, math.rad(90))
	Turn(turret, x_axis, 0, math.rad(45))
end

function script.AimFromWeapon() 
	return turret
end

function script.AimWeapon(num, heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	Turn(turret, y_axis, heading, math.rad(180))
	Turn(turret, x_axis, -pitch, math.rad(100))
	Turn(lbarrel, y_axis, ROCKET_SPREAD + 2*pitch, math.rad(300))
	Turn(rbarrel, y_axis, -ROCKET_SPREAD - 2*pitch, math.rad(300))
	Turn(lbarrel, x_axis, -pitch, math.rad(300))
	Turn(rbarrel, x_axis, -pitch, math.rad(300))
	gunHeading = heading
	WaitForTurn(turret, y_axis)
	WaitForTurn(turret, x_axis)
	StartThread(RestoreAfterDelay)
	return (1)
end

function script.QueryWeapon(piecenum)
	return flares[shotNum]
end

function script.FireWeapon()
	StartThread(Rock, gunHeading, ROCK_FIRE_FORCE, z_axis)
	StartThread(Rock, gunHeading - hpi, ROCK_FIRE_FORCE*0.4, x_axis)
end

function script.BlockShot(num, targetID)
	return GG.OverkillPrevention_CheckBlock(unitID, targetID, 620.1, 70, 0.3)
end

function script.Shot() 
	EmitSfx(flares[shotNum], UNIT_SFX2)
	EmitSfx(exhaust, UNIT_SFX3)
	shotNum = 3 - shotNum
end

function script.Killed(recentDamage, maxHealth)
	local severity = recentDamage / maxHealth
	if severity <= 0.25 then
		return 1
	elseif severity <= 0.50 then
		Explode(front, sfxNone)
		Explode(turret, sfxShatter)
		return 1
	elseif severity <= 0.99 then
		Explode(front, sfxShatter)
		Explode(turret, sfxShatter)
		return 2
	end
	Explode(front, sfxShatter)
	Explode(turret, sfxShatter)
	return 2
end
