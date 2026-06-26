--[[ Server: race state machine, ticking and state sync. ]]

LuaRace = LuaRace or {}

-- The single live game object.
LuaRace.Game = LuaRace.Game or {
	state       = LuaRace.STATE_IDLE,
	stateEnd    = 0,            -- CurTime() at which the current timed state ends
	winner      = -1,          -- LuaRace.ROLE_* of the winning side, or -1
	revealed    = {},          -- [runner] = CurTime() until which they're revealed
	lastResult  = "",          -- human readable result line
}

local G = LuaRace.Game

----------------------------------------------------------------------
-- State sync
----------------------------------------------------------------------

-- Collect runners that are currently revealed to cops (reveal time still valid).
local function GetRevealedRunners()
	local now = CurTime()
	local out = {}

	for _, ply in player.Iterator() do
		if LuaRace.IsRunner( ply ) and not LuaRace.IsBusted( ply ) then
			local until_ = G.revealed[ ply ]
			if until_ and until_ > now then
				out[ #out + 1 ] = ply
			end
		end
	end

	return out
end

-- Count participants by role / status.
function LuaRace.CountRoles()
	local cops, runners, activeRunners = 0, 0, 0

	for _, ply in player.Iterator() do
		if LuaRace.IsParticipant( ply ) then
			local role = LuaRace.GetRole( ply )
			if role == LuaRace.ROLE_COP then
				cops = cops + 1
			elseif role == LuaRace.ROLE_RUNNER then
				runners = runners + 1
				if not LuaRace.IsBusted( ply ) then
					activeRunners = activeRunners + 1
				end
			end
		end
	end

	return cops, runners, activeRunners
end

-- Broadcast the full state. Cheap enough to run a few times per second.
function LuaRace.Broadcast()
	local cops, runners, activeRunners = LuaRace.CountRoles()
	local timeLeft = math.max( 0, G.stateEnd - CurTime() )
	local revealed = GetRevealedRunners()

	net.Start( "LuaRace.Sync" )
		net.WriteUInt( G.state, 3 )
		net.WriteFloat( timeLeft )
		net.WriteUInt( cops, 8 )
		net.WriteUInt( runners, 8 )
		net.WriteUInt( activeRunners, 8 )
		net.WriteInt( G.winner, 8 )

		net.WriteUInt( #revealed, 8 )
		for _, ply in ipairs( revealed ) do
			net.WriteEntity( ply )
			net.WriteVector( LuaRace.GetTrackPos( ply ) )
		end
	net.Broadcast()
end

-- Fire a one-off event clients can react to (sounds, popups).
function LuaRace.FireEvent( name, data )
	net.Start( "LuaRace.Event" )
		net.WriteString( name )
		net.WriteString( data and util.TableToJSON( data ) or "" )
	net.Broadcast()
end

----------------------------------------------------------------------
-- State transitions
----------------------------------------------------------------------

local function ResetPlayers()
	for _, ply in player.Iterator() do
		ply:SetNWInt( LuaRace.NW_ROLE, LuaRace.ROLE_NONE )
		ply:SetNWBool( LuaRace.NW_PARTICIPANT, false )
		ply:SetNWBool( LuaRace.NW_BUSTED, false )
		ply:SetNWFloat( LuaRace.NW_BUSTPROG, 0 )
	end
end

-- Enter IDLE: clears everything.
function LuaRace.GoIdle()
	G.state    = LuaRace.STATE_IDLE
	G.stateEnd = 0
	G.winner   = -1
	G.revealed = {}
	ResetPlayers()
	LuaRace.Broadcast()
end

-- Returns ok, errMsg. Assigns roles (see sv_roles.lua) and starts the countdown.
function LuaRace.StartRace()
	if G.state ~= LuaRace.STATE_IDLE and G.state ~= LuaRace.STATE_ENDED then
		return false, "Une course est deja en cours."
	end

	local participants = LuaRace.GatherParticipants()
	if #participants < LuaRace.Cvar( "min_players" ) then
		return false, "Pas assez de joueurs (min " .. LuaRace.Cvar( "min_players" ) .. ")."
	end

	LuaRace.AssignRoles( participants )

	G.state    = LuaRace.STATE_COUNTDOWN
	G.stateEnd = CurTime() + LuaRace.Cvar( "headstart" )
	G.winner   = -1
	G.revealed = {}

	LuaRace.FireEvent( "start", {
		headstart = LuaRace.Cvar( "headstart" ),
	} )
	LuaRace.Broadcast()

	-- If there is no head start, go straight to running.
	if LuaRace.Cvar( "headstart" ) <= 0 then
		LuaRace.BeginChase()
	end

	return true
end

-- Countdown finished: release the cops.
function LuaRace.BeginChase()
	G.state    = LuaRace.STATE_RUNNING
	G.stateEnd = CurTime() + LuaRace.Cvar( "round_time" )
	LuaRace.ResetReveal() -- sets up the next ping
	LuaRace.FireEvent( "chase", {} )
	LuaRace.Broadcast()
end

-- End the race with a winning role.
function LuaRace.EndRace( winnerRole, reason )
	if G.state == LuaRace.STATE_ENDED or G.state == LuaRace.STATE_IDLE then return end

	G.state    = LuaRace.STATE_ENDED
	G.winner   = winnerRole
	G.stateEnd = CurTime() + LuaRace.Cvar( "results_time" )

	local who = winnerRole == LuaRace.ROLE_COP and "La POLICE" or "Les FUYARDS"
	G.lastResult = who .. " remporte la course !"

	LuaRace.FireEvent( "end", {
		winner = winnerRole,
		reason = reason or "",
	} )
	LuaRace.Broadcast()
end

-- Manual stop (admin / not enough players).
function LuaRace.StopRace( reason )
	LuaRace.FireEvent( "stop", { reason = reason or "" } )
	LuaRace.GoIdle()
end

----------------------------------------------------------------------
-- Tick
----------------------------------------------------------------------

local nextSync = 0

hook.Add( "Think", "LuaRace.Tick", function()
	local now = CurTime()

	if G.state == LuaRace.STATE_COUNTDOWN then
		LuaRace.HoldCops() -- keep cop vehicles still during the head start
		if now >= G.stateEnd then
			LuaRace.BeginChase()
		end

	elseif G.state == LuaRace.STATE_RUNNING then
		LuaRace.UpdateReveal( now )
		LuaRace.UpdateBusts( now )

		local _, _, activeRunners = LuaRace.CountRoles()
		if activeRunners <= 0 then
			-- Every runner caught -> cops win.
			LuaRace.EndRace( LuaRace.ROLE_COP, "all_busted" )
		elseif now >= G.stateEnd then
			-- Time's up with survivors -> runners win.
			LuaRace.EndRace( LuaRace.ROLE_RUNNER, "timeout" )
		end

	elseif G.state == LuaRace.STATE_ENDED then
		if now >= G.stateEnd then
			LuaRace.GoIdle()
		end
	end

	-- Throttled state broadcast (~5 Hz) while anything is happening.
	if G.state ~= LuaRace.STATE_IDLE and now >= nextSync then
		nextSync = now + 0.2
		LuaRace.Broadcast()
	end
end )

-- Keep counts sane when someone leaves mid-race.
hook.Add( "PlayerDisconnected", "LuaRace.Disconnect", function( ply )
	G.revealed[ ply ] = nil
end )

-- New joiners get a clean state pushed to them.
hook.Add( "PlayerInitialSpawn", "LuaRace.Welcome", function()
	timer.Simple( 3, LuaRace.Broadcast )
end )
