--[[ Server: busting runners by staying close to them. ]]

LuaRace = LuaRace or {}

local G = LuaRace.Game

-- Accumulated bust time per runner (seconds within range).
local progress = {}
local lastTick = CurTime()

-- Find the closest cop to a position within a radius. Returns cop, dist or nil.
local function NearestCop( pos, radius )
	local best, bestDist = nil, radius
	for _, ply in player.Iterator() do
		if LuaRace.IsParticipant( ply ) and LuaRace.IsCop( ply ) and ply:Alive() then
			local d = LuaRace.GetTrackPos( ply ):Distance( pos )
			if d <= bestDist then
				best, bestDist = ply, d
			end
		end
	end
	return best, bestDist
end

-- Mark a runner as caught.
local function Bust( runner, cop )
	runner:SetNWBool( LuaRace.NW_BUSTED, true )
	runner:SetNWFloat( LuaRace.NW_BUSTPROG, 1 )
	progress[ runner ] = nil
	G.revealed[ runner ] = nil

	LuaRace.FireEvent( "bust", {
		runner = runner:Nick(),
		cop    = IsValid( cop ) and cop:Nick() or "?",
	} )
end

function LuaRace.UpdateBusts( now )
	local dt = now - lastTick
	lastTick = now
	if dt <= 0 then return end

	local radius   = LuaRace.Cvar( "bust_radius" )
	local bustTime = LuaRace.Cvar( "bust_time" )

	for _, ply in player.Iterator() do
		if LuaRace.IsRunner( ply ) and LuaRace.IsParticipant( ply ) and not LuaRace.IsBusted( ply ) then
			local pos = LuaRace.GetTrackPos( ply )
			local cop, dist = NearestCop( pos, radius )

			local p = progress[ ply ] or 0
			if cop then
				-- Closer cops bust faster: full speed at the edge, 1.6x point-blank.
				local closeness = 1 + ( 1 - dist / radius ) * 0.6
				p = p + dt * closeness
				if p >= bustTime then
					Bust( ply, cop )
					p = 0
				end
			else
				-- Cooling off when nobody is near (slower than it builds).
				p = math.max( 0, p - dt * 0.75 )
			end

			progress[ ply ] = p
			ply:SetNWFloat( LuaRace.NW_BUSTPROG, math.Clamp( p / bustTime, 0, 1 ) )
		end
	end
end

-- Clear accumulators when a race resets.
hook.Add( "PlayerDisconnected", "LuaRace.BustCleanup", function( ply )
	progress[ ply ] = nil
end )
