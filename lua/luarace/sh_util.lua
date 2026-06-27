--[[ Shared helpers + network string registration. ]]

LuaRace = LuaRace or {}

-- Network strings.
if SERVER then
	util.AddNetworkString( "LuaRace.Sync" )        -- broadcast game state each tick
	util.AddNetworkString( "LuaRace.Event" )       -- one-off events (start, bust, win...)
	util.AddNetworkString( "LuaRace.PickVehicle" ) -- client -> server vehicle choice
end

-- Networked-var keys (set per player on the server, auto-replicated).
LuaRace.NW_ROLE        = "LuaRace_Role"        -- int role
LuaRace.NW_PARTICIPANT = "LuaRace_InRace"      -- bool
LuaRace.NW_BUSTED      = "LuaRace_Busted"      -- bool (runner caught)
LuaRace.NW_BUSTPROG    = "LuaRace_BustProgress"-- float 0-1 (runner being busted)

--[[ Role helpers. Safe to call on both realms. ]]
function LuaRace.GetRole( ply )
	if not IsValid( ply ) then return LuaRace.ROLE_NONE end
	return ply:GetNWInt( LuaRace.NW_ROLE, LuaRace.ROLE_NONE )
end

function LuaRace.IsCop( ply )    return LuaRace.GetRole( ply ) == LuaRace.ROLE_COP end
function LuaRace.IsRunner( ply ) return LuaRace.GetRole( ply ) == LuaRace.ROLE_RUNNER end

function LuaRace.IsParticipant( ply )
	return IsValid( ply ) and ply:GetNWBool( LuaRace.NW_PARTICIPANT, false )
end

function LuaRace.IsBusted( ply )
	return IsValid( ply ) and ply:GetNWBool( LuaRace.NW_BUSTED, false )
end

--[[ Returns the player's "race position": their Glide vehicle position if
     they're driving one, otherwise their own position. This is what the chase
     actually tracks. ]]
function LuaRace.GetTrackPos( ply )
	if not IsValid( ply ) then return Vector( 0, 0, 0 ) end

	if ply.GlideGetVehicle then
		local veh = ply:GlideGetVehicle()
		if IsValid( veh ) then return veh:GetPos() end
	end

	-- Fall back to a regular vehicle or the player.
	local veh = ply:GetVehicle()
	if IsValid( veh ) then return veh:GetPos() end

	return ply:GetPos()
end

-- Speed (units/s) of whatever the player is tracked by (vehicle or self).
function LuaRace.GetTrackSpeed( ply )
	if not IsValid( ply ) then return 0 end

	if ply.GlideGetVehicle then
		local veh = ply:GlideGetVehicle()
		if IsValid( veh ) then return veh:GetVelocity():Length() end
	end

	local veh = ply:GetVehicle()
	if IsValid( veh ) then return veh:GetVelocity():Length() end

	return ply:GetVelocity():Length()
end

-- Is the player currently sitting in a Glide vehicle?
function LuaRace.InGlideVehicle( ply )
	if not IsValid( ply ) or not ply.GlideGetVehicle then return false end
	return IsValid( ply:GlideGetVehicle() )
end

-- Format a number of seconds as M:SS for the HUD.
function LuaRace.FormatTime( seconds )
	seconds = math.max( 0, math.ceil( seconds ) )
	return string.format( "%d:%02d", math.floor( seconds / 60 ), seconds % 60 )
end
